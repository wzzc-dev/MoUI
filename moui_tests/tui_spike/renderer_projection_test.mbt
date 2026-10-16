/// The S0 spike re-implemented the projection to learn the rules; the shipped
/// `moui_tui_renderer` is what a terminal actually shows. Only feeding the real
/// demo app through the real renderer catches collisions that a hand-written
/// fixture never produces — so this is the headless half of the S5 evidence,
/// and the PTY smoke (`moui_tests/tui_pty_smoke`) is the other half.
///
/// Since tui-hardening H5 the headless carrier is `examples/tui_layers`: it is
/// the one app every PTY assertion reads, so the headless mirror has to run
/// the same program. (It used to be `examples/tui_split`, the app removed in
/// H5 once its gates were ported.)
///
/// Cell box and grid size match the PTY host (`CellBox::default()` = 8x16,
/// 100x30), so a row that reads here reads in the terminal too.

///|
fn rows(renderer : @tui_renderer.TuiRenderer) -> Array[String] {
  let lines : Array[String] = []
  for row in 0..<renderer.rows() {
    lines.push(renderer.line_text(row))
  }
  lines
}

///|
fn laid_out_layers_demo() -> (@runtime.AppRuntime, @tui_renderer.TuiRenderer) {
  let cell = @tui_renderer.CellBox::default()
  let width = 100.0 * cell.width
  let height = 30.0 * cell.height
  let runtime = @runtime.new_program_with_dimensions(
    program=@tui_layers_app.program(),
    width~,
    height~,
  )
  runtime.set_semantics_frames_enabled(true)
  let _ = runtime.layout()
  let renderer = @tui_renderer.TuiRenderer::new(
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width~, height~),
      scale_factor=1.0,
    ),
    sink=@tui_renderer.TuiSink::discard(),
    cell~,
  )
  (runtime, renderer)
}

///|
test "the shipped renderer projects the layers demo into readable rows" {
  let (runtime, renderer) = laid_out_layers_demo()
  let result = renderer.render_frame(runtime.draw_frame())
  assert_true(result.presented)
  let lines = rows(renderer)
  let grid = lines.join("\n")
  // 顶栏与焦点提示在同一行:它们是面板标题与焦点说明的内容。
  assert_true(lines[0].contains("MoUI TUI layers"))
  assert_true(lines[0].contains("focus: layers"))
  // 两个面板的标题必须同屏并存且行距有限 —— 这是「分栏」的可读性判据。
  // 这里按内容定位而不是钉死行号:量化改成「按格中心对齐」后,整块内容会随
  // 视口高度合法地移动一行,钉行号只会把正确的改动读成回归。layers 的两个
  // 面板头部各带一行说明(pane 标题在容器顶),中心量化可以让它们相差一行;
  // 判据是「同一屏、相邻行」,不是 split 时代的「严格同线」。
  match lines.search_by(line => line.contains("[ Layers 16/16 ]")) {
    None => abort("pane title 'Layers 16/16' did not render at all")
    Some(title_row) => {
      assert_true(title_row <= 6)
      match lines.search_by(line => line.contains("Files 10")) {
        None => abort("pane title 'Files 10' did not render at all")
        Some(files_row) => assert_true((files_row - title_row).abs() <= 2)
      }
    }
  }
  // 左栏:列表条目的名字完整可读。这里守的是实测过的残字 ——
  // 容器标签抢格会把行首字母擦成空格(`Entry 0` 变成 ` ntry 0`)。
  // 可视层按数据顺序取前八个,H5 扩充后的十六层列表让「前缀可见 + 尾部裁剪」
  // 成为同一条判据的两半。
  // 首帧列表框可见 7 行:标记状态逐行核对,可见范围以实测为准。
  for
    name in [
      "[x] Background", "[x] Grid", "[x] Strokes", "[x] Streamlines", "[ ] Fills",
      "[ ] Guides", "[x] Labels",
    ] {
    assert_true(grid.contains(name))
  }
  // 滚不下的尾行要被丢掉,而不是挤进边框行:这条和上一条合起来才是「裁剪」。
  assert_false(grid.contains("Shadows"))
  assert_false(grid.contains("Vellum"))
  // 右栏文件树:折叠标记与节点名都要落字。
  assert_true(grid.contains("▾"))
  for
    name in ["src", "core", "runtime", "program.mbt", "view.mbt", "runtime.mbt"] {
    assert_true(grid.contains(name))
  }
  // 树尾和列表尾同理:视口外的节点被裁掉,不挤进边框行。
  assert_false(grid.contains("moon.mod"))
  // 双栏必须同屏共存:存在同时带左栏条目和右栏折叠标记的一行。
  let mut side_by_side = false
  for line in lines {
    if line.contains("[x] ") && line.contains("▾") {
      side_by_side = true
    }
  }
  assert_true(side_by_side)
  // 裁剪发生在祖先 ScrollView 而不是窗口边界:超出左栏高度的条目被丢掉,
  // 不会被夹到最后一行,也不会画进右栏。
  assert_true(renderer.offscreen_node_count() > 0)
  match renderer.diagnostics().find("offscreen-nodes") {
    Some(record) => assert_true(record.count > 0)
    None => fail("clipped rows must be reported, not silently dropped")
  }
  // 状态行与键位帮助。
  assert_true(grid.contains("sel=Background node=src"))
  // 有余量的盒子必须闭合:存在同时带底边两角的一行。
  let mut closed = false
  for line in lines {
    if line.contains("╰") && line.contains("╯") {
      closed = true
    }
  }
  assert_true(closed)
  // 最后一行整行给了键位帮助,从第一个字符起完整可读。
  let last = lines[renderer.rows() - 1]
  assert_true(last.contains("tab/arrow-lr pane"))
}
