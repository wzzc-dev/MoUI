///|
fn ElementNode::dispatch_keyboard(
  self : ElementNode,
  target : ElementId,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  if self.id == target {
    self.dispatch_view_event(
      self.view_node,
      AppEvent::Keyboard(event),
      RenderNode::empty(),
      text_system,
      environment~,
      style~,
      focused=true,
    )
  } else {
    let child_environment = self.view_node.child_environment(environment)
    let child_style = self.view_node.child_style(style)
    let mut changed = false
    let mut activated = false
    let deliveries : Array[() -> Unit] = []
    for child in self.children {
      let result = child.dispatch_keyboard(
        target,
        event,
        environment=child_environment,
        style=child_style,
        text_system~,
      )
      changed = changed || result.changed
      activated = activated || result.activated
      deliveries.append(result.deliveries)
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
    }
  }
}

///|
fn ElementNode::dispatch_keyboard_shortcut(
  self : ElementNode,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  // Keyboard policy is typed (ADR 0033): overlay hosts own top-most-first
  // dismissal, keyboard-shortcut modifier scopes handle their own shortcuts.
  let owns_dismissal = self.view_node.keyboard_policy()
    is @core.KeyboardPolicy::TopMostDismissal
  let is_shortcut_scope = self.view_node.keyboard_policy()
    is @core.KeyboardPolicy::ShortcutScope
  let own = if owns_dismissal {
    // Give the host the first chance to consume Escape so a focused base
    // control cannot observe the event before the top-most presentation
    // dismisses. (The runtime layer stack runs hosts top-most-first before
    // this tree dispatch; this pass stays for unconsumed fall-through.)
    self.dispatch_view_event(
      self.view_node,
      AppEvent::Keyboard(event),
      RenderNode::empty(),
      text_system,
      environment~,
      style~,
    )
  } else {
    {
      changed: false,
      activated: false,
      captured: false,
      capture_target: None,
      focused: None,
      deliveries: [],
    }
  }
  if owns_dismissal && own.changed {
    own
  } else {
    let child_result = self.dispatch_keyboard_shortcut_to_children(
      event,
      environment~,
      style~,
      text_system~,
    )
    if child_result.activated {
      child_result
    } else if is_shortcut_scope || owns_dismissal {
      if owns_dismissal {
        child_result
        // Give the modifier node itself a chance to handle the keyboard event
        // (so its `handle_keyboard_shortcut` runs). Only if the node reports a
        // change (meaning the shortcut matched) do we activate the first child.
      } else if own.changed {
        self.activate_first_child(environment~, style~, text_system~)
      } else if child_result.changed {
        child_result
      } else {
        {
          changed: false,
          activated: false,
          captured: false,
          capture_target: None,
          focused: None,
          deliveries: [],
        }
      }
    } else {
      child_result
    }
  }
}

///|
fn ElementNode::dispatch_keyboard_shortcut_to_children(
  self : ElementNode,
  event : KeyboardEvent,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let deliveries : Array[() -> Unit] = []
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
  for child in self.children {
    let result = child.dispatch_keyboard_shortcut(
      event,
      environment=child_environment,
      style=child_style,
      text_system~,
    )
    changed = changed || result.changed
    activated = activated || result.activated
    deliveries.append(result.deliveries)
    if result.activated {
      break
    }
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
  }
}

///|
fn ElementNode::activate_primary(
  self : ElementNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let child_result = self.activate_first_child(
    environment~,
    style~,
    text_system~,
  )
  if child_result.activated {
    child_result
  } else {
    self.dispatch_view_event(
      self.view_node,
      AppEvent::Keyboard(KeyboardEvent::new(key="Enter")),
      RenderNode::empty(),
      text_system,
      environment~,
      style~,
    )
  }
}

///|
fn ElementNode::activate_first_child(
  self : ElementNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
) -> ElementEventResult {
  let child_environment = self.view_node.child_environment(environment)
  let child_style = self.view_node.child_style(style)
  for child in self.children {
    let result = child.activate_primary(
      environment=child_environment,
      style=child_style,
      text_system~,
    )
    if result.activated || result.changed {
      return result
    }
  }
  {
    changed: false,
    activated: false,
    captured: false,
    capture_target: None,
    focused: None,
    deliveries: [],
  }
}
