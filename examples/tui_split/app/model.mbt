///|
/// Which pane owns the keyboard. `Tab`/`Shift-Tab` and `ArrowLeft`/`ArrowRight`
/// move this field; the arrow keys then act inside it.
pub(all) enum Pane {
  ListPane
  TreePane
} derive(Eq, Debug)

///|
pub extend Pane with Debug::{to_repr}

///|
pub extend Pane with Eq::{not_equal, equal}

///|
pub(all) struct Entry {
  id : String
  title : String
  subtitle : String
}

///|
/// App-side mirror of `@views.TreeItem`: that value type has no `Eq`/`Debug`,
/// and the model must stay printable in tests.
pub(all) struct Node {
  id : String
  label : String
  children : Array[Node]
} derive(Debug)

///|
pub extend Node with Debug::{to_repr}

///|
pub fn node(
  id~ : String,
  label~ : String,
  children? : Array[Node] = [],
) -> Node {
  { id, label, children: children.copy(), }
}

///|
pub(all) enum Msg {
  CyclePane(Int)
  Move(Int)
  SelectEntry(String)
  SelectNode(String)
  ToggleNode(String)
  ToggleFocusedNode
  InsertEntry
  AddNode
  RemoveFocused
  SetScroll(Pane, Double)
  ScrollBy(Pane, Double)
}

///|
pub struct Model {
  entries : Array[Entry]
  selected_entry : String
  pane : Pane
  tree : Array[Node]
  expanded : Array[String]
  selected_node : String
  list_scroll : Double
  tree_scroll : Double
  serial : Int
}

///|
/// One terminal row is 16px in the cell grid, so a list row is two cells tall:
/// a bordered row then holds a title and its subtitle without wrapping.
pub let list_row_height : Double = 32.0

///|
pub let list_width : Double = 336.0

///|
pub let tree_width : Double = 336.0

///|
pub let scroll_line : Double = 16.0

///|
pub let pane_spacing : Double = 8.0

///|

///|
/// Sixteen rows is not a taste choice: the scroll and clipping proofs in
/// `app_test.mbt` only mean something when the list is taller than its own
/// viewport, and a 30-cell terminal window is ~480px of layout height.
pub fn Model::new() -> Model {
  let entries = [
    { id: "e-0", title: "Entry 0", subtitle: "row 0", },
    { id: "e-1", title: "Entry 1", subtitle: "row 1", },
    { id: "e-2", title: "Entry 2", subtitle: "row 2", },
    { id: "e-3", title: "Entry 3", subtitle: "row 3", },
    { id: "e-4", title: "Entry 4", subtitle: "row 4", },
    { id: "e-5", title: "Entry 5", subtitle: "row 5", },
    { id: "e-6", title: "Entry 6", subtitle: "row 6", },
    { id: "e-7", title: "Entry 7", subtitle: "row 7", },
    { id: "e-8", title: "Entry 8", subtitle: "row 8", },
    { id: "e-9", title: "Entry 9", subtitle: "row 9", },
    { id: "e-10", title: "Entry 10", subtitle: "row 10", },
    { id: "e-11", title: "Entry 11", subtitle: "row 11", },
    { id: "e-12", title: "Entry 12", subtitle: "row 12", },
    { id: "e-13", title: "Entry 13", subtitle: "row 13", },
    { id: "e-14", title: "Entry 14", subtitle: "row 14", },
    { id: "e-15", title: "Entry 15", subtitle: "row 15", },
  ]
  let tree = [
    node(id="src", label="src", children=[
      node(id="src/core", label="core", children=[
        node(id="src/core/program.mbt", label="program.mbt"),
        node(id="src/core/view.mbt", label="view.mbt"),
      ]),
      node(id="src/runtime", label="runtime", children=[
        node(id="src/runtime/runtime.mbt", label="runtime.mbt"),
      ]),
    ]),
    node(id="moon.mod", label="moon.mod"),
  ]
  {
    entries,
    selected_entry: "e-0",
    pane: ListPane,
    tree,
    expanded: [
      // Every folder starts open so the tree has enough rows to overflow its own
      // viewport: a scroll test on a tree that fits is vacuously true.
      "src", "src/core", "src/runtime",
    ],
    selected_node: "src",
    list_scroll: 0.0,
    tree_scroll: 0.0,
    serial: 0,
  }
}

