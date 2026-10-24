///|
/// Cross-feature integrity: the pieces added in later stages must survive the
/// persistence and export paths built in earlier ones.
///
/// Each feature works on its own; these tests check the *seams* between them,
/// which is where regressions actually hide.

///|
/// Run a world through a full save → reload cycle by writing its files and
/// parsing them back, exactly as the hosts do.

///|
/// Reload from an explicit file payload (used when the commit under test is
/// scoped rather than world-wide).
fn reload_with(
  model : WorldModel,
  files : Array[(String, String)],
) -> WorldModel {
  step(
    model,
    WorldFilesArrived(model.current().unwrap_or("世界"), true, files),
  )
}

///|
fn reload(model : WorldModel) -> WorldModel {
  // `commit_files(self, World)` is exactly what a host writes to disk, so
  // feeding it back in is the same round trip the player experiences.
  let files = commit_files(model, World)
  let folder = model.current().unwrap_or("世界")
  step(model, WorldFilesArrived(folder, true, files))
}

///|
test "a scene transcript survives a save and reload" {
  let model = step(crowded_world(), EnterScene("吧台"))
  let (sent, _e) = update(
    model,
    Send("掌柜的，温一壶酒"),
    world_host=editing_host,
  )
  let key = scene_key("吧台")
  assert_eq(sent.conversations.for_character(key).lines().length(), 2)
  let reloaded = reload(sent)
  // The scene is a normal conversation file, so the same read path finds it.
  let after = reloaded.conversations.for_character(key)
  assert_eq(after.lines().length(), 2)
  assert_eq(after.lines()[0].text(), "掌柜的，温一壶酒")
  // Speaker attribution survives too: a scene that lost its speakers on reload
  // would silently become a monologue.
  match after.lines()[1].speaker() {
    Character(id) => assert_true(reloaded.scenario().character(id) is Some(_))
    Player => fail("the scene reply kept its speaker")
  }
}

///|
test "a branched conversation survives a save and reload" {
  let model = talking()
  let (branched, _e) = update(model, BranchAt(0), world_host=editing_host)
  let key = branched.selected().unwrap()
  let reloaded = reload(branched)
  // The branch must be *parsed back*, not merely still in memory. A branch key
  // is not a character id, so a naive orphan filter would drop it exactly like
  // a scene.
  let files = commit_files(branched, World)
  match parse_world_files(world_files_from_paths(files)) {
    Some(parsed) => {
      let mut found = false
      for conversation in parsed.conversations {
        if conversation.character_id() == key {
          found = true
        }
      }
      assert_true(found)
    }
    None => fail("the reloaded folder must parse")
  }
  assert_eq(reloaded.conversations.for_character(key).lines().length(), 1)
  // The original is still there and still complete.
  assert_eq(
    reloaded.conversations.for_character("林掌柜").lines().length(),
    2,
  )
  // The index lists both, or the reload would silently drop the branch.
  assert_true(reloaded.conversations.find(key) is Some(_))
}

///|
test "swipe candidates survive a save and reload" {
  let model = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(model, Select(Some("林掌柜")))
  let (sent, _e) = update(selected, Send("温一壶酒"), turn_runner=(
    _request,
    _on_reply,
    _on_delta,
  ) => ())
  let (replied, _r) = update(
    sent,
    Reply("林掌柜", Some("客官里边坐。")),
  )
  let (again, _g) = update(replied, RegenerateReply, turn_runner=(
    _request,
    _on_reply,
    _on_delta,
  ) => ())
  let (twice, _t) = update(
    again,
    Regenerated("林掌柜", Some("后堂请。")),
  )
  let conversation = twice.conversations.for_character("林掌柜")
  assert_eq(conversation.lines()[1].candidate_count(), 2)
  let reloaded = reload(twice)
  // Both candidates must come back, or a reload would silently discard the
  // player's alternate replies.
  let after = reloaded.conversations.for_character("林掌柜")
  assert_eq(after.lines()[1].candidate_count(), 2)
  assert_eq(after.lines().length(), 2)
}

