///|
/// Rolling memory compression, the context preset, and semi-automatic
/// long-term memory: the pure parts plus the update-loop behaviours.

///|
test "a rolling summary is injected ahead of lore and history" {
  let scenario = default_scenario()
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  conversation = conversation.append(ChatLine::player("聊过的旧事"))
  conversation = conversation.with_summary("此前他们谈妥了赊账。", 3)
  let messages = build_messages(scenario, card, conversation, "温一壶酒")
  assert_eq(messages[0].0, "system")
  assert_true(messages[1].1.contains("【此前】"))
  assert_true(messages[1].1.contains("谈妥了赊账"))
  // The world-book hit follows the summary, history last.
  assert_true(messages[2].1.contains("【相关背景】"))
  assert_eq(messages[3], ("user", "聊过的旧事"))
}

///|
test "the budget parameter drives eviction and the summary rides inside it" {
  let scenario = Scenario::new(id="t", name="t", background="b", characters=[
    CharacterCard::new(id="lin", name="林", persona="p"),
  ])
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  let mut index = 0
  while index < 12 {
    conversation = conversation.append(
      ChatLine::player(
        "第 \\{index} 句，一句相当长的话用来占满小小的预算。",
      ),
    )
    index += 1
  }
  let plan = plan_messages(scenario, card, conversation, "你好", budget=400)
  assert_true(plan.evicted.length() > 0)
  let mut total = 0
  for message in plan.messages {
    total += message.0.length() + message.1.length()
  }
  assert_true(total <= 400)
  // With the default Standard budget, nothing is evicted for 12 short lines.
  assert_true(
    plan_messages(scenario, card, conversation, "你好").evicted.length() == 0,
  )
}

///|
test "compression waits for pressure plus fresh material" {
  let scenario = Scenario::new(id="t", name="t", background="b", characters=[
    CharacterCard::new(id="lin", name="林", persona="p"),
  ])
  let card = scenario
    .character("lin")
    .unwrap_or(CharacterCard::new(id="", name="", persona=""))
  let mut conversation = Conversation::new(character_id="lin")
  let mut index = 0
  while index < 12 {
    conversation = conversation.append(
      ChatLine::player(
        "第 \\{index} 句，一句相当长的话用来占满小小的预算。",
      ),
    )
    index += 1
  }
  // Under budget pressure with 12 fresh lines: compress.
  let evicted = plan_messages(scenario, card, conversation, "", budget=400).evicted
  assert_true(needs_compression(conversation, evicted.length()))
  // No evictions and a short history: no compression.
  assert_false(needs_compression(conversation, 0))
  // Fresh material below the threshold waits, even under pressure.
  let mut few = Conversation::new(character_id="lin")
  few = few.append(ChatLine::player("a"))
  few = few.append(ChatLine::player("b"))
  assert_false(needs_compression(few, 3))
}

///|
test "the summary round-trips through the conversations.json codec" {
  let book = ConversationBook::new()
  book.set(
    Conversation::new(character_id="林掌柜")
    .append(ChatLine::player("温一壶酒"))
    .with_summary("他们谈妥了赊账。", 7),
  )
  let parsed = parse_conversations_json(book.to_json_text())
  assert_true(parsed.valid)
  assert_eq(parsed.conversations.length(), 1)
  assert_eq(parsed.conversations[0].summary(), "他们谈妥了赊账。")
  assert_eq(parsed.conversations[0].summarized_upto(), 1)
  // With no summary the field is simply absent.
  let bare = parse_conversations_json(ConversationBook::new().to_json_text())
  assert_true(bare.conversations.is_empty())
}

///|
test "the context preset picks the budget and tolerant decode keeps old fields" {
  let standard = ModelConfig::new()
  assert_eq(standard.context_budget(), 6000)
  assert_eq(standard.with_context_preset("roomy").context_budget(), 12000)
  assert_eq(standard.with_context_preset("compact").context_budget(), 3000)
  assert_eq(
    standard.with_context_preset("garbage").context_preset(),
    "standard",
  )
  // A pre-preset config.json must not lose the endpoint/model/key.
  let restored = ModelConfig::from_json(
    "{\"endpoint\":\"https://example.invalid/v1\",\"model\":\"glm-5.3-flash\",\"api_key\":\"sk-x\"}",
  )
  assert_eq(restored.endpoint(), "https://example.invalid/v1")
  assert_eq(restored.model(), "glm-5.3-flash")
  assert_eq(restored.api_key(), "sk-x")
  assert_eq(restored.context_preset(), "standard")
  // Round trip through the writer.
  let written = standard.with_context_preset("roomy").to_json()
  assert_eq(ModelConfig::from_json(written).context_budget(), 12000)
}
