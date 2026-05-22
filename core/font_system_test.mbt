///|
test "font family stack defaults and css fallback order" {
  let system = FontFamilyStack::system_ui()
  inspect(system.css(), content="system-ui")
  let named = FontFamilyStack::named("Acme Mono")
    .with_fallback(FontFamily::UiMonospace)
    .with_fallback(FontFamily::Monospace)
  inspect(named.css(), content="\"Acme Mono\", ui-monospace, monospace")
  let spec = FontSpec::new()
  assert_true(spec.families == system)
  inspect(spec.size, content="16")
  inspect(spec.weight, content="400")
  assert_true(spec.style == FontStyle::Normal)
  let custom = FontSpec::new(
    families=named,
    size=13.0,
    weight=700,
    style=Italic,
  )
  assert_true(custom.families == named)
  assert_true(custom.style == FontStyle::Italic)
}

///|
test "runtime text measurer drives focused text input caret geometry" {
  let calls = Ref(0)
  let measurer = TextMeasurer::new(id="test-fixed-advance", measure=input => {
    calls.val = calls.val + 1
    let length = input.text.to_array().length()
    let carets : Array[Double] = []
    for index in 0..<(length + 1) {
      carets.push(index.to_double() * 11.0)
    }
    {
      size: Size::new(width=length.to_double() * 11.0, height=20.0),
      baseline: 12.0,
      caret_positions: carets,
    }
  })
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.set_text_measurer(measurer)
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  let input = runtime.focused_text_input()
  inspect(input.caret, content="3")
  inspect(input.caret_rect.origin.x, content="43")
  assert_true(calls.val > 0)
}

///|
test "runtime text measurer drives custom layout baselines" {
  let measured_baseline : Ref[Double?] = Ref(None)
  let placed_baseline : Ref[Double?] = Ref(None)
  let measurer = TextMeasurer::new(id="test-baseline", measure=input => {
    let length = input.text.to_array().length()
    let carets : Array[Double] = []
    for index in 0..<(length + 1) {
      carets.push(index.to_double() * 5.0)
    }
    {
      size: Size::new(width=length.to_double() * 5.0, height=30.0),
      baseline: 23.0,
      caret_positions: carets,
    }
  })
  let spec = ViewSpec::custom_layout(
    children=[
      ViewSpec::TextSpec({
        key: None,
        text: "Baseline",
        size: Size::new(width=80.0, height=24.0),
        font: FontSpec::new(size=16.0),
        color: Color::black(),
      }),
    ],
    measure=ctx => {
      measured_baseline.val = ctx.child_baselines[0]
      Size::new(width=80.0, height=30.0)
    },
    place=ctx => {
      placed_baseline.val = ctx.child_baselines[0]
      [Rect::new(x=0.0, y=0.0, width=80.0, height=24.0)]
    },
  )
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=80.0, height=30.0),
  )
  ignore(
    layout_spec_with_text_measurer(
      spec,
      Rect::new(x=0.0, y=0.0, width=80.0, height=30.0),
      text_measurer=measurer,
    ),
  )
  match measured_baseline.val {
    Some(value) => inspect(value, content="23")
    None => fail("expected injected baseline in custom measure")
  }
  runtime.set_text_measurer(measurer)
  ignore(runtime.build_draw_commands())
  match placed_baseline.val {
    Some(value) => inspect(value, content="23")
    None => fail("expected injected baseline in custom place")
  }
}
