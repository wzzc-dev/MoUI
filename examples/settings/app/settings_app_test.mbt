///|
test "settings update edits fields and selection" {
  let model = SettingsModel::new()
    .update(DisplayNameChanged("Grace Hopper"))
    .update(EmailChanged("grace@example.com"))
    .update(WorkspaceChanged("Compiler Lab"))
    .update(ThemeModeSelected("dark"))
    .update(NotificationsChanged(false))
    .update(TelemetryChanged(true))
    .update(SelectSettingsSection("preferences"))
  inspect(model.display_name, content="Grace Hopper")
  inspect(model.email, content="grace@example.com")
  inspect(model.workspace, content="Compiler Lab")
  inspect(model.theme_mode, content="dark")
  inspect(model.notifications, content="false")
  inspect(model.telemetry, content="true")
  inspect(model.selected_section, content="preferences")
}

///|
test "settings saveable snapshot restores model state" {
  let model = SettingsModel::new()
    .update(DisplayNameChanged("Katherine Johnson"))
    .update(EmailChanged("kj@nasa.example"))
    .update(WorkspaceChanged("Orbital Mechanics"))
    .update(ThemeModeSelected("light"))
    .update(NotificationsChanged(false))
    .update(TelemetryChanged(true))
    .update(SelectSettingsSection("workspace"))
    .update(SaveSettings)
  let restored = SettingsModel::restore_from_snapshot(model.save_snapshot())
  inspect(restored.display_name, content="Katherine Johnson")
  inspect(restored.email, content="kj@nasa.example")
  inspect(restored.workspace, content="Orbital Mechanics")
  inspect(restored.theme_mode, content="light")
  inspect(restored.notifications, content="false")
  inspect(restored.telemetry, content="true")
  inspect(restored.selected_section, content="workspace")
  inspect(restored.saved_label, content="Saved: Workspace")
}

///|
test "settings runtime draws profile shell" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=920.0,
    height=620.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Profile"))
  assert_true(has_text(commands, "Display name *"))
  assert_true(has_text(commands, "Email *"))
  assert_true(has_text(commands, "Save Settings"))
  assert_true(has_text(commands, "Saved: Not saved"))
}

///|
test "settings preferences section exposes theme controls" {
  let runtime = @runtime.new_program_with_dimensions(
    program=SettingsModel::new()
      .update(SelectSettingsSection("preferences"))
      .program(),
    width=920.0,
    height=620.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Preferences"))
  assert_true(has_text(commands, "Theme"))
  assert_true(has_text(commands, "Light"))
  assert_true(has_text(commands, "Dark"))
  assert_true(has_text(commands, "System"))
  assert_true(has_text(commands, "Telemetry"))
}

///|
test "settings runtime save button updates status" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=920.0,
    height=620.0,
  )
  assert_true(has_text(runtime.draw_commands(), "Saved: Not saved"))
  click_text(runtime, "Save Settings")
  assert_true(has_text(runtime.draw_commands(), "Saved: Profile"))
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for " + text)
  }
  let point = @moui.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
