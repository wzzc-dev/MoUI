///|
fn test_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: text => RichTextDocument::plain(text),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 4.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
}

///|
fn styled_rich_text_editor(value : Binding[String]) -> ViewSpec {
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
              font=Some(FontSpec::new(size=22.0, weight=700)),
            ),
          ],
          line_height=Some(34.0),
        ),
        RichTextBlock::new(
          runs=[RichTextRun::new(text="item")],
          prefix="• ",
          line_height=Some(24.0),
        ),
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="old",
              decoration=Some(RichTextDecoration::Strikethrough),
            ),
          ],
          line_height=Some(24.0),
        ),
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="code",
              font=Some(
                FontSpec::new(
                  families=FontFamilyStack::monospace(),
                  size=14.0,
                  weight=400,
                ),
              ),
              background=Some(Brush::solid(Color::black().multiply_alpha(0.08))),
            ),
          ],
          background=Some(Brush::solid(Color::gray().multiply_alpha(0.2))),
          inset=Insets::symmetric(horizontal=8.0, vertical=4.0),
          line_height=Some(24.0),
          corner_radius=6.0,
        ),
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="logo",
              image_source=Some("logo.png"),
              image_size=Some(Size::new(width=64.0, height=36.0)),
            ),
          ],
          line_height=Some(24.0),
        ),
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
          line_height=Some(24.0),
        ),
      ])
    },
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 4.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
}

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
test "rich text document plain formatter preserves multiline text" {
  let document = RichTextDocument::plain("a\n\nb")
  inspect(document.blocks.length(), content="3")
  inspect(document.blocks[0].runs[0].text, content="a")
  inspect(document.blocks[1].runs[0].text, content="")
  inspect(document.blocks[2].runs[0].text, content="b")
}

///|
test "rich text editor enter inserts newline and vertical arrows move caret" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  runtime.dispatch_event(TextInput(InsertText("de")))
  inspect(state.get(), content="abc\nde")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowUp")))
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
}

///|
test "rich text editor home end and delete edit within multiline text" {
  let state = State::new("abc\ndef")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abc\nXdef")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="End")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="abc\nXde")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Delete")))
  inspect(state.get(), content="abc\nde")
}

///|
test "tab traverses rich text editor focus with other controls" {
  let first = State::new("")
  let second = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_rich_text_editor(first.binding()),
        test_rich_text_editor(second.binding()),
      ],
    }),
    size=Size::new(width=360.0, height=480.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(InsertText("first")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(InsertText("second")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("!")))
  inspect(first.get(), content="first!")
  inspect(second.get(), content="second")
}

///|
test "rich text editor ime composition commits canonical text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(CompositionUpdate(CompositionUpdate::new(text="ni", cursor=None))),
  )
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
}

///|
test "rich text editor ime composition replaces selection" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
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
  runtime.dispatch_event(TextInput(InsertText("abcd")))
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
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(CompositionUpdate::new(text="你", cursor=None)),
    ),
  )
  inspect(state.get(), content="abcd")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="ab你")
}

///|
test "rich text editor semantics is editable text field" {
  let state = State::new("Title")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  let semantics = runtime.semantics()
  assert_true(semantics.role == SemanticsRole::TextField)
  inspect(semantics.label, content="Write")
  inspect(semantics.value, content="Title")
  assert_true(
    semantics.actions.any(action => action == SemanticsAction::SetText),
  )
  assert_false(
    semantics.actions.any(action => action == SemanticsAction::Submit),
  )
}

///|
test "rich text editor draw commands contain styled runs and block decorations" {
  let state = State::new("styled")
  let commands = RuntimeState::new_spec(
    root=styled_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  ).build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawText({ text: "Title", font: { weight: 700, .. }, .. })
    }),
  )
  assert_true(
    commands.any(command => command is DrawText({ text: "• ", .. })),
  )
  assert_true(
    commands.any(command => command is DrawText({ text: "code", .. })),
  )
  assert_true(
    commands.any(command => {
      command
      is DrawImage(
        {
          source: "logo.png",
          frame: { size: { width: 64.0, height: 36.0 }, .. },
          ..,
        }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is DrawText({ text: "A", font: { weight: 700, .. }, .. })
    }),
  )
  assert_true(commands.any(command => command is StrokeRect(_, _, 1.0)))
  assert_true(commands.any(command => command is FillRoundedRectBrush(_, _)))
  assert_true(commands.any(command => rich_text_editor_is_strike_rect(command)))
}

///|
test "rich text block height counts embedded visual newlines" {
  let font = FontSpec::new(size=16.0, weight=400)
  let block = RichTextBlock::new(
    runs=[
      RichTextRun::new(text="moonbit"),
      RichTextRun::new(text="\nlet x = 1\nlet y = 2"),
    ],
    inset=Insets::symmetric(vertical=4.0),
    line_height=Some(20.0),
  )
  inspect(rich_text_block_line_height(block, font).to_int(), content="60")
  inspect(
    rich_text_document_height(RichTextDocument::new(blocks=[block]), font).to_int(),
    content="68",
  )
}

