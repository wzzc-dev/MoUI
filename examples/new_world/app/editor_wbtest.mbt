///|
/// The six-block editor: opening, block switching, the save path, and the
/// draft → card → Markdown → card round trip that keeps a saved card lossless.

///|
/// A world with one fully-filled v2 card, opened through the real parser.
fn editor_world() -> WorldModel {
  let files : Array[(String, String)] = [
    ("world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 版本\n\n- 卡档: v2\n"),
    (
      "characters/温衍.md", "# 温衍\n\n## 人设\n\n清心寡欲的散仙。\n\n## 行为原则\n\n感情藏在细节里。\n\n## 说话方式\n\n舒缓克制\n\n## 示例台词\n\n坐吧。\n既来了，便坐吧。\n\n## 与用户的关系\n\n- 玩家身份: 徒弟\n- 玩家称呼: 狸奴\n- 边界: 自己的事一概不提\n\n## 当前情境\n\n夜深，洞府。\n\n## 开场白\n\n（搁下书卷）这么晚了，还不歇息？\n\n## 目标\n\n护徒弟走完这一关\n\n## 秘密\n\n他早已算出自己命里有一劫\n\n## 记忆规则\n\n答应过的事必须记得。\n",
    ),
  ]
  step(WorldModel::new(), WorldFilesArrived("tavern", true, files))
}

///|
test "the editor opens on a working copy of the whole card" {
  let model = step(editor_world(), EditCharacter("温衍"))
  assert_true(model.editor_open())
  assert_eq(model.editor_target(), Some("温衍"))
  let draft = model.editor_draft()
  assert_eq(draft.persona, "清心寡欲的散仙。")
  assert_eq(draft.principles, "感情藏在细节里。")
  assert_eq(draft.voice, "舒缓克制")
  assert_eq(draft.user_identity, "徒弟")
  assert_eq(draft.user_name, "狸奴")
  assert_eq(draft.boundary, "自己的事一概不提")
  assert_eq(draft.setting, "夜深，洞府。")
  assert_eq(draft.opening, "（搁下书卷）这么晚了，还不歇息？")
  assert_eq(draft.goal, "护徒弟走完这一关")
  assert_eq(draft.secret, "他早已算出自己命里有一劫")
  assert_eq(draft.memory_rules, "答应过的事必须记得。")
  // The example buffer is prose: one line per example, in order.
  assert_eq(model.editor_examples(), "坐吧。\n既来了，便坐吧。")
  // Opening the editor covers the drawer it came from.
  assert_false(model.drawer() is Some(_))
}

///|
test "editing an unknown card is inert and closing discards" {
  // An id that is not in the world: no editor opens.
  let untouched = step(editor_world(), EditCharacter("不存在"))
  assert_false(untouched.editor_open())
  // Closing clears the target, so a stale save cannot land anywhere.
  let opened = step(editor_world(), EditCharacter("温衍"))
  let closed = step(opened, CloseEditor)
  assert_false(closed.editor_open())
  assert_eq(closed.editor_target(), None)
}

///|
test "the editor tab snaps into range" {
  let model = editor_world()
  assert_eq(step(model, EditorTabChanged(3)).editor_tab(), 3)
  assert_eq(step(model, EditorTabChanged(99)).editor_tab(), 6)
  assert_eq(step(model, EditorTabChanged(-2)).editor_tab(), 0)
}

///|
test "saving writes the six blocks back and keeps the card's identity" {
  let screen_model = step(editor_world(), EditCharacter("温衍"))
  let edited = step(
    screen_model,
    EditorChanged(screen_model.editor_draft().with_principles("先看出口再坐下")),
  )
  let (saved, effect) = update(edited, SaveCharacter)
  assert_false(saved.editor_open())
  match saved.scenario().character("温衍") {
    Some(card) => {
      assert_eq(card.principles(), "先看出口再坐下")
      // The rest of the card survived the round trip.
      assert_eq(card.persona(), "清心寡欲的散仙。")
      assert_eq(card.opening(), "（搁下书卷）这么晚了，还不歇息？")
      assert_eq(card.relationship().user_name(), "狸奴")
      assert_eq(card.examples().length(), 2)
      // Identity is not editable here: id, name, marker colour stay.
      assert_eq(card.id(), "温衍")
      assert_eq(card.name(), "温衍")
    }
    None => fail("the edited card must still exist")
  }
  // A save is a world-scope commit (the card's Markdown changed).
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => run(_m => ()),
    (_descriptor, _task) => (),
  )
  assert_true(saved.log()[0].contains("已更新"))
}

///|
test "an emptied persona is refused, not written" {
  let screen_model = step(editor_world(), EditCharacter("温衍"))
  let emptied = step(
    screen_model,
    EditorChanged(screen_model.editor_draft().with_persona("  ")),
  )
  let (saved, _effect) = update(emptied, SaveCharacter)
  // The editor stays open and the card keeps its persona.
  assert_true(saved.editor_open())
  match saved.scenario().character("温衍") {
    Some(card) => assert_eq(card.persona(), "清心寡欲的散仙。")
    None => fail("the card must survive a refused save")
  }
  assert_true(saved.log()[0].contains("人设不能为空"))
}

///|
test "the example buffer splits on save, dropping blank lines" {
  let screen_model = step(editor_world(), EditCharacter("温衍"))
  let typed = step(
    screen_model,
    EditorExamplesChanged("嗯。\n\n（把茶推过来）喝吧。\n  \n再说。"),
  )
  let (saved, _effect) = update(typed, SaveCharacter)
  match saved.scenario().character("温衍") {
    Some(card) =>
      assert_eq(card.examples(), ["嗯。", "（把茶推过来）喝吧。", "再说。"])
    None => fail("the card must exist")
  }
}

