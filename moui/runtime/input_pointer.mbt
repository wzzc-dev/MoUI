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
      self.view_node,
      AppEvent::Pointer(event),
      render,
      text_system,
      environment~,
      style~,
      now_ms~,
    )
    let deliveries = child_result.deliveries.copy()
    deliveries.append(own.deliveries)
    {
      changed: child_result.changed || own.changed,
      activated: own.activated,
      captured: child_result.captured || own.captured,
      capture_target: match child_result.capture_target {
        Some(target) => Some(target)
        None => own.capture_target
      },
      focused: match own.focused {
        Some(value) => Some(value)
        None => child_result.focused
      },
      deliveries,
    }
  }
}

///|
fn ElementNode::dispatch_view_event(
  self : ElementNode,
  data : &RuntimeViewNode,
  event : AppEvent,
  render : RenderNode,
  text_system : TextSystem,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  now_ms? : Double = 0.0,
  focused? : Bool = false,
) -> ElementEventResult {
  let result = data.event({
    frame: render.frame,
    child_frames: render.children.map(child => child.frame),
    event,
    focused,
    state: self.control.view_context(focused),
    text_control: self.control.text_context(),
    text_system,
    environment,
    style,
    now_ms,
  })
  match result.state {
    Some(next_state) => self.control.apply_view_context(next_state)
    None => ()
  }
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  if result.state is Some(_) || result.text_control is Some(_) {
    self.dirty.mark_semantics()
  }
  self.apply_view_dirty_hint(result.dirty)
  {
    changed: result.changed || result.captured,
    activated: result.activated,
    captured: result.captured,
    capture_target: if result.captured {
      Some(self.id)
    } else {
      None
    },
    focused: if result.focused {
      Some(self.id)
    } else {
      None
    },
    deliveries: result.deliveries,
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
    ViewBuildDirty => self.dirty.mark_build_only()
  }
}

///|
fn ElementNode::mark_pointer_paint_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_paint()
  self.render_cache.clear()
}

