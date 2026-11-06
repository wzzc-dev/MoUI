///|
priv enum WidgetHarnessMsg {
  Increment
  Decrement
}

///|
fn widget_harness_test_program() -> @core.Program[Int32, WidgetHarnessMsg] {
  @core.Program::new(
    init=() => (0, @core.Effect::none()),
    update=(model, message) => {
      match message {
        Increment => (model + 1, @core.Effect::none())
        Decrement => (model - 1, @core.Effect::none())
      }
    },
    view=model => {
      @views.column(
        [
          @views.text("Count: \{model}"),
          @views.row(
            [
              @views.button("+", on_click=Increment),
              @views.button("-", on_click=Decrement),
            ],
            spacing=10.0,
          ),
        ],
        spacing=12.0,
      )
    },
  )
}

///|
test "widget harness taps text and observes drawn output" {
  let harness = @test_support.WidgetHarness::from_program(
    program=widget_harness_test_program(),
    width=320.0,
    height=240.0,
  )
  assert_true(harness.has_text("Count: 0"))
  assert_false(harness.has_text("Count: 1"))
  assert_true(harness.text_frame("+") is Some(_))
  harness.tap_text("+")
  assert_true(harness.has_text("Count: 1"))
  harness.tap_text("-")
  assert_true(harness.has_text("Count: 0"))
}

///|
test "widget harness tap_at dispatches through the layout tree" {
  let harness = @test_support.WidgetHarness::from_program(
    program=widget_harness_test_program(),
    width=320.0,
    height=240.0,
  )
  match harness.text_frame("+") {
    Some(frame) => {
      harness.tap_at(
        x=frame.origin.x + frame.size.width / 2.0,
        y=frame.origin.y + frame.size.height / 2.0,
      )
      assert_true(harness.has_text("Count: 1"))
    }
    None => fail("expected + button frame")
  }
}

///|
test "widget free helpers work over a bare runtime" {
  let runtime = @runtime.new_program_with_dimensions(
    program=widget_harness_test_program(),
    width=320.0,
    height=240.0,
  )
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Count: 0"),
  )
  @test_support.widget_tap_text(runtime, "+")
  assert_true(
    @test_support.widget_has_text(runtime.draw_commands(), "Count: 1"),
  )
  assert_true(
    @test_support.widget_text_frame(runtime.draw_commands(), "missing") is None,
  )
}

///|
test "widget harness tap_text raises on missing text" {
  let harness = @test_support.WidgetHarness::from_program(
    program=widget_harness_test_program(),
    width=320.0,
    height=240.0,
  )
  let outcome : Result[Unit, Error] = Ok(harness.tap_text("not drawn")) catch {
    error => Err(error)
  }
  assert_true(outcome is Err(_))
}
