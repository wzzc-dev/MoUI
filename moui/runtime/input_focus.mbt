///|
fn ElementNode::find_focusable_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  if (self.virtual_node.focusable)() && render.hit_bounds().contains(point) {
    Some(self.id)
  } else {
    let mut index = self.children.length() - 1
    while index >= 0 {
      if index < render.children.length() &&
        render.children[index].hit_bounds().contains(point) {
        match
          self.children[index].find_focusable_at(point, render.children[index]) {
          Some(id) => return Some(id)
          None => ()
        }
      }
      index = index - 1
    }
    None
  }
}

///|
fn ElementNode::focusable_ids(
  self : ElementNode,
  ids : Array[ElementId],
) -> Unit {
  if (self.virtual_node.focusable)() {
    ids.push(self.id)
  }
  for child in self.children {
    child.focusable_ids(ids)
  }
}

///|
fn ElementNode::focusable_key_target(
  self : ElementNode,
  key : String,
) -> ElementId? {
  if self.key == Some(Key::new(key)) {
    self.first_focusable_descendant()
  } else {
    for child in self.children {
      match child.focusable_key_target(key) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementNode::first_focusable_descendant(self : ElementNode) -> ElementId? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  if ids.length() == 0 {
    None
  } else {
    Some(ids[0])
  }
}

///|
fn ElementNode::contains_element_id(
  self : ElementNode,
  target : ElementId,
) -> Bool {
  if self.id == target {
    true
  } else {
    for child in self.children {
      if child.contains_element_id(target) {
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::active_focus_trap(
  self : ElementNode,
  current~ : ElementId?,
) -> ElementNode? {
  ignore(current)
  None
}

///|
fn ElementNode::accepts_tab_input(
  self : ElementNode,
  target : ElementId,
) -> Bool {
  if self.id == target {
    self.virtual_node_accepts_text_input(self.virtual_node)
  } else {
    for child in self.children {
      if child.accepts_tab_input(target) {
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::is_text_input_target(
  self : ElementNode,
  target : ElementId,
) -> Bool {
  if self.id == target {
    self.virtual_node_accepts_text_input(self.virtual_node)
  } else {
    for child in self.children {
      if child.is_text_input_target(target) {
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::virtual_node_accepts_text_input(
  self : ElementNode,
  data : VirtualNode,
) -> Bool {
  (data.text_input_state)({
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_frames: [],
    focused: true,
    state: { ..data.state, focused: true },
    text_control: self.control.text_context(),
    environment: Environment::neutral(),
    text_system: TextSystem::fallback(),
  })
  is Some(_)
}

///|
fn ElementNode::next_focus_in_scope(
  self : ElementNode,
  current~ : ElementId?,
  reverse~ : Bool,
) -> ElementId? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  if ids.length() == 0 {
    None
  } else {
    let mut index = -1
    match current {
      Some(current) =>
        for i, id in ids {
          if id == current {
            index = i
          }
        }
      None => ()
    }
    if reverse {
      let next = if index <= 0 { ids.length() - 1 } else { index - 1 }
      Some(ids[next])
    } else {
      let next = if index < 0 || index + 1 >= ids.length() {
        0
      } else {
        index + 1
      }
      Some(ids[next])
    }
  }
}

///|
fn ElementNode::next_focus(
  self : ElementNode,
  current~ : ElementId?,
  reverse~ : Bool,
) -> ElementId? {
  match self.active_focus_trap(current~) {
    Some(scope) => scope.next_focus_in_scope(current~, reverse~)
    None => self.next_focus_in_scope(current~, reverse~)
  }
}

///|
fn ElementNode::constrained_focus_target(
  self : ElementNode,
  requested : ElementId?,
  current~ : ElementId?,
) -> ElementId? {
  match self.active_focus_trap(current~) {
    Some(scope) =>
      match requested {
        Some(id) =>
          if scope.contains_element_id(id) {
            Some(id)
          } else {
            scope.next_focus_in_scope(current~, reverse=false)
          }
        None => None
      }
    None => requested
  }
}
