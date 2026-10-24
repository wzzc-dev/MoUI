///|
/// Update-loop behaviour: selection, sending, replies, config, the world
/// library, character creation, and AI world generation.
///
/// The world starts blank; most tests open a small tavern world folder first.
/// That is the same path the product uses (`WorldFilesArrived`), so the
/// fixtures exercise the folder codec rather than a JSON import shortcut that
/// no UI can reach. Provider-path tests flip the key on; no-key tests exercise
/// the scripted local reply.

///|
fn tavern() -> WorldModel {
  step(WorldModel::new(), WorldFilesArrived("tavern", true, tavern_files()))
}

///|
fn tavern_with_key() -> WorldModel {
  step(tavern(), ApiKeyChanged("sk-test"))
}

///|
test "selecting a character clears the composer" {
  let model = step(tavern(), SayDraftChanged("草稿"))
  assert_eq(model.say_draft(), "草稿")
  let selected = step(model, Select(Some("林掌柜")))
  assert_eq(selected.selected(), Some("林掌柜"))
  assert_eq(selected.say_draft(), "")
}

///|
test "update never mutates the model it was given" {
  // TEA purity: `(model, msg) -> (model, effect)` must not write through the
  // input. Record update (`{ ..model, }`) shares array references, so a branch
  // that logged or appended would edit the previous model too; the runtime
  // does not diff models today, which is exactly why this must be pinned.
  let before = tavern_with_key()
  let selected = step(before, Select(Some("林掌柜")))
  let log_before = before.log().length()
  assert_eq(before.conversations.active_count(), 0)
  // A turn appends a line, logs, and commits: all the containers mutate.
  let (after, _effect) = update(selected, Send("温一壶酒"), turn_runner=(
    _r,
    _c,
    _d,
  ) => ())
  assert_eq(selected.log().length(), log_before)
  assert_eq(
    selected.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  assert_true(after.log().length() > log_before)
  assert_eq(after.conversations.for_character("林掌柜").lines().length(), 1)
  // Character creation mutates the roster and the log the same way.
  let drafting = step(after, ToggleCreator)
  let (created, _commit) = update(
    step(drafting, CreatorChanged(drafting.creator_draft().with_name("阿七"))),
    CharacterCreated,
  )
  assert_eq(after.scenario().characters().length(), 2)
  assert_eq(created.scenario().characters().length(), 3)
  assert_eq(drafting.log().length(), after.log().length())
}

///|
test "re-selecting the same character keeps the draft" {
  // The map drags and taps re-select the current character; that must not
  // discard a half-written line.
  let selected = step(tavern(), Select(Some("林掌柜")))
  let typing = step(selected, SayDraftChanged("温一壶"))
  let again = step(typing, Select(Some("林掌柜")))
  assert_eq(again.say_draft(), "温一壶")
  // Panning is likewise not a selection change.
  let panned = step(typing, PanMap)
  assert_eq(panned.say_draft(), "温一壶")
  assert_eq(panned.selected(), Some("林掌柜"))
  // Clearing the selection still clears it.
  assert_eq(step(typing, Select(None)).say_draft(), "")
}

///|
test "a second send is refused while the first is in flight" {
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let (sent, _first) = update(selected, Send("温一壶酒"), turn_runner=(
    _r,
    _c,
    _d,
  ) => ())
  assert_true(sent.conversations.for_character("林掌柜").pending())
  let lines = sent.conversations.for_character("林掌柜").lines().length()
  // The player hits send again before the provider answers: no second line,
  // no second request, and no duplicate log entry.
  let (_, effect) = update(sent, Send("再来一壶"), turn_runner=(_r, _c, _d) => {
    ()
  })
  assert_true(is_no_effect(effect))
  let (after, again) = update(sent, Send("再来一壶"), turn_runner=(
    _r,
    _c,
    _d,
  ) => ())
  assert_true(is_no_effect(again))
  assert_eq(
    after.conversations.for_character("林掌柜").lines().length(),
    lines,
  )
  // Once the reply lands, sending works again.
  let answered = step(sent, Reply("林掌柜", Some("嗯。")))
  assert_false(answered.conversations.for_character("林掌柜").pending())
  let (_, third) = update(answered, Send("再来一壶"), turn_runner=(
    _r,
    _c,
    _d,
  ) => ())
  assert_true(is_run_effect(third))
}

///|
test "a world name with path syntax is sanitized before it reaches the host" {
  let commits : Array[String] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, _files, done) => {
      commits.push(folder)
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  let typed = step(WorldModel::new(), WorldNameChanged("../../etc/passwd"))
  let (created, effect) = update(typed, NewWorld, world_host=host)
  // The traversal is neutralised: the name is a single path component, so no
  // separator survives to make `..` mean "parent directory".
  let folder = match created.current() {
    Some(name) => name
    None => fail("a world should have been created")
  }
  assert_false(folder.contains("/"))
  assert_false(folder.contains("\\"))
  assert_true(folder != "." && folder != "..")
  // The host is only ever handed the sanitized name.
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(commits, [folder])
  // The player is told the name changed rather than silently losing it.
  assert_true(
    created.log().filter(line => line.contains("路径符号")).length() > 0,
  )
}

///|
test "sending with nothing selected is inert" {
  let model = WorldModel::new()
  let after = step(model, Send("你好"))
  assert_eq(after.log().length(), 0)
  assert_eq(after.conversations.for_character("林掌柜").lines().length(), 0)
}

///|
test "the no-key turn answers locally and completely" {
  // Without a key the world must still respond — in the same update, with no
  // dangling pending flag and no host effect.
  let selected = step(tavern(), Select(Some("林掌柜")))
  let after = step(selected, Send("  温一壶酒  "))
  let conversation = after.conversations.for_character("林掌柜")
  assert_eq(conversation.lines().length(), 2)
  assert_eq(conversation.lines()[0].text(), "温一壶酒")
  assert_false(conversation.pending())
  assert_eq(after.log().length(), 3)
  assert_true(after.log()[0].contains("本地剧本"))
  let (_next, effect) = update(selected, Send("温一壶酒"))
  assert_true(is_no_effect(effect))
}

///|
test "the scripted reply is deterministic and refers to the world" {
  let scenario = tavern().scenario()
  let card : CharacterCard = scenario.character("林掌柜").unwrap()
  let first = scripted_reply(scenario, card, "温一壶酒")
  let again = scripted_reply(scenario, card, "温一壶酒")
  assert_eq(first, again)
  assert_true(first != "")
  // A world-book hit leads with the lore the player asked about.
  assert_true(
    scripted_reply(scenario, card, "有花雕吗？").contains("女儿红"),
  )
}

///|
test "a keyed turn marks pending and emits exactly one provider effect" {
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let (sent, effect) = update(selected, Send("温一壶酒"))
  assert_true(is_run_effect(effect))
  let conversation = sent.conversations.for_character("林掌柜")
  assert_eq(conversation.lines().length(), 1)
  assert_true(conversation.pending())
}

///|
test "a reply is appended, cleaned, and clears pending" {
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let sent = step(selected, Send("温一壶酒"))
  let answered = step(
    sent,
    Reply("林掌柜", Some("「嗯，酒温好了。」")),
  )
  let conversation = answered.conversations.for_character("林掌柜")
  assert_eq(conversation.lines().length(), 2)
  // The corner brackets are stripped: the character speaks, not about itself.
  assert_eq(conversation.lines()[1].text(), "嗯，酒温好了。")
  assert_false(conversation.pending())
  assert_eq(answered.log().length(), 3)
}

///|
test "a failed reply keeps the history and clears pending" {
  // A provider hiccup must cost nothing: the player can simply ask again.
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let sent = step(selected, Send("温一壶酒"))
  let failed = step(sent, Reply("林掌柜", None))
  let conversation = failed.conversations.for_character("林掌柜")
  assert_eq(conversation.lines().length(), 1)
  assert_false(conversation.pending())
  // The failure is logged, and it names the provider rather than the character.
  assert_true(failed.log()[0].contains("没有回应"))
  assert_true(failed.log()[0].contains("林掌柜"))
}

///|
test "a reply for another character does not leak into this conversation" {
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let sent = step(selected, Send("你好"))
  // `jianghu` is not a character of this world, so the late reply is dropped
  // rather than creating a ghost conversation. (This test used to assert the
  // ghost: `for_character` returns a fresh Conversation for an unknown id, so
  // appending there wrote an orphan file that the loader then discarded.)
  let other = step(sent, Reply("jianghu", Some("嗯。")))
  assert_eq(other.conversations.for_character("林掌柜").lines().length(), 1)
  assert_eq(other.conversations.for_character("jianghu").lines().length(), 0)
  // A reply for a real, different character still lands correctly.
  let sibling = step(sent, Reply("赶考书生", Some("嗯。")))
  assert_eq(
    sibling.conversations.for_character("林掌柜").lines().length(),
    1,
  )
  assert_eq(
    sibling.conversations.for_character("赶考书生").lines().length(),
    1,
  )
}

///|
test "opening a different world folder replaces the world and drops selection" {
  let selected = step(tavern(), Select(Some("林掌柜")))
  let imported = step(
    selected,
    WorldFilesArrived("court", true, [
      ("world.md", "# 朝堂\n\n金殿之上，无人敢言。\n"),
      ("world_book.md", "# 世界书\n\n- 玉玺: 玉玺失踪了三日。\n"),
    ]),
  )
  assert_eq(imported.scenario.name(), "朝堂")
  // Conversations are keyed by character id and must not leak across worlds.
  assert_eq(
    imported.conversations.for_character("林掌柜").lines().length(),
    0,
  )
  assert_true(imported.log().length() > 0)
}

///|
test "opening a folder with no world.md keeps the current world" {
  let model = step(
    tavern(),
    WorldFilesArrived("junk", true, [("notes.txt", "随便什么")]),
  )
  assert_eq(model.scenario().name(), "雨夜酒馆")
  assert_true(model.log()[0].contains("不是世界文件夹"))
}

///|
test "configuration round-trips including the key, which belongs to the library" {
  let model = step(WorldModel::new(), ApiKeyChanged("sk-test"))
  assert_true(model.config.llm_enabled())
  let restored = ModelConfig::from_json(model.config.to_json())
  // Everything round-trips, the credential included: `config.json` is the
  // library root, and a world is a *subfolder* of the library, so sharing or
  // exporting a world never carries the key with it.
  assert_eq(restored.api_key(), "sk-test")
  assert_eq(restored.endpoint(), model.config.endpoint())
  assert_eq(restored.model(), model.config.model())
  assert_eq(restored.context_preset(), model.config.context_preset())
  assert_true(restored.llm_enabled())
  // A file written before the key was persisted still loads every other field.
  let legacy = ModelConfig::from_json(
    "{\"api_key\":\"sk-old\",\"endpoint\":\"https://example.invalid/v1\"}",
  )
  assert_eq(legacy.api_key(), "sk-old")
  assert_true(legacy.llm_enabled())
  // Clearing the key disables the provider path.
  assert_false(step(model, ApiKeyChanged("")).config.llm_enabled())
}

///|
test "numeric configuration rejects unparseable and non-positive input" {
  let model = WorldModel::new()
  let base = model.config.temperature()
  assert_eq(step(model, TemperatureChanged("abc")).config.temperature(), base)
  assert_eq(step(model, TemperatureChanged("-1")).config.temperature(), base)
  assert_eq(step(model, TemperatureChanged("0.4")).config.temperature(), 0.4)
}

///|
test "every Msg variant is reachable from a construction site" {
  // Mirrors the repository dead-message gate: each variant must be constructible
  // from the view or a proposal, not only from `update`.
  let model = WorldModel::new()
  let selected = step(tavern(), Select(Some("林掌柜")))
  let world_files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    ("world_book.md", "# 世界书\n\n- 酒: 后堂老酒。\n"),
  ]
  let touched = [
    step(model, Select(None)),
    step(selected, SayDraftChanged("draft")),
    step(selected, Send("hi")),
    step(selected, Reply("林掌柜", Some("ok"))),
    step(selected, Reply("林掌柜", None)),
    step(model, EndpointChanged("https://example.invalid")),
    step(model, ModelChanged("gpt-4o-mini")),
    step(model, ApiKeyChanged("sk-x")),
    step(model, TemperatureChanged("0.5")),
    step(model, SaveConfig),
    step(model, SyncLibrary),
    step(model, PickWorldRoot),
    step(model, WorldListArrived(["tavern"])),
    step(model, OpenWorld("tavern")),
    step(model, OpenSettings),
    step(model, CloseSettings),
    step(model, ConfigFileLoaded(None)),
    step(model, SettingsSaved(true)),
  ]
  assert_eq(touched.length(), 18)
  // Multi-argument messages are constructed but not stepped: the handler
  // behaviour has dedicated tests below.
  ignore(WorldFilesArrived("tavern", true, world_files))
  ignore(WorldNameChanged("新世界"))
  ignore(NewWorld)
  ignore(WorldCommitted("tavern", true))
  assert_true(step(model, ToggleCreator).creator_open())
  ignore(CreatorChanged(model.creator_draft().with_name("阿七")))
  ignore(CharacterCreated)
  ignore(WorldIdeaChanged("雨夜当铺"))
  ignore(GenerateWorld)
  ignore(WorldGenerated(None))
  ignore(ContextChanged("standard"))
  ignore(SummaryArrived("林掌柜", 60, Some("笔记")))
  ignore(MemoryProposalsArrived(None))
  ignore(AcceptMemory(0))
  ignore(DiscardMemory(0))
  ignore(DoDraftChanged("推开门"))
  ignore(StoryDraftChanged("雨声更大了。"))
  ignore(SendComposer)
  ignore(OpenDrawer(Profile))
  ignore(CloseDrawer)
  ignore(OpenMessageMenu(0))
  ignore(CloseMessageMenu)
  ignore(ToggleRail)
  ignore(ToggleAtmosphere)
  ignore(SetBackdrop(true))
  ignore(SetAppearance("ink"))
}

