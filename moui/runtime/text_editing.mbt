///|
fn ElementNode::dispatch_text_command(
  self : ElementNode,
  target : ElementId,
  intent : CommandIntent,
  paste_text? : String? = None,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> RuntimeTextCommandOutcome {
  if self.id == target {
    self.dispatch_view_text_command(
      self.view_node,
      intent,
      paste_text~,
      environment~,
      text_system~,
    )
  } else {
    for child in self.children {
      let result = child.dispatch_text_command(
        target,
        intent,
        paste_text~,
        environment~,
        text_system~,
      )
      if result.result.handled {
        if result.result.changed {
          self.dirty.mark_paint()
        }
        return result
      }
    }
    { result: TextCommandResult::ignored(), text_control: None, deliveries: [] }
  }
}

///|
fn ElementNode::dispatch_view_text_command(
  self : ElementNode,
  data : &RuntimeViewNode,
  intent : CommandIntent,
  paste_text~ : String?,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> RuntimeTextCommandOutcome {
  let result = data.text_command(
    {
      frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
      child_frames: [],
      event: AppEvent::Keyboard(KeyboardEvent::new(key="", pressed=false)),
      focused: true,
      state: self.control.view_context(true),
      text_control: self.control.text_context(),
      text_system,
      environment,
      style,
      now_ms: 0.0,
    },
    intent,
    paste_text,
  )
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  result
}
