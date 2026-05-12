///|
pub fn button(
  text : String,
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.ViewNode {
  button_base(text, None, width~, height~)
}

///|
pub fn button_on_click(
  text : String,
  on_click : @core.ClickHandler,
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.ViewNode {
  button_base(text, Some(on_click), width~, height~)
}

///|
fn button_base(
  text : String,
  on_click : @core.ClickHandler?,
  width~ : Double,
  height~ : Double,
) -> @core.ViewNode {
  @core.ViewNode::Button({
    text,
    size: @core.Size::new(width~, height~),
    state: @core.ButtonState::Normal,
    on_click,
  })
}

///|
pub fn button_with_state(
  text : String,
  state : @core.ButtonState,
) -> @core.ViewNode {
  @core.ViewNode::Button({
    text,
    size: @core.Size::new(width=180.0, height=44.0),
    state,
    on_click: None,
  })
}

///|
pub fn handle_button_pointer(
  node : @core.ViewNode,
  event : @core.PointerEvent,
  frame : @core.Rect,
) -> @core.ViewNode {
  node.handle_pointer(event, frame).node
}