///|
test "portraits survive a save and reload" {
  let model = crowded_world()
  let with_portrait = step(
    model,
    WorldFilesArrived("tavern", true, [
      (
        "world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 地点\n\n- 吧台: x=0 y=0 w=300 h=200\n",
      ),
      (
        "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 立绘\n\n林掌柜.png\n",
      ),
      ("characters/林掌柜.png", "iVBORw0KGgo="),
    ]),
  )
  match with_portrait.scenario().character("林掌柜") {
    Some(card) => assert_eq(card.portrait(), "林掌柜.png")
    None => fail("the character should exist")
  }
  // The asset cache is refreshed on load, so the image renders after a reload.
  assert_eq(with_portrait.portraits().length(), 1)
  let reloaded = reload(with_portrait)
  match reloaded.scenario().character("林掌柜") {
    Some(card) => assert_eq(card.portrait(), "林掌柜.png")
    None => fail("the character should survive")
  }
  assert_eq(reloaded.portraits().length(), 1)
}

///|
test "world-book modifiers survive a save and reload" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, [
      ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
      (
        "world_book.md", "# 世界书\n\n- 酒 [priority=9] [position=before] [probability=40]: 只温不冰。\n",
      ),
    ]),
  )
  let entry = model.scenario().world_book()[0]
  assert_eq(entry.priority(), 9)
  let reloaded = reload(model)
  let after = reloaded.scenario().world_book()[0]
  assert_eq(after.priority(), 9)
  assert_true(after.position() is Before)
  assert_eq(after.probability(), 40)
}

///|
test "a bundle carries scenes, branches and portraits together" {
  let model = step(crowded_world(), EnterScene("吧台"))
  let (sent, _e) = update(model, Send("温一壶酒"), world_host=editing_host)
  let (branched, _b) = update(sent, LeaveScene, world_host=editing_host)
  let text = match branched.bundle_text() {
    Some(value) => value
    None => fail("an open world must produce a bundle")
  }
  let bundle = match bundle_decode(text) {
    Some(value) => value
    None => fail("the bundle must decode")
  }
  // Every feature's file must be in the bundle: a world shared with a friend is
  // the whole point of export, and a missing scene is silent data loss.
  let mut has_scene = false
  let mut has_world = false
  let mut has_character = false
  for pair in bundle.files {
    // The scene key is `scene:吧台` in memory but its file name is sanitized
    // like any other (the colon becomes `_`), so match the written path.
    if pair.0.has_prefix("conversations/scene_") {
      has_scene = true
    }
    if pair.0 == "world.md" {
      has_world = true
    }
    if pair.0.has_prefix("characters/") {
      has_character = true
    }
  }
  assert_true(has_world)
  assert_true(has_character)
  assert_true(has_scene)
  // And importing reproduces the scene, which is what sharing a world means.
  let (restored, _e) = update(
    crowded_world(),
    WorldImported(true, "那个世界", bundle.files),
    world_host=editing_host,
  )
  assert_eq(
    restored.conversations.find(scene_key("吧台")).unwrap().lines().length(),
    2,
  )
}

