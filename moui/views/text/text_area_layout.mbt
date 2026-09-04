///|
fn text_area_text_frame(frame : @core.Rect) -> @core.Rect {
  frame.inset(@core.Insets::symmetric(horizontal=10.0, vertical=8.0))
}

///|
/// The single wrapping truth for the text area: every painted line,
/// caret, and selection rect derives from this paragraph layout, which
/// the shared `TextSystem` memoizes per (text, font, width).
fn text_area_paragraph(
  text_system : @core.TextSystem,
  text : String,
  font : @core.FontSpec,
  text_frame : @core.Rect,
) -> @core.TextParagraphLayoutResult {
  text_system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width=text_frame.size.width),
  )
}

///|
fn text_area_glyph_row_height(
  text_system : @core.TextSystem,
  line_text : String,
  font : @core.FontSpec,
) -> Double {
  text_system.measure_text(@core.TextLayoutInput::new(text=line_text, font~)).size.height.max(
    font.size * 1.15,
  )
}

///|
fn text_area_line_slot_y(
  text_frame : @core.Rect,
  line_index : Int,
  line_height : Double,
  glyph_height : Double,
) -> Double {
  let slot_top = text_frame.origin.y + line_index.to_double() * line_height
  slot_top + (line_height - glyph_height).max(0.0) / 2.0
}

///|
/// Paragraph line owning the given character offset. The fallback and
/// native paragraph metrics both cover the text contiguously, and both
/// fill a caret rect for a line-start offset as that line's first
/// caret, so an offset sitting exactly on a line boundary (other than
/// the document start) belongs to the line that *starts* there — not
/// to the previous line's end.
fn text_area_line_index_for_paragraph_offset(
  paragraph : @core.TextParagraphLayoutResult,
  offset : Int,
) -> Int {
  let max_len = paragraph.text.to_array().length()
  let boundaries = @core.TextGraphemeBoundaries::new(text=paragraph.text)
  let offset = boundaries.nearest_boundary(offset.clamp(min=0, max=max_len))
  for line in paragraph.lines {
    if line.line_index > 0 && line.text_range.start == offset {
      return line.line_index
    }
  }
  for line in paragraph.lines {
    if offset >= line.text_range.start && offset <= line.text_range.end {
      return line.line_index
    }
  }
  if paragraph.lines.is_empty() {
    0
  } else {
    paragraph.lines.length() - 1
  }
}

///|
/// Caret rect for a visual offset: the x comes from the shared
/// paragraph's caret geometry, the y from the widget's line-height slot
/// grid so caret, painted text, and selection highlight share one row
/// model.
fn text_area_display_caret_rect(
  paragraph : @core.TextParagraphLayoutResult,
  text_system : @core.TextSystem,
  text_frame : @core.Rect,
  font : @core.FontSpec,
  visual_offset : Int,
  line_height : Double,
) -> @core.Rect {
  let line_index = text_area_line_index_for_paragraph_offset(
    paragraph, visual_offset,
  )
  let caret = paragraph.caret_rect_at(visual_offset)
  let line_origin_x = if line_index < paragraph.lines.length() {
    paragraph.lines[line_index].origin.x
  } else {
    0.0
  }
  let glyph_h = text_area_glyph_row_height(text_system, " ", font)
  let y = text_area_line_slot_y(text_frame, line_index, line_height, glyph_h)
  @core.Rect::new(
    x=text_frame.origin.x + (caret.origin.x - line_origin_x),
    y~,
    width=text_editing_cursor_width(),
    height=glyph_h,
  )
}

///|
/// Selection highlight rects re-projected onto the widget's slot grid:
/// one rect per overlapping paragraph line, x from the shared caret
/// geometry, y from `text_area_line_slot_y` — the same row the painted
/// glyphs of that line occupy.
fn text_area_selection_slot_rects(
  paragraph : @core.TextParagraphLayoutResult,
  text_system : @core.TextSystem,
  font : @core.FontSpec,
  selection : @core.TextRange,
  text_frame : @core.Rect,
  line_height : Double,
) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  let chars = paragraph.text.to_array()
  for line in paragraph.lines {
    let start = @core.max_int(selection.start, line.text_range.start)
    let end = @core.min_int(selection.end, line.text_range.end)
    if start < end {
      let start_rect = paragraph.caret_rect_at(start)
      let end_rect = paragraph.caret_rect_at(end)
      let x0 = start_rect.origin.x.min(end_rect.origin.x) - line.origin.x
      let x1 = start_rect.origin.x.max(end_rect.origin.x) - line.origin.x
      let glyph_h = text_area_glyph_row_height(
        text_system,
        String::from_array(chars[start:end]),
        font,
      )
      rects.push(
        @core.Rect::new(
          x=text_frame.origin.x + x0,
          y=text_area_line_slot_y(
            text_frame,
            line.line_index,
            line_height,
            glyph_h,
          ),
          width=(x1 - x0).max(1.0),
          height=glyph_h,
        ),
      )
    }
  }
  rects
}

///|
fn text_area_draw_line_text(
  commands : Array[@core.DrawCommand],
  text_system : @core.TextSystem,
  line_text : String,
  font : @core.FontSpec,
  color : @core.Color,
  text_frame : @core.Rect,
  line_index : Int,
  line_height : Double,
  line_left : Double,
  line_width : Double,
) -> Unit {
  let glyph_h = text_area_glyph_row_height(text_system, line_text, font)
  let y = text_area_line_slot_y(text_frame, line_index, line_height, glyph_h)
  let line_frame = @core.Rect::new(
    x=line_left,
    y~,
    width=line_width,
    height=glyph_h,
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=line_text,
        frame=line_frame,
        font~,
        color~,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
}
