///|
fn rich_text_block_selection_visual_range(
  block : RichTextBlock,
  selection : TextRange,
) -> TextRange? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if selection.end <= source.start || selection.start >= source.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.start, source.start, source.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.end, source.start, source.end),
          content,
        )
        if end > start {
          Some(TextRange::new(start~, end~))
        } else {
          None
        }
      }
    (_, Some(content)) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.start, content.start, content.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.end, content.start, content.end),
          content,
        )
        if end > start {
          Some(TextRange::new(start~, end~))
        } else {
          None
        }
      }
    _ => None
  }
}

///|
fn append_rich_text_selection_commands(
  commands : Array[DrawCommand],
  document : RichTextDocument,
  content : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
  selection : TextRange?,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let mut y = content.origin.y
      for block in document.blocks {
        let line_height = rich_text_block_line_height(block, base_font)
        let block_height = line_height + block.inset.top + block.inset.bottom
        let frame = Rect::new(
          x=content.origin.x + block.inset.left,
          y=y + block.inset.top,
          width=max_double(
            0.0,
            content.size.width - block.inset.left - block.inset.right,
          ),
          height=line_height,
        )
        match rich_text_block_selection_visual_range(block, selection) {
          Some(range) =>
            append_rich_text_block_selection_rect(
              commands, block, range, frame, base_font, text_system,
            )
          None => ()
        }
        y = y + block_height
      }
    }
    None => ()
  }
}

///|
fn append_rich_text_block_selection_rect(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  range : TextRange,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Unit {
  let start_rect = rich_text_block_caret_rect(
    block,
    range.start,
    frame,
    base_font,
    text_system,
  )
  let end_rect = rich_text_block_caret_rect(
    block,
    range.end,
    frame,
    base_font,
    text_system,
  )
  if end_rect.origin.x > start_rect.origin.x {
    commands.push(
      FillRect(
        Rect::new(
          x=start_rect.origin.x,
          y=frame.origin.y + 4.0,
          width=end_rect.origin.x - start_rect.origin.x,
          height=max_double(10.0, frame.size.height - 8.0),
        ),
        Color::blue().with_alpha(0.18),
      ),
    )
  }
}