///|
pub fn Model::update(self : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  let next = match msg {
    CyclePane(step) => { ..self, pane: cycle_pane(self.pane, step), }
    Move(step) =>
      if self.pane == ListPane {
        self.move_entry(step)
      } else {
        self.move_node(step)
      }
    SelectEntry(id) => { ..self, pane: ListPane, selected_entry: id, }
    SelectNode(id) => { ..self, pane: TreePane, selected_node: id, }
    ToggleNode(id) =>
      {
        ..self,
        pane: TreePane,
        selected_node: id,
        expanded: toggle_id(self.expanded, id),
      }
    ToggleFocusedNode =>
      { ..self, expanded: toggle_id(self.expanded, self.selected_node), }
    InsertEntry => self.insert_entry()
    AddNode => self.add_node()
    RemoveFocused =>
      if self.pane == ListPane {
        self.remove_entry()
      } else {
        self.remove_node()
      }
    SetScroll(ListPane, y) => { ..self, list_scroll: clamp_scroll(y), }
    SetScroll(TreePane, y) => { ..self, tree_scroll: clamp_scroll(y), }
    ScrollBy(ListPane, delta) =>
      { ..self, list_scroll: clamp_scroll(self.list_scroll + delta), }
    ScrollBy(TreePane, delta) =>
      { ..self, tree_scroll: clamp_scroll(self.tree_scroll + delta), }
  }
  (next, @moui.Effect::none())
}

///|
pub fn cycle_pane(pane : Pane, step : Int) -> Pane {
  // Two panes, so any non-zero step flips. Kept as a step so the binding stays
  // right once a third pane exists.
  if step == 0 {
    pane
  } else if pane == ListPane {
    TreePane
  } else {
    ListPane
  }
}

///|
fn Model::move_entry(self : Model, step : Int) -> Model {
  let index = index_where(self.entries, entry => entry.id == self.selected_entry)
  let from = if index >= 0 { index } else { 0 }
  {
    ..self,
    selected_entry: self.entries[clamp_index(from + step, self.entries.length())].id,
  }
}

///|
fn Model::move_node(self : Model, step : Int) -> Model {
  let rows = visible_node_ids(self.tree, self.expanded)
  if rows.is_empty() {
    return self
  }
  let index = index_where(rows, id => id == self.selected_node)
  let from = if index >= 0 { index } else { 0 }
  { ..self, selected_node: rows[clamp_index(from + step, rows.length())], }
}

///|
fn Model::insert_entry(self : Model) -> Model {
  let id = "new-\{self.serial}"
  let entry = { id, title: "New \{self.serial}", subtitle: "inserted", }
  // Inserting at the head shifts every existing row down one slot. Selection is
  // deliberately not recomputed: it has to stay attached to the same entry id,
  // not to the index the entry happened to sit at.
  { ..self, entries: [entry] + self.entries, serial: self.serial + 1, }
}

///|
fn Model::add_node(self : Model) -> Model {
  let serial = self.serial
  {
    ..self,
    tree: [node(id="new-node-\{serial}", label="new-\{serial}")] + self.tree,
    serial: serial + 1,
  }
}

///|
fn Model::remove_entry(self : Model) -> Model {
  let index = index_where(self.entries, entry => entry.id == self.selected_entry)
  if index < 0 {
    return self
  }
  let entries : Array[Entry] = []
  let mut i = 0
  for entry in self.entries {
    if i != index {
      entries.push(entry)
    }
    i = i + 1
  }
  let selected_entry = if entries.is_empty() {
    ""
  } else {
    // Keep the cursor on the row that took the deleted row's slot.
    entries[clamp_index(index, entries.length())].id
  }
  { ..self, entries, selected_entry, }
}

