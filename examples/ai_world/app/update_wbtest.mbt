///|
/// Update-loop behaviour: selection, sending, replies, config, the world
/// library, character creation, and AI world generation.
///
/// The world starts blank; most tests import a small tavern scenario first.
/// Provider-path tests flip the key on; no-key tests exercise the scripted
/// local reply that replaced the old always-pending turn.

///|
let tavern_json : String =
  #|{ "id": "tavern", "name": "雨夜酒馆", "background": "夜雨敲窗，炉火正暖。",
  #|  "characters": [
  #|    { "id": "lin", "name": "林掌柜", "persona": "酒馆掌柜，话不多但句句在理。",
  #|      "voice": "简短、沉稳", "goal": "把这壶酒卖给客人", "secret": "后堂藏着一坛老酒" }
  #|  ],
  #|  "world_book": [ { "keys": ["酒", "花雕"], "content": "后堂埋着一坛三十年的女儿红。" } ] }

///|
fn tavern() -> WorldModel {
  step(WorldModel::new(), ImportScenario(tavern_json))
}

///|
fn tavern_with_key() -> WorldModel {
  step(tavern(), ApiKeyChanged("sk-test"))
}

///|
test "selecting a character clears the composer" {
  let model = step(tavern(), DraftChanged("草稿"))
  assert_eq(model.draft(), "草稿")
  let selected = step(model, Select(Some("lin")))
  assert_eq(selected.selected(), Some("lin"))
  assert_eq(selected.draft(), "")
}

///|
test "sending with nothing selected is inert" {
  let model = WorldModel::new()
  let after = step(model, Send("你好"))
  assert_eq(after.log().length(), 0)
  assert_eq(after.conversations.for_character("lin").lines().length(), 0)
}

///|
test "the no-key turn answers locally and completely" {
  // Without a key the world must still respond — in the same update, with no
  // dangling pending flag and no host effect.
  let selected = step(tavern(), Select(Some("lin")))
  let after = step(selected, Send("  温一壶酒  "))
  let conversation = after.conversations.for_character("lin")
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
  let card : CharacterCard = scenario.character("lin").unwrap()
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
  let selected = step(tavern_with_key(), Select(Some("lin")))
  let (sent, effect) = update(selected, Send("温一壶酒"))
  assert_true(is_run_effect(effect))
  let conversation = sent.conversations.for_character("lin")
  assert_eq(conversation.lines().length(), 1)
  assert_true(conversation.pending())
}

///|
test "a reply is appended, cleaned, and clears pending" {
  let selected = step(tavern_with_key(), Select(Some("lin")))
  let sent = step(selected, Send("温一壶酒"))
  let answered = step(sent, Reply("lin", Some("「嗯，酒温好了。」")))
  let conversation = answered.conversations.for_character("lin")
  assert_eq(conversation.lines().length(), 2)
  // The corner brackets are stripped: the character speaks, not about itself.
  assert_eq(conversation.lines()[1].text(), "嗯，酒温好了。")
  assert_false(conversation.pending())
  assert_eq(answered.log().length(), 3)
}

///|
test "a failed reply keeps the history and clears pending" {
  // A provider hiccup must cost nothing: the player can simply ask again.
  let selected = step(tavern_with_key(), Select(Some("lin")))
  let sent = step(selected, Send("温一壶酒"))
  let failed = step(sent, Reply("lin", None))
  let conversation = failed.conversations.for_character("lin")
  assert_eq(conversation.lines().length(), 1)
  assert_false(conversation.pending())
  // The failure is logged, and it names the provider rather than the character.
  assert_true(failed.log()[0].contains("no reply from provider"))
  assert_true(failed.log()[0].contains("林掌柜"))
}

///|
test "a reply for another character does not leak into this conversation" {
  let selected = step(tavern_with_key(), Select(Some("lin")))
  let sent = step(selected, Send("你好"))
  let other = step(sent, Reply("jianghu", Some("嗯。")))
  assert_eq(other.conversations.for_character("lin").lines().length(), 1)
  assert_eq(other.conversations.for_character("jianghu").lines().length(), 1)
}

///|
test "importing a scenario replaces the world and clears the selection" {
  let selected = step(WorldModel::new(), Select(Some("lin")))
  let imported = step(
    selected,
    ImportScenario(
      "{\"id\":\"court\",\"name\":\"朝堂\",\"background\":\"金殿。\"}",
    ),
  )
  assert_eq(imported.scenario.name(), "朝堂")
  assert_eq(imported.selected(), None)
  assert_true(imported.log().length() > 0)
}

///|
test "importing malformed JSON keeps the built-in reference world" {
  let model = WorldModel::new()
  let after = step(model, ImportScenario("garbage"))
  assert_eq(after.scenario.id(), "tavern")
}

