///|
/// Locate the top-most focusable element under `point`.
///
/// Child order matches pointer dispatch: hoisted overlay subtrees (control
/// popups, presentations) are searched first top-most-first, then remaining
/// in-flow siblings by paint bounds. Without the overlay prepass, a later
/// sibling whose layout frame sits under a floating popup (e.g. playground
/// editor under the examples picker) would steal focus on Pointer Down even
/// though pointer events correctly hit the popup.
fn ElementNode::find_focusable_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  let search_order : Array[Int] = []
  let mut overlay_search = render.children.length() - 1
  while overlay_search >= 0 {
    if overlay_search < self.children.length() &&
      render.children[overlay_search].is_overlay_child &&
      render.children[overlay_search].hit_bounds().contains(point) {
      search_order.push(overlay_search)
    } else if overlay_search < self.children.length() &&
      render.children[overlay_search].subtree_overlay_contains(point) {
      search_order.push(overlay_search)
    }
    overlay_search = overlay_search - 1
  }
  let mut regular_index = self.children.length() - 1
  while regular_index >= 0 {
    if regular_index < render.children.length() &&
      !render.children[regular_index].is_overlay_child {
      search_order.push(regular_index)
    }
    regular_index = regular_index - 1
  }
  for index in search_order {
    if index < render.children.length() {
      let child_render = render.children[index]
      let is_overlay_owner = render.children[index].is_overlay_child ||
        render.children[index].subtree_overlay_contains(point)
      let hit = is_overlay_owner || child_render.hit_bounds().contains(point)
      if hit {
        match self.children[index].find_focusable_at(point, child_render) {
          Some(id) => return Some(id)
          None => ()
        }
      }
    }
  }
  if self.view_node.focusable() && render.hit_bounds().contains(point) {
    Some(self.id)
  } else {
    None
  }
}

///|
fn ElementNode::focusable_ids(
  self : ElementNode,
  ids : Array[ElementId],
) -> Unit {
  if self.view_node.focusable() {
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
fn ElementNode::focusable_semantic_target(
  self : ElementNode,
  semantic_id : SemanticId,
) -> ElementId? {
  if self.view_node.semantics().semantic_id == Some(semantic_id) {
    self.first_focusable_descendant()
  } else {
    for child in self.children {
      match child.focusable_semantic_target(semantic_id) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementNode::stable_focus_identity(
  self : ElementNode,
  target : ElementId,
  inherited_key : String?,
  inherited_semantic_id : SemanticId?,
) -> (String?, SemanticId?)? {
  let key = match self.key {
    Some(value) => Some(value.value())
    None => inherited_key
  }
  let semantic_id = match self.view_node.semantics().semantic_id {
    Some(value) => Some(value)
    None => inherited_semantic_id
  }
  if self.id == target {
    Some((key, semantic_id))
  } else {
    for child in self.children {
      match child.stable_focus_identity(target, key, semantic_id) {
        Some(identity) => return Some(identity)
        None => ()
      }
    }
    None
  }
}

///|
fn ElementNode::focusable_order(self : ElementNode, target : ElementId) -> Int? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  for index, id in ids {
    if id == target {
      return Some(index)
    }
  }
  None
}

///|
fn ElementNode::focusable_at_order(
  self : ElementNode,
  order : Int,
) -> ElementId? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  if ids.is_empty() {
    None
  } else {
    Some(ids[order.clamp(min=0, max=ids.length() - 1)])
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
  let mut index = self.children.length() - 1
  while index >= 0 {
    match self.children[index].active_focus_trap(current~) {
      Some(scope) => return Some(scope)
      None => ()
    }
    index = index - 1
  }
  if self.view_node.focus_trap() {
    Some(self)
  } else {
    None
  }
}

///|
fn RuntimeState::capture_focus_restore_candidate_before_rebuild(
  self : RuntimeState,
) -> Unit {
  if self.animfocus.active_focus_trap is Some(_) {
    return
  }
  match self.animfocus.focused_element {
    Some(focused) => {
      match self.element_tree.root.stable_focus_identity(focused, None, None) {
        Some((key, semantic_id)) => {
          self.animfocus.saved_focus_key = key
          self.animfocus.saved_focus_semantic_id = semantic_id
        }
        None => {
          self.animfocus.saved_focus_key = None
          self.animfocus.saved_focus_semantic_id = None
        }
      }
      self.animfocus.saved_focus_order = self.element_tree.root.focusable_order(
        focused,
      )
    }
    None => {
      self.animfocus.saved_focus_key = None
      self.animfocus.saved_focus_semantic_id = None
      self.animfocus.saved_focus_order = None
    }
  }
}

///|
fn RuntimeState::sync_focus_trap_after_rebuild(self : RuntimeState) -> Unit {
  let previous_trap = self.animfocus.active_focus_trap
  let next_scope = self.element_tree.root.active_focus_trap(
    current=self.animfocus.focused_element,
  )
  let next_trap = next_scope.map(scope => scope.id)
  if previous_trap == next_trap {
    match (next_scope, self.animfocus.focused_element) {
      (Some(scope), Some(focused)) =>
        if !scope.contains_element_id(focused) {
          ignore(self.commit_focus(scope.first_focusable_descendant()))
        }
      _ => ()
    }
    return
  }
  match (previous_trap, next_scope) {
    (None, Some(scope)) => {
      self.animfocus.active_focus_trap = Some(scope.id)
      ignore(self.commit_focus(scope.first_focusable_descendant()))
    }
    (Some(_), None) => {
      let mut restored : ElementId? = None
      match self.animfocus.saved_focus_key {
        Some(key) => restored = self.element_tree.root.focusable_key_target(key)
        None => ()
      }
      if restored is None {
        match self.animfocus.saved_focus_semantic_id {
          Some(id) =>
            restored = self.element_tree.root.focusable_semantic_target(id)
          None => ()
        }
      }
      if restored is None {
        match self.animfocus.saved_focus_order {
          Some(order) =>
            restored = self.element_tree.root.focusable_at_order(order)
          None => ()
        }
      }
      self.animfocus.active_focus_trap = None
      self.animfocus.saved_focus_key = None
      self.animfocus.saved_focus_semantic_id = None
      self.animfocus.saved_focus_order = None
      ignore(self.commit_focus(restored))
    }
    (Some(_), Some(scope)) => {
      self.animfocus.active_focus_trap = Some(scope.id)
      ignore(self.commit_focus(scope.first_focusable_descendant()))
    }
    (None, None) => ()
  }
}

///|
fn ElementNode::accepts_tab_input(
  self : ElementNode,
  target : ElementId,
) -> Bool {
  if self.id == target {
    self.view_accepts_text_input(self.view_node)
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
fn ElementNode::view_accepts_text_input(
  self : ElementNode,
  data : &RuntimeViewNode,
) -> Bool {
  data.text_input_state({
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_frames: [],
    focused: true,
    state: self.control.view_context(true),
    text_control: self.control.text_context(),
    environment: Environment::neutral(),
    style: ViewStyle::empty(),
    text_system: TextSystem::fallback(),
    now_ms: 0.0,
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
