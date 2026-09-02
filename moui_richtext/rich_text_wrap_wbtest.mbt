///|
/// P1 acceptance: the session editor soft-wraps paragraphs through the
/// shared `TextSystem::layout_paragraph` memo, and paint height, caret
/// rectangles, hit-testing, copy, and selection bands all consume that
/// one layout. Runs deterministically on the fallback text system, so it
/// is GUI-free.

///|
fn wrap_fixture_words(count : Int) -> String {
  let mut text = ""
  for index in 0..<count {
    text = text + "word" + index.to_string() + " "
  }
  text
}

///|
fn source_line_starts(text : String) -> Array[Int] {
  let starts : Array[Int] = [0]
  let chars = text.to_array()
  for index, ch in chars {
    if ch == '\n' && index + 1 < chars.length() {
      starts.push(index + 1)
    }
  }
  starts
}

///|
test "soft wrap: one memoized layout, hit-test lands on the wrapped line start" {
  let base = @core.FontSpec::new()
  let text_system = @core.TextSystem::fallback()
  let source = wrap_fixture_words(160)
  let session = MarkdownDocumentSession::new(source)
  hot_path_metrics_reset()
  let plain = markdown_editor_block_to_rich_text(
    session.source,
    session.editor_blocks[0],
    base,
    base_dir=None,
  )
  let width = 220.0
  let wrapped = rich_text_block_soft_wrap(plain, width, base, text_system)
  let visual_line_count = rich_text_block_visual_line_count(wrapped)
  assert_true(visual_line_count > 3)
  assert_true(hot_path_block_wrap_builds.val == 1)
  // Re-wrapping the same content identity (e.g. every repaint and every
  // pointer event) must reuse the memoized layout.
  let again = rich_text_block_soft_wrap(plain, width, base, text_system)
  assert_true(hot_path_block_wrap_cache_hits.val == 1)
  assert_true(again == wrapped)
  // Wrapped geometry must be taller than the single-logical-line layout,
  // otherwise height, scroll, and paint still disagree.
  assert_true(
    rich_text_block_total_height(wrapped, base, text_system, block_width=width) >
    rich_text_block_total_height(plain, base, text_system, block_width=width),
  )
  // For each wrapped line (prefix lane excluded: plain paragraph), the
  // caret rect and the hit test must agree, and the hit must map back to
  // the exact source offset that starts the line.
  let frame = @core.Rect::new(x=0.0, y=0.0, width~, height=10000.0)
  let line_step = rich_text_block_line_step(wrapped, base, text_system)
  let visual = rich_text_document_view_block_visual_text(wrapped)
  let visual_starts = source_line_starts(visual)
  // The fixture is one logical source line, so the source offset of
  // wrapped line `k` starts at exactly the visual offset minus the `k`
  // injected newlines above it.
  let checked_lines = @core.min_int(5, visual_starts.length())
  assert_true(checked_lines >= 3)
  for line in 0..<checked_lines {
    let caret = rich_text_block_caret_rect(
      wrapped,
      visual_starts[line],
      frame,
      base,
      text_system,
    )
    let hit = rich_text_block_source_offset_at_point(
      wrapped,
      @core.Point::new(x=caret.origin.x + 0.1, y=caret.origin.y + 1.0),
      frame,
      base,
      text_system,
    )
    assert_true(hit == visual_starts[line] - line)
    assert_true(caret.origin.y >= line.to_double() * line_step)
  }
}

///|
test "soft wrap: copy across injected breaks yields canonical source text" {
  let base = @core.FontSpec::new()
  let text_system = @core.TextSystem::fallback()
  let source = wrap_fixture_words(160)
  let session = MarkdownDocumentSession::new(source)
  let plain = markdown_editor_block_to_rich_text(
    session.source,
    session.editor_blocks[0],
    base,
    base_dir=None,
  )
  let wrapped = rich_text_block_soft_wrap(plain, 220.0, base, text_system)
  let end = @core.min_int(300, session.source_length)
  let copied = selected_rich_text_block_text(
    wrapped,
    @core.TextRange::new(start=0, end~),
  ).unwrap_or("<selection missing>")
  let expected = markdown_editor_substring(source, 0, end)
  assert_true(copied == expected)
  assert_true(!expected.contains("\n"))
}

///|
test "soft wrap: a selection across wrapped lines paints one band per line" {
  let base = @core.FontSpec::new()
  let text_system = @core.TextSystem::fallback()
  let source = wrap_fixture_words(160)
  let session = MarkdownDocumentSession::new(source)
  let plain = markdown_editor_block_to_rich_text(
    session.source,
    session.editor_blocks[0],
    base,
    base_dir=None,
  )
  let wrapped = rich_text_block_soft_wrap(plain, 220.0, base, text_system)
  let visual = rich_text_document_view_block_visual_text(wrapped)
  let visual_starts = source_line_starts(visual)
  let frame = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=220.0,
    height=rich_text_block_line_height(wrapped, base, text_system),
  )
  let commands : Array[@core.DrawCommand] = []
  append_rich_text_block_selection_rect(
    commands,
    wrapped,
    @core.TextRange::new(start=visual_starts[0], end=visual_starts[3]),
    frame,
    base,
    text_system,
  )
  // Selection from the very start to the start of line 3: lines 0..2
  // paint one full-width band each; the trailing edge on line 3 is
  // zero-width and correctly skipped. Before P1 this painted a single
  // first-line band — or nothing at all when the end landed left of the
  // start.
  assert_true(commands.length() >= 3)
}
