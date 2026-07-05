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
    width=1.5,
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

///|
fn[Msg] text_area_control(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Outline,
  style? : TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  lines? : Int = 4,
  line_height? : Double = 28.0,
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let variant_label = match variant {
    TextFieldVariant::Filled => "filled"
    TextFieldVariant::Outline => "outline"
    TextFieldVariant::Plain => "plain"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="TextArea", key~),
    revision=() => {
      "textarea:\{value.get()}:\{placeholder}:\{view_size_revision(size)}:\{variant_label}:\{theme_revision}:\{lines}:\{line_height}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      let normal = resolved_style.normal
      let focused = resolved_style.focused
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_text_area_commands(
        commands,
        overlay_commands,
        text=value.get(),
        placeholder~,
        font=resolved_style.font,
        foreground=normal.foreground,
        placeholder_color=resolved_style.placeholder_color,
        background=normal.background,
        border=normal.border,
        focused_border=focused.border,
        cursor_color=resolved_style.cursor_color,
        corner_radius=normal.radius,
        frame=ctx.frame,
        focused=ctx.focused,
        control=ctx.text_control,
        text_system=ctx.text_system,
        theme=resolved_theme,
        visible_lines=lines,
        line_height~,
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      handle_text_area_event(
        ctx,
        value~,
        on_input~,
        on_submit~,
        font=resolved_style.font,
        line_height~,
      )
    },
    text_input_state=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      Some(
        text_input_state_for_multi_line(
          text=value.get(),
          frame=ctx.frame,
          font=resolved_style.font,
          control=ctx.text_control,
          text_system=ctx.text_system,
          line_height~,
          visible_lines=lines,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      handle_text_field_command(ctx, value~, on_input~, intent, paste_text~)
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value=value.get(),
        actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::SetText],
      )
    },
    focusable=() => true,
  )
}

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
        width=1.5,
        height=glyph_h,
      )
    } else {
      text_area_display_caret_rect(
        text_system, display_text, text_frame, font, visual_caret, line_height, visible_lines,
      )
    }
    overlay_commands.push(@core.DrawCommand::FillRect(cursor, cursor_color))
    overlay_commands.push(@core.DrawCommand::PopClip)
  }
}

