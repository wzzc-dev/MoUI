///|
/// 表单设计器画布：设计坐标系固定 640×480。
/// 绘制计划是纯数据；命中测试与拖拽在 update 里转 typed Msg。
using @views {
  canvas,
  draw_text,
  fill_rounded_rect,
  stroke_rounded_rect,
  push_clip,
  pop_clip,
}

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
priv enum DesignDrawOp {
  FillControl(@geometry.Rect, @ir.ControlKind)
  ControlLabel(String, @geometry.Rect, @graphics.Color)
  ControlText(String, @geometry.Rect, @graphics.Color)
  ControlRows(@geometry.Rect)
  SelectionStroke(@geometry.Rect)
  WindowFrame(@geometry.Rect)
}

///|
/// 设计画布绘制计划：窗口底板 → 控件（名字条 + 文本 + 行）→ 选中描边。
fn design_draw_plan(
  program : @ir.MomaoProgram,
  selection : String,
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
    }
  }
  ops
}

///|
/// 表单设计画布：canvas 绘制 + 拖拽事件转 typed Msg（画布局部坐标）。
pub fn design_canvas(
  program : @ir.MomaoProgram,
  selection : String,
) -> @moui.View[Msg] {
  canvas(
    measure=fn(constraints) {
      constraints.constrain(
        @geometry.Size::new(width=design_width, height=design_height),
      )
    },
    draw=fn(ctx, frame) {
      push_clip(ctx, frame)
      for op in design_draw_plan(program, selection) {
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
                @graphics.Color::rgba(r=0.10, g=0.24, b=0.86),
              ),
              2.5,
            )
          }
        }
      }
      pop_clip(ctx)
    },
    semantics_label="表单设计画布",
  ).on_drag_with_frame(fn(event, frame) {
    let lx = event.position.x - frame.origin.x
    let ly = event.position.y - frame.origin.y
    if event.phase == @views.DragGesturePhase::Started {
      Msg::CanvasPress(lx, ly)
    } else if event.phase == @views.DragGesturePhase::Changed {
      Msg::CanvasDragTo(lx, ly)
    } else {
      Msg::CanvasRelease(lx, ly)
    }
  })
}
