///|
/// Regression: single-blank paragraph separators must measure as the painted
/// collapsed height (0.4em), not a full line box. The uncollapsed measurement
/// overstated every separator by ~1.55em; once those tall heights entered the
/// persisted scroll geometry, `top_padding` (a prefix sum over them) ran ahead
/// of the actually drawn collapsed stack. Scrolling down by a small delta
/// while a separator moved above the window then netted a downward (backward)
/// displacement — the reported rollback.
test "blank separators measure as painted collapsed height" {
  ignore(markdown_scroll_take_geometry_compensation())
  let base = @core.FontSpec::new(size=19.0)
  let width = 717.0
  let text_system = @core.TextSystem::fallback()
  let parts : Array[String] = []
  for index in 0..<30 {
    parts.push("Paragraph \{index} with some flowing text to grow the page.")
  }
  let source = parts.join("\n\n")
  let session = MarkdownDocumentSession::new(source)
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let scroll_y = 500.0
  let viewport_height = 300.0
  let window = markdown_session_visible_window(
    session,
    selection,
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=scroll_y,
    visible_viewport_height=viewport_height,
    visible_overscan=160.0,
    content_width=width,
    text_system~,
  )
  ignore(
    markdown_session_record_measured_block_heights(
      session,
      window,
      content_width=width,
      base~,
      base_dir=None,
      text_system~,
      visible_scroll_y=scroll_y,
    ),
  )
  ignore(markdown_scroll_take_geometry_compensation())
  let geometry = markdown_document_block_geometry(session, base, content_width=width)
  match geometry {
    None => fail("expected scroll geometry after measuring the window")
    Some(geometry) => {
      for offset, window_block in window.document.blocks {
        let index = window.visible_start + offset
        if rich_text_block_is_blank_gap(window_block) {
          let painted = rich_text_block_total_height(
            window_block, base, text_system, block_width=width,
          )
          let stored = geometry.heights[index]
          if (painted - stored).abs() > 0.001 {
            fail(
              "blank \{index} painted=\{painted.to_string()} stored=\{stored.to_string()}",
            )
          }
        }
      }
    }
  }
}
