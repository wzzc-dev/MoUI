///|
fn ElementNode::dispatch_drag_drop(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
) -> ElementEventResult {
  let child_result = self.dispatch_drag_drop_to_children(event, render)
  if child_result.activated {
    child_result
  } else {
    let result = self.dispatch_view_event(
      self.view_node,
      AppEvent::DragDrop(event),
      render,
      TextSystem::fallback(),
      environment=Environment::neutral(),
    )
    let deliveries = child_result.deliveries.copy()
    deliveries.append(result.deliveries)
    {
      changed: child_result.changed || result.changed,
      activated: result.activated,
      captured: child_result.captured || result.captured,
      capture_target: match child_result.capture_target {
        Some(target) => Some(target)
        None => result.capture_target
      },
      focused: match result.focused {
        Some(value) => Some(value)
        None => child_result.focused
      },
      deliveries,
    }
  }
}

///|
fn ElementNode::dispatch_drag_drop_to_children(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
) -> ElementEventResult {
  match event.position {
    Some(position) => {
      let mut changed = false
      let mut activated = false
      let deliveries : Array[() -> Unit] = []
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(position) {
          let result = self.children[index].dispatch_drag_drop(
            event,
            render.children[index],
          )
          changed = changed || result.changed
          activated = activated || result.activated
          deliveries.append(result.deliveries)
          if result.changed || result.activated {
            break
          }
        }
        index = index - 1
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
      }
    }
    None =>
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
