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
  // Secondary/middle presses reach the view tree now that host backends
  // route right-button downs for per-target context menus; they must not
  // move the caret or start a selection drag.
  if event.button != 0 {
    return @core.ViewEventResult::ignored()
  }
  let text = value
  if search_bar && text != "" {
    let clear_frame = searchbar_clear_frame(ctx.frame)
    if event.phase == Up && clear_frame.contains(event.position) {
      let next_control = text_control_for_text(ctx.text_control, "")
      let messages = text_input_messages(on_input, "") +
        option_message(on_clear)
      return @common.view_event_result(
        changed=true,
        activated=true,
        focused=true,
        captured=true,
        text_control=Some(next_control),
        dirty=ViewBuildDirty,
        messages~,
      )
    }
  }
  if event.phase == Down && ctx.frame.contains(event.position) {
    let clicks = text_click_count_at_down(
      ctx.state,
      now_ms=ctx.now_ms,
      position=event.position,
    )
    let hit = single_line_text_caret_at_position(
      text,
      ctx.frame,
      font,
      ctx.text_system,
      search_bar,
      event.position,
      direction=ctx.environment.layout_direction,
    )
    let selection = text_click_selection(text, hit, count=clicks.count)
    let caret = match selection {
      Some(range) => range.end
      None => hit
    }
    let next_control = {
      ..ctx.text_control,
      caret,
      selection,
      text_selection_anchor: Some(caret),
      text_selection_origin: Some(event.position),
      goal_column: None,
      composition: None,
      composition_cursor: None,
    }
    @common.view_event_result(
      changed=true,
      focused=true,
      captured=true,
      text_control=Some(next_control),
      state=Some(ctx.state.with_slot(text_click_count_slot(), clicks)),
      dirty=ViewPaintDirty,
    )
  } else if event.phase == Move &&
    ctx.text_control.text_selection_anchor is Some(anchor) {
    if text_pointer_is_stationary(ctx.text_control, position=event.position) {
      // The press's own sample stream: keep the gesture alive without
      // pretending the pointer travelled.
      @common.view_event_result(
        focused=true,
        captured=true,
        text_control=Some(ctx.text_control),
      )
    } else {
      let caret = single_line_text_caret_at_position(
        text,
        ctx.frame,
        font,
        ctx.text_system,
        search_bar,
        event.position,
        direction=ctx.environment.layout_direction,
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
      if caret != ctx.text_control.caret ||
        selection != ctx.text_control.selection {
        @common.view_event_result(
          changed=true,
          captured=true,
          text_control=Some({ ..ctx.text_control, caret, selection, }),
          dirty=ViewPaintDirty,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    }
  } else if event.phase == Up &&
    ctx.text_control.text_selection_anchor is Some(_) {
    @common.view_event_result(
      changed=true,
      captured=true,
      text_control=Some({
        ..ctx.text_control,
        text_selection_anchor: None,
        text_selection_origin: None,
      }),
      dirty=ViewPaintDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}
