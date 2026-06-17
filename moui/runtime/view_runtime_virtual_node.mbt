///|
fn[Msg] erase_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> VirtualNode {
  erase_virtual_node_for_runtime(view.ops(), emit)
}

///|
fn[Msg] erase_virtual_node_for_runtime(
  virtual_node : @core.VirtualNode[Msg],
  emit : (Msg) -> Unit,
) -> VirtualNode {
  {
    identity: virtual_node.identity(),
    revision: virtual_node.revision(),
    children: () => {
      virtual_node.children().map(child => erase_view_for_runtime(child, emit))
    },
    build_child: match virtual_node.build_child() {
      Some(build) => Some(ctx => erase_view_for_runtime(build(ctx), emit))
      None => None
    },
    child_constraints: constraints => virtual_node.child_constraints(constraints),
    layout: context => virtual_node.layout(context),
    paint: context => virtual_node.paint(context),
    event: context => {
      let result = virtual_node.event(context)
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
    text_input_state: context => virtual_node.text_input_state(context),
    text_command: (context, intent, paste_text) => {
      let result = virtual_node.text_command_result(context, intent, paste_text~)
      for message in result.messages {
        emit(message)
      }
      { result: result.result, text_control: result.text_control, messages: [] }
    },
    semantics: () => virtual_node.semantics(),
    focusable: () => virtual_node.focusable(),
    state: virtual_node_state_context_default(),
  }
}
