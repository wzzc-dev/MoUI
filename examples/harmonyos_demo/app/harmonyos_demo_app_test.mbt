///|
test "harmonyos demo update changes model" {
  let tapped = @app.update(@app.Model::new(), TapDemo)
  inspect(tapped.tap_count, content="1")
  let rendered = @app.update(tapped, MarkRendered)
  inspect(rendered.render_hint, content="1")
  inspect(@app.update(rendered, Reset).tap_count, content="0")
}

///|
test "harmonyos demo runtime responds to button click and viewport" {
  // The demo content column is taller than 360; clip-aware hit testing
  // rejects clicks outside the viewport, so use a height that shows the buttons.
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=520.0,
    height=560.0,
  )
  assert_true(
    @test_support.widget_has_text(
      runtime.draw_commands(),
      "MoUI HarmonyOS Demo",
    ),
  )
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "520 x 560"),
  )
  @test_support.widget_tap_text(runtime, "Tap")
  assert_true(@test_support.widget_has_text(runtime.draw_commands(), "1"))
}

///|
test "harmonyos demo starts at the top of a tall viewport" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=520.0,
    height=900.0,
  )
  guard @test_support.widget_text_frame(
      runtime.draw_commands(),
      "MoUI HarmonyOS Demo",
    )
    is Some(frame) else {
    fail("expected title frame")
  }
  assert_true(frame.origin.y < 80.0)
}
