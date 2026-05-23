///|
test "markdown editor app emits primary wysiwyg commands" {
  let app = @app.MarkdownEditorApp::new()
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Editor notes", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Editor notes", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "• ", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor toggles source preview from action" {
  let app = @app.MarkdownEditorApp::new()
  inspect(app.source_preview_visible(), content="false")
  app.apply_action("source-preview")
  inspect(app.source_preview_visible(), content="true")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

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
  inspect(snapshot.rich_text.blocks.length(), content="2")
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
  let app = @app.MarkdownEditorApp::new()
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
  let app = @app.MarkdownEditorApp::new()
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
  let app = @app.MarkdownEditorApp::new()
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
        position=@core.Point::new(x=28.0, y=184.0),
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
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
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
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=126.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  assert_true(runtime.focused_text_input().caret >= 7)
}

///|
test "markdown editor selection highlight uses formatted heading range" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
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
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=460.0, y=184.0),
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
test "markdown editor core applies typed commands" {
  inspect(markdown_editor_apply_command("", Heading(2)), content="## Section")
  inspect(
    markdown_editor_apply_command("", Heading(6)),
    content="###### Caption",
  )
  inspect(markdown_editor_apply_command("", HorizontalRule), content="---")
  inspect(
    markdown_editor_apply_command("Base", Bold),
    content="Base\n\n**bold text**",
  )
  inspect(markdown_editor_apply_command("Base", Clear), content="")
}

///|
test "markdown editor inline command wraps selected source range" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    Bold,
    Some({ caret: 7, selection: Some(@core.TextRange::new(start=2, end=7)) }),
  )
  inspect(result.source, content="# **Title**")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected updated selection")
  }
  inspect(selection.start, content="4")
  inspect(selection.end, content="9")
}

///|
test "markdown editor typed inline marker wraps selected source range" {
  let bold = markdown_editor_transform_input(
    "Text bold tail",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "**",
  ).unwrap()
  inspect(bold.text, content="Text **bold** tail")
  inspect(bold.caret, content="11")
  guard bold.selection is Some(bold_selection) else {
    fail("expected bold selection")
  }
  inspect(bold_selection.start, content="7")
  inspect(bold_selection.end, content="11")
  let code = markdown_editor_transform_input(
    "Use code now",
    8,
    Some(@core.TextRange::new(start=4, end=8)),
    "`",
  ).unwrap()
  inspect(code.text, content="Use `code` now")
  let strike = markdown_editor_transform_input(
    "old text",
    3,
    Some(@core.TextRange::new(start=0, end=3)),
    "~~",
  ).unwrap()
  inspect(strike.text, content="~~old~~ text")
}

///|
test "markdown editor typed inline marker unwraps selected formatted range" {
  let result = markdown_editor_transform_input(
    "Text **bold** tail",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "**",
  ).unwrap()
  inspect(result.text, content="Text bold tail")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected unwrapped selection")
  }
  inspect(selection.start, content="5")
  inspect(selection.end, content="9")
}

///|
test "markdown editor paste url wraps or updates selected link text" {
  let wrapped = markdown_editor_transform_input(
    "Visit MoUI today",
    10,
    Some(@core.TextRange::new(start=6, end=10)),
    "https://moui.dev",
  ).unwrap()
  inspect(wrapped.text, content="Visit [MoUI](https://moui.dev) today")
  inspect(wrapped.caret, content="11")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected wrapped link selection")
  }
  inspect(wrapped_selection.start, content="7")
  inspect(wrapped_selection.end, content="11")
  let updated = markdown_editor_transform_input(
    wrapped.text,
    11,
    Some(wrapped_selection),
    "https://docs.moui.dev",
  ).unwrap()
  inspect(updated.text, content="Visit [MoUI](https://docs.moui.dev) today")
  guard updated.selection is Some(updated_selection) else {
    fail("expected updated link selection")
  }
  inspect(updated_selection.start, content="7")
  inspect(updated_selection.end, content="11")
  inspect(
    markdown_editor_transform_input(
      "Visit MoUI today",
      10,
      Some(@core.TextRange::new(start=6, end=10)),
      "https://moui.dev/docs page",
    )
    is None,
    content="true",
  )
}

///|
test "markdown editor paste image source wraps or updates selected alt text" {
  let wrapped = markdown_editor_transform_input(
    "Insert logo here",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "assets/logo.png",
  ).unwrap()
  inspect(wrapped.text, content="Insert ![logo](assets/logo.png) here")
  inspect(wrapped.caret, content="13")
  guard wrapped.selection is Some(wrapped_selection) else {
    fail("expected wrapped image selection")
  }
  inspect(wrapped_selection.start, content="9")
  inspect(wrapped_selection.end, content="13")
  let updated = markdown_editor_transform_input(
    wrapped.text,
    13,
    Some(wrapped_selection),
    "https://cdn.example/logo.webp",
  ).unwrap()
  inspect(
    updated.text,
    content="Insert ![logo](https://cdn.example/logo.webp) here",
  )
  guard updated.selection is Some(updated_selection) else {
    fail("expected updated image selection")
  }
  inspect(updated_selection.start, content="9")
  inspect(updated_selection.end, content="13")
}

///|
test "markdown editor paste and typed space complete autolinks" {
  let pasted = markdown_editor_transform_input(
    "Visit ",
    6,
    None,
    "https://moui.dev",
  ).unwrap()
  inspect(pasted.text, content="Visit <https://moui.dev>")
  inspect(pasted.caret, content="24")
  let typed = markdown_editor_transform_input(
    "Visit https://moui.dev",
    22,
    None,
    " ",
  ).unwrap()
  inspect(typed.text, content="Visit <https://moui.dev> ")
  inspect(typed.caret, content="25")
  inspect(
    markdown_editor_transform_input("Visit <https://moui.dev>", 23, None, " ")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\nhttps://moui.dev\n```", 20, None, " ")
    is None,
    content="true",
  )
}

