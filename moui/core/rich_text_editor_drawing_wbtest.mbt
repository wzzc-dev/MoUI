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
  let block = document.blocks[0]
  let line_height = rich_text_block_line_height(block, font)
  append_rich_text_block_commands(
    commands,
    block,
    Rect::new(
      x=10.0,
      y=20.0,
      width=260.0,
      height=line_height + block.inset.top + block.inset.bottom,
    ),
    line_height,
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
  let block = document.blocks[0]
  let line_height = rich_text_block_line_height(block, font)
  append_rich_text_block_commands(
    commands,
    block,
    Rect::new(
      x=20.0,
      y=30.0,
      width=220.0,
      height=line_height + block.inset.top + block.inset.bottom,
    ),
    line_height,
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
