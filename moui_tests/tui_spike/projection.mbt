/// S0 spike: project a committed semantics tree (plus the layout tree) into a
/// character-cell grid and render it as plain text / ANSI.
///
/// This is deliberately a *projection*, not a renderer: it never consumes
/// `DrawCommand`. It reads only `AppRuntime::set_text_system`,
/// `AppRuntime::layout`, `AppRuntime::read_semantics` and counts
/// `AppRuntime::draw_commands`, so the numbers it reports measure how much of a
/// TUI path already exists behind public API.

///|
pub struct CellGrid {
  cols : Int32
  rows : Int32
  chars : Array[Array[Char]]
  attrs : Array[Array[Int32]]
  /// Paint sequence that last wrote each cell (0 = never).
  owners : Array[Array[Int32]]
  /// Priority of each paint sequence: 1 = container chrome, 2 = leaf content.
  prio : Array[Int32]
}

///|
pub struct FrameAudit {
  nodes : Int32
  off_grid_point : Int32
  off_grid_size : Int32
  worst_off_grid_px : Double
} derive(Eq, Debug)

///|
pub extend FrameAudit with Debug::{to_repr}

///|
pub extend FrameAudit with Eq::{not_equal, equal}

///|
pub struct ProjectionReport {
  lines : Array[String]
  plain : String
  ansi : String
  cols : Int32
  rows : Int32
  semantics_nodes : Int32
  layout_nodes : Int32
  draw_commands : Int32
  audit_semantics : FrameAudit
  audit_layout : FrameAudit
  roles : Array[(String, Int32)]
  frames : Array[String]
  offscreen : Int32
}

///|
pub fn new_grid(cols : Int32, rows : Int32) -> CellGrid {
  // Each row needs its own backing array; a nested `Array::make` would alias
  // one row across the whole grid.
  let chars : Array[Array[Char]] = []
  let attrs : Array[Array[Int32]] = []
  let owners : Array[Array[Int32]] = []
  let prio : Array[Int32] = []
  let mut r = 0
  while r < rows {
    chars.push(Array::make(cols, ' '))
    attrs.push(Array::make(cols, 0))
    owners.push(Array::make(cols, 0))
    r = r + 1
  }
  { cols, rows, chars, attrs, owners, prio, }
}

///|
/// Cell ownership is the overlap-repair rule, in three priorities:
///   1 = container chrome (box border)
///   2 = container title text
///   3 = leaf content
/// Higher priority always wins. At equal priority the first paint keeps the
/// cell, so two sibling boxes whose quantized cells overlap cannot interleave
/// their letters.
fn claim(grid : CellGrid, row : Int32, col : Int32, seq : Int32) -> Bool {
  let other = grid.owners[row][col]
  if other == 0 || other == seq {
    true
  } else {
    grid.prio[seq - 1] > grid.prio[other - 1]
  }
}

///|
pub fn new_seq(grid : CellGrid, prio : Int32) -> Int32 {
  let seq = grid.prio.length() + 1
  grid.prio.push(prio)
  seq
}

///|
fn put(
  grid : CellGrid,
  row : Int32,
  col : Int32,
  ch : Char,
  attr : Int32,
  seq : Int32,
) -> Unit {
  if row >= 0 && row < grid.rows && col >= 0 && col < grid.cols {
    if claim(grid, row, col, seq) {
      grid.chars[row][col] = ch
      grid.attrs[row][col] = attr
      grid.owners[row][col] = seq
    }
  }
}

///|
fn write_text(
  grid : CellGrid,
  row : Int32,
  col : Int32,
  text : String,
  attr : Int32,
  seq : Int32,
) -> Unit {
  let mut c = col
  for ch in text {
    if c >= grid.cols {
      break
    }
    put(grid, row, c, ch, attr, seq)
    c = c + 1
  }
}

