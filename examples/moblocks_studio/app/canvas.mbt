///|
using @views {
  canvas,
  draw_text,
  draw_path,
  push_clip,
  pop_clip,
  push_transform,
  pop_transform,
}

///|
let node_width = 168.0

///|
let node_height = 72.0

///|
/// 榫卯半径：顶边凹槽与底边凸头共用同一半圆几何，上下积木可视觉咬合。
let puzzle_tab_radius = 10.0

///|
/// 积木主体圆角半径。
let block_corner_radius = 8.0

///|
/// 四分之一圆弧的 cubic 逼近系数。
let arc_kappa = 0.5522847498

///|
/// 画布绘制计划：纯数据，视图闭包只负责解释执行。
/// 测试可断言计划规模随节点数线性增长（帧基线的结构化代理）。
enum CanvasDrawOp {
  FillBlock(Array[@graphics.PathVerb], @graphics.Color)
  StrokeBlock(Array[@graphics.PathVerb], @graphics.Color, Double)
  NodeText(String, @geometry.Rect, @graphics.Color)
  EdgeLine(@geometry.Point, @geometry.Point, @graphics.Color)
}

///|
/// 节点的画布本地矩形（图坐标）。
pub fn node_rect(node : BlockNode) -> @geometry.Rect {
  @geometry.Rect::new(x=node.x, y=node.y, width=node_width, height=node_height)
}

///|
/// 下半圆弧从左到右（经过最低点）的 cubic 段，凹槽沿顶边左→右遍历时使用。
fn puzzle_arc_left_to_right(
  cx : Double,
  cy : Double,
  r : Double,
) -> Array[@graphics.PathVerb] {
  let k = arc_kappa * r
  [
    // (cx-r, cy) -> (cx, cy+r)
    @graphics.PathVerb::CubicTo(
      @geometry.Point::new(x=cx - r, y=cy + k),
      @geometry.Point::new(x=cx - k, y=cy + r),
      @geometry.Point::new(x=cx, y=cy + r),
    ),
    // (cx, cy+r) -> (cx+r, cy)
    @graphics.PathVerb::CubicTo(
      @geometry.Point::new(x=cx + k, y=cy + r),
      @geometry.Point::new(x=cx + r, y=cy + k),
      @geometry.Point::new(x=cx + r, y=cy),
    ),
  ]
}

///|
/// 下半圆弧从右到左（经过最低点）的 cubic 段，凸头沿底边右→左遍历时使用。
fn puzzle_arc_right_to_left(
  cx : Double,
  cy : Double,
  r : Double,
) -> Array[@graphics.PathVerb] {
  let k = arc_kappa * r
  [
    // (cx+r, cy) -> (cx, cy+r)
    @graphics.PathVerb::CubicTo(
      @geometry.Point::new(x=cx + r, y=cy + k),
      @geometry.Point::new(x=cx + k, y=cy + r),
      @geometry.Point::new(x=cx, y=cy + r),
    ),
    // (cx, cy+r) -> (cx-r, cy)
    @graphics.PathVerb::CubicTo(
      @geometry.Point::new(x=cx - k, y=cy + r),
      @geometry.Point::new(x=cx - r, y=cy + k),
      @geometry.Point::new(x=cx - r, y=cy),
    ),
  ]
}

