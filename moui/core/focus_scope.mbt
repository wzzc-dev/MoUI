///|
pub(all) enum FocusTraversalDirection {
  Next
  Previous
} derive(Eq, Debug, ToJson)

///|
struct FocusScopeItem {
  id : String
  enabled : Bool
  focusable : Bool
} derive(Eq, Debug, ToJson)

///|
struct FocusScope {
  items : Array[FocusScopeItem]
  current : String?
  wrap : Bool
  default_action : String
  dismiss_action : String
} derive(Eq, Debug, ToJson)

///|
pub fn FocusScopeItem::new(
  id~ : String,
  enabled? : Bool = true,
  focusable? : Bool = true,
) -> FocusScopeItem {
  { id, enabled, focusable }
}

///|
pub fn FocusScope::new(
  items~ : Array[FocusScopeItem],
  current? : String? = None,
  wrap? : Bool = true,
  default_action? : String = "",
  dismiss_action? : String = "",
) -> FocusScope {
  { items, current, wrap, default_action, dismiss_action }
}

///|
pub fn FocusScope::first_focusable(self : FocusScope) -> String? {
  for item in self.items {
    if item.enabled && item.focusable {
      return Some(item.id)
    }
  }
  None
}

///|
pub fn FocusScope::last_focusable(self : FocusScope) -> String? {
  let ids = self.focusable_ids()
  if ids.length() == 0 {
    None
  } else {
    Some(ids[ids.length() - 1])
  }
}

///|
pub fn FocusScope::next(self : FocusScope) -> String? {
  self.traverse(FocusTraversalDirection::Next)
}

///|
pub fn FocusScope::previous(self : FocusScope) -> String? {
  self.traverse(FocusTraversalDirection::Previous)
}

///|
pub fn FocusScope::traverse(
  self : FocusScope,
  direction : FocusTraversalDirection,
) -> String? {
  let ids = self.focusable_ids()
  if ids.length() == 0 {
    return None
  }
  let mut index = -1
  match self.current {
    Some(current) =>
      for candidate_index, id in ids {
        if id == current {
          index = candidate_index
        }
      }
    None => ()
  }
  match direction {
    Next => {
      let next = if index < 0 {
        0
      } else if index + 1 < ids.length() {
        index + 1
      } else if self.wrap {
        0
      } else {
        index
      }
      Some(ids[next])
    }
    Previous => {
      let previous = if index < 0 {
        ids.length() - 1
      } else if index > 0 {
        index - 1
      } else if self.wrap {
        ids.length() - 1
      } else {
        index
      }
      Some(ids[previous])
    }
  }
}

///|
pub fn FocusScope::focus_first_invalid(
  self : FocusScope,
  summary : FormValidationSummary,
) -> String? {
  match summary.first_invalid_id {
    Some(id) =>
      if self.contains_focusable(id) {
        Some(id)
      } else {
        self.first_focusable()
      }
    None => self.current
  }
}

///|
pub fn FocusScope::command_target(
  self : FocusScope,
  intent : CommandIntent,
) -> String? {
  match intent {
    Submit | Activate =>
      if self.default_action == "" {
        None
      } else {
        Some(self.default_action)
      }
    Cancel =>
      if self.dismiss_action == "" {
        None
      } else {
        Some(self.dismiss_action)
      }
    _ => None
  }
}

///|
pub fn focus_scope_command_intent(event : KeyboardEvent) -> CommandIntent? {
  if !event.pressed {
    None
  } else if event.key == "Enter" {
    Some(CommandIntent::Submit)
  } else if event.key == "Escape" {
    Some(CommandIntent::Cancel)
  } else {
    None
  }
}

///|
fn FocusScope::focusable_ids(self : FocusScope) -> Array[String] {
  let ids : Array[String] = []
  for item in self.items {
    if item.enabled && item.focusable {
      ids.push(item.id)
    }
  }
  ids
}

///|
fn FocusScope::contains_focusable(self : FocusScope, id : String) -> Bool {
  for item in self.items {
    if item.id == id && item.enabled && item.focusable {
      return true
    }
  }
  false
}
