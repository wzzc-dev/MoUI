///|
/// 表单设计器画布：设计坐标系固定 640×480。
/// 绘制计划是纯数据；命中测试与拖拽在 update 里转 typed Msg。
using @views {canvas, draw_text, fill_rounded_rect, stroke_rounded_rect}

///|
let design_width : Double = 640.0

///|
let design_height : Double = 480.0

///|
fn kind_fill(kind : @ir.ControlKind) -> @graphics.Color {
  match kind {
    @ir.Button => @graphics.Color::rgba(r=0.22, g=0.45, b=0.86)
    @ir.Label => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    @ir.TextField => @graphics.Color::rgba(r=0.80, g=0.55, b=0.16)
    @ir.CheckBox => @graphics.Color::rgba(r=0.45, g=0.40, b=0.75)
    @ir.ListBox => @graphics.Color::rgba(r=0.20, g=0.55, b=0.58)
    @ir.Table => @graphics.Color::rgba(r=0.60, g=0.35, b=0.35)
  }
}

///|
fn kind_fill_light(kind : @ir.ControlKind) -> @graphics.Color {
  match kind {
    @ir.Button => @graphics.Color::rgba(r=0.55, g=0.70, b=0.93)
    @ir.Label => @graphics.Color::rgba(r=0.62, g=0.80, b=0.66)
    @ir.TextField => @graphics.Color::rgba(r=0.93, g=0.78, b=0.55)
    @ir.CheckBox => @graphics.Color::rgba(r=0.74, g=0.70, b=0.90)
    @ir.ListBox => @graphics.Color::rgba(r=0.60, g=0.82, b=0.84)
    @ir.Table => @graphics.Color::rgba(r=0.86, g=0.68, b=0.68)
  }
}

///|
/// 控件在设计坐标系中的矩形。
pub fn control_rect(control : @ir.Control) -> @geometry.Rect {
  @geometry.Rect::new(
    x=control.x.to_double(),
    y=control.y.to_double(),
    width=control.width.to_double(),
    height=control.height.to_double(),
  )
}

///|
/// 命中测试（设计坐标）：后画的在上，倒序取第一个命中。
pub fn hit_test_control(
  controls : Array[@ir.Control],
  x : Double,
  y : Double,
) -> @ir.Control? {
  let mut i = controls.length()
  while i > 0 {
    i = i - 1
    let control = controls[i]
    let rect = control_rect(control)
    if x >= rect.origin.x &&
      x <= rect.origin.x + rect.size.width &&
      y >= rect.origin.y &&
      y <= rect.origin.y + rect.size.height {
      return Some(control)
    }
  }
  None
}

///|
pub(all) enum DesignDrawOp {
  FillControl(@geometry.Rect, @ir.ControlKind)
  ControlLabel(String, @geometry.Rect, @graphics.Color)
  ControlText(String, @geometry.Rect, @graphics.Color)
  ControlRows(@geometry.Rect)
  SelectionStroke(@geometry.Rect)
  SelectionHandle(@geometry.Rect)
  WindowFrame(@geometry.Rect)
  GridDot(@geometry.Rect)
  GuideV(Double)
  GuideH(Double)
}

///|
/// 把设计坐标矩形平移到窗口全局坐标。
fn place_rect(
  rect : @geometry.Rect,
  dx : Double,
  dy : Double,
) -> @geometry.Rect {
  @geometry.Rect::new(
    x=rect.origin.x + dx,
    y=rect.origin.y + dy,
    width=rect.size.width,
    height=rect.size.height,
  )
}

///|
/// 对齐容差（设计坐标 px）：拖拽边缘与其他边缘差 ≤ 4 即吸附显示参考线。
fn near_edge(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 4.0
}

