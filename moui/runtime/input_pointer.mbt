///|
fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
  capture_lookup? : Bool = true,
  now_ms? : Double = 0.0,
) -> ElementEventResult {
  let child_result = self.dispatch_pointer_to_children(
    event,
    render,
    environment~,
    style~,
    text_system~,
    capture_lookup~,
    now_ms~,
  )
  if child_result.activated {
    child_result
  } else {
    let own = self.dispatch_view_event(
      self.erased_view_node,
      AppEvent::Pointer(event),
      render,
      text_system,
      environment~,
      style~,
      now_ms~,
    )
    {
      changed: child_result.changed || own.changed,
      activated: own.activated,
      focused: match own.focused {
        Some(value) => Some(value)
        None => child_result.focused
      },
    }
  }
}

///|
fn ElementNode::dispatch_view_event(
  self : ElementNode,
  data : ErasedViewNode,
  event : AppEvent,
  render : RenderNode,
  text_system : TextSystem,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  now_ms? : Double = 0.0,
  focused? : Bool = false,
) -> ElementEventResult {
  let result = (data.event)({
    frame: render.frame,
    child_frames: render.children.map(child => child.frame),
    event,
    focused,
    state: { ..data.state, focused, },
    text_control: self.control.text_context(),
    text_system,
    environment,
    style,
    now_ms,
  })
  match result.state {
    Some(next_state) => self.erased_view_node = { ..data, state: next_state }
    None => ()
  }
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  self.apply_view_dirty_hint(result.dirty)
  {
    changed: result.changed || result.captured,
    activated: result.activated,
    focused: if result.focused {
      Some(self.id)
    } else {
      None
    },
  }
}

///|
fn ElementNode::apply_view_dirty_hint(
  self : ElementNode,
  dirty : ViewDirtyHint,
) -> Unit {
  match dirty {
    ViewClean => ()
    ViewPaintDirty => self.mark_pointer_paint_dirty()
    ViewLayoutDirty => {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
    ViewBuildDirty => {
      self.dirty.mark_build()
      self.clear_cached_layout_and_paint()
    }
  }
}

///|
fn ElementNode::mark_pointer_paint_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_paint()
  self.render_cache.clear()
}

///|
fn ElementNode::dispatch_pointer_to_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  environment~ : Environment,
  style~ : ViewStyle,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
  now_ms~ : Double,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let mut focused : ElementId? = None
  let mut layout_changed = false
  let child_environment = (self.erased_view_node.child_environment)(environment)
  let child_style = (self.erased_view_node.child_style)(style)
  // On a `Move`, the pointer can only be over one element, so only one child
  // receives the event. Any *other* child that still holds hover (from a prior
  // move) has been left behind and must get a synthetic `Exit` to clear it —
  // host backends never emit a leave event, and a move outside a child is not
  // delivered to it by hit-testing. Doing this in the same traversal that
  // delivers the `Move` keeps the `Exit` target identical to whatever the
  // `Move` previously hovered, regardless of repaint boundaries, overlays, or
  // element-id churn, which a separate top-down hover resolver got wrong. An
  // `Exit` itself cascades the same way, so a hovered leaf deep inside an
  // overlay still gets cleared when the pointer leaves the overlay's frame.
  let is_move = event.phase == PointerPhase::Move ||
    event.phase == PointerPhase::Exit
  let mut delivered_main_event = false
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      let has_capture = capture_lookup &&
        child.has_active_pointer_capture(event.phase)
      let hit = has_capture ||
        child_render.hit_bounds().contains(event.position)
      if hit && !delivered_main_event {
        let result = child.dispatch_pointer(
          event,
          child_render,
          environment=child_environment,
          style=child_style,
          text_system~,
          capture_lookup~,
          now_ms~,
        )
        changed = changed || result.changed
        activated = activated || result.activated
        layout_changed = layout_changed ||
          (result.changed && child.has_dirty_layout())
        match result.focused {
          Some(_) => focused = result.focused
          None => ()
        }
        // Only consider the main event delivered when the child actually
        // handled it — matching the original `break` condition. A hit child
        // that did not handle the event (e.g. a non-interactive container)
        // lets the traversal continue so a sibling beneath it can receive
        // the event. For Move/Exit, the loop keeps going regardless so that
        // previously hovered siblings get a synthetic Exit to clear hover.
        if has_capture ||
          result.changed ||
          result.activated ||
          result.focused is Some(_) {
          delivered_main_event = true
        }
      } else if is_move && child.has_hovered_descendant() {
        // Pointer moved off this child (or a descendant it previously
        // hovered) — send an `Exit` so its hover clears. The exit carries the
        // current position, which is by definition outside the child, so views
        // that re-check `inside` see `false`.
        let exit_event = PointerEvent::new(
          position=event.position,
          phase=PointerPhase::Exit,
        )
        let exit_result = child.dispatch_pointer(
          exit_event,
          child_render,
          environment=child_environment,
          style=child_style,
          text_system~,
          capture_lookup=false,
          now_ms~,
        )
        changed = changed || exit_result.changed
        if exit_result.changed && child.has_dirty_layout() {
          layout_changed = true
        }
      }
    }
    index = index - 1
  }
  if changed {
    if layout_changed {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    } else {
      self.mark_pointer_paint_dirty()
    }
  }
  { changed, activated, focused }
}

