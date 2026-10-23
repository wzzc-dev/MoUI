///|
/// The responsive shell: the two-column stage, the drawers, the message menu,
/// the atmosphere view, and the onboarding/settings pages.
///
/// These are model-and-layout tests: `Screen` is pure data, so the breakpoints
/// can be asserted without a renderer, and the *presence* of a control in the
/// view tree is asserted by walking it rather than by eyeballing a screenshot.

///|
/// Does the view tree contain a button/field with this label or placeholder?
fn tree_has_text(view : @moui.View[Msg], needle : String) -> Bool {
  let semantics = view.semantics()
  if semantics.label is Some(label) && label == needle {
    return true
  }
  if semantics.description is Some(description) && description == needle {
    return true
  }
  for child in view.children() {
    if tree_has_text(child, needle) {
      return true
    }
  }
  false
}

///|
/// Does the view tree contain a text node whose label *contains* the needle?
/// Prose captions are whole sentences, so presence checks on a phrase inside
/// them need a substring walk rather than an exact match.
fn tree_contains_text(view : @moui.View[Msg], needle : String) -> Bool {
  let semantics = view.semantics()
  if semantics.label is Some(label) && label.contains(needle) {
    return true
  }
  if semantics.description is Some(description) && description.contains(needle) {
    return true
  }
  for child in view.children() {
    if tree_contains_text(child, needle) {
      return true
    }
  }
  false
}

///|
/// A world folder with one character, opened through the real parser.
fn opened_world() -> WorldModel {
  let files : Array[(String, String)] = [
    (
      "world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 地点\n\n- 吧台: x=20 y=20 w=240 h=150\n",
    ),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 位置\n\nx=100 y=90\n",
    ),
  ]
  step(WorldModel::new(), WorldFilesArrived("tavern", true, files))
}

///|
test "the wide layout is two columns: the rail and the stage" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let open = view_for(opened_world(), screen)
  // The rail's door: recent characters (empty here) and the creator.
  assert_true(tree_has_text(open, "＋ 设定人物"))
  assert_true(tree_has_text(open, "最近角色"))
  // The stage: the composer and the scene header's actions.
  assert_true(tree_has_text(open, "发送"))
  assert_true(tree_has_text(open, "氛围"))
  assert_true(tree_has_text(open, "档案"))
  // The old permanent third column is gone: no event rail, no tab strip.
  assert_false(tree_has_text(open, "推进时间"))
  assert_false(tree_has_text(open, "事件"))
}

///|
test "the library manager leaves the stage once a world is open" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  // With a world open, the stage shows the conversation, not folder
  // management: the library list and the generation box are settings concerns.
  let open = view_for(opened_world(), screen)
  assert_false(tree_has_text(open, "选择世界库…"))
  assert_false(tree_has_text(open, "生成世界"))
  assert_false(tree_has_text(open, "新世界的名字…"))
}

///|
test "with no world open the library and generation own the main screen" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let fresh = view_for(WorldModel::new(), screen)
  assert_true(tree_has_text(fresh, "选择世界库…"))
  assert_true(tree_has_text(fresh, "生成世界"))
  assert_true(tree_has_text(fresh, "新世界的名字…"))
}

///|
test "settings carries the library manager, world generation, and appearance" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let in_settings = view_for(step(opened_world(), OpenSettings), screen)
  assert_true(tree_has_text(in_settings, "选择世界库…"))
  assert_true(tree_has_text(in_settings, "生成世界"))
  assert_true(tree_has_text(in_settings, "导出世界"))
  // And the model settings are still there.
  assert_true(tree_has_text(in_settings, "保存设置"))
  // The two appearances.
  assert_true(tree_has_text(in_settings, "宣纸"))
  assert_true(tree_has_text(in_settings, "墨蓝"))
}

///|
test "a drawer opens over the stage and closes again" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let base = opened_world()
  // Nothing open: the drawer's own controls are not in the tree.
  assert_false(tree_has_text(view_for(base, screen), "角色档案"))
  // The profile drawer.
  let profile = view_for(step(base, OpenDrawer(Profile)), screen)
  assert_true(tree_has_text(profile, "角色档案"))
  assert_true(tree_has_text(profile, "关闭"))
  // The memory drawer.
  let memory = view_for(step(base, OpenDrawer(Memory)), screen)
  assert_true(tree_has_text(memory, "长久记忆"))
  // The model drawer.
  let model_drawer = view_for(step(base, OpenDrawer(Model)), screen)
  assert_true(tree_has_text(model_drawer, "模型状态"))
  assert_true(tree_has_text(model_drawer, "打开设置"))
  // The events drawer carries the time-advance action that used to live in a
  // permanent rail.
  let events = view_for(step(base, OpenDrawer(Events)), screen)
  assert_true(tree_has_text(events, "推进时间"))
  // And closing removes it.
  let closed = view_for(step(step(base, OpenDrawer(Profile)), CloseDrawer), screen)
  assert_false(tree_has_text(closed, "角色档案"))
}

