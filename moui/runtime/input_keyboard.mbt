///|
fn ElementNode::dispatch_keyboard(
  self : ElementNode,
  target : ElementId,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  if self.id == target {
    self.dispatch_view_event(
      self.erased_view_node,
      AppEvent::Keyboard(event),
      RenderNode::empty(),
      text_system,
      environment~,
    )
  } else {
    let mut changed = false
    let mut activated = false
    for child in self.children {
      let result = child.dispatch_keyboard(
        target,
        event,
        environment~,
        text_system~,
      )
      changed = changed || result.changed
      activated = activated || result.activated
    }
    if changed {
      self.dirty.mark_paint()
    }
    { changed, activated, focused: None }
  }
}

///|
fn ElementNode::dispatch_keyboard_shortcut(
  self : ElementNode,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let child_result = self.dispatch_keyboard_shortcut_to_children(
    event,
    environment~,
    text_system~,
  )
  if child_result.activated {
    child_result
  } else if self.erased_view_node.identity.kind.has_prefix(
      "Modified<KeyboardShortcut>",
    ) {
    if child_result.changed {
      child_result
    } else {
      self.activate_first_child(environment~, text_system~)
    }
  } else {
    child_result
  }
}

///|
fn ElementNode::dispatch_keyboard_shortcut_to_children(
  self : ElementNode,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  for child in self.children {
    let result = child.dispatch_keyboard_shortcut(
      event,
      environment~,
      text_system~,
    )
    changed = changed || result.changed
    activated = activated || result.activated
    if result.activated {
      break
    }
  }
  if changed {
    self.dirty.mark_paint()
  }
  { changed, activated, focused: None }
}

///|
fn ElementNode::activate_primary(
  self : ElementNode,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let child_result = self.activate_first_child(environment~, text_system~)
  if child_result.activated {
    child_result
  } else {
    self.dispatch_view_event(
      self.erased_view_node,
      AppEvent::Keyboard(KeyboardEvent::new(key="Enter")),
      RenderNode::empty(),
      text_system,
      environment~,
    )
  }
}

///|
fn ElementNode::activate_first_child(
  self : ElementNode,
  environment? : Environment = Environment::neutral(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  for child in self.children {
    let result = child.activate_primary(environment~, text_system~)
    if result.activated || result.changed {
      return result
    }
  }
  { changed: false, activated: false, focused: None }
}
