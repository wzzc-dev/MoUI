///|
/// Prompt assembly: what the model is actually shown.

///|
test "the system prompt carries the world, the persona, and the secret rule" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let prompt = build_system_prompt(scenario, card)
  assert_true(prompt.contains("林掌柜"))
  assert_true(prompt.contains("酒馆掌柜"))
  // The secret is present but gated, so a player must earn it.
  assert_true(prompt.contains("官文"))
  assert_true(prompt.contains("不要主动说出"))
  // The world background and the scene are both there.
  assert_true(prompt.contains("夜酒馆"))
  assert_true(prompt.contains("吧台"))
}

///|
test "an empty secret or voice omits its section instead of printing blanks" {
  let scenario = default_scenario()
  let bare = CharacterCard::new(
    id="x",
    name="某人",
    persona="他只是路过。",
  )
  let prompt = build_system_prompt(scenario, bare)
  assert_true(prompt.contains("某人"))
  assert_false(prompt.contains("【秘密】"))
  assert_false(prompt.contains("【说话方式】"))
}

///|
test "messages are ordered system, lore, then history oldest-first" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  conversation = conversation.append(ChatLine::player("你好"))
  conversation = conversation.append(ChatLine::character("lin", "嗯。"))
  let messages = build_messages(scenario, card, conversation, "温一壶酒")
  // System prompt first, lore second.
  assert_eq(messages[0].0, "system")
  assert_eq(messages[1].0, "system")
  assert_true(messages[1].1.contains("土酿"))
  // History after, in original order.
  assert_eq(messages[2], ("user", "你好"))
  assert_eq(messages[3], ("assistant", "嗯。"))
}

///|
test "history is trimmed from the oldest end when the budget is exceeded" {
  // A long history must not silently produce an over-budget request.
  let scenario = Scenario::new(id="t", name="t", background="b", characters=[
    CharacterCard::new(id="lin", name="林", persona="p"),
  ])
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  let mut index = 0
  while index < 200 {
    conversation = conversation.append(
      ChatLine::player(
        "第 \{index} 句，一句很长的话用来占满预算。",
      ),
    )
    index += 1
  }
  let messages = build_messages(scenario, card, conversation, "你好")
  let mut total = 0
  for message in messages {
    total += message.0.length() + message.1.length()
  }
  assert_true(total <= context_char_budget)
  // The newest lines survive; the oldest are the ones dropped.
  assert_true(messages[messages.length() - 1].1.contains("第 199 句"))
}

///|
test "the newest line survives even when the budget is already spent" {
  // The newest turn is the thing the model must answer. It is reserved before
  // the history walk, so an over-tight budget can drop older lines but never
  // the question itself.
  let scenario = Scenario::new(id="t", name="t", background="b", characters=[
    CharacterCard::new(id="lin", name="林", persona="p"),
  ])
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let conversation = Conversation::new(character_id="lin")
    .append(ChatLine::player("旧的一句"))
    .append(ChatLine::character("lin", "旧的回答"))
    .append(ChatLine::player("这一句必须留下"))
  // A budget far smaller than the system prompt alone.
  let plan = plan_messages(scenario, card, conversation, "你好", budget=1)
  assert_eq(
    plan.messages[plan.messages.length() - 1].1,
    "这一句必须留下",
  )
  // Everything older is handed to the compressor instead of vanishing.
  assert_eq(plan.evicted.length(), 2)
  assert_eq(plan.evicted[0].text(), "旧的一句")
}

///|
test "an unrelated turn adds no lore message" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let conversation = Conversation::new(character_id="lin")
  let messages = build_messages(scenario, card, conversation, "你好")
  // Only the system prompt: no lore block, no history.
  assert_eq(messages.length(), 1)
}

///|
test "the prompt summary reports message count, size, and lore hits" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let summary = prompt_summary(
    scenario,
    card,
    Conversation::new(character_id="lin"),
    "打二两酒",
  )
  assert_true(summary.contains("messages"))
  assert_true(summary.contains("lore hits"))
}

