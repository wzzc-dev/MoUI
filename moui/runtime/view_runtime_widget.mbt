///|
fn[Msg] erase_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> RuntimeWidget {
  erase_widget_ops_for_runtime(view.ops(), emit)
}

///|
fn[Msg] erase_widget_ops_for_runtime(
  ops : @core.WidgetOps[Msg],
  emit : (Msg) -> Unit,
) -> RuntimeWidget {
  {
    identity: ops.identity(),
    revision: ops.revision(),
    children: () => {
      ops.children().map(child => erase_view_for_runtime(child, emit))
    },
    build_child: match ops.build_child() {
      Some(build) => Some(ctx => erase_view_for_runtime(build(ctx), emit))
      None => None
    },
    child_constraints: constraints => ops.child_constraints(constraints),
    layout: context => ops.layout(context),
    paint: context => ops.paint(context),
    event: context => {
      let result = ops.event(context)
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
    text_input_state: context => ops.text_input_state(context),
    text_command: (context, intent, paste_text) => {
      let result = ops.text_command_result(context, intent, paste_text~)
      for message in result.messages {
        emit(message)
      }
      { result: result.result, text_control: result.text_control, messages: [] }
    },
    semantics: () => ops.semantics(),
    focusable: () => ops.focusable(),
    state: widget_state_context_default(),
  }
}