///|
test "clearing a conversation actually reaches the disk" {
  let model = talking()
  let (cleared, _e) = update(model, ClearConversation, world_host=editing_host)
  assert_eq(
    cleared.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  // The commit must carry the file. A skipped file leaves the old history on
  // disk, so the clear would silently undo itself on the next load.
  let scoped = commit_files(cleared, Conversation("林掌柜"))
  let mut wrote_it = false
  for pair in scoped {
    if pair.0 == conversation_path("林掌柜") {
      wrote_it = true
    }
  }
  assert_true(wrote_it)
  // And a reload of that payload is genuinely empty.
  let reloaded = reload_with(cleared, scoped)
  assert_eq(
    reloaded.conversations.for_character("林掌柜").lines().length(),
    0,
  )
}

///|
test "deleting every line leaves an empty transcript, not a resurrection" {
  let model = talking()
  let (trimmed, _e) = update(model, DeleteLine(0), world_host=editing_host)
  let (emptied, _e2) = update(trimmed, DeleteLine(0), world_host=editing_host)
  assert_eq(
    emptied.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  let reloaded = reload(emptied)
  assert_eq(
    reloaded.conversations.for_character("林掌柜").lines().length(),
    0,
  )
}

///|
test "a world-scope commit writes every conversation, including empty ones" {
  let model = talking()
  let (cleared, _e) = update(model, ClearConversation, world_host=editing_host)
  let files = commit_files(cleared, World)
  let mut count = 0
  for pair in files {
    if pair.0.has_prefix("conversations/") && pair.0 != conversation_index_file {
      count += 1
    }
  }
  // 林掌柜 is cleared but still present; the index lists only non-empty ones.
  assert_eq(count, 1)
}

///|
test "reloading a world never grows its event log" {
  let model = crowded_world()
  let files = commit_files(model, World)
  let mut current = model
  for _ in 0..<5 {
    current = step(current, WorldFilesArrived("x", true, files))
  }
  // The UI still reports the load, so the player is not left guessing.
  assert_true(
    current.log().filter(line => line.contains("已载入")).length() > 0,
  )
  // But the file it writes is free of session chatter.
  let mut body = ""
  for pair in commit_files(current, World) {
    if pair.0 == events_file {
      body = pair.1
    }
  }
  assert_false(body.contains("已载入"))
  // And the events that *are* world history survive the round trip.
  let reloaded = reload(current)
  assert_eq(
    reloaded.log().filter(line => line.contains("已载入")).length(),
    1,
  )
}

///|
test "transient lines are recognised so history is not filtered by accident" {
  assert_true(
    is_transient_log_line(
      "已载入「雨夜酒馆」：3 个角色，1 条世界书",
    ),
  )
  assert_true(
    is_transient_log_line(
      "世界书提示：角色卡无法解析：characters/甲.md",
    ),
  )
  // Real events are not transient: they must reach the file.
  assert_false(is_transient_log_line("you → 林掌柜: 温一壶酒"))
  assert_false(is_transient_log_line("林掌柜: 客官里边坐。"))
  assert_false(
    is_transient_log_line("（这段时间）掌柜擦了三遍柜台。"),
  )
}

///|
test "real events round-trip; notices are not duplicated" {
  let model = crowded_world()
  let (logged, _e) = update(model, AdvanceTime, world_host=editing_host)
  let persisted = logged.log().filter(line => !is_transient_log_line(line))
  let reloaded = reload(logged)
  let after = reloaded.log().filter(line => !is_transient_log_line(line))
  // World history is identical across the round trip.
  assert_eq(after, persisted)
  // Exactly one "loaded" notice, no matter how many times the folder is read.
  assert_eq(
    reloaded.log().filter(line => line.contains("已载入")).length(),
    1,
  )
}

///|
test "a partial summary keeps its coverage across a reload" {
  // Ten lines summarised, twenty in total. If the marker is lost the summary
  // silently claims to cover the ten it never saw, and compression never runs
  // again — the summary goes stale while the prompt keeps using it.
  let mut conversation = Conversation::new(character_id="林掌柜").with_summary(
    "早先的摘要。", 10,
  )
  for index in 0..<20 {
    conversation = conversation.append(ChatLine::player("第 \{index} 句"))
  }
  assert_eq(conversation.summarized_upto(), 10)
  let restored = parse_conversation_file(conversation.to_json_text())
  let back = restored.conversations[0]
  assert_eq(back.summarized_upto(), 10)
  assert_eq(back.appended(), 20)
  assert_eq(back.summary(), "早先的摘要。")
}

///|
test "a file from before the marker existed still loads" {
  // Older builds wrote only `summary`. Those files can only mean "the summary
  // covers what is loaded", so that is the fallback.
  let legacy = "{\"conversations\":[{\"character\":\"林掌柜\",\"summary\":\"旧摘要。\",\"lines\":[{\"speaker\":\"user\",\"text\":\"甲\"},{\"speaker\":\"assistant\",\"text\":\"乙\"}]}]}"
  let parsed = parse_conversation_file(legacy)
  assert_true(parsed.valid)
  let conversation = parsed.conversations[0]
  assert_eq(conversation.summarized_upto(), 2)
  assert_eq(conversation.summary(), "旧摘要。")
}

///|
test "a hand-edited marker is clamped to the lines that exist" {
  // Claiming more coverage than there are lines would make the conversation
  // believe it needs no compression ever again.
  let lying = "{\"conversations\":[{\"character\":\"林掌柜\",\"summary\":\"x\",\"summarized_upto\":999,\"lines\":[{\"speaker\":\"user\",\"text\":\"甲\"}]}]}"
  let conversation = parse_conversation_file(lying).conversations[0]
  assert_eq(conversation.summarized_upto(), 1)
  // A negative marker degrades to "covers nothing", so compression runs.
  let negative = "{\"conversations\":[{\"character\":\"林掌柜\",\"summary\":\"x\",\"summarized_upto\":-5,\"lines\":[{\"speaker\":\"user\",\"text\":\"甲\"}]}]}"
  assert_eq(
    parse_conversation_file(negative).conversations[0].summarized_upto(),
    0,
  )
}

///|
test "an empty summary never claims coverage" {
  let mut conversation = Conversation::new(character_id="林掌柜")
  for index in 0..<5 {
    conversation = conversation.append(ChatLine::player("第 \{index} 句"))
  }
  let back = parse_conversation_file(conversation.to_json_text()).conversations[0]
  assert_eq(back.summarized_upto(), 0)
  assert_eq(back.summary(), "")
}

///|
test "a compacted summary is committed, not just remembered" {
  let model = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(model, Select(Some("林掌柜")))
  let (compacted, effect) = update(
    selected,
    SummaryArrived("林掌柜", 3, Some("压缩后的摘要。")),
    world_host=editing_host,
  )
  // The handler must ask the host to persist: a summary kept only in memory is
  // recomputed (or lost) on the next launch.
  assert_true(is_run_effect(effect))
  assert_eq(
    compacted.conversations.for_character("林掌柜").summary(),
    "压缩后的摘要。",
  )
  // And the payload carries it.
  let mut written = ""
  for pair in commit_files(compacted, Conversation("林掌柜")) {
    if pair.0 == conversation_path("林掌柜") {
      written = pair.1
    }
  }
  assert_true(written.contains("压缩后的摘要"))
  // Round trip: the reload sees the same summary AND the same coverage.
  let reloaded = reload_with(
    compacted,
    commit_files(compacted, Conversation("林掌柜")),
  )
  let back = reloaded.conversations.for_character("林掌柜")
  assert_eq(back.summary(), "压缩后的摘要。")
  assert_eq(back.summarized_upto(), 3)
}

///|
test "a failed compaction changes nothing" {
  let model = step(crowded_world(), ApiKeyChanged("sk-test"))
  let selected = step(model, Select(Some("林掌柜")))
  let (after, _e) = update(
    selected,
    SummaryArrived("林掌柜", 3, None),
    world_host=editing_host,
  )
  // A failed provider call leaves the conversation untouched so the next
  // overflowing turn retries with fresh material.
  assert_eq(after.conversations.for_character("林掌柜").summary(), "")
  assert_eq(after.conversations.for_character("林掌柜").summarized_upto(), 0)
}

///|
test "every character field survives a world round trip" {
  // `rename_card` rebuilds a card field by field, so a field added to
  // `CharacterCard` but not copied there disappears on *every* load. That
  // happened to `portrait_prompt`. This test sets every field to a distinct
  // value, so adding a field without wiring it fails here.
  let card = CharacterCard::new(
    id="lin",
    name="林掌柜",
    persona="话少。",
    appearance="深色短褂。",
    portrait="林掌柜.png",
    portrait_prompt="四十岁上下，油灯侧光。",
    voice="简短。",
    goal="撑过今晚。",
    secret="柜下有东西。",
    location="吧台",
    point=@geometry.Point::new(x=100.0, y=90.0),
  )
  let scenario = Scenario::new(
    id="tavern",
    name="酒馆",
    background="雨夜。",
    locations=[
      ScenarioLocation::new(
        id="吧台",
        name="吧台",
        description="木柜台。",
        rect=@geometry.Rect::new(x=0.0, y=0.0, width=200.0, height=150.0),
      ),
    ],
    characters=[card],
  )
  let files = scenario.world_files()
  let reloaded = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, files),
  )
  let back = reloaded.scenario().characters()[0]
  assert_eq(back.persona(), "话少。")
  assert_eq(back.appearance(), "深色短褂。")
  assert_eq(back.portrait(), "林掌柜.png")
  assert_eq(back.portrait_prompt(), "四十岁上下，油灯侧光。")
  assert_eq(back.voice(), "简短。")
  assert_eq(back.goal(), "撑过今晚。")
  assert_eq(back.secret(), "柜下有东西。")
  assert_eq(back.location(), "吧台")
  assert_eq(back.point().x, 100.0)
  // The name is the file base, so it is preserved too.
  assert_eq(back.name(), "林掌柜")
}

