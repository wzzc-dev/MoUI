///|
pub struct ColumnVisibilityState {
  visible : Array[String]
  locked : Array[String]
}

///|
pub fn ColumnVisibilityState::new(
  visible~ : Array[String],
  locked? : Array[String] = [],
) -> ColumnVisibilityState {
  { visible: visible.copy(), locked: locked.copy() }
}

///|
pub fn ColumnVisibilityState::visible(
  self : ColumnVisibilityState,
) -> Array[String] {
  self.visible.copy()
}

///|
pub fn ColumnVisibilityState::locked(
  self : ColumnVisibilityState,
) -> Array[String] {
  self.locked.copy()
}

///|
pub fn ColumnVisibilityState::is_visible(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.visible, id)
}

///|
fn ColumnVisibilityState::is_locked(
  self : ColumnVisibilityState,
  id : String,
) -> Bool {
  string_array_contains(self.locked, id)
}

///|
pub fn ColumnVisibilityState::set_visible(
  self : ColumnVisibilityState,
  id : String,
  visible : Bool,
) -> ColumnVisibilityState {
  if self.is_locked(id) {
    self
  } else {
    { ..self, visible: set_string_selected(self.visible, id, visible) }
  }
}
