///|
/// Which pane owns the arrow keys and the pane-highlight. `Tab`/`Shift-Tab` and
/// `ArrowLeft`/`ArrowRight` move this field.
///
/// `FilterPane` is a *routing* pane, not a text cursor: the runtime's own focus
/// chain is separate (see `app_test.mbt`), so typing reaches the field only once
/// the field has been clicked. Keeping it in the cycle is what lets the key-help
/// line and the border colour say "now keys type, they do not command".
pub(all) enum Pane {
  LayersPane
  FilesPane
  FilterPane
} derive(Eq, Debug)

///|
pub extend Pane with Debug::{to_repr}

///|
pub extend Pane with Eq::{not_equal, equal}

///|
pub(all) struct Layer {
  id : String
  name : String
  visible : Bool
} derive(Eq, Debug)

///|
pub extend Layer with Debug::{to_repr}

///|
pub extend Layer with Eq::{not_equal, equal}

///|
pub(all) enum Msg {
  CyclePane(Int)
  Move(Int)
  SelectLayer(String)
  ToggleLayer(String)
  ToggleFocused
  SetFilter(String)
  SetOnlyVisible(Bool)
  AddLayer
  RemoveLayer
  SelectNode(String)
  ToggleNode(String)
  AddNode
  SetScroll(Pane, Double)
  ScrollBy(Pane, Double)
}

///|
pub struct Model {
  layers : Array[Layer]
  selected_layer : String
  filter : String
  only_visible : Bool
  tree : Array[Node]
  expanded : Array[String]
  selected_node : String
  pane : Pane
  layer_scroll : Double
  tree_scroll : Double
  serial : Int
}

///|
/// App-side mirror of `@views.TreeItem`: that value type carries no `Eq`/`Debug`,
/// and the model has to stay printable in tests.
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
/// A `selectable_list` row is 36px of content (24px title plus 6px padding on each
/// side) and the list lays rows out at `row_height + 4`, while it sizes its own box
/// from `row_height` alone. Anything below 36 is therefore a lie: the box comes out
/// shorter than the rows inside it, the scroll viewport is sized from that
/// under-report, and the rows below the fold stop being clickable. 40 is the
/// smallest value that is both its own real height and the pitch the rows get.
pub let row_height : Double = 40.0

///|
pub let layer_width : Double = 168.0

///|
pub let tree_width : Double = 160.0

///|
pub let scroll_line : Double = 16.0

///|
pub let pane_spacing : Double = 8.0

///|
/// Eight layers, not a taste choice: the filter proofs need a list longer than
/// one keystroke can collapse to zero rows, and the scroll proof needs a list
/// taller than its own viewport. The names are chosen so the typed needle walks
/// the visible count in clearly separate steps — `s` leaves 6, `st` leaves 2
/// (Strokes, Streamlines), `stro` leaves 1 — so each keystroke that reached the
/// model is separately readable from the status line.
pub fn Model::new() -> Model {
  let layers = [
    { id: "l-bg", name: "Background", visible: true, },
    { id: "l-grid", name: "Grid", visible: true, },
    { id: "l-stroke", name: "Strokes", visible: true, },
    { id: "l-stream", name: "Streamlines", visible: true, },
    { id: "l-fill", name: "Fills", visible: false, },
    { id: "l-guide", name: "Guides", visible: false, },
    { id: "l-label", name: "Labels", visible: true, },
    { id: "l-shadow", name: "Shadows", visible: true, },
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
    node(id="examples", label="examples", children=[
      node(id="examples/tui_split", label="tui_split"),
      node(id="examples/tui_layers", label="tui_layers"),
    ]),
    node(id="moon.mod", label="moon.mod"),
  ]
  {
    layers,
    selected_layer: "l-bg",
    filter: "",
    only_visible: false,
    tree,
    // Every folder starts open so both panes overflow their own viewport: a
    // scroll proof on a list that fits is vacuously true.
    expanded: ["src", "src/core", "src/runtime", "examples"],
    selected_node: "src",
    pane: LayersPane,
    layer_scroll: 0.0,
    tree_scroll: 0.0,
    serial: 0,
  }
}