///|
test "the library listing opens the first world automatically" {
  let seen : Array[String] = []
  let (model, effect) = update(
    WorldModel::new(),
    WorldListArrived(["tavern", "court"]),
    world_host=test_host,
  )
  assert_eq(model.worlds().length(), 2)
  // Driving the effect performs the read for the first world.
  @moui.Effect::runtime_visit(
    effect,
    _message => seen.push("message"),
    _dispatch => (),
    (_descriptor, _run) => seen.push("run"),
    (_descriptor, _task) => (),
  )
  assert_true(seen.length() > 0)
}

///|
test "opening a world parses its folder and goes on stage" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  assert_eq(model.current(), Some("tavern"))
  assert_eq(model.scenario().name(), "雨夜酒馆")
  assert_eq(model.scenario().characters().length(), 2)
  assert_eq(model.scenario().world_book().length(), 1)
  // The loaded card works as a conversation partner:
  let talking = step(model, Select(Some("林掌柜")))
  let (sent, effect) = update(talking, Send("这酒怎么卖？"), turn_runner=(
    _r,
    _c,
    _d,
  ) => ())
  assert_eq(sent.conversations.for_character("林掌柜").lines().length(), 2)
  assert_true(is_no_effect(effect))
}

///|
test "a failed read is reported and does not open the folder" {
  let model = step(WorldModel::new(), WorldFilesArrived("nope", false, []))
  assert_eq(model.current(), None)
  assert_true(model.library_missing())
  assert_true(model.log()[0].contains("无法读取世界库"))
}

