///|
fn mapped_rich_text_editor(value : Binding[String]) -> ViewSpec {
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
              text="Title",
              source_range=Some({ start: 2, end: 7 }),
            ),
          ],
          source_range=Some({ start: 0, end: 7 }),
          content_range=Some({ start: 2, end: 7 }),
        ),
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="bold",
              source_range=Some({ start: 16, end: 20 }),
            ),
          ],
          prefix="☐ ",
          source_range=Some({ start: 10, end: 22 }),
          content_range=Some({ start: 16, end: 22 }),
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
fn table_mapped_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: _text => {
      RichTextDocument::new(blocks=[
        RichTextBlock::new(
          runs=[RichTextRun::new(text="A  |  B\n1  |  2")],
          table=Some({
            rows: [
              [
                {
                  text: "A",
                  header: true,
                  align: None,
                  source_range: Some({ start: 2, end: 3 }),
                },
                {
                  text: "B",
                  header: true,
                  align: Some(TextAlign::TextEnd),
                  source_range: Some({ start: 7, end: 8 }),
                },
              ],
              [
                {
                  text: "1",
                  header: false,
                  align: None,
                  source_range: Some({ start: 14, end: 15 }),
                },
                {
                  text: "2",
                  header: false,
                  align: Some(TextAlign::TextEnd),
                  source_range: Some({ start: 19, end: 20 }),
                },
              ],
            ],
            row_height: 28.0,
            cell_padding: Insets::symmetric(horizontal=6.0, vertical=4.0),
            border: Color::black().multiply_alpha(0.2),
            header_background: Some(
              Brush::solid(Color::gray().multiply_alpha(0.16)),
            ),
          }),
          source_range=Some({ start: 0, end: 21 }),
          content_range=Some({ start: 0, end: 21 }),
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
test "rich text editor copy uses visual text for mapped source ranges" {
  let state = State::new("# Title\n\n- [ ] **bold**")
  let runtime = RuntimeState::new_spec(
    root=mapped_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let copied = runtime.dispatch_focused_text_command(Copy)
  assert_true(copied.handled)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied visual text")
  }
  inspect(text, content="Title\nbold")
}

///|
test "rich text editor cut copies visual text and deletes source selection" {
  let state = State::new("# Title\n\n- [ ] **bold**")
  let runtime = RuntimeState::new_spec(
    root=mapped_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let cut = runtime.dispatch_focused_text_command(Cut)
  assert_true(cut.handled)
  assert_true(cut.changed)
  guard cut.clipboard_text is Some(text) else {
    fail("expected cut visual text")
  }
  inspect(text, content="Title\nbold")
  inspect(state.get(), content="")
}

///|
test "rich text editor caret uses source mapped visual text" {
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
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  let mapped_x = input.caret_rect.origin.x
  let font = FontSpec::new(size=16.0, weight=400)
  let source_end = input.frame.origin.x +
    14.0 +
    TextSystem::fallback().measure_text(
      TextLayoutInput::new(text="# Title", font~),
    ).size.width
  assert_true(mapped_x < source_end)
}

///|
test "rich text caret geometry helper maps source offsets" {
  let font = FontSpec::new(size=16.0, weight=400)
  let content = rich_text_editor_content_rect(
    Rect::new(x=0.0, y=0.0, width=320.0, height=220.0),
  )
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(text="Title", source_range=Some({ start: 2, end: 7 })),
      ],
      source_range=Some({ start: 0, end: 7 }),
      content_range=Some({ start: 2, end: 7 }),
    ),
  ])
  guard rich_text_document_caret_rect_at_source(document, 2, content, font)
    is Some(start_rect) else {
    fail("expected start caret rect")
  }
  guard rich_text_document_caret_rect_at_source(document, 7, content, font)
    is Some(end_rect) else {
    fail("expected end caret rect")
  }
  inspect(start_rect.origin.x, content="14")
  assert_true(end_rect.origin.x > start_rect.origin.x)
}

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

///|
test "rich text editor click maps rich table cells to source ranges" {
  let source = State::new("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = RuntimeState::new_spec(
    root=table_mapped_rich_text_editor(source.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=250.0, y=54.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  assert_true(input.caret >= 19)
  assert_true(input.caret <= 20)
}