///|
test "history maps player turns to user and character turns to assistant" {
  let conversation = Conversation::new(character_id="lin")
    .append(ChatLine::player("我问"))
    .append(ChatLine::character("lin", "我答"))
  let wire = conversation.to_wire()
  assert_eq(wire.length(), 2)
  assert_eq(wire[0].0, "user")
  assert_eq(wire[1].0, "assistant")
}

///|
test "the v2 blocks assemble in card order and stay capped" {
  let scenario = default_scenario()
  // A card with every block filled, so the whole ordering chain is checkable.
  let card = CharacterCard::new(
    id="lin",
    name="林掌柜",
    persona="酒馆掌柜，话不多。",
    principles="先算账后说话。",
    voice="简短沉稳",
    examples=["嗯，酒烫好了。"],
    relationship={
      user_identity: "过路人",
      user_name: "客官",
      boundary: "不过问身世",
    },
    setting="夜雨，店里只剩一位客人。",
    goal="平安关店",
    secret="后堂藏着一坛老酒",
    memory_rules="答应过的事必须记得。",
  )
  let prompt = build_system_prompt(scenario, card)
  // ② principles before ③ voice before ③ examples before ④ relationship
  // before ⑤ setting before ⑥ memory rules before the scene line.
  let principles_at = find_substring(prompt, "【行为原则】")
  let voice_at = find_substring(prompt, "【说话方式】")
  let examples_at = find_substring(prompt, "【示例台词】")
  let relationship_at = find_substring(prompt, "【与用户的关系】")
  let setting_at = find_substring(prompt, "【当前情境】")
  let rules_at = find_substring(prompt, "【记忆规则】")
  let scene_at = find_substring(prompt, "【场景】")
  assert_true(principles_at is Some(_))
  assert_true(voice_at is Some(_))
  assert_true(examples_at is Some(_))
  assert_true(relationship_at is Some(_))
  assert_true(setting_at is Some(_))
  assert_true(rules_at is Some(_))
  assert_true(principles_at.unwrap_or(0) < voice_at.unwrap_or(0))
  assert_true(voice_at.unwrap_or(0) < examples_at.unwrap_or(0))
  assert_true(examples_at.unwrap_or(0) < relationship_at.unwrap_or(0))
  assert_true(relationship_at.unwrap_or(0) < setting_at.unwrap_or(0))
  assert_true(setting_at.unwrap_or(0) < rules_at.unwrap_or(0))
  assert_true(rules_at.unwrap_or(0) < scene_at.unwrap_or(0))
  // Example lines are labelled with the speaker.
  assert_true(prompt.contains("林掌柜：嗯，酒烫好了。"))
  // The world's default mood titles the scene line.
  assert_true(prompt.contains("官道旁的小酒馆"))
  assert_true(prompt.contains("夜深"))
}

///|
test "the mood override re-titles the scene line" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let dawn : SceneMood = { title: "官道晨光", time_label: "拂晓", variant: Calm }
  let prompt = build_system_prompt(scenario, card, mood=Some(dawn))
  assert_true(prompt.contains("官道晨光"))
  assert_true(prompt.contains("拂晓"))
  assert_false(prompt.contains("官道旁的小酒馆"))
}

///|
test "an empty card prints no blank v2 sections" {
  let scenario = Scenario::new(id="t", name="t", background="b")
  let bare = CharacterCard::new(id="x", name="某人", persona="路过。")
  let prompt = build_system_prompt(scenario, bare)
  assert_false(prompt.contains("【行为原则】"))
  assert_false(prompt.contains("【示例台词】"))
  assert_false(prompt.contains("【与用户的关系】"))
  assert_false(prompt.contains("【当前情境】"))
  assert_false(prompt.contains("【记忆规则】"))
}

///|
test "memories ride between the system prompt and the summary" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  conversation = conversation.with_summary("此前他们谈妥了赊账。", 3)
  let memories = [
    MemoryEntry::authored("他赊过一壶酒").with_pinned(true),
    MemoryEntry::authored("他说想看海"),
  ]
  // A line that hits no lore, so only system / memories / summary are sent.
  let messages = plan_messages(
    scenario,
    card,
    conversation,
    "今天风很大",
    memories~,
  ).messages
  // system prompt, memories, summary.
  assert_eq(messages.length(), 3)
  assert_true(messages[1].1.contains("【长久的记忆】"))
  assert_true(messages[1].1.contains("他赊过一壶酒"))
  assert_true(messages[1].1.contains("他说想看海"))
  // The summary comes after the memories.
  assert_true(messages[2].1.contains("【此前】"))
}