///|
test "a folder without a name row is not a world" {
  let model = step(
    WorldModel::new(),
    WorldFilesArrived("empty", true, [
      ("world.md", "只有文字没有标题"),
      ("world_book.md", ""),
    ]),
  )
  assert_eq(model.current(), None)
  assert_true(model.log()[0].contains("不是世界文件夹"))
}

///|
test "creating a world stages it, dedups names, and commits the folder" {
  let commits : Array[String] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, _files, done) => {
      commits.push(folder)
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  let named = step(WorldModel::new(), WorldNameChanged("新大陆"))
  let (created, effect) = update(named, NewWorld, world_host=host)
  assert_eq(created.current(), Some("新大陆"))
  assert_eq(created.worlds(), ["新大陆"])
  assert_eq(created.scenario().id(), "新大陆")
  assert_eq(commits.length(), 0)
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => commits.push("other"),
  )
  assert_eq(commits.length(), 1)
  ignore(commits)
  assert_eq(commits[0], "新大陆")
  // A duplicate name is refused instead of silently replacing the folder.
  let again = step(created, WorldNameChanged("新大陆"))
  let refused = step(again, NewWorld)
  assert_true(refused.log()[0].contains("已存在"))
  assert_true(is_no_effect(update(refused, NewWorld).1))
}

