///|
/// 表单设计器画布：设计坐标系固定 640×480，无缩放（MVP）。
/// 绘制计划是纯数据，便于测试；视图闭包只负责解释执行。
/// 交互：按下命中控件 → 拖动移动；按空白 → 取消选中。
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
/// 控件主色（按类型区分，便于一眼识别）。
fn kind_fill(kind : ControlKind) -> @graphics.Color {
  match kind {
    Button => @graphics.Color::rgba(r=0.22, g=0.45, b=0.86)
    Label => @graphics.Color::rgba(r=0.30, g=0.62, b=0.36)
    TextField => @graphics.Color::rgba(r=0.80, g=0.55, b=0.16)
  }
}

///|
fn kind_fill_light(kind : ControlKind) -> @graphics.Color {
  match kind {
    Button => @graphics.Color::rgba(r=0.55, g=0.70, b=0.93)
    Label => @graphics.Color::rgba(r=0.62, g=0.80, b=0.66)
    TextField => @graphics.Color::rgba(r=0.93, g=0.78, b=0.55)
  }
}

///|
/// 控件在设计坐标系中的矩形。
pub fn control_rect(control : FormControl) -> @geometry.Rect {
  @geometry.Rect::new(
    x=control.x,
    y=control.y,
    width=control.width,
    height=control.height,
  )
}

///|
/// 命中测试（设计坐标）：后画的在上，倒序取第一个命中。
pub fn hit_test_control(
  controls : Array[FormControl],
  x : Double,
  y : Double,
) -> FormControl? {
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
  FillControl(@geometry.Rect, ControlKind)
  ControlLabel(String, @geometry.Rect, @graphics.Color)
  ControlText(String, @geometry.Rect, @graphics.Color)
  SelectionStroke(@geometry.Rect)
  WindowFrame(@geometry.Rect)
}

///|
/// 设计画布绘制计划：窗口底板 → 控件（名字条 + 文本）→ 选中描边。
fn design_draw_plan(
  project : FormProject,
  selection : Int?,
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
  for control in project.controls {
    let rect = control_rect(control)
    ops.push(FillControl(rect, control.kind))
    // 名字条：控件名画在顶部小字条，模仿易语言窗体的控件标识
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
    match selection {
      Some(selected) =>
        if selected == control.id {
          ops.push(SelectionStroke(rect))
        }
      None => ()
    }
  }
  ops
}

///|
/// 表单设计画布：canvas 绘制 + 拖拽事件转 typed Msg（画布局部坐标）。
pub fn design_canvas(
  project : FormProject,
  selection : Int?,
) -> @moui.View[Msg] {
  canvas(
    measure=fn(constraints) {
      constraints.constrain(
        @geometry.Size::new(width=design_width, height=design_height),
      )
    },
    draw=fn(ctx, frame) {
      push_clip(ctx, frame)
      for op in design_draw_plan(project, selection) {
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
      CanvasPress(lx, ly)
    } else if event.phase == @views.DragGesturePhase::Changed {
      CanvasDragTo(lx, ly)
    } else {
      CanvasRelease(lx, ly)
    }
  })
}
