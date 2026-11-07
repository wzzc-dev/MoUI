///|
/// Deliver a host-recognized gesture (trackpad pinch, rotation, pan, double
/// tap, pressure) into the view tree.
///
/// Gestures carry no position: the event belongs to the content under the
/// cursor, so the runtime targets the element chain at the last known primary
/// pointer position and walks it deepest-first — the first handler that
/// claims the gesture (the `View::on_gesture` modifier reports `changed`)
/// wins, so a text nested inside a gesture-observing canvas still hands the
/// gesture up to the canvas. With no pointer sample yet there is no target
/// and the gesture is dropped; the modifier's docs state that contract.
fn RuntimeState::dispatch_gesture_event(
  self : RuntimeState,
  event : @core.GestureEvent,
) -> Unit {
  let position = match self.last_pointer_position {
    Some(position) => position
    None => return
  }
  let path = self.element_tree.root.inspector_hit_path(
    position,
    self.render_tree.root,
  )
  let mut index = path.length() - 1
  while index >= 0 {
    let target = ElementId::new(path[index])
    match
      self.element_tree.root.dispatch_app_event_to_target(
        target,
        Gesture(event),
        self.render_tree.root,
        environment=self.environment,
        text_system=self.text_system,
        now_ms=self.animfocus.now_ms,
      ) {
      Some(result) =>
        if result.changed || result.activated {
          self.apply_event_dispatch_outcome(
            result.changed,
            result.activated,
            result.deliveries,
          )
          return
        }
      None => ()
    }
    index = index - 1
  }
}
