///|
fn append_text_area_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  text~ : String,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  frame~ : @core.Rect,
  focused~ : Bool,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  theme~ : @core.Theme,
  scroll_offset~ : Double,
  line_height~ : Double,
) -> Unit {
  let border = if focused { focused_border } else { border }
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  append_border(commands, rounded, border)
  let display_text = text_with_composition(text, control, focused~)
  let text_frame = text_area_text_frame(frame)
  let is_placeholder = display_text == ""
  let paint_color = if is_placeholder { placeholder_color } else { foreground }
  let paragraph = text_area_paragraph(
    text_system,
    if is_placeholder {
      ""
    } else {
      display_text
    },
    font,
    text_frame,
  )
  commands.push(@core.DrawCommand::PushClip(text_frame))
  let wrapped = if is_placeholder {
    text_area_paragraph(text_system, placeholder, font, text_frame)
  } else {
    paragraph
  }
  // The scroll offset is clamped against the painted content here so a
  // stale stored offset (external text replacement) can never show
  // blank space; drawing helpers receive a content frame shifted up by
  // the offset while the clip stays pinned to the viewport frame.
  let offset = text_area_clamped_scroll_offset(
    scroll_offset,
    line_count=wrapped.lines.length(),
    line_height~,
    viewport_height=text_frame.size.height,
  )
  let content_frame = @core.Rect::new(
    x=text_frame.origin.x,
    y=text_frame.origin.y - offset,
    width=text_frame.size.width,
    height=text_frame.size.height,
  )
  let window = text_area_visible_line_window(
    offset~,
    viewport_height=text_frame.size.height,
    line_count=wrapped.lines.length(),
    line_height~,
  )
  let chars = wrapped.text.to_array()
  for line in wrapped.lines {
    if line.line_index < window.0 {
      continue
    }
    if line.line_index >= window.1 {
      break
    }
    let line_range = line.text_range
    if line_range.start >= line_range.end {
      continue
    }
    let line_text = String::from_array(chars[line_range.start:line_range.end])
    text_area_draw_line_text(
      commands,
      text_system,
      line_text,
      font,
      paint_color,
      content_frame,
      line.line_index,
      line_height,
      text_frame.origin.x,
      text_frame.size.width,
    )
  }
  commands.push(@core.DrawCommand::PopClip)
  if focused {
    overlay_commands.push(@core.DrawCommand::PushClip(text_frame))
    if control.composition is None {
      let selection_color = theme.palette.primary.with_alpha(0.18)
      match active_text_selection(control.selection) {
        Some(sel) => {
          let rects = text_area_selection_slot_rects(
            paragraph, text_system, font, sel, content_frame, line_height,
          )
          for rect in rects {
            overlay_commands.push(
              @core.DrawCommand::FillRect(rect, selection_color),
            )
          }
        }
        None => ()
      }
    } else if display_text != "" {
      match control.composition {
        Some(composition) =>
          if composition != "" {
            let comp_start = composition_start_index(
              text,
              control.caret,
              control.selection,
            )
            let boundaries = @core.TextGraphemeBoundaries::new(
              text=display_text,
            )
            let start_off = boundaries.nearest_boundary(comp_start)
            let end_off = boundaries.nearest_boundary(
              comp_start + text_length(composition),
            )
            let r0 = text_area_display_caret_rect(
              paragraph, text_system, content_frame, font, start_off, line_height,
            )
            let r1 = text_area_display_caret_rect(
              paragraph, text_system, content_frame, font, end_off, line_height,
            )
            if r1.origin.x > r0.origin.x {
              overlay_commands.push(
                @core.DrawCommand::FillRect(
                  @core.Rect::new(
                    x=r0.origin.x,
                    y=r0.origin.y + r0.size.height - 2.0,
                    width=r1.origin.x - r0.origin.x,
                    height=1.5,
                  ),
                  cursor_color.with_alpha(0.72),
                ),
              )
            }
          }
        None => ()
      }
    }
    let visual_caret = text_field_visual_caret(text, control, focused=true)
    let cursor = if display_text == "" {
      let glyph_h = text_area_glyph_row_height(text_system, " ", font)
      @core.Rect::new(
        x=text_frame.origin.x,
        y=text_area_line_slot_y(content_frame, 0, line_height, glyph_h),
        width=text_editing_cursor_width(),
        height=glyph_h,
      )
    } else {
      text_area_display_caret_rect(
        paragraph, text_system, content_frame, font, visual_caret, line_height,
      )
    }
    overlay_commands.push(
      @core.DrawCommand::FillRect(
        text_editing_visual_cursor_rect(
          cursor,
          visual_caret,
          display_text.to_array().length(),
        ),
        cursor_color,
      ),
    )
    overlay_commands.push(@core.DrawCommand::PopClip)
  }
}
