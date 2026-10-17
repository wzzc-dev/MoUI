///|
/// Prompt assembly: turn a scenario plus a conversation into a request.
///
/// Everything here is a pure function. That matters for two reasons: the prompt
/// can be unit-tested without a provider, and the character of the example's
/// "AI" is reviewable as text rather than hidden behind a network call.
///
/// Budget rule (fixed order, so trimming is predictable): the system prompt is
/// never trimmed, world-book hits are included while they fit, then history is
/// kept newest-first until the budget runs out.

///|
/// How many characters of prompt we are willing to send. Bounded so a
/// misbehaving provider cannot be handed an unbounded request.
pub let context_char_budget : Int = 6000

///|
/// Build the system prompt for a conversation with one character.
///
/// The order is deliberate: who they are, then how they talk, then what they
/// want, then what they are hiding, then the world. The card fields come before
/// the world background because persona outranks setting when the two conflict.
pub fn build_system_prompt(scenario : Scenario, card : CharacterCard) -> String {
  let sections : Array[String] = []
  sections.push(
    "你在扮演一个互动世界中的角色。用第一人称回应，始终留在角色中。",
  )
  sections.push("【世界】\n" + scenario.background())
  sections.push("【你是" + card.name() + "】\n" + card.persona())
  if card.appearance() != "" {
    sections.push("【外貌】" + card.appearance())
  }
  if card.voice() != "" {
    sections.push("【说话方式】" + card.voice())
  }
  if card.goal() != "" {
    sections.push("【你想要的】" + card.goal())
  }
  if card.secret() != "" {
    // The secret is withheld unless the player earns it: this is what makes
    // asking the right question pay off instead of everything being dumpable
    // in one line.
    sections.push(
      "【秘密】" +
      card.secret() +
      "（除非玩家明确问起或你信任对方，不要主动说出）",
    )
  }
  sections.push("【场景】" + scenario.name())
  for place in scenario.locations() {
    sections.push("- " + place.name() + "：" + place.description())
  }
  sections.join("\n\n")
}

///|
/// The world-book block for one player turn, or `""` when nothing matched.
pub fn world_book_for(scenario : Scenario, player_text : String) -> String {
  world_book_block(scenario, player_text)
}

///|
/// The outcome of planning one request: the wire messages plus the history
/// lines that did NOT fit the budget (oldest first). The evicted tail is what
/// the compressor consumes, so eviction stays a pure, inspectable value.
pub(all) struct MessagePlan {
  messages : Array[(String, String)]
  evicted : Array[ChatLine]
} derive(Eq, Debug)

///|
pub extend MessagePlan with Debug::{to_repr}

///|
pub extend MessagePlan with Eq::{not_equal, equal}

///|
/// Build the wire messages for one request: system prompt, the rolling
/// summary, the world-book block, and the history that fits the budget.
///
/// The world-book block rides on the *player's* turn rather than the system
/// prompt, so only the turn that mentions "当铺" pays for the pawnshop lore.
pub fn plan_messages(
  scenario : Scenario,
  card : CharacterCard,
  conversation : Conversation,
  player_text : String,
  budget? : Int = context_char_budget,
) -> MessagePlan {
  let messages : Array[(String, String)] = []
  messages.push(("system", build_system_prompt(scenario, card)))
  if conversation.summary() != "" {
    // The compressed memory of everything that fell out of the window. It
    // participates in the budget like any other message.
    messages.push(("system", "【此前】\n" + conversation.summary()))
  }
  let lore = world_book_for(scenario, player_text)
  if lore != "" {
    messages.push(("system", "【相关背景】\n" + lore))
  }
  // History newest-first until the remaining budget is spent.
  let mut used = total_chars(messages)
  let kept : Array[(String, String)] = []
  let evicted : Array[ChatLine] = []
  let mut index = conversation.lines().length()
  while index > 0 {
    index -= 1
    let line = conversation.lines()[index]
    let wire = (line.wire_role(), line.text)
    let cost = wire.0.length() + wire.1.length()
    if used + cost > budget {
      break
    }
    kept.push(wire)
    used += cost
  }
  // Everything before the kept newest lines is evicted, oldest first, ready
  // for the compressor.
  let evict_count = conversation.lines().length() - kept.length()
  for back in 0..<evict_count {
    evicted.push(conversation.lines()[back])
  }
  // Restore oldest-first order for the wire.
  let mut cursor = kept.length()
  while cursor > 0 {
    cursor -= 1
    messages.push(kept[cursor])
  }
  { messages, evicted, }
}

///|
/// Build the wire messages for one request (the default budget).
pub fn build_messages(
  scenario : Scenario,
  card : CharacterCard,
  conversation : Conversation,
  player_text : String,
) -> Array[(String, String)] {
  plan_messages(scenario, card, conversation, player_text).messages
}

