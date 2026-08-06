///|
test "selection node cell mapping" {
  // 4 行可视,1 行回看,滚动 1:first_visible = 1+4-4-1 = 0
  let node = TerminalSelectionNode::new(
    cell_width=10.0,
    cell_height=20.0,
    scroll_offset=1,
    total_lines=5,
    rows=4,
    cols=8,
  )
  let frame = @core.Rect::new(x=0.0, y=0.0, width=80.0, height=80.0)
  // 原点 → 可视行 0(全局行 0)
  let (r0, c0) = node.cell_at(@core.Point::new(x=0.0, y=0.0), frame)
  inspect(r0, content="0")
  inspect(c0, content="0")
  // 第 3.5 格宽、第 2.4 格高 → 列 3、可视行 2(全局行 2)
  let (r1, c1) = node.cell_at(@core.Point::new(x=35.0, y=48.0), frame)
  inspect(r1, content="2")
  inspect(c1, content="3")
  // 越界:负坐标与超出区域收敛到合法范围
  let (r2, c2) = node.cell_at(@core.Point::new(x=-30.0, y=-20.0), frame)
  inspect(r2, content="0")
  inspect(c2, content="0")
  let (r3, c3) = node.cell_at(@core.Point::new(x=900.0, y=900.0), frame)
  inspect(r3, content="4")
  inspect(c3, content="7")
}

///|
test "selection node mapping with scroll offset" {
  // 8 行可视,3 行回看,滚动 2:first_visible = 11-8-2 = 1
  let node = TerminalSelectionNode::new(
    cell_width=9.6,
    cell_height=20.0,
    scroll_offset=2,
    total_lines=11,
    rows=8,
    cols=10,
  )
  let frame = @core.Rect::new(x=0.0, y=0.0, width=96.0, height=160.0)
  // 可视行 3(第 4 行)→ 全局行 1 + 3 = 4
  let (r, _) = node.cell_at(@core.Point::new(x=0.0, y=60.0), frame)
  inspect(r, content="4")
  // 最后一格 → 列 9
  let (_, c) = node.cell_at(@core.Point::new(x=95.0, y=0.0), frame)
  inspect(c, content="9")
}
