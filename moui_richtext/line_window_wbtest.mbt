///|
/// A document with many small blocks — the ordinary case. The line window
/// must stay disengaged, and the block range must match what the block-indexed
/// height walk produces.
fn line_window_blocks_document() -> String {
  let parts : Array[String] = []
  for index in 0..<200 {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push("Paragraph " + index.to_string() + " with some body text.")
    parts.push("")
  }
  parts.join("\n")
}

///|
test "line window stays disengaged for an ordinary multi-block document" {
  let session = MarkdownDocumentSession::new(line_window_blocks_document())
  let font = @core.FontSpec::new()
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=600.0,
    overscan=200.0,
    content_width=860.0,
  )
  inspect(window.clip_lines, content="0")
  // The window still renders a bounded slice of the block list, not all of it.
  assert_true(window.rendered_block_count < window.block_count)
  assert_true(window.visible_start >= 0)
  assert_true(window.visible_end >= window.visible_start)
}

///|
test "line window stays disengaged while scrolling a multi-block document" {
  let session = MarkdownDocumentSession::new(line_window_blocks_document())
  let font = @core.FontSpec::new()
  let content_height = session.estimated_content_height(
    base=font,
    content_width=860.0,
  )
  assert_true(content_height > 0.0)
  for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
    let window = session.rich_text_window(
      { caret: 0, selection: None },
      base=font,
      scroll_y=content_height * fraction,
      viewport_height=600.0,
      overscan=200.0,
      content_width=860.0,
    )
    inspect(window.clip_lines, content="0")
  }
}

///|
/// One soft-wrapped paragraph holding many source lines: the shape that makes
/// the block-granular range useless. Step 1 only records that the range still
/// reports no clipping; the clipping itself arrives with the slice.
test "single oversized block reports the full block in the window" {
  let parts : Array[String] = []
  for index in 0..<4000 {
    parts.push(
      "　　第" +
      index.to_string() +
      "段正文内容，模拟长篇小说的一行文字。",
    )
  }
  let session = MarkdownDocumentSession::new(parts.join("\n"))
  let font = @core.FontSpec::new()
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=600.0,
    overscan=200.0,
    content_width=860.0,
  )
  // One paragraph block plus the block the caret sits in.
  assert_true(window.block_count <= 2)
  inspect(window.clip_lines, content="0")
}

///|
/// A paragraph block whose content is four source lines, for slice tests.
fn line_window_slice_block() -> (String, MarkdownEditorBlock) raise {
  let source = "alpha line\nbeta line\ngamma line\ndelta line"
  let blocks = parse_markdown_editor_blocks_shell(source)
  guard blocks.length() == 1 else {
    fail("expected one soft-wrapped paragraph block")
  }
  (source, blocks[0])
}

///|
test "slicing a block keeps absolute source offsets" {
  let (source, block) = line_window_slice_block()
  let sliced = markdown_editor_block_slice_to_source_lines(source, block, 2, 3)
  inspect(sliced.block.text, content="gamma line\ndelta line")
  // `gamma line` starts at offset 21 in the full source; the slice runs to the
  // end of `delta line`, exclusive.
  inspect(sliced.content_range.start, content="21")
  inspect(sliced.content_range.end, content="42")
  inspect(sliced.source_range.start, content="21")
  // The slice is a real substring of the document at those offsets.
  inspect(
    markdown_editor_substring(
      source,
      sliced.content_range.start,
      sliced.content_range.end,
    ),
    content="gamma line\ndelta line",
  )
}

///|
test "slicing re-parses inline runs from the slice" {
  let source = "one **bold**\ntwo `code`\nthree plain"
  let blocks = parse_markdown_editor_blocks_shell(source)
  let sliced = markdown_editor_block_slice_to_source_lines(
    source,
    blocks[0],
    1,
    2,
  )
  inspect(sliced.block.text, content="two `code`\nthree plain")
  // The materialised parse carries the code span from the kept lines.
  let materialized = markdown_editor_block_materialized(
    source,
    source_length=markdown_editor_text_length(source),
    source_digest=0UL,
    sliced,
  )
  assert_true(
    materialized.block.inlines.any(inline => {
      inline.kind == Code && inline.text == "code"
    }),
  )
}

///|
test "slicing from the first line returns the whole block unchanged" {
  let (source, block) = line_window_slice_block()
  let sliced = markdown_editor_block_slice_to_source_lines(source, block, 0, 3)
  assert_true(sliced == block)
}

///|
test "an out-of-range slice falls back to the whole block" {
  let (source, block) = line_window_slice_block()
  // Past the end: nothing to render, so the caller gets the block back rather
  // than an empty one it would have to special-case.
  assert_true(
    markdown_editor_block_slice_to_source_lines(source, block, 9, 12) == block,
  )
  assert_true(
    markdown_editor_block_slice_to_source_lines(source, block, 3, 1) == block,
  )
  // A block with no content lines is returned as-is.
  let empty = parse_markdown_editor_blocks_shell("")
  if empty.length() > 0 {
    assert_true(
      markdown_editor_block_slice_to_source_lines("", empty[0], 1, 2) ==
      empty[0],
    )
  }
}

///|
/// The gate 3a must pass before it can be enabled.
///
/// A caret rect is a screen position, so it has to track the scroll exactly:
/// scrolling by N moves it by N, whether the caret's own line is inside the
/// window or not. Clipping the window to the visible band removes an
/// out-of-band caret's line from `window.document`, and the defect this guards
/// against pinned the caret to the start of the block instead of letting it
/// follow the scroll.
fn line_window_caret_y(scroll_y : Double) -> Double {
  let parts : Array[String] = []
  for index in 0..<3000 {
    parts.push(
      "　　第" +
      index.to_string() +
      "段正文内容，模拟长篇小说的一行文字。",
    )
  }
  let source = parts.join("\n")
  let session = MarkdownDocumentSession::new(source)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=860.0, height=600.0)
  let font = @core.FontSpec::new()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let state = markdown_session_input_state(
    text=source,
    frame~,
    session~,
    selection~,
    font~,
    control=session_editor_text_control(caret=0),
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=scroll_y,
    visible_viewport_height=600.0,
    visible_overscan=0.0,
    text_system=@core.TextSystem::fallback(),
  )
  state.caret_rect.origin.y
}

///|
test "caret rect tracks the scroll while the caret is in the window" {
  let base = line_window_caret_y(0.0)
  let scrolled = line_window_caret_y(200.0)
  assert_true((base - scrolled - 200.0).abs() < 2.0)
}

///|
test "caret rect tracks the scroll after the caret leaves the window" {
  let base = line_window_caret_y(0.0)
  let scrolled = line_window_caret_y(20000.0)
  assert_true((base - scrolled - 20000.0).abs() < 2.0)
}