///|
fn[Msg] handle_text_area_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  font~ : @core.FontSpec,
  line_height~ : Double,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_text_area_pointer(ctx, value~, font~, event)
    @core.AppEvent::Keyboard(event) =>
      handle_text_area_keyboard(
        ctx,
        value~,
        on_input~,
        on_submit~,
        font~,
        line_height~,
        event,
      )
    @core.AppEvent::TextInput(event) =>
      view_text_input_result(ctx, value~, on_input~, event, record_history=true)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_text_area_keyboard(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  font~ : @core.FontSpec,
  line_height~ : Double,
  event : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Enter" {
    if on_submit is Some(_) && !event.modifiers.shift {
      return view_event_result(
        changed=true,
        activated=on_submit is Some(_),
        captured=true,
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
        messages=option_message(on_submit),
      )
    }
    return view_text_input_result(
      ctx,
      value~,
      on_input~,
      @core.TextInputEvent::InsertText("\n"),
      record_history=true,
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value.get())
    return view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  }
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=true)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=false)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if event.key == "Backspace" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteSurrounding(1, 0),
          record_history=true,
        )
    }
  }
  if event.key == "Delete" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteSurrounding(0, 1),
          record_history=true,
        )
    }
  }
  if event.key == "ArrowUp" {
    return text_area_vertical_caret_move(
      ctx,
      value.get(),
      font~,
      line_height~,
      up=true,
      extend=event.modifiers.shift,
    )
  }
  if event.key == "ArrowDown" {
    return text_area_vertical_caret_move(
      ctx,
      value.get(),
      font~,
      line_height~,
      up=false,
      extend=event.modifiers.shift,
    )
  }
  if event.key == "ArrowLeft" {
    return view_caret_move_result(
      ctx,
      value.get(),
      TextCaretDirection::MoveLeft,
      event.modifiers.shift,
    )
  }
  if event.key == "ArrowRight" {
    return view_caret_move_result(
      ctx,
      value.get(),
      TextCaretDirection::MoveRight,
      event.modifiers.shift,
    )
  }
  if event.key == "Home" {
    return view_caret_move_result(
      ctx,
      value.get(),
      TextCaretDirection::MoveStart,
      event.modifiers.shift,
    )
  }
  if event.key == "End" {
    return view_caret_move_result(
      ctx,
      value.get(),
      TextCaretDirection::MoveEnd,
      event.modifiers.shift,
    )
  }
  match event.text {
    Some(text) =>
      if text != "" {
        view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::InsertText(text),
          record_history=true,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    None => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] text_area_vertical_caret_move(
  ctx : @core.ViewEventContext,
  text : String,
  font~ : @core.FontSpec,
  line_height~ : Double,
  up~ : Bool,
  extend~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text_frame = text_area_text_frame(ctx.frame)
  let display_text = text_with_composition(text, ctx.text_control, focused=true)
  let paragraph = text_area_paragraph(
    ctx.text_system,
    display_text,
    font,
    text_frame,
  )
  let visual_caret = text_field_visual_caret(
    text,
    ctx.text_control,
    focused=true,
  )
  let caret_rect = paragraph.caret_rect_at(visual_caret)
  let target_point = if up {
    @core.Point::new(
      x=caret_rect.origin.x,
      y=caret_rect.origin.y - line_height * 0.5,
    )
  } else {
    @core.Point::new(
      x=caret_rect.origin.x,
      y=caret_rect.origin.y + line_height * 1.5,
    )
  }
  let hit = paragraph.hit_test(target_point)
  if hit.offset == ctx.text_control.caret && !extend {
    return @core.ViewEventResult::ignored()
  }
  let next_control = if extend {
    let anchor = match ctx.text_control.text_selection_anchor {
      Some(a) => a
      None => ctx.text_control.caret
    }
    let start = @core.min_int(anchor, hit.offset)
    let end = @core.max_int(anchor, hit.offset)
    {
      ..ctx.text_control,
      caret: hit.offset,
      selection: Some(@core.TextRange::new(start~, end~)),
      text_selection_anchor: Some(anchor),
      composition: None,
      composition_cursor: None,
    }
  } else {
    {
      ..ctx.text_control,
      caret: hit.offset,
      selection: None,
      text_selection_anchor: None,
      composition: None,
      composition_cursor: None,
    }
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    next_control.selection != ctx.text_control.selection ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
  )
}

///|
fn[Msg] handle_text_area_pointer(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  font~ : @core.FontSpec,
  event : @core.PointerEvent,
) -> @core.ViewEventResult[Msg] {
  let text = value.get()
  let text_frame = text_area_text_frame(ctx.frame)
  let display_text = text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  if event.phase == @core.PointerPhase::Down &&
    ctx.frame.contains(event.position) {
    let paragraph = text_area_paragraph(
      ctx.text_system,
      display_text,
      font,
      text_frame,
    )
    let local_point = @core.Point::new(
      x=event.position.x - text_frame.origin.x,
      y=event.position.y - text_frame.origin.y,
    )
    let hit = paragraph.hit_test(local_point)
    let next_control = {
      ..ctx.text_control,
      caret: hit.offset,
      selection: None,
      text_selection_anchor: Some(hit.offset),
      composition: None,
      composition_cursor: None,
    }
    view_event_result(
      changed=true,
      focused=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.phase == @core.PointerPhase::Move &&
    ctx.text_control.text_selection_anchor is Some(anchor) {
    let paragraph = text_area_paragraph(
      ctx.text_system,
      display_text,
      font,
      text_frame,
    )
    let local_point = @core.Point::new(
      x=event.position.x - text_frame.origin.x,
      y=event.position.y - text_frame.origin.y,
    )
    let hit = paragraph.hit_test(local_point)
    if hit.offset != anchor || hit.offset != ctx.text_control.caret {
      let start = @core.min_int(anchor, hit.offset)
      let end = @core.max_int(anchor, hit.offset)
      let next_control = {
        ..ctx.text_control,
        caret: hit.offset,
        selection: Some(@core.TextRange::new(start~, end~)),
      }
      view_event_result(
        changed=true,
        captured=true,
        text_control=Some(next_control),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if event.phase == @core.PointerPhase::Up &&
    ctx.text_control.text_selection_anchor is Some(_) {
    view_event_result(
      changed=true,
      captured=true,
      text_control=Some({ ..ctx.text_control, text_selection_anchor: None }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn text_input_state_for_multi_line(
  text~ : String,
  frame~ : @core.Rect,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  line_height~ : Double,
  visible_lines~ : Int,
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, control, focused=true)
  let text_frame = text_area_text_frame(frame)
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = text_field_visual_caret(text, control, focused=true)
  let adjusted_rect = if display_text == "" {
    let glyph_h = text_area_glyph_row_height(text_system, " ", font)
    @core.Rect::new(
      x=text_frame.origin.x,
      y=text_area_line_slot_y(text_frame, 0, line_height, glyph_h),
      width=1.5,
      height=glyph_h,
    )
  } else {
    text_area_display_caret_rect(
      text_system, display_text, text_frame, font, visual_caret, line_height, visible_lines,
    )
  }
  {
    focused: true,
    element_id: None,
    text,
    caret,
    selection: text_input_grapheme_selection(boundaries, control.selection),
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect: adjusted_rect,
  }
}
