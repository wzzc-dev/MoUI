///|
/// 表单设计器画布：设计坐标系固定 640×480。
/// 绘制计划是纯数据；命中测试与拖拽在 update 里转 typed Msg。
using @views {canvas, draw_text, fill_rounded_rect, stroke_rounded_rect}

///|
/// 设计坐标系尺寸单一来源是 @ir.DESIGN_WIDTH/HEIGHT（拖拽与属性编辑共用）。
let design_width : Double = @ir.DESIGN_WIDTH.to_double()

///|
let design_height : Double = @ir.DESIGN_HEIGHT.to_double()

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
/// 角手柄命中半径（设计坐标 px）：手柄绘制为角点为中心的 8x8 方块，
/// 命中区放宽到 6px 半径，指针更好抓。
let handle_hit_radius : Double = 6.0

///|
/// 角手柄命中测试（设计坐标）：手柄只画在选中控件的四角，
/// 手柄中心即控件角点，按下点距角点 ≤ 命中半径即命中该角。
pub fn hit_test_handle(
  control : @ir.Control,
  x : Double,
  y : Double,
) -> @ir.DragCorner? {
  let rect = control_rect(control)
  let corners : Array[(@ir.DragCorner, Double, Double)] = [
    (@ir.CornerNW, rect.origin.x, rect.origin.y),
    (@ir.CornerNE, rect.origin.x + rect.size.width, rect.origin.y),
    (@ir.CornerSW, rect.origin.x, rect.origin.y + rect.size.height),
    (
      @ir.CornerSE,
      rect.origin.x + rect.size.width,
      rect.origin.y + rect.size.height,
    ),
  ]
  for corner in corners {
    let (tag, cx, cy) = corner
    if (x - cx).abs() <= handle_hit_radius &&
      (y - cy).abs() <= handle_hit_radius {
      return Some(tag)
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
/// 对齐容差（设计坐标 px）：拖拽边缘与其他边缘差 ≤ 4 即吸附显示参考线。
fn near_edge(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 4.0
}

///|
/// 网格步长（与画布点阵一致的 32px 设计图纸网格）。
let grid_step : Double = 32.0

///|
/// 网格量化：吸附到最近的 32px 网格线。
fn grid_snap(value : Double) -> Double {
  (value / grid_step).round() * grid_step
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
/// 单轴吸附：从候选 (参考线位置, 对应平移量) 里取平移量最小且 ≤ 容差的一条。
fn best_snap_delta(deltas : Array[(Double, Double)]) -> Double? {
  let tol = 4.0
  let mut best : Double? = None
  let mut best_abs = tol + 1.0
  for candidate in deltas {
    let delta = candidate.1
    let abs = delta.abs()
    if abs <= tol && abs < best_abs {
      best = Some(delta)
      best_abs = abs
    }
  }
  best
}

///|
/// 拖拽移动吸附（设计坐标）：候选控件原点 (x, y) 与控件尺寸给定后，
/// 左/右/水平中心、上/下/垂直中心若与参考线目标（画布三线与其他控件边缘，
/// 与 alignment_guides 同一集合）差 ≤ 4px，就把原点平移到精确对齐。
/// 返回吸附后的原点。参考线目标全部落在画布内，吸附不会越界。
pub fn snap_move_position(
  controls : Array[@ir.Control],
  drag_name : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> (Double, Double) {
  let tol = 4.0
  let (verticals, horizontals) = alignment_guides(
    controls,
    drag_name,
    @geometry.Rect::new(x~, y~, width~, height~),
  )
  let mut snap_x = x
  match
    best_snap_delta(
      {
        let deltas : Array[(Double, Double)] = []
        for target in verticals {
          if (x - target).abs() <= tol {
            deltas.push((target, target - x))
          }
          if (x + width - target).abs() <= tol {
            deltas.push((target, target - (x + width)))
          }
          if (x + width / 2.0 - target).abs() <= tol {
            deltas.push((target, target - (x + width / 2.0)))
          }
        }
        deltas
      },
    ) {
    Some(delta) => snap_x = x + delta
    // 无参考线命中时落 32px 网格（设计图纸点阵的磁吸）
    None => snap_x = grid_snap(x)
  }
  let mut snap_y = y
  match
    best_snap_delta(
      {
        let deltas : Array[(Double, Double)] = []
        for target in horizontals {
          if (y - target).abs() <= tol {
            deltas.push((target, target - y))
          }
          if (y + height - target).abs() <= tol {
            deltas.push((target, target - (y + height)))
          }
          if (y + height / 2.0 - target).abs() <= tol {
            deltas.push((target, target - (y + height / 2.0)))
          }
        }
        deltas
      },
    ) {
    Some(delta) => snap_y = y + delta
    None => snap_y = grid_snap(y)
  }
  (snap_x, snap_y)
}

///|
/// 缩放边缘吸附：先按角位算出提议矩形，再把**移动中的边**向参考线目标
/// （≤4px）或 32px 网格钳制，最后用调整后的指针位重算缩放。
/// 对角固定、夹取纪律仍由 resize_from_corner 保证。
pub fn snap_resize_position(
  controls : Array[@ir.Control],
  drag_name : String,
  control : @ir.Control,
  corner : @ir.DragCorner,
  to_x : Double,
  to_y : Double,
) -> (Double, Double) {
  let tol = 4.0
  let proposed = control.resize_from_corner(
    corner,
    to_x.to_int(),
    to_y.to_int(),
  )
  let rect = control_rect(proposed)
  let (verticals, horizontals) = alignment_guides(controls, drag_name, rect)
  // 移动边：SE→右/下，NW→左/上，NE→右/上，SW→左/下
  let moves_right = match corner {
    @ir.CornerSE | @ir.CornerNE => true
    @ir.CornerNW | @ir.CornerSW => false
  }
  let moves_bottom = match corner {
    @ir.CornerSE | @ir.CornerSW => true
    @ir.CornerNW | @ir.CornerNE => false
  }
  let right = rect.origin.x + rect.size.width
  let bottom = rect.origin.y + rect.size.height
  let mut new_x = to_x
  let mut new_y = to_y
  let x_candidates = {
    let deltas : Array[(Double, Double)] = []
    let edge = if moves_right { right } else { rect.origin.x }
    for target in verticals {
      if (edge - target).abs() <= tol {
        deltas.push((target, target - edge))
      }
    }
    deltas
  }
  let y_candidates = {
    let deltas : Array[(Double, Double)] = []
    let edge = if moves_bottom { bottom } else { rect.origin.y }
    for target in horizontals {
      if (edge - target).abs() <= tol {
        deltas.push((target, target - edge))
      }
    }
    deltas
  }
  match best_snap_delta(x_candidates) {
    Some(delta) => new_x = to_x + delta
    None => new_x = grid_snap(to_x)
  }
  match best_snap_delta(y_candidates) {
    Some(delta) => new_y = to_y + delta
    None => new_y = grid_snap(to_y)
  }
  (new_x, new_y)
}

///|
/// 设计画布绘制计划：窗口底板 → 网格点阵 → 控件（名字条 + 文本 + 行）→
/// 选中描边与角手柄 → 拖拽对齐参考线。全部是**设计坐标**（640×480）；
/// 全局坐标变换（平移 + 等比缩放）在绘制闭包里按 frame 现算，缩放时
/// 命中测试用同一个比例换算，二者永不失配。
pub fn design_draw_plan(
  program : @ir.MomaoProgram,
  selection : String,
  drag_control : String?,
) -> Array[DesignDrawOp] {
  let ops : Array[DesignDrawOp] = []
  ops.push(
    WindowFrame(
      @geometry.Rect::new(
        x=0.0,
        y=0.0,
        width=design_width,
        height=design_height,
      ),
    ),
  )
  // 网格点阵（32px 步进）：给画布「设计图纸」质感
  let mut gx = 32.0
  while gx < design_width {
    let mut gy = 32.0
    while gy < design_height {
      ops.push(GridDot(@geometry.Rect::new(x=gx, y=gy, width=2.0, height=2.0)))
      gy = gy + 32.0
    }
    gx = gx + 32.0
  }
  for control in program.controls {
    let rect = control_rect(control)
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
  // 拖拽中的对齐参考线（智能蓝——与朱砂选中描边区分，拖拽辅助不抢选中语义）
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
            ops.push(GuideV(x))
          }
          for y in horizontals {
            ops.push(GuideH(y))
          }
        }
      }
  }
  ops
}

///|
/// 智能参考线颜色：与选中描边的朱砂区分，拖拽辅助不抢选中语义。
fn guide_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.30, g=0.52, b=0.90)
}