///|
test "select_memories feeds the injection: pinned always, hits by relevance" {
  let all = [
    MemoryEntry::authored("答应过教她御剑").with_pinned(true),
    MemoryEntry::authored("他赊过一壶酒"),
  ]
  let picked = select_memories(all, "还记着赊的那壶酒吗")
  assert_eq(picked.length(), 2)
  // Without a relevant line, only the pinned entry rides.
  assert_eq(select_memories(all, "今天天气不错").length(), 1)
}

///|
test "the opening lands as the first real message, once" {
  let model0 = opened_world_for_memory()
  // The fixture card has no opening yet — give it one through the editor.
  let opened = step(model0, Select(Some("林掌柜")))
  assert_eq(
    opened.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  // A card with an opening: its first line lands on first select…
  let scenario = default_scenario()
  let with_opening = CharacterCard::new(
    id="lin",
    name="林掌柜",
    persona="酒馆掌柜，话不多。",
    opening="（抬头看了你一眼）……坐吧。",
  )
  let world = Scenario::new(
    id="tavern",
    name=scenario.name(),
    background=scenario.background(),
    locations=scenario.locations(),
    characters=[with_opening],
    world_book=scenario.world_book(),
    mood=scenario.mood(),
  )
  let based = {
    ..opened_world_for_memory().fork(),
    scenario: world,
  }
  let selected = step(based, Select(Some("lin")))
  let lines = selected.conversations.for_character("lin").lines()
  assert_eq(lines.length(), 1)
  assert_true(lines[0].speaker() is Character(_))
  assert_eq(lines[0].text(), "（抬头看了你一眼）……坐吧。")
  // …and re-selecting does not duplicate it.
  let again = step(step(selected, Select(None)), Select(Some("lin")))
  assert_eq(again.conversations.for_character("lin").lines().length(), 1)
}

///|
test "the prompt preview shows what the model really receives" {
  // The preview is the send path's own assembly: the system prompt, the
  // memories, the history and the player's line.
  // The model carries the world; the preview reads it like the send path.
  let model = {
    ..step(WorldModel::new(), Select(Some("lin"))),
    scenario: default_scenario(),
  }
  let messages = prompt_preview_messages(model, "温一壶酒")
  assert_true(messages.length() >= 2)
  // The first message is the system prompt, with the persona in it.
  assert_eq(messages[0].0, "system")
  assert_true(messages[0].1.contains("林掌柜"))
  // The pending line is the last message: what 发送 would send.
  let last = messages[messages.length() - 1]
  assert_eq(last.0, "user")
  assert_true(last.1.contains("温一壶酒"))
  // The plain-text form carries the role labels, which is what the clipboard
  // receives.
  let text = prompt_preview_text(model, "温一壶酒")
  assert_true(text.contains("=== system ==="))
  assert_true(text.contains("林掌柜"))
  // The role labels are readable.
  assert_eq(prompt_role_label("system"), "系统 / 上下文")
  assert_eq(prompt_role_label("user"), "玩家")
  assert_eq(prompt_role_label("assistant"), "角色")
}

///|
test "a hidden memory never shows up in the prompt preview" {
  // The preview and the request share one assembly, so what the player hides
  // is invisible in both.
  let model = {
    ..step(WorldModel::new(), Select(Some("lin"))),
    scenario: default_scenario(),
  }
  let hidden = MemoryEntry::authored("她不让我提她娘").with_hidden(true)
  let with_hidden = {
    ..model,
    memories: {
      entries: [
        {
          character_id: "lin",
          entries: [hidden],
        },
      ],
    },
  }
  let messages = prompt_preview_messages(with_hidden, "她娘")
  for message in messages {
    assert_false(message.1.contains("她不让我提她娘"))
  }
}
