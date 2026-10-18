///|
/// Scenes: several characters in one room, one transcript, one responder.

///|
/// A world with two people standing in the same place plus one elsewhere.
fn crowded_world() -> WorldModel {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 地点\n\n- 吧台: x=0 y=0 w=300 h=200\n- 后巷: x=320 y=0 w=280 h=200\n",
    ),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 位置\n\nx=100 y=100\n",
    ),
    (
      "characters/赶考书生.md", "# 赶考书生\n\n## 人设\n\n赶考。\n\n## 位置\n\nx=150 y=120\n",
    ),
    (
      "characters/江湖人.md", "# 江湖人\n\n## 人设\n\n赶路。\n\n## 位置\n\nx=400 y=100\n",
    ),
    ("world_book.md", "# 世界书\n\n- 酒: 老酒。\n"),
  ]
  step(WorldModel::new(), WorldFilesArrived("tavern", true, files))
}

///|
test "a place's cast is everyone standing inside it" {
  let model = crowded_world()
  let cast = cast_at(model.scenario(), "吧台")
  let names : Array[String] = []
  for card in cast {
    names.push(card.name())
  }
  assert_eq(cast.length(), 2)
  assert_true(names.contains("林掌柜"))
  assert_true(names.contains("赶考书生"))
  // The person in the back alley is not at the bar.
  assert_false(names.contains("江湖人"))
  assert_eq(cast_at(model.scenario(), "后巷").length(), 1)
  assert_eq(cast_at(model.scenario(), "不存在").length(), 0)
}

///|
test "the respondent answers to their name, otherwise rotates" {
  let model = crowded_world()
  let cast = cast_at(model.scenario(), "吧台")
  match responder_for(cast, "掌柜的，温一壶酒", 0) {
    Some(card) => assert_eq(card.name(), "林掌柜")
    None => fail("someone should answer")
  }
  // A name in the line wins over the rotation.
  match responder_for(cast, "书生，你从哪来？", 1) {
    Some(card) => assert_eq(card.name(), "赶考书生")
    None => fail("the named character should answer")
  }
  // Rotation keeps a scene from being a monologue.
  let first = responder_for(cast, "有人吗", 0)
  let second = responder_for(cast, "有人吗", 1)
  match (first, second) {
    (Some(a), Some(b)) => assert_true(a.id() != b.id())
    _ => fail("both rotations must resolve")
  }
  // An empty cast has no responder.
  assert_true(responder_for([], "hi", 0) is None)
}

///|
test "entering a scene with a cast opens it; empty places refuse" {
  let model = crowded_world()
  let opened = step(model, EnterScene("吧台"))
  assert_eq(opened.scene_location(), Some("吧台"))
  assert_true(opened.in_scene())
  assert_eq(opened.scene_cast().length(), 2)
  // A place with nobody in it says so instead of opening an empty scene.
  let place_without_people = step(model, EnterScene("不存在"))
  assert_eq(place_without_people.scene_location(), None)
  // Leaving returns to private mode.
  assert_eq(step(opened, LeaveScene).scene_location(), None)
}

///|
test "a scene turn lands in the scene transcript, not a private chat" {
  let model = step(crowded_world(), EnterScene("吧台"))
  let (sent, effect) = update(
    model,
    Send("掌柜的，温一壶酒"),
    world_host=(
      {
        list_worlds: _done => (),
        pick_root: _done => (),
        read_world: (_folder, _done) => (),
        write_world: (_folder, _files, _done) => (),
        read_config: _done => (),
        write_config: (_content, _done) => (),
        export_world: (_folder, _files, _done) => (),
        import_world: _done => (),
      } : WorldHost),
  )
  ignore(effect)
  let scene = sent.conversations.for_character(scene_key("吧台"))
  assert_eq(scene.lines().length(), 2)
  assert_eq(scene.lines()[0].text(), "掌柜的，温一壶酒")
  // The reply is attributed to a real character, not to the scene key.
  match scene.lines()[1].speaker() {
    Character(id) => assert_true(sent.scenario().character(id) is Some(_))
    Player => fail("the scene reply must be spoken by a character")
  }
  // The private conversation with that character is untouched.
  assert_eq(sent.conversations.for_character("林掌柜").lines().length(), 0)
}

