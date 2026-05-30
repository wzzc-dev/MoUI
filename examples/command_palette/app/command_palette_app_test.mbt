///|
test "command palette filters metadata and shortcuts" {
  let model = CommandPaletteModel::new().update(QueryChanged("edit"))
  let filtered = model.filtered_commands()
  inspect(filtered.length(), content="2")
  assert_true(
    filtered.any(command => command.display_label() == "Copy Selection"),
  )
  assert_true(
    filtered.any(command => command.display_label() == "Paste Selection"),
  )
  let shortcut = CommandPaletteModel::new().update(QueryChanged("Meta+s"))
  inspect(shortcut.filtered_commands().length(), content="1")
  inspect(
    shortcut.filtered_commands()[0].display_label(),
    content="Save Document",
  )
}

///|
test "command palette dispatches enabled and ignores disabled" {
  let saved = CommandPaletteModel::new().update(
    CommandSelected(@core.CommandIntent::Submit),
  )
  inspect(saved.dispatched.length(), content="1")
  inspect(saved.last_result, content="Dispatched: Save Document")
  let disabled = saved.update(CommandSelected(@core.CommandIntent::Cancel))
  inspect(disabled.dispatched.length(), content="1")
  inspect(disabled.last_result, content="Disabled: Archive Document")
}

///|
test "command palette command map dispatches shortcut but not disabled" {
  let map = action_command_map()
  let save_event = @core.KeyboardEvent::new(
    key="s",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  match map.dispatch_shortcut(save_event) {
    Some(@core.CommandIntent::Submit) => ()
    _ => fail("expected submit shortcut")
  }
  let archive_event = @core.KeyboardEvent::new(
    key="Backspace",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  match map.dispatch_shortcut(archive_event) {
    None => ()
    Some(_) => fail("disabled command should not dispatch")
  }
  assert_false(map.dispatch_intent(@core.CommandIntent::Cancel))
}

///|
test "command palette runtime exposes command rows" {
  let commands = @app.runtime(width=800.0, height=680.0).draw_commands()
  assert_true(has_text(commands, "Command Palette"))
  assert_true(has_text(commands, "Save Document"))
  assert_true(has_text(commands, "Meta+s"))
  assert_true(has_text(commands, "Archive Document"))
  assert_true(has_text(commands, "Context menu fallback"))
  assert_true(has_text(commands, "Dispatch Log"))
}

///|
test "command palette shortcut dispatch does not regress runtime command map" {
  let runtime = @app.runtime(width=800.0, height=680.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(
    runtime
    .action_commands()
    .any(command => command.display_label() == "Save Document"),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
