///|
test "design systems app renders source mapped preview evidence" {
  let commands = @app.DesignSystemsApp::new()
    .runtime(width=960.0, height=680.0)
    .draw_commands()
  assert_true(has_text(commands, "Design Systems"))
  assert_true(has_text(commands, "Semantic palette roles"))
  assert_true(has_text(commands, "Typography specimen"))
  assert_true(has_text(commands, "Spacing and density"))
  assert_true(has_text(commands, "Component token matrix"))
  assert_true(has_text(commands, "source-mapped preview"))
  assert_true(has_text(commands, "not official complete"))
}

///|
test "design systems app switches official presets and custom override" {
  let model = @app.DesignSystemsModel::new()
    .update(@app.DesignSystemsMsg::SelectPreset("carbon"))
    .update(@app.DesignSystemsMsg::SelectScheme("dark"))
    .update(@app.DesignSystemsMsg::SelectVariant("system"))
    .update(@app.DesignSystemsMsg::SelectDensity("compact"))
    .update(@app.DesignSystemsMsg::ToggleCustom)
  assert_true(model.preset == @app.DesignSystemChoice::Carbon)
  assert_true(model.scheme == @core.ColorScheme::Dark)
  assert_true(model.variant == @common.DesignSchemeVariant::SchemeSystem)
  assert_true(model.density == @common.DesignDensity::Compact)
  assert_true(model.custom_enabled)
  let commands = model.runtime(width=960.0, height=680.0).draw_commands()
  assert_true(has_text(commands, "IBM Carbon Design System"))
  assert_true(has_text(commands, "Custom override on"))
  assert_true(has_text(commands, "Compact"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