///|
test "rich text block draws embedded visual newlines on separate rows" {
  let commands : Array[DrawCommand] = []
  let font = FontSpec::new(size=16.0, weight=400)
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(text="moonbit"),
        RichTextRun::new(text="\nlet x = 1\n"),
      ],
      inset=Insets::symmetric(vertical=4.0),
      line_height=Some(20.0),
    ),
  ])
  append_rich_text_blocks(
    commands,
    document,
    Rect::new(x=10.0, y=20.0, width=260.0, height=120.0),
    font,
    Color::black(),
    TextSystem::fallback(),
  )
  let mut first_y = -1
  let mut second_y = -1
  for command in commands {
    match command {
      DrawText({ text: "moonbit", frame, .. }) =>
        first_y = frame.origin.y.to_int()
      DrawText({ text: "let x = 1", frame, .. }) =>
        second_y = frame.origin.y.to_int()
      _ => ()
    }
  }
  inspect(first_y, content="24")
  inspect(second_y, content="44")
}

///|
test "rich text caret geometry follows embedded visual newlines" {
  let font = FontSpec::new(size=16.0, weight=400)
  let content = Rect::new(x=10.0, y=20.0, width=260.0, height=120.0)
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(text="moonbit"),
        RichTextRun::new(text="\n", source_range=None),
        RichTextRun::new(
          text="let x = 1\n",
          source_range=Some({ start: 0, end: 10 }),
        ),
      ],
      line_height=Some(20.0),
      source_range=Some({ start: 0, end: 10 }),
      content_range=Some({ start: 0, end: 10 }),
    ),
  ])
  guard rich_text_document_caret_rect_at_source(document, 0, content, font)
    is Some(first_code_rect) else {
    fail("expected code caret rect")
  }
  guard rich_text_document_caret_rect_at_source(document, 10, content, font)
    is Some(blank_line_rect) else {
    fail("expected blank line caret rect")
  }
  inspect(first_code_rect.origin.y.to_int(), content="44")
  inspect(blank_line_rect.origin.y.to_int(), content="64")
}

///|
test "rich text block left border stays outside inset text" {
  let commands : Array[DrawCommand] = []
  let font = FontSpec::new(size=16.0, weight=400)
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[RichTextRun::new(text="quote")],
      border_left=Some(
        BorderStyle::new(brush=Brush::solid(Color::gray()), width=4.0),
      ),
      inset={ top: 5.0, right: 0.0, bottom: 7.0, left: 14.0 },
      line_height=Some(24.0),
    ),
  ])
  append_rich_text_blocks(
    commands,
    document,
    Rect::new(x=20.0, y=30.0, width=220.0, height=120.0),
    font,
    Color::black(),
    TextSystem::fallback(),
  )
  let mut border_rect : Rect? = None
  let mut text_frame : Rect? = None
  for command in commands {
    match command {
      FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width == 4.0 {
          border_rect = Some(rect)
        }
      DrawText({ text: "quote", frame, .. }) => text_frame = Some(frame)
      _ => ()
    }
  }
  guard border_rect is Some(border) else { fail("expected left border") }
  guard text_frame is Some(text) else { fail("expected quote text") }
  inspect(border.origin.x, content="20")
  inspect(border.origin.y, content="35")
  inspect(border.size.height, content="24")
  inspect(text.origin.x, content="34")
  assert_true(border.origin.x + border.size.width < text.origin.x)
}

///|
fn rich_text_editor_is_strike_rect(command : DrawCommand) -> Bool {
  match command {
    FillRect(rect, color) =>
      rect.size.height >= 1.0 && rect.size.height < 3.0 && color.a > 0.5
    _ => false
  }
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

///|
test "rich text editor input transform can intercept backspace" {
  let state = State::new("# Title")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::RichTextEditorSpec({
      key: None,
      value: state.binding(),
      placeholder: "Write",
      size: Size::new(width=320.0, height=220.0),
      format: text => RichTextDocument::plain(text),
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
      input_transform: Some((text, _caret, _selection, input) => {
        if input == "\u{0008}" {
          Some(RichTextInputTransform::new(text=text[2:].to_owned(), caret=0))
        } else {
          None
        }
      }),
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="End")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="Title")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "rich text editor placeholder and focus cursor render from empty state" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  let initial = runtime.build_draw_commands()
  assert_true(
    initial.any(command => command is DrawText({ text: "Write", .. })),
  )
  assert_false(initial.any(command => command is FillRect(_)))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let focused = runtime.build_draw_commands()
  assert_true(focused.any(command => command is FillRoundedRectBrush(_, _)))
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  assert_true(input.caret_rect.origin.x > input.frame.origin.x)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}