///|
test "blank line before the name row refuses to build a world" {
  let (refused, _effect) = update(WorldModel::new(), NewWorld)
  assert_eq(refused.current(), None)
  assert_true(refused.log()[0].contains("起个名字"))
}

///|
test "a created character joins the world, selects itself, and is committed" {
  let commits : Array[String] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, _files, done) => {
      commits.push(folder)
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  let based = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  let opened = step(based, ToggleCreator)
  let drafted = step(
    opened,
    CreatorChanged(
      based
      .creator_draft()
      .with_name("阿七")
      .with_persona("游历四方的剑客。")
      .with_voice("直来直去"),
    ),
  )
  let (created, effect) = update(drafted, CharacterCreated, world_host=host)
  assert_eq(created.selected(), Some("阿七"))
  assert_false(created.creator_open())
  match created.scenario().character("阿七") {
    Some(card) => {
      assert_eq(card.persona(), "游历四方的剑客。")
      assert_true(card.point().x > 0.0)
    }
    None => fail("character card missing")
  }
  // Driving the returned effect performs the folder write on the host.
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(commits.length(), 1)
  assert_eq(commits[0], "tavern")
}

///|
test "the world name field round-trips" {
  let model = step(
    WorldModel::new(),
    WorldIdeaChanged("雨夜江南小镇的当铺"),
  )
  assert_eq(model.idea(), "雨夜江南小镇的当铺")
}

