///|
fn ElementNode::dispatch_web_view_event(
  self : ElementNode,
  id : String,
  event : @core.PlatformViewEvent,
  environment? : @core.Environment = @core.Environment::neutral(),
  style? : @core.ViewStyle = @core.ViewStyle::empty(),
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> ElementEventResult {
  let result = self.dispatch_view_event(
    self.view_node,
    @core.AppEvent::PlatformView(id, event),
    RenderNode::empty(),
    text_system,
    environment~,
    style~,
  )
  if result.activated || result.changed || result.captured {
    result
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    for child in self.children {
      let child_result = child.dispatch_web_view_event(
        id,
        event,
        environment=child_environment,
        style=child_style,
        text_system~,
      )
      if child_result.activated || child_result.changed || child_result.captured {
        return child_result
      }
    }
    {
      changed: false,
      activated: false,
      captured: false,
      capture_target: None,
      focused: None,
      deliveries: [],
    }
  }
}
