///|
/// Lorebook rules: parsing the modifiers, and the selection engine.

///|
fn lore_entry(
  keys : Array[String],
  content : String,
  priority? : Int32,
  position? : LorePosition,
  recursion? : Int32,
  probability? : Int32,
) -> WorldEntry {
  WorldEntry::new(
    keys~,
    content~,
    priority?,
    position?,
    recursion?,
    probability?,
  )
}

///|
test "modifiers parse from a world-book line, in any order" {
  let entry = parse_world_book_line(
    "- 酒 | 花雕 [priority=10] [position=before] [recursion=2] [probability=60]: 后堂老酒。",
  ).unwrap()
  assert_eq(entry.keys(), ["酒", "花雕"])
  assert_eq(entry.content(), "后堂老酒。")
  assert_eq(entry.priority(), 10)
  assert_true(entry.position() is Before)
  assert_eq(entry.recursion(), 2)
  assert_eq(entry.probability(), 60)
  // Order-independent and case-insensitive.
  let reordered = parse_world_book_line(
    "- 酒 [PROBABILITY=30] [Priority=3]: 老酒。",
  ).unwrap()
  assert_eq(reordered.probability(), 30)
  assert_eq(reordered.priority(), 3)
  // The plain form keeps every default.
  let plain = parse_world_book_line("- 酒: 老酒。").unwrap()
  assert_eq(plain.priority(), 0)
  assert_true(plain.position() is After)
  assert_eq(plain.recursion(), 0)
  assert_eq(plain.probability(), 100)
}

///|
test "bad or unknown modifiers never cost the player their entry" {
  // Out-of-range values clamp instead of rejecting the line.
  let clamped = parse_world_book_line(
    "- 酒 [probability=999] [priority=-5] [recursion=-1]: 老酒。",
  ).unwrap()
  assert_eq(clamped.probability(), 100)
  assert_eq(clamped.priority(), 0)
  assert_eq(clamped.recursion(), 0)
  // An unknown modifier is ignored; the keys survive.
  let unknown = parse_world_book_line("- 酒 [colour=red]: 老酒。").unwrap()
  assert_eq(unknown.keys(), ["酒"])
  assert_eq(unknown.content(), "老酒。")
  // A non-numeric value falls back rather than failing the parse.
  let garbage = parse_world_book_line("- 酒 [priority=high]: 老酒。").unwrap()
  assert_eq(garbage.priority(), 0)
  // An unterminated bracket is literal text, not a swallowed line.
  let unterminated = parse_world_book_line("- 酒 [priority=3: 老酒。")
  assert_true(unterminated is Some(_))
}

///|
test "only non-default modifiers are written back" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "普通条目。"),
    lore_entry(["花雕"], "重要条目。", priority=5, position=Before),
    lore_entry(["雨"], "偶发条目。", probability=40),
  ])
  // Round-trip through the public folder writer: that is the shape the player
  // sees on disk.
  let text = pair_for(scenario.world_files(), "world_book.md")
  // The ordinary entry keeps its historical one-line shape.
  assert_true(text.contains("- 酒: 普通条目。"))
  assert_true(text.contains("[priority=5]"))
  assert_true(text.contains("[position=before]"))
  assert_true(text.contains("[probability=40]"))
  // And the whole thing round-trips through the parser.
  let parsed : Array[WorldEntry] = []
  for line in text.split("\n").to_array() {
    match parse_world_book_line(line.to_owned()) {
      Some(entry) => parsed.push(entry)
      None => ()
    }
  }
  assert_eq(parsed.length(), 3)
  assert_eq(parsed[1].priority(), 5)
  assert_eq(parsed[2].probability(), 40)
}

///|
test "priority orders the injected block" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "低优先级。", priority=1),
    lore_entry(["酒"], "高优先级。", priority=9),
    lore_entry(["酒"], "中优先级。", priority=5),
  ])
  let hits = select_lore(scenario, "温一壶酒", "", 0)
  let block = lore_block_at(hits, After)
  let lines = block.split("\n").to_array()
  assert_eq(lines[0], "- 高优先级。")
  assert_eq(lines[1], "- 中优先级。")
  assert_eq(lines[2], "- 低优先级。")
}

///|
test "position splits world rules from scene facts" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "这是世界规则。", position=Before),
    lore_entry(["酒"], "这是场景事实。", position=After),
  ])
  let hits = select_lore(scenario, "酒", "", 0)
  let before = lore_block_at(hits, Before)
  let after = lore_block_at(hits, After)
  assert_true(before.contains("世界规则"))
  assert_false(before.contains("场景事实"))
  assert_true(after.contains("场景事实"))
  assert_false(after.contains("世界规则"))
}