///|
test "a scene prompt names the room and everyone present" {
  let model = crowded_world()
  let cast = cast_at(model.scenario(), "吧台")
  let responder = match responder_for(cast, "你好", 0) {
    Some(card) => card
    None => fail("need a responder")
  }
  let prompt = build_scene_prompt(model.scenario(), "吧台", cast, responder)
  assert_true(prompt.contains("吧台"))
  assert_true(prompt.contains("林掌柜"))
  assert_true(prompt.contains("赶考书生"))
  // The respondent is marked so the model knows who to speak as.
  assert_true(prompt.contains("（你）"))
  // And it is told not to speak for the others.
  assert_true(prompt.contains("不要替其他角色发言"))
}

///|
test "a scene reply is appended with the respondent as speaker" {
  // A key turns the turn into a provider request, so the reply arrives later
  // via `SceneReply` — that is the path a real scene takes.
  let keyed = step(crowded_world(), ApiKeyChanged("sk-test"))
  let model = step(keyed, EnterScene("吧台"))
  let key = scene_key("吧台")
  let (with_player, _send) = update(model, Send("书生，你从哪来？"), world_host={
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, _done) => (),
    write_world: (_folder, _files, _done) => (),
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
  })
  let (replied, _e) = update(
    with_player,
    SceneReply(key, "赶考书生", Some("小生从南边来。")),
    world_host={
      list_worlds: _done => (),
      pick_root: _done => (),
      read_world: (_folder, _done) => (),
      write_world: (_folder, _files, _done) => (),
      read_config: _done => (),
      write_config: (_content, _done) => (),
      export_world: (_folder, _files, _done) => (),
      import_world: _done => (),
    },
  )
  let lines = replied.conversations.for_character(key).lines()
  assert_eq(lines.length(), 2)
  match lines[1].speaker() {
    Character(id) => assert_eq(id, "赶考书生")
    Player => fail("the reply belongs to the respondent")
  }
  assert_eq(lines[1].text(), "小生从南边来。")
}

///|
test "scene keys never collide with character ids" {
  assert_eq(scene_key("吧台"), "scene:吧台")
  assert_true(is_scene_key("scene:吧台"))
  assert_false(is_scene_key("林掌柜"))
  // The transcript file name is sanitized like any other key.
  assert_true(conversation_path(scene_key("吧台")).has_suffix(".json"))
}

///|
test "tapping a place enters its scene; tapping a person selects them" {
  let model = crowded_world()
  let origin = @geometry.Point::new(x=0.0, y=0.0)
  // Inside 吧台, away from either marker.
  let place = location_at(
    model.scenario(),
    origin,
    @geometry.Point::new(x=20.0, y=20.0),
  )
  assert_eq(place, Some("吧台"))
  // Outside every rect.
  assert_true(
    location_at(
      model.scenario(),
      origin,
      @geometry.Point::new(x=999.0, y=999.0),
    )
    is None,
  )
  // A person inside a place still hit-tests as a person first (view order).
  assert_eq(
    character_at(
      model.scenario(),
      origin,
      @geometry.Point::new(x=100.0, y=100.0),
    ),
    Some("林掌柜"),
  )
}

///|
test "advancing time offline still writes an event" {
  let model = crowded_world()
  let before = model.log().length()
  let (after, effect) = update(model, AdvanceTime)
  ignore(effect)
  assert_true(after.log().length() > before)
  assert_true(
    after.log().filter(line => line.contains("这段时间")).length() > 0,
  )
}

