///|
/// Resolve a key press into the next highlighted command index.
///
/// Bindings: ArrowDown/ArrowUp step, Home/End jump to the ends. `wrap` keeps
/// the step inside the list (ArrowUp from the first row lands on the last);
/// `wrap=false` stops at the ends. Section titles are not counted, so `count`
/// is the flattened command count and `active=-1` means nothing is highlighted.
/// `None` means the key is not a navigation key, or there is nowhere to go.
pub fn command_menu_navigation_index(
  event : @core.KeyboardEvent,
  count : Int32,
  active~ : Int32 = -1,
  wrap~ : Bool = true,
) -> Int32? {
  if !event.pressed || count <= 0 {
    return None
  }
  let key = if event.key != "" { event.key } else { event.code }
  let last = count - 1
  match key {
    "ArrowDown" | "Down" =>
      if active < 0 || active >= last {
        if wrap {
          Some(0)
        } else {
          None
        }
      } else {
        Some(active + 1)
      }
    "ArrowUp" | "Up" =>
      if active < 0 {
        Some(last)
      } else if active == 0 {
        if wrap {
          Some(last)
        } else {
          None
        }
      } else {
        Some(active - 1)
      }
    "Home" => Some(0)
    "End" => Some(last)
    _ => None
  }
}

///|
/// Type-ahead match: the next label starting with the typed character,
/// searching forward from the highlighted row and wrapping around the list.
///
/// Only single printable characters participate — arrows, Tab and modifiers
/// are left to `command_menu_navigation_index` — and matching is
/// case-insensitive by lowercasing both sides.
pub fn command_menu_type_ahead_match(
  event : @core.KeyboardEvent,
  labels : Array[String],
  active~ : Int32 = -1,
) -> Int32? {
  let count = labels.length()
  if !event.pressed || count == 0 {
    return None
  }
  let typed = match event.text {
    Some(text) => text
    None => event.key
  }
  if typed.to_array().length() != 1 {
    return None
  }
  let needle = typed.to_lower()
  let start = if active >= 0 && active < count { active + 1 } else { 0 }
  for offset = 0; offset < count; offset = offset + 1 {
    let index = (start + offset) % count
    if labels[index].to_lower().has_prefix(needle) {
      return Some(index)
    }
  }
  None
}
