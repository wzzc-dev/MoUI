///|
fn ElementNode::dispatch_web_view_event(
  self : ElementNode,
  id : String,
  event : PlatformViewEvent,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> Bool {
  let data = self.erased_view_node
  let result = (data.event)({
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_frames: [],
    event: AppEvent::PlatformView(id, event),
    focused: false,
    state: data.state,
    text_control: self.control.text_context(),
    text_system,
    environment,
    style,
    now_ms: 0.0,
  })
  match result.state {
    Some(next_state) => self.erased_view_node = { ..data, state: next_state }
    None => ()
  }
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  if result.activated || result.changed || result.captured {
    true
  } else {
    let child_environment = (self.erased_view_node.child_environment)(
      environment,
    )
    let child_style = (self.erased_view_node.child_style)(style)
    self.children.any(child => {
      child.dispatch_web_view_event(
        id,
        event,
        environment=child_environment,
        style=child_style,
        text_system~,
      )
    })
  }
}
