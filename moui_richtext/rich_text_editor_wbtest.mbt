///|
test "rich text run frame leaves right ink bleed" {
  let font = @core.FontSpec::new(size=20.0)
  let text_system = @core.TextSystem::fallback()
  let text_width = rich_text_width("Today", font, text_system)
  let commands : Array[@core.DrawCommand] = []
  append_rich_text_block_commands(
    commands,
    RichTextBlock::new(runs=[RichTextRun::new(text="Today")]),
    @core.Rect::new(x=10.0, y=20.0, width=400.0, height=40.0),
    40.0,
    font,
    @core.Color::black(),
    text_system~,
  )
  guard commands.length() == 1 else {
    fail("expected one rich text draw command")
  }
  guard commands[0] is @core.DrawCommand::DrawText({ text: "Today", frame, .. }) else {
    fail("expected Today text command")
  }
  assert_true(frame.origin.x == 10.0)
  assert_true(frame.size.width > text_width)
  assert_true(frame.size.width <= 400.0)
}

///|
test "rich text editor wheel event emits a controlled scroll message" {
  let source = rich_text_scroll_test_source()
  let font = @core.FontSpec::new(size=14.0)
  let observed = Ref(0.0)
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=0.0,
      update=(_model, next) => {
        observed.val = next
        next
      },
      view=scroll_y => {
        controlled_rich_text_editor(
          value=source,
          on_input=_ => scroll_y,
          placeholder="",
          size=@core.Size::new(width=320.0, height=80.0),
          format=rich_text_scroll_test_document,
          font~,
          foreground=@core.Color::black(),
          placeholder_color=@core.Color::black(),
          background=@core.Brush::solid(@core.Color::white()),
          cursor_color=@core.Color::black(),
          visible_scroll_y=scroll_y,
          on_scroll=Some(next => next),
          visible_viewport_height=80.0,
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=80.0),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-48.0),
      ),
    ),
  )
  assert_true(observed.val > 0.0)
}

///|
/// Playground-style path: content is already translated by -scroll_y before
/// layering. Culling must use visible_scroll_y=0 against the untranslated clip,
/// otherwise the visible band misses every block and the editor paints blank.
test "rich text editor scrolled content culls against paint coordinates" {
  let font = @core.FontSpec::new(size=14.0)
  let text_system = @core.TextSystem::fallback()
  let document = rich_text_scroll_test_document(rich_text_scroll_test_source())
  let clip = @core.Rect::new(x=0.0, y=0.0, width=320.0, height=80.0)
  let scroll_y = 120.0
  let content = rich_text_scrolled_content_rect(
    clip,
    scroll_y~,
    visible_viewport_height=80.0,
  )
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    font,
    @core.Color::black(),
    text_system~,
    visible_scroll_y=0.0,
    visible_viewport_height=80.0,
    visible_overscan=40.0,
    clip_rect=Some(clip),
  )
  assert_true(layers.length() > 0)
  assert_true(layers.length() < document.blocks.length())
  for layer in layers {
    // Every retained block must intersect the viewport (plus overscan bleed).
    let bottom = layer.frame.origin.y + layer.frame.size.height
    assert_true(bottom >= clip.origin.y - 40.0)
    assert_true(layer.frame.origin.y <= clip.origin.y + clip.size.height + 40.0)
  }
}

///|
fn rich_text_scroll_test_source() -> String {
  let lines : Array[String] = []
  for index in 0..<24 {
    lines.push("line " + index.to_string())
  }
  lines.join("\n")
}

///|
fn rich_text_scroll_test_document(source : String) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  for line in source.split("\n") {
    blocks.push(
      RichTextBlock::new(
        runs=[RichTextRun::new(text=line.to_owned())],
        line_height=Some(20.0),
      ),
    )
  }
  RichTextDocument::new(blocks~)
}
