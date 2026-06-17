///|
priv struct VirtualNode {
  identity : @core.VirtualNodeIdentity
  revision : String
  children : () -> Array[VirtualNode]
  build_child : ((@core.ComponentContext) -> VirtualNode)?
  child_constraints : (Constraints) -> Constraints
  layout : (@core.VirtualNodeLayoutContext) -> @core.VirtualNodeLayoutResult
  paint : (@core.VirtualNodePaintContext) -> @core.VirtualNodePaintPlan
  event : (@core.VirtualNodeEventContext) -> @core.VirtualNodeEventResult[Unit]
  text_input_state : (@core.VirtualNodePaintContext) -> TextInputState?
  text_command : (@core.VirtualNodeEventContext, CommandIntent, String?) -> @core.VirtualNodeTextCommandResult[
    Unit,
  ]
  semantics : () -> @core.VirtualNodeSemanticsInfo
  focusable : () -> Bool
  state : @core.VirtualNodeStateContext
}

///|
fn virtual_node_state_context_default() -> @core.VirtualNodeStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    scratch: "",
  }
}