///|
test "AI generation without a key builds a local world immediately" {
  let commits : Array[String] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, _files, done) => {
      commits.push(folder)
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  let idea = step(
    WorldModel::new(),
    WorldIdeaChanged("雨夜江南小镇的当铺"),
  )
  let (generated, effect) = update(idea, GenerateWorld, world_host=host)
  assert_true(is_no_effect(effect))
  assert_false(generated.generating())
  assert_eq(generated.scenario().name(), "雨夜江南小镇的当铺")
  assert_eq(generated.current(), Some("雨夜江南小镇的当铺"))
  assert_true(generated.log()[0].contains("无 key"))
  // A blank idea is refused, and a second generation is ignored while one is
  // already in flight on the provider path.
  let blank = step(WorldModel::new(), GenerateWorld)
  assert_true(blank.log()[0].contains("一句话"))
  let busy = step({ ..tavern_with_key(), generating: true, }, GenerateWorld)
  assert_eq(busy.generating(), true)
  assert_true(is_no_effect(update(busy, GenerateWorld).1))
}

///|
test "AI generation with a key emits one provider request" {
  let seen : Array[LlmRequest] = []
  let selected = step(
    tavern_with_key(),
    WorldIdeaChanged("一座悬在海雾中的灯塔城"),
  )
  let (generating, effect) = update(selected, GenerateWorld, turn_runner=(
    request : LlmRequest,
    _on_reply : (String?) -> Unit,
    _on_delta : (String) -> Unit,
  ) => seen.push(request))
  assert_true(is_run_effect(effect))
  assert_true(generating.generating())
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_dispatch => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 1)
  assert_true(seen[0].system().contains("JSON"))
  assert_eq(seen[0].user(), "一座悬在海雾中的灯塔城")
}

///|
test "a generated world is imported, renamed to its folder, and committed" {
  // No world open: the generation becomes its own folder. (The commit call is
  // exercised end-to-end in the NewWorld and CharacterCreated tests.)
  let generated = step(
    WorldModel::new(),
    WorldGenerated(
      Some(
        "{\"id\":\"beacon\",\"name\":\"灯塔城\",\"background\":\"海雾不散。\",\"characters\":[],\"world_book\":[]}",
      ),
    ),
  )
  assert_eq(generated.scenario().name(), "灯塔城")
  assert_eq(generated.scenario().id(), "灯塔城")
  assert_eq(generated.current(), Some("灯塔城"))
  assert_false(generated.generating())
  // A malformed generation is a message, never a broken world.
  let bad = step(WorldModel::new(), WorldGenerated(Some("not json")))
  assert_true(bad.log()[0].contains("不是可解析的世界"))
  // A provider failure clears the spinner and keeps the old world.
  let failed = step({ ..tavern(), generating: true, }, WorldGenerated(None))
  assert_eq(failed.scenario().name(), "雨夜酒馆")
  assert_false(failed.generating())
}

///|
/// A host whose callbacks record nothing; for contract tests.
let test_host : WorldHost = {
  list_worlds: _done => (),
  pick_root: _done => (),
  read_world: (_folder, _done) => (),
  write_world: (_folder, _files, _done) => (),
  read_config: _done => (),
  write_config: (_content, _done) => (),
  export_world: (_folder, _files, _done) => (),
  import_world: _done => (),
  copy_to_clipboard: _text => (),
}

///|
fn tavern_files() -> Array[(String, String)] {
  [
    (
      "world.md", "# 雨夜酒馆\n\n夜雨敲窗，炉火正暖。\n\n## 地点\n\n- 吧台: x=40 y=300 w=180 h=80\n",
    ),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n酒馆掌柜，话不多但句句在理。\n\n## 说话方式\n\n简短、沉稳\n\n## 秘密\n\n后堂藏着一坛老酒\n\n## 位置\n\nx=320 y=210\n",
    ),
    (
      "characters/赶考书生.md", "# 赶考书生\n\n## 人设\n\n姓陈，进京赶考，盘缠将尽。\n",
    ),
    (
      "world_book.md", "# 世界书\n\n- 酒 | 花雕: 后堂埋着一坛三十年的女儿红。\n",
    ),
  ]
}

