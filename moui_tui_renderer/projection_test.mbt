/// S2 投影证据:cell 栅格上的 z-order 策略。
/// 这些用例复述的是 S0 探针定下并已实测的规则,而不是新行为:
/// BFS 浅层先画、叶子内容优先于容器边框、同层先到先得、
/// 每次绘制裁剪到自身量化盒并在盒内折行、完全离屏的帧直接丢掉。
/// 角色分档(Region/Item/Label/Content/Placeholder)决定谁写字、谁只画框:
/// 区域与条目容器都不写字,聚合标签画进栅格只会打断自己人的首字母。

///|
test "node text prefers label, then value, then description" {
  let labeled = node(
    1UL,
    role=@core.Text,
    frame=rect(0.0, 0.0, 80.0, 16.0),
    label="label",
    value="value",
  )
  assert_eq(@moui_tui_renderer.node_text(labeled), "label")
  let valued = node(
    2UL,
    role=@core.Text,
    frame=rect(0.0, 0.0, 80.0, 16.0),
    value="value",
  )
  assert_eq(@moui_tui_renderer.node_text(valued), "value")
}

///|
test "quantization keeps exactly the cells a centre click can hit" {
  let box = @moui_tui_renderer.CellBox::default()
  // 帧顶边 9 落在第 1 格的下半格:第 0 格的中心在 4,宿主的点击点落在帧外,
  // 所以那一格不能画。外扩规则(顶边 floor、底边 ceil)会把标签留在这种
  // 点不着的格子上 —— 按钮看起来比命中区高一行。
  let (r0, c0, r1, c1) = @moui_tui_renderer.quantize(
    rect(9.0, 9.0, 23.0, 23.0),
    box,
    20,
    6,
  )
  assert_eq(c0, 1)
  assert_eq(r0, 1)
  assert_eq(c1, 3)
  assert_eq(r1, 1)
  // 越界的盒子夹进可视区,而不是画到屏幕外。
  let (ar0, ac0, ar1, ac1) = @moui_tui_renderer.quantize(
    rect(-40.0, -40.0, 400.0, 400.0),
    box,
    20,
    6,
  )
  assert_eq(ac0, 0)
  assert_eq(ar0, 0)
  assert_eq(ac1, 19)
  assert_eq(ar1, 5)
  // 帧比半格还窄(分隔线就是这种):一个中心都落在外面时退回帧起点那一格,
  // 宁可少一行可点,也不能整块消失。
  let (sr0, sc0, sr1, sc1) = @moui_tui_renderer.quantize(
    rect(8.0, 12.0, 80.0, 3.0),
    box,
    20,
    6,
  )
  assert_eq(sr0, 0)
  assert_eq(sr1, 0)
  assert_eq(sc0, 1)
  assert_eq(sc1, 10)
}

///|
/// 同一条不变量的通式:量化出来的行区间必须**正好**等于「中心落在帧里」的那些行。
/// 逐相位扫一遍(格高 16 → 帧顶边偏移 0..15):钉死单一尺寸正是这次的盲区,
/// 100x30 恰好落在旧的外扩规则与宿主中心点击一致的地方,所以它从没红过。
/// 列轴走的是同一条量化通路,不必重复扫。
test "every drawn row is hittable and every hittable row is drawn" {
  let cell = @moui_tui_renderer.CellBox::default()
  let rows = 12
  let mut offset = 0
  while offset < 16 {
    let y = 96.0 + offset.to_double()
    let height = 48.0
    let (r0, _, r1, _) = @moui_tui_renderer.quantize(
      rect(0.0, y, 80.0, height),
      cell,
      20,
      rows,
    )
    let mut first = -1
    let mut last = -1
    let mut row = 0
    while row < rows {
      let centre = (row.to_double() + 0.5) * cell.height
      if centre >= y && centre < y + height {
        if first < 0 {
          first = row
        }
        last = row
      }
      row = row + 1
    }
    assert_true(first >= 0)
    assert_eq(r0, first)
    assert_eq(r1, last)
    offset = offset + 1
  }
}