///|
/// Every paint is clipped to the node's own quantized box and wrapped across
/// that box's rows. Pixel renderers get this for free from `clip_rect`; a cell
/// projection has to do it explicitly or sibling nodes interleave into noise.
priv struct Cursor {
  mut row : Int32
  mut col : Int32
  c0 : Int32
  r1 : Int32
  c1 : Int32
  attr : Int32
  seq : Int32
}

///|
fn advance_cursor(cur : Cursor) -> Bool {
  cur.row = cur.row + 1
  cur.col = cur.c0
  cur.row <= cur.r1
}

///|
fn put_word(grid : CellGrid, cur : Cursor, word : String) -> Bool {
  if cur.col + word.length() - 1 > cur.c1 && !advance_cursor(cur) {
    false
  } else {
    for ch in word {
      if cur.col > cur.c1 {
        break
      }
      put(grid, cur.row, cur.col, ch, cur.attr, cur.seq)
      cur.col = cur.col + 1
    }
    cur.col = cur.col + 1
    true
  }
}

///|
pub fn write_boxed(
  grid : CellGrid,
  r0 : Int32,
  c0 : Int32,
  r1 : Int32,
  c1 : Int32,
  text : String,
  attr : Int32,
  seq : Int32,
) -> Unit {
  let cur : Cursor = { row: r0, col: c0, c0, r1, c1, attr, seq, }
  let mut word = ""
  for ch in text {
    if ch == '\n' {
      if word.length() > 0 && !put_word(grid, cur, word) {
        return
      }
      word = ""
      if !advance_cursor(cur) {
        return
      }
    } else if ch == ' ' {
      if word.length() > 0 && !put_word(grid, cur, word) {
        return
      }
      word = ""
    } else {
      word = word + ch.to_string()
    }
  }
  if word.length() > 0 {
    ignore(put_word(grid, cur, word))
  }
}

///|
pub fn draw_box(
  grid : CellGrid,
  r0 : Int32,
  c0 : Int32,
  r1 : Int32,
  c1 : Int32,
  title : String,
  attr : Int32,
  chrome : Int32,
  label : Int32,
) -> Unit {
  if r1 - r0 < 2 || c1 - c0 < 2 {
    // Too small to frame: still mark presence so the node is not lost.
    put(grid, r0, c0, '~', attr, chrome)
    return
  }
  put(grid, r0, c0, '\u{250c}', attr, chrome)
  put(grid, r0, c1, '\u{2510}', attr, chrome)
  put(grid, r1, c0, '\u{2514}', attr, chrome)
  put(grid, r1, c1, '\u{2518}', attr, chrome)
  let mut c = c0 + 1
  while c < c1 {
    put(grid, r0, c, '\u{2500}', attr, chrome)
    put(grid, r1, c, '\u{2500}', attr, chrome)
    c = c + 1
  }
  let mut r = r0 + 1
  while r < r1 {
    put(grid, r, c0, '\u{2502}', attr, chrome)
    put(grid, r, c1, '\u{2502}', attr, chrome)
    r = r + 1
  }
  if title.length() > 0 {
    write_text(grid, r0, c0 + 1, " " + title, attr, label)
  }
}

///|
let container_roles : Array[String] = [
  "Group", "Row", "List", "ListItem", "Grid", "Main", "Navigation", "Form", "FormField",
  "Table", "Tab", "Menu", "Tree", "TreeItem", "ScrollView", "Dialog", "ButtonGroup",
  "Separator", "Option", "Cell", "Tooltip", "Link",
]

///|
let leaf_roles : Array[String] = [
  "Text", "Status", "Alert", "Heading", "Button", "Checkbox", "Switch", "Radio",
  "TextField", "ComboBox", "Slider", "Progress", "Image", "WebView",
]

///|
fn is_container(role : String) -> Bool {
  container_roles.contains(role)
}

