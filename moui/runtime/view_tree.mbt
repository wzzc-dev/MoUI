///|
priv struct RuntimeWidget {
  identity : @core.WidgetIdentity
  revision : String
  children : () -> Array[RuntimeWidget]
  build_child : ((@core.ComponentContext) -> RuntimeWidget)?
  child_constraints : (Constraints) -> Constraints
  layout : (@core.WidgetLayoutContext) -> @core.WidgetLayoutResult
  paint : (@core.WidgetPaintContext) -> @core.WidgetPaintPlan
  event : (@core.WidgetEventContext) -> @core.WidgetEventResult[Unit]
  text_input_state : (@core.WidgetPaintContext) -> TextInputState?
  text_command : (@core.WidgetEventContext, CommandIntent, String?) -> @core.WidgetTextCommandResult[
    Unit,
  ]
  semantics : () -> @core.WidgetSemanticsInfo
  focusable : () -> Bool
  state : @core.WidgetStateContext
}

///|
fn widget_state_context_default() -> @core.WidgetStateContext {
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