///|
/// 视觉盒必须等于命中盒。宿主把一次鼠标点击换成「格中心」那一个点
/// (`y = (row + 0.5) * cell.height`,见 `moui_terminal_host/input_channel.mbt`),
/// 所以标签画在哪一行,那一行的中心就必须落在控件帧里。
/// 帧取 counter 在 54x11 下的真实几何(y=110 h=36):帧顶边落在第 6 格的下半格,
/// 外扩规则把 `[-]` 画在第 6 行,而要点第 7 行才点得着 —— 就是实测到的错位。
test "a button label is drawn on a row the click can hit" {
  let button = node(
    1UL,
    role=@core.Button,
    frame=rect(88.0, 110.0, 40.0, 36.0),
    label="-",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(432.0, 176.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes=[button], root=button)))
  let cell = @moui_tui_renderer.CellBox::default()
  let label_rows : Array[Int] = []
  for y in 0..<renderer.rows() {
    if renderer.line_text(y).contains("[-]") {
      label_rows.push(y)
    }
  }
  assert_eq(label_rows.length(), 1)
  for row in label_rows {
    let centre_y = (row.to_double() + 0.5) * cell.height
    assert_true(centre_y >= 110.0)
    assert_true(centre_y < 110.0 + 36.0)
  }
}

///|
test "paint order is breadth-first from the root with strays appended" {
  let root = node(1UL, role=@core.Group, frame=rect(0.0, 0.0, 80.0, 16.0))
  let shallow = node(2UL, role=@core.Text, frame=rect(0.0, 0.0, 80.0, 16.0))
  let deep = node(3UL, role=@core.Text, frame=rect(0.0, 0.0, 80.0, 16.0))
  let stray = node(4UL, role=@core.Text, frame=rect(0.0, 0.0, 80.0, 16.0))
  let root_with_children = node(
    1UL,
    role=@core.Group,
    frame=rect(0.0, 0.0, 80.0, 16.0),
    children=[nid(2UL), nid(3UL)],
  )
  // 数组顺序故意打乱:深层写在最前,离屏兄弟写在最后。
  let nodes = [deep, root_with_children, shallow, stray]
  let order = @moui_tui_renderer.paint_order(nodes, Some(root.node_id))
  // 浅层必须在深层之前落笔,这样深层才有机会抢占。
  assert_eq(order, [1, 2, 0, 3])
}

///|
test "a container box and its items project into a recognisable grid" {
  let items = [
    node(
      2UL,
      role=@core.Text,
      frame=rect(8.0, 16.0, 100.0, 16.0),
      label="alpha",
    ),
    node(3UL, role=@core.Text, frame=rect(8.0, 32.0, 100.0, 16.0), label="beta"),
    node(
      4UL,
      role=@core.Text,
      frame=rect(8.0, 48.0, 100.0, 16.0),
      label="gamma",
    ),
  ]
  let root = container(
    1UL,
    frame=rect(0.0, 0.0, 160.0, 96.0),
    title="Files",
    children=items.map(n => n.node_id),
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  assert_eq(renderer.cols(), 20)
  assert_eq(renderer.rows(), 6)
  let result = renderer.render_frame(
    semantics_frame(nodes=[root] + items, root~),
  )
  assert_true(result.presented)
  assert_eq(renderer.offscreen_node_count(), 0)
  let lines : Array[String] = []
  for y in 0..<renderer.rows() {
    lines.push(renderer.line_text(y))
  }
  println("\n===== box + items =====\n\{grid(lines)}")
  // 区域只画框,不写字:`@core.List` 的 label 是集合摘要(`Selectable list`
  // 这类),画在盒顶会和第一个条目抢同一行,被更深的文本打断成残字。
  // 放弃的方案:每个区域画带标题的盒 —— 半截标题比没有标题更难读。
  for line in lines {
    assert_false(line.contains("Files"))
  }
  assert_eq(cell_at(renderer, 0, 0), '╭')
  assert_eq(cell_at(renderer, 0, 19), '╮')
  assert_eq(cell_at(renderer, 5, 0), '╰')
  assert_eq(cell_at(renderer, 5, 19), '╯')
  // 三个条目各自占一行,顺序与树顺序一致
  assert_eq(cell_at(renderer, 1, 0), '│')
  assert_true(lines[1].contains("alpha"))
  assert_true(lines[2].contains("beta"))
  assert_true(lines[3].contains("gamma"))
  assert_false(lines[1].contains("beta"))
}

///|
test "leaf content is allowed to overwrite its container border" {
  let root = container(1UL, frame=rect(0.0, 0.0, 160.0, 96.0), title="H", children=[
    nid(2UL),
  ])
  let leaf = node(
    2UL,
    role=@core.Text,
    frame=rect(0.0, 0.0, 80.0, 16.0),
    label="hello",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes=[root, leaf], root~)))
  println("\n===== content over border =====\n\{renderer.line_text(0)}")
  // 优先级 3 的内容盖掉优先级 1 的左上角,这正是"内容优先于边框"
  assert_eq(cell_at(renderer, 0, 0), 'h')
  assert_eq(cell_at(renderer, 0, 1), 'e')
  // 盒子之外的边框不受影响
  assert_eq(cell_at(renderer, 0, 19), '╮')
  assert_eq(cell_at(renderer, 5, 0), '╰')
}