///|
/// Explicit `SemanticsRole` -> TUI tag mapping. This is the table a real
/// `moui_tui_renderer` would need, so it is written as a total match over the
/// enum instead of relying on `Debug` stringification.
fn role_tag(node : @core.SemanticsNode) -> String {
  match node.role {
    @core.Text => "Text"
    @core.Link => "Link"
    @core.Heading => "Heading"
    @core.Navigation => "Navigation"
    @core.Main => "Main"
    @core.Button => "Button"
    @core.Checkbox => "Checkbox"
    @core.TextField => "TextField"
    @core.List => "List"
    @core.ListItem => "ListItem"
    @core.Grid => "Grid"
    @core.ScrollView => "ScrollView"
    @core.Switch => "Switch"
    @core.Radio => "Radio"
    @core.Slider => "Slider"
    @core.Progress => "Progress"
    @core.Tab => "Tab"
    @core.Dialog => "Dialog"
    @core.Tooltip => "Tooltip"
    @core.Menu => "Menu"
    @core.ButtonGroup => "ButtonGroup"
    @core.Form => "Form"
    @core.FormField => "FormField"
    @core.Tree => "Tree"
    @core.TreeItem => "TreeItem"
    @core.Group => "Group"
    @core.WebView => "WebView"
    @core.Image => "Image"
    @core.Alert => "Alert"
    @core.Status => "Status"
    @core.ComboBox => "ComboBox"
    @core.Option => "Option"
    @core.Table => "Table"
    @core.Row => "Row"
    @core.Cell => "Cell"
    @core.Separator => "Separator"
    @core.None => "None"
  }
}

///|
fn node_text(node : @core.SemanticsNode) -> String {
  if node.label.length() > 0 {
    node.label
  } else if node.value.length() > 0 {
    node.value
  } else {
    node.description
  }
}

///|
fn sgr(attr : Int32) -> String {
  if attr == 1 {
    "\u{1b}[36m"
  } else if attr == 2 {
    "\u{1b}[1;34m"
  } else if attr == 3 {
    "\u{1b}[32m"
  } else if attr == 4 {
    "\u{1b}[1;33;4m"
  } else if attr == 5 {
    "\u{1b}[1m"
  } else if attr == 6 {
    "\u{1b}[35m"
  } else {
    "\u{1b}[0m"
  }
}

///|
fn attr_for(node : @core.SemanticsNode, role : String) -> Int32 {
  if node.state.focused {
    4
  } else if role == "Button" {
    2
  } else if role == "Heading" {
    5
  } else if role == "Text" || role == "Status" || role == "Alert" {
    3
  } else {
    let interactive = [
      "TextField", "ComboBox", "Slider", "Progress", "Checkbox", "Switch", "Radio",
    ]
    if interactive.contains(role) {
      6
    } else {
      1
    }
  }
}

///|
fn clamp_int(value : Int32, limit : Int32) -> Int32 {
  if value < 0 {
    0
  } else if value >= limit {
    limit - 1
  } else {
    value
  }
}

///|
fn quantize(
  frame : @core.Rect,
  cell_w : Double,
  cell_h : Double,
  cols : Int32,
  rows : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let c0 = clamp_int((frame.origin.x / cell_w).floor().to_int(), cols)
  let r0 = clamp_int((frame.origin.y / cell_h).floor().to_int(), rows)
  let c1 = clamp_int(
    ((frame.origin.x + frame.size.width) / cell_w).ceil().to_int() - 1,
    cols,
  )
  let r1 = clamp_int(
    ((frame.origin.y + frame.size.height) / cell_h).ceil().to_int() - 1,
    rows,
  )
  (r0, c0, r1, c1)
}

///|
fn off_grid(value : Double, unit : Double) -> Bool {
  let q = value / unit
  (q - q.round()).abs() > 0.001
}

