///|
/// White-box coverage for the command-menu keyboard model: the arrow walk with
/// and without wrapping, Home/End, the guards that keep it out of text
/// selection, and the single-character type-ahead match.

///|
fn menu_key(
  key~ : String,
  text~ : String? = None,
  pressed~ : Bool = true,
) -> @core.KeyboardEvent {
  @core.KeyboardEvent::new(key~, text~, pressed~)
}

///|
test "navigation index steps down and lands on the first row" {
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowDown"), 4),
    Some(0),
  )
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowDown"), 4, active=0),
    Some(1),
  )
  assert_eq(
    command_menu_navigation_index(menu_key(key="Down"), 4, active=2),
    Some(3),
  )
}

///|
test "navigation index wraps and stops at the ends" {
  // Wrapping is the default: past the last row, back to the first; before the
  // first row, to the last.
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowDown"), 4, active=3),
    Some(0),
  )
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowUp"), 4, active=-1),
    Some(3),
  )
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowUp"), 4, active=0),
    Some(3),
  )
  // wrap=false keeps the walk inside the list instead of cycling.
  assert_eq(
    command_menu_navigation_index(
      menu_key(key="ArrowDown"),
      4,
      active=3,
      wrap=false,
    ),
    None,
  )
  assert_eq(
    command_menu_navigation_index(
      menu_key(key="ArrowUp"),
      4,
      active=0,
      wrap=false,
    ),
    None,
  )
  assert_eq(
    command_menu_navigation_index(
      menu_key(key="ArrowUp"),
      4,
      active=2,
      wrap=false,
    ),
    Some(1),
  )
}

///|
test "navigation index handles Home End and unknown keys" {
  assert_eq(command_menu_navigation_index(menu_key(key="Home"), 7), Some(0))
  assert_eq(command_menu_navigation_index(menu_key(key="End"), 7), Some(6))
  assert_eq(
    command_menu_navigation_index(menu_key(key="PageDown"), 7, active=2),
    None,
  )
  assert_eq(command_menu_navigation_index(menu_key(key="Enter"), 7), None)
}

///|
test "navigation index ignores release and empty lists" {
  assert_eq(
    command_menu_navigation_index(menu_key(key="ArrowDown", pressed=false), 4),
    None,
  )
  assert_eq(command_menu_navigation_index(menu_key(key="ArrowDown"), 0), None)
  assert_eq(command_menu_navigation_index(menu_key(key="ArrowUp"), -1), None)
  // A host that only reports the physical key still navigates.
  let physical = @core.KeyboardEvent::new(key="", code="ArrowDown")
  assert_eq(command_menu_navigation_index(physical, 3, active=0), Some(1))
}

///|
test "type-ahead matches a prefix and searches forward" {
  let labels = ["Open File", "Open Folder", "Save", "Save All"]
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="o", text=Some("o")), labels),
    Some(0),
  )
  // From the highlighted row the search continues downwards, not from the top.
  assert_eq(
    command_menu_type_ahead_match(
      menu_key(key="o", text=Some("o")),
      labels,
      active=0,
    ),
    Some(1),
  )
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="s", text=Some("s")), labels),
    Some(2),
  )
  // Nothing below the highlight matches, so the search wraps to the top.
  assert_eq(
    command_menu_type_ahead_match(
      menu_key(key="o", text=Some("o")),
      labels,
      active=1,
    ),
    Some(0),
  )
}

///|
test "type-ahead is case-insensitive and prefers text over key" {
  let labels = ["Save"]
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="S", text=Some("S")), labels),
    Some(0),
  )
  // `text` carries the character the user actually typed; `key` may be a
  // physical name such as "KeyS".
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="KeyS", text=Some("s")), labels),
    Some(0),
  )
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="s", text=Some("s")), labels),
    Some(0),
  )
}

///|
test "type-ahead rejects non-printable and multi-character input" {
  let labels = ["Save", "Open"]
  // Navigation keys must stay with the navigation helper.
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="ArrowDown"), labels),
    None,
  )
  // A multi-character `text` (paste, IME commit) is not a type-ahead hit.
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="", text=Some("sa")), labels),
    None,
  )
  assert_eq(
    command_menu_type_ahead_match(
      menu_key(key="s", text=Some("s"), pressed=false),
      labels,
    ),
    None,
  )
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="s", text=Some("s")), []),
    None,
  )
  assert_eq(
    command_menu_type_ahead_match(menu_key(key="z", text=Some("z")), labels),
    None,
  )
}
