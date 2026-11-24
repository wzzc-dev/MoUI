///|
/// Declarative in-app drag-and-drop: recognizer, hover resolution, and phase
/// dispatch.
///
/// This is deliberately separate from `input_drag_drop.mbt`, which delivers
/// backend/OS file drops as `DragDropEvent`. Here the runtime owns the session
/// and the views only declare roles:
///
/// - a press on the deepest `DragSource` element arms a pending press;
/// - once pointer travel reaches that source's `min_distance`, the session
///   starts and delivers `Started`, then `Moved` per sample;
/// - the deepest `DropTarget` that accepts the payload hovers, with
///   `Entered` / `Moved` / `Left` transitions;
/// - `Up` delivers `Dropped` and then one terminal `Ended` with the target key
///   (or `None`), and Escape / pointer `Cancel` deliver `Ended(None)`.
///
/// Roles are resolved per role, not per element: every `View` in a modifier
/// chain is its own element, so `.draggable(...).drop_target(...)` stacked on
/// one view still yields both roles (the outer element declares the target,
/// the inner one the source).

///|
priv enum ViewDragRole {
  DragSourceRole
  DragTargetRole(@core.DragPayload)
}

///|
priv struct ViewDragHit {
  id : ElementId
  source : @core.DragSource?
  target : @core.DropTarget?
}

///|
/// A primary press on a source that has not yet crossed `min_distance`.
priv struct ViewDragPress {
  source_id : ElementId
  source : @core.DragSource
  origin : Point
}

///|
/// An active drag session. It owns the pointer stream from `Started` until one
/// terminal `Ended`, regardless of what element the pointer is over.
priv struct ViewDragSession {
  source_id : ElementId
  payload : @core.DragPayload
  mut target_id : ElementId?
  mut target_key : String?
  mut position : Point
}

///|
priv struct ViewDragPointerOutcome {
  mut consumed : Bool
  mut changed : Bool
  deliveries : Array[() -> Unit]
}

///|
fn ViewDragPointerOutcome::new() -> ViewDragPointerOutcome {
  { consumed: false, changed: false, deliveries: [], }
}

///|
/// Match this element's own declaration against one role. A target only
/// matches when it accepts the payload, so a rejecting target never hovers.
fn ElementNode::drag_role_match(
  self : ElementNode,
  role : ViewDragRole,
) -> ViewDragHit? {
  let declaration = self.view_node.drag_declaration()
  match role {
    DragSourceRole =>
      match declaration.source {
        Some(source) =>
          Some({ id: self.id, source: Some(source), target: None, })
        None => None
      }
    DragTargetRole(payload) =>
      match declaration.target {
        Some(target) =>
          if target.accepts(payload) {
            Some({ id: self.id, source: None, target: Some(target), })
          } else {
            None
          }
        None => None
      }
  }
}

///|
/// Resolve the deepest element on the hit path that declares `role`, honouring
/// the same overlay priority, clipping, and disabled-environment rules as
/// pointer dispatch. The walk tries hit children in dispatch order before the
/// element itself, so an inner declaration always wins over a wrapping one.
fn ElementNode::resolve_drag_role(
  self : ElementNode,
  point : Point,
  render : RenderNode,
  environment : Environment,
  node_to_screen : Transform2D,
  clip : Rect?,
  role : ViewDragRole,
) -> ViewDragHit? {
  // `.disabled` sets the child environment; an inert subtree declares nothing
  // even though its nodes still report a declaration. This mirrors the
  // dispatch funnel that makes disabled controls ignore pointer events.
  if !environment.enabled {
    return None
  }
  let own_screen_frame = render.screen_frame(node_to_screen)
  let child_clip : Rect? = if render.clips_children {
    Some(runtime_clip_intersection(clip, own_screen_frame))
  } else {
    clip
  }
  let child_environment = self.view_node.child_environment(environment)
  let dispatch_order : Array[Int32] = []
  let is_overlay_owner : Array[Bool] = []
  for _ in self.children {
    is_overlay_owner.push(false)
  }
  // Hoisted overlay subtrees are hit first, top-most first — same prepass as
  // `dispatch_pointer_to_children`, so a drop target inside a popup wins over
  // in-flow content painted underneath it.
  let mut overlay_search = render.children.length() - 1
  while overlay_search >= 0 {
    if overlay_search < self.children.length() &&
      render.children[overlay_search].is_overlay_child &&
      runtime_point_hits_frame(
        point,
        render.children[overlay_search].screen_frame(
          render.child_to_screen(
            node_to_screen,
            render.children[overlay_search],
          ),
        ),
        None,
      ) {
      dispatch_order.push(overlay_search)
      is_overlay_owner[overlay_search] = true
    } else if overlay_search < self.children.length() &&
      render.children[overlay_search].subtree_overlay_contains_in_screen(
        point,
        render.child_to_screen(node_to_screen, render.children[overlay_search]),
      ) {
      dispatch_order.push(overlay_search)
      is_overlay_owner[overlay_search] = true
    }
    overlay_search = overlay_search - 1
  }
  let mut regular_index = self.children.length() - 1
  while regular_index >= 0 {
    if regular_index < render.children.length() &&
      !render.children[regular_index].is_overlay_child &&
      !is_overlay_owner[regular_index] {
      dispatch_order.push(regular_index)
    }
    regular_index = regular_index - 1
  }
  let mut overlay_covered = false
  for index in dispatch_order {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      let child_to_screen = render.child_to_screen(node_to_screen, child_render)
      let child_hit_clip = if child_render.is_overlay_child {
        None
      } else {
        child_clip
      }
      let hit = is_overlay_owner[index] ||
        runtime_point_hits_frame(
          point,
          child_render.screen_frame(child_to_screen),
          child_hit_clip,
        )
      let blocked_by_overlay = overlay_covered && !is_overlay_owner[index]
      if hit && !blocked_by_overlay {
        if is_overlay_owner[index] {
          overlay_covered = true
        }
        match
          child.resolve_drag_role(
            point, child_render, child_environment, child_to_screen, child_hit_clip,
            role,
          ) {
          Some(found) => return Some(found)
          None => ()
        }
      }
    }
  }
  // The element's own declaration only applies when the pointer is inside its
  // own frame; a release outside the window must not hover the root target.
  if runtime_point_hits_frame(point, own_screen_frame, clip) {
    self.drag_role_match(role)
  } else {
    None
  }
}

