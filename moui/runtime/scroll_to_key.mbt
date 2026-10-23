///|
priv struct ScrollTarget {
  scroll_id : ElementId
  viewport : Rect
  target : Rect
}

///|
fn ElementNode::find_scroll_target(
  self : ElementNode,
  key : String,
  layout : PlacedNode,
  nearest_scroll : (ElementId, Rect)?,
) -> ScrollTarget? {
  let nearest_scroll = if self.view_node.semantics().role == Some(ScrollView) {
    Some((self.id, layout.frame))
  } else {
    nearest_scroll
  }
  if self.key == Some(Key::new(key)) {
    return match nearest_scroll {
      Some((scroll_id, viewport)) =>
        Some({ scroll_id, viewport, target: layout.frame, })
      None => None
    }
  }
  for index, child in self.children {
    if index < layout.children.length() {
      match
        child.find_scroll_target(key, layout.children[index], nearest_scroll) {
        Some(found) => return Some(found)
        None => ()
      }
    }
  }
  None
}

///|
/// Nearest scrolling ancestor of the element that asked to be revealed,
/// with its own rect as the target. Like `find_scroll_target` this pairs
/// the element tree with the placed tree, but the trigger is an element
/// id rather than an app key, and the request is consumed here so a
/// reveal scrolls once per caret or selection change instead of
/// pinning the viewport every frame.
fn ElementNode::find_text_reveal(
  self : ElementNode,
  layout : PlacedNode,
  nearest_scroll : (ElementId, Rect)?,
) -> ScrollTarget? {
  let nearest_scroll = if self.view_node.semantics().role == Some(ScrollView) {
    Some((self.id, layout.frame))
  } else {
    nearest_scroll
  }
  match self.control.take_reveal() {
    None => ()
    Some(target) =>
      return match nearest_scroll {
        Some((scroll_id, viewport)) => Some({ scroll_id, viewport, target, })
        None => None
      }
  }
  for index, child in self.children {
    if index < layout.children.length() {
      match child.find_text_reveal(layout.children[index], nearest_scroll) {
        Some(found) => return Some(found)
        None => ()
      }
    }
  }
  None
}

///|
fn PlacedNode::event_render_node(self : PlacedNode) -> RenderNode {
  {
    ..RenderNode::empty(),
    element_id: self.element_id,
    frame: self.frame,
    paint_bounds: self.frame,
    children: self.children.map(child => child.event_render_node()),
  }
}

