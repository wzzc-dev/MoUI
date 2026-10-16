/// The S0 spike re-implemented the projection to learn the rules; the shipped
/// `moui_tui_renderer` is what a terminal actually shows. Only feeding the real
/// demo app through the real renderer catches collisions that a hand-written
/// fixture never produces — so this is the headless half of the S5 evidence,
/// and the PTY smoke (`moui_tests/tui_pty_smoke`) is the other half.
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
fn laid_out_split_demo() -> (@runtime.AppRuntime, @tui_renderer.TuiRenderer) {
  let cell = @tui_renderer.CellBox::default()
  let width = 100.0 * cell.width
  let height = 30.0 * cell.height
  let runtime = @runtime.new_program_with_dimensions(
    program=@tui_split_app.program(),
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
test "the shipped renderer projects the split demo into readable rows" {
  let (runtime, renderer) = laid_out_split_demo()
  let result = renderer.render_frame(runtime.draw_frame())
  assert_true(result.presented)
  let lines = rows(renderer)
  let grid = lines.join("\n")
  // 顶栏与焦点提示在同一行:它们是两个面板各自的标题内容。
  assert_true(lines[0].contains("MoUI TUI split"))
  assert_true(lines[0].contains("focus: list"))
  // 两个面板的标题必须在同一行并存 —— 这是「分栏」的可读性判据。
  // 这里按内容定位而不是钉死行号:量化改成「按格中心对齐」后,整块内容会随
  // 视口高度合法地移动一行,钉行号只会把正确的改动读成回归。
  match lines.search_by(line => line.contains("[ Entries 16 ]")) {
    None => abort("pane title 'Entries 16' did not render at all")
    Some(title_row) => {
      assert_true(title_row <= 2)
      assert_true(lines[title_row].contains("Files 7"))
    }
  }
  // 左栏:每个条目的名字完整可读。这里守的是实测过的残字 ——
  // 容器标签抢格会把行首字母擦成空格,`Entry 0` 变成 ` ntry 0`。
  // 上界是 7 而不是 8:边框那一圈格子现在只属于框(见 S7 addendum),所以
  // 栏里少落一行。改动前多出来的那一行是 `row 8`,实测写在底边框上 ——
  // 整行读作 `╰row 8 ────────`,角还在但笔画被字吃了。「看得见」不是「画得对」。
  for k in 0..<=7 {
    assert_true(grid.contains("Entry \{k}"))
    assert_true(grid.contains("row \{k}"))
  }
  // 滚不下的那一行要被丢掉,而不是挤进边框行:这条和上一条合起来才是「裁剪」。
  assert_false(grid.contains("row 8"))
  // 右栏文件树:折叠标记与节点名都要落字。
  assert_true(grid.contains("▾"))
  for
    name in [
      "[src]", "[core]", "[runtime]", "[program.mbt]", "[view.mbt]", "[moon.mod]",
    ] {
    assert_true(grid.contains(name))
  }
  // 双栏必须同屏共存:存在同时带左栏条目和右栏条目的一行。
  let mut side_by_side = false
  for line in lines {
    if line.contains("Entry ") && line.contains("▾") {
      side_by_side = true
    }
  }
  assert_true(side_by_side)
  // 裁剪发生在祖先 ScrollView 而不是窗口边界:超出左栏高度的条目被丢掉,
  // 不会被夹到最后一行、也不会画进右栏。
  assert_false(grid.contains("Entry 12"))
  assert_true(renderer.offscreen_node_count() > 0)
  match renderer.diagnostics().find("offscreen-nodes") {
    Some(record) => assert_true(record.count > 0)
    None => fail("clipped rows must be reported, not silently dropped")
  }
  // 状态行与键位帮助行。
  assert_true(grid.contains("sel=Entry 0 node=src"))
  assert_true(grid.contains("tab/arrow-lr pane"))
  // 有余量的盒子必须闭合:存在一行同时出现底边的左右两角。
  // 右栏文件树框的底边就是这个证据 —— 盒子的角是投影出来的,不是拼出来的。
  let mut closed = false
  for line in lines {
    if line.contains("╰") && line.contains("╯") {
      closed = true
    }
  }
  assert_true(closed)
  // 最后一行整行给了键位帮助,而且从第一个字符起就完整可读。
  // 根容器没有边框样式却按 Region 投影成外框,它那一圈笔画是优先级 1 的装饰,
  // 被优先级 3 的内容盖掉是 S0 定下的规则;反过来让边框赢会写出
  // `╰ab/arrow-lr pane` 这种残字 —— 残字比开口更难读。
  let last = lines[renderer.rows() - 1]
  assert_true(last.has_prefix("tab/arrow-lr pane"))
}
