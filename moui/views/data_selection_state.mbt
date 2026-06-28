///|
pub struct SelectionState {
  selected : Array[String]
}

///|
pub struct SelectableListItem[Msg] {
  id : String
  title : String
  subtitle : String
  detail : String
  message : Msg
  enabled : Bool
}

///|
pub fn SelectionState::new(selected? : Array[String] = []) -> SelectionState {
  { selected: selected.copy() }
}

///|
pub fn SelectionState::contains(self : SelectionState, id : String) -> Bool {
  string_array_contains(self.selected, id)
}

///|
pub fn SelectionState::toggle(
  self : SelectionState,
  id : String,
) -> SelectionState {
  { selected: toggle_string_selected(self.selected, id) }
}

///|
pub fn SelectionState::count(self : SelectionState) -> Int {
  self.selected.length()
}

///|
pub fn[Msg] SelectableListItem::new(
  id~ : String,
  title~ : String,
  message~ : Msg,
  subtitle? : String = "",
  detail? : String = "",
  enabled? : Bool = true,
) -> SelectableListItem[Msg] {
  { id, title, subtitle, detail, message, enabled }
}

///|
pub fn[Msg] selectable_list_item(
  id~ : String,
  title~ : String,
  message~ : Msg,
  subtitle? : String = "",
  detail? : String = "",
  enabled? : Bool = true,
) -> SelectableListItem[Msg] {
  SelectableListItem::new(id~, title~, message~, subtitle~, detail~, enabled~)
}

///|
fn set_string_selected(
  selected : Array[String],
  id : String,
  enabled : Bool,
) -> Array[String] {
  if enabled {
    if string_array_contains(selected, id) {
      selected.copy()
    } else {
      let next = selected.copy()
      next.push(id)
      next
    }
  } else {
    selected.filter(item => item != id)
  }
}

///|
fn toggle_string_selected(
  selected : Array[String],
  id : String,
) -> Array[String] {
  set_string_selected(selected, id, !string_array_contains(selected, id))
}
