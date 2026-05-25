///|
test "markdown editor snapshot tracks typora core document shape" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "# Title\n\nParagraph with **bold**\n- [x] done\n```\nlet x = 1\n```",
  )
  inspect(snapshot.active_heading, content="Title")
  inspect(snapshot.line_count, content="7")
  inspect(snapshot.blocks.length(), content="4")
  guard snapshot.blocks[0]
    is {
      block: { kind: Heading(1), text: "Title", .. },
      source_range: { start: 0, end: 7 },
      content_range: { start: 2, end: 7 },
    } else {
    fail("expected heading source mapping")
  }
  guard snapshot.blocks[2]
    is {
      block: { kind: TaskListItem(true), text: "done", .. },
      content_range: { start, end },
      ..,
    } else {
    fail("expected task block mapping")
  }
  inspect(start, content="39")
  inspect(end, content="43")
  guard snapshot.blocks[3].block.kind is CodeBlock else {
    fail("expected fenced code block")
  }
  inspect(snapshot.rich_text.blocks.length(), content="4")
}

///|
test "markdown editor snapshot resolves reference links and images" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "See [MoUI][site] and ![Logo][logo]\n\n[site]: https://moui.dev\n[logo]: assets/logo.png",
  )
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0].block.inlines[1]
    is {
      kind: MarkdownInlineKind::Link,
      text: "MoUI",
      target: Some("https://moui.dev"),
    } else {
    fail("expected resolved reference link")
  }
  guard snapshot.blocks[0].block.inlines[3]
    is {
      kind: MarkdownInlineKind::Image,
      text: "Logo",
      target: Some("assets/logo.png"),
    } else {
    fail("expected resolved reference image")
  }
  guard snapshot.rich_text.blocks[0].runs[1]
    is { text: "MoUI", font: Some({ weight: 500, .. }), .. } else {
    fail("expected styled rich link")
  }
  guard snapshot.rich_text.blocks[0].runs[3]
    is { image_source: Some("assets/logo.png"), .. } else {
    fail("expected rich image source")
  }
}

///|
test "markdown editor snapshot tracks footnotes" {
  let snapshot = MarkdownEditorSnapshot::parse(
    "Paragraph with note[^1].\n\n[^1]: Footnote body",
  )
  inspect(snapshot.blocks.length(), content="2")
  guard snapshot.blocks[0].block.inlines[1]
    is { kind: MarkdownInlineKind::FootnoteReference, text: "1", .. } else {
    fail("expected footnote reference inline")
  }
  guard snapshot.blocks[1]
    is {
      block: {
        kind: FootnoteDefinition("1"),
        text: "Footnote body",
        inlines: [{ text: "Footnote body", .. }],
        ..,
      },
      source_range: { start: 26, end: 45 },
      content_range: { start: 32, end: 45 },
    } else {
    fail("expected footnote definition mapping")
  }
  guard snapshot.rich_text.blocks[0].runs[1]
    is {
      text: "[^1]",
      visual_text: Some("1"),
      source_range: Some({ start: 19, end: 23 }),
      ..,
    } else {
    fail("expected rich footnote reference marker")
  }
  guard snapshot.rich_text.blocks[1]
    is {
      border_left: Some(_),
      runs: [
        {
          visual_text: Some("1"),
          source_range: Some({ start: 26, end: 32 }),
          ..,
        },
        {
          text: "Footnote body",
          source_range: Some({ start: 32, end: 45 }),
          ..,
        },
      ],
      ..,
    } else {
    fail("expected rich footnote definition")
  }
}

///|
test "markdown editor snapshot tracks long fenced code blocks" {
  let snapshot = MarkdownEditorSnapshot::parse("````moonbit\n```\n````")
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0]
    is {
      block: {
        kind: CodeBlock,
        text: "```",
        code_language: Some("moonbit"),
        ..,
      },
      source_range: { start: 0, end: 20 },
      content_range: { start: 12, end: 16 },
    } else {
    fail("expected long fenced code block")
  }
  inspect(snapshot.rich_text.blocks.length(), content="1")
  guard snapshot.rich_text.blocks[0].runs
    is [{ text: "moonbit", .. }, { text: "\n```", .. }] else {
    fail("expected language label before code content")
  }
}

