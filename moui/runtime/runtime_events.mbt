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
  paste_text~ : String? = None,
) -> TextCommandResult {
  match self.animfocus.focused_element {
    Some(target) => {
      let outcome = self.element_tree.root.dispatch_text_command(
        target,
        intent,
        paste_text~,
        environment=self.environment,
        text_system=self.text_system,
      )
      let result = outcome.result
      if result.changed {
        self.dirty.needs_redraw = true
        self.dirty.needs_rebuild = true
        self.dirty.needs_paint = true
        self.mark_build_dirty(self.element_tree.id())
      }
      self.deliver_messages(outcome.deliveries)
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
      self.animfocus.now_ms = frame.time_ms
      if self.animfocus.active_animations {
        self.dirty.needs_paint = true
        self.dirty.needs_redraw = true
        self.mark_dirty(self.element_tree.id())
        // A hold produces no pointer sample of its own, so a recognizer that
        // completes on elapsed time would have nothing to re-evaluate. Re-emit
        // the pressed position as a `Move` while the frame latch is held and a
        // pointer is down; recognizers at an unchanged position are idempotent,
        // so controls that only respond to movement see no effect. The subtree
        // stops asking for frames once it settles, which ends the re-sampling.
        // Snapshot first: dispatching can release a press and mutate the map.
        for stream in self.animfocus.pointer_presses.to_array() {
          let (id, position) = stream
          ignore(
            self.dispatch_pointer_event(
              PointerEvent::new(position~, phase=Move, id~),
            ),
          )
        }
      }
    }
    Resize(size) => {
      self.size = size
      self.request_root_rebuild(reason="viewport resized")
      self.dirty.needs_redraw = true
      self.dirty.needs_layout = true
      self.dirty.needs_paint = true
      self.element_tree.root.mark_subtree_layout_dirty()
      self.mark_build_dirty(self.element_tree.id())
    }
    Redraw(_) => {
      self.dirty.needs_redraw = false
      self.dirty.rebuild_wakeup_redraw = false
    }
    Pointer(event) => ignore(self.dispatch_pointer_event(event))
    Keyboard(event) => {
      let layout = self.layout_tree_for_input()
      // Top-most dismissal layer stack (ADR 0033): overlay hosts registered
      // during the placement pass receive Escape/Back top-most-first, so a
      // popover nested inside a dialog dismisses before the dialog.
      let layer_consumed = self.dispatch_dismissal_layers(event)
      if layer_consumed {
        return
      }
      let shortcut = self.element_tree.root.dispatch_keyboard_shortcut(
        event,
        environment=self.environment,
        text_system=self.text_system,
      )
      if shortcut.changed || shortcut.activated {
        self.dirty.needs_redraw = self.dirty.needs_redraw || shortcut.changed
        self.dirty.needs_rebuild = self.dirty.needs_rebuild ||
          shortcut.activated
        self.dirty.needs_paint = self.dirty.needs_paint || shortcut.changed
        self.mark_current_dirty_elements()
        if shortcut.activated {
          self.request_activation_rebuild()
        }
        self.deliver_messages(shortcut.deliveries)
      } else if self.action_commands.dispatch_shortcut(event) is Some(_) {
        self.deliver_messages(shortcut.deliveries)
        self.request_activation_rebuild()
      } else if event.pressed && event.key == "Tab" {
        self.deliver_messages(shortcut.deliveries)
        match self.animfocus.focused_element {
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
                layout~,
                environment=self.environment,
                text_system=self.text_system,
              )
              self.dirty.needs_redraw = self.dirty.needs_redraw ||
                result.changed
              self.dirty.needs_rebuild = self.dirty.needs_rebuild ||
                result.activated
              self.dirty.needs_paint = self.dirty.needs_paint || result.changed
              if result.changed || result.activated {
                self.mark_current_dirty_elements()
              }
              if result.activated {
                self.request_activation_rebuild()
              }
              self.deliver_messages(result.deliveries)
            } else {
              ignore(self.move_focus(reverse=event.modifiers.shift))
            }
          }
          None => ignore(self.move_focus(reverse=event.modifiers.shift))
        }
      } else {
        self.deliver_messages(shortcut.deliveries)
        match self.animfocus.focused_element {
          Some(target) => {
            let result = self.element_tree.root.dispatch_keyboard(
              target,
              event,
              layout~,
              environment=self.environment,
              text_system=self.text_system,
            )
            self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
            self.dirty.needs_rebuild = self.dirty.needs_rebuild ||
              result.activated
            self.dirty.needs_paint = self.dirty.needs_paint || result.changed
            if result.changed || result.activated {
              self.mark_current_dirty_elements()
            }
            if result.activated {
              self.request_activation_rebuild()
            }
            self.deliver_messages(result.deliveries)
          }
          None => ()
        }
      }
    }
    TextInput(event) =>
      match self.animfocus.focused_element {
        Some(target) => {
          let layout = self.layout_tree_for_input()
          let result = self.element_tree.root.dispatch_text_input(
            target,
            event,
            layout~,
            environment=self.environment,
            text_system=self.text_system,
          )
          self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
          self.dirty.needs_rebuild = self.dirty.needs_rebuild ||
            result.activated
          self.dirty.needs_paint = self.dirty.needs_paint || result.changed
          if result.changed || result.activated {
            self.mark_current_dirty_elements()
          }
          if result.activated {
            self.request_activation_rebuild()
          }
          self.deliver_messages(result.deliveries)
        }
        None => ()
      }
    DragDrop(event) => {
      let result = self.element_tree.root.dispatch_drag_drop(
        event,
        self.render_tree.root,
      )
      self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
      self.dirty.needs_rebuild = self.dirty.needs_rebuild || result.activated
      self.dirty.needs_paint = self.dirty.needs_paint || result.changed
      if result.changed || result.activated {
        self.mark_current_dirty_elements()
      }
      if result.activated {
        self.request_activation_rebuild()
      }
      self.deliver_messages(result.deliveries)
    }
    PlatformView(id, event) => {
      let result = self.element_tree.root.dispatch_web_view_event(
        id,
        event,
        environment=self.environment,
        text_system=self.text_system,
      )
      if result.changed || result.activated || result.captured {
        self.dirty.needs_rebuild = true
        self.dirty.needs_redraw = true
        self.dirty.needs_paint = true
        self.mark_current_dirty_elements()
        self.request_activation_rebuild()
      }
      self.deliver_messages(result.deliveries)
    }
    CloseRequested => ()
  }
  // Caret/selection reveals are resolved against the placed tree once the
  // event that moved the caret has been folded in. Only input events can
  // move a caret, so a frame tick or resize skips the walk entirely.
  match event {
    Pointer(_) | Keyboard(_) | TextInput(_) =>
      self.try_pending_text_reveal_from_current_layout()
    _ => ()
  }
}