///|
fn Model::remove_node(self : Model) -> Model {
  let rows = visible_node_ids(self.tree, self.expanded)
  let index = index_where(rows, id => id == self.selected_node)
  let removed = self.selected_node
  let tree = remove_node_by_id(self.tree, removed)
  let remaining = visible_node_ids(tree, self.expanded)
  let selected_node = if remaining.is_empty() {
    ""
  } else if index < 0 {
    remaining[0]
  } else {
    remaining[clamp_index(index, remaining.length())]
  }
  {
    ..self,
    tree,
    selected_node,
    // Drop the ids that no longer name a node: the deleted folder took its
    // whole subtree with it, and a stale "src/core" would make a re-created
    // folder open by itself.
    expanded: keep_live_ids(tree, self.expanded),
  }
}

///|
fn keep_live_ids(nodes : Array[Node], ids : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for id in ids {
    match find_node(nodes, id) {
      Some(_) => out.push(id)
      None => ()
    }
  }
  out
}

///|
pub fn selected_entry_title(model : Model) -> String {
  match
    model.entries.iter().find_first(entry => entry.id == model.selected_entry) {
    Some(entry) => entry.title
    None => "-"
  }
}

///|
pub fn selected_node_label(model : Model) -> String {
  match find_node(model.tree, model.selected_node) {
    Some(node) => node.label
    None => "-"
  }
}

///|
pub fn find_node(nodes : Array[Node], id : String) -> Node? {
  for node in nodes {
    if node.id == id {
      return Some(node)
    }
    match find_node(node.children, id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
/// Flattens the tree the way `tree_view` renders it: the node row, then its
/// children when the node is expanded. Selection steps through this list, so a
/// collapsed subtree is skipped exactly like it is hidden.
pub fn visible_node_ids(
  nodes : Array[Node],
  expanded : Array[String],
) -> Array[String] {
  let rows : Array[String] = []
  for node in nodes {
    append_visible_node_ids(rows, node, expanded)
  }
  rows
}

///|
fn append_visible_node_ids(
  rows : Array[String],
  node : Node,
  expanded : Array[String],
) -> Unit {
  rows.push(node.id)
  if contains_id(expanded, node.id) {
    for child in node.children {
      append_visible_node_ids(rows, child, expanded)
    }
  }
}

///|
pub fn to_tree_items(nodes : Array[Node]) -> Array[@views.TreeItem] {
  nodes.map(node => {
    @views.tree_item(
      id=node.id,
      label=node.label,
      children=to_tree_items(node.children),
    )
  })
}

///|
fn contains_id(ids : Array[String], id : String) -> Bool {
  ids.any(value => value == id)
}

///|
/// Slot of the first row satisfying `f`, or -1 when the id is gone. Selection
/// lives in the model as an id, so every move has to translate it back to a
/// position against whatever rows exist right now.
fn[T] index_where(items : Array[T], f : (T) -> Bool) -> Int {
  let mut index = 0
  let mut found = -1
  while index < items.length() && found < 0 {
    if f(items[index]) {
      found = index
    }
    index = index + 1
  }
  found
}

///|
fn toggle_id(ids : Array[String], id : String) -> Array[String] {
  if contains_id(ids, id) {
    remove_id(ids, id)
  } else {
    let out = ids.copy()
    out.push(id)
    out
  }
}

///|
fn remove_id(ids : Array[String], id : String) -> Array[String] {
  let out : Array[String] = []
  for value in ids {
    if value != id {
      out.push(value)
    }
  }
  out
}

///|
fn remove_node_by_id(nodes : Array[Node], id : String) -> Array[Node] {
  let out : Array[Node] = []
  for node in nodes {
    if node.id != id {
      out.push({ ..node, children: remove_node_by_id(node.children, id), })
    }
  }
  out
}

///|
fn clamp_index(index : Int, length : Int) -> Int {
  if length <= 0 {
    0
  } else if index < 0 {
    0
  } else if index >= length {
    length - 1
  } else {
    index
  }
}

///|
fn clamp_scroll(value : Double) -> Double {
  // Only the lower bound is known here: the scroll container clamps against the
  // real viewport, and the app never sees the terminal height.
  if value < 0.0 {
    0.0
  } else {
    value
  }
}