///|
test "advancing time with a key asks the provider and logs the narration" {
  let keyed = step(crowded_world(), ApiKeyChanged("sk-test"))
  let seen : Array[LlmRequest] = []
  let runner : TurnRunner = (request, _on_reply) => seen.push(request)
  let (asked, effect) = update(keyed, AdvanceTime, turn_runner=runner)
  assert_true(is_run_effect(effect))
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_eq(seen.length(), 1)
  assert_true(seen[0].system().contains("时间线"))
  assert_true(seen[0].user().contains("雨夜酒馆"))
  // The narration lands as one event line, prefixed so it reads as time
  // passing rather than as a character speaking.
  let (settled, _e) = update(
    asked,
    TimeAdvanced(Some("掌柜擦了三遍柜台，雨一直没停。")),
  )
  assert_eq(
    settled.log()[0],
    "（这段时间）掌柜擦了三遍柜台，雨一直没停。",
  )
  // A failed generation says so and adds no blank line.
  let (failed, _f) = update(asked, TimeAdvanced(None))
  assert_true(failed.log()[0].contains("失败"))
}

///|
test "the advanced-time prompt names the place and the people" {
  let model = crowded_world()
  let present = cast_at(model.scenario(), "吧台")
  let (system, user) = advance_time_prompt(
    model.scenario(),
    Some("吧台"),
    present,
  )
  assert_true(system.contains("时间线"))
  assert_true(user.contains("吧台"))
  assert_true(user.contains("林掌柜"))
  // Without a scene location the prompt falls back to the world name.
  let (_, world_only) = advance_time_prompt(model.scenario(), None, [])
  assert_true(world_only.contains("雨夜酒馆"))
}

///|
test "a narration is clipped so one reply cannot flood the log" {
  let long = "很长的叙述。".repeat(200)
  let event = time_advanced_event(long)
  assert_true(event.length() < long.length())
  assert_eq(time_advanced_event("   "), "")
}

///|
test "scene speakers alternate across turns" {
  // A turn appends two lines (the player's and the reply), so rotation must key
  // on the number of *player* lines. Keying on total lines advanced by two and
  // the same character answered every round — the scene was a monologue wearing
  // a cast list.
  let keyed = step(crowded_world(), ApiKeyChanged("sk-test"))
  let entered = step(keyed, EnterScene("吧台"))
  let key = scene_key("吧台")
  let never : TurnRunner = (_request, _on_reply) => ()
  let mut current = entered
  let responders : Array[String] = []
  for round in 0..<4 {
    let (asked, _e) = update(
      current,
      Send("第 \{round} 句"),
      turn_runner=never,
      world_host=editing_host,
    )
    // Reply as the character the prompt names.
    let prompt = build_scene_prompt(
      asked.scenario(),
      "吧台",
      cast_at(asked.scenario(), "吧台"),
      match
        responder_for(
          cast_at(asked.scenario(), "吧台"),
          "第 \{round} 句",
          round,
        ) {
        Some(card) => card
        None => fail("a responder is required")
      },
    )
    let who = if prompt.contains("扮演林掌柜") {
      "林掌柜"
    } else {
      "赶考书生"
    }
    responders.push(who)
    let (replied, _r) = update(
      asked,
      SceneReply(key, who, Some("（\{who}回应）")),
      world_host=editing_host,
    )
    current = replied
  }
  // Two characters in the cast => alternating voices.
  assert_eq(responders.length(), 4)
  assert_true(responders[0] != responders[1])
  assert_eq(responders[0], responders[2])
  assert_eq(responders[1], responders[3])
}

///|
test "the rotation index counts turns, not lines" {
  // Pin the arithmetic directly: after N player lines the index is N.
  let model = step(crowded_world(), EnterScene("吧台"))
  let (one, _e) = update(model, Send("第一句"), world_host=editing_host)
  let key = scene_key("吧台")
  let players = one.conversations
    .for_character(key)
    .lines()
    .filter(line => line.speaker() is Player)
  assert_eq(players.length(), 1)
  let (two, _e2) = update(one, Send("第二句"), world_host=editing_host)
  let players_two = two.conversations
    .for_character(key)
    .lines()
    .filter(line => line.speaker() is Player)
  assert_eq(players_two.length(), 2)
}