///|
fn ElementNode::mark_pointer_descendant_paint_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_paint_descendant()
  self.render_cache.invalidate_composition()
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
  let mut captured = false
  let mut capture_target : ElementId? = None
  let mut focused : ElementId? = None
  let deliveries : Array[() -> Unit] = []
  let mut layout_changed = false
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
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
  //
  // Touch hosts (HarmonyOS / Android) often never emit Move between taps: Up
  // leaves the control in `Hovered` (button_control treats Up-inside as hover),
  // and the next Down hits a *different* control without a Move. Without Exit
  // on Down, the previous button keeps its hover/press tint (gray-white) until
  // some later full redraw. Include Down (and Cancel) in the stale-hover clear.
  let clear_stale_hover = event.phase == PointerPhase::Move ||
    event.phase == PointerPhase::Exit ||
    event.phase == PointerPhase::Down ||
    event.phase == PointerPhase::Cancel
  let mut delivered_main_event = false
  // Once a hoisted overlay surface covering the point has been dispatched,
  // in-flow siblings must not receive the same main event — even when the
  // overlay content itself is non-interactive (text, tooltips, spacer
  // containers). Without this, clicks fall through a popup onto whatever it
  // covers (focusing covered text fields, pressing covered buttons). Active
  // pointer captures are exempt so an ongoing gesture keeps its target.
  let mut overlay_covered = false
  // Hoisted overlay subtrees (control popups, presentations) receive pointer
  // events before in-flow content, top-most first — globally, via the
  // `subtree_overlay_contains` prepass: a popup hoisted anywhere inside a
  // child subtree wins over in-flow siblings painted underneath it. Their
  // placed frames bound the hit region, so a click outside the popup falls
  // through to in-flow content below.
  let dispatch_order : Array[Int] = []
  let is_overlay_owner : Array[Bool] = []
  for _ in self.children {
    is_overlay_owner.push(false)
  }
  let mut overlay_search = render.children.length() - 1
  while overlay_search >= 0 {
    if overlay_search < self.children.length() &&
      render.children[overlay_search].is_overlay_child &&
      render.children[overlay_search].hit_bounds().contains(event.position) {
      dispatch_order.push(overlay_search)
      is_overlay_owner[overlay_search] = true
    } else if overlay_search < self.children.length() &&
      render.children[overlay_search].subtree_overlay_contains(event.position) {
      dispatch_order.push(overlay_search)
      is_overlay_owner[overlay_search] = true
    }
    overlay_search = overlay_search - 1
  }
  let mut regular_index = self.children.length() - 1
  while regular_index >= 0 {
    if regular_index < render.children.length() &&
      !render.children[regular_index].is_overlay_child {
      dispatch_order.push(regular_index)
    }
    regular_index = regular_index - 1
  }
  for index in dispatch_order {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      let has_capture = capture_lookup &&
        child.has_active_pointer_capture(event.phase)
      // An overlay owner is dispatched for its hoisted popup even when the
      // point lies outside the owner's own (possibly clipped) frame.
      let hit = is_overlay_owner[index] ||
        has_capture ||
        child_render.hit_bounds().contains(event.position)
      // In-flow children are skipped while an overlay surface covering the
      // point has been dispatched (unless an active capture targets them).
      let blocked_by_overlay = overlay_covered &&
        !is_overlay_owner[index] &&
        !has_capture
      if hit && !delivered_main_event && !blocked_by_overlay {
        if is_overlay_owner[index] {
          overlay_covered = true
        }
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
        captured = captured || result.captured
        deliveries.append(result.deliveries)
        match (capture_target, result.capture_target) {
          (None, Some(target)) => capture_target = Some(target)
          _ => ()
        }
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
        // the event; overlay owners are the exception — reaching one means
        // the point is inside a popup surface, so in-flow content is blocked
        // via `overlay_covered`. For Move/Exit, the loop keeps going
        // regardless so that previously hovered siblings get a synthetic
        // Exit to clear hover.
        if has_capture ||
          result.changed ||
          result.activated ||
          result.focused is Some(_) {
          delivered_main_event = true
        }
      } else if clear_stale_hover && child.has_hovered_descendant() {
        // Pointer left this child (Move) or pressed elsewhere (Down on touch)
        // without a host leave event — send `Exit` so hover/press clears. The
        // exit carries the current position, outside this child by definition.
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
        captured = captured || exit_result.captured
        deliveries.append(exit_result.deliveries)
        if exit_result.changed && child.has_dirty_layout() {
          layout_changed = true
        }
      }
    }
  }
  if changed {
    if layout_changed {
      self.dirty.mark_layout_descendant()
      self.layout_cache.clear()
      self.render_cache.clear()
    } else {
      self.mark_pointer_descendant_paint_dirty()
    }
  }
  { changed, activated, captured, capture_target, focused, deliveries }
}

///|
/// True if this element or any descendant currently reports `hovered` or
/// `pressed` in its view state. Used to decide which children to send a
/// synthetic `Exit` to when the pointer leaves them (Move) or presses
/// elsewhere (Down on touch). A child without hover/press has nothing to clear,
/// so it is skipped — this keeps the extra dispatch off the common case.
fn ElementNode::has_hovered_descendant(self : ElementNode) -> Bool {
  if self.control.view_state.hovered || self.control.view_state.pressed {
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
  match self.hit_rect {
    Some(hit) => hit
    None => self.paint_bounds
  }
}

///|

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
  let (result, _) = self.dispatch_pointer_to_target_with_scroll_ancestor(
    target,
    event,
    render,
    environment~,
    style~,
    text_system~,
    now_ms~,
  )
  result
}

