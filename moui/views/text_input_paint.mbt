///|
fn append_text_field_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  text~ : String,
  placeholder~ : String,
  size~ : @core.Size,
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
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> Unit {
  ignore(size)
  let border = if focused { focused_border } else { border }
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  if bottom_border_only {
    append_bottom_border(commands, frame, border)
  } else {
    append_border(commands, rounded, border)
  }
  // Fluent 2 focus reveal: paint an inner stroke inside the frame when focused.
  match inner_focus_border {
    Some(color) =>
      append_inner_focus_border(commands, frame, color, corner_radius)
    None => ()
  }
  let display_text = text_with_composition(text, control, focused~)
  let display = if display_text == "" { placeholder } else { display_text }
  let color = if text == "" { placeholder_color } else { foreground }
  let text_frame = frame.inset(
    @core.Insets::symmetric(horizontal=10.0, vertical=4.0),
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text~,
      display_text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
      theme~,
    )
  }
}

///|
fn append_searchbar_commands(
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
) -> Unit {
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  let border = if focused { focused_border } else { border }
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  append_border(commands, rounded, border)
  let icon_frame = @core.Rect::new(
    x=frame.origin.x + 10.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
  append_searchbar_search_icon(commands, icon_frame, foreground.with_alpha(0.6))
  let display_text = text_with_composition(text, control, focused~)
  let display = if display_text == "" { placeholder } else { display_text }
  let color = if text == "" { placeholder_color } else { foreground }
  let text_frame = searchbar_text_frame(frame, has_text=text != "")
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text~,
      display_text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
      theme~,
    )
  }
  if text != "" {
    let clear_frame = searchbar_clear_frame(frame)
    append_searchbar_clear_icon(
      commands,
      clear_frame,
      foreground.with_alpha(0.6),
    )
  }
}

///|
fn append_border(
  commands : Array[@core.DrawCommand],
  rounded : @core.RoundedRect,
  border : @core.BorderStyle?,
) -> Unit {
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          @core.DrawCommand::StrokeRoundedRectBrush(
            rounded,
            border.brush,
            border.width,
          ),
        )
      }
    None => ()
  }
}

///|
/// Fluent 2 underline text field: paint only the bottom edge as a straight
/// line, ignoring side/top borders and corner radius.
fn append_bottom_border(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  border : @core.BorderStyle?,
) -> Unit {
  match border {
    Some(border) =>
      if border.width > 0.0 {
        let y = frame.origin.y + frame.size.height - border.width / 2.0
        let path = @core.PathSpec::new(
          verbs=[
            @core.PathVerb::MoveTo(@core.Point::new(x=frame.origin.x, y~)),
            @core.PathVerb::LineTo(
              @core.Point::new(x=frame.origin.x + frame.size.width, y~),
            ),
          ],
          stroke=Some(border.brush),
          stroke_width=border.width,
        )
        commands.push(@core.DrawCommand::DrawPath(path))
      }
    None => ()
  }
}

///|
/// Fluent 2 focus reveal: paint an inner stroke inset 2px inside the control
/// frame so focus reads as a distinct inner ring rather than a thicker outer
/// border.
fn append_inner_focus_border(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
  corner_radius : Double,
) -> Unit {
  let inset = 2.0
  let inner = @core.RoundedRect::new(
    rect=@core.Rect::new(
      x=frame.origin.x + inset,
      y=frame.origin.y + inset,
      width=frame.size.width - inset * 2.0,
      height=frame.size.height - inset * 2.0,
    ),
    radius=(corner_radius - inset).clamp(min=0.0, max=corner_radius),
  )
  commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(
      inner,
      @core.Brush::solid(color),
      1.0,
    ),
  )
}