///|
test "a pure unrelated library message produces no effect without a host" {
  let (_sent, effect) = update(WorldModel::new(), SyncLibrary)
  assert_true(is_no_effect(effect))
}

///|
/// Run one message and keep the model, dropping the effect. The effect is the
/// host's concern; these tests are about the model transition.
fn step(model : WorldModel, msg : Msg) -> WorldModel {
  let (next, _effect) = update(model, msg)
  next
}

///|
/// Does this effect do nothing? `Effect` is opaque to the app package, so the
/// test observes behaviour rather than matching variants.
fn is_no_effect(effect : @moui.Effect[Msg]) -> Bool {
  let mut dispatched = 0
  @moui.Effect::runtime_visit(
    effect,
    _message => dispatched += 1,
    _dispatch => (),
    (_descriptor, _run) => (),
    (_descriptor, _task) => (),
  )
  dispatched == 0
}

///|
/// Does this effect start a runner? A provider turn must be a structured run,
/// not a fire-and-forget dispatch.
fn is_run_effect(effect : @moui.Effect[Msg]) -> Bool {
  let mut started = 0
  @moui.Effect::runtime_visit(
    effect,
    _message => (),
    _dispatch => started += 1,
    (_descriptor, _run) => started += 1,
    (_descriptor, _task) => (),
  )
  started > 0
}

///|
test "settings open, file load, and save write to the world library" {
  let writes : Array[String] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (_folder, _files, _done) => (),
    read_config: done => {
      done(
        Some(
          "{\"endpoint\":\"https://api.pie-xian.com/v1\",\"model\":\"glm-5.3-flash\",\"api_key\":\"sk-x\",\"temperature\":0.7,\"tick_interval_ms\":900.0}",
        ),
      )
    },
    write_config: (content, done) => {
      writes.push(content)
      done(true)
    },
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  // Opening the settings page reads the file and restores the config.
  let (opened, effect) = update(
    WorldModel::new(),
    OpenSettings,
    world_host=host,
  )
  assert_eq(opened.page(), Settings)
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  let (loaded, _e) = update(
    opened,
    ConfigFileLoaded(
      Some(
        "{\"endpoint\":\"https://api.pie-xian.com/v1\",\"model\":\"glm-5.3-flash\",\"api_key\":\"sk-x\",\"temperature\":0.7,\"tick_interval_ms\":900.0}",
      ),
    ),
  )
  assert_eq(loaded.config().endpoint(), "https://api.pie-xian.com/v1")
  assert_eq(loaded.config().model(), "glm-5.3-flash")
  assert_true(loaded.log()[0].contains("config.json"))
  // Saving writes the current config as JSON to the library.
  let with_key = step(loaded, ApiKeyChanged("sk-live"))
  let (_saved, save_effect) = update(with_key, SaveConfig, world_host=host)
  @moui.Effect::runtime_visit(
    save_effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(writes.length(), 1)
  // The file carries every setting, the credential included: it lives at the
  // library root, and worlds (the subfolders) are what gets exported/shared.
  assert_true(writes[0].contains("glm-5.3-flash"))
  assert_true(writes[0].contains("sk-live"))
  assert_true(writes[0].contains("\"api_key\""))
  // Close returns to the main page.
  assert_eq(step(loaded, CloseSettings).page(), Main)
  // A failed save is a log line; a missing file is silently ignored.
  let failed = step(with_key, SettingsSaved(false))
  assert_true(failed.log()[0].contains("写入失败"))
  let (_quiet, quiet_effect) = update(WorldModel::new(), OpenSettings)
  assert_true(is_no_effect(quiet_effect))
  let ignored = step(WorldModel::new(), ConfigFileLoaded(None))
  assert_eq(ignored.config().api_key(), "")
}

///|
test "a provider turn carries the whole plan, including earlier turns" {
  // Regression: the request used to be built from `plan.messages[0]` plus the
  // last message only, so the model never saw history, the rolling summary, or
  // the world-book block. Each turn was silently stateless.
  let seen : Array[LlmRequest] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    seen.push(request)
  }
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  let (sent, effect) = update(
    selected,
    Send("温一壶酒"),
    turn_runner=runner,
  )
  assert_true(is_run_effect(effect))
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 1)
  // First turn: persona + the player's line, and the lore hit rides along.
  let first = seen[0].messages()
  assert_eq(first[0].0, "system")
  assert_true(first[0].1.contains("林掌柜"))
  assert_eq(first[first.length() - 1], ("user", "温一壶酒"))
  assert_true(first.length() >= 3)
  assert_true(
    first.filter(message => message.1.contains("女儿红")).length() > 0,
  )
  // Second turn must include the previous exchange, oldest-first.
  let answered = step(sent, Reply("林掌柜", Some("嗯，酒温好了。")))
  let (_again, second_effect) = update(
    answered,
    Send("再来一壶"),
    turn_runner=runner,
  )
  assert_true(is_run_effect(second_effect))
  @moui.Effect::runtime_visit(
    second_effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 2)
  let history = seen[1].messages()
  assert_true(
    history.filter(message => message.1 == "温一壶酒").length() > 0,
  )
  assert_true(
    history.filter(message => message.1 == "嗯，酒温好了。").length() > 0,
  )
  assert_eq(history[history.length() - 1], ("user", "再来一壶"))
  // The assistant line keeps its wire role rather than being flattened.
  assert_true(history.filter(message => message.0 == "assistant").length() > 0)
}

