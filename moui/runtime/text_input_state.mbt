///|
fn ElementNode::focused_text_input(
  self : ElementNode,
  target : ElementId,
  render : RenderNode,
  text_system? : TextSystem = TextSystem::fallback(),
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
) -> TextInputState? {
  if self.id == target {
    view_text_input_state(
      self,
      self.view_node,
      render,
      text_system,
      environment,
      style,
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    for index, child in self.children {
      if index < render.children.length() {
        match
          child.focused_text_input(
            target,
            render.children[index],
            text_system~,
            environment=child_environment,
            style=child_style,
          ) {
          Some(state) => return Some(state)
          None => ()
        }
      }
    }
    None
  }
}

///|
fn view_text_input_state(
  element : ElementNode,
  data : &RuntimeViewNode,
  render : RenderNode,
  text_system : TextSystem,
  environment : Environment,
  style : ViewStyle,
) -> TextInputState? {
  data.text_input_state({
    frame: render.frame,
    child_frames: render.children.map(child => child.frame),
    focused: true,
    state: element.control.view_context(true),
    text_control: element.control.text_context(),
    environment,
    style,
    text_system,
    now_ms: 0.0,
  })
}
