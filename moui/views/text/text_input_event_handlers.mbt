///|
fn[Msg] handle_text_field_event(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  search_bar~ : Bool,
  on_clear~ : Msg?,
  on_cancel~ : Msg? = None,
) -> @core.ViewEventResult[Msg] {
  let result = match ctx.event {
    Pointer(event) =>
      handle_text_field_pointer(
        ctx,
        value~,
        font~,
        on_input~,
        search_bar~,
        on_clear~,
        event,
      )
    Keyboard(event) =>
      handle_text_field_keyboard(
        ctx,
        value~,
        on_input~,
        on_submit~,
        on_cancel~,
        event,
      )
    TextInput(event) =>
      view_text_input_result(ctx, value~, on_input~, event, record_history=true)
    _ => @core.ViewEventResult::ignored()
  }
  text_field_reveal_caret(ctx, value~, font~, search_bar~, result)
}

///|
/// Publish the caret's surface rect when the caret or the selection
/// moved. A single-line field owns no viewport, so this is the only
/// reveal path it has: the runtime scrolls the nearest `ScrollView`
/// ancestor to it, which is what makes a long form usable on a phone.
fn[Msg] text_field_reveal_caret(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  search_bar~ : Bool,
  result : @core.ViewEventResult[Msg],
) -> @core.ViewEventResult[Msg] {
  let control = match result.text_control {
    None => return result
    Some(control) => control
  }
  if control.caret == ctx.text_control.caret &&
    control.selection == ctx.text_control.selection {
    return result
  }
  let display_text = text_with_composition(value, control, focused=true)
  let text_frame = single_line_text_frame(ctx.frame, search_bar, value != "")
  let layout = ctx.text_system.measure_text(
    @core.TextLayoutInput::new(
      text=display_text,
      font~,
      max_width=text_frame.size.width,
      direction=ctx.environment.layout_direction,
    ),
  )
  let visual_caret = text_field_visual_caret(value, control, focused=true)
  let cursor_x = text_frame.origin.x +
    caret_offset(layout.caret_positions, visual_caret)
  {
    ..result,
    text_control: Some({
      ..control,
      reveal: Some(text_editing_exact_cursor_rect(text_frame, cursor_x)),
    }),
  }
}

///|
fn[Msg] handle_text_field_keyboard(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  on_cancel~ : Msg? = None,
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
      dirty=ViewPaintDirty,
      messages=option_message(on_submit),
    )
  }
  // Escape only means something when the caller has somewhere to go: a bare
  // field leaves it to the enclosing overlay or dialog to dismiss.
  if event.key == "Escape" && on_cancel is Some(_) {
    return @common.view_event_result(
      activated=true,
      captured=true,
      dirty=ViewPaintDirty,
      messages=option_message(on_cancel),
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value)
    return @common.view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=ViewPaintDirty,
    )
  }
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=true)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=ViewBuildDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=false)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=ViewBuildDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if event.key == "Backspace" {
    match @core.active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          DeleteSurrounding(1, 0),
          record_history=true,
        )
    }
  }
  if event.key == "Delete" {
    match @core.active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          DeleteSurrounding(0, 1),
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
          InsertText(text),
          record_history=true,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    None => @core.ViewEventResult::ignored()
  }
}
