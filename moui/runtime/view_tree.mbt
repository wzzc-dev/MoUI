///|
priv struct ErasedViewNode {
  identity : @core.ViewIdentity
  revision : String
  children : () -> Array[ErasedViewNode]
  build_child : ((@core.ComponentContext) -> ErasedViewNode)?
  child_constraints : (Constraints) -> Constraints
  child_environment : (Environment) -> Environment
  child_style : (ViewStyle) -> ViewStyle
  layout : (@core.ViewLayoutContext) -> @core.ViewLayoutResult
  paint : (@core.ViewPaintContext) -> @core.ViewPaintPlan
  event : (@core.ViewEventContext) -> @core.ViewEventResult[Unit]
  text_input_state : (@core.ViewPaintContext) -> TextInputState?
  text_command : (@core.ViewEventContext, CommandIntent, String?) -> @core.ViewTextCommandResult[
    Unit,
  ]
  semantics : () -> @core.ViewSemanticsInfo
  focusable : () -> Bool
  flex_weight : () -> Double
  state : @core.ViewStateContext
}

///|
fn erased_view_node_state_context_default() -> @core.ViewStateContext {
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