///|
test "recursion chains one trigger into the next" {
  // 酒 → 花雕 → 女儿红: each entry's *content* triggers the next.
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "店里有一种花雕。", recursion=2),
    lore_entry(["花雕"], "花雕其实就是女儿红。", recursion=1),
    lore_entry(["女儿红"], "女儿红埋了三十年。"),
  ])
  // Recursion walks the whole chain from one player mention.
  let chained = select_lore(scenario, "来点酒", "", 0)
  assert_eq(chained.length(), 3)
  // Chain depth is recorded, so the UI/log can explain the chain.
  let depths : Array[Int32] = []
  for hit in chained {
    depths.push(hit.depth)
  }
  assert_true(depths.contains(0))
  assert_true(depths.contains(1))
  assert_true(depths.contains(2))
  // Without recursion on the first entry the chain stops.
  let no_chain = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "店里有一种花雕。"),
    lore_entry(["花雕"], "花雕就是女儿红。"),
    lore_entry(["女儿红"], "埋了三十年。"),
  ])
  assert_eq(select_lore(no_chain, "来点酒", "", 0).length(), 1)
}

///|
test "recursion is capped so a hand-edited file cannot loop" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒"], "循环 酒。", recursion=99),
    lore_entry(["循环"], "又一个 酒。", recursion=99),
  ])
  // The cap keeps this finite; it must terminate and stay small.
  let hits = select_lore(scenario, "酒", "", 0)
  assert_true(hits.length() <= 2)
  assert_true(lore_recursion_cap <= 8)
}

///|
test "probability is deterministic per turn, not per call" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["雨"], "下雨了。", probability=50),
  ])
  let entry = scenario.world_book()[0]
  // Same turn => same answer, every time. This is what makes a retry
  // reproducible instead of rerolling the world.
  let first = lore_passes_probability(entry, 7)
  for _ in 0..<5 {
    assert_eq(lore_passes_probability(entry, 7), first)
  }
  // Across many turns both outcomes occur, so 50% is not silently 0 or 100.
  let mut on = 0
  let mut turn = 0
  while turn < 200 {
    if lore_passes_probability(entry, turn) {
      on += 1
    }
    turn += 1
  }
  assert_true(on > 60 && on < 140)
  // 100 always fires, 0 never does.
  let always = lore_entry(["雨"], "x", probability=100)
  let never = lore_entry(["雨"], "x", probability=0)
  assert_true(lore_passes_probability(always, 1))
  assert_false(lore_passes_probability(never, 1))
}

///|
test "the prompt places before-entries ahead of the persona" {
  let scenario = Scenario::new(
    id="s",
    name="s",
    background="雨夜。",
    characters=[
      CharacterCard::new(id="lin", name="掌柜", persona="话少。"),
    ],
    world_book=[
      lore_entry(["酒"], "规矩：只温不冰。", position=Before),
      lore_entry(["酒"], "场景：后堂有老酒。"),
    ],
  )
  let card = scenario.character("lin").unwrap()
  let conversation = Conversation::new(character_id="lin").append(
    ChatLine::player("温一壶酒"),
  )
  let plan = plan_messages(scenario, card, conversation, "温一壶酒")
  // The world rule is the first system message, ahead of the persona.
  assert_eq(plan.messages[0].0, "system")
  assert_true(plan.messages[0].1.contains("世界规则"))
  assert_true(plan.messages[0].1.contains("只温不冰"))
  // The persona prompt still follows it.
  assert_true(plan.messages[1].1.contains("你是掌柜"))
  // The scene fact sits after the summary and before the history.
  let mut scene_at = -1
  for index, message in plan.messages {
    if message.1.contains("场景：后堂有老酒") {
      scene_at = index
    }
  }
  assert_true(scene_at > 1)
}

///|
test "the lore summary names what fired" {
  let scenario = Scenario::new(id="s", name="s", background="b", world_book=[
    lore_entry(["酒", "花雕"], "老酒。"),
  ])
  let hits = select_lore(scenario, "有花雕吗", "", 0)
  let summary = lore_summary(hits)
  assert_true(summary.contains("酒"))
  assert_true(summary.contains("花雕"))
  // The size is reported too, not just the names.
  assert_true(summary.contains("1 条"))
  assert_true(summary.contains("3 字"))
  assert_eq(lore_summary([]), "")
}

