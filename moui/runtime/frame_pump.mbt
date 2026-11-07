///|
/// Frame-tick delivery into the view tree.
///
/// Paint-only motion (transitions, the scroll rebound band) samples the
/// advancing clock during paint and needs no event. Authoritative-offset
/// motion — scroll fling inertia is the first consumer — can only advance
/// through the normal event -> state -> layout -> `on_scroll` path, so the
/// runtime hands the `FrameTick` event itself to the deepest subtrees whose
/// last paint reported a live animation. Handlers that own no frame motion
/// ignore it; a tick that moves nothing costs one targeted walk and keeps no
/// runtime state.
///
/// No public API is added: `AppEvent::FrameTick` already exists and view
/// event handlers already receive `AppEvent`s; the runtime simply stopped
/// dropping this one on the floor.

///|
fn RuntimeState::dispatch_frame_ticks_to_animating(
  self : RuntimeState,
  frame : Frame,
) -> Unit {
  if !self.animfocus.active_animations {
    return
  }
  let targets : Array[ElementId] = []
  collect_animating_frame_targets(self.render_tree.root, targets)
  for target in targets {
    match
      self.element_tree.root.dispatch_app_event_to_target(
        target,
        AppEvent::FrameTick(frame),
        self.render_tree.root,
        environment=self.environment,
        text_system=self.text_system,
        now_ms=self.animfocus.now_ms,
      ) {
      Some(result) =>
        self.apply_event_dispatch_outcome(
          result.changed,
          result.activated,
          result.deliveries,
        )
      None => ()
    }
  }
}

///|
/// Deepest render nodes that reported a live animation. `animating` folds up
/// the render tree, so an owner is a node whose own flag is set while none of
/// its children claims the frame; its element id is the dispatch target.
fn collect_animating_frame_targets(
  node : RenderNode,
  targets : Array[ElementId],
) -> Unit {
  if !node.animating {
    return
  }
  let child_owns = node.children.iter().any(child => child.animating)
  if child_owns {
    for child in node.children {
      if child.animating {
        collect_animating_frame_targets(child, targets)
      }
    }
  } else {
    targets.push(node.element_id)
  }
}

///|
/// Deliver one `AppEvent` to exactly one element, resolving the target's
/// placed geometry the way the targeted pointer path does and propagating the
/// result's dirty hint through the ancestors. Frame ticks carry no capture,
/// hover, or arena semantics, so there is nothing to bubble: the walk stops
/// at the target.
fn ElementNode::dispatch_app_event_to_target(
  self : ElementNode,
  target : ElementId,
  event : AppEvent,
  render : RenderNode,
  environment~ : Environment = Environment::neutral(),
  style~ : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem = TextSystem::fallback(),
  now_ms~ : Double = 0.0,
  node_to_screen~ : Transform2D = Transform2D::identity(),
) -> ElementEventResult? {
  if self.id == target {
    return Some(
      self.dispatch_view_event(
        self.view_node,
        event,
        render,
        text_system,
        environment~,
        style~,
        now_ms~,
        node_to_screen~,
      ),
    )
  }
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
  let mut index = 0
  while index < self.children.length() {
    if index < render.children.length() {
      let child_to_screen = render.child_to_screen(
        node_to_screen,
        render.children[index],
      )
      match
        self.children[index].dispatch_app_event_to_target(
          target,
          event,
          render.children[index],
          environment=child_environment,
          style=child_style,
          text_system~,
          now_ms~,
          node_to_screen=child_to_screen,
        ) {
        Some(result) => {
          if result.changed {
            if self.children[index].has_dirty_layout() {
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
    index = index + 1
  }
  None
}