///|
test "markdown editor inline command unwraps matching marker pair" {
  let bold = markdown_editor_apply_command_at(
    "Text **bold** tail",
    Bold,
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(bold.source, content="Text bold tail")
  inspect(bold.caret, content="9")
  guard bold.selection is Some(bold_selection) else {
    fail("expected unwrapped bold selection")
  }
  inspect(bold_selection.start, content="5")
  inspect(bold_selection.end, content="9")
  let code = markdown_editor_apply_command_at(
    "Use `code` now",
    Code,
    Some({ caret: 9, selection: Some(@core.TextRange::new(start=5, end=9)) }),
  )
  inspect(code.source, content="Use code now")
  inspect(code.caret, content="8")
  let strike = markdown_editor_apply_command_at(
    "~~old~~ text",
    Strikethrough,
    Some({ caret: 5, selection: Some(@core.TextRange::new(start=2, end=5)) }),
  )
  inspect(strike.source, content="old text")
}

///|
test "markdown editor link command wraps and unwraps selected text" {
  let linked = markdown_editor_apply_command_at(
    "Visit MoUI today",
    Link,
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(linked.source, content="Visit [MoUI](https://example.com) today")
  guard linked.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
  let unlinked = markdown_editor_apply_command_at(
    linked.source,
    Link,
    Some({ caret: 11, selection: Some(selection) }),
  )
  inspect(unlinked.source, content="Visit MoUI today")
  guard unlinked.selection is Some(unlinked_selection) else {
    fail("expected unlinked selection")
  }
  inspect(unlinked_selection.start, content="6")
  inspect(unlinked_selection.end, content="10")
}

///|
test "markdown editor image command wraps and unwraps selected alt text" {
  let inserted = markdown_editor_apply_command_at(
    "Insert logo here",
    Image,
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(inserted.source, content="Insert ![logo](image.png) here")
  guard inserted.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
  let unwrapped = markdown_editor_apply_command_at(
    inserted.source,
    Image,
    Some({ caret: 13, selection: Some(selection) }),
  )
  inspect(unwrapped.source, content="Insert logo here")
  guard unwrapped.selection is Some(unwrapped_selection) else {
    fail("expected unwrapped image alt selection")
  }
  inspect(unwrapped_selection.start, content="7")
  inspect(unwrapped_selection.end, content="11")
}

///|
test "markdown editor link target command updates and wraps selected text" {
  let updated = markdown_editor_apply_command_at(
    "Visit [MoUI](https://example.com) today",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(updated.source, content="Visit [MoUI](https://moui.dev) today")
  guard updated.selection is Some(selection) else {
    fail("expected updated link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
  let wrapped = markdown_editor_apply_command_at(
    "Visit MoUI today",
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=6, end=10)) }),
  )
  inspect(wrapped.source, content="Visit [MoUI](https://moui.dev) today")
}

///|
test "markdown editor link target command updates reference definition" {
  let source = "Visit [MoUI][site] today\n\n[site]: https://example.com"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://example.com") else {
    fail("expected selected reference link target")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor link target command creates missing reference definition" {
  let source = "Visit [MoUI][site] today"
  let updated = markdown_editor_apply_command_at(
    source,
    SetLinkTarget("https://moui.dev"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(
    updated.source,
    content="Visit [MoUI][site] today\n\n[site]: https://moui.dev",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference link text selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor reads selected link and image targets" {
  let source = "Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)"
  guard markdown_editor_selected_link_target(source, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=7, end=11)),
    })
    is Some("https://moui.dev") else {
    fail("expected selected link target")
  }
  guard markdown_editor_selected_image_target(source, {
      caret: 41,
      selection: Some(@core.TextRange::new(start=37, end=41)),
    })
    is Some("assets/logo.png") else {
    fail("expected selected image target")
  }
  inspect(
    markdown_editor_selected_link_target(source, {
      caret: 5,
      selection: Some(@core.TextRange::new(start=0, end=5)),
    })
    is None,
    content="true",
  )
}

///|
test "markdown editor code language command updates fenced block" {
  let source = "Intro\n```moonbit\nlet x = 1\n```\nTail"
  guard markdown_editor_selected_code_language(source, {
      caret: 20,
      selection: None,
    })
    is Some("moonbit") else {
    fail("expected selected code language")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetCodeLanguage("rust"),
    Some({ caret: 20, selection: None }),
  )
  inspect(updated.source, content="Intro\n```rust\nlet x = 1\n```\nTail")
  inspect(updated.caret, content="17")
  let cleared = markdown_editor_apply_command_at(
    updated.source,
    SetCodeLanguage(""),
    Some({ caret: 17, selection: None }),
  )
  inspect(cleared.source, content="Intro\n```\nlet x = 1\n```\nTail")
  inspect(cleared.caret, content="13")
}

///|
test "markdown editor image target command updates and wraps selected alt text" {
  let updated = markdown_editor_apply_command_at(
    "Insert ![logo](image.png) here",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(updated.source, content="Insert ![logo](assets/logo.png) here")
  guard updated.selection is Some(selection) else {
    fail("expected updated image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
  let wrapped = markdown_editor_apply_command_at(
    "Insert logo here",
    SetImageTarget("assets/logo.png"),
    Some({ caret: 11, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(wrapped.source, content="Insert ![logo](assets/logo.png) here")
}

///|
test "markdown editor image target command updates reference definition" {
  let source = "Insert ![logo][mark] here\n\n[mark]: old.png"
  guard markdown_editor_selected_image_target(source, {
      caret: 13,
      selection: Some(@core.TextRange::new(start=9, end=13)),
    })
    is Some("old.png") else {
    fail("expected selected reference image target")
  }
  let updated = markdown_editor_apply_command_at(
    source,
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(
    updated.source,
    content="Insert ![logo][mark] here\n\n[mark]: assets/logo.png",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor image target command creates missing reference definition" {
  let source = "Insert ![logo][mark] here"
  let updated = markdown_editor_apply_command_at(
    source,
    SetImageTarget("assets/logo.png"),
    Some({ caret: 13, selection: Some(@core.TextRange::new(start=9, end=13)) }),
  )
  inspect(
    updated.source,
    content="Insert ![logo][mark] here\n\n[mark]: assets/logo.png",
  )
  guard updated.selection is Some(selection) else {
    fail("expected reference image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor image command seeds an image snippet" {
  inspect(
    markdown_editor_apply_command("", Image),
    content="![image alt](image.png)",
  )
}

///|
test "markdown editor app inline command uses tracked selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title")
  app.set_selection(7, Some(@core.TextRange::new(start=2, end=7)))
  app.apply_command_to_selection(Code)
  inspect(app.document(), content="# `Title`")
}

///|
test "markdown editor app inline command toggles tracked formatted selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor app undo and redo structured formatting commands" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text **bold**")
  assert_true(app.can_undo())
  assert_false(app.can_redo())
  assert_true(app.undo())
  inspect(app.document(), content="Text bold")
  assert_true(app.can_redo())
  assert_true(app.redo())
  inspect(app.document(), content="Text **bold**")
}

///|
test "markdown editor app undo and redo target edits" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  assert_true(app.undo())
  inspect(app.document(), content="Visit [MoUI](https://old.example)")
  assert_true(app.redo())
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
}

///|
test "markdown editor app clears command history on document reset" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.set_document("Fresh")
  assert_false(app.can_undo())
  assert_false(app.undo())
  inspect(app.document(), content="Fresh")
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.clear()
  assert_false(app.can_undo())
}

///|
test "markdown editor app target inputs sync from selection and apply edits" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  inspect(app.block_label(), content="Paragraph")
  guard app.target_kind() is @app.MarkdownEditorTargetKind::PlainSelection else {
    fail("expected plain target mode")
  }
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  guard app.target_kind() is @app.MarkdownEditorTargetKind::LinkTarget else {
    fail("expected link target mode")
  }
  inspect(app.link_target(), content="https://old.example")
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](old.png)",
  )
  app.set_selection(41, Some(@core.TextRange::new(start=37, end=41)))
  guard app.target_kind() is @app.MarkdownEditorTargetKind::ImageTarget else {
    fail("expected image target mode")
  }
  inspect(app.image_target(), content="old.png")
  app.set_image_target("assets/logo.png")
  app.apply_image_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)",
  )
  app.set_selection(5, Some(@core.TextRange::new(start=0, end=5)))
  guard app.target_kind() is @app.MarkdownEditorTargetKind::PlainSelection else {
    fail("expected plain target mode after non-target selection")
  }
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  guard app.target_kind() is @app.MarkdownEditorTargetKind::TableTools else {
    fail("expected table tools mode")
  }
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  guard app.target_kind() is @app.MarkdownEditorTargetKind::CodeLanguageTarget else {
    fail("expected code language mode")
  }
  inspect(app.code_language(), content="moonbit")
  app.set_code_language("rust")
  app.apply_code_language()
  inspect(app.document(), content="```rust\nlet x = 1\n```")
}

///|
test "markdown editor app block label syncs from selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title\n- item\nPlain")
  app.set_selection(3, None)
  inspect(app.block_label(), content="Heading 1")
  app.set_selection(10, None)
  inspect(app.block_label(), content="Bullet list")
  app.apply_command_to_selection(Paragraph)
  inspect(app.document(), content="# Title\nitem\nPlain")
  inspect(app.block_label(), content="Paragraph")
}

///|
test "markdown editor target bar renders contextual controls" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  let plain = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    plain.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Select link or image text to edit its target", .. }
      )
    }),
  )
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let link = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
  assert_false(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_selection(44, Some(@core.TextRange::new(start=40, end=44)))
  let image = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    image.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  let table = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Table tools", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Center", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Auto", .. })
    }),
  )
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  let code = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Code lang", .. })
    }),
  )
}

