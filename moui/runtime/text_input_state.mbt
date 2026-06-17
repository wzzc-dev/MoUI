///|
fn ElementNode::focused_text_input(
  self : ElementNode,
  target : ElementId,
  render : RenderNode,
  text_system? : TextSystem = TextSystem::fallback(),
  environment? : Environment = Environment::neutral(),
) -> TextInputState? {
  if self.id == target {
    widget_text_input_state(self, self.widget, render, text_system, environment)
  } else {
    for index, child in self.children {
      if index < render.children.length() {
        match
          child.focused_text_input(
            target,
            render.children[index],
            text_system~,
            environment~,
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
fn widget_text_input_state(
  element : ElementNode,
  data : Widget,
  render : RenderNode,
  text_system : TextSystem,
  environment : Environment,
) -> TextInputState? {
  (data.text_input_state)({
    frame: render.frame,
    child_frames: render.children.map(child => child.frame),
    focused: true,
    state: { ..data.state, focused: true },
    text_control: element.control.text_context(),
    environment,
    text_system,
  })
}