///|
/// 积木榫卯外轮廓（图坐标）：圆角矩形主体 + 顶边凹槽 + 底边凸头。
/// 框架没有路径 clip，凹槽必须画进外轮廓而非挖洞；inflate>0 生成外扩
/// 轮廓供选中/聚光灯描边（凸头半径增大、凹槽半径相应收窄）。
fn block_outline_verbs(
  rect : @geometry.Rect,
  inflate : Double,
) -> Array[@graphics.PathVerb] {
  let x0 = rect.origin.x - inflate
  let y0 = rect.origin.y - inflate
  let x1 = rect.origin.x + rect.size.width + inflate
  let y1 = rect.origin.y + rect.size.height + inflate
  let c = block_corner_radius + inflate
  let cx = (x0 + x1) / 2.0
  let tab_r = puzzle_tab_radius + inflate
  let notch_r = puzzle_tab_radius - inflate
  let verbs : Array[@graphics.PathVerb] = [
    @graphics.PathVerb::MoveTo(@geometry.Point::new(x=x0 + c, y=y0)),
  ]
  // 顶边：左段 → 凹槽（挖进主体）→ 右段
  if notch_r > 1.0 {
    verbs.push(
      @graphics.PathVerb::LineTo(@geometry.Point::new(x=cx - notch_r, y=y0)),
    )
    for verb in puzzle_arc_left_to_right(cx, y0, notch_r) {
      verbs.push(verb)
    }
  }
  verbs.push(@graphics.PathVerb::LineTo(@geometry.Point::new(x=x1 - c, y=y0)))
  verbs.push(
    @graphics.PathVerb::QuadTo(
      @geometry.Point::new(x=x1, y=y0),
      @geometry.Point::new(x=x1, y=y0 + c),
    ),
  )
  verbs.push(@graphics.PathVerb::LineTo(@geometry.Point::new(x=x1, y=y1 - c)))
  verbs.push(
    @graphics.PathVerb::QuadTo(
      @geometry.Point::new(x=x1, y=y1),
      @geometry.Point::new(x=x1 - c, y=y1),
    ),
  )
  // 底边：右段 → 凸头（凸出主体下缘）→ 左段
  verbs.push(
    @graphics.PathVerb::LineTo(@geometry.Point::new(x=cx + tab_r, y=y1)),
  )
  for verb in puzzle_arc_right_to_left(cx, y1, tab_r) {
    verbs.push(verb)
  }
  verbs.push(@graphics.PathVerb::LineTo(@geometry.Point::new(x=x0 + c, y=y1)))
  verbs.push(
    @graphics.PathVerb::QuadTo(
      @geometry.Point::new(x=x0, y=y1),
      @geometry.Point::new(x=x0, y=y1 - c),
    ),
  )
  verbs.push(@graphics.PathVerb::LineTo(@geometry.Point::new(x=x0, y=y0 + c)))
  verbs.push(
    @graphics.PathVerb::QuadTo(
      @geometry.Point::new(x=x0, y=y0),
      @geometry.Point::new(x=x0 + c, y=y0),
    ),
  )
  verbs.push(@graphics.PathVerb::Close)
  verbs
}

///|
/// 榫卯形状命中（图坐标）：底边凸头半圆 ∪（主体矩形 − 顶边凹槽半圆）。
fn block_contains(node : BlockNode, x : Double, y : Double) -> Bool {
  let cx = node.x + node_width / 2.0
  // 底边凸头凸出主体下缘
  let tab_dx = x - cx
  let tab_dy = y - (node.y + node_height)
  if tab_dx * tab_dx + tab_dy * tab_dy <= puzzle_tab_radius * puzzle_tab_radius {
    return true
  }
  if x < node.x ||
    x > node.x + node_width ||
    y < node.y ||
    y > node.y + node_height {
    return false
  }
  // 顶边凹槽挖空区域不命中
  let notch_dx = x - cx
  let notch_dy = y - node.y
  if notch_dx * notch_dx + notch_dy * notch_dy <
    puzzle_tab_radius * puzzle_tab_radius {
    return false
  }
  true
}

///|
/// 命中测试（图坐标）：后画的在上，倒序命中第一个包含点的节点。
pub fn hit_test(graph : BlockGraph, x : Double, y : Double) -> BlockNode? {
  let mut i = graph.nodes.length()
  while i > 0 {
    i = i - 1
    let node = graph.nodes[i]
    if block_contains(node, x, y) {
      return Some(node)
    }
  }
  None
}

///|
fn edge_line_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.55, g=0.58, b=0.65)
}

