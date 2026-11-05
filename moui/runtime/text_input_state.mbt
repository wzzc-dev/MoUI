///|
fn ElementNode::focused_text_input(
  self : ElementNode,
  target : ElementId,
  render : RenderNode,
  text_system~ : TextSystem = TextSystem::fallback(),
  environment~ : Environment = Environment::neutral(),
  style~ : ViewStyle = ViewStyle::empty(),
  node_to_screen~ : Transform2D = Transform2D::identity(),
) -> TextInputState? {
  if self.id == target {
    view_text_input_state(
      self,
      self.view_node,
      render.screen_frame(node_to_screen),
      render.screen_child_frames(node_to_screen),
      text_system,
      environment,
      style,
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    for index, child in self.children {
      if index < render.children.length() {
        let child_to_screen = render.child_to_screen(
          node_to_screen,
          render.children[index],
        )
        match
          child.focused_text_input(
            target,
            render.children[index],
            text_system~,
            environment=child_environment,
            style=child_style,
            node_to_screen=child_to_screen,
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
  frame : Rect,
  child_frames : Array[Rect],
  text_system : TextSystem,
  environment : Environment,
  style : ViewStyle,
) -> TextInputState? {
  data.text_input_state({
    frame,
    child_frames,
    focused: true,
    state: element.control.view_context(true),
    text_control: element.control.text_context(),
    environment,
    style,
    text_system,
    now_ms: 0.0,
  })
}