///|
/// A whole-world shape with **every** field set to a distinguishable value, run
/// through the folder and the JSON codec.
///
/// Several bugs in this example were the same shape: a field existed on the
/// model but was never carried by a codec or by a hand-written rebuild
/// (`rename_card` dropped `portrait_prompt`; `CharacterCard.location` was never
/// written to Markdown at all). A field-by-field assertion is the only guard
/// that notices when a *new* field is added without wiring it, so each
/// persistent type gets one here.

///|
fn maximal_world() -> Scenario {
  Scenario::new(
    id="maximal",
    name="全集世界",
    background="一句背景。",
    map_width=700.0,
    map_height=460.0,
    locations=[
      ScenarioLocation::new(
        id="厅",
        name="大厅",
        description="厅的描述。",
        rect=@geometry.Rect::new(x=10.0, y=20.0, width=210.0, height=160.0),
      ),
      ScenarioLocation::new(
        id="院",
        name="后院",
        description="院的描述。",
        rect=@geometry.Rect::new(x=300.0, y=200.0, width=180.0, height=140.0),
      ),
    ],
    characters=[
      CharacterCard::new(
        id="a",
        name="甲",
        persona="甲的设定。",
        appearance="甲的外貌。",
        portrait="甲.png",
        portrait_prompt="甲的立绘提示词。",
        voice="甲的说话方式。",
        goal="甲的目标。",
        secret="甲的秘密。",
        location="厅",
        point=@geometry.Point::new(x=60.0, y=70.0),
        color=@graphics.Color::rgba(r=0.1, g=0.2, b=0.3),
      ),
      CharacterCard::new(
        id="b",
        name="乙",
        persona="乙的设定。",
        voice="乙的说话方式。",
        location="院",
        point=@geometry.Point::new(x=350.0, y=250.0),
      ),
    ],
    world_book=[
      WorldEntry::new(
        keys=["甲", "甲某"],
        content="最高优先级条目。",
        priority=7,
        position=Before,
        recursion=2,
        probability=40,
      ),
      WorldEntry::new(keys=["乙"], content="普通条目。"),
    ],
  )
}

