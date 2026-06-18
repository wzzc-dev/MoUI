///|
fn ElementNode::dispatch_text_input(
  self : ElementNode,
  target : ElementId,
  event : TextInputEvent,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  if self.id == target {
    self.dispatch_view_event(
      self.erased_view_node,
      AppEvent::TextInput(event),
      RenderNode::empty(),
      text_system,
      environment~,
    )
  } else {
    let mut changed = false
    let mut activated = false
    for child in self.children {
      let result = child.dispatch_text_input(
        target,
        event,
        environment~,
        text_system~,
      )
      changed = changed || result.changed
      activated = activated || result.activated
    }
    if changed {
      self.dirty.mark_paint()
    }
    { changed, activated, focused: None }
  }
}
