///|
using @views {
  canvas,
  fill_rounded_rect,
  stroke_rounded_rect,
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
/// 画布绘制计划：纯数据，视图闭包只负责解释执行。
/// 测试可断言计划规模随节点数线性增长（帧基线的结构化代理）。
enum CanvasDrawOp {
  FillNode(@geometry.Rect, @graphics.Color)
  StrokeNode(@geometry.Rect, @graphics.Color, Double)
  NodeText(String, @geometry.Rect, @graphics.Color)
  EdgeLine(@geometry.Point, @geometry.Point, @graphics.Color)
}

///|
/// 节点的画布本地矩形（图坐标）。
pub fn node_rect(node : BlockNode) -> @geometry.Rect {
  @geometry.Rect::new(x=node.x, y=node.y, width=node_width, height=node_height)
}

///|
/// 命中测试（图坐标）：后画的在上，倒序命中第一个包含点的节点。
pub fn hit_test(graph : BlockGraph, x : Double, y : Double) -> BlockNode? {
  let mut i = graph.nodes.length()
  while i > 0 {
    i = i - 1
    let node = graph.nodes[i]
    if x >= node.x &&
      x <= node.x + node_width &&
      y >= node.y &&
      y <= node.y + node_height {
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
/// 生成画布的纯数据绘制计划（图坐标）：先边后节点，选中节点追加描边，
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
    ops.push(FillNode(rect, color))
    ops.push(
      NodeText(node.title, rect, @graphics.Color::rgba(r=1.0, g=1.0, b=1.0)),
    )
    match selection {
      Some(selected) =>
        if selected == node.id {
          ops.push(
            StrokeNode(
              @geometry.Rect::new(
                x=rect.origin.x - 3.0,
                y=rect.origin.y - 3.0,
                width=rect.size.width + 6.0,
                height=rect.size.height + 6.0,
              ),
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
            StrokeNode(
              @geometry.Rect::new(
                x=rect.origin.x - 6.0,
                y=rect.origin.y - 6.0,
                width=rect.size.width + 12.0,
                height=rect.size.height + 12.0,
              ),
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
          FillNode(rect, color) =>
            fill_rounded_rect(
              ctx,
              @graphics.RoundedRect::new(rect~, radius=10.0),
              @graphics.Brush::solid(color),
            )
          StrokeNode(rect, color, width) =>
            stroke_rounded_rect(
              ctx,
              @graphics.RoundedRect::new(rect~, radius=12.0),
              @graphics.Brush::solid(color),
              width,
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