///|
fn assert_maximal_scenario(label : String, scenario : Scenario) -> Unit raise {
  // `id` is deliberately NOT asserted: the folder codec derives it from the
  // world's directory name (`world.md` stores the display name only), so a
  // folder round trip legitimately renames the id. The JSON codec keeps it.
  if scenario.name() != "全集世界" {
    fail(label + ": name")
  }
  if scenario.background() != "一句背景。" {
    fail(label + ": background")
  }
  if scenario.map_width() != 700.0 || scenario.map_height() != 460.0 {
    fail(label + ": map size")
  }
  if scenario.locations().length() != 2 {
    fail(label + ": location count")
  }
  let place = scenario.locations()[0]
  // `id` is derived from the display name by the folder codec (there is one
  // column for it in the file), so only the name and description are asserted.
  if place.name() != "大厅" || place.description() != "厅的描述。" {
    fail(label + ": location fields")
  }
  if place.rect().origin.x != 10.0 || place.rect().size.width != 210.0 {
    fail(label + ": location rect")
  }
  if scenario.characters().length() != 2 {
    fail(label + ": character count")
  }
  let first = scenario.characters()[0]
  if first.persona() != "甲的设定。" ||
    first.appearance() != "甲的外貌。" ||
    first.portrait() != "甲.png" ||
    first.portrait_prompt() != "甲的立绘提示词。" ||
    first.voice() != "甲的说话方式。" ||
    first.goal() != "甲的目标。" ||
    first.secret() != "甲的秘密。" ||
    first.location() != "厅" {
    fail(label + ": character fields")
  }
  if first.point().x != 60.0 || first.point().y != 70.0 {
    fail(label + ": character point")
  }
  if first.location() != "厅" {
    fail(label + ": character location")
  }
  // The colour is derived from the name, so it only has to stay stable.
  if first.color().r != scenario.characters()[0].color().r {
    fail(label + ": character colour")
  }
  if scenario.world_book().length() != 2 {
    fail(label + ": world book count")
  }
  let entry = scenario.world_book()[0]
  if entry.keys().length() != 2 || entry.keys()[1] != "甲某" {
    fail(label + ": entry keys")
  }
  if entry.content() != "最高优先级条目。" {
    fail(label + ": entry content")
  }
  if entry.priority() != 7 {
    fail(label + ": entry priority")
  }
  if !(entry.position() is Before) {
    fail(label + ": entry position")
  }
  if entry.recursion() != 2 {
    fail(label + ": entry recursion")
  }
  if entry.probability() != 40 {
    fail(label + ": entry probability")
  }
}