///|
test "markdown editor snapshot tracks setext headings" {
  let snapshot = MarkdownEditorSnapshot::parse("Title\n=====\nSection\n---")
  inspect(snapshot.blocks.length(), content="2")
  guard snapshot.blocks[0]
    is {
      block: { kind: Heading(1), text: "Title", .. },
      source_range: { start: 0, end: 11 },
      content_range: { start: 0, end: 5 },
    } else {
    fail("expected setext h1 mapping")
  }
  guard snapshot.blocks[1]
    is {
      block: { kind: Heading(2), text: "Section", .. },
      source_range: { start: 12, end: 23 },
      content_range: { start: 12, end: 19 },
    } else {
    fail("expected setext h2 mapping")
  }
  inspect(snapshot.active_heading, content="Title")
  inspect(snapshot.outline.length(), content="2")
  inspect(snapshot.outline[0].level, content="1")
  inspect(snapshot.outline[0].title, content="Title")
  inspect(snapshot.outline[0].source_start, content="0")
  inspect(snapshot.outline[1].level, content="2")
  inspect(snapshot.outline[1].title, content="Section")
  inspect(snapshot.outline[1].source_start, content="12")
  inspect(snapshot.rich_text.blocks.length(), content="2")
}

///|
test "markdown editor snapshot estimates reading time" {
  inspect(MarkdownEditorSnapshot::parse("").reading_minutes, content="0")
  inspect(MarkdownEditorSnapshot::parse("one two").reading_minutes, content="1")
  let words : Array[String] = []
  for index in 0..<221 {
    words.push("w" + index.to_string())
  }
  inspect(
    MarkdownEditorSnapshot::parse(words.join(" ")).reading_minutes,
    content="2",
  )
}

///|
test "markdown editor snapshot tracks markdown tables" {
  let source = "| Name | Done |\n| :--- | ---: |\n| Core | yes |"
  let snapshot = MarkdownEditorSnapshot::parse(source)
  inspect(snapshot.blocks.length(), content="1")
  guard snapshot.blocks[0].block.kind is Table else {
    fail("expected table block")
  }
  inspect(snapshot.blocks[0].block.text, content="Name  |  Done\nCore  |  yes")
  inspect(snapshot.blocks[0].source_range.start, content="0")
  inspect(snapshot.blocks[0].source_range.end, content="46")
  inspect(snapshot.blocks[0].content_range.start, content="0")
  inspect(snapshot.blocks[0].content_range.end, content="46")
  inspect(snapshot.rich_text.blocks.length(), content="1")
  guard snapshot.rich_text.blocks[0].runs
    is [{ text: "Name  |  Done\nCore  |  yes", .. }] else {
    fail("expected visual table text")
  }
  guard snapshot.rich_text.blocks[0].table is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="2")
  inspect(table.rows[0].length(), content="2")
  inspect(table.rows[1].length(), content="2")
  inspect(table.rows[0][0].text, content="Name")
  inspect(table.rows[0][0].header, content="true")
  guard table.rows[0][0].align is None else {
    fail("expected default start alignment")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextEnd) else {
    fail("expected trailing alignment")
  }
  guard table.rows[0][0].source_range is Some(first_range) else {
    fail("expected first table cell source range")
  }
  inspect(first_range.start, content="2")
  inspect(first_range.end, content="6")
  inspect(table.rows[1][0].text, content="Core")
  inspect(table.rows[1][0].header, content="false")
  guard table.rows[1][0].source_range is Some(body_range) else {
    fail("expected body table cell source range")
  }
  inspect(body_range.start, content="34")
  inspect(body_range.end, content="38")
  inspect(
    markdown_editor_active_block_label(source, { caret: 18, selection: None }),
    content="Table",
  )
}