///|
/// Dispatch one drag phase to exactly one element (the source or the current
/// target), never to its ancestors. The context carries this element's own
/// screen frame, matching `dispatch_view_event` geometry conventions.
fn ElementNode::dispatch_drag_phase(
  self : ElementNode,
  target_id : ElementId,
  phase : @core.DragPhase,
  payload : @core.DragPayload,
  position : Point,
  target_key : String?,
  render : RenderNode,
  node_to_screen : Transform2D,
) -> RuntimeDragOutcome? {
  if self.id == target_id {
    let result = self.view_node.drag(
      @core.ViewDragContext::new(
        phase~,
        payload~,
        position~,
        frame=render.screen_frame(node_to_screen),
        target_key~,
      ),
    )
    if result.changed {
      self.mark_pointer_paint_dirty()
    }
    return Some(result)
  }
  let mut index = 0
  while index < self.children.length() {
    if index < render.children.length() {
      let child_to_screen = render.child_to_screen(
        node_to_screen,
        render.children[index],
      )
      match
        self.children[index].dispatch_drag_phase(
          target_id,
          phase,
          payload,
          position,
          target_key,
          render.children[index],
          child_to_screen,
        ) {
        Some(result) => return Some(result)
        None => ()
      }
    }
    index = index + 1
  }
  None
}

///|
fn RuntimeState::resolve_view_drag_source(
  self : RuntimeState,
  point : Point,
) -> (ElementId, @core.DragSource)? {
  match
    self.element_tree.root.resolve_drag_role(
      point,
      self.render_tree.root,
      self.environment,
      Transform2D::identity(),
      None,
      DragSourceRole,
    ) {
    Some(hit) =>
      match hit.source {
        Some(source) => Some((hit.id, source))
        None => None
      }
    None => None
  }
}

///|
fn RuntimeState::resolve_view_drag_target(
  self : RuntimeState,
  point : Point,
  payload : @core.DragPayload,
) -> (ElementId, String)? {
  match
    self.element_tree.root.resolve_drag_role(
      point,
      self.render_tree.root,
      self.environment,
      Transform2D::identity(),
      None,
      DragTargetRole(payload),
    ) {
    Some(hit) =>
      match hit.target {
        Some(target) => Some((hit.id, target.key))
        None => None
      }
    None => None
  }
}

///|
fn RuntimeState::dispatch_view_drag_phase_to(
  self : RuntimeState,
  target_id : ElementId,
  phase : @core.DragPhase,
  payload : @core.DragPayload,
  position : Point,
  target_key : String?,
  outcome : ViewDragPointerOutcome,
) -> Bool {
  match
    self.element_tree.root.dispatch_drag_phase(
      target_id,
      phase,
      payload,
      position,
      target_key,
      self.render_tree.root,
      Transform2D::identity(),
    ) {
    Some(result) => {
      outcome.changed = outcome.changed || result.changed
      outcome.deliveries.append(result.deliveries)
      true
    }
    None => false
  }
}

