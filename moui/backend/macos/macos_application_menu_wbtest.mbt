///|
test "macOS application menus preserve typed command order" {
  let first = @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    label="First",
  )
  let second = @core.ActionCommand::new(
    intent=@core.CommandIntent::Submit,
    label="Second",
  )
  let menus = [
    @services.ApplicationMenu::new(title="File", items=[
      @services.ApplicationMenuItem::MenuCommand(first),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(second),
    ]),
  ]
  assert_eq(macos_application_menu_commands(menus), [first, second])
}

///|
test "macOS application menu shortcuts use AppKit modifier masks" {
  let command = @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    shortcut=Some(
      @core.KeyboardShortcut::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  assert_eq(macos_application_menu_shortcut(command), ("s", 1_179_648))
}

///|
test "macOS application-menu placement keeps global command ids" {
  let settings = @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    label="Settings\u{2026}",
    shortcut=Some(
      @core.KeyboardShortcut::new(
        key=",",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let open = @core.ActionCommand::new(
    intent=@core.CommandIntent::Activate,
    label="Open",
  )
  let menus = [
    @services.ApplicationMenu::application(items=[
      @services.ApplicationMenuItem::MenuCommand(settings),
    ]),
    @services.ApplicationMenu::new(title="File", items=[
      @services.ApplicationMenuItem::MenuCommand(open),
    ]),
  ]
  let top = macos_application_menu_descriptors(menus)
  let application = macos_application_menu_items(menus)
  assert_eq(top.length(), 1)
  assert_eq(top[0].title, "File")
  assert_eq(top[0].items[0].action_id, 2)
  assert_eq(application.length(), 1)
  assert_eq(application[0].action_id, 1)
  assert_eq(application[0].key_equivalent, ",")
  assert_eq(application[0].key_modifier_mask, 1_048_576)
}

///|
test "macOS application Edit commands reach focused MoUI text and clipboard" {
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.text_field(
      "https://example.test/path",
      on_input=_value => (),
      width=240.0,
      height=40.0,
    ),
    size=@core.Size::new(width=240.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=120.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=120.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  dispatch_macos_application_command(
    runtime,
    @core.ActionCommand::new(intent=@core.CommandIntent::SelectAll),
  )
  dispatch_macos_application_command(
    runtime,
    @core.ActionCommand::new(intent=@core.CommandIntent::Copy),
  )
  debug_inspect(
    macos_clipboard_read_text(),
    content="Some(\"https://example.test/path\")",
  )
}

///|
#borrow(menu_title, item_title)
extern "C" fn macos_perform_menu_item(
  menu_title : Bytes,
  item_title : Bytes,
) -> Int = "moui_macos_perform_menu_item"

///|
extern "C" fn macos_first_responder_edit_actions_test() -> Int = "moui_macos_first_responder_edit_actions_test"

///|
extern "C" fn macos_application_menu_key_equivalent_test() -> Int = "moui_macos_application_menu_key_equivalent_test"

///|
test "macOS native first responder receives standard Edit commands" {
  assert_eq(macos_first_responder_edit_actions_test(), 1)
}

///|
test "macOS physical Edit key equivalent reaches the first responder" {
  assert_eq(macos_application_menu_key_equivalent_test(), 1)
}

///|
test "macOS menu-bar items invoke the backend-owned action target" {
  let select_all = @core.ActionCommand::new(
    intent=@core.CommandIntent::SelectAll,
    label="Select All",
    shortcut=Some(
      @core.KeyboardShortcut::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let menus = [
    @services.ApplicationMenu::new(title="Edit", items=[
      @services.ApplicationMenuItem::MenuCommand(select_all),
    ]),
  ]
  @window_macos.set_system_menus(macos_application_menu_descriptors(menus))
  let selected_action = Ref(0)
  assert_true(
    bind_macos_menu_bar_items(macos_application_menu_bar_items(menus), action_id => {
      selected_action.val = action_id
    }),
  )
  assert_eq(
    macos_perform_menu_item(
      @utf8.encode("Edit"[:], bom=false),
      @utf8.encode("Select All"[:], bom=false),
    ),
    1,
  )
  assert_eq(selected_action.val, 1)
}
