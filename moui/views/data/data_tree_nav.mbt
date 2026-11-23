///|
/// What a tree key press asks the app to do to the active row. MoUI computes
/// the target row; the app owns the active id and moves focus itself, so the
/// tree stays a pure function of the app's state.
#derive(Eq, Debug, ToJson)
pub enum TreeNavigationEffect {
  /// Move the active row to `id` (ArrowUp/Down, Home/End, or a parent move).
  Focus
  /// Expand `id` (ArrowRight on a collapsed branch).
  Expand
  /// Collapse `id` (ArrowLeft on an expanded branch).
  Collapse
  /// Activate `id` (Enter/Space): open, run or toggle the row's primary action.
  Activate
}

///|
/// The row and the effect resolved from one key press.
#derive(Eq, Debug, ToJson)
pub(all) struct TreeNavigationTarget {
  id : String
  effect : TreeNavigationEffect
}

///|
/// One flattened row: what a keyboard walk over the tree needs, kept separate
/// from the rendered views so the walk can be tested without a runtime.
priv struct TreeVisibleRow {
  id : String
  /// Id of the parent row, or "" for a root. Used by ArrowLeft to step out of
  /// a collapsed branch.
  parent : String
  depth : Int32
  has_children : Bool
  expanded : Bool
}

///|
/// The ids the tree currently shows, in render order (roots first, expanded
/// children right after their parent). Apps drive their active row over this
/// list; collapsed subtrees are absent, so a keyboard walk never lands on a
/// hidden row.
pub fn tree_visible_ids(
  items : Array[TreeItem],
  expanded~ : Array[String],
) -> Array[String] {
  tree_visible_rows(items, expanded~).map(row => row.id)
}

///|
fn tree_visible_rows(
  items : Array[TreeItem],
  expanded~ : Array[String],
) -> Array[TreeVisibleRow] {
  let rows : Array[TreeVisibleRow] = []
  append_tree_visible_rows(rows, items, parent="", depth=0, expanded~)
  rows
}

///|
fn append_tree_visible_rows(
  rows : Array[TreeVisibleRow],
  items : Array[TreeItem],
  parent~ : String,
  depth~ : Int32,
  expanded~ : Array[String],
) -> Unit {
  for item in items {
    let is_expanded = @controls.string_array_contains(expanded, item.id)
    let has_children = item.children.length() > 0
    rows.push({
      id: item.id,
      parent,
      depth,
      has_children,
      expanded: is_expanded,
    })
    if has_children && is_expanded {
      append_tree_visible_rows(
        rows,
        item.children,
        parent=item.id,
        depth=depth + 1,
        expanded~,
      )
    }
  }
}

///|
/// Resolve a key press against the visible rows.
///
/// Bindings (Chrome/VSCode file-tree parity): ArrowDown/ArrowUp move the active
/// row, Home/End jump to the first/last visible row, Enter/Space activate,
/// ArrowRight expands a collapsed branch (or steps into its first child),
/// ArrowLeft collapses an expanded branch (or steps out to the parent). An
/// unknown or empty `active~` starts the walk at the first row. The caller
/// applies the effect, so nothing here depends on runtime state.
pub fn tree_navigation_target(
  event : @core.KeyboardEvent,
  items : Array[TreeItem],
  expanded~ : Array[String],
  active~ : String,
) -> TreeNavigationTarget? {
  // Auto-repeat is fine for held arrows, so only key-up releases are ignored.
  if !event.pressed {
    return None
  }
  let rows = tree_visible_rows(items, expanded~)
  if rows.length() == 0 {
    return None
  }
  let key = if event.key != "" { event.key } else { event.code }
  let found = find_tree_row_index(rows, active)
  match key {
    "ArrowDown" | "Down" => tree_row_at(rows, found + 1)
    "ArrowUp" | "Up" => tree_row_at(rows, found - 1)
    "Home" => tree_row_at(rows, 0)
    "End" => tree_row_at(rows, rows.length() - 1)
    "Enter" | "Space" | " " => activate_tree_row(rows, found)
    "ArrowLeft" | "Left" => tree_left_target(rows, found)
    "ArrowRight" | "Right" => tree_right_target(rows, found)
    _ => None
  }
}

///|
fn find_tree_row_index(rows : Array[TreeVisibleRow], id : String) -> Int32 {
  for i = 0; i < rows.length(); i = i + 1 {
    if rows[i].id == id {
      return i
    }
  }
  -1
}

///|
fn tree_row_at(
  rows : Array[TreeVisibleRow],
  index : Int32,
) -> TreeNavigationTarget? {
  if index < 0 || index >= rows.length() {
    None
  } else {
    Some({ id: rows[index].id, effect: Focus, })
  }
}

///|
fn activate_tree_row(
  rows : Array[TreeVisibleRow],
  index : Int32,
) -> TreeNavigationTarget? {
  if index < 0 || index >= rows.length() {
    None
  } else {
    Some({ id: rows[index].id, effect: Activate, })
  }
}

///|
fn tree_left_target(
  rows : Array[TreeVisibleRow],
  index : Int32,
) -> TreeNavigationTarget? {
  if index < 0 || index >= rows.length() {
    return None
  }
  let row = rows[index]
  if row.has_children && row.expanded {
    // An open branch collapses before the walk steps out to its parent, the
    // way a file tree's Left key folds the folder under the cursor.
    Some({ id: row.id, effect: Collapse, })
  } else if row.parent != "" {
    Some({ id: row.parent, effect: Focus, })
  } else {
    None
  }
}

///|
fn tree_right_target(
  rows : Array[TreeVisibleRow],
  index : Int32,
) -> TreeNavigationTarget? {
  if index < 0 || index >= rows.length() {
    return None
  }
  let row = rows[index]
  if row.has_children && !row.expanded {
    Some({ id: row.id, effect: Expand, })
  } else if index + 1 < rows.length() && rows[index + 1].depth > row.depth {
    Some({ id: rows[index + 1].id, effect: Focus, })
  } else {
    None
  }
}