///|
/// 生成画布的纯数据绘制计划（图坐标）：先边后节点，选中节点追加外扩描边，
/// 聚光灯节点（当前执行/等待确认）追加高亮描边。
pub fn canvas_draw_plan(
  graph : BlockGraph,
  selection : Int?,
  spotlight : Int?,
) -> Array[CanvasDrawOp] {
  let specs = block_catalog()
  let ops : Array[CanvasDrawOp] = []
  for edge in graph.edges {
    match (graph.find_node(edge.from), graph.find_node(edge.to)) {
      (Some(from), Some(to)) => {
        let a = @geometry.Point::new(
          x=from.x + node_width / 2.0,
          y=from.y + node_height,
        )
        let b = @geometry.Point::new(x=to.x + node_width / 2.0, y=to.y)
        ops.push(EdgeLine(a, b, edge_line_color()))
      }
      _ => ()
    }
  }
  for node in graph.nodes {
    let color = match find_spec(specs, node.kind) {
      Some(spec) => category_color(spec.category)
      None => @graphics.Color::rgba(r=0.5, g=0.5, b=0.5)
    }
    let rect = node_rect(node)
    ops.push(FillBlock(block_outline_verbs(rect, 0.0), color))
    ops.push(
      NodeText(node.title, rect, @graphics.Color::rgba(r=1.0, g=1.0, b=1.0)),
    )
    match selection {
      Some(selected) =>
        if selected == node.id {
          ops.push(
            StrokeBlock(
              block_outline_verbs(rect, 3.0),
              @graphics.Color::rgba(r=0.10, g=0.24, b=0.86),
              2.5,
            ),
          )
        }
      None => ()
    }
    match spotlight {
      Some(lit) =>
        if lit == node.id {
          ops.push(
            StrokeBlock(
              block_outline_verbs(rect, 6.0),
              @graphics.Color::rgba(r=0.99, g=0.77, b=0.10),
              3.5,
            ),
          )
        }
      None => ()
    }
  }
  ops
}

///|
/// 积木画布：canvas 绘制 + 拖拽事件转 typed Msg。
/// 视图只转发画布本地坐标；命中/节点拖动/平移/缩放的逻辑在 update 里。
pub fn block_canvas(
  graph : BlockGraph,
  selection : Int?,
  spotlight : Int?,
  viewport_x : Double,
  viewport_y : Double,
  viewport_zoom : Double,
) -> @moui.View[Msg] {
  canvas(
    measure=fn(constraints) {
      // 保持远小于 flex 槽位，避免测量溢出撑破 row 命中区
      constraints.constrain(@geometry.Size::new(width=480.0, height=360.0))
    },
    draw=fn(ctx, frame) {
      push_clip(ctx, frame)
      // 视口变换：屏幕 = (图坐标 - 视口原点) × 缩放
      push_transform(ctx, @graphics.Transform2D::{
        a: viewport_zoom,
        b: 0.0,
        c: 0.0,
        d: viewport_zoom,
        tx: frame.origin.x - viewport_x * viewport_zoom,
        ty: frame.origin.y - viewport_y * viewport_zoom,
      })
      for op in canvas_draw_plan(graph, selection, spotlight) {
        match op {
          FillBlock(verbs, color) =>
            draw_path(
              ctx,
              @graphics.PathSpec::new(
                verbs~,
                fill=Some(@graphics.Brush::solid(color)),
              ),
            )
          StrokeBlock(verbs, color, width) =>
            draw_path(
              ctx,
              @graphics.PathSpec::new(
                verbs~,
                stroke=Some(@graphics.Brush::solid(color)),
                stroke_width=width,
              ),
            )
          NodeText(content, rect, color) =>
            draw_text(
              ctx,
              @text.TextRun::new(
                text=content,
                frame=rect,
                font=@text.FontSpec::new(size=13.0),
                color~,
              ),
            )
          EdgeLine(a, b, color) =>
            draw_path(
              ctx,
              @graphics.PathSpec::new(
                verbs=[
                  @graphics.PathVerb::MoveTo(a),
                  @graphics.PathVerb::LineTo(b),
                ],
                stroke=Some(@graphics.Brush::solid(color)),
                stroke_width=1.6 / viewport_zoom,
              ),
            )
        }
      }
      pop_transform(ctx)
      pop_clip(ctx)
    },
    semantics_label="积木画布",
  ).on_drag_with_frame(fn(event, frame) {
    let lx = event.position.x - frame.origin.x
    let ly = event.position.y - frame.origin.y
    let msg = if event.phase == @views.DragGesturePhase::Started {
      CanvasPress(lx, ly)
    } else if event.phase == @views.DragGesturePhase::Changed {
      CanvasDragTo(lx, ly)
    } else {
      CanvasRelease(lx, ly)
    }
    msg
  })
}
