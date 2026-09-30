///|
/// 积木画布：语句链的 Scratch 式投影——拼图块外形（榫头/卯口）+ 分类配色 +
/// 同层拖拽重排。绘制计划是纯数据（可快照测试）；命中/落槽/拖拽在
/// update 里转 typed Msg。与设计画布同契约：paint 命令是窗口全局坐标、
/// measure 忽略约束返回自身尺寸、不用 PushClip/PushTransform。

///|
/// 布局常量（画布局部坐标）。
let block_step : Double = 40.0

///|
let block_height : Double = 34.0

///|
let block_indent : Double = 24.0

///|
let block_margin : Double = 10.0

///|
let block_width : Double = 430.0

///|
/// 按可用宽度把标签截成「…」结尾（设计稿 `.blk` 的 `text-overflow: ellipsis`）。
///
/// 逐字符累加而不是按平均字宽估算：块标签是中英混排
/// （`命令 set_text(显示, "你好，MoUI Studio！")`），中英字宽差近一倍，
/// 用平均值会算出「刚好放下」然后仍然溢出几个字符。
/// 口径与 `text_estimate_width` 一致（ASCII 7.9 / 全角 13.0），并留
/// `WIDTH_SAFETY` 的余量：实测估算比实渲**偏窄约 2%**（「…悬停积木…」
/// 估算 294.4、实渲 300.8），所以按 98% 预算截断，宁可早切一个字也不要
/// 越界半个字。
///
/// 两个已踩过的坑：
/// ① 曾按 `12/13` 折算字号（以为文字按 12pt 渲染）——实际主题正文是
///    16pt，凭空折算让预算**虚高 8%**，截断了却仍然溢出；
/// ② 只截断不预留余量，2% 的估算误差在长句上就是 5-6pt 的越界。
pub const LABEL_WIDTH_SAFETY : Double = 0.98

///|
pub fn fit_label(label : String, max_width : Double) -> String {
  let budget = max_width * LABEL_WIDTH_SAFETY
  let full = text_estimate_width(label)
  if full <= budget {
    return label
  }
  // 省略号本身也要占位（全角，13.0 @13pt）
  let ellipsis_cost = text_estimate_width("…")
  let mut used = 0.0
  let mut kept = ""
  for c in label {
    let cost = if c.to_int() < 0x80 { 7.9 } else { 13.0 }
    if used + cost + ellipsis_cost > budget {
      break
    }
    used = used + cost
    kept = kept + c.to_string()
  }
  kept + "…"
}

///|
/// 语句链逐项矩形（顺序即链条顺序；x 随深度缩进）。
/// 积木行矩形。`avail_width` 是画布可用宽：**必须传**（默认值是历史常量，
/// 只在没有视口信息的纯逻辑测试里用）。
///
/// 为什么要有这个参数：`block_width = 430` 是设计宽，而积木窗格在 1280 窗
/// 口下只剩 ~370——不夹取的话块体与块文字会直接画到右栏上面去（实测块文字
/// 右缘 1289 > 裁剪区右缘 1164）。这里的夹取和上层 `scroll_view` 的裁剪区
/// 是两个层次的保护，缺一不可：夹取让块**长对了**，裁剪区只是兜底。
pub fn blocks_item_rects(
  blocks : Array[@blocks.BlockItem],
  avail_width? : Double = block_width,
) -> Array[@geometry.Rect] {
  let rects : Array[@geometry.Rect] = []
  let budget = (avail_width - block_margin * 2.0).max(160.0)
  for item in blocks {
    let x = block_margin + item.depth.to_double() * block_indent
    let width = (budget - item.depth.to_double() * block_indent).max(120.0)
    rects.push(
      @geometry.Rect::new(
        x~,
        y=block_margin + rects.length().to_double() * block_step,
        width~,
        height=block_height,
      ),
    )
  }
  rects
}

///|
/// 命中测试：返回压点所在行（链条下标），无命中返回 -1。
pub fn blocks_hit_index(
  blocks : Array[@blocks.BlockItem],
  x : Double,
  y : Double,
) -> Int {
  let rects = blocks_item_rects(blocks)
  let mut i = rects.length()
  while i > 0 {
    i = i - 1
    let r = rects[i]
    if x >= r.origin.x &&
      x <= r.origin.x + r.size.width &&
      y >= r.origin.y &&
      y <= r.origin.y + r.size.height {
      return i
    }
  }
  -1
}

