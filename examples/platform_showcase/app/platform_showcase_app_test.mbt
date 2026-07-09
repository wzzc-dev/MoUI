///|
test "platform showcase update changes model" {
  let model = PlatformShowcaseModel::new(active_platform=PlatformId::MacOS)
  let selected = update(model, SelectPlatform("android"))
  assert_true(selected.selected_platform == @app.PlatformId::Android)
  let edited = update(selected, SampleTextChanged("Five hosts"))
  inspect(edited.sample_text, content="Five hosts")
  let toggled = update(edited, FeatureToggled(false))
  inspect(toggled.feature_enabled, content="false")
  let slid = update(toggled, SliderChanged(0.25))
  inspect(slid.slider_value, content="0.25")
  inspect(update(slid, Increment).counter, content="1")
  inspect(update(update(slid, Increment), Decrement).counter, content="0")
  inspect(update(slid, Reset).slider_value, content="0.68")
}

///|
test "platform showcase runtime renders app surface and runtime matrix" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::Linux),
    width=1040.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "macOS"))
  assert_true(has_text(commands, "Linux"))
  assert_true(has_text(commands, "Windows"))
  assert_true(has_text(commands, "Android"))
  assert_true(has_text(commands, "iOS"))
  assert_true(has_text(commands, "Web"))
  assert_true(has_text(commands, "MoUI Platform Showcase"))
  assert_true(has_text(commands, "Launch Review"))
  assert_true(has_text(commands, "Interaction Lab"))
  assert_true(has_text(commands, "Live Status"))
  assert_true(has_text(commands, "Runtime Matrix"))
  assert_true(has_text(commands, "Selected route"))
}

///|
test "platform showcase mobile host fills device width" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width=1366.0,
    height=1024.0,
  )
  let commands = runtime.draw_commands()
  assert_true(has_fill_at_least_width(commands, 1366.0))
}

///|
test "platform showcase page scroll responds to wheel delta" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(active_platform=@app.PlatformId::IOS),
    width=390.0,
    height=640.0,
  )
  let before = text_y(
    commands=runtime.draw_commands(),
    text="MoUI Platform Showcase",
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=24.0, y=24.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-160.0),
      ),
    ),
  )
  let after = text_y(
    commands=runtime.draw_commands(),
    text="MoUI Platform Showcase",
  )
  match (before, after) {
    (Some(before), Some(after)) => assert_true(after < before)
    _ => fail("expected clipped page content before and after scroll")
  }
}

///|
test "platform id string roundtrip" {
  let ids = [
    @app.PlatformId::MacOS,
    @app.PlatformId::Linux,
    @app.PlatformId::Windows,
    @app.PlatformId::Android,
    @app.PlatformId::IOS,
    @app.PlatformId::Web,
  ]
  for id in ids {
    assert_true(platform_id_from_string(platform_id_to_string(id)) == Some(id))
  }
  assert_true(platform_id_from_string("plan9") is None)
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_fill_at_least_width(
  commands : Array[@core.DrawCommand],
  width : Double,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::FillRoundedRectBrush({ rect: { size, .. }, .. }, _) &&
    size.width >= width
  })
}

///|
fn text_y(commands~ : Array[@core.DrawCommand], text~ : String) -> Double? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame.origin.y)
        }
      _ => ()
    }
  }
  None
}
