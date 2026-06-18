///|
fn[Msg] erase_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> ErasedViewNode {
  {
    identity: view.identity(),
    revision: view.revision(),
    children: () => {
      view.children().map(child => erase_view_for_runtime(child, emit))
    },
    build_child: match view.build_child() {
      Some(build) => Some(ctx => erase_view_for_runtime(build(ctx), emit))
      None => None
    },
    child_constraints: constraints => view.child_constraints(constraints),
    layout: context => view.layout(context),
    paint: context => view.paint(context),
    event: context => {
      let result = view.event(context)
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
    text_input_state: context => view.text_input_state(context),
    text_command: (context, intent, paste_text) => {
      let result = view.text_command_result(context, intent, paste_text~)
      for message in result.messages {
        emit(message)
      }
      { result: result.result, text_control: result.text_control, messages: [] }
    },
    semantics: () => view.semantics(),
    focusable: () => view.accepts_focus(),
    state: erased_view_node_state_context_default(),
  }
}