///|
test "the editor is visible in the tree and leaves on close" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let base = editor_world()
  assert_false(tree_has_text(view_for(base, screen), "编辑角色"))
  let open_view = view_for(step(base, EditCharacter("温衍")), screen)
  // The page header: the title and the character it edits.
  assert_true(tree_has_text(open_view, "编辑角色"))
  assert_true(tree_has_text(open_view, "温衍"))
  // The block switcher and the footer.
  assert_true(tree_has_text(open_view, "身份与背景"))
  assert_true(tree_has_text(open_view, "保存"))
  assert_true(tree_has_text(open_view, "取消"))
  // The way out, stated on the page.
  assert_true(tree_has_text(open_view, "关闭不会保存"))
  let closed = view_for(step(base, CloseEditor), screen)
  assert_false(tree_has_text(closed, "编辑角色"))
}

///|
test "the editor shows the portrait in a frame, beside the fields" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let open_view = view_for(
    step(editor_world(), EditCharacter("温衍")),
    screen,
  )
  // The portrait block is one of the seven, and its preview names the frame.
  assert_true(tree_has_text(open_view, "外貌与立绘"))
  let portrait_view = view_for(
    step(
      step(editor_world(), EditCharacter("温衍")),
      EditorTabChanged(6),
    ),
    screen,
  )
  assert_true(tree_has_text(portrait_view, "立绘预览（透明底已垫好）"))
  // The fields sit next to the picture, not under it.
  assert_true(tree_has_text(portrait_view, "立绘文件名（characters/ 下的图片名，空 = 无）"))
  assert_true(tree_has_text(portrait_view, "立绘提示词（拿去生图用）"))
}

///|
test "the profile drawer frames the portrait the same way" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let profile = view_for(
    step(step(editor_world(), Select(Some("温衍"))), OpenDrawer(Profile)),
    screen,
  )
  // The read-only view carries the same framed picture, so the two views show
  // the character the same way.
  assert_true(tree_has_text(profile, "立绘"))
}

///|
test "the profile drawer carries the way into the editor" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  // With a character selected, the drawer is their dossier and the editor's
  // door; without one it is only a hint.
  let plain = view_for(step(editor_world(), OpenDrawer(Profile)), screen)
  assert_true(tree_has_text(plain, "角色档案"))
  assert_false(tree_has_text(plain, "编辑角色"))
  let profile = view_for(
    step(step(editor_world(), Select(Some("温衍"))), OpenDrawer(Profile)),
    screen,
  )
  assert_true(tree_has_text(profile, "角色档案"))
  assert_true(tree_has_text(profile, "编辑角色"))
}

///|
test "saving a card refreshes the world's portraits" {
  // The model caches the world's pictures so rendering never does IO. A save
  // can bring a new picture into the folder (the editor's 立绘 field points
  // at a file the player just dropped in beside the card), and the cache has
  // to learn about it — otherwise the picture only shows up after a restart.
  let png =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  let mut written : Array[(String, String)] = []
  let host : WorldHost = {
    list_worlds: _done => (),
    pick_root: _done => (),
    read_world: (_folder, done) => {
      // The folder now carries the picture the card points at.
      done(
        true,
        [
          ("world.md", "# 雨夜酒馆\n"),
          ("characters/温衍.jpg", png),
        ],
      )
    },
    write_world: (_folder, files, done) => {
      written = files
      done(true)
    },
    read_config: _done => (),
    write_config: (_content, _done) => (),
    export_world: (_folder, _files, _done) => (),
    import_world: _done => (),
  }
  let opened = step(editor_world(), EditCharacter("温衍"))
  let typed = step(
    opened,
    EditorChanged(opened.editor_draft().with_portrait("温衍.jpg")),
  )
  let (_saved, effect) = update(typed, SaveCharacter, world_host=host)
  // The save wrote the card, and the world was read again afterwards so the
  // picture joins the model.
  let mut read_again = false
  @moui.Effect::runtime_visit(
    effect,
    _m => (),
    _d => (),
    (_descriptor, run) => {
      run(_m => {
        read_again = true
      })
    },
    (_descriptor, _task) => (),
  )
  assert_true(read_again)
  // The card's 立绘 field points at the picture.
  let mut portrait_field = ""
  for pair in written {
    if pair.0.has_suffix("温衍.md") {
      portrait_field = pair.1
    }
  }
  assert_true(portrait_field.contains("温衍.jpg"))
}

///|
test "the refreshed portraits reach the model" {
  // The message the refresh carries is the model's cache: the picture is
  // there right after the save, without a restart.
  let png =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  let model = step(editor_world(), WorldPortraitsRefreshed([("characters/温衍.jpg", png)]))
  assert_eq(model.portraits.length(), 1)
  // A card that names the picture finds it in the refreshed cache.
  let card = match parse_character_md("# 温衍\n\n## 人设\n\n散仙。\n\n## 立绘\n\n温衍.jpg\n") {
    Some(c) => c
    None => fail("the card must parse")
  }
  assert_eq(card.portrait(), "温衍.jpg")
  // The picture's own type decides the data URI's mime: a .jpg is a jpeg.
  assert_true(portrait_uri(card, model.portraits).has_prefix("data:image/jpeg;base64,"))
}