///|
test "markdown editor renders table grid preview" {
  let app = MarkdownEditorApp::new()
  app.set_document("| Name | Done |\n| :---: | ---: |\n| Core | yes |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Name", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Core", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Name", align: @core.TextAlign::TextCenter, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Done", align: @core.TextAlign::TextEnd, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => command is @core.DrawCommand::StrokeRect(_, _, 1.0)),
  )
}

///|
test "markdown editor click maps table preview cells to markdown source" {
  let app = MarkdownEditorApp::new()
  app.set_document("| Name | Done |\n| --- | --- |\n| Core | yes |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let mut target : @core.Rect? = None
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::DrawText({ text: "yes", frame, .. }) =>
        target = Some(frame)
      _ => ()
    }
  }
  guard target is Some(frame) else { fail("expected rendered yes cell") }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let caret = runtime.focused_text_input().caret
  assert_true(caret >= 38)
  assert_true(caret <= 41)
}

///|
test "markdown editor formatter emits source ranges for visual mapping" {
  let document = markdown_editor_format("# Title\n- [ ] task")
  inspect(document.blocks.length(), content="2")
  guard document.blocks[0]
    is {
      source_range: Some({ start: 0, end: 7 }),
      content_range: Some({ start: 2, end: 7 }),
      runs: [{ source_range: Some({ start: 2, end: 7 }), .. }],
      ..,
    } else {
    fail("expected heading source ranges")
  }
  guard document.blocks[1]
    is {
      source_range: Some({ start: 8, end: 18 }),
      content_range: Some({ start: 14, end: 18 }),
      runs: [{ source_range: Some({ start: 14, end: 18 }), .. }],
      ..,
    } else {
    fail("expected task source ranges")
  }
  let nested = markdown_editor_format("  - [x] nested")
  guard nested.blocks[0]
    is {
      content_range: Some({ start: 8, end: 14 }),
      runs: [{ source_range: Some({ start: 8, end: 14 }), .. }],
      ..,
    } else {
    fail("expected nested task source ranges")
  }
}

///|
test "markdown editor formatter maps inline spans past hidden markers" {
  let document = markdown_editor_format("Text **bold** and `code`")
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs
    is [
      { text: "Text ", source_range: Some({ start: 0, end: 5 }), .. },
      { text: "bold", source_range: Some({ start: 7, end: 11 }), .. },
      { text: " and ", source_range: Some({ start: 13, end: 18 }), .. },
      { text: "code", source_range: Some({ start: 19, end: 23 }), .. },
    ] else {
    fail("expected inline source ranges to skip markdown delimiters")
  }
}

///|
test "markdown editor formatter maps link image and strike delimiters" {
  let document = markdown_editor_format(
    "Visit [MoUI](https://moui.dev), ![logo](logo.png), ~~old~~ and <https://moui.dev>",
  )
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs
    is [
      { text: "Visit ", source_range: Some({ start: 0, end: 6 }), .. },
      { text: "MoUI", source_range: Some({ start: 7, end: 11 }), .. },
      { text: ", ", source_range: Some({ start: 30, end: 32 }), .. },
      {
        text: "logo",
        visual_text: Some("logo"),
        image_source: Some("logo.png"),
        source_range: Some({ start: 34, end: 38 }),
        ..,
      },
      { text: ", ", source_range: Some({ start: 49, end: 51 }), .. },
      { text: "old", source_range: Some({ start: 53, end: 56 }), .. },
      { text: " and ", source_range: Some({ start: 58, end: 63 }), .. },
      {
        text: "https://moui.dev",
        source_range: Some({ start: 64, end: 80 }),
        ..,
      },
    ] else {
    fail(
      "expected source ranges to skip link image strike and autolink delimiters",
    )
  }
  guard document.blocks[0].runs[5].decoration
    is Some(@core.RichTextDecoration::Strikethrough) else {
    fail("expected strikethrough decoration")
  }
}