///|
test "same-priority containers are first-come-wins" {
  let outer = container(1UL, frame=rect(0.0, 0.0, 80.0, 48.0), title="", children=[
    nid(2UL),
  ])
  let inner = node(2UL, role=@core.List, frame=rect(40.0, 16.0, 80.0, 48.0))
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(
    renderer.render_frame(semantics_frame(nodes=[outer, inner], root=outer)),
  )
  let lines : Array[String] = []
  for y in 0..<renderer.rows() {
    lines.push(renderer.line_text(y))
  }
  println("\n===== sibling boxes =====\n\{grid(lines)}")
  // 后画的同层盒子不能打断先画的竖线:重叠格保留第一个盒子
  assert_eq(cell_at(renderer, 1, 5), '╭')
  assert_eq(cell_at(renderer, 1, 9), '│')
  assert_eq(cell_at(renderer, 2, 5), '─')
}

///|
/// 抢占宽字符的一格,必须把它的伴侣格一起处理掉:残留的右半格不出文本,
/// 整行会凭空少一格,盒子的右边框被挤到前一格上。
test "stealing a wide glyph clears its partner cell" {
  let tab = node(
    1UL,
    role=@core.Tab,
    frame=rect(0.0, 0.0, 40.0, 16.0),
    label="文件",
  )
  // 优先级 3 的叶子只盖住「文」的右半格。
  let leaf = node(
    2UL,
    role=@core.Text,
    frame=rect(8.0, 0.0, 8.0, 16.0),
    label="x",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes=[tab, leaf], root=tab)))
  let first = renderer.line_text(0)
  println("\n===== wide glyph steal =====\n\{first}")
  // 左半格被擦成空白,「件」仍留在它自己的两格里。
  assert_eq(cell_at(renderer, 0, 0), ' ')
  assert_eq(cell_at(renderer, 0, 1), 'x')
  assert_eq(cell_at(renderer, 0, 2), '件')
  assert_eq(line_chars(first).length(), 3)
}

///|
test "CJK text wraps inside its own quantized box" {
  let root = container(1UL, frame=rect(0.0, 0.0, 80.0, 96.0), title="面板", children=[
    nid(2UL),
  ])
  let leaf = node(
    2UL,
    role=@core.Text,
    frame=rect(8.0, 32.0, 32.0, 48.0),
    label="文件名列表",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes=[root, leaf], root~)))
  let lines : Array[String] = []
  for y in 0..<renderer.rows() {
    lines.push(renderer.line_text(y))
  }
  println("\n===== cjk wrap =====\n\{grid(lines)}")
  // 4 格宽只放得下两个汉字,剩下的必须折到盒内下一行而不是溢进兄弟盒
  assert_true(lines[2].contains("文件"))
  assert_true(lines[3].contains("名列"))
  assert_true(lines[4].contains("表"))
  assert_false(lines[2].contains("名"))
  assert_false(lines[3].contains("文"))
  assert_false(lines[4].contains("列"))
  // 盒外的列仍然是边框:折行不能越界
  assert_eq(cell_at(renderer, 2, 0), '│')
  assert_eq(cell_at(renderer, 4, 9), '│')
}

///|
test "fully off-screen frames are dropped instead of clamped to the edge" {
  let root = container(1UL, frame=rect(0.0, 0.0, 160.0, 96.0), title="Files", children=[
    nid(2UL),
    nid(3UL),
  ])
  let visible = node(
    2UL,
    role=@core.Text,
    frame=rect(8.0, 16.0, 100.0, 16.0),
    label="alpha",
  )
  // 滚出可视区的行:夹到边界会和留在屏上的兄弟叠在同一行
  let scrolled = node(
    3UL,
    role=@core.Text,
    frame=rect(8.0, 400.0, 100.0, 16.0),
    label="gone",
  )
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(
    renderer.render_frame(
      semantics_frame(nodes=[root, visible, scrolled], root~),
    ),
  )
  assert_eq(renderer.offscreen_node_count(), 1)
  let record = renderer.diagnostics().find("offscreen-nodes")
  match record {
    Some(r) => assert_eq(r.count, 1)
    None => fail("expected an offscreen-nodes diagnostic")
  }
  let all = renderer.line_text(0) + renderer.line_text(1)
  assert_false(all.contains("gone"))
  assert_true(renderer.line_text(1).contains("alpha"))
}

