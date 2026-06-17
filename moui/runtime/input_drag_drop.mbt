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
    let result = self.dispatch_widget_event(
      self.widget,
      AppEvent::DragDrop(event),
      render,
      TextSystem::fallback(),
      environment=Environment::neutral(),
    )
    {
      changed: child_result.changed || result.changed,
      activated: result.activated,
      focused: match result.focused {
        Some(value) => Some(value)
        None => child_result.focused
      },
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
          if result.changed || result.activated {
            break
          }
        }
        index = index - 1
      }
      if changed {
        self.dirty.mark_paint()
      }
      { changed, activated, focused: None }
    }
    None => { changed: false, activated: false, focused: None }
  }
}
