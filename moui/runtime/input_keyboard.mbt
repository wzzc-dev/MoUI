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
  let is_overlay_host = self.view_node.identity().kind == "OverlayHost"
  // OverlayHost owns the presentation stack's keyboard policy. Give it the
  // first chance to consume Escape so a focused base control cannot observe
  // the event before the top-most presentation dismisses.
  let own_first = is_overlay_host
  let own = if own_first {
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
  if own_first && own.changed {
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
    } else if self.view_node.identity().kind.has_prefix(
        "Modified<KeyboardShortcut>",
      ) ||
      is_overlay_host {
      if is_overlay_host {
        child_result
      } else {
        // Give the modifier node itself a chance to handle the keyboard event
        // (so its `handle_keyboard_shortcut` runs). Only if the node reports a
        // change (meaning the shortcut matched) do we activate the first child.
        let own = if own_first {
          own
        } else {
          self.dispatch_view_event(
            self.view_node,
            AppEvent::Keyboard(event),
            RenderNode::empty(),
            text_system,
            environment~,
            style~,
          )
        }
        if own.changed {
          if self.view_node.identity().kind == "OverlayHost" {
            own
          } else {
            self.activate_first_child(environment~, style~, text_system~)
          }
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
