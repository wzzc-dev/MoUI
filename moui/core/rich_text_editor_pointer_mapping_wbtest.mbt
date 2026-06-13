///|
test "rich text editor pointer maps visual text to source offset" {
  let source = State::new("# Title")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::RichTextEditorSpec({
      key: None,
      value: source.binding(),
      placeholder: "Write",
      size: Size::new(width=320.0, height=220.0),
      format: _text => {
        RichTextDocument::new(blocks=[
          RichTextBlock::new(
            runs=[
              RichTextRun::new(
                text="Title",
                source_range=Some({ start: 2, end: 7 }),
              ),
            ],
            source_range=Some({ start: 0, end: 7 }),
            content_range=Some({ start: 2, end: 7 }),
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
    }),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=15.0, y=16.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
}

///|
test "rich text editor pointer maps visual list prefix to content start" {
  let source = State::new("- [ ] task")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::RichTextEditorSpec({
      key: None,
      value: source.binding(),
      placeholder: "Write",
      size: Size::new(width=320.0, height=220.0),
      format: _text => {
        RichTextDocument::new(blocks=[
          RichTextBlock::new(
            runs=[
              RichTextRun::new(
                text="task",
                source_range=Some({ start: 6, end: 10 }),
              ),
            ],
            prefix="☐ ",
            source_range=Some({ start: 0, end: 10 }),
            content_range=Some({ start: 6, end: 10 }),
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
    }),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=15.0, y=16.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "rich text editor selection highlight uses mapped visual range" {
  let source = State::new("# Title")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::RichTextEditorSpec({
      key: None,
      value: source.binding(),
      placeholder: "Write",
      size: Size::new(width=320.0, height=220.0),
      format: _text => {
        RichTextDocument::new(blocks=[
          RichTextBlock::new(
            runs=[
              RichTextRun::new(
                text="Title",
                source_range=Some({ start: 2, end: 7 }),
              ),
            ],
            source_range=Some({ start: 0, end: 7 }),
            content_range=Some({ start: 2, end: 7 }),
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
    }),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=15.0, y=16.0),
        phase=PointerPhase::Down,
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
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  let mut highlight : Rect? = None
  for command in commands {
    match command {
      FillRect(rect, color) =>
        if color == Color::blue().with_alpha(0.18) {
          highlight = Some(rect)
        }
      _ => ()
    }
  }
  match highlight {
    Some(rect) => {
      let font = FontSpec::new(size=16.0, weight=400)
      let source_prefix_width = TextSystem::fallback().measure_text(
          TextLayoutInput::new(text="# Ti", font~),
        ).size.width
      assert_true(rect.size.width < source_prefix_width)
      assert_true(rect.origin.x >= 14.0)
    }
    None => fail("expected rich text selection highlight")
  }
}

///|
test "rich text editor drag selects mapped source range" {
  let source = State::new("# Title")
  let changed = State::new(false)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::RichTextEditorSpec({
      key: None,
      value: source.binding(),
      placeholder: "Write",
      size: Size::new(width=320.0, height=220.0),
      format: _text => {
        RichTextDocument::new(blocks=[
          RichTextBlock::new(
            runs=[
              RichTextRun::new(
                text="Title",
                source_range=Some({ start: 2, end: 7 }),
              ),
            ],
            source_range=Some({ start: 0, end: 7 }),
            content_range=Some({ start: 2, end: 7 }),
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
      on_selection_change: Some((_caret, selection) => {
        match selection {
          Some(range) =>
            if range.normalized().start == 2 && range.normalized().end == 7 {
              changed.set(true)
            }
          None => ()
        }
      }),
      on_prefix_click: None,
      input_transform: None,
      accepts_tab_input: false,
    }),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=15.0, y=16.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=310.0, y=16.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  guard input.selection is Some(selection) else {
    fail("expected drag selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="7")
  inspect(changed.get(), content="true")
}