///|
/// The placed subtree of one element, so an event that arrives without a
/// hit-test (a key press, an IME commit) is handed the same geometry the
/// pointer path resolves. `None` means the element has no placed frame yet,
/// and the caller keeps a frame-less dispatch.
fn PlacedNode::event_render_node_for(
  self : PlacedNode,
  id : ElementId,
) -> RenderNode? {
  if self.element_id == id {
    Some(self.event_render_node())
  } else {
    for child in self.children {
      match child.event_render_node_for(id) {
        Some(node) => return Some(node)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementNode::dispatch_event_to_target(
  self : ElementNode,
  target : ElementId,
  event : AppEvent,
  layout : PlacedNode,
  environment~ : Environment,
  style~ : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
) -> ElementEventResult? {
  if self.id == target {
    Some(
      self.dispatch_view_event(
        self.view_node,
        event,
        layout.event_render_node(),
        text_system,
        environment~,
        style~,
      ),
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    for index, child in self.children {
      if index < layout.children.length() {
        let child_result = child.dispatch_event_to_target(
          target,
          event,
          layout.children[index],
          environment=child_environment,
          style=child_style,
          text_system~,
        )
        match child_result {
          Some(result) => {
            // Placement caches are keyed by frame, so an ancestor of a node
            // whose state just re-flowed still holds the stale subtree. The
            // pointer path drops them level by level as it unwinds; a
            // targeted dispatch must do the same or a scrolled child stays
            // parked where the previous frame placed it.
            if result.changed {
              if child.has_dirty_layout() {
                self.dirty.mark_layout_descendant()
                self.layout_cache.clear()
                self.render_cache.clear()
              } else {
                self.mark_pointer_descendant_paint_dirty()
              }
            }
            return Some(result)
          }
          None => ()
        }
      }
    }
    None
  }
}

///|
fn RuntimeState::apply_targeted_event_result(
  self : RuntimeState,
  result : ElementEventResult,
) -> Unit {
  match result.focused {
    Some(target) => ignore(self.commit_focus(Some(target)))
    None => ()
  }
  if result.captured {
    match result.capture_target {
      Some(target) =>
        self.animfocus.pointer_captures[primary_pointer_id] = target
      None =>
        match result.focused {
          Some(target) =>
            self.animfocus.pointer_captures[primary_pointer_id] = target
          None => ()
        }
    }
  }
  self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
  self.dirty.needs_rebuild = self.dirty.needs_rebuild || result.activated
  self.dirty.needs_paint = self.dirty.needs_paint || result.changed
  if result.changed || result.activated {
    self.mark_current_dirty_elements()
    self.mark_semantics_dirty(self.element_tree.id())
  }
  if result.activated {
    self.request_activation_rebuild()
  }
  self.deliver_messages(result.deliveries)
}

///|
fn scroll_axis_delta(
  start : Double,
  end : Double,
  viewport_start : Double,
  viewport_end : Double,
  alignment : ScrollAlignment,
) -> Double {
  match alignment {
    Start => start - viewport_start
    Center => (start + end) / 2.0 - (viewport_start + viewport_end) / 2.0
    End => end - viewport_end
    Nearest =>
      if start < viewport_start {
        start - viewport_start
      } else if end > viewport_end {
        end - viewport_end
      } else {
        0.0
      }
  }
}

///|
/// Scroll one resolved target into its viewport by dispatching a wheel
/// delta to the owning scroll view. Both a key-triggered request and a
/// text reveal end here, so the two can never disagree on how a delta
/// reaches the control.
fn RuntimeState::scroll_target_into_view(
  self : RuntimeState,
  found : ScrollTarget,
  alignment : ScrollAlignment,
) -> Unit {
  let dx = scroll_axis_delta(
    found.target.origin.x,
    found.target.origin.x + found.target.size.width,
    found.viewport.origin.x,
    found.viewport.origin.x + found.viewport.size.width,
    alignment,
  )
  let dy = scroll_axis_delta(
    found.target.origin.y,
    found.target.origin.y + found.target.size.height,
    found.viewport.origin.y,
    found.viewport.origin.y + found.viewport.size.height,
    alignment,
  )
  if dx != 0.0 || dy != 0.0 {
    match
      self.element_tree.root.dispatch_event_to_target(
        found.scroll_id,
        Pointer(
          PointerEvent::new(
            position=Point::new(
              x=found.viewport.origin.x + found.viewport.size.width / 2.0,
              y=found.viewport.origin.y + found.viewport.size.height / 2.0,
            ),
            phase=Move,
            wheel_delta=Point::new(x=-dx, y=-dy),
          ),
        ),
        self.layout_tree.root,
        environment=self.environment,
        text_system=self.text_system,
      ) {
      Some(result) => self.apply_targeted_event_result(result)
      None => ()
    }
  }
}

///|
fn RuntimeState::try_pending_scroll_from_current_layout(
  self : RuntimeState,
) -> Bool {
  match self.pending_scroll_request {
    Some(request) =>
      match
        self.element_tree.root.find_scroll_target(
          request.key,
          self.layout_tree.root,
          None,
        ) {
        Some(found) => {
          self.pending_scroll_request = None
          self.scroll_target_into_view(found, request.alignment)
          true
        }
        None => false
      }
    None => false
  }
}

///|
/// Fold any caret/selection reveal request into the current placed tree.
/// Runs on the same post-layout point as the key request, so the rect a
/// text view reported during an event is resolved against fresh frames.
fn RuntimeState::try_pending_text_reveal_from_current_layout(
  self : RuntimeState,
) -> Unit {
  let layout = self.layout_tree_for_input()
  match self.element_tree.root.find_text_reveal(layout, None) {
    Some(found) => self.scroll_target_into_view(found, Nearest)
    None => ()
  }
}

///|
fn RuntimeState::scroll_to_key(
  self : RuntimeState,
  key : String,
  alignment : ScrollAlignment,
) -> Bool {
  self.pending_scroll_request = Some({ key, alignment, })
  self.ensure_layout_tree()
  if self.pending_scroll_request is None {
    true
  } else {
    self.try_pending_scroll_from_current_layout()
  }
}

///|
pub fn AppRuntime::scroll_to_key(
  self : AppRuntime,
  key : String,
  alignment~ : @core.ScrollAlignment = Nearest,
) -> Bool {
  self.state.scroll_to_key(key, alignment)
}
