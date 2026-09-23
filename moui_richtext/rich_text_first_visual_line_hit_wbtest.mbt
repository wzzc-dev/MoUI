///|
/// Regression: clicking the FIRST visual line of a soft-wrapped source
/// line used to snap the caret to the line's start. A paragraph block's
/// inline runs carry one run per source line plus a bare "\n" run between
/// them; splitting that newline run yields two empty segments, and the
/// second one sits at the start of the next line before any content — the
/// hit walk's empty-segment shortcut returned there and ignored the click
/// x entirely.

///|
fn first_visual_line_session() -> MarkdownDocumentSession {
  // Long narration lines that wrap at the test content width, each with
  // the full-width-space indent a novel line carries.
  let parts : Array[String] = []
  for index in 0..<400 {
    parts.push(
      "　　第" +
      index.to_string() +
      "段正文内容，这一行足够长，会在窗口宽度处软换行成多个视觉行，用来复现点击第一行时光标落点错误的问题。",
    )
  }
  MarkdownDocumentSession::new(parts.join("\n"))
}

///|
test "click on the first visual line of a wrapped source line stays inside the line" {
  let session = first_visual_line_session()
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let viewport = 600.0
  let overscan = 320.0
  let width = 752.0
  let frame = @core.Rect::new(x=0.0, y=0.0, width=752.0, height=viewport)
  let scroll_y = 5000.0
  let selection : MarkdownEditorSelection = { caret: 0, selection: None, }
  let window = markdown_session_visible_window(
    session,
    selection,
    font,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=scroll_y,
    visible_viewport_height=viewport,
    visible_overscan=overscan,
    content_width=width,
    text_system~,
  )
  let content = window.content_rect(frame)
  let document = window.document
  let block = document.blocks[0]
  // Click the midpoint x of every visual line and map back to source. The
  // click lands several characters past the line's two-space indent, so
  // no click may resolve to the line's own start offset.
  let source_chars = session.source()
  let line_heights = rich_text_block_line_heights(
    block, font, text_system, width,
  )
  let mut y = content.origin.y + block.inset.top
  let mut failures = 0
  for _line_index, height in line_heights {
    let point = @core.Point::new(
      x=content.origin.x + block.inset.left + 300.0,
      y=y + height / 2.0,
    )
    match
      rich_text_document_source_offset_at_point(
        document, point, content, font, text_system,
      ) {
      Some(offset) => {
        // Start of the source line containing the resolved offset.
        let mut scan = 0
        let mut line_start = 0
        for ch in source_chars {
          if scan >= offset {
            break
          }
          if ch == '\n' {
            line_start = scan + 1
          }
          scan = scan + 1
        }
        if offset == line_start {
          failures = failures + 1
        }
      }
      None => failures = failures + 1
    }
    y = y + height
  }
  inspect(failures, content="0")
  // The visible band must hold many wrapped visual lines (each source
  // line wraps into two), or the test would pass vacuously.
  assert_true(line_heights.length() > 100)
}
