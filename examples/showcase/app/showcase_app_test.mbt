///|
test "showcase app emits visual polish commands" {
  let app = @app.ShowcaseApp::new()
  let commands = app.runtime(width=760.0, height=420.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "MoUI Gallery", .. })
    }),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawImage(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushClip(_)),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::PushOpacity(_)),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::FillRoundedRectBrush(
        _,
        @core.Brush::LinearGradient(_)
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Renderer capability", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "image", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "partial", .. })
    }),
  )
}

///|
test "showcase state toggles theme and active copy" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.toggle_scheme()
  app.toggle_active()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "State-driven visuals are active", .. }
      )
    }),
  )
  assert_true(app.dark.get())
  assert_true(app.active.get())
}

///|
test "showcase navigation and dialog state are wired" {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  app.show_dialog()
  app.navigation.replace("controls")
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Gallery dialog", .. })
    }),
  )
  assert_true(app.dialog_visible.get())
  assert_true(app.navigation.current() == "controls")
}
