///|
/// The responsive shell: breakpoints, onboarding vs. workbench, and the move of
/// the library manager / world generation into settings.
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
test "the breakpoints pick wide, medium, and compact by width alone" {
  let wide = Screen::for_viewport(1600.0, 900.0)
  assert_eq(wide.mode, Wide)
  // The wide block keeps the designed column widths when there is room to
  // spare, so a 2,500px monitor does not stretch a dialogue line.
  assert_eq(wide.stage, 520.0)
  assert_eq(wide.rail, 310.0)
  assert_eq(wide.controls, 330.0)

  let medium = Screen::for_viewport(900.0, 700.0)
  assert_eq(medium.mode, Medium)
  assert_true(medium.stage > medium.rail)

  let phone = Screen::for_viewport(390.0, 844.0)
  assert_eq(phone.mode, Compact)
  // A portrait phone gets the full width for the stage: a 310px rail next to a
  // 40px conversation would be unusable.
  assert_eq(phone.rail, 0.0)
  assert_eq(phone.controls, 0.0)
  assert_eq(phone.stage, 390.0 - 24.0)
  assert_true(phone.tight_controls)
}

///|
test "a degenerate viewport falls back instead of producing NaN" {
  // Hosts report 0×0 before the first real resize.
  let zero = Screen::for_viewport(0.0, 0.0)
  assert_eq(zero.mode, Wide)
  assert_true(zero.stage > 0.0)
  // A literal NaN (0.0/0.0) keeps the test dependency-free; the point is that
  // the screen sanitizes it rather than propagating it into layout.
  let nan_value = 0.0 / 0.0
  let nan = Screen::for_viewport(nan_value, nan_value)
  assert_true(!nan.stage.is_nan())
  assert_true(!nan.map_height.is_nan())
}

///|
test "a phone-sized map is shorter than a desktop map" {
  let wide = Screen::for_viewport(1600.0, 900.0)
  let phone = Screen::for_viewport(390.0, 844.0)
  assert_true(phone.map_height < wide.map_height)
  // But never so short that the map is a sliver.
  assert_true(phone.map_height >= 120.0)
}

///|
test "the library manager leaves the workbench once a world is open" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  // With a world open, the workbench shows the conversation, not folder
  // management: the library list and the generation box are settings concerns.
  let open = view_for(opened_world(), screen)
  assert_false(tree_has_text(open, "选择世界库…"))
  assert_false(tree_has_text(open, "生成世界"))
  assert_false(tree_has_text(open, "新世界的名字…"))
  // The roster and the event log are still there — this is the workbench.
  assert_true(tree_has_text(open, "人物"))
  assert_true(tree_has_text(open, "事件"))
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
test "settings carries the library manager and world generation" {
  let screen = Screen::for_viewport(1600.0, 900.0)
  let in_settings = view_for(step(opened_world(), OpenSettings), screen)
  assert_true(tree_has_text(in_settings, "选择世界库…"))
  assert_true(tree_has_text(in_settings, "生成世界"))
  assert_true(tree_has_text(in_settings, "导出世界"))
  // And the model settings are still there.
  assert_true(tree_has_text(in_settings, "保存设置"))
}

///|
test "the shell tab selector maps its codes and defaults to the chat" {
  let model = WorldModel::new()
  assert_eq(model.shell_tab(), Chat)
  assert_eq(step(model, ShellTabChanged(1)).shell_tab(), Library)
  assert_eq(step(model, ShellTabChanged(2)).shell_tab(), Controls)
  assert_eq(step(model, ShellTabChanged(99)).shell_tab(), Chat)
}

///|
test "a narrow layout renders one panel and the tab strip, not three columns" {
  let phone = Screen::for_viewport(390.0, 844.0)
  let on_chat = view_for(opened_world(), phone)
  // The tab strip exists.
  assert_true(tree_has_text(on_chat, "对话"))
  assert_true(tree_has_text(on_chat, "人物"))
  assert_true(tree_has_text(on_chat, "事件"))
  // The event log is on another tab, so it is not in this frame.
  assert_false(tree_has_text(on_chat, "推进时间"))
  // Switching to the event tab renders it full width.
  let on_events = view_for(step(opened_world(), ShellTabChanged(2)), phone)
  assert_true(tree_has_text(on_events, "推进时间"))
}

///|
test "the medium layout keeps the stage and switches the side rail" {
  let medium = Screen::for_viewport(900.0, 700.0)
  let model = opened_world()
  let on_chat = view_for(model, medium)
  // The conversation is always present; the side rail is what switches.
  assert_true(tree_has_text(on_chat, "林掌柜"))
  assert_false(tree_has_text(on_chat, "推进时间"))
  let on_controls = view_for(step(model, ShellTabChanged(2)), medium)
  assert_true(tree_has_text(on_controls, "推进时间"))
  // The stage did not move out of the frame: the composer's send action is
  // still there while the side rail shows the event log.
  assert_true(tree_has_text(on_controls, "发送"))
  // The composer is the three-field format: the intent label opens the bracket.
  assert_true(tree_has_text(on_controls, "说【"))
  assert_true(tree_has_text(on_controls, "做【"))
  assert_true(tree_has_text(on_controls, "旁白【"))
}