///|
/// Deliver a captured event to its target and, for Move/Up/Cancel, let the
/// nearest scroll-view ancestor observe the same stream. A child control can
/// keep its normal capture/click semantics while a surrounding scroll view
/// still recognizes a touch drag that started on that control.
fn ElementNode::dispatch_pointer_to_target_with_scroll_ancestor(
  self : ElementNode,
  target : ElementId,
  event : PointerEvent,
  render : RenderNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  now_ms? : Double = 0.0,
  bubble_scroll? : Bool = true,
) -> (ElementEventResult?, Bool) {
  if self.id == target {
    (
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
      ),
      false,
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    let mut index = 0
    while index < self.children.length() {
      if index < render.children.length() {
        match
          self.children[index].dispatch_pointer_to_target_with_scroll_ancestor(
            target,
            event,
            render.children[index],
            environment=child_environment,
            style=child_style,
            text_system~,
            now_ms~,
            bubble_scroll~,
          ) {
          (Some(result), bubbled) => {
            // Pointer capture normally routes Move/Up/Cancel only to the
            // target. Gesture modifiers are often stacked, though (for
            // example a tap wrapped by a drag), so ancestors must observe the
            // captured stream as it unwinds. A child activation wins the
            // gesture; ancestors receive a synthetic Cancel in that case so
            // they can release pending drag/tap state without activating a
            // second command.
            let should_bubble = bubble_scroll &&
              event.phase != PointerPhase::Down &&
              // A nested scroll view has already observed this stream when
              // `bubbled` is true. Keep walking so non-scroll gesture
              // ancestors can still clean up, but avoid feeding a second
              // scroll container the same captured event.
              (!bubbled || !self.is_scroll_view_node())
            if should_bubble {
              let ancestor_event = if result.activated &&
                event.phase == PointerPhase::Up {
                PointerEvent::new(
                  position=event.position,
                  phase=PointerPhase::Cancel,
                  button=event.button,
                  modifiers=event.modifiers,
                  time_ms=event.time_ms,
                )
              } else {
                event
              }
              let own = self.dispatch_view_event(
                self.view_node,
                AppEvent::Pointer(ancestor_event),
                render,
                text_system,
                environment~,
                style~,
                now_ms~,
              )
              let combined = merge_element_event_results(result, own)
              // Once an ancestor drag recognizes a Move, cancel the child
              // press recognizer. Otherwise the captured child can still
              // activate on Up after the drag has already started.
              let combined = if event.phase == PointerPhase::Move &&
                own.changed &&
                (own.activated || self.is_scroll_view_node()) &&
                result.captured {
                let cancel_event = PointerEvent::new(
                  position=event.position,
                  phase=PointerPhase::Cancel,
                  button=event.button,
                  modifiers=event.modifiers,
                  time_ms=event.time_ms,
                )
                match
                  self.children[index].dispatch_pointer_to_target_with_scroll_ancestor(
                    target,
                    cancel_event,
                    render.children[index],
                    environment=child_environment,
                    style=child_style,
                    text_system~,
                    now_ms~,
                    bubble_scroll=false,
                  ) {
                  (Some(cancelled), _) =>
                    merge_element_event_results(combined, cancelled)
                  (None, _) => combined
                }
              } else {
                combined
              }
              if combined.changed {
                self.mark_pointer_paint_dirty()
              }
              // `bubbled` tracks whether a scroll ancestor has already
              // observed the stream, rather than whether an arbitrary
              // gesture ancestor handled it. This lets a scroll view above a
              // tap/drag stack continue to receive the captured Move.
              return (
                Some(combined),
                bubbled || (self.is_scroll_view_node() && own.captured),
              )
            }
            if result.changed {
              self.mark_pointer_paint_dirty()
            }
            return (Some(result), bubbled)
          }
          (None, _) => ()
        }
      }
      index = index + 1
    }
    (None, false)
  }
}

///|
fn merge_element_event_results(
  first : ElementEventResult,
  second : ElementEventResult,
) -> ElementEventResult {
  let deliveries = first.deliveries.copy()
  deliveries.append(second.deliveries)
  {
    changed: first.changed || second.changed,
    activated: first.activated || second.activated,
    captured: first.captured || second.captured,
    capture_target: match first.capture_target {
      Some(target) => Some(target)
      None => second.capture_target
    },
    focused: match second.focused {
      Some(value) => Some(value)
      None => first.focused
    },
    deliveries,
  }
}

///|
fn ElementNode::is_scroll_view_node(self : ElementNode) -> Bool {
  self.view_node.semantics().role == Some(@core.SemanticsRole::ScrollView)
}
