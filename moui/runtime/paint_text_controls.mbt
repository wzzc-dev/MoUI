///|
fn append_text_field_selection_commands(
  commands : Array[DrawCommand],
  text : String,
  text_frame : Rect,
  layout : TextLayoutResult,
  selection : TextRange?,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let selection = normalize_grapheme_range(
        TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(
        selection.start,
        0,
        layout.caret_positions.length() - 1,
      )
      let end = clamp_int(
        selection.end,
        start,
        layout.caret_positions.length() - 1,
      )
      let x0 = text_frame.origin.x + layout.caret_positions[start]
      let x1 = text_frame.origin.x + layout.caret_positions[end]
      if x1 > x0 {
        commands.push(
          FillRect(
            Rect::new(
              x=x0,
              y=text_frame.origin.y + 6.0,
              width=x1 - x0,
              height=max_double(8.0, text_frame.size.height - 12.0),
            ),
            Color::blue().with_alpha(0.18),
          ),
        )
      }
    }
    None => ()
  }
}

///|
fn append_text_field_editing_overlay(
  commands : Array[DrawCommand],
  text : String,
  display_text : String,
  text_frame : Rect,
  layout : TextLayoutResult,
  element : ElementNode,
  cursor_color : Color,
) -> Unit {
  commands.push(PushClip(text_frame))
  if element.control.composition is None {
    append_text_field_selection_commands(
      commands,
      display_text,
      text_frame,
      layout,
      element.control.selection,
    )
  } else {
    append_text_field_composition_underline(
      commands, text, text_frame, layout, element, cursor_color,
    )
  }
  let caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    layout.caret_positions.length() - 1,
  )
  let cursor_x = text_frame.origin.x + layout.caret_positions[caret]
  let cursor = Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + 6.0,
    width=1.5,
    height=max_double(8.0, text_frame.size.height - 12.0),
  )
  commands.push(FillRect(cursor, cursor_color))
  commands.push(PopClip)
}

///|
fn append_text_field_composition_underline(
  commands : Array[DrawCommand],
  text : String,
  text_frame : Rect,
  layout : TextLayoutResult,
  element : ElementNode,
  cursor_color : Color,
) -> Unit {
  match element.control.composition {
    Some(composition) =>
      if composition != "" {
        let start = clamp_int(
          composition_start_index(
            text,
            element.control.caret,
            element.control.selection,
          ),
          0,
          layout.caret_positions.length() - 1,
        )
        let end = clamp_int(
          start + text_length(composition),
          start,
          layout.caret_positions.length() - 1,
        )
        let x0 = text_frame.origin.x + layout.caret_positions[start]
        let x1 = text_frame.origin.x + layout.caret_positions[end]
        if x1 > x0 {
          commands.push(
            FillRect(
              Rect::new(
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
  commands : Array[DrawCommand],
  frame : Rect,
  color : Color,
) -> Unit {
  let center = Point::new(
    x=frame.origin.x + frame.size.width * 0.42,
    y=frame.origin.y + frame.size.height * 0.42,
  )
  let radius = frame.size.width * 0.26
  commands.push(
    StrokeRoundedRect(
      RoundedRect::new(
        rect=Rect::new(
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
    DrawPath(
      PathSpec::new(
        verbs=[
          PathVerb::MoveTo(
            Point::new(x=center.x + radius * 0.7, y=center.y + radius * 0.7),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + frame.size.width * 0.86,
              y=frame.origin.y + frame.size.height * 0.86,
            ),
          ),
        ],
        stroke=Some(Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
fn append_searchbar_clear_icon(
  commands : Array[DrawCommand],
  frame : Rect,
  color : Color,
) -> Unit {
  let inset = frame.size.width * 0.28
  commands.push(
    DrawPath(
      PathSpec::new(
        verbs=[
          PathVerb::MoveTo(
            Point::new(x=frame.origin.x + inset, y=frame.origin.y + inset),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
          PathVerb::MoveTo(
            Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + inset,
            ),
          ),
          PathVerb::LineTo(
            Point::new(
              x=frame.origin.x + inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
        ],
        stroke=Some(Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
fn append_text_field_commands(
  commands : Array[DrawCommand],
  overlay_commands : Array[DrawCommand],
  element : ElementNode,
  data : TextFieldViewSpec,
  frame : Rect,
  focused : Bool,
  environment : RenderEnvironment,
) -> Unit {
  let border = if focused { data.focused_border } else { data.border }
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  if data.corner_radius > 0.0 {
    commands.push(FillRoundedRectBrush(rounded, data.background))
  } else {
    commands.push(FillRoundedRectBrush(rounded, data.background))
  }
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }
  let text = data.value.get()
  let display_text = text_with_composition(text, element, focused)
  let display = if display_text == "" { data.placeholder } else { display_text }
  let font = environment_font(environment, data.font)
  let color = if text == "" {
    environment_color(environment, data.placeholder_color)
  } else {
    environment_color(environment, data.foreground)
  }
  let text_frame = frame.inset(Insets::symmetric(horizontal=10.0, vertical=4.0))
  commands.push(
    DrawText(
      TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text,
      display_text,
      text_frame,
      layout,
      element,
      data.cursor_color,
    )
  }
}

///|
fn append_searchbar_commands(
  commands : Array[DrawCommand],
  overlay_commands : Array[DrawCommand],
  element : ElementNode,
  data : SearchBarViewSpec,
  frame : Rect,
  environment : RenderEnvironment,
  focused_id : ElementId?,
) -> Unit {
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  let is_focused = focused_id == Some(element.id)
  let border = if is_focused { data.focused_border } else { data.border }
  commands.push(FillRoundedRectBrush(rounded, data.background))
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }

  let icon_frame = Rect::new(
    x=frame.origin.x + 10.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
  append_searchbar_search_icon(
    commands,
    icon_frame,
    data.foreground.with_alpha(0.6),
  )

  let text = data.query.get()
  let display_text = text_with_composition(text, element, is_focused)
  let display = if display_text == "" { data.placeholder } else { display_text }
  let font = environment_font(environment, data.font)
  let color = if text == "" {
    environment_color(environment, data.placeholder_color)
  } else {
    environment_color(environment, data.foreground)
  }
  let text_frame = searchbar_text_frame(frame, has_text=text != "")
  commands.push(
    DrawText(
      TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=TextAlign::TextStart,
      ),
    ),
  )
  if is_focused {
    let layout = environment_measure_text(
      environment,
      TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text,
      display_text,
      text_frame,
      layout,
      element,
      data.cursor_color,
    )
  }

  if text != "" {
    let clear_frame = Rect::new(
      x=frame.origin.x + frame.size.width - 26.0,
      y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
      width=16.0,
      height=16.0,
    )
    append_searchbar_clear_icon(
      commands,
      clear_frame,
      data.foreground.with_alpha(0.6),
    )
  }
}

///|
fn searchbar_text_frame(frame : Rect, has_text~ : Bool) -> Rect {
  Rect::new(
    x=frame.origin.x + 32.0,
    y=frame.origin.y,
    width=if has_text {
      frame.size.width - 64.0
    } else {
      frame.size.width - 32.0
    },
    height=frame.size.height,
  ).inset(Insets::symmetric(vertical=0.0))
}