///|
fn append_text_field_editing_overlay(
  commands : Array[@core.DrawCommand],
  text~ : String,
  display_text~ : String,
  text_frame~ : @core.Rect,
  layout~ : @core.TextLayoutResult,
  control~ : @core.TextControlStateContext,
  cursor_color~ : @core.Color,
  theme~ : @core.Theme,
) -> Unit {
  commands.push(@core.DrawCommand::PushClip(text_frame))
  if control.composition is None {
    append_text_field_selection_commands(
      commands,
      display_text,
      text_frame,
      layout,
      control.selection,
      theme,
    )
  } else {
    append_text_field_composition_underline(
      commands,
      text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
    )
  }
  let caret = clamp_int(
    text_field_visual_caret(text, control, focused=true),
    0,
    max_int(0, layout.caret_positions.length() - 1),
  )
  let cursor_x = text_frame.origin.x + layout.caret_positions[caret]
  let cursor = text_editing_visual_cursor_rect(
    @core.Rect::new(
      x=cursor_x,
      y=text_frame.origin.y + 6.0,
      width=text_editing_cursor_width(),
      height=max_double(8.0, text_frame.size.height - 12.0),
    ),
    caret,
    display_text.to_array().length(),
  )
  commands.push(@core.DrawCommand::FillRect(cursor, cursor_color))
  commands.push(@core.DrawCommand::PopClip)
}

///|
fn append_text_field_selection_commands(
  commands : Array[@core.DrawCommand],
  text : String,
  text_frame : @core.Rect,
  layout : @core.TextLayoutResult,
  selection : @core.TextRange?,
  theme : @core.Theme,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let selection = @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(
        selection.start,
        0,
        max_int(0, layout.caret_positions.length() - 1),
      )
      let end = clamp_int(
        selection.end,
        start,
        max_int(start, layout.caret_positions.length() - 1),
      )
      let x0 = text_frame.origin.x + layout.caret_positions[start]
      let x1 = text_frame.origin.x + layout.caret_positions[end]
      if x1 > x0 {
        // Selection highlight tracks the ambient theme's primary palette token
        // so it follows the active color scheme (light/dark) and custom palette
        // overrides, rather than a hard-coded light theme. The alpha matches the
        // rich text editor selection highlight convention (0.18) so plain text
        // fields and rich editors render selection highlights consistently.
        let selection_color = theme.palette.primary.with_alpha(0.18)
        commands.push(
          @core.DrawCommand::FillRect(
            @core.Rect::new(
              x=x0,
              y=text_frame.origin.y + 6.0,
              width=x1 - x0,
              height=max_double(8.0, text_frame.size.height - 12.0),
            ),
            selection_color,
          ),
        )
      }
    }
    None => ()
  }
}

///|
fn append_text_field_composition_underline(
  commands : Array[@core.DrawCommand],
  text~ : String,
  text_frame~ : @core.Rect,
  layout~ : @core.TextLayoutResult,
  control~ : @core.TextControlStateContext,
  cursor_color~ : @core.Color,
) -> Unit {
  match control.composition {
    Some(composition) =>
      if composition != "" {
        let start = clamp_int(
          composition_start_index(text, control.caret, control.selection),
          0,
          max_int(0, layout.caret_positions.length() - 1),
        )
        let end = clamp_int(
          start + text_length(composition),
          start,
          max_int(start, layout.caret_positions.length() - 1),
        )
        let x0 = text_frame.origin.x + layout.caret_positions[start]
        let x1 = text_frame.origin.x + layout.caret_positions[end]
        if x1 > x0 {
          commands.push(
            @core.DrawCommand::FillRect(
              @core.Rect::new(
                x=x0,
                y=text_frame.origin.y + text_frame.size.height - 7.0,
                width=x1 - x0,
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

///|
fn append_searchbar_search_icon(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
) -> Unit {
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width * 0.42,
    y=frame.origin.y + frame.size.height * 0.42,
  )
  let radius = frame.size.width * 0.26
  commands.push(
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=center.x - radius,
          y=center.y - radius,
          width=radius * 2.0,
          height=radius * 2.0,
        ),
        radius~,
      ),
      color,
      1.6,
    ),
  )
  commands.push(
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(
            @core.Point::new(
              x=center.x + radius * 0.7,
              y=center.y + radius * 0.7,
            ),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width * 0.86,
              y=frame.origin.y + frame.size.height * 0.86,
            ),
          ),
        ],
        stroke=Some(@core.Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
fn append_searchbar_clear_icon(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
) -> Unit {
  let inset = frame.size.width * 0.28
  commands.push(
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(
            @core.Point::new(x=frame.origin.x + inset, y=frame.origin.y + inset),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
          @core.PathVerb::MoveTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + inset,
            ),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
        ],
        stroke=Some(@core.Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}
