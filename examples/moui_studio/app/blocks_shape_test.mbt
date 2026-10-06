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
  let ops = @app.blocks_draw_plan(blocks, texts, rects, -1, "", None, 0.0, 0.0)
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
  assert_true(
    match blocks[0].kind {
      @blocks.BkIf => true
      _ => false
    },
  )
  assert_true(
    match blocks[3].kind {
      @blocks.BkEnd => true
      _ => false
    },
  )
  // 1) 顶块**不**长高（帽只有一行）
  assert_eq(visual[0].size.height, base[0].size.height)
  // 2) 两行子栈**都**右缩同一个量
  assert_eq(base[1].size.width - visual[1].size.width, 10.0)
  assert_eq(base[2].size.width - visual[2].size.width, 10.0)
  // 3) 收尾块与后续语句不缩（它们不在体内）
  assert_eq(visual[3].size.width, base[3].size.width)
  // 4) 左壁：一条，长度 = 帽底 → 收尾块顶边
  let texts = blocks.map(item => item.text)
  let ops = @app.blocks_draw_plan(blocks, texts, visual, -1, "", None, 0.0, 0.0)
  let mut arms = 0
  for op in ops {
    match op {
      @app.BlockArm(_, ay, _, ah, kind) => {
        arms = arms + 1
        assert_true(
          match kind {
            @blocks.BkIf => true
            _ => false
          },
        )
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
    loop_blocks,
    loop_texts,
    loop_visual,
    -1,
    "",
    None,
    0.0,
    0.0,
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
    flat,
    flat_texts,
    flat_visual,
    -1,
    "",
    None,
    0.0,
    0.0,
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

///|
/// M7①：匹配帽的多分支 C 形臂——帽 + 每个情况行 + 否则都是 C 头，
/// 各自把「自己到下一个收尾块」的子栈围成 C（4 段臂）；情况体内的
/// 语句行右缩（blocks_in_c_body 同口径）。
test "match hat wraps every arm in a C shape" {
  let blocks = @blocks.block_chain([
    @ir.Match(
      @ir.EnumTag("花色", "红桃"),
      [
        @ir.MatchArm::{
          case_name: "红桃",
          body: [@ir.Assign("a", @ir.IntLit(1))],
        },
        @ir.MatchArm::{
          case_name: "黑桃",
          body: [@ir.Assign("b", @ir.IntLit(2))],
        },
      ],
      [@ir.Assign("c", @ir.IntLit(3))],
    ),
  ])
  // 快照口径：4 段臂（帽→情况0、情况0→情况1、情况1→否则、否则→结束）
  let base = @app.blocks_item_rects(blocks, avail_width=470.0)
  let visual = @app.blocks_visual_rects(blocks, base)
  let ops = @app.blocks_draw_plan(
    blocks,
    blocks.map(item => item.text),
    visual,
    -1,
    "",
    None,
    0.0,
    0.0,
  )
  let mut arms = 0
  for op in ops {
    match op {
      @app.BlockArm(_, _, _, _, _) => arms = arms + 1
      _ => ()
    }
  }
  assert_eq(arms, 4)
  // 匹配帽带决策徽标（与如果/当同族）
  let mut badges = 0
  for op in ops {
    match op {
      @app.BlockBadge(_, _, _) => badges = badges + 1
      _ => ()
    }
  }
  assert_eq(badges, 1)
  // 情况体内的语句行右缩（C 形包裹的第二个信号）
  // 链序：0 帽 / 1 情况行 / 2 体 / 3 情况行 / 4 体 / 5 否则 / 6 体 / 7 结束
  assert_true(@app.blocks_in_c_body(blocks, 2))
  assert_true(@app.blocks_in_c_body(blocks, 4))
  assert_true(@app.blocks_in_c_body(blocks, 6))
  // 情况行与帽同层（伴随装饰块），不在任何 C 体内
  assert_false(@app.blocks_in_c_body(blocks, 1))
  assert_false(@app.blocks_in_c_body(blocks, 3))
}

///|
/// M7①：声明块投影——enum/struct 是只读数据行（path 空、无榫卯、
/// 无 C 臂、无插槽），文本取规范写法。
test "declaration blocks project as read-only rows" {
  let program = @proposals.sample_hello()
  let with_decls = {
    ..program,
    enums: [@ir.EnumDecl::{ name: "花色", cases: ["红桃", "黑桃"], }],
    structs: [
      @ir.StructDecl::{
        name: "Person",
        fields: [@ir.StructField::{ field_name: "名字", field_type: "text", }],
      },
    ],
  }
  let decls = @blocks.declaration_chain(with_decls)
  assert_eq(decls.length(), 2)
  assert_true(decls[0].kind is @blocks.BkEnumDecl)
  assert_eq(decls[0].text, "enum 花色 { 红桃, 黑桃 }")
  assert_true(decls[1].kind is @blocks.BkStructDecl)
  assert_eq(decls[1].text, "struct Person { 名字: text }")
  // 只读口径：装饰块路径为空
  for item in decls {
    assert_eq(item.path.length(), 0)
  }
  // 绘制计划：有块体与标签，没有榫卯/臂/洞
  let rects = @app.blocks_item_rects(decls, avail_width=470.0)
  let ops = @app.blocks_draw_plan(
    decls,
    decls.map(item => item.text),
    rects,
    -1,
    "",
    None,
    0.0,
    0.0,
  )
  let mut bodies = 0
  let mut decorations = 0
  for op in ops {
    match op {
      @app.BlockOutline(_, _, _, _, _, _, _) => bodies = bodies + 1
      @app.BlockArm(_, _, _, _, _) => decorations = decorations + 1
      _ => ()
    }
  }
  assert_eq(bodies, 2)
  assert_eq(decorations, 0)
}

///|
/// M7② headless 帧验收：单轮廓 PathSpec（一次 fill+stroke，榫头/卯口
/// 在轮廓动词里）与字段访问胶囊（pill 洞）走真实绘制指令流。
test "headless acceptance: outline path and field access pill" {
  // 1) 单轮廓几何：榫头凸起（y-5）与卯口凹口（y+h+5）都在路径动词里
  let verbs = @app.block_outline_path(10.0, 20.0, 200.0, 30.0, true, true)
  let mut has_tab_bump = false
  let mut has_notch_dip = false
  // 卯口肩点必须在**底边** y+h=50——抓到顶边 y=20 会让路径自交,
  // Skia 非零环绕填充出贯穿整行的楔形（实测缺陷,快照锁死）
  let mut shoulder_left = false
  let mut shoulder_right = false
  for verb in verbs {
    match verb {
      @core.LineTo(p) => {
        if p.y == 15.0 {
          has_tab_bump = true
        }
        if p.y == 55.0 {
          has_notch_dip = true
        }
        if p.x == 30.0 && p.y == 50.0 {
          shoulder_left = true
        }
        if p.x == 48.0 && p.y == 50.0 {
          shoulder_right = true
        }
      }
      _ => ()
    }
  }
  assert_true(has_tab_bump)
  assert_true(has_notch_dip)
  assert_true(shoulder_left)
  assert_true(shoulder_right)
  // 2) 一次 fill+stroke：绘制指令流里只有一条 DrawPath
  let ctx = @views.PaintContext::new()
  @app.paint_block_outline(
    ctx,
    10.0,
    20.0,
    200.0,
    30.0,
    @blocks.BkCall,
    true,
    true,
  )
  let commands = ctx.finish()
  assert_eq(commands.length(), 1)
  match commands[0] {
    @core.DrawPath(path) => {
      assert_true(path.fill is Some(_))
      assert_true(path.stroke is Some(_))
    }
    _ => fail("块体应为单轮廓路径")
  }
  // 3) 字段访问胶囊：FieldAccess 槽 pill=true，普通运算槽 pill=false
  let blocks = @blocks.block_chain([
    @ir.Assign("y", @ir.FieldAccess(@ir.Var("person"), "名字")),
    @ir.Assign("z", @ir.Binary(@ir.Add, @ir.Var("a"), @ir.Var("b"))),
  ])
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0)
  let ops = @app.blocks_draw_plan(
    blocks,
    blocks.map(item => item.text),
    rects,
    -1,
    "",
    None,
    0.0,
    0.0,
  )
  let mut field_pill = false
  let mut plain_hole = false
  for op in ops {
    match op {
      @app.SlotHole(_, _, _, _, _, pill) =>
        if pill {
          field_pill = true
        } else {
          plain_hole = true
        }
      _ => ()
    }
  }
  assert_true(field_pill)
  assert_true(plain_hole)
}
