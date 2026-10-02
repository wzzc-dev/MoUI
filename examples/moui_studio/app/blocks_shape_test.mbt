///|
/// 切片 E（积木形状）：形状参与语义编码——变量族胶囊大圆角、
/// 条件块带徽标、返回块带箭头前缀。
test "block shapes encode semantics" {
  // 变量族 = 胶囊圆角；控制流/命令 = 小圆角
  assert_eq(@app.block_corner_radius(@blocks.BkDeclare), 14.0)
  assert_eq(@app.block_corner_radius(@blocks.BkAssign), 14.0)
  assert_eq(@app.block_corner_radius(@blocks.BkSetIndex), 14.0)
  assert_eq(@app.block_corner_radius(@blocks.BkIf), 6.0)
  assert_eq(@app.block_corner_radius(@blocks.BkCall), 6.0)
  // 绘制计划：条件块产生徽标 op
  let blocks = @blocks.block_chain([
    @ir.If(
      @ir.Binary(@ir.Gt, @ir.Var("人数"), @ir.IntLit(0)),
      [@ir.Assign("a", @ir.IntLit(1))],
      [],
      [],
    ),
    @ir.Return(Some(@ir.Var("a"))),
  ])
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0)
  let texts = blocks.map(item => item.text)
  let ops = @app.blocks_draw_plan(
    blocks,
    texts,
    rects,
    -1,
    "",
    None,
    0.0,
    0.0,
  )
  let mut badges = 0
  for op in ops {
    match op {
      @app.BlockBadge(_, _, _) => badges = badges + 1
      _ => ()
    }
  }
  assert_eq(badges, 1)
  // 返回块标签带 ↩ 前缀
  let mut return_label = ""
  for op in ops {
    match op {
      @app.BlockLabel(text, _, _, _, _) =>
        if text.contains("↩") {
          return_label = text
        }
      _ => ()
    }
  }
  assert_true(return_label != "")
}