///|
test "markdown editor runtime inline keyboard shortcut toggles selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime typed marker wraps tracked selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
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
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("**")),
  )
  inspect(app.document(), content="**bold**")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="6")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="2")
  inspect(selection.end, content="6")
}

///|
test "markdown editor runtime link strike and image shortcuts use tracked selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text link old logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text [link](https://example.com) old logo")
  app.set_selection(36, Some(@core.TextRange::new(start=33, end=36)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ logo",
  )
  app.set_selection(45, Some(@core.TextRange::new(start=41, end=45)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ ![logo](image.png)",
  )
}

///|
test "markdown editor runtime block keyboard shortcuts transform caret and selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Intro\nTitle\nFirst\nSecond")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="2",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n## Title\nFirst\nSecond")
  app.set_selection(9, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="6",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\nFirst\nSecond")
  app.set_selection(30, Some(@core.TextRange::new(start=19, end=31)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="u",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\n- First\n- Second")
}

///|
test "markdown editor task checkbox toggles by content offset" {
  let open = markdown_editor_toggle_task_at("- [ ] todo", 6).unwrap()
  inspect(open.source, content="- [x] todo")
  inspect(open.caret, content="6")
  let checked = markdown_editor_toggle_task_at("Intro\n- [x] done", 12).unwrap()
  inspect(checked.source, content="Intro\n- [ ] done")
  let nested = markdown_editor_toggle_task_at("  - [ ] nested", 8).unwrap()
  inspect(nested.source, content="  - [x] nested")
  inspect(nested.caret, content="8")
  inspect(markdown_editor_toggle_task_at("- item", 2) is None, content="true")
}

///|
test "markdown editor app toggles task checkbox by prefix offset" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [x] todo")
  app.toggle_task_at(6)
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor block command transforms current line" {
  let result = markdown_editor_apply_command_at(
    "Intro\nTitle\nBody",
    Heading(2),
    Some({ caret: 8, selection: None }),
  )
  inspect(result.source, content="Intro\n## Title\nBody")
  inspect(result.caret, content="11")
  let h6 = markdown_editor_apply_command_at(
    "Intro\nFine print\nBody",
    Heading(6),
    Some({ caret: 8, selection: None }),
  )
  inspect(h6.source, content="Intro\n###### Fine print\nBody")
  inspect(h6.caret, content="15")
  let rule = markdown_editor_apply_command_at(
    "Intro\n---\nBody",
    HorizontalRule,
    Some({ caret: 7, selection: None }),
  )
  inspect(rule.source, content="Intro\n---\nBody")
  inspect(rule.caret, content="9")
}

///|
test "markdown editor block command replaces existing marker" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    TaskList,
    Some({ caret: 4, selection: None }),
  )
  inspect(result.source, content="- [ ] Title")
  inspect(result.caret, content="8")
}

///|
test "markdown editor block command toggles same marker off" {
  let heading = markdown_editor_apply_command_at(
    "## Title",
    Heading(2),
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="1")
  let quote = markdown_editor_apply_command_at(
    "> Quote",
    Quote,
    Some({ caret: 4, selection: None }),
  )
  inspect(quote.source, content="Quote")
  inspect(quote.caret, content="2")
}