///|
pub fn Model::update(self : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  let next = match msg {
    CyclePane(step) => { ..self, pane: cycle_pane(self.pane, step), }
    Move(step) =>
      if self.pane == FilesPane {
        self.move_node(step)
      } else {
        self.move_layer(step)
      }
    SelectLayer(id) => { ..self, pane: LayersPane, selected_layer: id, }
    ToggleLayer(id) =>
      {
        ..self.update_layer_visibility(id),
        pane: LayersPane,
        selected_layer: id,
      }
    ToggleFocused =>
      if self.pane == FilesPane {
        { ..self, expanded: toggle_id(self.expanded, self.selected_node), }
      } else {
        self.update_layer_visibility(self.selected_layer)
      }
    SetFilter(text) =>
      // A keystroke reaching the field is the evidence that the field is being
      // typed into, which is what releases the Space/Enter command claims.
      { ..self, filter: text, pane: FilterPane, }
    SetOnlyVisible(value) => { ..self, only_visible: value, }
    AddLayer => self.add_layer()
    RemoveLayer => self.remove_layer()
    SelectNode(id) => { ..self, pane: FilesPane, selected_node: id, }
    ToggleNode(id) =>
      {
        ..self,
        pane: FilesPane,
        selected_node: id,
        expanded: toggle_id(self.expanded, id),
      }
    AddNode =>
      {
        ..self,
        tree: [node(id="new-\{self.serial}", label="new-\{self.serial}")] +
        self.tree,
        serial: self.serial + 1,
      }
    SetScroll(FilesPane, y) => { ..self, tree_scroll: clamp_scroll(y), }
    SetScroll(pane, y) =>
      if pane == LayersPane {
        { ..self, layer_scroll: clamp_scroll(y), }
      } else {
        // The filter box has no viewport to scroll; its own `Move` routing stays.
        self
      }
    ScrollBy(FilesPane, delta) =>
      { ..self, tree_scroll: clamp_scroll(self.tree_scroll + delta), }
    ScrollBy(LayersPane, delta) =>
      { ..self, layer_scroll: clamp_scroll(self.layer_scroll + delta), }
    ScrollBy(FilterPane, _) => self
  }
  (next, @moui.Effect::none())
}

///|
fn Model::update_layer_visibility(self : Model, id : String) -> Model {
  {
    ..self,
    layers: self.layers.map(layer => {
      if layer.id == id {
        { ..layer, visible: !layer.visible, }
      } else {
        layer
      }
    }),
  }
}

///|
/// Three panes, so a step wraps instead of flipping. `Tab` and `Shift-Tab` are
/// the same command with a sign, which keeps the binding list honest about what
/// the keyboard actually does.
pub fn cycle_pane(pane : Pane, step : Int) -> Pane {
  let order = [LayersPane, FilesPane, FilterPane]
  let index = index_of_pane(pane)
  if step == 0 || index < 0 {
    return pane
  }
  let count = order.length()
  // MoonBit's `%` follows the dividend, so normalise before indexing.
  let next = ((index + step) % count + count) % count
  order[next]
}

///|
fn index_of_pane(pane : Pane) -> Int {
  match pane {
    LayersPane => 0
    FilesPane => 1
    FilterPane => 2
  }
}

///|
pub fn pane_name(pane : Pane) -> String {
  match pane {
    LayersPane => "layers"
    FilesPane => "files"
    FilterPane => "filter"
  }
}

///|
/// Rows the layer pane actually draws: `only_visible` first, then the substring
/// filter. Matching is case-insensitive so a terminal user never has to shift for
/// `Strokes`. Selection is not filtered, so `hide=` and `rows=` are allowed to
/// disagree in the status line.
pub fn visible_layers(model : Model) -> Array[Layer] {
  let needle = model.filter.to_lower()
  model.layers.filter(layer => {
    (!model.only_visible || layer.visible) &&
    (needle.length() == 0 || layer.name.to_lower().contains(needle))
  })
}

///|
pub fn hidden_count(model : Model) -> Int {
  model.layers.filter(layer => !layer.visible).length()
}

///|
fn Model::move_layer(self : Model, step : Int) -> Model {
  let rows = visible_layers(self)
  if rows.is_empty() {
    return self
  }
  let index = index_where(rows, layer => layer.id == self.selected_layer)
  let from = if index >= 0 { index } else { 0 }
  { ..self, selected_layer: rows[clamp_index(from + step, rows.length())].id, }
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
fn Model::add_layer(self : Model) -> Model {
  let layer = {
    id: "l-new-\{self.serial}",
    name: "Layer \{self.serial}",
    visible: true,
  }
  // Head insert: every existing row shifts down one slot, and selection stays
  // attached to an id rather than to the index the layer happened to sit at.
  { ..self, layers: [layer] + self.layers, serial: self.serial + 1, }
}

///|
fn Model::remove_layer(self : Model) -> Model {
  let rows = visible_layers(self)
  let index = index_where(rows, layer => layer.id == self.selected_layer)
  let layers : Array[Layer] = []
  for layer in self.layers {
    if layer.id != self.selected_layer {
      layers.push(layer)
    }
  }
  let selected_layer = if layers.is_empty() {
    ""
  } else if index < 0 {
    layers[0].id
  } else {
    layers[clamp_index(index, layers.length())].id
  }
  { ..self, layers, selected_layer, }
}

///|
pub fn selected_layer_name(model : Model) -> String {
  match
    model.layers.iter().find_first(layer => layer.id == model.selected_layer) {
    Some(layer) => layer.name
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
/// Layer rows are drawn from a filtered list, so the same id has to be found in
/// whatever rows exist right now rather than in the full array.
pub fn layer_marker(model : Model, id : String) -> String {
  match model.layers.iter().find_first(layer => layer.id == id) {
    Some(layer) => if layer.visible { "[x]" } else { "[ ]" }
    None => "[?]"
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
/// children when expanded. Selection steps through this list, so a collapsed
/// subtree is skipped exactly like it is hidden.
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
fn toggle_id(ids : Array[String], id : String) -> Array[String] {
  if contains_id(ids, id) {
    ids.filter(value => value != id)
  } else {
    let out = ids.copy()
    out.push(id)
    out
  }
}

///|
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
