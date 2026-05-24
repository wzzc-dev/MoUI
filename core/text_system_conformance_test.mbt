///|
fn text_conformance_carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn assert_text_layout_invariants(
  system : TextSystem,
  text : String,
  font : FontSpec,
) -> Unit raise {
  let layout = system.measure_text(TextLayoutInput::new(text~, font~))
  inspect(
    layout.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    text_conformance_carets_are_monotonic(layout.caret_positions),
    content="true",
  )
  if text == "" {
    inspect(layout.size.width, content="0")
  } else {
    inspect(layout.size.width > 0.0, content="true")
  }
  inspect(layout.size.height > 0.0, content="true")
  inspect(layout.baseline > 0.0, content="true")
  let clamped = system.measure_text(
    TextLayoutInput::new(text~, font~, max_width=18.0),
  )
  inspect(clamped.size.width <= 18.0, content="true")
  inspect(
    clamped.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    text_conformance_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 18.0, content="true")
  }
}

///|
fn fixed_advance_text_system(advance : Double) -> TextSystem {
  TextSystem::new(id="test-fixed-advance-conformance", measure=input => {
    let carets : Array[Double] = [0.0]
    let mut cursor = 0.0
    for _ in input.text {
      cursor = cursor + advance
      carets.push(cursor)
    }
    let width = match input.max_width {
      Some(max_width) => cursor.min(max_width)
      None => cursor
    }
    match input.max_width {
      Some(max_width) =>
        for index in 0..<carets.length() {
          carets[index] = carets[index].min(max_width)
        }
      None => ()
    }
    {
      size: Size::new(width~, height=input.font.size * 1.25),
      baseline: input.font.size * 0.8,
      caret_positions: carets,
    }
  })
}

///|
fn focus_text_conformance_field(runtime : RuntimeState) -> Unit {
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
}

///|
fn mixed_rich_text_conformance_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: _text => {
      RichTextDocument::new(blocks=[
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="你🙂 אבג",
              source_range=Some({ start: 2, end: 8 }),
            ),
          ],
          source_range=Some({ start: 0, end: 8 }),
          content_range=Some({ start: 2, end: 8 }),
        ),
      ])
    },
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 4.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
}

///|
test "fallback text system conforms for unicode samples" {
  let system = TextSystem::fallback()
  let font = FontSpec::new(size=16.0, weight=400)
  assert_text_layout_invariants(system, "", font)
  assert_text_layout_invariants(system, "abc", font)
  assert_text_layout_invariants(system, "你好", font)
  assert_text_layout_invariants(system, "🙂", font)
  assert_text_layout_invariants(system, "a你🙂b", font)
  assert_text_layout_invariants(system, "abc אבג def", font)
}

///|
test "text field conformance covers cjk emoji replacement and deletion" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("a你🙂b")))
  inspect(state.get(), content="a你🙂b")
  inspect(runtime.focused_text_input().caret, content="4")
  runtime.dispatch_event(TextInput(DeleteRange(TextRange::new(start=1, end=3))))
  inspect(state.get(), content="ab")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="End", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("你好🙂")))
  inspect(state.get(), content="你好🙂")
  inspect(runtime.focused_text_input().caret, content="3")
}

///|
test "text field conformance keeps mixed bidi caret movement logical" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=240.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("abc אבג def")))
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  inspect(runtime.focused_text_input().caret, content="9")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="7")
  guard input.selection is Some(selection) else {
    fail("expected bidi logical selection")
  }
  inspect(selection.normalized().start, content="7")
  inspect(selection.normalized().end, content="9")
  runtime.dispatch_event(TextInput(InsertText("ZZ")))
  inspect(state.get(), content="abc אבגZZef")
}

///|
test "text field ime anchor follows unicode composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=200.0, height=60.0),
  )
  runtime.set_text_system(fixed_advance_text_system(7.0))
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你🙂a",
          cursor=Some(TextRange::new(start=2, end=2)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  guard input.composition is Some(composition) else {
    fail("expected unicode composition")
  }
  inspect(composition, content="你🙂a")
  inspect(input.caret_rect.origin.x, content="24")
}

///|
test "rich text conformance maps unicode source carets and selections" {
  let source = State::new("# 你🙂 אבג")
  let runtime = RuntimeState::new_spec(
    root=mixed_rich_text_conformance_editor(source.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.set_text_system(fixed_advance_text_system(8.0))
  focus_text_conformance_field(runtime)
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
  inspect(input.caret_rect.origin.x, content="14")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let selected = runtime.focused_text_input()
  guard selected.selection is Some(selection) else {
    fail("expected rich text unicode selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="4")
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        FillRect(_, color) => color == Color::blue().with_alpha(0.18)
        _ => false
      }
    }),
  )
  let content = rich_text_editor_content_rect(
    Rect::new(x=0.0, y=0.0, width=320.0, height=220.0),
  )
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(
          text="你🙂 אבג",
          source_range=Some({ start: 2, end: 8 }),
        ),
      ],
      source_range=Some({ start: 0, end: 8 }),
      content_range=Some({ start: 2, end: 8 }),
    ),
  ])
  guard rich_text_document_caret_rect_at_source(
      document,
      8,
      content,
      FontSpec::new(size=16.0, weight=400),
      text_system=fixed_advance_text_system(8.0),
    )
    is Some(end_rect) else {
    fail("expected mapped unicode rich text caret")
  }
  inspect(end_rect.origin.x, content="62")
}