///|
test "markdown editor paragraph command strips block markers" {
  let heading = markdown_editor_apply_command_at(
    "# Title",
    Paragraph,
    Some({ caret: 4, selection: None }),
  )
  inspect(heading.source, content="Title")
  inspect(heading.caret, content="2")
  let nested = markdown_editor_apply_command_at(
    "  - child",
    Paragraph,
    Some({ caret: 6, selection: None }),
  )
  inspect(nested.source, content="child")
  inspect(nested.caret, content="2")
  let lines = markdown_editor_apply_command_at(
    "- one\n> two\n3. three",
    Paragraph,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=0, end=20)) }),
  )
  inspect(lines.source, content="one\ntwo\nthree")
}

///|
test "markdown editor block command transforms setext heading blocks" {
  let paragraph = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Paragraph,
    Some({ caret: 8, selection: None }),
  )
  inspect(paragraph.source, content="Intro\nTitle\nTail")
  inspect(paragraph.caret, content="8")
  let heading = markdown_editor_apply_command_at(
    "Intro\nTitle\n---\nTail",
    Heading(3),
    Some({ caret: 8, selection: None }),
  )
  inspect(heading.source, content="Intro\n### Title\nTail")
  inspect(heading.caret, content="12")
  let quote = markdown_editor_apply_command_at(
    "Intro\nTitle\n=====\nTail",
    Quote,
    Some({ caret: 8, selection: None }),
  )
  inspect(quote.source, content="Intro\n> Title\nTail")
}

///|
test "markdown editor reports active block label" {
  let source = "# Title\n- item\n> quote\n```\ncode\n```"
  inspect(
    markdown_editor_active_block_label(source, { caret: 3, selection: None }),
    content="Heading 1",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 10, selection: None }),
    content="Bullet list",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 18, selection: None }),
    content="Quote",
  )
  inspect(
    markdown_editor_active_block_label(source, { caret: 29, selection: None }),
    content="Code block",
  )
}

///|
test "markdown editor app block command uses tracked caret" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Intro\nTitle")
  app.set_selection(8, None)
  app.apply_command_to_selection(Quote)
  inspect(app.document(), content="Intro\n> Title")
}

///|
test "markdown editor block command transforms selected lines" {
  let bullet = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    BulletList,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(bullet.source, content="Intro\n- First\n- Second\nTail")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected transformed bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="22")
  let ordered = markdown_editor_apply_command_at(
    "Intro\n- First\n- Second\nTail",
    OrderedList,
    Some({ caret: 22, selection: Some(@core.TextRange::new(start=6, end=22)) }),
  )
  inspect(ordered.source, content="Intro\n1. First\n2. Second\nTail")
  let quote = markdown_editor_apply_command_at(
    "Intro\n1. First\n2. Second\nTail",
    Quote,
    Some({ caret: 24, selection: Some(@core.TextRange::new(start=6, end=24)) }),
  )
  inspect(quote.source, content="Intro\n> First\n> Second\nTail")
  let rule = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    HorizontalRule,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(rule.source, content="Intro\n---\nTail")
  guard rule.selection is Some(rule_selection) else {
    fail("expected rule selection")
  }
  inspect(rule_selection.start, content="6")
  inspect(rule_selection.end, content="9")
  let table = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    Table,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(
    table.source,
    content="Intro\n| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\nTail",
  )
  inspect(table.caret, content="8")
}

///|
test "markdown editor block commands renumber ordered list context" {
  let converted = markdown_editor_apply_command_at(
    "1. first\nsecond\n9. third",
    OrderedList,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=15)) }),
  )
  inspect(converted.source, content="1. first\n2. second\n3. third")
  guard converted.selection is Some(converted_selection) else {
    fail("expected converted ordered line selection")
  }
  inspect(converted_selection.start, content="10")
  inspect(converted_selection.end, content="18")
  let unlisted = markdown_editor_apply_command_at(
    "1. first\n2. second\n3. third",
    Paragraph,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=18)) }),
  )
  inspect(unlisted.source, content="1. first\nsecond\n3. third")
}

///|
test "markdown editor app block command uses tracked multi-line selection" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Intro\nFirst\nSecond")
  app.set_selection(18, Some(@core.TextRange::new(start=6, end=18)))
  app.apply_command_to_selection(TaskList)
  inspect(app.document(), content="Intro\n- [ ] First\n- [ ] Second")
}

///|
test "markdown editor app command renumbers ordered list context" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("1. first\nsecond\n9. third")
  app.set_selection(15, Some(@core.TextRange::new(start=9, end=15)))
  app.apply_command_to_selection(OrderedList)
  inspect(app.document(), content="1. first\n2. second\n3. third")
}

///|
test "markdown editor code block wraps current line and selected lines" {
  let current = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nTail",
    CodeBlock,
    Some({ caret: 8, selection: None }),
  )
  inspect(current.source, content="Intro\n```\nlet x = 1\n```\nTail")
  inspect(current.caret, content="12")
  let selected = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nlet y = 2\nTail",
    CodeBlock,
    Some({ caret: 25, selection: Some(@core.TextRange::new(start=6, end=25)) }),
  )
  inspect(
    selected.source,
    content="Intro\n```\nlet x = 1\nlet y = 2\n```\nTail",
  )
  guard selected.selection is Some(selection) else {
    fail("expected selected code content")
  }
  inspect(selection.start, content="10")
  inspect(selection.end, content="29")
}

///|
test "markdown editor code block unwraps containing fenced block" {
  let result = markdown_editor_apply_command_at(
    "Intro\n```\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 12, selection: None }),
  )
  inspect(result.source, content="Intro\nlet x = 1\nTail")
  inspect(result.caret, content="8")
  let tagged = markdown_editor_apply_command_at(
    "Intro\n```moonbit\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 20, selection: None }),
  )
  inspect(tagged.source, content="Intro\nlet x = 1\nTail")
  inspect(tagged.caret, content="9")
}

///|
test "markdown editor block command appends snippet without caret context" {
  let result = markdown_editor_apply_command_at("Base", Heading(1), None)
  inspect(result.source, content="Base\n\n# Heading")
}