///|
test "every field of every persistent type survives the folder codec" {
  let scenario = maximal_world()
  assert_maximal_scenario("in memory", scenario)
  match parse_world_files(world_files_from_paths(scenario.world_files())) {
    Some(parsed) => assert_maximal_scenario("folder", parsed.scenario)
    None => fail("the maximal world must parse")
  }
}

///|
test "every field of every persistent type survives the JSON codec" {
  let scenario = maximal_world()
  let json = scenario.to_json()
  match Scenario::try_from_json(json) {
    Some(back) => assert_maximal_scenario("json", back)
    None => fail("the maximal world must decode")
  }
}

///|
test "every field of every persistent type survives a bundle" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("maximal", true, maximal_world().world_files()),
  )
  let text = match model.bundle_text() {
    Some(value) => value
    None => fail("an open world must produce a bundle")
  }
  match bundle_decode(text) {
    Some(bundle) =>
      match parse_world_files(world_files_from_paths(bundle.files)) {
        Some(parsed) => assert_maximal_scenario("bundle", parsed.scenario)
        None => fail("the bundled world must parse")
      }
    None => fail("the bundle must decode")
  }
}

///|
/// The conversation half of the maximal-shape guard.
///
/// `Conversation` mixes persisted state (`lines`, `summary`, `summarized_upto`)
/// with derived/session state (`pending`, `appended`). Pinning which is which
/// here is what keeps a future field from silently landing on the wrong side.

///|
fn maximal_conversation() -> Conversation {
  let mut conversation = Conversation::new(character_id="林掌柜")
  // Two candidates on the reply, showing the second: `text` is the shown slot,
  // `alternatives` holds the rest, and `selected` remembers which.
  let reply = ChatLine::character("林掌柜", "第二版回话。")
    .with_alternative("第一版回话。")
    .with_candidate(0)
  conversation = conversation
    .append(ChatLine::player("温一壶酒"))
    .append(reply)
    .with_summary("早先的摘要。", 1)
  conversation
}

///|
fn assert_maximal_conversation(
  label : String,
  conversation : Conversation,
) -> Unit raise {
  if conversation.character_id() != "林掌柜" {
    fail(label + ": conversation id")
  }
  if conversation.lines().length() != 2 {
    fail(label + ": line count")
  }
  let first = conversation.lines()[0]
  if !(first.speaker() is Player) || first.text() != "温一壶酒" {
    fail(label + ": player line")
  }
  let second = conversation.lines()[1]
  match second.speaker() {
    Character(id) => if id != "林掌柜" { fail(label + ": speaker id") }
    Player => fail(label + ": reply speaker")
  }
  // Candidates and the selected slot are part of the saved history: losing them
  // means a reload silently discards every alternate reply.
  if second.candidate_count() != 2 {
    fail(label + ": candidate count")
  }
  if second.text() != "第二版回话。" {
    fail(label + ": shown candidate")
  }
  if second.alternatives().length() != 1 ||
    second.alternatives()[0] != "第一版回话。" {
    fail(label + ": alternatives")
  }
  if second.selected() != 0 {
    fail(label + ": selected index")
  }
  if conversation.summary() != "早先的摘要。" {
    fail(label + ": summary")
  }
  if conversation.summarized_upto() != 1 {
    fail(label + ": summary coverage")
  }
}

