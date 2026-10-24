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
pub let context_char_budget : Int32 = 6000

///|
/// How many example lines may ride in one prompt. A handful of real sentences
/// stabilises a voice; twenty of them crowd out the actual conversation.
pub let example_lines_limit : Int32 = 8

///|
/// Build the system prompt for a conversation with one character.
///
/// The order is the six blocks of the card, deliberately: ① who they are,
/// ② how they judge and act, ③ how they talk (with real example lines — a
/// handful of actual sentences stabilises a voice far better than adjectives),
/// ④ the bond with the player, ⑤ the situation the opening assumes, then the
/// hidden material (goal, secret, memory rules), and finally the world and
/// scene. The card fields come before the world background because persona
/// outranks setting when the two conflict.
pub fn build_system_prompt(
  scenario : Scenario,
  card : CharacterCard,
  mood~ : SceneMood? = None,
) -> String {
  let sections : Array[String] = []
  sections.push(
    "你在扮演一个互动世界中的角色。用第一人称回应，始终留在角色中。",
  )
  sections.push("【世界】\n" + scenario.background())
  sections.push("【你是" + card.name() + "】\n" + card.persona())
  if card.principles() != "" {
    sections.push("【行为原则】" + card.principles())
  }
  if card.appearance() != "" {
    sections.push("【外貌】" + card.appearance())
  }
  if card.voice() != "" {
    sections.push("【说话方式】" + card.voice())
  }
  // ③ Example lines: real sentences in the character's own voice, capped so a
  // chatty author cannot spend the whole budget rehearsing.
  if !card.examples().is_empty() {
    let lines : Array[String] = []
    let mut count = 0
    for example in card.examples() {
      if count >= example_lines_limit {
        break
      }
      if example.trim() != "" {
        lines.push(card.name() + "：" + example)
        count += 1
      }
    }
    if !lines.is_empty() {
      sections.push("【示例台词】\n" + lines.join("\n"))
    }
  }
  // ④ The relationship: who the player is, what they are called, the boundary.
  let relationship = card.relationship()
  let relationship_lines : Array[String] = []
  if relationship.user_identity() != "" {
    relationship_lines.push("玩家身份：" + relationship.user_identity())
  }
  if relationship.user_name() != "" {
    relationship_lines.push(
      "你称呼玩家：「" + relationship.user_name() + "」",
    )
  }
  if relationship.boundary() != "" {
    relationship_lines.push("关系边界：" + relationship.boundary())
  }
  if !relationship_lines.is_empty() {
    sections.push("【与用户的关系】\n" + relationship_lines.join("\n"))
  }
  if card.setting() != "" {
    sections.push("【当前情境】" + card.setting())
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
  if card.memory_rules() != "" {
    sections.push(
      "【记忆规则】" +
      card.memory_rules() +
      "（这些是你在长期相处中必须守住的记忆。）",
    )
  }
  // The scene line is the same string the header shows: the mood's title when
  // the player set one, the world name otherwise, with the time label.
  let resolved = match mood {
    Some(value) => value
    None => scenario.mood()
  }
  let scene_title = if resolved.title() != "" {
    resolved.title()
  } else {
    scenario.name()
  }
  sections.push(
    "【场景】" +
    scene_title +
    (if resolved.time_label() != "" { "（\{resolved.time_label()}）" } else { "" }),
  )
  for place in scenario.locations() {
    sections.push("- " + place.name() + "：" + place.description())
  }
  sections.join("\n\n")
}

///|
/// The messages the next request would carry, verbatim.
///
/// This is the *same* assembly the send path uses — `plan_messages`, the same
/// scene prompt swap, the same memory selection — so the preview cannot
/// drift from what is really sent. A power user can read what the model
/// sees, and carry it to another tool.
pub fn prompt_preview_messages(
  model : WorldModel,
  draft : String,
) -> Array[(String, String)] {
  let player_text = draft.trim().to_owned()
  match model.scene_location() {
    Some(location) => {
      let cast = cast_at(model.scenario, location)
      let conversation = model.conversations.for_character(scene_key(location))
      let turn_index = match
        conversation.lines().filter(line => line.speaker() is Player) {
        players => players.length()
      }
      match responder_for(cast, player_text, turn_index) {
        None => []
        Some(responder) => {
          let memories = select_memories(
            model.memories.for_character(responder.id()).entries(),
            player_text,
          )
          let mood = conversation.mood().unwrap_or(model.scenario.mood())
          let plan = plan_messages(
            model.scenario,
            responder,
            conversation,
            player_text,
            budget=model.config.context_budget(),
            memories~,
            mood=Some(mood),
          )
          // A scene turn swaps the persona prompt for the scene prompt; the
          // rest of the plan rides along unchanged.
          let messages : Array[(String, String)] = [
            (
              "system",
              build_scene_prompt(
                model.scenario,
                location,
                cast,
                responder,
              ),
            ),
          ]
          for index, message in plan.messages {
            if index > 0 {
              messages.push(message)
            }
          }
          messages
        }
      }
    }
    None =>
      match model.selected {
        None => []
        Some(id) =>
          match model.scenario.character(id) {
            None => []
            Some(card) => {
              let stored = model.conversations.for_character(id)
              // The pending line rides in the preview: the player reads what
              // pressing 发送 would actually send.
              let conversation = if player_text == "" {
                stored
              } else {
                stored.append(ChatLine::player(player_text))
              }
              let memories = select_memories(
                model.memories.for_character(id).entries(),
                player_text,
              )
              let mood = conversation.mood().unwrap_or(model.scenario.mood())
              let plan = plan_messages(
                model.scenario,
                card,
                conversation,
                player_text,
                budget=model.config.context_budget(),
                memories~,
                mood=Some(mood),
              )
              // The newest line is framed for the model only — the same
              // framing the send path applies, so the preview shows the text
              // the model really reads.
              let wire : Array[(String, String)] = []
              for index, message in plan.messages {
                if index == plan.messages.length() - 1 {
                  wire.push((message.0, frame_player_turn(message.1, Say)))
                } else {
                  wire.push(message)
                }
              }
              wire
            }
          }
      }
  }
}

///|
/// The prompt preview as plain text (what the clipboard carries).
pub fn prompt_preview_text(model : WorldModel, draft : String) -> String {
  let messages = prompt_preview_messages(model, draft)
  let lines : Array[String] = []
  for message in messages {
    let (role, text) = message
    lines.push("=== " + role + " ===")
    lines.push(text)
    lines.push("")
  }
  lines.join("\n")
}

///|
/// The label of a wire role, the way the preview shows it.
pub fn prompt_role_label(role : String) -> String {
  match role {
    "system" => "系统 / 上下文"
    "user" => "玩家"
    "assistant" => "角色"
    _ => role
  }
}

///|
///|
/// Frame the player's line according to its intent, so the model knows whether
/// it is being spoken to, shown an action, or handed narration to continue.
///
/// This is the AI Dungeon "do / say / story" distinction at the prompt layer:
/// without it, "我推开门" reads as dialogue and the model answers it in quotes
/// instead of describing what is behind the door.
pub fn frame_player_text(text : String, intent : InputIntent) -> String {
  match intent {
    Say => text
    Do =>
      "*" +
      text +
      "*（这是一个动作，请回应它的后果，不要当成对白回答）"
    Story =>
      "（旁白）" +
      text +
      "（这是玩家在叙述，请接着往下写，不要以角色身份回话）"
    Beat =>
      "（这一幕）" +
      text +
      "（这是玩家给出的一拍：请把它演出来——写场景、在场的人与他们的反应，不要以角色身份回话）"
  }
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
/// Build the wire messages for one request: system prompt, the character's
/// long-term memories, the rolling summary, the world-book block, and the
/// history that fits the budget.
///
/// The world-book block rides on the *player's* turn rather than the system
/// prompt, so only the turn that mentions "当铺" pays for the pawnshop lore.
///
/// Two messages are never trimmed: the system prompt (persona outranks
/// setting) and the newest line (the player's actual turn). Dropping the
/// newest line would make the model answer the world description instead of
/// the question, so it is reserved before the history walk starts.
pub fn plan_messages(
  scenario : Scenario,
  card : CharacterCard,
  conversation : Conversation,
  player_text : String,
  budget~ : Int32 = context_char_budget,
  memories~ : Array[MemoryEntry] = [],
  mood~ : SceneMood? = None,
) -> MessagePlan {
  let messages : Array[(String, String)] = []
  // Position matters: `Before` entries are world rules and belong ahead of the
  // persona, `After` entries are scene facts that belong just before the
  // history. Both come from the same lorebook, ordered by priority.
  let hits = select_lore(
    scenario,
    player_text,
    "",
    conversation.lines().length(),
  )
  let before = lore_block_at(hits, Before)
  if before != "" {
    messages.push(("system", "【世界规则】\n" + before))
  }
  messages.push(("system", build_system_prompt(scenario, card, mood~)))
  // The shared history the player pinned or that matched this turn: what the
  // character remembers about *them*, not about the world.
  if !memories.is_empty() {
    let lines : Array[String] = []
    for entry in memories {
      lines.push("- " + entry.content())
    }
    messages.push(
      (
        "system",
        "【长久的记忆】\n" +
        lines.join("\n") +
        "\n（这些是你与玩家共同经历的事实，像记得自己的名字一样记得它们。）",
      ),
    )
  }
  if conversation.summary() != "" {
    // The compressed memory of everything that fell out of the window. It
    // participates in the budget like any other message.
    messages.push(("system", "【此前】\n" + conversation.summary()))
  }
  let after = lore_block_at(hits, After)
  if after != "" {
    messages.push(("system", "【相关背景】\n" + after))
  }
  let lines = conversation.lines()
  // History newest-first until the remaining budget is spent. The newest line
  // is mandatory (see above), so it is taken before the loop and its cost is
  // charged up front.
  let kept : Array[(String, String)] = []
  let evicted : Array[ChatLine] = []
  let mut used = total_chars(messages)
  let mut index = lines.length()
  if index > 0 {
    index -= 1
    let newest = lines[index]
    let wire = (newest.wire_role(), newest.text)
    kept.push(wire)
    used += wire.0.length() + wire.1.length()
  }
  while index > 0 {
    index -= 1
    let line = lines[index]
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
  let evict_count = lines.length() - kept.length()
  for back in 0..<evict_count {
    evicted.push(lines[back])
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
fn total_chars(messages : Array[(String, String)]) -> Int32 {
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
pub let summary_keep_recent : Int32 = 10

///|
/// Minimum number of NEW conversation lines before compression runs again.
pub let summary_min_new_lines : Int32 = 10

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
  evicted_count : Int32,
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
  keep_recent : Int32,
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
pub let memory_proposal_recent_lines : Int32 = 12

///|
/// How many appends between memory-extraction proposals.
pub let memory_proposal_every : Int32 = 10

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
pub fn clip_chars(text : String, max_chars : Int32) -> String {
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
