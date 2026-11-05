///|
fn ElementNode::dispatch_text_input(
  self : ElementNode,
  target : ElementId,
  event : TextInputEvent,
  layout~ : PlacedNode,
  environment~ : Environment = Environment::neutral(),
  style~ : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  if self.id == target {
    let (frame, child_frames) = layout
      .event_geometry_for(target, Transform2D::identity())
      .unwrap_or_else(() => (Rect::new(x=0.0, y=0.0, width=0.0, height=0.0), []))
    self.dispatch_view_event_with_geometry(
      self.view_node,
      TextInput(event),
      frame,
      child_frames,
      text_system,
      environment~,
      style~,
      focused=true,
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    let mut changed = false
    let mut activated = false
    let deliveries : Array[() -> Unit] = []
    for child in self.children {
      let result = child.dispatch_text_input(
        target,
        event,
        layout~,
        environment=child_environment,
        style=child_style,
        text_system~,
      )
      changed = changed || result.changed
      activated = activated || result.activated
      deliveries.append(result.deliveries)
    }
    if changed {
      self.dirty.mark_paint_descendant()
      self.render_cache.invalidate_composition()
    }
    {
      changed,
      activated,
      captured: false,
      capture_target: None,
      focused: None,
      deliveries,
      gesture: PointerGestureTrace::empty(),
    }
  }
}