///|
fn total_chars(messages : Array[(String, String)]) -> Int {
  let mut total = 0
  for message in messages {
    total += message.0.length() + message.1.length()
  }
  total
}

///|
/// A one-line description of what the model was shown, for the UI's prompt
/// inspector. This is what makes a surprising reply debuggable: the player can
/// see exactly which lore got injected and how much history survived.
pub fn prompt_summary(
  scenario : Scenario,
  card : CharacterCard,
  conversation : Conversation,
  player_text : String,
) -> String {
  let messages = build_messages(scenario, card, conversation, player_text)
  let hits = world_book_trigger(scenario, player_text).length()
  "\{messages.length()} messages, \{total_chars(messages)} chars" +
  (if hits > 0 { ", \{hits} lore hits" } else { ", no lore hit" })
}

///|
/// How many recent lines stay raw (un-summarized) in the request.
pub let summary_keep_recent : Int = 10

///|
/// Minimum number of NEW conversation lines before compression runs again.
pub let summary_min_new_lines : Int = 10

///|
/// The oldest chunk of a conversation: everything before the last
/// `summary_keep_recent` raw lines. Empty when there is nothing worth folding
/// into the rolling summary.
pub fn compression_source(conversation : Conversation) -> Array[ChatLine] {
  let lines = conversation.lines()
  if lines.length() <= summary_keep_recent {
    return []
  }
  lines[0:lines.length() - summary_keep_recent].to_owned()
}

///|
/// Should this turn fire a compression request? True when the history is
/// actually under pressure (at the cap, or the budget evicted lines) and at
/// least `summary_min_new_lines` new lines accumulated since the last
/// summary, so the provider is not asked on every send.
pub fn needs_compression(
  conversation : Conversation,
  evicted_count : Int,
) -> Bool {
  let under_pressure = conversation.lines().length() >=
    chat_history_limit - summary_keep_recent ||
    evicted_count > 0
  under_pressure &&
  conversation.appended() - conversation.summarized_upto() >=
  summary_min_new_lines
}

///|
/// Render conversation lines for a prompt, speaker-readable:
/// `你: …` / `<角色名>: …`. Lines newer than `keep_recent` are cut, matching
/// what the request itself still shows verbatim.
fn render_lines(
  lines : Array[ChatLine],
  character_name : String,
  keep_recent : Int,
) -> String {
  let rendered : Array[String] = []
  for line in lines {
    let prefix = match line.speaker() {
      Player => "你"
      Character(_) => character_name
    }
    rendered.push("\{prefix}: \{line.text()}")
  }
  let start = (rendered.length() - keep_recent).max(0)
  rendered[start:].join("\n")
}

///|
/// The prompt pair that folds an old conversation chunk (and any previous
/// summary) into one short fact note.
pub fn summarize_prompt(
  character_name~ : String,
  prior_summary~ : String,
  source_lines~ : Array[ChatLine],
) -> (String, String) {
  let system = "你是对话世界的记忆压缩器。把给定的旧对话压写成一段不超过120字的第三人称事实笔记。保留:已达成的承诺、已经说出口的秘密、关系变化、地点与事件。不要复述寒暄,不要添加对话里没有的事实。只输出笔记本身。"
  let user = if prior_summary == "" {
    render_lines(source_lines, character_name, summary_keep_recent)
  } else {
    "既有笔记:\n\{prior_summary}\n\n新增片段:\n\{render_lines(source_lines, character_name, summary_keep_recent)}"
  }
  (system, user)
}

///|
/// How many recent lines the memory extractor reads.
pub let memory_proposal_recent_lines : Int = 12

///|
/// How many appends between memory-extraction proposals.
pub let memory_proposal_every : Int = 10

///|
/// The prompt pair asking the provider to distill durable facts into
/// world-book entries. The reply is JSON shaped like the world codec.
pub fn propose_memory_prompt(
  character_name~ : String,
  lines~ : Array[ChatLine],
) -> (String, String) {
  let system = [
    "你是对话世界的记忆管理员。从最近对话中找出 0-2 条值得世界长期记住的客观事实(承诺、关系、身份、地点、重要事件)。",
    "只输出一个 JSON 对象:{\"memories\":[{\"keys\":[\"触发关键词\"],\"content\":\"一句话事实\"}]}。",
    "关键词必须出现在事实里;没有值得记的就输出 {\"memories\":[]}。不要输出 JSON 以外的文字。",
  ].join("\n")
  (system, render_lines(lines, character_name, memory_proposal_recent_lines))
}

///|
/// Hard-truncate a summary so a misbehaving provider cannot inflate it.
pub fn clip_chars(text : String, max_chars : Int) -> String {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  if chars.length() <= max_chars {
    text
  } else {
    String::from_array(chars[0:max_chars]) + "……"
  }
}