///|
test "a world file with modifiers survives a full folder round trip" {
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    (
      "world_book.md",
      "# 世界书\n\n" +
      "- 酒: 普通条目。\n" +
      "- 花雕 [priority=8] [position=before]: 只温不冰。\n" +
      "- 雨 [probability=25] [recursion=1]: 雨天无人。\n",
    ),
  ]
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let book = parsed.scenario.world_book()
      assert_eq(book.length(), 3)
      assert_eq(book[0].priority(), 0)
      assert_eq(book[1].priority(), 8)
      assert_true(book[1].position() is Before)
      assert_eq(book[2].probability(), 25)
      assert_eq(book[2].recursion(), 1)
      // Write it back and confirm the file still says the same thing.
      let rewritten = pair_for(parsed.scenario.world_files(), "world_book.md")
      assert_true(rewritten.contains("[priority=8]"))
      assert_true(rewritten.contains("[position=before]"))
      assert_true(rewritten.contains("[probability=25]"))
      assert_true(rewritten.contains("[recursion=1]"))
      // The plain entry gained no noise.
      assert_true(rewritten.contains("- 酒: 普通条目。"))
    }
    None => fail("the folder must parse")
  }
}

///|
test "an entry with probability 0 never reaches the prompt" {
  let scenario = Scenario::new(
    id="s",
    name="s",
    background="b",
    characters=[
      CharacterCard::new(id="lin", name="掌柜", persona="话少。"),
    ],
    world_book=[
      lore_entry(["酒"], "这条永远不该出现。", probability=0),
    ],
  )
  let card = scenario.character("lin").unwrap()
  let conversation = Conversation::new(character_id="lin").append(
    ChatLine::player("温一壶酒"),
  )
  let plan = plan_messages(scenario, card, conversation, "温一壶酒")
  for message in plan.messages {
    assert_false(message.1.contains("永远不该出现"))
  }
}

///|
test "intents frame the wire; the journal keeps the marked player line" {
  // Say is the default and leaves the text alone.
  assert_eq(frame_player_text("温一壶酒", Say), "温一壶酒")
  // Do marks the line as an action and tells the model not to answer it as
  // dialogue.
  let acted = frame_player_text("推开门", Do)
  assert_true(acted.contains("推开门"))
  assert_true(acted.contains("动作"))
  assert_true(acted.contains("不要当成对白"))
  // Story marks narration and asks the model to continue it.
  let narrated = frame_player_text("雨下了一夜", Story)
  assert_true(narrated.contains("旁白"))
  assert_true(narrated.contains("接着往下写"))
  // The stored line carries the canonical marker (what the transcript shows and
  // what the journal keeps); the wire framing is a separate concern.
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  let selected = step(model, Select(Some("林掌柜")))
  // The collapsed composer writes into the active intent's field, so an
  // action is typed after switching the mode to 做.
  let acting = step(
    step(selected, ComposerModeChanged(Do)),
    DoDraftChanged("推开门"),
  )
  let (sent, _e) = update(acting, SendComposer, world_host={
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (_folder, _files, _done) => (),
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  })
  assert_eq(
    sent.conversations.for_character("林掌柜").lines()[0].text(),
    "（动作）推开门",
  )
}

///|
test "the composer fields start empty and the intent labels stay stable" {
  let model = WorldModel::new()
  assert_eq(model.say_draft(), "")
  assert_eq(model.do_draft(), "")
  assert_eq(model.story_draft(), "")
  // Labels are what the composer rows show.
  assert_eq(Say.label(), "说")
  assert_eq(Do.label(), "做")
  assert_eq(Story.label(), "旁白")
}

///|
test "a Do turn sends the framed action on the wire" {
  let captured : Array[String] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    // Capture the wire text: the assertion is about what the model is sent.
    let wire : Array[String] = []
    for message in request.messages() {
      wire.push(message.0 + ":" + message.1)
    }
    captured.push(wire.join("\n"))
  }
  let keyed = step(
    step(WorldModel::new(), WorldFilesArrived("tavern", true, tavern_files())),
    ApiKeyChanged("sk-test"),
  )
  let selected = step(keyed, Select(Some("林掌柜")))
  // The action goes through the 做 intent: the mode switcher first, then the
  // field.
  let acting = step(
    step(selected, ComposerModeChanged(Do)),
    DoDraftChanged("推开门"),
  )
  let (_sent, effect) = update(acting, SendComposer, turn_runner=runner)
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(captured.length(), 1)
  assert_true(captured[0].contains("user:"))
  assert_true(captured[0].contains("动作"))
  assert_true(captured[0].contains("推开门"))
  // Only one copy of the player's line: framing must replace, not append.
  let mut copies = 0
  let mut rest = captured[0]
  while rest.find("推开门") is Some(at) {
    copies += 1
    rest = rest[at + 3:].to_owned()
  }
  assert_eq(copies, 1)
}
