///|
fn text_area_text_frame(frame : @core.Rect) -> @core.Rect {
  frame.inset(@core.Insets::symmetric(horizontal=10.0, vertical=8.0))
}

///|
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
fn text_area_soft_break_after(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '、' ||
  ch == '，' ||
  ch == '。' ||
  ch == '；' ||
  ch == '：' ||
  ch == '）' ||
  ch == ')'
}

///|
fn text_area_measure_width(
  text_system : @core.TextSystem,
  text : String,
  font : @core.FontSpec,
) -> Double {
  text_system.measure_text(@core.TextLayoutInput::new(text~, font~)).size.width
}

///|
/// Wrap using the active TextSystem measure (Skia real widths when available).
fn text_area_wrap_line_ranges(
  text_system : @core.TextSystem,
  text : String,
  font : @core.FontSpec,
  max_width : Double,
  max_lines : Int,
) -> Array[@core.TextRange] {
  let chars = text.to_array()
  let length = chars.length()
  if length == 0 || max_width <= 0.0 || max_lines <= 0 {
    return []
  }
  let ranges : Array[@core.TextRange] = []
  let mut start = 0
  while start < length && ranges.length() < max_lines {
    let mut end = start
    let mut last_break = start
    let mut fits = true
    while end < length {
      let candidate = String::from_array(chars[start:end + 1])
      let width = text_area_measure_width(text_system, candidate, font)
      if width > max_width && end > start {
        fits = false
        break
      }
      if chars[end] == '\n' {
        end = end + 1
        fits = false
        break
      }
      if text_area_soft_break_after(chars[end]) {
        last_break = end + 1
      }
      end = end + 1
    }
    let line_end = if fits {
      length
    } else if end > start && chars[end - 1] == '\n' {
      end
    } else if last_break > start {
      last_break
    } else if end > start + 1 {
      end - 1
    } else {
      end
    }
    if line_end <= start {
      break
    }
    ranges.push(@core.TextRange::new(start~, end=line_end))
    start = line_end
  }
  ranges
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
fn text_area_line_index_for_offset(
  wrap_ranges : Array[@core.TextRange],
  offset : Int,
) -> Int {
  for line_index, line_range in wrap_ranges {
    if offset >= line_range.start && offset <= line_range.end {
      return line_index
    }
  }
  if wrap_ranges.is_empty() {
    0
  } else {
    wrap_ranges.length() - 1
  }
}

///|
fn text_area_display_caret_rect(
  text_system : @core.TextSystem,
  display_text : String,
  text_frame : @core.Rect,
  font : @core.FontSpec,
  visual_offset : Int,
  line_height : Double,
  visible_lines : Int,
) -> @core.Rect {
  let boundaries = @core.TextGraphemeBoundaries::new(text=display_text)
  let max_len = display_text.to_array().length()
  let offset = boundaries.nearest_boundary(
    visual_offset.clamp(min=0, max=max_len),
  )
  let wrap_ranges = text_area_wrap_line_ranges(
    text_system,
    display_text,
    font,
    text_frame.size.width,
    visible_lines,
  )
  let line_index = text_area_line_index_for_offset(wrap_ranges, offset)
  let line_start = if line_index < wrap_ranges.length() {
    wrap_ranges[line_index].start
  } else {
    0
  }
  let chars = display_text.to_array()
  let prefix = String::from_array(chars[line_start:offset])
  let measured = text_system.measure_text(
    @core.TextLayoutInput::new(
      text=prefix,
      font~,
      max_width=text_frame.size.width,
    ),
  )
  let glyph_h = text_area_glyph_row_height(text_system, " ", font)
  let y = text_area_line_slot_y(text_frame, line_index, line_height, glyph_h)
  @core.Rect::new(
    x=text_frame.origin.x + measured.size.width,
    y~,
    width=text_editing_cursor_width(),
    height=glyph_h,
  )
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
