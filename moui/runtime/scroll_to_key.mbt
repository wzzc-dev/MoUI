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
  let nearest_scroll = if self.view_node.semantics().role ==
    Some(@core.SemanticsRole::ScrollView) {
    Some((self.id, layout.frame))
  } else {
    nearest_scroll
  }
  if self.key == Some(Key::new(key)) {
    return match nearest_scroll {
      Some((scroll_id, viewport)) =>
        Some({ scroll_id, viewport, target: layout.frame })
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
fn ElementNode::dispatch_event_to_target(
  self : ElementNode,
  target : ElementId,
  event : AppEvent,
  layout : PlacedNode,
  environment~ : Environment,
  style? : ViewStyle = ViewStyle::empty(),
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
        match
          child.dispatch_event_to_target(
            target,
            event,
            layout.children[index],
            environment=child_environment,
            style=child_style,
            text_system~,
          ) {
          Some(result) => return Some(result)
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
    self.animfocus.active_pointer_capture = match result.capture_target {
      Some(target) => Some(target)
      None => result.focused
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
          let dx = scroll_axis_delta(
            found.target.origin.x,
            found.target.origin.x + found.target.size.width,
            found.viewport.origin.x,
            found.viewport.origin.x + found.viewport.size.width,
            request.alignment,
          )
          let dy = scroll_axis_delta(
            found.target.origin.y,
            found.target.origin.y + found.target.size.height,
            found.viewport.origin.y,
            found.viewport.origin.y + found.viewport.size.height,
            request.alignment,
          )
          self.pending_scroll_request = None
          if dx != 0.0 || dy != 0.0 {
            match
              self.element_tree.root.dispatch_event_to_target(
                found.scroll_id,
                Pointer(
                  PointerEvent::new(
                    position=Point::new(
                      x=found.viewport.origin.x +
                        found.viewport.size.width / 2.0,
                      y=found.viewport.origin.y +
                        found.viewport.size.height / 2.0,
                    ),
                    phase=PointerPhase::Move,
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
          true
        }
        None => false
      }
    None => false
  }
}

///|
fn RuntimeState::scroll_to_key(
  self : RuntimeState,
  key : String,
  alignment : ScrollAlignment,
) -> Bool {
  self.pending_scroll_request = Some({ key, alignment })
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
  alignment? : @core.ScrollAlignment = @core.ScrollAlignment::Nearest,
) -> Bool {
  self.state.scroll_to_key(key, alignment)
}
