///|
fn ElementNode::dispatch_drag_drop(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
  node_to_screen~ : Transform2D = Transform2D::identity(),
  clip~ : Rect? = None,
) -> ElementEventResult {
  let child_result = self.dispatch_drag_drop_to_children(
    event, render, node_to_screen, clip,
  )
  if child_result.activated {
    child_result
  } else {
    let result = self.dispatch_view_event(
      self.view_node,
      DragDrop(event),
      render,
      TextSystem::fallback(),
      environment=Environment::neutral(),
      node_to_screen~,
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
      gesture: child_result.gesture.merge(result.gesture),
    }
  }
}

///|
fn ElementNode::dispatch_drag_drop_to_children(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
  node_to_screen : Transform2D,
  clip : Rect?,
) -> ElementEventResult {
  match event.position {
    Some(position) => {
      let own_screen_frame = render.screen_frame(node_to_screen)
      let child_clip : Rect? = if render.clips_children {
        Some(runtime_clip_intersection(clip, own_screen_frame))
      } else {
        clip
      }
      let mut changed = false
      let mut activated = false
      let deliveries : Array[() -> Unit] = []
      let mut index = self.children.length() - 1
      while index >= 0 {
        let mut handled = false
        if index < render.children.length() &&
          ({
            let child_to_screen = render.child_to_screen(
              node_to_screen,
              render.children[index],
            )
            let child_hit_clip = if render.children[index].is_overlay_child {
              None
            } else {
              child_clip
            }
            let hit = runtime_point_hits_frame(
              position,
              render.children[index].screen_frame(child_to_screen),
              child_hit_clip,
            )
            if hit {
              let result = self.children[index].dispatch_drag_drop(
                event,
                render.children[index],
                node_to_screen=child_to_screen,
                clip=child_hit_clip,
              )
              changed = changed || result.changed
              activated = activated || result.activated
              deliveries.append(result.deliveries)
              handled = result.changed || result.activated
            }
            hit
          }) {
          if handled {
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
        gesture: PointerGestureTrace::empty(),
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
        gesture: PointerGestureTrace::empty(),
      }
  }
}