///|
fn audit_frames(
  frames : Array[@core.Rect],
  cell_w : Double,
  cell_h : Double,
) -> FrameAudit {
  let mut off_point = 0
  let mut off_size = 0
  let mut worst = 0.0
  for frame in frames {
    let points = [frame.origin.x, frame.origin.y]
    let units = [cell_w, cell_h]
    let mut i = 0
    while i < 2 {
      if off_grid(points[i], units[i]) {
        off_point = off_point + 1
        let err = (points[i] / units[i]).round()
        let err_px = (points[i] / units[i] - err).abs() * units[i]
        if err_px > worst {
          worst = err_px
        }
      }
      i = i + 1
    }
    if off_grid(frame.size.width, cell_w) || off_grid(frame.size.height, cell_h) {
      off_size = off_size + 1
    }
  }
  {
    nodes: frames.length(),
    off_grid_point: off_point,
    off_grid_size: off_size,
    worst_off_grid_px: worst,
  }
}

///|
fn collect_layout_frames(
  node : @core.LayoutResult,
  out : Array[@core.Rect],
) -> Unit {
  out.push(node.frame)
  for child in node.children {
    collect_layout_frames(child, out)
  }
}

///|
fn layout_count(node : @core.LayoutResult) -> Int32 {
  let mut total = 1
  for child in node.children {
    total = total + layout_count(child)
  }
  total
}