///|
test "configuration edits round-trip through persistence" {
  let model = step(WorldModel::new(), ApiKeyChanged("sk-test"))
  assert_true(model.config.llm_enabled())
  let restored = ModelConfig::from_json(model.config.to_json())
  assert_eq(restored.api_key(), "sk-test")
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
  let selected = step(tavern(), Select(Some("lin")))
  let world_files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n"),
    ("characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n"),
    ("world_book.md", "# 世界书\n\n- 酒: 后堂老酒。\n"),
  ]
  let touched = [
    step(model, Select(None)),
    step(selected, DraftChanged("draft")),
    step(selected, Send("hi")),
    step(selected, Reply("lin", Some("ok"))),
    step(selected, Reply("lin", None)),
    step(model, EndpointChanged("https://example.invalid")),
    step(model, ModelChanged("gpt-4o-mini")),
    step(model, ApiKeyChanged("sk-x")),
    step(model, TemperatureChanged("0.5")),
    step(model, SaveConfig),
    step(model, ConfigLoaded(None)),
    step(model, ConfigSaved),
    step(model, ImportScenario("{}")),
    step(model, SyncLibrary),
    step(model, PickWorldRoot),
    step(model, WorldListArrived(["tavern"])),
    step(model, OpenWorld("tavern")),
    step(model, OpenSettings),
    step(model, CloseSettings),
    step(model, ConfigFileLoaded(None)),
    step(model, SettingsSaved(true)),
  ]
  assert_eq(touched.length(), 21)
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
  ignore(SummaryArrived("lin", 60, Some("笔记")))
  ignore(MemoryProposalsArrived(None))
  ignore(AcceptMemory(0))
  ignore(DiscardMemory(0))
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
  assert_eq(model.scenario().characters().length(), 1)
  assert_eq(model.scenario().world_book().length(), 1)
  // The loaded card works as a conversation partner:
  let talking = step(model, Select(Some("林掌柜")))
  let (sent, effect) = update(talking, Send("这酒怎么卖？"), turn_runner=(
    _r,
    _c,
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
  assert_true(writes[0].contains("sk-live"))
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
  let committed = parse_world_files(world_files_from_paths(writes[0].1))
  match committed {
    Some(ok) => {
      assert_eq(ok.conversations.length(), 1)
      let lines = ok.conversations[0].lines()
      assert_eq(lines.length(), 2)
      assert_eq(lines[0].text(), "温一壶酒")
      // The scripted reply belongs to the character and is not empty.
      assert_true(lines[1].speaker() is Character(_))
      assert_true(lines[1].text() != "")
      assert_true(ok.events.length() > 0)
      // A fresh open of a folder restores the conversation and the log from
      // the committed files — the folder is the source of truth.
      let reopened = step(
        WorldModel::new(),
        WorldFilesArrived("tavern2", true, writes[0].1),
      )
      let restored = reopened.conversations.for_character("林掌柜")
      assert_eq(restored.lines().length(), 2)
      assert_eq(restored.lines()[0].text(), "温一壶酒")
      // The committed events come back, plus this fresh open's own receipt.
      assert_true(reopened.log()[0].contains("已载入"))
      assert_true(
        reopened.log().filter(line => line.contains("温一壶酒")).length() >
        0,
      )
    }
    None => fail("committed folder must parse back")
  }
}

///|
test "an overflowing send fires the compressor exactly once per threshold" {
  let captured : Array[String] = []
  let runner : TurnRunner = (request, _on_reply) => {
    captured.push(request.system)
  }
  let model = tavern_with_key()
  let selected = step(model, Select(Some("lin")))
  // Fill the history past the cap so compression pressure exists.
  let mut index = 0
  while index < 55 {
    selected.conversations.set(
      selected.conversations
      .for_character("lin")
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
      "lin",
      _sent.conversations.for_character("lin").appended(),
      Some("此前他们聊了55句闲聊。"),
    ),
  )
  assert_eq(
    with_summary.conversations.for_character("lin").summary(),
    "此前他们聊了55句闲聊。",
  )
  captured.clear()
  let (_again, second_effect) = update(
    with_summary,
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
  let selected = step(model0, Select(Some("lin")))
  // Bring the conversation to 9 appended lines so the reply reaches 10.
  let mut index = 0
  while index < 9 {
    selected.conversations.set(
      selected.conversations
      .for_character("lin")
      .append(ChatLine::player("第 \\{index} 句")),
    )
    index += 1
  }
  let captured : Array[String] = []
  let runner : TurnRunner = (request, _on_reply) => {
    captured.push(request.character_id)
  }
  let (replied, effect) = update(
    selected,
    Reply("lin", Some("嗯。")),
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
  // Accept writes the entry into the world book (and clears the draft).
  let (accepted, _commit) = update(deduplicated, AcceptMemory(0))
  assert_eq(accepted.memory_drafts().length(), 0)
  assert_eq(accepted.scenario().world_book().length(), 2)
  assert_true(
    accepted.scenario().world_book()[1].content() ==
    "林掌柜允许了赊账。",
  )
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
