///|
fn[Msg] erase_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> Widget {
  erase_widget_for_runtime(view.ops(), emit)
}

///|
fn[Msg] erase_widget_for_runtime(
  widget : @core.Widget[Msg],
  emit : (Msg) -> Unit,
) -> Widget {
  {
    identity: widget.identity(),
    revision: widget.revision(),
    children: () => {
      widget.children().map(child => erase_view_for_runtime(child, emit))
    },
    build_child: match widget.build_child() {
      Some(build) => Some(ctx => erase_view_for_runtime(build(ctx), emit))
      None => None
    },
    child_constraints: constraints => widget.child_constraints(constraints),
    layout: context => widget.layout(context),
    paint: context => widget.paint(context),
    event: context => {
      let result = widget.event(context)
      for message in result.messages {
        emit(message)
      }
      {
        changed: result.changed,
        activated: result.activated,
        focused: result.focused,
        captured: result.captured,
        state: result.state,
        text_control: result.text_control,
        dirty: result.dirty,
        messages: [],
      }
    },
    text_input_state: context => widget.text_input_state(context),
    text_command: (context, intent, paste_text) => {
      let result = widget.text_command_result(context, intent, paste_text~)
      for message in result.messages {
        emit(message)
      }
      { result: result.result, text_control: result.text_control, messages: [] }
    },
    semantics: () => widget.semantics(),
    focusable: () => widget.focusable(),
    state: widget_state_context_default(),
  }
}