///|
test "markdown editor renders image preview while mapping alt text" {
  let app = MarkdownEditorApp::new()
  app.set_document("![logo](image.png)")
  let runtime = app.runtime(width=980.0, height=640.0)
  assert_true(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawImage({ source: "image.png", .. })
    }),
  )
  assert_false(
    runtime
    .draw_commands()
    .any(command => {
      command is @core.DrawCommand::DrawText({ text: "[image: logo]", .. })
    }),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let copied = runtime.dispatch_focused_text_command(@core.CommandIntent::Copy)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied image alt text")
  }
  inspect(text, content="logo")
}

///|
test "markdown editor click places caret after hidden heading marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("New ")),
  )
  inspect(app.document(), content="# New Title")
}

///|
test "markdown editor click maps inline formatted text to source offset" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=126.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  assert_true(runtime.focused_text_input().caret >= 7)
}

///|
test "markdown editor selection highlight uses formatted heading range" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => markdown_editor_is_selection_highlight(command)),
  )
}

///|
test "markdown editor drag selection tracks markdown source range" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=460.0, y=84.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  guard runtime.focused_text_input().selection is Some(selection) else {
    fail("expected drag selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="7")
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="# **Title**")
}

///|
fn markdown_editor_is_selection_highlight(command : @core.DrawCommand) -> Bool {
  match command {
    FillRect(_, color) => color.a == 0.18
    _ => false
  }
}

///|
test "markdown parser recognizes supported block and inline subset" {
  let blocks = parse_markdown(
    "# Title\n## Section\n### Detail\n#### Fine\n##### Small\n###### Caption\nText with **bold** and *italic* and `code` and [link](https://moui.dev) and ![alt](image.png) and ~~old~~\n- bullet\n- [ ] todo\n- [x] done\n1. one\n> quote\n---\n```\ncode\n```",
  )
  inspect(blocks.length(), content="14")
  guard blocks[0].kind is Heading(1) else { fail("expected h1") }
  guard blocks[1].kind is Heading(2) else { fail("expected h2") }
  guard blocks[2].kind is Heading(3) else { fail("expected h3") }
  guard blocks[3].kind is Heading(4) else { fail("expected h4") }
  guard blocks[4].kind is Heading(5) else { fail("expected h5") }
  guard blocks[5].kind is Heading(6) else { fail("expected h6") }
  guard blocks[6].kind is Paragraph else { fail("expected paragraph") }
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Bold),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Italic),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Code),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Link),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Image),
  )
  assert_true(
    blocks[6].inlines.any(span => span.kind == MarkdownInlineKind::Strikethrough),
  )
  guard blocks[7].kind is UnorderedListItem else {
    fail("expected unordered list")
  }
  guard blocks[8].kind is TaskListItem(false) else {
    fail("expected open task")
  }
  guard blocks[9].kind is TaskListItem(true) else {
    fail("expected checked task")
  }
  guard blocks[10].kind is OrderedListItem(1) else {
    fail("expected ordered list")
  }
  guard blocks[11].kind is Blockquote else { fail("expected quote") }
  guard blocks[12].kind is HorizontalRule else { fail("expected rule") }
  guard blocks[13].kind is CodeBlock else { fail("expected code block") }
}

///|
test "markdown parser recognizes tables as table blocks" {
  let blocks = parse_markdown("| Name | Done |\n| --- | --- |\n| Core | yes |")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: Table, text: "Name  |  Done\nCore  |  yes", .. } else {
    fail("expected table block")
  }
}

///|
test "markdown parser preserves malformed inline syntax as plain text" {
  let blocks = parse_markdown("Text with **open and `dangling\n+ plus list")
  inspect(blocks.length(), content="2")
  guard blocks[0].kind is Paragraph else {
    fail("expected malformed inline paragraph")
  }
  inspect(blocks[0].inlines.length(), content="1")
  guard blocks[0].inlines[0] is { kind: MarkdownInlineKind::Plain, text, .. } else {
    fail("expected plain malformed inline text")
  }
  inspect(text, content="Text with **open and `dangling")
  guard blocks[1].kind is Paragraph else {
    fail("expected plus list to stay paragraph")
  }
}