///|
test "focus and selection are visually distinct from plain text" {
  let plain = @moui_tui_renderer.attrs_for(
    "ListItem",
    @core.SemanticsState::default(),
  )
  let focused = @moui_tui_renderer.attrs_for("ListItem", state(focused=true))
  let selected = @moui_tui_renderer.attrs_for("ListItem", state(selected=true))
  assert_true(focused.underline)
  assert_true(focused.bold)
  assert_true(selected.reverse)
  assert_false(plain.underline)
  assert_false(plain.reverse)
  // 焦点态必须改变前景色,否则键盘导航在终端里看不出来
  assert_true(focused.fg != plain.fg)
}

///|
/// S4 双栏 demo 暴露的缺口:窗口边界之外的行原来只按整屏裁剪,
/// 于是左栏滚出可视区的行会画到右栏的同一行上。裁到祖先 `ScrollView`
/// 之后,这一行按离屏丢掉。
fn two_panes() -> (@core.SemanticsNode, Array[@core.SemanticsNode]) {
  let shown = node(
    2UL,
    role=@core.Text,
    frame=rect(8.0, 16.0, 60.0, 16.0),
    label="alpha",
  )
  let bled = node(
    3UL,
    role=@core.Text,
    frame=rect(8.0, 48.0, 60.0, 16.0),
    label="gone",
  )
  let right_row = node(
    5UL,
    role=@core.Text,
    frame=rect(88.0, 48.0, 60.0, 16.0),
    label="right",
  )
  let left = node(
    1UL,
    role=@core.ScrollView,
    frame=rect(0.0, 0.0, 80.0, 48.0),
    label="Files",
    children=[nid(2UL), nid(3UL)],
  )
  let right = node(
    4UL,
    role=@core.ScrollView,
    frame=rect(80.0, 0.0, 80.0, 96.0),
    children=[nid(5UL)],
  )
  let root = node(6UL, role=@core.Group, frame=rect(0.0, 0.0, 160.0, 96.0), children=[
    nid(1UL),
    nid(4UL),
  ])
  (root, [root, left, right, shown, bled, right_row])
}

///|
test "a scroll view clips its own rows, not just the window edge" {
  let (root, nodes) = two_panes()
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  let lines : Array[String] = []
  for y in 0..<renderer.rows() {
    lines.push(renderer.line_text(y))
  }
  println("\n===== per-pane clip =====\n\{grid(lines)}")
  // 左栏只有 3 行高:第 1 行的 alpha 在内,第 3 行的 gone 已经被滚出去。
  assert_true(lines[1].contains("alpha"))
  assert_false(lines[3].contains("gone"))
  assert_eq(renderer.offscreen_node_count(), 1)
  // 第 3 行属于右栏:兄弟栏的内容不能因为左栏溢出而被覆盖。
  assert_true(lines[3].contains("right"))
  assert_eq(cell_at(renderer, 3, 10), '│')
}

///|
test "clips narrow at scroll views and are inherited by every descendant" {
  let (root, nodes) = two_panes()
  let cell = @moui_tui_renderer.CellBox::default()
  let clips = @moui_tui_renderer.clips_in_tree(
    nodes,
    Some(root.node_id),
    cell,
    20,
    6,
  )
  let view = @moui_tui_renderer.viewport(cell, 20, 6)
  // 面板自己拿到可视区:它的边框要画满整栏。
  assert_eq(clips[0].chrome, view)
  assert_eq(clips[1].chrome, view)
  assert_eq(clips[2].chrome, view)
  // 栏内的行拿到「祖先滚动面板 ∩ 可视区」,也就是栏框本身:边框还画在这一圈。
  assert_eq(clips[3].chrome, rect(0.0, 0.0, 80.0, 48.0))
  assert_eq(clips[5].chrome, rect(80.0, 0.0, 80.0, 96.0))
  // 但字与高亮带只能画在框线内侧:终端的线是一整格,而布局的边框只有几像素,
  // 两者共用一格时列表行就会写在框线上。
  assert_eq(clips[3].content, rect(8.0, 16.0, 64.0, 16.0))
  assert_eq(clips[4].content, rect(8.0, 16.0, 64.0, 16.0))
  assert_eq(clips[5].content, rect(88.0, 16.0, 64.0, 64.0))
}