///|
/// 拖拽对齐参考线（设计坐标）：被拖控件的左/右/水平中心、上/下/垂直中心
/// 与画布三线（边/中心）及其他控件边缘对齐时，返回要画的参考线位置。
fn alignment_guides(
  program : Array[@ir.Control],
  drag_name : String,
  dragged : @geometry.Rect,
) -> (Array[Double], Array[Double]) {
  let tol = 4.0
  let verticals : Array[Double] = []
  let horizontals : Array[Double] = []
  let d_left = dragged.origin.x
  let d_right = dragged.origin.x + dragged.size.width
  let d_cx = dragged.origin.x + dragged.size.width / 2.0
  let d_top = dragged.origin.y
  let d_bottom = dragged.origin.y + dragged.size.height
  let d_cy = dragged.origin.y + dragged.size.height / 2.0
  fn push_unique(arr : Array[Double], value : Double) -> Unit {
    for existing in arr {
      if (existing - value).abs() <= tol {
        return
      }
    }
    arr.push(value)
  }

  for target in [0.0, design_width / 2.0, design_width] {
    if near_edge(d_left, target) ||
      near_edge(d_right, target) ||
      near_edge(d_cx, target) {
      push_unique(verticals, target)
    }
  }
  for target in [0.0, design_height / 2.0, design_height] {
    if near_edge(d_top, target) ||
      near_edge(d_bottom, target) ||
      near_edge(d_cy, target) {
      push_unique(horizontals, target)
    }
  }
  for control in program {
    if control.name == drag_name {
      continue
    }
    let r = control_rect(control)
    for
      target in [
        r.origin.x,
        r.origin.x + r.size.width,
        r.origin.x + r.size.width / 2.0,
      ] {
      if near_edge(d_left, target) ||
        near_edge(d_right, target) ||
        near_edge(d_cx, target) {
        push_unique(verticals, target)
      }
    }
    for
      target in [
        r.origin.y,
        r.origin.y + r.size.height,
        r.origin.y + r.size.height / 2.0,
      ] {
      if near_edge(d_top, target) ||
        near_edge(d_bottom, target) ||
        near_edge(d_cy, target) {
        push_unique(horizontals, target)
      }
    }
  }
  (verticals, horizontals)
}

///|
/// 设计画布绘制计划：窗口底板 → 网格点阵 → 控件（名字条 + 文本 + 行）→
/// 选中描边与角手柄 → 拖拽对齐参考线。
/// dx/dy 是画布 frame 在窗口中的原点——MoUI paint 契约是窗口全局坐标，
/// 命令必须自带偏移（render 管线按原样收集命令，不做逐层平移）。
pub fn design_draw_plan(
  program : @ir.MomaoProgram,
  selection : String,
  drag_control : String?,
  dx : Double,
  dy : Double,
) -> Array[DesignDrawOp] {
  let ops : Array[DesignDrawOp] = []
  ops.push(
    WindowFrame(
      place_rect(
        @geometry.Rect::new(
          x=0.0,
          y=0.0,
          width=design_width,
          height=design_height,
        ),
        dx,
        dy,
      ),
    ),
  )
  // 网格点阵（32px 步进）：给画布「设计图纸」质感
  let mut gx = 32.0
  while gx < design_width {
    let mut gy = 32.0
    while gy < design_height {
      ops.push(
        GridDot(
          @geometry.Rect::new(x=gx + dx, y=gy + dy, width=2.0, height=2.0),
        ),
      )
      gy = gy + 32.0
    }
    gx = gx + 32.0
  }
  for control in program.controls {
    let rect = place_rect(control_rect(control), dx, dy)
    ops.push(FillControl(rect, control.kind))
    let name_rect = @geometry.Rect::new(
      x=rect.origin.x,
      y=rect.origin.y,
      width=rect.size.width,
      height=(rect.size.height * 0.38).min(18.0).max(14.0),
    )
    ops.push(ControlLabel(control.name, name_rect, kind_fill(control.kind)))
    ops.push(
      ControlText(
        control.text,
        rect,
        @graphics.Color::rgba(r=0.12, g=0.13, b=0.16),
      ),
    )
    if control.items.length() > 0 {
      ops.push(ControlRows(rect))
    }
    if selection == control.name {
      ops.push(SelectionStroke(rect))
      // 四角手柄：8x8 实心方块（选中即可拖拽缩放的暗示）
      let h = 4.0
      for
        corner in [
          (rect.origin.x, rect.origin.y),
          (rect.origin.x + rect.size.width, rect.origin.y),
          (rect.origin.x, rect.origin.y + rect.size.height),
          (rect.origin.x + rect.size.width, rect.origin.y + rect.size.height),
        ] {
        ops.push(
          SelectionHandle(
            @geometry.Rect::new(
              x=corner.0 - h,
              y=corner.1 - h,
              width=8.0,
              height=8.0,
            ),
          ),
        )
      }
    }
  }
  // 拖拽中的对齐参考线（朱砂色，画布全高/全宽）
  match drag_control {
    None => ()
    Some(name) =>
      match @ir.find_control(program, name) {
        None => ()
        Some(dragged) => {
          let (verticals, horizontals) = alignment_guides(
            program.controls,
            name,
            control_rect(dragged),
          )
          for x in verticals {
            ops.push(GuideV(x + dx))
          }
          for y in horizontals {
            ops.push(GuideH(y + dy))
          }
        }
      }
  }
  ops
}