///|
/// Advance the declarative drag recognizer for one pointer sample and collect
/// the phases it produces. Messages are returned as deliveries rather than
/// delivered here: the caller folds them into the same terminal batch as the
/// ordinary pointer dispatch, so a phase cannot rebuild the tree in the middle
/// of the sequence and invalidate the remaining element ids.
fn RuntimeState::advance_view_drag(
  self : RuntimeState,
  event : PointerEvent,
) -> ViewDragPointerOutcome {
  let outcome = ViewDragPointerOutcome::new()
  // The in-app session is a primary-pointer, primary-button gesture. A second
  // finger must not move it; hover and press are per-element in this runtime.
  if event.id != primary_pointer_id {
    return outcome
  }
  match event.phase {
    Down => {
      // A fresh primary press while a session is still open is a host stream
      // reset: terminate the session properly (`Left` + `Ended(None)`) instead
      // of dropping it without its one terminal phase.
      match self.drag_session {
        Some(session) => self.cancel_view_drag_session(session, outcome)
        None => ()
      }
      self.drag_press = None
      if event.button == 0 {
        match self.resolve_view_drag_source(event.position) {
          Some((source_id, source)) =>
            self.drag_press = Some({
              source_id,
              source,
              origin: event.position,
            })
          None => ()
        }
      }
    }
    Move =>
      match self.drag_session {
        Some(session) =>
          self.advance_view_drag_session(session, event.position, outcome)
        None =>
          match self.drag_press {
            Some(press) => {
              let dx = event.position.x - press.origin.x
              let dy = event.position.y - press.origin.y
              let limit = press.source.min_distance
              if dx * dx + dy * dy >= limit * limit {
                self.drag_press = None
                self.start_view_drag(press, event.position, outcome)
              }
            }
            None => ()
          }
      }
    Up =>
      match self.drag_session {
        Some(session) => self.finish_view_drag(session, event.position, outcome)
        None => self.clear_view_drag_press()
      }
    Cancel =>
      match self.drag_session {
        Some(session) => self.cancel_view_drag_session(session, outcome)
        None => self.clear_view_drag_press()
      }
    Exit => ()
  }
  outcome
}

///|
fn RuntimeState::clear_view_drag_press(self : RuntimeState) -> Unit {
  self.drag_press = None
}

///|
fn RuntimeState::start_view_drag(
  self : RuntimeState,
  press : ViewDragPress,
  position : Point,
  outcome : ViewDragPointerOutcome,
) -> Unit {
  let payload = press.source.payload
  if !self.dispatch_view_drag_phase_to(
      press.source_id,
      @core.DragPhase::Started,
      payload,
      position,
      None,
      outcome,
    ) {
    // The source element disappeared between the press and the threshold
    // sample (a rebuild remounted it); there is nothing to own the session.
    return
  }
  let session = {
    source_id: press.source_id,
    payload,
    target_id: None,
    target_key: None,
    position,
  }
  self.drag_session = Some(session)
  outcome.consumed = true
  self.enter_view_drag_target(session, position, outcome)
}

///|
fn RuntimeState::advance_view_drag_session(
  self : RuntimeState,
  session : ViewDragSession,
  position : Point,
  outcome : ViewDragPointerOutcome,
) -> Unit {
  let previous_target = session.target_id
  let previous_key = session.target_key
  let resolved = self.resolve_view_drag_target(position, session.payload)
  let (next_target, next_key) = match resolved {
    Some(hit) => (Some(hit.0), Some(hit.1))
    None => (None, None)
  }
  session.position = position
  session.target_id = next_target
  session.target_key = next_key
  let target_changed = previous_target != next_target
  if target_changed {
    match previous_target {
      Some(previous) =>
        match previous_key {
          Some(key) =>
            ignore(
              self.dispatch_view_drag_phase_to(
                previous,
                @core.DragPhase::Left,
                session.payload,
                position,
                Some(key),
                outcome,
              ),
            )
          None => ()
        }
      None => ()
    }
    match next_target {
      Some(target) =>
        match next_key {
          Some(key) =>
            ignore(
              self.dispatch_view_drag_phase_to(
                target,
                @core.DragPhase::Entered,
                session.payload,
                position,
                Some(key),
                outcome,
              ),
            )
          None => ()
        }
      None => ()
    }
  } else {
    match next_target {
      Some(target) =>
        match next_key {
          Some(key) =>
            ignore(
              self.dispatch_view_drag_phase_to(
                target,
                @core.DragPhase::Moved,
                session.payload,
                position,
                Some(key),
                outcome,
              ),
            )
          None => ()
        }
      None => ()
    }
  }
  // The source observes every move sample, including the one that changed the
  // hovered target.
  ignore(
    self.dispatch_view_drag_phase_to(
      session.source_id,
      @core.DragPhase::Moved,
      session.payload,
      position,
      session.target_key,
      outcome,
    ),
  )
  outcome.consumed = true
}

