///|
fn ElementNode::dispatch_web_view_event(
  self : ElementNode,
  id : String,
  event : PlatformViewEvent,
  environment? : Environment = Environment::default(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> Bool {
  let data = self.widget
  let result = (data.event)({
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_frames: [],
    event: AppEvent::PlatformView(id, event),
    focused: false,
    state: data.state,
    text_control: self.control.text_context(),
    text_system,
    environment,
  })
  match result.state {
    Some(next_state) => self.widget = { ..data, state: next_state }
    None => ()
  }
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  if result.activated || result.changed || result.captured {
    true
  } else {
    self.children.any(child => {
      child.dispatch_web_view_event(id, event, environment~, text_system~)
    })
  }
}