///|
/// 表单设计画布：canvas 绘制 + 点选/拖拽事件转 typed Msg（画布局部坐标）。
/// measure 忽略约束返回固定设计尺寸（640x480）——画布不能被行布局拉伸，
/// 否则右侧检查器会被挤出窗口、设计坐标与命中测试失真。
pub fn design_canvas(
  program : @ir.MomaoProgram,
  selection : String,
  drag_control : String?,
) -> @moui.View[Msg] {
  @views.container(
    canvas(
      measure=fn(_constraints) {
        @geometry.Size::new(width=design_width, height=design_height)
      },
      draw=fn(ctx, frame) {
        // MoUI paint 契约：命令是窗口全局坐标，绘制内容用 frame.origin 偏移
        // 进自己的 frame。不用 PushClip/PushTransform——wasm 渲染管线里
        // 画布层内嵌 clip/transform 栈会吞掉整层命令（已实测）。
        let dx = frame.origin.x
        let dy = frame.origin.y
        for op in design_draw_plan(program, selection, drag_control, dx, dy) {
          match op {
            WindowFrame(rect) => {
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=10.0),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.97, g=0.97, b=0.98),
                ),
              )
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=10.0),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.75, g=0.77, b=0.82),
                ),
                1.5,
              )
            }
            FillControl(rect, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=6.0),
                @graphics.Brush::solid(kind_fill_light(kind)),
              )
            ControlLabel(name, rect, color) => {
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=4.0),
                @graphics.Brush::solid(color),
              )
              draw_text(
                ctx,
                @text.TextRun::new(
                  text=name,
                  frame=@geometry.Rect::new(
                    x=rect.origin.x + 6.0,
                    y=rect.origin.y + 1.0,
                    width=(rect.size.width - 8.0).max(0.0),
                    height=rect.size.height,
                  ),
                  font=@text.FontSpec::new(size=11.0),
                  color=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0),
                ),
              )
            }
            ControlText(content, rect, color) =>
              if content != "" {
                draw_text(
                  ctx,
                  @text.TextRun::new(
                    text=content,
                    frame=@geometry.Rect::new(
                      x=rect.origin.x + 8.0,
                      y=rect.origin.y + rect.size.height * 0.45,
                      width=(rect.size.width - 12.0).max(0.0),
                      height=rect.size.height * 0.5,
                    ),
                    font=@text.FontSpec::new(size=13.0),
                    color~,
                  ),
                )
              }
            ControlRows(rect) => {
              let mut row = 0
              while row < 3 {
                let row_y = rect.origin.y + 16.0 + row.to_double() * 14.0
                stroke_rounded_rect(
                  ctx,
                  @graphics.RoundedRect::new(
                    rect=@geometry.Rect::new(
                      x=rect.origin.x + 6.0,
                      y=row_y,
                      width=(rect.size.width - 12.0).max(0.0),
                      height=12.0,
                    ),
                    radius=3.0,
                  ),
                  @graphics.Brush::solid(
                    @graphics.Color::rgba(r=0.55, g=0.56, b=0.60),
                  ),
                  1.0,
                )
                row = row + 1
              }
            }
            SelectionStroke(rect) => {
              let inflate = 3.0
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=rect.origin.x - inflate,
                    y=rect.origin.y - inflate,
                    width=rect.size.width + inflate * 2.0,
                    height=rect.size.height + inflate * 2.0,
                  ),
                  radius=8.0,
                ),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.78, g=0.26, b=0.20),
                ),
                2.5,
              )
            }
            SelectionHandle(rect) => {
              let brush = @graphics.Brush::solid(
                @graphics.Color::rgba(r=0.78, g=0.26, b=0.20),
              )
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=2.0),
                brush,
              )
            }
            GridDot(rect) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect~, radius=1.0),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.85, g=0.86, b=0.90),
                ),
              )
            GuideV(x) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=x - 0.75,
                    y=dy,
                    width=1.5,
                    height=design_height,
                  ),
                  radius=0.0,
                ),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.78, g=0.26, b=0.20),
                ),
                1.5,
              )
            GuideH(y) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=dx,
                    y=y - 0.75,
                    width=design_width,
                    height=1.5,
                  ),
                  radius=0.0,
                ),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.78, g=0.26, b=0.20),
                ),
                1.5,
              )
          }
        }
      },
      semantics_label="表单设计画布",
    )
    // 点选在前：单击（无拖拽位移）只走 tap 识别器，拖拽结束的 tap 以
    // model.drag 是否仍存在区分（见 update 的 CanvasTap 处理）。
    .on_tap_with_frame(fn(position, frame) {
      Msg::CanvasTap(position.x - frame.origin.x, position.y - frame.origin.y)
    })
    .on_drag_with_frame(fn(event, frame) {
      let lx = event.position.x - frame.origin.x
      let ly = event.position.y - frame.origin.y
      if event.phase == @views.DragGesturePhase::Started {
        Msg::CanvasPress(lx, ly)
      } else if event.phase == @views.DragGesturePhase::Changed {
        Msg::CanvasDragTo(lx, ly)
      } else {
        Msg::CanvasRelease(lx, ly)
      }
    }),
    padding=0.0,
  )
}
