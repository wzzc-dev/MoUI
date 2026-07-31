// Popover/sheet state types. These live here so popover/ can reference them
// without importing the parent package (which would be circular). Re-exported
// by the root facade.

///|
pub(all) enum PopoverPlacement {
  BottomStart
  BottomEnd
  TopStart
  TopEnd
} derive(Eq, Debug)

///|
pub struct DropdownState {
  expanded : Bool
  selected : String
}

///|
pub fn DropdownState::new(
  expanded? : Bool = false,
  selected? : String = "",
) -> DropdownState {
  { expanded, selected }
}

// === Enum to_string() methods ===
// Stable string contracts mirroring Flutter enum.name and Swift String-backed
// enums. Naming convention: snake_case.

///|
pub fn PopoverPlacement::to_string(self : PopoverPlacement) -> String {
  match self {
    BottomStart => "bottom_start"
    BottomEnd => "bottom_end"
    TopStart => "top_start"
    TopEnd => "top_end"
  }
}
