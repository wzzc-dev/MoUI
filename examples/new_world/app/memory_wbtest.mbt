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

///|
test "the memory book stores, replaces, and clears per character" {
  let book = MemoryBook::new()
  // An unseen character reads as an empty record.
  assert_eq(book.for_character("温衍").entries().length(), 0)
  book.set({
    character_id: "温衍",
    entries: [MemoryEntry::authored("他赊过一壶酒")],
  })
  book.set({
    character_id: "温衍",
    entries: [
      MemoryEntry::authored("他赊过一壶酒"),
      MemoryEntry::proposed("答应过教她御剑"),
    ],
  })
  // The second set replaces the record for the same id, not appends.
  assert_eq(book.entries.length(), 1)
  assert_eq(book.for_character("温衍").entries().length(), 2)
  book.set({
    character_id: "狸奴",
    entries: [MemoryEntry::authored("怕打雷")],
  })
  assert_eq(book.entries.length(), 2)
  book.clear()
  assert_eq(book.entries.length(), 0)
}

///|
test "select_memories always keeps pinned entries and fills the rest by hit" {
  let all = [
    MemoryEntry::authored("他说想看海").with_pinned(true),
    MemoryEntry::authored("徒弟怕打雷，那夜靠我很近"),
    MemoryEntry::authored("御剑课上她摔了下来"),
    MemoryEntry::authored("他赊过一壶酒，说发工钱就还"),
    MemoryEntry::authored("无关的琐事"),
    MemoryEntry::authored("另一条无关的话"),
    MemoryEntry::authored("第三条无关的话"),
  ]
  // Pinned rides even with an empty player line.
  let none = select_memories(all, "")
  assert_eq(none.length(), 1)
  assert_true(none[0].pinned())
  // A keyword hit pulls exactly one unpinned entry on top of the pinned one.
  let one = select_memories(all, "还记着御剑那课吗")
  assert_eq(one.length(), 2)
  assert_true(one[0].pinned())
  assert_true(one[1].content().contains("御剑"))
  // The limit caps unpinned hits; pinned entries never count against it.
  let capped = select_memories(all, "打雷 御剑 赊酒 海", limit=2)
  assert_eq(capped.length(), 3)
}

///|
test "the memory Markdown round-trips pins and provenance" {
  let entries = [
    MemoryEntry::authored("他赊过一壶酒"),
    MemoryEntry::proposed("答应过教她御剑").with_pinned(true),
  ]
  let text = memory_md_text(entries)
  assert_true(text.contains("- 他赊过一壶酒\n"))
  assert_true(text.contains("- [固定] [来源:AI] 答应过教她御剑\n"))
  let restored = parse_memory_md(text)
  assert_eq(restored.length(), 2)
  assert_false(restored[0].pinned())
  assert_true(restored[0].source() is Authored)
  assert_true(restored[1].pinned())
  assert_true(restored[1].source() is Adopted)
  assert_eq(restored[1].content(), "答应过教她御剑")
  // Tolerance: comments, blank lines, and stray text are not entries.
  let tolerant = parse_memory_md(
    "# 记忆\n\n<!-- 一行一条 -->\n\n- 正事\n随便一行\n\n- [固定] 要紧的事\n",
  )
  assert_eq(tolerant.length(), 2)
  assert_eq(tolerant[0].content(), "正事")
  assert_eq(tolerant[1].content(), "要紧的事")
  assert_true(tolerant[1].pinned())
  // An empty body is a valid empty list.
  assert_eq(parse_memory_md("").length(), 0)
  assert_eq(parse_memory_md("# 记忆\n").length(), 0)
}

///|
test "the memory file path sits beside the card it belongs to" {
  assert_eq(memory_path("温衍"), "characters/温衍.memory.md")
  // The same sanitising rule the cards use, so a hostile id cannot escape.
  assert_eq(memory_path("../x"), "characters/_.._x.memory.md")
}

///|
test "a conversation mood round-trips through the journal codec" {
  let mood : SceneMood = {
    title: "清虚洞府",
    time_label: "夜深",
    variant: Cold,
  }
  let book = ConversationBook::new()
  book.set(
    Conversation::new(character_id="温衍", mood~).append(
      ChatLine::player("师父睡了么"),
    ),
  )
  let parsed = parse_conversations_json(book.to_json_text())
  assert_true(parsed.valid)
  match parsed.conversations[0].mood() {
    Some(loaded) => {
      assert_eq(loaded.title(), "清虚洞府")
      assert_eq(loaded.time_label(), "夜深")
      assert_true(loaded.variant() is Cold)
    }
    None => fail("the mood must round-trip")
  }
  // Without a mood the field is simply absent, and the world default applies.
  let bare = ConversationBook::new()
  bare.set(
    Conversation::new(character_id="温衍").append(ChatLine::player("在吗")),
  )
  let plain = parse_conversations_json(bare.to_json_text())
  assert_true(plain.conversations[0].mood() is None)
}

///|
test "the appearance field decodes per-field and snaps bad values" {
  let config = ModelConfig::new()
  assert_eq(config.appearance(), "paper")
  assert_eq(config.with_appearance("ink").appearance(), "ink")
  assert_eq(config.with_appearance("nonsense").appearance(), "paper")
  // A pre-appearance config.json keeps every other field.
  let restored = ModelConfig::from_json(
    "{\"endpoint\":\"https://example.invalid/v1\",\"model\":\"m\",\"api_key\":\"k\"}",
  )
  assert_eq(restored.endpoint(), "https://example.invalid/v1")
  assert_eq(restored.appearance(), "paper")
  // And the writer carries it.
  assert_true(
    ModelConfig::new().with_appearance("ink").to_json().contains("ink"),
  )
}

