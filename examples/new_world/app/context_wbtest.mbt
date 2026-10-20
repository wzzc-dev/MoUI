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