///|
/// True if this element or any descendant currently reports `hovered` in its
/// view state. Used to decide which children to send a synthetic `Exit` to on a
/// `Move` that no longer hits them. A child without hover has nothing to clear,
/// so it is skipped — this keeps the extra dispatch off the common case.
fn ElementNode::has_hovered_descendant(self : ElementNode) -> Bool {
  if self.erased_view_node.state.hovered {
    return true
  }
  for child in self.children {
    if child.has_hovered_descendant() {
      return true
    }
  }
  false
}

///|
fn RenderNode::hit_bounds(self : RenderNode) -> Rect {
  self.paint_bounds
}

///|
fn ElementNode::has_active_pointer_capture(
  self : ElementNode,
  phase : PointerPhase,
) -> Bool {
  if phase == PointerPhase::Down {
    false
  } else if self.has_local_active_pointer_capture() {
    true
  } else {
    self.children.any(child => child.has_active_pointer_capture(phase))
  }
}

///|
fn ElementNode::has_local_active_pointer_capture(_self : ElementNode) -> Bool {
  false
}

///|
fn ElementNode::active_pointer_capture_id(
  self : ElementNode,
  phase : PointerPhase,
) -> ElementId? {
  if phase == PointerPhase::Down {
    None
  } else if self.has_local_active_pointer_capture() {
    Some(self.id)
  } else {
    let mut index = self.children.length() - 1
    while index >= 0 {
      match self.children[index].active_pointer_capture_id(phase) {
        Some(id) => return Some(id)
        None => ()
      }
      index = index - 1
    }
    None
  }
}

///|
fn ElementNode::dispatch_pointer_to_target(
  self : ElementNode,
  target : ElementId,
  event : PointerEvent,
  render : RenderNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  now_ms? : Double = 0.0,
) -> ElementEventResult? {
  if self.id == target {
    Some(
      self.dispatch_pointer(
        event,
        render,
        environment~,
        style~,
        text_system~,
        capture_lookup=false,
        now_ms~,
      ),
    )
  } else {
    let child_environment = (self.erased_view_node.child_environment)(
      environment,
    )
    let child_style = (self.erased_view_node.child_style)(style)
    let mut index = 0
    while index < self.children.length() {
      if index < render.children.length() {
        match
          self.children[index].dispatch_pointer_to_target(
            target,
            event,
            render.children[index],
            environment=child_environment,
            style=child_style,
            text_system~,
            now_ms~,
          ) {
          Some(result) => {
            if result.changed {
              self.mark_pointer_paint_dirty()
            }
            return Some(result)
          }
          None => ()
        }
      }
      index = index + 1
    }
    None
  }
}