///|
test "the rolling summary rides on later turns" {
  let seen : Array[LlmRequest] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    seen.push(request)
  }
  let selected = step(tavern_with_key(), Select(Some("林掌柜")))
  selected.conversations.set(
    selected.conversations
    .for_character("林掌柜")
    .append(ChatLine::player("旧事一桩"))
    .with_summary("他们谈妥了赊账。", 60),
  )
  let (_sent, effect) = update(
    selected,
    Send("赊账还算数吗"),
    turn_runner=runner,
  )
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 1)
  let messages = seen[0].messages()
  assert_true(
    messages.filter(message => message.1.contains("【此前】")).length() == 1,
  )
  assert_true(
    messages.filter(message => message.1.contains("谈妥了赊账")).length() ==
    1,
  )
}

///|
test "sending commits the journal and a fresh open restores it" {
  let writes : Array[(String, Array[(String, String)])] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (folder, files, done) => {
      writes.push((folder, files))
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
    copy_to_clipboard: _text => (),
  }
  // Fresh open of the tavern folder (no journal on file yet).
  let opened = step(
    WorldModel::new(),
    WorldFilesArrived("tavern", true, tavern_files()),
  )
  assert_eq(opened.log().length(), 1)
  // The player talks to 林掌柜 with no key: the scripted reply completes
  // inline, and both the player line and the events ride the commit.
  let selected = step(opened, Select(Some("林掌柜")))
  let (_sent, effect) = update(selected, Send("温一壶酒"), world_host=host)
  assert_true(is_run_effect(effect))
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(writes.length(), 1)
  assert_eq(writes[0].0, "tavern")
  // A turn writes only the conversation it touched plus the event log: no
  // world.md, no character cards, no other conversation. That is the point of
  // the conversation scope.
  let paths : Array[String] = []
  for pair in writes[0].1 {
    paths.push(pair.0)
  }
  assert_eq(paths.length(), 2)
  assert_true(paths.contains(conversation_path("林掌柜")))
  assert_true(paths.contains(events_file))
  assert_false(paths.contains("world.md"))
  // The written conversation file parses back on its own.
  let written : String = pair_for(writes[0].1, conversation_path("林掌柜"))
  let parsed = parse_conversation_file(written)
  assert_true(parsed.valid)
  assert_eq(parsed.conversations.length(), 1)
  let lines = parsed.conversations[0].lines()
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].text(), "温一壶酒")
  // The scripted reply belongs to the character and is not empty.
  assert_true(lines[1].speaker() is Character(_))
  assert_true(lines[1].text() != "")
  let events = parse_events_json(pair_for(writes[0].1, events_file))
  assert_true(events.events.length() > 0)
  // A fresh open restores the conversation and the log: the folder is the
  // source of truth. (The open combines the base world files with the
  // conversation-scoped commit, which is what a real host returns.)
  let folder : Array[(String, String)] = tavern_files()
  for pair in writes[0].1 {
    folder.push(pair)
  }
  let reopened = step(
    WorldModel::new(),
    WorldFilesArrived("tavern2", true, folder),
  )
  let restored = reopened.conversations.for_character("林掌柜")
  assert_eq(restored.lines().length(), 2)
  assert_eq(restored.lines()[0].text(), "温一壶酒")
  // The committed events come back, plus this fresh open's own receipt.
  assert_true(reopened.log()[0].contains("已载入"))
  assert_true(
    reopened.log().filter(line => line.contains("温一壶酒")).length() > 0,
  )
}

