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
  @core.View::from_node(
    TextArea::{
      value,
      placeholder,
      size,
      theme,
      variant,
      style,
      lines,
      line_height,
      theme_revision,
      variant_label,
      key,
    },
    event=(node, ctx) => text_area_event(node, ctx, on_input, on_submit),
    text_command=(node, ctx, intent, paste_text) => {
      handle_text_field_command(
        ctx,
        value=node.value,
        on_input~,
        intent,
        paste_text~,
      )
    },
  )
}

///|
fn[Msg] text_area_event(
  node : TextArea,
  ctx : @core.ViewEventContext,
  on_input : ((String) -> Msg)?,
  on_submit : Msg?,
) -> @core.ViewEventResult[Msg] {
  let resolved_theme = node.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match node.style {
    Some(value) => value
    None => node.variant.style(resolved_theme)
  }
  handle_text_area_event(
    ctx,
    value=node.value,
    on_input~,
    on_submit~,
    font=resolved_style.font,
    line_height=node.line_height,
  )
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
      extend_selection=event.modifiers.shift,
    )
  }
  if event.key == "ArrowDown" {
    return text_area_vertical_caret_move(
      ctx,
      value.get(),
      font~,
      line_height~,
      up=false,
      extend_selection=event.modifiers.shift,
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
  extend_selection~ : Bool,
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
  if hit.offset == ctx.text_control.caret && !extend_selection {
    return @core.ViewEventResult::ignored()
  }
  let next_control = if extend_selection {
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
      width=text_editing_cursor_width(),
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