///|
test "markdown parser handles blank lines and unterminated code blocks" {
  let blocks = parse_markdown("\n\n```moonbit\nlet x = 1")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: CodeBlock, code_language: Some("moonbit"), .. } else {
    fail("expected trailing code block")
  }
  inspect(blocks[0].text, content="let x = 1")
}

///|
test "markdown parser recognizes star bullets and ordered list numbers" {
  let blocks = parse_markdown("* star\n42. answer")
  inspect(blocks.length(), content="2")
  guard blocks[0].kind is UnorderedListItem else {
    fail("expected star bullet")
  }
  guard blocks[1].kind is OrderedListItem(42) else {
    fail("expected ordered list number")
  }
  inspect(blocks[1].text, content="answer")
}

///|
test "markdown inline parser emits separated plain and styled spans" {
  let spans = parse_markdown_inlines("a **b** c `d` *e* __f__ _g_")
  inspect(spans.length(), content="10")
  guard spans[0] is { kind: MarkdownInlineKind::Plain, text: "a ", .. } else {
    fail("expected leading plain span")
  }
  guard spans[1] is { kind: MarkdownInlineKind::Bold, text: "b", .. } else {
    fail("expected bold span")
  }
  guard spans[3] is { kind: MarkdownInlineKind::Code, text: "d", .. } else {
    fail("expected code span")
  }
  guard spans[5] is { kind: MarkdownInlineKind::Italic, text: "e", .. } else {
    fail("expected italic span")
  }
  guard spans[7] is { kind: MarkdownInlineKind::Bold, text: "f", .. } else {
    fail("expected underscore bold span")
  }
  guard spans[9] is { kind: MarkdownInlineKind::Italic, text: "g", .. } else {
    fail("expected underscore italic span")
  }
}

///|
test "markdown inline parser preserves link image and strike metadata" {
  let spans = parse_markdown_inlines(
    "[MoUI](https://moui.dev) ![logo](logo.png) ~~old~~ <https://moui.dev>",
  )
  guard spans[0]
    is {
      kind: MarkdownInlineKind::Link,
      text: "MoUI",
      target: Some("https://moui.dev"),
    } else {
    fail("expected link target")
  }
  guard spans[2]
    is {
      kind: MarkdownInlineKind::Image,
      text: "logo",
      target: Some("logo.png"),
    } else {
    fail("expected image target")
  }
  guard spans[4] is { kind: MarkdownInlineKind::Strikethrough, text: "old", .. } else {
    fail("expected strikethrough")
  }
  guard spans[6]
    is {
      kind: MarkdownInlineKind::Autolink,
      text: "https://moui.dev",
      target: Some("https://moui.dev"),
    } else {
    fail("expected autolink target")
  }
}

///|
test "markdown parser preserves footnote metadata" {
  let blocks = parse_markdown("Text[^note]\n\n[^note]: Body text")
  inspect(blocks.length(), content="2")
  guard blocks[0].inlines[1]
    is { kind: MarkdownInlineKind::FootnoteReference, text: "note", .. } else {
    fail("expected footnote reference")
  }
  guard blocks[1]
    is {
      kind: FootnoteDefinition("note"),
      text: "Body text",
      inlines: [{ text: "Body text", .. }],
      ..,
    } else {
    fail("expected footnote definition block")
  }
}

///|
test "markdown parser preserves html block metadata" {
  let blocks = parse_markdown("<div>Block</div>")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: HtmlBlock, text: "<div>Block</div>", .. } else {
    fail("expected html block")
  }
}

///|
test "markdown parser preserves inline html tag metadata" {
  let spans = parse_markdown_inlines("Use <kbd>Esc</kbd> now")
  inspect(spans.length(), content="5")
  inspect(spans[0].text, content="Use ")
  inspect(markdown_editor_test_inline_kind_name(spans[1].kind), content="html")
  inspect(spans[1].text, content="<kbd>")
  inspect(spans[2].text, content="Esc")
  inspect(spans[3].text, content="</kbd>")
  inspect(spans[4].text, content=" now")
  guard spans[1].kind is MarkdownInlineKind::HtmlInline else {
    fail("expected opening html tag span")
  }
  guard spans[3].kind is MarkdownInlineKind::HtmlInline else {
    fail("expected closing html tag span")
  }
}