///|
fn RuntimeState::commit_focus(self : RuntimeState, next : ElementId?) -> Bool {
  let previous = self.animfocus.focused_element
  if previous == next {
    return false
  }
  self.animfocus.focused_element = next
  match previous {
    Some(id) => {
      self.mark_dirty(id)
      self.mark_semantics_dirty(id)
    }
    None => ()
  }
  match next {
    Some(id) => {
      self.mark_dirty(id)
      self.mark_semantics_dirty(id)
    }
    None => ()
  }
  true
}

///|
/// Dispatches one pointer event and reports whether the runtime consumed it.
/// This is intentionally separate from `dispatch_event`: browser hosts need
/// this result synchronously, while ordinary hosts can continue to ignore it.
fn RuntimeState::dispatch_pointer_event(
  self : RuntimeState,
  event : PointerEvent,
) -> InputDispatchResult {
  self.ensure_render_tree()
  self.last_event_hit_path = self.element_tree.root.inspector_hit_path(
    event.position,
    self.render_tree.root,
  )
  let release_pointer = match self.animfocus.pointer_captures.get(event.id) {
    Some(_) => event.phase == Up || event.phase == Cancel
    None => false
  }
  // Track the pressed position per stream for the frame-tick re-sample that
  // lets a duration-based recognizer complete while a finger holds still
  // (`Move` updates it so the synthesised sample follows the real pointer, and
  // `Exit` must not clear it: hover can leave a control while the press
  // continues).
  match event.phase {
    Down => self.animfocus.pointer_presses[event.id] = event.position
    Move =>
      if self.animfocus.pointer_presses.contains(event.id) {
        self.animfocus.pointer_presses[event.id] = event.position
      }
    Up | Cancel => self.animfocus.pointer_presses.remove(event.id)
    _ => ()
  }
  // Focus, like hover, has one owner: the primary stream. A second finger
  // pressing elsewhere mid-gesture must not pull focus away from the control
  // the first finger is dragging (hosts that report one finger only, such as
  // the embedded ones, always arrive as the primary id and are unaffected).
  if event.phase == Down && event.id == primary_pointer_id {
    let previous_focus = self.animfocus.focused_element
    let candidate_focus = self.element_tree.root.find_focusable_at(
      event.position,
      self.render_tree.root,
    )
    ignore(
      self.commit_focus(
        self.element_tree.root.constrained_focus_target(
          candidate_focus,
          current=previous_focus,
        ),
      ),
    )
  }
  let result = match self.animfocus.pointer_captures.get(event.id) {
    Some(target) =>
      if event.phase == Down {
        self.element_tree.root.dispatch_pointer(
          event,
          self.render_tree.root,
          environment=self.environment,
          text_system=self.text_system,
          capture_lookup=false,
          now_ms=self.animfocus.now_ms,
        )
      } else {
        match
          self.element_tree.root.dispatch_pointer_to_target(
            target,
            event,
            self.render_tree.root,
            environment=self.environment,
            text_system=self.text_system,
            now_ms=self.animfocus.now_ms,
          ) {
          Some(result) => result
          None => {
            self.animfocus.pointer_captures.remove(event.id)
            self.element_tree.root.dispatch_pointer(
              event,
              self.render_tree.root,
              environment=self.environment,
              text_system=self.text_system,
              capture_lookup=false,
              now_ms=self.animfocus.now_ms,
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
        now_ms=self.animfocus.now_ms,
      )
  }
  // Views can claim focus from the pointer handler (e.g. picker popup
  // interaction). Prefer that claim over the geometry-only hit from
  // `find_focusable_at` so focus tracks the control that handled the event.
  match result.focused {
    Some(target) => ignore(self.commit_focus(Some(target)))
    None => ()
  }
  if event.phase == Down {
    // Standard controls report `captured` on a handled Down. Retain the
    // focusable hit target so the matching Up reaches the same element even
    // if browser focus/semantics updates repaint the tree between DOM events.
    // A control with an explicit local capture keeps precedence.
    let captured_target = match
      self.element_tree.root.active_pointer_capture_id(Move) {
      Some(target) => Some(target)
      None =>
        if result.captured {
          match result.capture_target {
            Some(target) => Some(target)
            None => self.animfocus.focused_element
          }
        } else {
          None
        }
    }
    match captured_target {
      Some(target) => self.animfocus.pointer_captures[event.id] = target
      None => self.animfocus.pointer_captures.remove(event.id)
    }
  } else if event.phase == Up || event.phase == Cancel {
    self.animfocus.pointer_captures.remove(event.id)
  }
  self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
  self.dirty.needs_rebuild = self.dirty.needs_rebuild || result.activated
  self.dirty.needs_paint = self.dirty.needs_paint || result.changed
  if result.changed || result.activated {
    self.mark_current_dirty_elements()
  }
  if result.activated {
    self.request_activation_rebuild()
  }
  let dispatch_result = {
    // A wheel event is consumed only when a scroll target actually moved. In
    // particular, this keeps the browser default available at a scroll edge.
    // Pointer capture is a separate host concern and must not stand in for
    // consumption on every input phase.
    handled: if event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0 {
      result.changed
    } else {
      result.captured || result.changed || result.activated
    },
    capture_pointer: event.phase == Down && result.captured,
    release_pointer,
  }
  self.deliver_messages(result.deliveries)
  dispatch_result
}

///|
fn RuntimeState::move_focus(
  self : RuntimeState,
  reverse~ : Bool = false,
) -> Bool {
  self.ensure_render_tree()
  let previous_focus = self.animfocus.focused_element
  let next_focus = self.element_tree.root.next_focus(
    current=previous_focus,
    reverse~,
  )
  self.commit_focus(next_focus)
}

///|
fn RuntimeState::focus_key(self : RuntimeState, key : String) -> Bool {
  self.ensure_render_tree()
  let found = self.element_tree.root.focusable_key_target(key)
  match found {
    Some(target) => {
      let previous_focus = self.animfocus.focused_element
      let constrained = self.element_tree.root.constrained_focus_target(
        Some(target),
        current=previous_focus,
      )
      if constrained == Some(target) {
        ignore(self.commit_focus(Some(target)))
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
  for stream in self.animfocus.pointer_captures.to_array() {
    let (id, target) = stream
    if !self.element_tree.root.contains_element_id(target) {
      self.animfocus.pointer_captures.remove(id)
    }
  }
}

///|
/// Dispatch a keyboard event to the registered dismissal layers, top-most
/// first. Returns true when a layer consumed the event.
fn RuntimeState::dispatch_dismissal_layers(
  self : RuntimeState,
  event : KeyboardEvent,
) -> Bool {
  let mut consumed = false
  let mut index = self.layer_stack.length() - 1
  let layout = self.layout_tree_for_input()
  while index >= 0 {
    if !consumed {
      let result = self.element_tree.root.dispatch_keyboard(
        self.layer_stack[index],
        event,
        layout~,
        environment=self.environment,
        text_system=self.text_system,
      )
      if result.changed || result.activated {
        self.dirty.needs_redraw = self.dirty.needs_redraw || result.changed
        self.dirty.needs_paint = self.dirty.needs_paint || result.changed
        self.dirty.needs_rebuild = self.dirty.needs_rebuild || result.activated
        self.mark_current_dirty_elements()
        self.deliver_messages(result.deliveries)
        consumed = true
      }
    }
    index = index - 1
  }
  consumed
}
