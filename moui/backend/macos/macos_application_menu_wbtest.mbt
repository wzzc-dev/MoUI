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
