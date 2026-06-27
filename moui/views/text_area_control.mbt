

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
    @core.TextLayoutInput::new(
      text=text,
      font=font,
      max_width=text_frame.size.width,
    ),
  )
}

fn text_area_min_int(a : Int, b : Int) -> Int {
  if a <= b { a } else { b }
}

fn text_area_max_int(a : Int, b : Int) -> Int {
  if a >= b { a } else { b }
}

fn text_area_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min { min } else if value > max { max } else { value }
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
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
        child_viewport: None,
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
        actions=[
          @core.SemanticsAction::Focus,
          @core.SemanticsAction::SetText,
        ],
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
) -> Unit {
  let border = if focused { focused_border } else { border }
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  append_border(commands, rounded, border)
  let display_text = text_with_composition(text, control, focused~)
  let text_frame = text_area_text_frame(frame)
  let paragraph = text_area_paragraph(text_system, display_text, font, text_frame)
  commands.push(@core.DrawCommand::PushClip(text_frame))
  if display_text == "" {
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=placeholder,
          frame=text_frame,
          font=font,
          color=placeholder_color,
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
  } else {
    for line in paragraph.lines {
      let line_range = line.text_range
      if line_range.start < line_range.end {
        let chars = display_text.to_array()
        let line_text = String::from_array(chars[line_range.start:line_range.end])
        let line_frame = @core.Rect::new(
          x=text_frame.origin.x + line.origin.x,
          y=text_frame.origin.y + line.origin.y,
          width=line.size.width,
          height=line.size.height,
        )
        commands.push(
          @core.DrawCommand::DrawText(
            @core.TextRun::new(
              text=line_text,
              frame=line_frame,
              font=font,
              color=foreground,
              align=@core.TextAlign::TextStart,
            ),
          ),
        )
      }
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
    }
    let visual_caret = text_field_visual_caret(text, control, focused=true)
    let caret_rect = paragraph.caret_rect_at(visual_caret)
    let cursor = @core.Rect::new(
      x=text_frame.origin.x + caret_rect.origin.x,
      y=text_frame.origin.y + caret_rect.origin.y,
      width=1.5,
      height=max_double(16.0, caret_rect.size.height),
    )
    overlay_commands.push(@core.DrawCommand::FillRect(cursor, cursor_color))
    overlay_commands.push(@core.DrawCommand::PopClip)
  }
}

///|
fn[Msg] handle_text_area_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
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
  font~ : @core.FontSpec,
  line_height~ : Double,
  event : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Enter" {
    return view_text_input_result(
      ctx,
      value~,
      on_input~,
      @core.TextInputEvent::InsertText("\n"),
      record_history=true,
    )
  }
  if is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value.get())
    return view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  }
  if is_undo_shortcut(event) {
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
  if is_redo_shortcut(event) {
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
      @core.TextCaretDirection::MoveLeft,
      event.modifiers.shift,
    )
  }
  if event.key == "ArrowRight" {
    return view_caret_move_result(
      ctx,
      value.get(),
      @core.TextCaretDirection::MoveRight,
      event.modifiers.shift,
    )
  }
  if event.key == "Home" {
    return view_caret_move_result(
      ctx,
      value.get(),
      @core.TextCaretDirection::MoveStart,
      event.modifiers.shift,
    )
  }
  if event.key == "End" {
    return view_caret_move_result(
      ctx,
      value.get(),
      @core.TextCaretDirection::MoveEnd,
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
    let start = text_area_min_int(anchor, hit.offset)
    let end = text_area_max_int(anchor, hit.offset)
    {
      ..ctx.text_control,
      caret: hit.offset,
      selection: Some(@core.TextRange::new(start=start, end=end)),
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
      let start = text_area_min_int(anchor, hit.offset)
      let end = text_area_max_int(anchor, hit.offset)
      let next_control = {
        ..ctx.text_control,
        caret: hit.offset,
        selection: Some(@core.TextRange::new(start=start, end=end)),
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
      text_control=Some(
        { ..ctx.text_control, text_selection_anchor: None },
      ),
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
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, control, focused=true)
  let text_frame = text_area_text_frame(frame)
  let paragraph = text_area_paragraph(text_system, display_text, font, text_frame)
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = text_area_clamp_int(
    text_field_visual_caret(text, control, focused=true),
    0,
    text_area_max_int(0, paragraph.caret_rects.length() - 1),
  )
  let caret_rect = paragraph.caret_rect_at(visual_caret)
  let adjusted_rect = @core.Rect::new(
    x=text_frame.origin.x + caret_rect.origin.x,
    y=text_frame.origin.y + caret_rect.origin.y,
    width=max_double(1.5, caret_rect.size.width),
    height=max_double(16.0, caret_rect.size.height),
  )
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
