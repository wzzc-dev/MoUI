/// S0 spike verdict evidence: run the cell projection over the real
/// `examples/counter` and `examples/showcase` programs and check that the
/// projected grid is structurally recognisable.

///|
test "counter projects into a recognisable cell grid" {
  let report = @tui_spike.project(
    @counter_app.program(),
    320.0,
    200.0,
    8.0,
    16.0,
  )
  println("\n===== counter projected to 40x12 cells =====")
  for line in report.lines {
    println(line)
  }
  println(@tui_spike.summary(report))
  for f in report.frames {
    println(f)
  }
  assert_true(report.plain.contains("MoUI Counter"))
  assert_true(report.plain.contains("Count:"))
  assert_true(report.plain.contains("[-]"))
  assert_true(report.plain.contains("[Reset]"))
  assert_true(report.plain.contains("[+]"))
  // The three buttons are declared inside one `row(...)`, so a structurally
  // faithful projection must place them on the same text line.
  let minus = @tui_spike.line_containing(report.lines, "[-]")
  let reset = @tui_spike.line_containing(report.lines, "[Reset]")
  let plus = @tui_spike.line_containing(report.lines, "[+]")
  match (minus, reset, plus) {
    (Some(a), Some(b), Some(c)) => {
      assert_eq(a, b)
      assert_eq(b, c)
    }
    _ => fail("expected all three counter buttons in the projected grid")
  }
  assert_true(report.semantics_nodes > 0)
}

///|
test "showcase projects without losing its semantic structure" {
  let report = @tui_spike.project(
    @showcase_app.ShowcaseModel::new().program(),
    1200.0,
    800.0,
    8.0,
    16.0,
  )
  println("\n===== showcase projected to 150x50 cells =====")
  for line in report.lines {
    println(line)
  }
  println(@tui_spike.summary(report))
  assert_true(report.semantics_nodes > 10)
  assert_true(report.draw_commands > 0)
  // Structural recognisability, not pixel fidelity: the page title, the rail's
  // first entries and a card heading must survive quantization intact.
  assert_true(report.plain.contains("MoUI Showcase"))
  assert_true(report.plain.contains("[Welcome]"))
  assert_true(report.plain.contains("[Patterns Overview]"))
  assert_true(report.plain.contains("Responsive grid"))
  assert_true(report.offscreen > 0)
}

///|
test "ansi output carries per-role escape sequences" {
  let report = @tui_spike.project(
    @counter_app.program(),
    320.0,
    200.0,
    8.0,
    16.0,
  )
  assert_true(report.ansi.contains("\u{1b}["))
}

///|
test "overlap repair: leaf beats label beats chrome, first leaf keeps the cell" {
  let grid = @tui_spike.new_grid(20, 3)
  let chrome = @tui_spike.new_seq(grid, 1)
  let label = @tui_spike.new_seq(grid, 2)
  @tui_spike.draw_box(grid, 0, 0, 2, 19, "OuterTitle", 0, chrome, label)
  let first = @tui_spike.new_seq(grid, 3)
  @tui_spike.write_boxed(grid, 0, 1, 0, 10, "Hello", 0, first)
  let second = @tui_spike.new_seq(grid, 3)
  @tui_spike.write_boxed(grid, 0, 1, 0, 10, "World", 0, second)
  let top = @tui_spike.grid_lines(grid)[0]
  println("overlap row: \{top}")
  assert_true(top.contains("Hello"))
  assert_true(!top.contains("World"))
  assert_true(!top.contains("OuterTitle"))
}

///|
test "off-viewport nodes are clipped, not folded onto the boundary row" {
  // The counter's button row sits at y=122 in a 320x80 viewport (5 cells tall).
  let report = @tui_spike.project(
    @counter_app.program(),
    320.0,
    80.0,
    8.0,
    16.0,
  )
  println("\n===== counter clipped to 40x5 cells =====")
  for line in report.lines {
    println(line)
  }
  assert_true(report.offscreen >= 3)
  assert_true(!report.plain.contains("[Reset]"))
  assert_true(!report.plain.contains("[-]"))
  assert_true(report.plain.contains("MoUI Counter"))
}

///|
test "chrome-only rows read as pure box drawing" {
  let grid = @tui_spike.new_grid(12, 3)
  let chrome = @tui_spike.new_seq(grid, 1)
  @tui_spike.draw_box(grid, 0, 0, 2, 11, "", 0, chrome, chrome)
  let lines = @tui_spike.grid_lines(grid)
  assert_true(@tui_spike.row_is_chrome_only(lines[0]))
  assert_true(@tui_spike.row_is_chrome_only(lines[1]))
  assert_true(@tui_spike.row_is_chrome_only(lines[2]))
  let leaf = @tui_spike.new_seq(grid, 3)
  @tui_spike.write_boxed(grid, 1, 2, 1, 9, "hi", 0, leaf)
  assert_true(!@tui_spike.row_is_chrome_only(@tui_spike.grid_lines(grid)[1]))
}

///|
/// S4 evidence: the two-pane split demo is the shape a terminal renderer must
/// reproduce. This is the projection half of the proof -- `app_test.mbt` in the
/// demo itself measures the pre-quantization frames and clips.
///
/// The grid below is the *spike's* scratch projector, kept because it is the
/// instrument that measured the rules. Its `?]` residue and punched-through
/// row heads are the defects S2 fixed; `renderer_projection_test.mbt` and
/// `moui_tui_renderer/projection_test.mbt` are what the shipped renderer does.
test "the split demo projects as two panes side by side" {
  let report = @tui_spike.project(
    @tui_split_app.program(),
    960.0,
    480.0,
    8.0,
    16.0,
  )
  println("\n===== tui_split projected to 120x30 cells =====")
  for line in report.lines {
    println(line)
  }
  println(@tui_spike.summary(report))
  inspect(role_count(report, "List"), content="1")
  inspect(role_count(report, "Tree"), content="1")
  inspect(role_count(report, "ScrollView"), content="2")
  assert_true(report.plain.contains("Entries 16"))
  assert_true(report.plain.contains("Files 7"))
  assert_true(report.plain.contains("Entry 0"))
  assert_true(report.plain.contains("program.mbt"))
  // Columns, not just presence: if the split collapsed into one stacked column
  // both labels would start in the left margin.
  let list_col = col_of(report, "Entry 0")
  let tree_col = col_of(report, "program.mbt")
  println("list_col=\{list_col.to_string()} tree_col=\{tree_col.to_string()}")
  assert_true(list_col < tree_col)
  // 16 rows of 32px overflow a 480px window, so the projection has to report the
  // rows it could not place. The spike only clips at the window edge, never at a
  // pane's own box -- that is the per-pane clip `moui_tui_renderer` must add.
  assert_true(report.offscreen > 0)
}

///|
fn role_count(report : @tui_spike.ProjectionReport, name : String) -> Int {
  let mut total = 0
  for (role, count) in report.roles {
    if role == name {
      total = count
    }
  }
  total
}

///|
fn col_of(report : @tui_spike.ProjectionReport, needle : String) -> Int raise {
  let row = match @tui_spike.line_containing(report.lines, needle) {
    Some(i) => i
    None => fail("no projected row contains " + needle)
  }
  match report.lines[row].find(needle) {
    Some(col) => col
    None => fail(needle + " is not inside its projected row")
  }
}
