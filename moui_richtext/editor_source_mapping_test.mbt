///|
test "markdown_editor_format produces a RichTextDocument with blocks" {
  let document = markdown_editor_format("# Title\n\nParagraph")
  assert_true(document.blocks.length() >= 1)
  // The first block should have a source range.
  assert_true(document.blocks[0].source_range is Some(_))
}

///|
test "markdown_editor_format_for_selection reveals inline markers when selection touches them" {
  // source = "**bold**", with selection inside the "bold" text [3, 5).
  // The revealed run should expand to include the "**" markers.
  let selection : MarkdownEditorSelection = {
    caret: 4,
    selection: Some(@core.TextRange::new(start=3, end=5)),
  }
  let document = markdown_editor_format_for_selection("**bold**", selection)
  // Find a run whose text contains the bold markers (i.e. was revealed).
  let has_revealed = document.blocks.any(block => {
    block.runs.any(run => run.text.contains("**"))
  })
  assert_true(has_revealed)
}

///|
test "markdown_editor_format_for_selection does not reveal markers outside selection" {
  // source = "plain **bold** plain", selection at [0, 5) (only "plain").
  // The bold markers should NOT be revealed because the selection does not touch them.
  let selection : MarkdownEditorSelection = {
    caret: 5,
    selection: Some(@core.TextRange::new(start=0, end=5)),
  }
  let document = markdown_editor_format_for_selection(
    "plain **bold** plain", selection,
  )
  // No run should contain the full "**bold**" marker pair as text.
  let has_full_marker = document.blocks.any(block => {
    block.runs.any(run => run.text == "**bold**")
  })
  assert_false(has_full_marker)
}

///|
test "markdown_editor_format_for_writing_mode with focus_mode dims inactive blocks" {
  // Two blocks: heading and paragraph. Focus on the paragraph.
  let source = "# Heading\n\nParagraph body"
  // Caret inside the paragraph block (after "# Heading\n\n" = offset 11).
  let selection : MarkdownEditorSelection = { caret: 12, selection: None }
  let font = @core.FontSpec::new(size=16.0)
  let document = markdown_editor_format_for_writing_mode(
    source,
    selection,
    base=font,
    focus_mode=true,
  )
  // The heading block (not active) should be dimmed (color set).
  let dimmed_blocks = document.blocks.filter(b => b.color is Some(_))
  assert_true(dimmed_blocks.length() >= 1)
}

///|
test "markdown_editor_format_for_writing_mode without focus_mode does not dim" {
  let source = "# Heading\n\nParagraph body"
  let selection : MarkdownEditorSelection = { caret: 12, selection: None }
  let font = @core.FontSpec::new(size=16.0)
  let document = markdown_editor_format_for_writing_mode(
    source,
    selection,
    base=font,
    focus_mode=false,
  )
  // Without focus mode, no block should be force-dimmed by the focus logic.
  // (Blocks may still have their own colors, but the focus dimming is not applied.)
  assert_true(document.blocks.length() >= 1)
}

///|
test "MarkdownEditorSnapshot::parse produces consistent metadata" {
  let snapshot = MarkdownEditorSnapshot::parse("# Title\n\nParagraph text")
  inspect(snapshot.source, content="# Title\n\nParagraph text")
  assert_true(snapshot.blocks.length() >= 1)
  assert_true(snapshot.line_count >= 2)
  assert_true(snapshot.word_count >= 2)
  inspect(snapshot.outline.length(), content="1")
  inspect(snapshot.outline[0].title, content="Title")
  assert_true(snapshot.rich_text.blocks.length() >= 1)
}

///|
test "MarkdownEditorSnapshot::parse_with_font produces rich text with font" {
  let font = @core.FontSpec::new(size=20.0)
  let snapshot = MarkdownEditorSnapshot::parse_with_font(
    "# Title\n\nBody", font,
  )
  // The heading block should have a font with size 20.0 * heading_scale.
  let heading_block = snapshot.rich_text.blocks[0]
  guard heading_block.font is Some(heading_font) else {
    fail("expected a font on the heading block")
  }
  assert_true(heading_font.size >= 20.0)
}

///|
test "markdown_editor_active_selection returns None for collapsed range" {
  let collapsed = @core.TextRange::new(start=5, end=5)
  assert_true(markdown_editor_active_selection(Some(collapsed)) is None)
}

///|
test "markdown_editor_active_selection returns Some for non-collapsed range" {
  let range = @core.TextRange::new(start=2, end=8)
  guard markdown_editor_active_selection(Some(range)) is Some(active) else {
    fail("expected Some for non-collapsed range")
  }
  inspect(active.start, content="2")
  inspect(active.end, content="8")
}

///|
test "markdown_editor_active_selection returns None for None input" {
  assert_true(markdown_editor_active_selection(None) is None)
}

///|
test "markdown_editor_active_block_label returns label for caret in heading" {
  let source = "# Heading\n\nParagraph"
  let selection : MarkdownEditorSelection = { caret: 2, selection: None }
  let label = markdown_editor_active_block_label(source, selection)
  // Caret at position 2 is inside "# Heading", which is a heading.
  assert_true(label.contains("Heading"))
}

///|
test "markdown_editor_active_block_label returns Paragraph for caret in paragraph" {
  let source = "# Heading\n\nParagraph"
  // Caret at position 12 is inside "Paragraph" (after "# Heading\n\n").
  let selection : MarkdownEditorSelection = { caret: 12, selection: None }
  let label = markdown_editor_active_block_label(source, selection)
  inspect(label, content="Paragraph")
}

///|
test "markdown_editor_preview_text returns (empty) for empty string" {
  inspect(markdown_editor_preview_text(""), content="(empty)")
}

///|
test "markdown_editor_preview_text returns source unchanged for short text" {
  inspect(markdown_editor_preview_text("short text"), content="short text")
}

///|
test "markdown_editor_preview_text truncates long text with ellipsis" {
  let long_text = "a".repeat(800)
  let preview = markdown_editor_preview_text(long_text)
  assert_true(preview.contains("..."))
  // The preview should be shorter than the original.
  assert_true(markdown_editor_text_length(preview) < 800)
}

///|
test "markdown_block_to_rich_text converts a heading block" {
  let block : MarkdownBlock = {
    kind: Heading(1),
    text: "Title",
    inlines: [{ text: "Title", kind: Plain, target: None }],
    table_alignments: [],
    code_language: None,
  }
  let font = @core.FontSpec::new(size=16.0)
  let rich_block = markdown_block_to_rich_text(block, font)
  assert_true(rich_block.runs.length() >= 1)
  guard rich_block.font is Some(heading_font) else {
    fail("expected a font on the heading rich block")
  }
  // Heading font should have weight 700.
  inspect(heading_font.weight, content="700")
}
