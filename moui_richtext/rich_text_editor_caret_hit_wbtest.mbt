///|
/// Pointer hit testing must share the painted block geometry: percentage-width
/// image runs only reach their real height when the content column width is
/// known (see `rich_text_run_resolved_image_width`). A width-blind walk — the
/// historical behavior — accumulates different block heights than painting, so
/// every click below an image gallery resolved into the wrong block (often the
/// gallery's HTML block, whose selection-reveal then collapsed the rendered
/// images into raw markup and made the visible content jump).
test "pointer hit test matches painted geometry around image galleries" {
  let source = "# Title\n\n<div>\n<img src=\"resource/a.png\" width=\"48%\" alt=\"A\"/>\n<img src=\"resource/b.png\" width=\"48%\" alt=\"B\"/>\n</div>\n\n## Section\n\nTarget paragraph text.\n\nTail paragraph text.\n"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let content_width = 960.0
  let window = session.rich_text_window(
    selection,
    base=font,
    scroll_y=0.0,
    viewport_height=2000.0,
    overscan=0.0,
    content_width~,
  )
  let content = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=content_width,
    height=2000.0,
  )
  let window_content = window.content_rect(content)
  // Painted geometry: the same width-aware walk `append_rich_text_document_layers`
  // uses, so bands line up with what is actually on screen.
  let mut y = window_content.origin.y
  let mut gallery_frame : @core.Rect? = None
  let mut gallery_start = -1
  let mut gallery_end = -1
  let mut target_frame : @core.Rect? = None
  let mut target_start = -1
  let mut target_end = -1
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=window_content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        window_content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if block.source_range is Some(range) {
      let block_source = source[range.start:range.end].to_owned()
      if block_source.contains("img") {
        gallery_frame = Some(frame)
        gallery_start = range.start
        gallery_end = range.end
      }
      if block_source.contains("Target") {
        target_frame = Some(frame)
        target_start = range.start
        target_end = range.end
      }
    }
    y = y + block_height
  }
  let target_frame = match target_frame {
    Some(frame) => frame
    None => fail("target paragraph not found in window")
  }
  assert_true(target_start >= 0 && target_end >= target_start)
  let gallery_frame = match gallery_frame {
    Some(frame) => frame
    None => fail("gallery range not found")
  }
  assert_true(gallery_start >= 0 && gallery_end >= gallery_start)
  // Clicking the middle of the visible target paragraph must land in it.
  let target_click = @core.Point::new(
    x=target_frame.origin.x + target_frame.size.width * 0.5,
    y=target_frame.origin.y + target_frame.size.height * 0.5,
  )
  let caret = rich_text_document_source_offset_at_point(
      window.document,
      target_click,
      window_content,
      font,
      text_system,
    )
    .unwrap_or(-1)
  assert_true(caret >= target_start && caret <= target_end)
  // Clicking the middle of the rendered gallery must stay inside the gallery's
  // source range instead of skipping into the blocks below.
  let gallery_click = @core.Point::new(
    x=gallery_frame.origin.x + gallery_frame.size.width * 0.5,
    y=gallery_frame.origin.y + gallery_frame.size.height * 0.5,
  )
  let gallery_caret = rich_text_document_source_offset_at_point(
      window.document,
      gallery_click,
      window_content,
      font,
      text_system,
    )
    .unwrap_or(-1)
  assert_true(
    gallery_caret >= gallery_start && gallery_caret <= gallery_end,
  )
}