///|
fn index_of(
  nodes : Array[@core.SemanticsNode],
  id : @core.SemanticsNodeId,
) -> Int32? {
  let mut i = 0
  while i < nodes.length() {
    if nodes[i].node_id == id {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Breadth-first order from the root: containers paint before descendants, so a
/// deeper paint overwriting a shallower one is this projection's overlap-repair
/// rule.
fn paint_order(
  nodes : Array[@core.SemanticsNode],
  root : @core.SemanticsNodeId?,
) -> Array[Int32] {
  let order : Array[Int32] = []
  let visited = Array::make(nodes.length(), false)
  let queue : Array[Int32] = []
  match root {
    Some(id) =>
      match index_of(nodes, id) {
        Some(i) => queue.push(i)
        None => ()
      }
    None => ()
  }
  let mut head = 0
  while head < queue.length() {
    let i = queue[head]
    head = head + 1
    if visited[i] {
      continue
    }
    visited[i] = true
    order.push(i)
    for child_id in nodes[i].children {
      match index_of(nodes, child_id) {
        Some(j) => if !visited[j] { queue.push(j) }
        None => ()
      }
    }
  }
  let mut i = 0
  while i < nodes.length() {
    if !visited[i] {
      order.push(i)
    }
    i = i + 1
  }
  order
}

///|
/// Paints one node and reports whether it was on-screen. A frame that lies
/// entirely outside the viewport is dropped, the way a pixel renderer would
/// drop it through `clip_rect`; clamping it instead would fold scrolled-away
/// siblings onto the boundary row.
fn paint_node(
  grid : CellGrid,
  node : @core.SemanticsNode,
  cell_w : Double,
  cell_h : Double,
) -> Bool {
  let vp_w = cell_w * grid.cols.to_double()
  let vp_h = cell_h * grid.rows.to_double()
  let frame = node.frame
  let right = frame.origin.x + frame.size.width
  let bottom = frame.origin.y + frame.size.height
  if right <= 0.0 ||
    bottom <= 0.0 ||
    frame.origin.x >= vp_w ||
    frame.origin.y >= vp_h {
    return false
  }
  let role = role_tag(node)
  let text = node_text(node)
  let attr = attr_for(node, role)
  let (r0, c0, r1, c1) = quantize(frame, cell_w, cell_h, grid.cols, grid.rows)
  let container = is_container(role)
  let seq = new_seq(grid, if container { 1 } else { 3 })
  if role == "Button" {
    write_boxed(grid, r0, c0, r1, c1, "[" + text + "]", attr, seq)
  } else if role == "Image" {
    write_boxed(grid, r0, c0, r1, c1, "[image]", attr, seq)
  } else if role == "WebView" {
    write_boxed(grid, r0, c0, r1, c1, "[web-view]", attr, seq)
  } else if role == "Checkbox" || role == "Switch" || role == "Radio" {
    let mark = if node.state.checked is Some(_) { "(x) " } else { "( ) " }
    write_boxed(grid, r0, c0, r1, c1, mark + text, attr, seq)
  } else if role == "TextField" || role == "ComboBox" {
    write_boxed(grid, r0, c0, r1, c1, text + "|", attr, seq)
  } else if role == "Slider" || role == "Progress" {
    let mut c = c0
    while c <= c1 && c < grid.cols {
      put(grid, r0, c, '\u{2550}', attr, seq)
      c = c + 1
    }
    put(grid, r0, c0 + 1, '>', attr, seq)
  } else if text.length() > 0 && !container {
    write_boxed(grid, r0, c0, r1, c1, text, attr, seq)
  }
  if container {
    let label = new_seq(grid, 2)
    draw_box(grid, r0, c0, r1, c1, text, attr, seq, label)
  } else if leaf_roles.contains(role) && text.length() == 0 {
    put(grid, r0, c0, '?', attr, seq)
  }
  true
}

///|
fn role_histogram(nodes : Array[@core.SemanticsNode]) -> Array[(String, Int32)] {
  let names : Array[String] = []
  let counts : Array[Int32] = []
  for node in nodes {
    let name = role_tag(node)
    let mut i = 0
    let mut found = -1
    while i < names.length() {
      if names[i] == name {
        found = i
        break
      }
      i = i + 1
    }
    if found < 0 {
      names.push(name)
      counts.push(1)
    } else {
      counts[found] = counts[found] + 1
    }
  }
  let out : Array[(String, Int32)] = []
  let mut i = 0
  while i < names.length() {
    out.push((names[i], counts[i]))
    i = i + 1
  }
  out
}

///|
fn trim_line(line : String) -> String {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == ' ' {
    end = end - 1
  }
  let mut out = ""
  let mut i = 0
  while i < end {
    out = out + chars[i].to_string()
    i = i + 1
  }
  out
}

///|
pub fn grid_lines(grid : CellGrid) -> Array[String] {
  let lines : Array[String] = []
  for row in grid.chars {
    let mut s = ""
    for ch in row {
      s = s + ch.to_string()
    }
    lines.push(trim_line(s))
  }
  lines
}

///|
pub fn grid_to_ansi(grid : CellGrid) -> String {
  let lines : Array[String] = []
  let mut r = 0
  while r < grid.rows {
    let mut s = ""
    let mut current = -1
    let mut c = 0
    while c < grid.cols {
      let attr = grid.attrs[r][c]
      if attr != current {
        s = s + sgr(attr)
        current = attr
      }
      s = s + grid.chars[r][c].to_string()
      c = c + 1
    }
    lines.push(s + "\u{1b}[0m")
    r = r + 1
  }
  lines.join("\n")
}

///|
fn snapshot_nodes(
  read : Result[@runtime.SemanticsRead, @runtime.SemanticsReadError],
) -> Array[@core.SemanticsNode] {
  match read {
    Ok(Full(snapshot)) => snapshot.nodes()
    Ok(Delta(delta)) => delta.upserted()
    Ok(Unchanged(_)) => []
    Err(_) => []
  }
}

///|
fn snapshot_root(
  read : Result[@runtime.SemanticsRead, @runtime.SemanticsReadError],
) -> @core.SemanticsNodeId? {
  match read {
    Ok(Full(snapshot)) => snapshot.root()
    _ => None
  }
}

///|
pub fn line_containing(lines : Array[String], needle : String) -> Int32? {
  let mut i = 0
  while i < lines.length() {
    if lines[i].contains(needle) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// True when a grid row carries only blank space and box-drawing chrome, i.e.
/// nothing landed on it as text. Used to prove the boundary row is not a
/// dumping ground for scrolled-away siblings.
pub fn row_is_chrome_only(line : String) -> Bool {
  let chrome = [
    ' ', '\u{2500}', '\u{2502}', '\u{250c}', '\u{2510}', '\u{2514}', '\u{2518}',
    '\u{2550}',
  ]
  let mut clean = true
  for ch in line {
    if !chrome.contains(ch) {
      clean = false
    }
  }
  clean
}

///|
fn audit_text(audit : FrameAudit) -> String {
  "nodes=\{audit.nodes.to_string()} off_grid_point=\{audit.off_grid_point.to_string()} off_grid_size=\{audit.off_grid_size.to_string()} worst_off_grid_px=\{audit.worst_off_grid_px.to_string()}"
}

///|
/// One-line-per-fact evidence dump for the plan document.
pub fn summary(report : ProjectionReport) -> String {
  let mut out = ""
  out = out + "grid=\{report.cols.to_string()}x\{report.rows.to_string()}\n"
  out = out + "semantics_nodes=\{report.semantics_nodes.to_string()}\n"
  out = out + "layout_nodes=\{report.layout_nodes.to_string()}\n"
  out = out + "draw_commands=\{report.draw_commands.to_string()}\n"
  out = out + "offscreen_nodes=\{report.offscreen.to_string()}\n"
  out = out + "audit_semantics: \{audit_text(report.audit_semantics)}\n"
  out = out + "audit_layout: \{audit_text(report.audit_layout)}\n"
  out = out + "roles:"
  for (name, count) in report.roles {
    out = out + " \{name}=\{count.to_string()}"
  }
  out
}

///|
pub fn[Model, Msg] project(
  program : @core.Program[Model, Msg],
  width : Double,
  height : Double,
  cw : Double,
  ch : Double,
) -> ProjectionReport {
  let runtime = @runtime.new_program_with_dimensions(program~, width~, height~)
  runtime.set_text_system(cell_text_system())
  let layout = runtime.layout()
  let commands = runtime.draw_commands()
  let read = runtime.read_semantics()
  let nodes = snapshot_nodes(read)
  let root = snapshot_root(read)
  let layout_frame_list : Array[@core.Rect] = []
  collect_layout_frames(layout, layout_frame_list)
  let semantic_frames : Array[@core.Rect] = []
  for node in nodes {
    semantic_frames.push(node.frame)
  }
  let cols = (width / cw).floor().to_int()
  let rows = (height / ch).floor().to_int()
  let grid = new_grid(cols, rows)
  let mut offscreen = 0
  for i in paint_order(nodes, root) {
    if !paint_node(grid, nodes[i], cw, ch) {
      offscreen = offscreen + 1
    }
  }
  let lines = grid_lines(grid)
  let frames : Array[String] = []
  let mut fi = 0
  while fi < nodes.length() && fi < 16 {
    let n = nodes[fi]
    let label = node_text(n)
    let x = n.frame.origin.x.to_string()
    let y = n.frame.origin.y.to_string()
    let w = n.frame.size.width.to_string()
    let h = n.frame.size.height.to_string()
    frames.push(
      role_tag(n) +
      " '" +
      label +
      "' x=" +
      x +
      " y=" +
      y +
      " w=" +
      w +
      " h=" +
      h,
    )
    fi = fi + 1
  }
  runtime.destroy()
  {
    lines,
    plain: lines.join("\n"),
    ansi: grid_to_ansi(grid),
    cols,
    rows,
    semantics_nodes: nodes.length(),
    layout_nodes: layout_count(layout),
    draw_commands: commands.length(),
    audit_semantics: audit_frames(semantic_frames, cw, ch),
    audit_layout: audit_frames(layout_frame_list, cw, ch),
    roles: role_histogram(nodes),
    frames,
    offscreen,
  }
}