///|
/// A world with one character, opened through the real parser — the fixture
/// the memory CRUD tests talk to.
fn opened_world_for_memory() -> WorldModel {
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
  ]
  step(WorldModel::new(), WorldFilesArrived("tavern", true, files))
}

///|
test "the memory drawer's CRUD lands in the book and persists" {
  let model = step(opened_world_for_memory(), Select(Some("林掌柜")))
  // Add: the input becomes an authored entry and the input clears.
  let typed = step(
    model,
    MemoryDraftChanged("他赊过一壶酒，说发工钱就还"),
  )
  let (added, _commit) = update(typed, AddMemory)
  let entries = added.memories.for_character("林掌柜").entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].content(), "他赊过一壶酒，说发工钱就还")
  assert_true(entries[0].source() is Authored)
  assert_false(entries[0].pinned())
  assert_eq(added.memory_input(), "")
  // Pin: the entry always rides in the prompt from now on.
  let pinned = step(added, ToggleMemoryPin(0))
  assert_true(pinned.memories.for_character("林掌柜").entries()[0].pinned())
  // Unpin again.
  let unpinned = step(pinned, ToggleMemoryPin(0))
  assert_false(
    unpinned.memories.for_character("林掌柜").entries()[0].pinned(),
  )
  // Delete: the entry is gone.
  let deleted = step(unpinned, DeleteMemory(0))
  assert_eq(deleted.memories.for_character("林掌柜").entries().length(), 0)
  // An empty line is refused with a hint, not stored.
  let blank = step(deleted, MemoryDraftChanged("   "))
  let (refused, _e) = update(blank, AddMemory)
  assert_eq(refused.memories.for_character("林掌柜").entries().length(), 0)
  assert_true(refused.log()[0].contains("先写下"))
  // With no character on stage, add is inert but explains itself.
  let (inert, _e2) = update(opened_world_for_memory(), AddMemory)
  assert_true(inert.log()[0].contains("先在舞台"))
}

///|
test "memory edits never write through the model they were given" {
  let model = step(opened_world_for_memory(), Select(Some("林掌柜")))
  let typed = step(model, MemoryDraftChanged("一条要紧的事"))
  let added = step(typed, AddMemory)
  // The model the caller still holds is untouched by the add.
  assert_eq(model.memories.for_character("林掌柜").entries().length(), 0)
  assert_eq(added.memories.for_character("林掌柜").entries().length(), 1)
  // And a clone is independent: editing the copy does not move the original.
  let copied = added.memories.clone()
  copied.set({ character_id: "林掌柜", entries: [], })
  assert_eq(added.memories.for_character("林掌柜").entries().length(), 1)
}

///|
test "a memory can be kept out of the prompt" {
  // The player writes it for themselves; the model never reads it. The entry
  // stays in the file and in the drawer.
  let entries = parse_memory_md(
    "- 狸奴怕打雷\n- [不进上下文] 她不让我提她娘\n",
  )
  assert_eq(entries.length(), 2)
  assert_false(entries[0].hidden())
  assert_true(entries[1].hidden())
  assert_eq(entries[1].content(), "她不让我提她娘")
  // A hidden entry is never injected, not even when it is pinned.
  let pinned = entries[1].with_pinned(true)
  let picked = select_memories([pinned], "她娘")
  assert_eq(picked.length(), 0)
  // A visible one still is.
  let visible = select_memories([entries[0]], "打雷")
  assert_eq(visible.length(), 1)
}

///|
test "a progression topic keeps only the newest state" {
  // The same fact changes: the character must answer as the world is now.
  let entries = parse_memory_md(
    "- [进展:住处] 住在城南的旧宅\n" +
    "- [进展:住处] 搬去了城北的院子\n" +
    "- [进展:伤势] 左臂有旧伤\n" +
    "- 她叫狸奴\n",
  )
  assert_eq(entries.length(), 4)
  assert_eq(entries[0].topic(), "住处")
  assert_eq(entries[1].topic(), "住处")
  // The latest of each topic is the current one.
  let current = latest_per_topic(entries)
  assert_eq(current.length(), 2)
  assert_eq(current[0].content(), "搬去了城北的院子")
  assert_eq(current[1].content(), "左臂有旧伤")
  // Only the current state of a topic rides in the prompt; the plain memory
  // is unaffected.
  let picked = select_memories(entries, "院子")
  let texts : Array[String] = []
  for entry in picked {
    texts.push(entry.content())
  }
  assert_true(texts.contains("搬去了城北的院子"))
  assert_false(texts.contains("住在城南的旧宅"))
}

///|
test "the memory markers survive a round trip through the file" {
  let entries = [
    MemoryEntry::authored("住在城南的旧宅").with_topic("住处"),
    MemoryEntry::proposed("她不让我提她娘").with_hidden(true),
  ]
  let text = memory_md_text(entries)
  let parsed = parse_memory_md(text)
  assert_eq(parsed.length(), 2)
  assert_eq(parsed[0].topic(), "住处")
  assert_eq(parsed[0].content(), "住在城南的旧宅")
  assert_true(parsed[1].hidden())
  assert_eq(parsed[1].content(), "她不让我提她娘")
}
