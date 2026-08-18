///|
fn[Msg] handle_text_field_event(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  search_bar~ : Bool,
  on_clear~ : Msg?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_text_field_pointer(
        ctx,
        value~,
        font~,
        on_input~,
        search_bar~,
        on_clear~,
        event,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_text_field_keyboard(ctx, value~, on_input~, on_submit~, event)
    @core.AppEvent::TextInput(event) =>
      view_text_input_result(ctx, value~, on_input~, event, record_history=true)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_text_field_pointer(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  search_bar~ : Bool,
  on_clear~ : Msg?,
  event : @core.PointerEvent,
) -> @core.ViewEventResult[Msg] {
  let text = value
  if search_bar && text != "" {
    let clear_frame = searchbar_clear_frame(ctx.frame)
    if event.phase == @core.PointerPhase::Up &&
      clear_frame.contains(event.position) {
      let next_control = text_control_for_text(ctx.text_control, "")
      let messages = text_input_messages(on_input, "") +
        option_message(on_clear)
      return @common.view_event_result(
        changed=true,
        activated=true,
        focused=true,
        captured=true,
        text_control=Some(next_control),
        dirty=@core.ViewDirtyHint::ViewBuildDirty,
        messages~,
      )
    }
  }
  if event.phase == @core.PointerPhase::Down &&
    ctx.frame.contains(event.position) {
    let caret = single_line_text_caret_at_position(
      text,
      ctx.frame,
      font,
      ctx.text_system,
      search_bar,
      event.position,
    )
    let next_control = {
      ..ctx.text_control,
      caret,
      selection: None,
      text_selection_anchor: Some(caret),
      composition: None,
      composition_cursor: None,
    }
    @common.view_event_result(
      changed=true,
      focused=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.phase == @core.PointerPhase::Move &&
    ctx.text_control.text_selection_anchor is Some(anchor) {
    let caret = single_line_text_caret_at_position(
      text,
      ctx.frame,
      font,
      ctx.text_system,
      search_bar,
      event.position,
    )
    let selection = if caret == anchor {
      None
    } else {
      Some(
        @core.TextRange::new(
          start=@core.min_int(anchor, caret),
          end=@core.max_int(anchor, caret),
        ),
      )
    }
    if caret != ctx.text_control.caret || selection != ctx.text_control.selection {
      @common.view_event_result(
        changed=true,
        captured=true,
        text_control=Some({ ..ctx.text_control, caret, selection }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if event.phase == @core.PointerPhase::Up &&
    ctx.text_control.text_selection_anchor is Some(_) {
    @common.view_event_result(
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
fn[Msg] handle_text_field_keyboard(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  event : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Enter" {
    return @common.view_event_result(
      changed=true,
      activated=on_submit is Some(_),
      captured=true,
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=option_message(on_submit),
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value)
    return @common.view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  }
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=true)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewBuildDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=false)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewBuildDirty,
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
  if event.key == "ArrowLeft" {
    return view_caret_move_result(ctx, value, MoveLeft, event.modifiers.shift)
  }
  if event.key == "ArrowRight" {
    return view_caret_move_result(ctx, value, MoveRight, event.modifiers.shift)
  }
  if event.key == "Home" {
    return view_caret_move_result(ctx, value, MoveStart, event.modifiers.shift)
  }
  if event.key == "End" {
    return view_caret_move_result(ctx, value, MoveEnd, event.modifiers.shift)
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