///|
test "a history line's more menu carries the retired action row" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  // A conversation with two lines, so line 0 has something to act on.
  let talking = step(
    step(opened_world(), Select(Some("林掌柜"))),
    Send("温一壶酒"),
  )
  let replied = step(
    talking,
    Reply("林掌柜", Some("客官里边坐。")),
  )
  // Closed: the menu's items are not in the tree.
  assert_false(tree_has_text(view_for(replied, screen), "从此分叉"))
  // Open on line 1 (the character's reply): regenerate, edit, delete, branch.
  let menu = view_for(step(replied, OpenMessageMenu(1)), screen)
  assert_true(tree_has_text(menu, "从此分叉"))
  assert_true(tree_has_text(menu, "改这句"))
  assert_true(tree_has_text(menu, "删这句"))
  assert_true(tree_has_text(menu, "重新生成"))
  // The player's own line offers the same branch/edit/delete items; its menu
  // simply has no regenerate-only extra (the composer's own 重新生成 button is
  // always on screen, so an absence assertion on that label cannot be exact).
  let player_menu = view_for(step(replied, OpenMessageMenu(0)), screen)
  assert_true(tree_has_text(player_menu, "从此分叉"))
  assert_true(tree_has_text(player_menu, "改这句"))
  // Closing removes it.
  let closed = view_for(step(replied, CloseMessageMenu), screen)
  assert_false(tree_has_text(closed, "从此分叉"))
}

///|
test "the atmosphere view opens full-screen and leaves on exit" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let base = opened_world()
  assert_false(tree_has_text(view_for(base, screen), "退出"))
  let inside = view_for(step(base, ToggleAtmosphere), screen)
  assert_true(tree_has_text(inside, "退出"))
  assert_true(tree_contains_text(inside, "点角色私聊"))
  // Selecting a character from the map leaves the atmosphere view.
  let left = step(step(base, ToggleAtmosphere), Select(Some("林掌柜")))
  assert_false(left.atmosphere())
  assert_false(tree_has_text(view_for(left, screen), "退出"))
}

///|
test "the medium layout toggles its rail instead of tabbing panels" {
  let medium = Screen::for_viewport(900.0, 700.0)
  let model = opened_world()
  // Closed: the stage has the width; the rail is not rendered.
  assert_false(tree_has_text(view_for(model, medium), "＋ 设定人物"))
  // Open: the rail appears, the stage keeps its composer.
  let open = view_for(step(model, ToggleRail), medium)
  assert_true(tree_has_text(open, "＋ 设定人物"))
  assert_true(tree_has_text(open, "发送"))
  // The scene header carries the toggle on non-wide layouts.
  assert_true(tree_has_text(open, "角色"))
}

///|
test "a phone shows the full-screen chat and opens the roster as an overlay" {
  let phone = Screen::for_viewport(390.0, 844.0)
  let model = opened_world()
  let chat = view_for(model, phone)
  assert_true(tree_has_text(chat, "发送"))
  assert_true(tree_has_text(chat, "角色"))
  // The roster overlay.
  let roster = view_for(step(model, ToggleRail), phone)
  assert_true(tree_has_text(roster, "最近角色"))
  assert_true(tree_has_text(roster, "关闭"))
}

///|
test "the scene stage keeps the cast, the map, and the way back" {
  // Two characters at one location: the scene list and the scene stage exist.
  let files : Array[(String, String)] = [
    (
      "world.md", "# 雨夜酒馆\n\n夜雨敲窗。\n\n## 地点\n\n- 吧台: x=20 y=20 w=240 h=150\n",
    ),
    (
      "characters/林掌柜.md", "# 林掌柜\n\n## 人设\n\n掌柜。\n\n## 所在\n\n吧台\n",
    ),
    (
      "characters/阿七.md", "# 阿七\n\n## 人设\n\n跑堂。\n\n## 所在\n\n吧台\n",
    ),
  ]
  let world = step(WorldModel::new(), WorldFilesArrived("tavern", true, files))
  let screen = Screen::for_viewport(1600.0, 900.0)
  let rail = view_for(world, screen)
  assert_true(tree_contains_text(rail, "场景 · 吧台"))
  let scene = view_for(step(world, EnterScene("吧台")), screen)
  assert_true(tree_contains_text(scene, "人在场"))
  assert_true(tree_has_text(scene, "离开场景"))
  // The scene's own transcript labels every speaker.
  assert_true(tree_contains_text(scene, "这里还没有人说话"))
}

///|
test "the composer is one field by default, and 组合 opens the combined form" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let model = opened_world()
  let collapsed = view_for(model, screen)
  // The mode switcher shows the current intent, and the way into the
  // combined form is one button away.
  assert_true(tree_has_text(collapsed, "说 ▾"))
  assert_true(tree_has_text(collapsed, "组合"))
  // The three permanent fields are gone.
  assert_false(tree_has_text(collapsed, "做【"))
  assert_false(tree_has_text(collapsed, "旁白【"))
  // Expanded: the three fields come back, each with its own intent — and the
  // way back is on screen. Without 收起 the player would be stuck in the
  // combined form.
  let expanded = view_for(step(model, ToggleComposerExpanded), screen)
  assert_true(tree_has_text(expanded, "做【"))
  assert_true(tree_has_text(expanded, "旁白【"))
  assert_true(tree_has_text(expanded, "收起"))
  assert_true(tree_has_text(expanded, "多段合成 · 一次发送"))
  // The collapsed form has no 收起 — it has 组合.
  assert_false(tree_has_text(collapsed, "收起"))
  // The intent menu lists the three intents.
  let menu = view_for(step(model, ComposerMenuChanged(true)), screen)
  assert_true(tree_has_text(menu, "旁白"))
  assert_true(tree_has_text(menu, "做"))
}
