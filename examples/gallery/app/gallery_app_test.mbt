///|
test "gallery view renders the desktop specimen sections" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=1040.0,
    height=780.0,
    environment=@moui.Environment::neutral().with_theme_spec(
      @views.desktop_theme_spec(),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(@test_support.widget_has_text(commands, "MoUI Gallery"))
  assert_true(@test_support.widget_has_text(commands, "Typography"))
  assert_true(@test_support.widget_has_text(commands, "Buttons"))
  assert_true(@test_support.widget_has_text(commands, "Form"))
  assert_true(@test_support.widget_has_text(commands, "Active users"))
  assert_true(@test_support.widget_has_text(commands, "Surfaces and elevation"))
}

///|
test "gallery update keeps control state" {
  let model = @app.Model::new()
    .update(@app.SetDark(true))
    .update(@app.SetServiceName("worker"))
    .update(@app.SetVolume(30.0))
    .update(@app.SetNotifications(false))
  assert_true(model.dark)
  assert_eq(model.service_name, "worker")
  assert_eq(model.volume, 30.0)
  assert_false(model.notifications)
}

///|
test "gallery dark program still renders the header" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program_with_model(
      @app.Model::new().update(@app.SetDark(true)),
    ),
    width=1040.0,
    height=780.0,
    environment=@moui.Environment::neutral().with_theme_spec(
      @views.desktop_theme_spec(),
    ),
  )
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "MoUI Gallery"),
  )
}