///|
test "markdown editor enter continues list task quote and ordered markers" {
  let bullet = markdown_editor_transform_input("- item", 6, None, "\n").unwrap()
  inspect(bullet.text, content="- item\n- ")
  inspect(bullet.caret, content="9")
  let task = markdown_editor_transform_input("- [x] done", 10, None, "\n").unwrap()
  inspect(task.text, content="- [x] done\n- [ ] ")
  let quote = markdown_editor_transform_input("> quote", 7, None, "\n").unwrap()
  inspect(quote.text, content="> quote\n> ")
  let ordered = markdown_editor_transform_input("3. item", 7, None, "\n").unwrap()
  inspect(ordered.text, content="3. item\n4. ")
  let nested = markdown_editor_transform_input(
    "- parent\n  - child",
    18,
    None,
    "\n",
  ).unwrap()
  inspect(nested.text, content="- parent\n  - child\n  - ")
}

///|
test "markdown editor enter exits empty continuation markers" {
  let bullet = markdown_editor_transform_input("- ", 2, None, "\n").unwrap()
  inspect(bullet.text, content="")
  inspect(bullet.caret, content="0")
  let task = markdown_editor_transform_input("- [ ] ", 6, None, "\n").unwrap()
  inspect(task.text, content="")
  inspect(task.caret, content="0")
  let quote = markdown_editor_transform_input("> ", 2, None, "\n").unwrap()
  inspect(quote.text, content="")
  inspect(quote.caret, content="0")
  let ordered = markdown_editor_transform_input("1. ", 3, None, "\n").unwrap()
  inspect(ordered.text, content="")
  inspect(ordered.caret, content="0")
  let nested = markdown_editor_transform_input("- parent\n  - ", 12, None, "\n").unwrap()
  inspect(nested.text, content="- parent\n- ")
  inspect(nested.caret, content="11")
  let nested_task = markdown_editor_transform_input(
    "- parent\n  - [ ] ",
    16,
    None,
    "\n",
  ).unwrap()
  inspect(nested_task.text, content="- parent\n- [ ] ")
  inspect(nested_task.caret, content="15")
  let middle = markdown_editor_transform_input("Intro\n- \nTail", 8, None, "\n").unwrap()
  inspect(middle.text, content="Intro\n\nTail")
  inspect(middle.caret, content="6")
}

