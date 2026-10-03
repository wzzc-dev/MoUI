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

///|
/// C 形包裹（Scratch 的核心视觉语义）由三段拼成：
/// **帽**（顶块，一行高）+ **左壁**（`BlockArm`）+ **底口**（收尾块）。
///
/// 关键几何断言（全部由实测输出定标）：
/// - 顶块**保持一行高**（不拉高）：早先把它拉高，顶块填充盖住了子行上半部分
///   （实测顶块 10..130 覆盖子行 50..124），子块看着像陷进父块里；
/// - 左壁从帽底拉到**收尾块顶边**（不越过 `end`）：实测 arm y=42 h=86，
///   而 `end` 顶边 = 130，42+86=128 ≈ 130（留 2pt 与帽底重叠）；
/// - 同一体内的**所有**子行都右缩（不是只有第一行）：实测两行都是 416。
test "control flow heads wrap their body in a C shape" {
  let blocks = @blocks.block_chain([
    @ir.If(
      @ir.Binary(@ir.Gt, @ir.Var("人数"), @ir.IntLit(0)),
      [@ir.Assign("a", @ir.IntLit(1)), @ir.Assign("b", @ir.IntLit(2))],
      [],
      [],
    ),
  ])
  let base = @app.blocks_item_rects(blocks, avail_width=470.0)
  let visual = @app.blocks_visual_rects(blocks, base)
  // 链条：if(0) / a=1(1) / b=2(1) / end(0)
  assert_eq(blocks.length(), 4)
  assert_true(match blocks[0].kind {
    @blocks.BkIf => true
    _ => false
  })
  assert_true(match blocks[3].kind {
    @blocks.BkEnd => true
    _ => false
  })
  // 1) 顶块**不**长高（帽只有一行）
  assert_eq(visual[0].size.height, base[0].size.height)
  // 2) 两行子栈**都**右缩同一个量
  assert_eq(base[1].size.width - visual[1].size.width, 10.0)
  assert_eq(base[2].size.width - visual[2].size.width, 10.0)
  // 3) 收尾块与后续语句不缩（它们不在体内）
  assert_eq(visual[3].size.width, base[3].size.width)
  // 4) 左壁：一条，长度 = 帽底 → 收尾块顶边
  let texts = blocks.map(item => item.text)
  let ops = @app.blocks_draw_plan(
    blocks, texts, visual, -1, "", None, 0.0, 0.0,
  )
  let mut arms = 0
  for op in ops {
    match op {
      @app.BlockArm(_, ay, _, ah, kind) => {
        arms = arms + 1
        assert_true(match kind {
          @blocks.BkIf => true
          _ => false
        })
        let cap_bottom = base[0].origin.y + base[0].size.height
        let end_top = base[3].origin.y
        // 壁从帽底附近起，止于收尾块顶边（允许 2pt 与帽底重叠）
        assert_true(ay <= cap_bottom + 0.5)
        assert_true(ay + ah <= end_top + 2.5)
      }
      _ => ()
    }
  }
  assert_eq(arms, 1)
}

///|
/// 只有控制流头块带 C 形（左壁 + 子行右缩）；普通语句序列两者都没有。
test "only control flow heads get a C shape" {
  let loop_blocks = @blocks.block_chain([
    @ir.CountLoop(@ir.IntLit(3), None, [@ir.Break]),
  ])
  let loop_base = @app.blocks_item_rects(loop_blocks, avail_width=470.0)
  let loop_visual = @app.blocks_visual_rects(loop_blocks, loop_base)
  let loop_texts = loop_blocks.map(item => item.text)
  let loop_ops = @app.blocks_draw_plan(
    loop_blocks, loop_texts, loop_visual, -1, "", None, 0.0, 0.0,
  )
  let mut loop_arms = 0
  for op in loop_ops {
    match op {
      @app.BlockArm(_, _, _, _, _) => loop_arms = loop_arms + 1
      _ => ()
    }
  }
  assert_eq(loop_arms, 1)
  // 纯命令序列：既没有壁，也没有任何一行被右缩
  let flat = @blocks.block_chain([
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
  ])
  let flat_base = @app.blocks_item_rects(flat, avail_width=470.0)
  let flat_visual = @app.blocks_visual_rects(flat, flat_base)
  let flat_texts = flat.map(item => item.text)
  let flat_ops = @app.blocks_draw_plan(
    flat, flat_texts, flat_visual, -1, "", None, 0.0, 0.0,
  )
  let mut flat_arms = 0
  for op in flat_ops {
    match op {
      @app.BlockArm(_, _, _, _, _) => flat_arms = flat_arms + 1
      _ => ()
    }
  }
  assert_eq(flat_arms, 0)
  let mut i = 0
  while i < flat_base.length() {
    assert_eq(flat_visual[i].size.width, flat_base[i].size.width)
    assert_eq(flat_visual[i].size.height, flat_base[i].size.height)
    i = i + 1
  }
}