///|
/// 表单设计画布：canvas 绘制 + 点选/拖拽事件转 typed Msg（设计坐标）。
/// semantics_label 与空态提示由调用方经 i18n 翻译器传入。
/// 测量按约束**等比铺满**可用区域（缩放因子 = 帧宽 / 640），绘制与命中
/// 测试都从各自收到的 frame 现算同一比例——画布列弹性伸缩时二者永不失配。
/// zoom > 0 时改为固定逻辑尺寸 640×zoom（用户档位），超出视口由调用方的
/// 滚动容器接管；比例仍从帧宽现算，指针换算无需额外分支。
pub fn design_canvas(
  program : @ir.MomaoProgram,
  selection : String,
  drag_control : String?,
  semantics_label : String,
  empty_hint : String,
  zoom? : Double = 0.0,
) -> @moui.View[Msg] {
  @views.container(
    canvas(
      measure=fn(constraints) {
        // zoom > 0：固定逻辑尺寸（用户档位）；zoom = 0：等比铺满可用区域
        if zoom > 0.0 {
          @geometry.Size::new(
            width=design_width * zoom,
            height=design_height * zoom,
          )
        } else {
          // 等比铺满：宽 = min(可用宽, 可用高 ÷ 3/4)；无界约束退回 1:1 基准
          let ratio = design_height / design_width
          let mut width = if constraints.max.width < constraints.max.height / ratio {
            constraints.max.width
          } else {
            constraints.max.height / ratio
          }
          if width <= 0.0 || width > 1.0e8 {
            width = design_width
          }
          @geometry.Size::new(width~, height=width * ratio)
        }
      },
      draw=fn(ctx, frame) {
        // MoUI paint 契约：命令是窗口全局坐标。缩放因子从分配到的帧现算，
        // 绘制计划（设计坐标）统一做 平移×缩放 变换。不用 PushClip/
        // PushTransform——wasm 渲染管线里画布层内嵌 clip/transform 栈会
        // 吞掉整层命令（已实测）。
        let scale = if frame.size.width > 0.0 {
          frame.size.width / design_width
        } else {
          1.0
        }
        fn place(rect : @geometry.Rect) -> @geometry.Rect {
          @geometry.Rect::new(
            x=frame.origin.x + rect.origin.x * scale,
            y=frame.origin.y + rect.origin.y * scale,
            width=rect.size.width * scale,
            height=rect.size.height * scale,
          )
        }
        for op in design_draw_plan(program, selection, drag_control) {
          match op {
            WindowFrame(rect) => {
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=place(rect), radius=10.0 * scale),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.97, g=0.97, b=0.98),
                ),
              )
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=place(rect), radius=10.0 * scale),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.75, g=0.77, b=0.82),
                ),
                1.5,
              )
            }
            FillControl(rect, kind) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=place(rect), radius=6.0 * scale),
                @graphics.Brush::solid(kind_fill_light(kind)),
              )
            ControlLabel(name, rect, color) => {
              let placed = place(rect)
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=placed, radius=4.0 * scale),
                @graphics.Brush::solid(color),
              )
              draw_text(
                ctx,
                @text.TextRun::new(
                  text=name,
                  frame=@geometry.Rect::new(
                    x=placed.origin.x + 6.0 * scale,
                    y=placed.origin.y + 1.0 * scale,
                    width=(placed.size.width - 8.0 * scale).max(0.0),
                    height=placed.size.height,
                  ),
                  font=@text.FontSpec::new(size=11.0 * scale),
                  color=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0),
                ),
              )
            }
            ControlText(content, rect, color) =>
              if content != "" {
                let placed = place(rect)
                draw_text(
                  ctx,
                  @text.TextRun::new(
                    text=content,
                    frame=@geometry.Rect::new(
                      x=placed.origin.x + 8.0 * scale,
                      y=placed.origin.y + placed.size.height * 0.45,
                      width=(placed.size.width - 12.0 * scale).max(0.0),
                      height=placed.size.height * 0.5,
                    ),
                    font=@text.FontSpec::new(size=13.0 * scale),
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
                    rect=place(
                      @geometry.Rect::new(
                        x=rect.origin.x + 6.0,
                        y=row_y,
                        width=(rect.size.width - 12.0).max(0.0),
                        height=12.0,
                      ),
                    ),
                    radius=3.0 * scale,
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
                  rect=place(
                    @geometry.Rect::new(
                      x=rect.origin.x - inflate,
                      y=rect.origin.y - inflate,
                      width=rect.size.width + inflate * 2.0,
                      height=rect.size.height + inflate * 2.0,
                    ),
                  ),
                  radius=8.0 * scale,
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
                @graphics.RoundedRect::new(rect=place(rect), radius=2.0 * scale),
                brush,
              )
            }
            GridDot(rect) =>
              fill_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(rect=place(rect), radius=1.0 * scale),
                @graphics.Brush::solid(
                  @graphics.Color::rgba(r=0.85, g=0.86, b=0.90),
                ),
              )
            GuideV(x) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=frame.origin.x + x * scale - 0.75,
                    y=frame.origin.y,
                    width=1.5,
                    height=frame.size.height,
                  ),
                  radius=0.0,
                ),
                @graphics.Brush::solid(guide_color()),
                1.5,
              )
            GuideH(y) =>
              stroke_rounded_rect(
                ctx,
                @graphics.RoundedRect::new(
                  rect=@geometry.Rect::new(
                    x=frame.origin.x,
                    y=frame.origin.y + y * scale - 0.75,
                    width=frame.size.width,
                    height=1.5,
                  ),
                  radius=0.0,
                ),
                @graphics.Brush::solid(guide_color()),
                1.5,
              )
          }
        }
        // 空画布引导：没有控件时给一句从哪开始的提示（i18n 由调用方传入）
        if program.controls.length() == 0 {
          draw_text(
            ctx,
            @text.TextRun::new(
              text=empty_hint,
              frame=@geometry.Rect::new(
                x=frame.origin.x,
                y=frame.origin.y,
                width=frame.size.width,
                height=frame.size.height,
              ),
              font=@text.FontSpec::new(size=15.0),
              color=@graphics.Color::rgba(r=0.55, g=0.56, b=0.60),
              align=TextCenter,
            ),
          )
        }
      },
      semantics_label~,
    )
    // 点选在前：单击（无拖拽位移）只走 tap 识别器，拖拽结束的 tap 以
    // model.drag 是否仍存在区分（见 update 的 CanvasTap 处理）。
    // 帧 → 设计坐标：除以与绘制同一来源（帧宽/640）的缩放因子。
    .on_tap_with_frame(fn(position, frame) {
      let scale = if frame.size.width > 0.0 {
        frame.size.width / design_width
      } else {
        1.0
      }
      Msg::CanvasTap(
        (position.x - frame.origin.x) / scale,
        (position.y - frame.origin.y) / scale,
      )
    })
    .on_drag_with_frame(fn(event, frame) {
      let scale = if frame.size.width > 0.0 {
        frame.size.width / design_width
      } else {
        1.0
      }
      let lx = (event.position.x - frame.origin.x) / scale
      let ly = (event.position.y - frame.origin.y) / scale
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