///|
test "markdown editor enter falls back for plain paragraph" {
  inspect(
    markdown_editor_transform_input("paragraph", 9, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor typed space completes block markers" {
  let h1 = markdown_editor_transform_input("#", 1, None, " ").unwrap()
  inspect(h1.text, content="# ")
  inspect(h1.caret, content="2")
  let h2 = markdown_editor_transform_input("##", 2, None, " ").unwrap()
  inspect(h2.text, content="## ")
  inspect(h2.caret, content="3")
  let h3 = markdown_editor_transform_input("###", 3, None, " ").unwrap()
  inspect(h3.text, content="### ")
  inspect(h3.caret, content="4")
  let h6 = markdown_editor_transform_input("######", 6, None, " ").unwrap()
  inspect(h6.text, content="###### ")
  inspect(h6.caret, content="7")
  inspect(
    markdown_editor_transform_input("#######", 7, None, " ") is None,
    content="true",
  )
  let bullet = markdown_editor_transform_input("-", 1, None, " ").unwrap()
  inspect(bullet.text, content="- ")
  inspect(bullet.caret, content="2")
  let star = markdown_editor_transform_input("*", 1, None, " ").unwrap()
  inspect(star.text, content="- ")
  inspect(star.caret, content="2")
  let ordered = markdown_editor_transform_input("1.", 2, None, " ").unwrap()
  inspect(ordered.text, content="1. ")
  inspect(ordered.caret, content="3")
  let quote = markdown_editor_transform_input(">", 1, None, " ").unwrap()
  inspect(quote.text, content="> ")
  inspect(quote.caret, content="2")
  let task = markdown_editor_transform_input("[ ]", 3, None, " ").unwrap()
  inspect(task.text, content="- [ ] ")
  inspect(task.caret, content="6")
  let checked = markdown_editor_transform_input("[x]", 3, None, " ").unwrap()
  inspect(checked.text, content="- [x] ")
  inspect(checked.caret, content="6")
}

///|
test "markdown editor typed space only completes marker tokens" {
  inspect(
    markdown_editor_transform_input("text #", 6, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "#",
      1,
      Some(@core.TextRange::new(start=0, end=1)),
      " ",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\n#\n```", 5, None, " ") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes horizontal rule lines" {
  let rule = markdown_editor_transform_input("---", 3, None, "\n").unwrap()
  inspect(rule.text, content="---\n")
  inspect(rule.caret, content="4")
  let star_rule = markdown_editor_transform_input("***", 3, None, "\n").unwrap()
  inspect(star_rule.text, content="***\n")
  inspect(star_rule.caret, content="4")
  inspect(
    markdown_editor_transform_input("--- title", 9, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes table header" {
  let table = markdown_editor_transform_input("| A | B |", 9, None, "\n").unwrap()
  inspect(table.text, content="| A | B |\n| --- | --- |\n|  |  |")
  inspect(table.caret, content="26")
  let compact = markdown_editor_transform_input("A | B", 5, None, "\n").unwrap()
  inspect(compact.text, content="A | B\n| --- | --- |\n|  |  |")
  inspect(compact.caret, content="22")
  inspect(
    markdown_editor_transform_input("| --- | --- |", 13, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes fenced code opener" {
  let plain = markdown_editor_transform_input("```", 3, None, "\n").unwrap()
  inspect(plain.text, content="```\n\n```")
  inspect(plain.caret, content="4")
  let lang = markdown_editor_transform_input("```moonbit", 10, None, "\n").unwrap()
  inspect(lang.text, content="```moonbit\n\n```")
  inspect(lang.caret, content="11")
  let nested = markdown_editor_transform_input("  ```", 5, None, "\n").unwrap()
  inspect(nested.text, content="  ```\n  \n  ```")
  inspect(nested.caret, content="8")
  let long = markdown_editor_transform_input("````", 4, None, "\n").unwrap()
  inspect(long.text, content="````\n\n````")
  inspect(long.caret, content="5")
}

///|
test "markdown editor enter inside code block preserves code indentation" {
  let source = "```\n  let x = 1\n```"
  let result = markdown_editor_transform_input(source, 15, None, "\n").unwrap()
  inspect(result.text, content="```\n  let x = 1\n  \n```")
  inspect(result.caret, content="18")
}

///|
test "markdown editor code block content bypasses markdown marker transforms" {
  inspect(
    markdown_editor_transform_input("```\n# code\n```", 5, None, "\u{0008}")
    is None,
    content="true",
  )
  let entered = markdown_editor_transform_input(
    "```\n- item\n```",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(entered.text, content="```\n- item\n\n```")
}

///|
test "markdown editor tab indents and shift tab outdents selected lines" {
  let indented = markdown_editor_transform_input(
    "Intro\n- one\n- two\nTail",
    17,
    Some(@core.TextRange::new(start=6, end=17)),
    "\t",
  ).unwrap()
  inspect(indented.text, content="Intro\n  - one\n  - two\nTail")
  inspect(indented.caret, content="21")
  guard indented.selection is Some(selection) else {
    fail("expected indented selection")
  }
  inspect(selection.start, content="6")
  inspect(selection.end, content="21")
  let outdented = markdown_editor_transform_input(
    indented.text,
    indented.caret,
    indented.selection,
    "\u{000b}",
  ).unwrap()
  inspect(outdented.text, content="Intro\n- one\n- two\nTail")
  inspect(outdented.caret, content="17")
}

///|
test "markdown editor tab moves through table cells" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let first = markdown_editor_transform_input(source, 2, None, "\t").unwrap()
  inspect(first.text, content=source)
  inspect(first.caret, content="6")
  let previous = markdown_editor_transform_input(source, 6, None, "\u{000b}").unwrap()
  inspect(previous.text, content=source)
  inspect(previous.caret, content="2")
  let appended = markdown_editor_transform_input(source, 30, None, "\t").unwrap()
  inspect(appended.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(appended.caret, content="36")
}

///|
test "markdown editor enter inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_transform_input(source, 30, None, "\n").unwrap()
  inspect(inserted.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(inserted.caret, content="39")
  let middle = markdown_editor_transform_input(source, 26, None, "\n").unwrap()
  inspect(middle.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(middle.caret, content="36")
}

///|
test "markdown editor command inserts table row below current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(inserted.caret, content="39")
}

///|
test "markdown editor command inserts table column after current cell" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 30, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  inspect(inserted.caret, content="35")
  let middle = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 26, selection: None }),
  )
  inspect(
    middle.source,
    content="| A |  | B |\n| --- | --- | --- |\n| 1 |  | 2 |",
  )
  inspect(middle.caret, content="31")
}

///|
test "markdown editor table column edits preserve alignment markers" {
  let source = "| A | B | C |\n| :--- | :---: | ---: |\n| 1 | 2 | 3 |"
  let inserted = markdown_editor_apply_command_at(
    source,
    InsertTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(
    inserted.source,
    content="| A | B |  | C |\n| :--- | :---: | --- | ---: |\n| 1 | 2 |  | 3 |",
  )
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 44, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| :--- | ---: |\n| 1 | 3 |")
}

///|
test "markdown editor command sets table column alignment" {
  let source = "| A | B | C |\n| --- | :---: | ---: |\n| 1 | 2 | 3 |"
  let centered = markdown_editor_apply_command_at(
    source,
    SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    centered.source,
    content="| A | B | C |\n| --- | :---: | :---: |\n| 1 | 2 | 3 |",
  )
  inspect(centered.caret, content="47")
  let auto = markdown_editor_apply_command_at(
    centered.source,
    SetTableColumnAlignment(None),
    Some({ caret: 48, selection: None }),
  )
  inspect(
    auto.source,
    content="| A | B | C |\n| --- | :---: | --- |\n| 1 | 2 | 3 |",
  )
  let snapshot = MarkdownEditorSnapshot::parse(auto.source)
  guard snapshot.rich_text.blocks[0].table is Some(table) else {
    fail("expected table preview")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextCenter) else {
    fail("expected center alignment to remain")
  }
  guard table.rows[0][2].align is None else {
    fail("expected cleared alignment")
  }
}

///|
test "markdown editor app action sets table column alignment" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-align-right")
  inspect(app.document(), content="| A | B |\n| --- | ---: |\n| 1 | 2 |")
  app.apply_action("table-align-auto")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 1 | 2 |")
}

///|
test "markdown editor command deletes current table row" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |"
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(deleted.source, content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  inspect(deleted.caret, content="23")
  let cleared = markdown_editor_apply_command_at(
    "| A | B |\n| --- | --- |\n| 1 | 2 |",
    DeleteTableRow,
    Some({ caret: 30, selection: None }),
  )
  inspect(cleared.source, content="| A | B |\n| --- | --- |\n|  |  |")
  inspect(cleared.caret, content="26")
}

///|
test "markdown editor command deletes current table column" {
  let source = "| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |"
  let deleted = markdown_editor_apply_command_at(
    source,
    DeleteTableColumn,
    Some({ caret: 40, selection: None }),
  )
  inspect(deleted.source, content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  inspect(deleted.caret, content="2")
  let cleared = markdown_editor_apply_command_at(
    "| A |\n| --- |\n| 1 |",
    DeleteTableColumn,
    Some({ caret: 16, selection: None }),
  )
  inspect(cleared.source, content="|  |\n| --- |\n|  |")
  inspect(cleared.caret, content="3")
}

///|
test "markdown editor multiline paste continues block context" {
  let bullet = markdown_editor_transform_input("- one", 5, None, " two\nthree").unwrap()
  inspect(bullet.text, content="- one two\n- three")
  inspect(bullet.caret, content="17")
  let task = markdown_editor_transform_input(
    "- [x] done",
    10,
    None,
    " today\ntomorrow",
  ).unwrap()
  inspect(task.text, content="- [x] done today\n- [ ] tomorrow")
  let quote = markdown_editor_transform_input("> note", 6, None, " now\nnext").unwrap()
  inspect(quote.text, content="> note now\n> next")
  let nested = markdown_editor_transform_input(
    "  3. one",
    8,
    None,
    " done\ntwo",
  ).unwrap()
  inspect(nested.text, content="  3. one done\n  4. two")
}

///|
test "markdown editor multiline paste continues ordered numbers" {
  let result = markdown_editor_transform_input(
    "3. one",
    6,
    None,
    " done\ntwo\nthree",
  ).unwrap()
  inspect(result.text, content="3. one done\n4. two\n5. three")
}

///|
test "markdown editor multiline paste inside code block preserves text with indent" {
  let result = markdown_editor_transform_input(
    "```\n  one\n```",
    9,
    None,
    " + two\nthree",
  ).unwrap()
  inspect(result.text, content="```\n  one + two\n  three\n```")
}

///|
test "markdown editor backspace removes block marker at content start" {
  let heading = markdown_editor_transform_input("# Title", 2, None, "\u{0008}").unwrap()
  inspect(heading.text, content="Title")
  inspect(heading.caret, content="0")
  let task = markdown_editor_transform_input(
    "Intro\n- [x] done",
    12,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(task.text, content="Intro\ndone")
  inspect(task.caret, content="6")
  let quote = markdown_editor_transform_input("> quote", 2, None, "\u{0008}").unwrap()
  inspect(quote.text, content="quote")
  inspect(quote.caret, content="0")
  let nested = markdown_editor_transform_input("  - child", 4, None, "\u{0008}").unwrap()
  inspect(nested.text, content="- child")
  inspect(nested.caret, content="2")
  inspect(
    markdown_editor_transform_input("# Title", 3, None, "\u{0008}") is None,
    content="true",
  )
}

///|
test "markdown editor backspace removes inline marker pair at content start" {
  let bold = markdown_editor_transform_input(
    "Text **bold** tail",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bold.text, content="Text bold tail")
  inspect(bold.caret, content="5")
  let code = markdown_editor_transform_input(
    "Use `code` now",
    5,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(code.text, content="Use code now")
  inspect(code.caret, content="4")
  let strike = markdown_editor_transform_input(
    "~~old~~ text",
    2,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(strike.text, content="old text")
  inspect(strike.caret, content="0")
  let link = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(link.text, content="Visit MoUI today")
  inspect(link.caret, content="6")
  let image = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(image.text, content="Insert logo here")
  inspect(image.caret, content="7")
  inspect(
    markdown_editor_transform_input("Text **bold** tail", 8, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor delete removes inline marker pair at content end" {
  let bold = markdown_editor_transform_input(
    "Text **bold** tail",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bold.text, content="Text bold tail")
  inspect(bold.caret, content="5")
  let code = markdown_editor_transform_input(
    "Use `code` now",
    9,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(code.text, content="Use code now")
  inspect(code.caret, content="4")
  let strike = markdown_editor_transform_input(
    "~~old~~ text",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(strike.text, content="old text")
  inspect(strike.caret, content="0")
  let link = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(link.text, content="Visit MoUI today")
  inspect(link.caret, content="6")
  let image = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    13,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(image.text, content="Insert logo here")
  inspect(image.caret, content="7")
  inspect(
    markdown_editor_transform_input("Text **bold** tail", 10, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor backspace at block start merges with previous block" {
  let paragraph = markdown_editor_transform_input(
    "First\nSecond",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(paragraph.text, content="First Second")
  inspect(paragraph.caret, content="5")
  let bullets = markdown_editor_transform_input(
    "- first\n- second",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bullets.text, content="- first second")
  inspect(bullets.caret, content="7")
  let tasks = markdown_editor_transform_input(
    "- [x] done\n- [ ] next",
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(tasks.text, content="- [x] done next")
  inspect(tasks.caret, content="10")
  let quotes = markdown_editor_transform_input(
    "> first\n> second",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quotes.text, content="> first second")
  let mixed = markdown_editor_transform_input(
    "# Title\n- item",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(mixed.text, content="Title item")
  inspect(mixed.caret, content="5")
  inspect(
    markdown_editor_transform_input("First\nSecond", 7, None, "\u{0008}")
    is None,
    content="true",
  )
  let blank = markdown_editor_transform_input(
    "First\n\nSecond",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(blank.text, content="First\nSecond")
  inspect(blank.caret, content="5")
}

///|
test "markdown editor delete at block end merges with next block" {
  let paragraph = markdown_editor_transform_input(
    "First\nSecond",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(paragraph.text, content="First Second")
  inspect(paragraph.caret, content="5")
  let bullets = markdown_editor_transform_input(
    "- first\n- second",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bullets.text, content="- first second")
  inspect(bullets.caret, content="7")
  let ordered = markdown_editor_transform_input(
    "1. first\n2. second",
    8,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(ordered.text, content="1. first second")
  inspect(ordered.caret, content="8")
  let mixed = markdown_editor_transform_input(
    "# Title\n- item",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(mixed.text, content="Title item")
  inspect(mixed.caret, content="5")
  let blank = markdown_editor_transform_input(
    "First\n\nSecond",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(blank.text, content="First\nSecond")
  inspect(blank.caret, content="5")
  inspect(
    markdown_editor_transform_input("First\nSecond", 6, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor renumbers contiguous ordered lists after transforms" {
  let backspace = markdown_editor_transform_input(
    "1. first\n3. second\n4. third",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace.text, content="1. first second\n2. third")
  inspect(backspace.caret, content="8")
  let delete = markdown_editor_transform_input(
    "8. first\n10. second\n11. third",
    8,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete.text, content="8. first second\n9. third")
  inspect(delete.caret, content="8")
  let enter = markdown_editor_transform_input(
    "1. first\n7. second",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(enter.text, content="1. first\n2. \n3. second")
  inspect(enter.caret, content="12")
}

///|
test "markdown editor runtime enter continues bullet list" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- item\n- ")
}

///|
test "markdown editor runtime enter inserts table row" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let mut target : @core.Rect? = None
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::DrawText({ text: "2", frame, .. }) =>
        target = Some(frame)
      _ => ()
    }
  }
  guard target is Some(frame) else { fail("expected rendered table cell") }
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
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(runtime.focused_text_input().caret, content="39")
}

///|
test "markdown editor runtime shortcut inserts table column" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="=",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
}

///|
test "markdown editor runtime shortcut inserts table row" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
}

///|
test "markdown editor runtime shortcut deletes table row" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="-",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
}

///|
test "markdown editor runtime shortcut deletes table column" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(40, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="_",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
}

///|
test "markdown editor runtime enter outdents nested empty list marker" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- parent\n  - ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=212.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- parent\n- ")
  inspect(runtime.focused_text_input().caret, content="11")
}

///|
test "markdown editor runtime tab indents focused line" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  inspect(app.document(), content="  - item")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Tab",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  inspect(app.document(), content="- item")
}

///|
test "markdown editor runtime backspace removes hidden heading marker" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime backspace removes hidden inline marker" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime backspace removes hidden link marker" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime delete removes hidden link marker" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<11 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime backspace merges visual blocks" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<8 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="8")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title item")
}

///|
test "markdown editor runtime delete merges visual blocks" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Title item")
  inspect(runtime.focused_text_input().caret, content="5")
}

///|
test "markdown editor runtime delete preserves same-list merge" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- first\n- second")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="- first second")
  inspect(runtime.focused_text_input().caret, content="7")
}

///|
test "markdown editor runtime undo restores input transform caret" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="#")
  inspect(runtime.focused_text_input().caret, content="1")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
}

///|
test "markdown editor runtime prefix click toggles task checkbox" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor copy exports visual text without hidden markdown markers" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
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
  assert_true(copied.handled)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied visual text")
  }
  inspect(text, content="Title\nbold")
}

///|
test "markdown editor paste command continues list context" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("- one")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some(" two\nthree"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="- one two\n- three")
}

///|
test "markdown editor paste command links selected text with url" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit MoUI")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<6 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="11")
  guard input.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor paste command inserts image from selected alt text" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Insert logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("assets/logo.png"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Insert ![logo](assets/logo.png)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="13")
  guard input.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor runtime paste and typing complete autolinks" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Visit ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit <https://moui.dev>")

  app.set_document("Visit https://moui.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Visit <https://moui.dev> ")
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
test "markdown editor toolbar actions update canonical markdown" {
  let app = @app.MarkdownEditorApp::new()
  app.clear()
  app.apply_action("h1")
  inspect(app.document(), content="# Heading")
  app.clear()
  app.apply_action("h6")
  inspect(app.document(), content="###### Caption")
  app.clear()
  app.apply_action("bold")
  assert_true(app.document().contains("**bold text**"))
  app.apply_action("strike")
  assert_true(app.document().contains("~~old text~~"))
  app.apply_action("link")
  assert_true(app.document().contains("[link text](https://example.com)"))
  app.apply_action("link-target")
  assert_true(app.document().contains("[link text](https://moui.dev)"))
  app.apply_action("image")
  assert_true(app.document().contains("![image alt](image.png)"))
  app.apply_action("image-target")
  assert_true(app.document().contains("![image alt](assets/image.png)"))
  app.apply_action("code-language")
  assert_true(app.document().contains("```moonbit\ncode block\n```"))
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-row")
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-column")
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  app.set_selection(30, None)
  app.apply_action("table-row-delete")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  app.set_selection(40, None)
  app.apply_action("table-column-delete")
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  app.set_document("# Heading")
  app.set_selection(4, None)
  app.apply_action("paragraph")
  inspect(app.document(), content="Heading")
}

///|
test "markdown editor toolbar seeds every supported action from empty document" {
  for
    expected in [
      "**bold text**", "*italic text*", "`code`", "~~old text~~", "[link text](https://example.com)",
      "[link text](https://moui.dev)", "![image alt](image.png)", "![image alt](assets/image.png)",
      "Paragraph", "# Heading", "## Section", "### Detail", "#### Subdetail", "##### Note",
      "###### Caption", "- List item", "- [ ] Task item", "1. List item", "> Quote",
      "---", "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |", "```\ncode block\n```",
    ] {
    let app = @app.MarkdownEditorApp::new()
    app.clear()
    app.apply_action(markdown_action_from_seed(expected))
    inspect(app.document(), content=expected)
  }
}

///|
test "markdown editor toolbar applies actions at current caret context" {
  let app = @app.MarkdownEditorApp::new()
  app.set_document("Base")
  for
    action in [
      "bold", "italic", "code", "strike", "link", "image", "h1", "h2", "h3", "h4",
      "h5", "h6", "ul", "task", "ol", "quote", "codeblock",
    ] {
    app.apply_action(action)
  }
  let document = app.document()
  inspect(
    document,
    content="Base\n\n**bold text**\n\n*italic text*\n\n`code`\n\n~~old text~~\n\n[link text](https://example.com)\n\n```\n> ![image alt](image.png)\n```",
  )
  app.apply_action("unknown")
  inspect(app.document(), content=document)
}

///|
fn markdown_action_from_seed(expected : String) -> String {
  if expected == "**bold text**" {
    "bold"
  } else if expected == "*italic text*" {
    "italic"
  } else if expected == "`code`" {
    "code"
  } else if expected == "~~old text~~" {
    "strike"
  } else if expected == "[link text](https://example.com)" {
    "link"
  } else if expected == "[link text](https://moui.dev)" {
    "link-target"
  } else if expected == "![image alt](image.png)" {
    "image"
  } else if expected == "![image alt](assets/image.png)" {
    "image-target"
  } else if expected == "Paragraph" {
    "paragraph"
  } else if expected == "# Heading" {
    "h1"
  } else if expected == "## Section" {
    "h2"
  } else if expected == "### Detail" {
    "h3"
  } else if expected == "#### Subdetail" {
    "h4"
  } else if expected == "##### Note" {
    "h5"
  } else if expected == "###### Caption" {
    "h6"
  } else if expected == "- List item" {
    "ul"
  } else if expected == "- [ ] Task item" {
    "task"
  } else if expected == "1. List item" {
    "ol"
  } else if expected == "> Quote" {
    "quote"
  } else if expected == "---" {
    "rule"
  } else if expected ==
    "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |" {
    "table"
  } else {
    "codeblock"
  }
}

///|
test "markdown editor runtime typing updates document" {
  let app = @app.MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("- item")),
  )
  inspect(app.document(), content="# Hi\n- item")
}

///|
test "markdown editor runtime enter completes fenced code block" {
  let app = @app.MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=184.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("```moonbit")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="```moonbit\n\n```")
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("let x = 1")),
  )
  inspect(app.document(), content="```moonbit\nlet x = 1\n```")
}

///|
test "markdown editor clear redraws placeholder and optional empty source preview" {
  let app = @app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  app.clear()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Start writing Markdown", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
  app.set_source_preview_visible(true)
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let source_commands = runtime.draw_commands()
  assert_true(
    source_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
}
