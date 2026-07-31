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
  visible_lines~ : Int,
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
  if is_placeholder {
    let wrap_ranges = text_area_wrap_line_ranges(
      text_system,
      placeholder,
      font,
      text_frame.size.width,
      visible_lines,
    )
    let chars = placeholder.to_array()
    for line_index, line_range in wrap_ranges {
      if line_range.start >= line_range.end {
        continue
      }
      let line_text = String::from_array(chars[line_range.start:line_range.end])
      text_area_draw_line_text(
        commands,
        text_system,
        line_text,
        font,
        placeholder_color,
        text_frame,
        line_index,
        line_height,
        text_frame.origin.x,
        text_frame.size.width,
      )
    }
  } else {
    let wrap_ranges = text_area_wrap_line_ranges(
      text_system,
      display_text,
      font,
      text_frame.size.width,
      visible_lines,
    )
    let chars = display_text.to_array()
    for line_index, line_range in wrap_ranges {
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
        text_frame,
        line_index,
        line_height,
        text_frame.origin.x,
        text_frame.size.width,
      )
    }
  }
  commands.push(@core.DrawCommand::PopClip)
  if focused {
    overlay_commands.push(@core.DrawCommand::PushClip(text_frame))
    if control.composition is None {
      let selection_color = theme.palette.primary.with_alpha(0.18)
      match active_text_selection(control.selection) {
        Some(sel) => {
          let rects = paragraph.selection_rects(sel)
          for rect in rects {
            let adjusted = @core.Rect::new(
              x=text_frame.origin.x + rect.origin.x,
              y=text_frame.origin.y + rect.origin.y,
              width=rect.size.width,
              height=rect.size.height,
            )
            overlay_commands.push(
              @core.DrawCommand::FillRect(adjusted, selection_color),
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
              text_system, display_text, text_frame, font, start_off, line_height,
              visible_lines,
            )
            let r1 = text_area_display_caret_rect(
              text_system, display_text, text_frame, font, end_off, line_height,
              visible_lines,
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
        y=text_area_line_slot_y(text_frame, 0, line_height, glyph_h),
        width=text_editing_cursor_width(),
        height=glyph_h,
      )
    } else {
      text_area_display_caret_rect(
        text_system, display_text, text_frame, font, visual_caret, line_height, visible_lines,
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