///|
/// 框小到没有内侧时不能把整栏清空:那一栏宁可让字压框线,也要把行画出来。
test "a ring with no inside keeps its full rect" {
  let leaf = node(
    2UL,
    role=@core.Text,
    frame=rect(8.0, 16.0, 60.0, 16.0),
    label="alpha",
  )
  // 2 格高、3 格宽:量化不出内侧格子。
  let tight = node(
    1UL,
    role=@core.ScrollView,
    frame=rect(0.0, 0.0, 24.0, 32.0),
    children=[nid(2UL)],
  )
  let root = node(3UL, role=@core.Group, frame=rect(0.0, 0.0, 24.0, 32.0), children=[
    nid(1UL),
  ])
  let clips = @moui_tui_renderer.clips_in_tree(
    [root, tight, leaf],
    Some(root.node_id),
    @moui_tui_renderer.CellBox::default(),
    3,
    2,
  )
  assert_eq(clips[2].content, rect(0.0, 0.0, 24.0, 32.0))
}

///|
/// S5 的两条判据都落在这棵树上:「上下键移动带边框列表的选中项」要求
/// 选中态在终端里看得见,而选中住在条目容器上(实测
/// `ListItem … text='Entry 0, row 0'`),容器自己不能写字。
fn list_tree(
  selected~ : Bool,
) -> (@core.SemanticsNode, Array[@core.SemanticsNode]) {
  let row_a = node(
    4UL,
    role=@core.Text,
    frame=rect(8.0, 16.0, 60.0, 16.0),
    label="Entry 0",
  )
  let row_b = node(
    5UL,
    role=@core.Text,
    frame=rect(8.0, 32.0, 60.0, 16.0),
    label="Entry 1",
  )
  let item_a = node(
    2UL,
    role=@core.ListItem,
    frame=rect(0.0, 16.0, 80.0, 16.0),
    label="Entry 0, row 0",
    state=state(selected~),
    children=[nid(4UL)],
  )
  let item_b = node(
    3UL,
    role=@core.ListItem,
    frame=rect(0.0, 32.0, 80.0, 16.0),
    label="Entry 1, row 1",
    children=[nid(5UL)],
  )
  let list = node(
    1UL,
    role=@core.List,
    frame=rect(0.0, 0.0, 80.0, 64.0),
    label="Selectable list",
    children=[nid(2UL), nid(3UL)],
  )
  (list, [list, item_a, item_b, row_a, row_b])
}

///|
test "wrappers paint nothing so their rows keep their letters" {
  let (root, nodes) = list_tree(selected=true)
  let (sink, _) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes~, root~)))
  let lines : Array[String] = []
  for y in 0..<4 {
    lines.push(renderer.line_text(y))
  }
  println("\n===== silent wrappers =====\n\{grid(lines)}")
  assert_true(lines[1].contains("Entry 0"))
  assert_true(lines[2].contains("Entry 1"))
  // 实测过的残字:容器标签/占位符抢走格,行首字母被擦成空格或 `?`。
  assert_eq(cell_at(renderer, 1, 1), 'E')
  assert_eq(cell_at(renderer, 2, 1), 'E')
  // 集合摘要与条目的聚合名字都不许进栅格。
  for line in lines {
    assert_false(line.contains("Selectable"))
    assert_false(line.contains("row 0"))
  }
}

///|
/// 选中态必须由属性(反显)到达终端:字符不变,但增量必须非空,
/// 否则上下键移动选中项时终端什么都不会发生。
test "selection reaches the terminal as an attrs-only band" {
  let (on_root, on_nodes) = list_tree(selected=true)
  let (on_sink, on_capture) = capture()
  let on_renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink=on_sink,
  )
  ignore(
    on_renderer.render_frame(semantics_frame(nodes=on_nodes, root=on_root)),
  )
  let (off_root, off_nodes) = list_tree(selected=false)
  let (off_sink, off_capture) = capture()
  let off_renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink=off_sink,
  )
  ignore(
    off_renderer.render_frame(semantics_frame(nodes=off_nodes, root=off_root)),
  )
  // 反显码 7 只在选中帧出现;两帧的字格完全一致。
  assert_true(count_occurrences(on_capture.text(), "\u{1b}[0;7") > 0)
  assert_eq(count_occurrences(off_capture.text(), "\u{1b}[0;7"), 0)
  for y in 0..<4 {
    // 属性变化不许挪动任何一个字形。
    assert_eq(on_renderer.line_text(y), off_renderer.line_text(y))
  }
  let before = on_capture.total()
  ignore(
    on_renderer.render_frame(semantics_frame(nodes=off_nodes, root=off_root)),
  )
  // 字没变但选中变了:增量必须非空,否则上下键移动选中项时终端不动。
  assert_true(on_capture.total() > before)
}
