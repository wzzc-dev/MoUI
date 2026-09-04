///|
fn[Msg] view_caret_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  direction : TextCaretDirection,
  extend_selection : Bool,
) -> @core.ViewEventResult[Msg] {
  let caret_move = move_text_caret(
    text,
    ctx.text_control.caret,
    ctx.text_control.selection,
    direction,
    extend_selection~,
  )
  let next_control = {
    ..ctx.text_control,
    caret: caret_move.caret,
    selection: caret_move.selection,
    composition: None,
    composition_cursor: None,
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    next_control.selection != ctx.text_control.selection ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  @common.view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
  )
}

///|
fn[Msg] text_semantics_set_text(
  ctx : @core.ViewSemanticsActionContext,
  value : String,
  on_input : ((String) -> Msg)?,
  next : String,
) -> @core.ViewSemanticsActionResult[Msg] {
  let previous = value
  if previous == next {
    return @core.ViewSemanticsActionResult::accepted(
      dirty=@core.ViewDirtyHint::ViewClean,
    )
  }
  let undo_stack : Array[@core.TextHistoryEntryContext] = []
  undo_stack.append(ctx.text_control.undo_stack)
  let (start, before, after) = @core.text_history_delta(previous, next)
  undo_stack.push({
    start,
    before,
    after,
    caret: ctx.text_control.caret,
    selection: ctx.text_control.selection,
  })
  let next_control : @core.TextControlStateContext = {
    caret: text_length(next),
    selection: None,
    composition: None,
    composition_cursor: None,
    text_selection_anchor: None,
    undo_stack,
    redo_stack: [],
  }
  @core.ViewSemanticsActionResult::accepted(
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewBuildDirty,
    messages=text_input_messages(on_input, next),
  )
}