///|
test "markdown parser does not split inline html inside code or links" {
  let code = parse_markdown_inlines("Use `<kbd>` code")
  guard code[1] is { kind: MarkdownInlineKind::Code, text: "<kbd>", .. } else {
    fail("expected code span to keep html-looking source")
  }
  let link = parse_markdown_inlines("[<kbd>](https://example.com)")
  guard link[0]
    is {
      kind: MarkdownInlineKind::Link,
      text: "kbd",
      target: Some("https://example.com"),
    } else {
    fail("expected html-looking link text to stay a link")
  }
  let autolink = parse_markdown_inlines("Visit <https://example.com>")
  guard autolink[1]
    is {
      kind: MarkdownInlineKind::Autolink,
      text: "https://example.com",
      target: Some("https://example.com"),
    } else {
    fail("expected autolink to stay autolink")
  }
}

///|
fn markdown_editor_test_inline_kind_name(kind : MarkdownInlineKind) -> String {
  match kind {
    HtmlInline => "html"
    Plain => "plain"
    _ => "other"
  }
}

///|
test "markdown formatter produces rich text blocks and styled runs" {
  let document = markdown_to_rich_text(
    "# Title\n- item\n- [x] done\n> quote\n```moonbit\ncode\n```\n---",
  )
  inspect(document.blocks.length(), content="6")
  inspect(document.blocks[0].runs[0].text, content="Title")
  inspect(document.blocks[0].runs[0].font.unwrap().weight, content="700")
  inspect(document.blocks[1].prefix, content="• ")
  inspect(document.blocks[2].prefix, content="☑ ")
  assert_true(document.blocks[3].border_left is Some(_))
  assert_true(document.blocks[4].background is Some(_))
  inspect(document.blocks[4].runs[0].text, content="moonbit")
  inspect(document.blocks[4].runs[1].text, content="\ncode")
  assert_true(document.blocks[5].rule)
}

///|
test "markdown formatter renders footnotes as structured rich text" {
  let document = markdown_to_rich_text("Text[^a]\n\n[^a]: Footnote")
  inspect(document.blocks.length(), content="2")
  guard document.blocks[0].runs[1]
    is { text: "[^a]", visual_text: Some("a"), background: Some(_), .. } else {
    fail("expected styled footnote reference")
  }
  guard document.blocks[1]
    is {
      border_left: Some(_),
      runs: [{ visual_text: Some("a"), .. }, { text: "Footnote", .. }],
      ..,
    } else {
    fail("expected styled footnote definition")
  }
}

///|
test "markdown formatter renders html blocks as structured rich text" {
  let document = markdown_to_rich_text("<div>Block</div>")
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0]
    is {
      background: Some(_),
      runs: [{ text: "<div>Block</div>", font: Some({ families, .. }), .. }],
      ..,
    } else {
    fail("expected styled html block")
  }
  inspect(families.families.length() > 0, content="true")
}

///|
test "markdown formatter renders inline html tags as styled runs" {
  let blocks = parse_markdown("Use <kbd>Esc</kbd> now")
  inspect(blocks[0].inlines[1].text, content="<kbd>")
  let document = markdown_to_rich_text("Use <kbd>Esc</kbd> now")
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs.length(), content="5")
  inspect(document.blocks[0].runs[1].text, content="<kbd>")
  inspect(document.blocks[0].runs[1].background is Some(_), content="true")
  inspect(document.blocks[0].runs[1].font is Some(_), content="true")
  guard document.blocks[0].runs[1]
    is { text: "<kbd>", background: Some(_), font: Some({ size, .. }), .. } else {
    fail("expected styled opening html run")
  }
  guard document.blocks[0].runs[3]
    is { text: "</kbd>", background: Some(_), .. } else {
    fail("expected styled closing html run")
  }
  assert_true(size < @core.FontSpec::new().size)
}
