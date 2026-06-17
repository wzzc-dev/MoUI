///|
fn RuntimeState::set_action_commands(
  self : RuntimeState,
  commands : ActionCommandMap,
) -> Unit {
  self.action_commands = commands
}

///|
fn RuntimeState::action_commands(self : RuntimeState) -> Array[ActionCommand] {
  self.action_commands.commands()
}

///|
fn RuntimeState::dispatch_command(
  self : RuntimeState,
  intent : CommandIntent,
) -> Bool {
  let text_result = self.dispatch_focused_text_command(intent)
  if text_result.handled {
    text_result.changed
  } else if self.action_commands.dispatch_intent(intent) {
    self.request_activation_rebuild()
    true
  } else {
    false
  }
}

///|
fn RuntimeState::dispatch_action_command(
  self : RuntimeState,
  command : ActionCommand,
) -> Bool {
  if self.action_commands.dispatch_command(command) {
    self.request_activation_rebuild()
    true
  } else {
    false
  }
}

///|
fn RuntimeState::dispatch_focused_text_command(
  self : RuntimeState,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  match self.focused_element {
    Some(target) => {
      let result = self.element_tree.root.dispatch_text_command(
        target,
        intent,
        paste_text~,
        environment=self.environment,
        text_system=self.text_system,
      )
      if result.changed {
        self.needs_redraw = true
        self.needs_rebuild = true
        self.needs_paint = true
        self.mark_build_dirty(self.element_tree.id())
        self.rebuild_if_possible()
      }
      result
    }
    None => TextCommandResult::ignored()
  }
}