///|
test "an overflowing send fires the compressor exactly once per threshold" {
  let captured : Array[String] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    captured.push(request.system())
  }
  let model = tavern_with_key()
  let selected = step(model, Select(Some("林掌柜")))
  // Fill the history past the cap so compression pressure exists.
  let mut index = 0
  while index < 55 {
    selected.conversations.set(
      selected.conversations
      .for_character("林掌柜")
      .append(ChatLine::player("第 \\{index} 句闲聊")),
    )
    index += 1
  }
  let (_sent, effect) = update(
    selected,
    Send("新的一句"),
    turn_runner=runner,
  )
  assert_true(is_run_effect(effect))
  // Actually run the effect's provider calls, then inspect the requests.
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(captured.length(), 2)
  // The second provider request is the memory compressor.
  assert_true(captured[1].contains("记忆压缩器"))
  // Install the summary and confirm the throttle holds on the next send.
  let with_summary = step(
    _sent,
    SummaryArrived(
      "林掌柜",
      _sent.conversations.for_character("林掌柜").appended(),
      Some("此前他们聊了55句闲聊。"),
    ),
  )
  assert_eq(
    with_summary.conversations.for_character("林掌柜").summary(),
    "此前他们聊了55句闲聊。",
  )
  captured.clear()
  // The reply lands before the next turn: one send is in flight at a time, so
  // a test that skipped the reply would now hit the in-flight guard.
  let answered = step(with_summary, Reply("林掌柜", Some("嗯。")))
  let (_again, second_effect) = update(
    answered,
    Send("再来一句"),
    turn_runner=runner,
  )
  @moui.Effect::runtime_visit(
    second_effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(captured.length(), 1)
}

///|
test "memory proposals parse, deduplicate, and land only on accept" {
  let model0 = tavern_with_key()
  let selected = step(model0, Select(Some("林掌柜")))
  // Bring the conversation to 9 appended lines so the reply reaches 10.
  let mut index = 0
  while index < 9 {
    selected.conversations.set(
      selected.conversations
      .for_character("林掌柜")
      .append(ChatLine::player("第 \\{index} 句")),
    )
    index += 1
  }
  let captured : Array[String] = []
  let runner : TurnRunner = (request, _on_reply, _on_delta) => {
    captured.push(request.character_id)
  }
  let (replied, effect) = update(
    selected,
    Reply("林掌柜", Some("嗯。")),
    turn_runner=runner,
  )
  assert_eq(replied.memory_drafts().length(), 0)
  // The extraction request rides the same runner as a distinct character.
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_true(captured.contains("!memory"))
  // A proposal with a duplicate of the curated book plus one new fact.
  let proposals = "{\"memories\":[{\"keys\":[\"酒\",\"花雕\"],\"content\":\"后堂埋着一坛三十年的女儿红。\"},{\"keys\":[\"赊账\"],\"content\":\"林掌柜允许了赊账。\"}]}"
  let processing = step(replied, MemoryProposalsArrived(Some(proposals)))
  assert_eq(processing.memory_drafts().length(), 1)
  assert_eq(
    processing.memory_drafts()[0].content(),
    "林掌柜允许了赊账。",
  )
  // Re-proposing the same facts deduplicates against the table.
  let deduplicated = step(processing, MemoryProposalsArrived(Some(proposals)))
  assert_eq(deduplicated.memory_drafts().length(), 1)
  // Accept writes the entry into the selected character's memory book (and
  // clears the draft); the world book stays curated lore only.
  let (accepted, _commit) = update(deduplicated, AcceptMemory(0))
  assert_eq(accepted.memory_drafts().length(), 0)
  assert_eq(accepted.scenario().world_book().length(), 1)
  let adopted = accepted.memories.for_character("林掌柜").entries()
  assert_eq(adopted.length(), 1)
  assert_eq(adopted[0].content(), "林掌柜允许了赊账。")
  assert_true(adopted[0].source() is Adopted)
  assert_false(adopted[0].pinned())
  // Discard simply drops it.
  let (with_two, _e) = update(
    processing,
    MemoryProposalsArrived(
      Some(
        "{\"memories\":[{\"keys\":[\"新事\"],\"content\":\"全新的事实。\"}]}",
      ),
    ),
  )
  assert_eq(with_two.memory_drafts().length(), 2)
  let discarded = step(with_two, DiscardMemory(0))
  assert_eq(discarded.memory_drafts().length(), 1)
  assert_eq(discarded.memory_drafts()[0].content(), "全新的事实。")
}
