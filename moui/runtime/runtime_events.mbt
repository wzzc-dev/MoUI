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
    FrameTick(frame) => {
      // Advance the animation clock so controls can compute transition
      // progress from `ViewPaintContext.now_ms`. While any subtree is still
      // animating, keep paint + redraw dirty so the host ticks another frame;
      // once every animation settles (`active_animations` flips false) this
      // becomes a passive clock update with no extra redraw.
      self.now_ms = frame.time_ms
      if self.active_animations {
        self.needs_paint = true
        self.needs_redraw = true
        self.mark_dirty(self.element_tree.id())
      }
    }
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
      // Track hover across moves so the previously hovered element gets a
      // synthetic `Exit` when the pointer leaves it. Host backends only emit
      // `Move`, and a move landing outside an element is never delivered to it
      // by hit-testing — so without this the element's `hovered` flag sticks.
      // Skip while a pointer is captured (a drag) so the captured element keeps
      // its `pressed` state until `Up`, rather than being reset to `Normal`.
      if event.phase == PointerPhase::Move && self.active_pointer_capture is None {
        self.dispatch_hover_exit_if_needed(event.position)
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
              now_ms=self.now_ms,
            )
          } else {
            match
              self.element_tree.root.dispatch_pointer_to_target(
                target,
                event,
                self.render_tree.root,
                environment=self.environment,
                text_system=self.text_system,
                now_ms=self.now_ms,
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
                  now_ms=self.now_ms,
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
            now_ms=self.now_ms,
          )
      }
      if event.phase == PointerPhase::Down {
        self.active_pointer_capture = self.element_tree.root.active_pointer_capture_id(
          PointerPhase::Move,
        )
      } else if event.phase == PointerPhase::Up ||
        event.phase == PointerPhase::Cancel {
        self.active_pointer_capture = None
        // After a press cycle ends, re-resolve the hover target at the current
        // position so subsequent moves deliver `Exit` from the right element.
        // `Up` lands on whatever is under the pointer now (the button stays
        // hovered); `Cancel` clears hover outright.
        self.hovered_element = if event.phase == PointerPhase::Cancel {
          None
        } else {
          self.element_tree.root.find_hover_target(
            event.position,
            self.render_tree.root,
          )
        }
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
  // A rebuild can also remove the hovered element (e.g. a hovered button's
  // subtree is swapped out). Drop the stale id so we never try to dispatch an
  // `Exit` to an element that no longer exists.
  match self.hovered_element {
    Some(target) =>
      if !self.element_tree.root.contains_element_id(target) {
        self.hovered_element = None
      }
    None => ()
  }
}

///|
/// Resolve the element now under `position` and, when it differs from the
/// previously hovered one, deliver a synthetic `Exit` pointer event to the old
/// target so it can clear its hover state. The `Exit` is dispatched directly to
/// the target id (bypassing hit-testing, since the pointer is by definition no
/// longer over it) and carries the current position so views that re-check
/// `inside` see `false`. Updates `hovered_element` to the new target (or
/// `None`). Paint/redraw dirty flags propagate from the `Exit` result so the
/// cleared hover actually repaints.
fn RuntimeState::dispatch_hover_exit_if_needed(
  self : RuntimeState,
  position : Point,
) -> Unit {
  let new_hovered = self.element_tree.root.find_hover_target(
    position,
    self.render_tree.root,
  )
  if new_hovered == self.hovered_element {
    return
  }
  match self.hovered_element {
    Some(old) => {
      let exit_event = PointerEvent::new(position~, phase=PointerPhase::Exit)
      match
        self.element_tree.root.dispatch_pointer_to_target(
          old,
          exit_event,
          self.render_tree.root,
          environment=self.environment,
          text_system=self.text_system,
          now_ms=self.now_ms,
        ) {
        Some(result) => {
          self.needs_redraw = self.needs_redraw || result.changed
          self.needs_paint = self.needs_paint || result.changed
          if result.changed {
            self.mark_current_dirty_elements()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  self.hovered_element = new_hovered
}