///|
pub fn blocks_parent_of(path : Array[Int]) -> Array[Int] {
  let parent : Array[Int] = []
  let mut i = 0
  while i < path.length() - 1 {
    parent.push(path[i])
    i = i + 1
  }
  parent
}

///|
pub fn blocks_same_path(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 落槽计算：同层兄弟中，中心线在指针上方的个数（0..=兄弟数）。
/// 只在拖拽块的兄弟层内计数——跨层移动不在 v1 范围。
pub fn blocks_drop_slot(
  blocks : Array[@blocks.BlockItem],
  list_path : Array[Int],
  pointer_y : Double,
  rects : Array[@geometry.Rect],
) -> Int {
  let mut slot = 0
  let mut i = 0
  for item in blocks {
    if blocks_same_path(blocks_parent_of(item.path), list_path) {
      let r = rects[i]
      if r.origin.y + r.size.height / 2.0 <= pointer_y {
        slot = slot + 1
      }
    }
    i = i + 1
  }
  slot
}

///|
/// 拼图块绘制计划：逐块 = 体 + 文本 +（同层连续时）顶部榫头与底部卯口 +
/// 选中/聚光灯描边 + 拖拽落槽指示线。display_texts 与 blocks 一一对应
/// （控制流块的本地化标签由 blocks_panel 预渲染，draw 闭包拿不到翻译器）。
pub fn blocks_draw_plan(
  blocks : Array[@blocks.BlockItem],
  display_texts : Array[String],
  rects : Array[@geometry.Rect],
  selected : Int,
  spotlight : String,
  drag : BlocksDragState?,
  dx : Double,
  dy : Double,
) -> Array[BlocksDrawOp] {
  let ops : Array[BlocksDrawOp] = []
  // 拖拽落槽指示线：同层兄弟的第 to 槽位
  match drag {
    None => ()
    Some(d) => {
      let mut mark_y : Double? = None
      let mut mark_w : Double = 300.0
      let mut seen = 0
      let mut i = 0
      for item in blocks {
        if blocks_same_path(blocks_parent_of(item.path), d.list_path) {
          let r = rects[i]
          mark_w = r.size.width
          if seen == d.to {
            mark_y = Some(r.origin.y - 3.0)
          }
          seen = seen + 1
        }
        i = i + 1
      }
      if seen == d.to {
        // 落到最后一个兄弟之后：线画在其底缘下方
        let mut i2 = 0
        for item in blocks {
          if blocks_same_path(blocks_parent_of(item.path), d.list_path) {
            let r = rects[i2]
            mark_y = Some(r.origin.y + r.size.height + 3.0)
          }
          i2 = i2 + 1
        }
      }
      match mark_y {
        Some(y) => ops.push(InsertMark(dx + 10.0, dy + y, mark_w))
        None => ()
      }
    }
  }
  let mut i = 0
  for item in blocks {
    let r = rects[i]
    let x = r.origin.x + dx
    let y = r.origin.y + dy
    let w = r.size.width
    let h = r.size.height
    let display = if i < display_texts.length() { display_texts[i] } else { "" }
    let is_selected = i == selected
    let is_spotlight = item.text != "" && item.text == spotlight
    ops.push(BlockBody(x, y, w, h, item.kind))
    // 榫头：本块在列表中不是第一条才画——首块的上一项是父块（新栈开始）
    if item.path.length() > 0 && item.path[item.path.length() - 1] > 0 {
      ops.push(BlockTab(x + 20.0, y - 5.0, 18.0, item.kind))
    }
    // 卯口：底边中央挖去画布底色，下一块的榫头插进来
    if item.path.length() > 0 {
      ops.push(BlockNotchCut(x + 20.0, y + h - 1.0))
    }
    let marker = if is_spotlight { "▶ " } else { "" }
    // 标签按**块宽**截断（设计稿 .blk 是 `text-overflow: ellipsis` 口径）：
    // 块体已经夹到画布宽，但长语句仍会顶到块右缘之外——用省略号收尾，
    // 让「这里有更多内容」是**看得见**的，而不是被画布边缘硬切掉一半。
    ops.push(
      BlockLabel(
        "\{marker}\{display}",
        x + 10.0,
        y + 8.0,
        (w - 20.0).max(40.0),
        fit_label("\{marker}\{display}", (w - 20.0).max(40.0)),
      ),
    )
    if is_selected || is_spotlight {
      ops.push(BlockStroke(x, y, w, h))
    }
    i = i + 1
  }
  ops
}

///|
pub(all) enum BlocksDrawOp {
  BlockBody(Double, Double, Double, Double, @blocks.BlockKind)
  BlockTab(Double, Double, Double, @blocks.BlockKind)
  BlockNotchCut(Double, Double)
  BlockLabel(String, Double, Double, Double, String)
  BlockStroke(Double, Double, Double, Double)
  InsertMark(Double, Double, Double)
}

///|
/// 画布视图：绘制 + 点选/拖拽事件转 typed Msg（画布局部坐标）。
pub fn blocks_canvas(
  blocks : Array[@blocks.BlockItem],
  display_texts : Array[String],
  selected : Int,
  spotlight : String,
  drag : BlocksDragState?,
  width : Double,
  height : Double,
  semantics_label : String,
) -> @moui.View[Msg] {
  @views.container(
    canvas(
      measure=fn(_constraints) {
        // 宽度必须由调用方给定：scroll_view 给子节点的是无界约束
        // （纵向滚动、横向不滚），画布自己量不出视口宽——写死 470 会
        // 在窄窗格里溢出到隔壁面板。
        @geometry.Size::new(width=width.max(160.0), height=height.max(160.0))
      },
      draw=fn(ctx, frame) {
        let dx = frame.origin.x
        let dy = frame.origin.y
        let rects = blocks_item_rects(blocks, avail_width=width)
        let ops = blocks_draw_plan(
          blocks, display_texts, rects, selected, spotlight, drag, dx, dy,
        )
        for op in ops {
          match op {
            BlockBody(x, y, w, h, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=h),
                  radius=6.0,
                ),
                @graphics.Brush::solid(block_fill(kind)),
              )
            BlockTab(x, y, w, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=7.0),
                  radius=2.0,
                ),
                @graphics.Brush::solid(block_fill(kind)),
              )
            BlockNotchCut(x, y) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=18.0, height=6.0),
                  radius=2.0,
                ),
                @graphics.Brush::solid(block_notch_color()),
              )
            BlockLabel(_text, x, y, maxw, fitted) =>
              draw_text(
                ctx,
                @text.TextRun::new(
                  text=fitted,
                  frame=@geometry.Rect::new(x~, y~, width=maxw, height=20.0),
                  font=@text.FontSpec::new(size=12.0),
                  color=block_text_color(),
                ),
              )
            BlockStroke(x, y, w, h) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=x - 2.0,
                    y=y - 2.0,
                    width=w + 4.0,
                    height=h + 4.0,
                  ),
                  radius=8.0,
                ),
                @graphics.Brush::solid(ide_accent()),
                2.0,
              )
            InsertMark(x, y, w) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(x~, y~, width=w, height=3.0),
                  radius=1.5,
                ),
                @graphics.Brush::solid(ide_accent()),
              )
          }
        }
      },
      semantics_label~,
    )
    .on_tap_with_frame(fn(position, frame) {
      Msg::BlocksCanvasTap(
        position.x - frame.origin.x,
        position.y - frame.origin.y,
      )
    })
    .on_drag_with_frame(fn(event, frame) {
      let lx = event.position.x - frame.origin.x
      let ly = event.position.y - frame.origin.y
      if event.phase == @views.DragGesturePhase::Started {
        Msg::BlocksCanvasPress(lx, ly)
      } else if event.phase == @views.DragGesturePhase::Changed {
        Msg::BlocksCanvasDragTo(lx, ly)
      } else {
        Msg::BlocksCanvasRelease
      }
    }),
    padding=0.0,
  )
}