///|
fn RuntimeState::enter_view_drag_target(
  self : RuntimeState,
  session : ViewDragSession,
  position : Point,
  outcome : ViewDragPointerOutcome,
) -> Unit {
  match self.resolve_view_drag_target(position, session.payload) {
    Some((target, key)) => {
      session.target_id = Some(target)
      session.target_key = Some(key)
      ignore(
        self.dispatch_view_drag_phase_to(
          target,
          @core.DragPhase::Entered,
          session.payload,
          position,
          Some(key),
          outcome,
        ),
      )
    }
    None => ()
  }
}

///|
fn RuntimeState::finish_view_drag(
  self : RuntimeState,
  session : ViewDragSession,
  position : Point,
  outcome : ViewDragPointerOutcome,
) -> Unit {
  // Resolve at the release sample rather than trusting the last move: hosts may
  // deliver a final Up at a position that never had a Move sample.
  let previous_target = session.target_id
  let previous_key = session.target_key
  let resolved = self.resolve_view_drag_target(position, session.payload)
  let (next_target, next_key) = match resolved {
    Some(hit) => (Some(hit.0), Some(hit.1))
    None => (None, None)
  }
  if previous_target != next_target {
    match previous_target {
      Some(previous) =>
        match previous_key {
          Some(key) =>
            ignore(
              self.dispatch_view_drag_phase_to(
                previous,
                @core.DragPhase::Left,
                session.payload,
                position,
                Some(key),
                outcome,
              ),
            )
          None => ()
        }
      None => ()
    }
    match (next_target, next_key) {
      (Some(target), Some(key)) =>
        ignore(
          self.dispatch_view_drag_phase_to(
            target,
            @core.DragPhase::Entered,
            session.payload,
            position,
            Some(key),
            outcome,
          ),
        )
      _ => ()
    }
  }
  let dropped_key = match (next_target, next_key) {
    (Some(target), Some(key)) => {
      ignore(
        self.dispatch_view_drag_phase_to(
          target,
          @core.DragPhase::Dropped,
          session.payload,
          position,
          Some(key),
          outcome,
        ),
      )
      Some(key)
    }
    _ => None
  }
  ignore(
    self.dispatch_view_drag_phase_to(
      session.source_id,
      @core.DragPhase::Ended,
      session.payload,
      position,
      dropped_key,
      outcome,
    ),
  )
  self.drag_session = None
  self.clear_view_drag_press()
  outcome.consumed = true
}

///|
fn RuntimeState::cancel_view_drag_session(
  self : RuntimeState,
  session : ViewDragSession,
  outcome : ViewDragPointerOutcome,
) -> Unit {
  match session.target_id {
    Some(target) =>
      ignore(
        self.dispatch_view_drag_phase_to(
          target,
          @core.DragPhase::Left,
          session.payload,
          session.position,
          session.target_key,
          outcome,
        ),
      )
    None => ()
  }
  ignore(
    self.dispatch_view_drag_phase_to(
      session.source_id,
      @core.DragPhase::Ended,
      session.payload,
      session.position,
      None,
      outcome,
    ),
  )
  self.drag_session = None
  self.clear_view_drag_press()
  outcome.consumed = true
}

///|
/// Escape cancels an active in-app drag and is consumed by it (a dialog behind
/// the drag must not dismiss in the same key press). Returns an empty outcome
/// when no session is active.
fn RuntimeState::dispatch_view_drag_escape(
  self : RuntimeState,
) -> ViewDragPointerOutcome {
  let outcome = ViewDragPointerOutcome::new()
  match self.drag_session {
    Some(session) => self.cancel_view_drag_session(session, outcome)
    None => ()
  }
  outcome
}

///|
/// Drop a drag session whose source or hovered target disappeared in a
/// rebuild. There is no element left to receive `Left`/`Ended`, so the session
/// is dropped silently rather than dispatching to recycled ids.
fn RuntimeState::clear_stale_view_drag(self : RuntimeState) -> Unit {
  match self.drag_press {
    Some(press) =>
      if !self.element_tree.root.contains_element_id(press.source_id) {
        self.drag_press = None
      }
    None => ()
  }
  match self.drag_session {
    Some(session) =>
      if !self.element_tree.root.contains_element_id(session.source_id) {
        self.drag_session = None
      } else {
        match session.target_id {
          Some(target) =>
            if !self.element_tree.root.contains_element_id(target) {
              session.target_id = None
              session.target_key = None
            }
          None => ()
        }
      }
    None => ()
  }
}