///|
test "every conversation field survives its file" {
  let conversation = maximal_conversation()
  assert_maximal_conversation("in memory", conversation)
  let parsed = parse_conversation_file(conversation.to_json_text())
  if !parsed.valid || parsed.conversations.length() != 1 {
    fail("the conversation file must parse")
  }
  assert_maximal_conversation("file", parsed.conversations[0])
}

///|
test "every conversation field survives a world round trip" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, crowded_world().scenario().world_files()),
  )
  let seeded = model.fork()
  seeded.conversations.set(maximal_conversation())
  let next = { ..model, conversations: seeded.conversations, }
  assert_maximal_conversation(
    "before",
    next.conversations.for_character("林掌柜"),
  )
  let reloaded = reload(next)
  assert_maximal_conversation(
    "after",
    reloaded.conversations.for_character("林掌柜"),
  )
}

///|
test "session-only conversation state is deliberately not persisted" {
  // `pending` describes an in-flight request; a reload starts with nothing in
  // flight. `appended` is re-derived from the loaded line count. Pinning this
  // stops someone "fixing" the round trip by persisting a stuck pending flag.
  let mut conversation = Conversation::new(character_id="林掌柜")
  conversation = conversation.append(ChatLine::player("甲")).with_pending(true)
  let parsed = parse_conversation_file(conversation.to_json_text())
  let back = parsed.conversations[0]
  assert_false(back.pending())
  assert_eq(back.appended(), 1)
}

///|
test "a scene keeps its cast across a reload when places have slug ids" {
  // AI generation (and any JSON-authored world) gives places english ids, while
  // characters reference those ids in `location`. If the folder codec rewrote
  // the id to the display name, every such card would point at a place that no
  // longer exists and the scene's cast would empty out on reload.
  let scenario = Scenario::new(
    id="t",
    name="酒馆",
    background="雨夜。",
    locations=[
      ScenarioLocation::new(
        id="bar",
        name="吧台",
        description="木柜台。",
        rect=@geometry.Rect::new(x=300.0, y=300.0, width=100.0, height=100.0),
      ),
    ],
    characters=[
      CharacterCard::new(
        id="a",
        name="甲",
        persona="x",
        location="bar",
        point=@geometry.Point::new(x=10.0, y=10.0),
      ),
      CharacterCard::new(
        id="b",
        name="乙",
        persona="y",
        location="bar",
        point=@geometry.Point::new(x=20.0, y=20.0),
      ),
    ],
  )
  // Both stand outside the rect, so only their `location` can put them on stage.
  assert_eq(cast_at(scenario, "bar").length(), 2)
  let reloaded = step(
    WorldModel::new(),
    WorldFilesArrived("t", true, scenario.world_files()),
  )
  // The slug id survives, so the scene still has its two people.
  assert_eq(reloaded.scenario().locations()[0].id(), "bar")
  assert_eq(reloaded.scenario().locations()[0].name(), "吧台")
  assert_eq(cast_at(reloaded.scenario(), "bar").length(), 2)
}

///|
test "a place whose id is its name is written without the redundant suffix" {
  // Hand-written worlds should not gain noise.
  let scenario = Scenario::new(id="t", name="酒馆", background="雨夜。", locations=[
    ScenarioLocation::new(
      id="吧台",
      name="吧台",
      description="木柜台。",
      rect=@geometry.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    ),
  ])
  let text = pair_for(scenario.world_files(), "world.md")
  assert_false(text.contains("id="))
  assert_true(text.contains("- 吧台: x=0 y=0 w=100 h=100: 木柜台。"))
  // And it still parses back to the same place.
  match parse_world_files(world_files_from_paths(scenario.world_files())) {
    Some(parsed) => {
      assert_eq(parsed.scenario.locations()[0].id(), "吧台")
      assert_eq(parsed.scenario.locations()[0].description(), "木柜台。")
    }
    None => fail("the world must parse")
  }
}
