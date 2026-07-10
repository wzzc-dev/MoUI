///|
fn ElementNode::find_node_by_id(
  self : ElementNode,
  target : ElementId,
) -> ElementNode? {
  if self.id == target {
    Some(self)
  } else {
    for child in self.children {
      match child.find_node_by_id(target) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementNode::first_text_input_descendant(self : ElementNode) -> ElementId? {
  if self.view_accepts_text_input(self.erased_view_node) {
    Some(self.id)
  } else {
    for child in self.children {
      match child.first_text_input_descendant() {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
fn semantics_node_by_id(
  node : SemanticsNode,
  target : ElementId,
) -> SemanticsNode? {
  if node.element_id == target {
    Some(node)
  } else {
    for child in node.children {
      match semantics_node_by_id(child, target) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
fn RuntimeState::apply_semantics_event_result(
  self : RuntimeState,
  result : ElementEventResult,
) -> Bool {
  self.needs_redraw = self.needs_redraw || result.changed
  self.needs_rebuild = self.needs_rebuild || result.activated
  self.needs_paint = self.needs_paint || result.changed
  if result.changed || result.activated {
    self.mark_current_dirty_elements()
  }
  if result.activated {
    self.request_activation_rebuild()
  }
  result.changed || result.activated
}

///|
fn RuntimeState::focus_semantics_target(
  self : RuntimeState,
  target : ElementId,
) -> Bool {
  match self.element_tree.root.find_node_by_id(target) {
    Some(node) => {
      let focus_target = Some(
        node.first_focusable_descendant().unwrap_or(target),
      )
      let constrained = self.element_tree.root.constrained_focus_target(
        focus_target,
        current=self.focused_element,
      )
      match constrained {
        Some(id) => {
          let changed = self.focused_element != Some(id)
          self.focused_element = Some(id)
          if changed {
            self.mark_dirty(self.element_tree.id())
          }
          true
        }
        None => false
      }
    }
    None => false
  }
}

///|
fn RuntimeState::activate_semantics_target(
  self : RuntimeState,
  target : ElementId,
) -> Bool {
  match self.element_tree.root.find_node_by_id(target) {
    Some(node) =>
      self.apply_semantics_event_result(
        node.activate_primary(
          environment=self.environment,
          text_system=self.text_system,
        ),
      )
    None => false
  }
}

///|
fn RuntimeState::set_semantics_text(
  self : RuntimeState,
  target : ElementId,
  value : String?,
) -> Bool {
  match (self.element_tree.root.find_node_by_id(target), value) {
    (Some(node), Some(value)) =>
      match node.first_text_input_descendant() {
        Some(text_target) => {
          self.focused_element = Some(text_target)
          ignore(self.dispatch_focused_text_command(CommandIntent::SelectAll))
          self.dispatch_event(TextInput(TextInputEvent::InsertText(value)))
          true
        }
        None => false
      }
    _ => false
  }
}

///|
fn RuntimeState::dispatch_semantics_action(
  self : RuntimeState,
  element_id : ElementId,
  action : SemanticsAction,
  value : String?,
) -> Bool {
  self.ensure_render_tree()
  match semantics_node_by_id(self.cached_semantics(), element_id) {
    Some(node) => {
      if !node.actions.any(exposed => exposed == action) || node.state.disabled {
        return false
      }
      match action {
        Focus => self.focus_semantics_target(element_id)
        SetText => self.set_semantics_text(element_id, value)
        Activate | Submit | Select | Expand | Collapse | Dismiss =>
          self.activate_semantics_target(element_id)
        Scroll => false
      }
    }
    None => false
  }
}

///|
pub fn AppRuntime::dispatch_semantics_action(
  self : AppRuntime,
  element_id : @core.ElementId,
  action : @core.SemanticsAction,
  value? : String? = None,
) -> Bool {
  let handled = self.state.dispatch_semantics_action(element_id, action, value)
  if handled {
    self.state.request_redraw()
  }
  handled
}