///|
fn RuntimeState::dispatch_event(self : RuntimeState, event : AppEvent) -> Unit {
  // Additive observation hook: broadcast every AppEvent before processing.
  // Defaults to a no-op; only active when an observer is installed (agent layer).
  (self.event_observer)(event)
  match event {
    FrameTick(_) => ()
    Resize(size) => {
      self.size = size
      self.needs_rebuild = self.element_tree.root.mark_component_tree_build_dirty()
      self.needs_redraw = true
      self.needs_layout = true
      self.needs_paint = true
      self.element_tree.root.mark_subtree_layout_dirty()
      self.mark_build_dirty(self.element_tree.id())
    }
    Redraw(_) => self.needs_redraw = false
    Pointer(event) => {
      self.ensure_render_tree()
      if event.phase == PointerPhase::Down {
        let previous_focus = self.focused_element
        let candidate_focus = self.element_tree.root.find_focusable_at(
          event.position,
          self.render_tree.root,
        )
        self.focused_element = self.element_tree.root.constrained_focus_target(
          candidate_focus,
          current=previous_focus,
        )
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id())
        }
      }
      let result = match self.active_pointer_capture {
        Some(target) =>
          if event.phase == PointerPhase::Down {
            self.element_tree.root.dispatch_pointer(
              event,
              self.render_tree.root,
              environment=self.environment,
              text_system=self.text_system,
              capture_lookup=false,
            )
          } else {
            match
              self.element_tree.root.dispatch_pointer_to_target(
                target,
                event,
                self.render_tree.root,
                environment=self.environment,
                text_system=self.text_system,
              ) {
              Some(result) => result
              None => {
                self.active_pointer_capture = None
                self.element_tree.root.dispatch_pointer(
                  event,
                  self.render_tree.root,
                  environment=self.environment,
                  text_system=self.text_system,
                  capture_lookup=false,
                )
              }
            }
          }
        None =>
          self.element_tree.root.dispatch_pointer(
            event,
            self.render_tree.root,
            environment=self.environment,
            text_system=self.text_system,
            capture_lookup=false,
          )
      }
      if event.phase == PointerPhase::Down {
        self.active_pointer_capture = self.element_tree.root.active_pointer_capture_id(
          PointerPhase::Move,
        )
      } else if event.phase == PointerPhase::Up ||
        event.phase == PointerPhase::Cancel {
        self.active_pointer_capture = None
      }
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
      self.needs_paint = self.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_current_dirty_elements()
      }
      if result.activated {
        self.request_activation_rebuild()
      }
    }
    Keyboard(event) => {
      let shortcut = self.element_tree.root.dispatch_keyboard_shortcut(
        event,
        environment=self.environment,
        text_system=self.text_system,
      )
      if shortcut.changed || shortcut.activated {
        self.needs_redraw = self.needs_redraw || shortcut.changed
        self.needs_rebuild = self.needs_rebuild || shortcut.activated
        self.needs_paint = self.needs_paint || shortcut.changed
        self.mark_current_dirty_elements()
        if shortcut.activated {
          self.request_activation_rebuild()
        }
      } else if self.action_commands.dispatch_shortcut(event) is Some(_) {
        self.request_activation_rebuild()
      } else if event.pressed && event.key == "Tab" {
        match self.focused_element {
          Some(target) => {
            let constrained_target = self.element_tree.root.constrained_focus_target(
              Some(target),
              current=Some(target),
            )
            if constrained_target != Some(target) {
              ignore(self.move_focus(reverse=event.modifiers.shift))
            } else if self.element_tree.root.accepts_tab_input(target) {
              let result = self.element_tree.root.dispatch_keyboard(
                target,
                event,
                environment=self.environment,
                text_system=self.text_system,
              )
              self.needs_redraw = self.needs_redraw || result.changed
              self.needs_rebuild = self.needs_rebuild || result.activated
              self.needs_paint = self.needs_paint || result.changed
              if result.changed || result.activated {
                self.mark_current_dirty_elements()
              }
              if result.activated {
                self.request_activation_rebuild()
              }
              if result.changed {
                self.rebuild_if_possible()
              }
            } else {
              ignore(self.move_focus(reverse=event.modifiers.shift))
            }
          }
          None => ignore(self.move_focus(reverse=event.modifiers.shift))
        }
      } else {
        match self.focused_element {
          Some(target) => {
            let is_text_input = self.element_tree.root.is_text_input_target(
              target,
            )
            let result = self.element_tree.root.dispatch_keyboard(
              target,
              event,
              environment=self.environment,
              text_system=self.text_system,
            )
            self.needs_redraw = self.needs_redraw || result.changed
            self.needs_rebuild = self.needs_rebuild || result.activated
            self.needs_paint = self.needs_paint || result.changed
            if result.changed || result.activated {
              self.mark_current_dirty_elements()
            }
            if result.activated {
              self.request_activation_rebuild()
            }
            if is_text_input && result.changed {
              self.rebuild_if_possible()
            }
          }
          None => ()
        }
      }
    }
    TextInput(event) =>
      match self.focused_element {
        Some(target) => {
          let result = self.element_tree.root.dispatch_text_input(
            target,
            event,
            environment=self.environment,
            text_system=self.text_system,
          )
          self.needs_redraw = self.needs_redraw || result.changed
          self.needs_rebuild = self.needs_rebuild || result.activated
          self.needs_paint = self.needs_paint || result.changed
          if result.changed || result.activated {
            self.mark_current_dirty_elements()
          }
          if result.activated {
            self.request_activation_rebuild()
          }
          if result.changed {
            self.rebuild_if_possible()
          }
        }
        None => ()
      }
    DragDrop(event) => {
      let result = self.element_tree.root.dispatch_drag_drop(
        event,
        self.render_tree.root,
      )
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
      self.needs_paint = self.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_current_dirty_elements()
      }
      if result.activated {
        self.request_activation_rebuild()
      }
    }
    AppEvent::PlatformView(id, event) =>
      if self.element_tree.root.dispatch_web_view_event(
          id,
          event,
          environment=self.environment,
          text_system=self.text_system,
        ) {
        self.needs_rebuild = true
        self.needs_redraw = true
        self.needs_paint = true
        self.mark_current_dirty_elements()
        self.request_activation_rebuild()
      }
    CloseRequested => ()
  }
}

///|
fn RuntimeState::move_focus(
  self : RuntimeState,
  reverse? : Bool = false,
) -> Bool {
  self.ensure_render_tree()
  let previous_focus = self.focused_element
  self.focused_element = self.element_tree.root.next_focus(
    current=previous_focus,
    reverse~,
  )
  if previous_focus != self.focused_element {
    self.mark_dirty(self.element_tree.id())
    true
  } else {
    false
  }
}

///|
fn RuntimeState::focus_key(self : RuntimeState, key : String) -> Bool {
  self.ensure_render_tree()
  match self.element_tree.root.focusable_key_target(key) {
    Some(target) => {
      let previous_focus = self.focused_element
      let constrained = self.element_tree.root.constrained_focus_target(
        Some(target),
        current=previous_focus,
      )
      if constrained == Some(target) {
        self.focused_element = Some(target)
        if previous_focus != self.focused_element {
          self.mark_dirty(self.element_tree.id())
        }
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
fn RuntimeState::advance_time(self : RuntimeState, time_ms : Double) -> Unit {
  self.dispatch_event(FrameTick(self.clock.frame(time_ms)))
}

///|
fn RuntimeState::clear_stale_pointer_capture(self : RuntimeState) -> Unit {
  match self.active_pointer_capture {
    Some(target) =>
      if !self.element_tree.root.contains_element_id(target) {
        self.active_pointer_capture = None
      }
    None => ()
  }
}
