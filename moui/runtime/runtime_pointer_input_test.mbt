///|
test "direct pointer input reports scroll consumption at boundaries" {
  let root : @core.View[Unit] = @views.scroll_view(
    runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
    width=20.0,
    height=40.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  ignore(runtime.layout())
  let consumed = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=5.0),
      phase=Move,
      wheel_delta=@core.Point::new(x=0.0, y=-12.0),
    ),
  )
  if consumed.host_flags() != 1 {
    fail("expected a moved scroll view to consume the wheel")
  }
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=-1000.0),
      ),
    ),
  )
  let edge = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=5.0),
      phase=Move,
      wheel_delta=@core.Point::new(x=0.0, y=-12.0),
    ),
  )
  if edge.host_flags() != 0 {
    fail("expected a scroll boundary to retain the browser default")
  }
}

///|
test "direct pointer input drags a scroll view" {
  let root : @core.View[Unit] = @views.scroll_view(
    runtime_test_rect(width=20.0, height=200.0, color=@core.Color::blue()),
    width=20.0,
    height=40.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  ignore(runtime.layout())
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=30.0),
      phase=Down,
    ),
  )
  if down.host_flags() != 3 {
    fail("expected a scroll view to capture pointer down")
  }
  let move_result = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=5.0, y=10.0),
      phase=Move,
    ),
  )
  if move_result.host_flags() != 1 {
    fail("expected a scroll drag to be handled")
  }
  assert_true(runtime.layout().children[0].frame.origin.y == -20.0)
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position=@core.Point::new(x=5.0, y=10.0), phase=Up),
  )
  if up.host_flags() != 5 {
    fail("expected a scroll view to release pointer capture")
  }
}

///|
test "direct pointer input drags a scroll view from a child control" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.scroll_view(
    @views.column(
      [
        @views.button("Tap", on_click="clicked", width=20.0, height=20.0),
        runtime_test_rect(width=20.0, height=180.0, color=@core.Color::blue()),
      ],
      spacing=0.0,
    ),
    width=20.0,
    height=40.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=10.0),
        phase=Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=0.0),
        phase=Move,
      ),
    ),
  )
  assert_true(runtime.layout().children[0].frame.origin.y < 0.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=@core.Point::new(x=5.0, y=0.0), phase=Up),
    ),
  )
  assert_true(received.is_empty())
}

///|
test "direct pointer input keeps a child click within scroll drag slop" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.scroll_view(
    @views.column(
      [
        @views.button("Tap", on_click="clicked", width=20.0, height=20.0),
        runtime_test_rect(width=20.0, height=180.0, color=@core.Color::blue()),
      ],
      spacing=0.0,
    ),
    width=20.0,
    height=40.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=10.0),
        phase=Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=6.0, y=11.0),
        phase=Move,
      ),
    ),
  )
  assert_true(runtime.layout().children[0].frame.origin.y == 0.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=6.0, y=11.0),
        phase=Up,
      ),
    ),
  )
  inspect(received.join(","), content="clicked")
}

///|
test "direct pointer input keeps a button target from down through up" {
  let received : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let position = @core.Point::new(x=8.0, y=8.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=Move),
    ),
  )
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=Down),
  )
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=Up),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}

///|
test "direct pointer input keeps a button target across a redraw" {
  let received : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let position = @core.Point::new(x=8.0, y=8.0)
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=Down),
  )
  ignore(runtime.draw_frame())
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position~, phase=Up),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}

///|
/// A drag modifier commonly wraps a tap modifier in app controls.  A click
/// must clear the drag recognizer before the next hover Move; otherwise the
/// stale Pending state turns that Move into a drag and makes the control
/// follow the pointer.
test "drag modifier clears its state after a child tap consumes Up" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=40.0,
      height=40.0,
      padding=0.0,
    )
    .on_drag(event => "drag:" + event.phase.label())
    .on_tap("clicked")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=40.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  let center = @core.Point::new(x=20.0, y=20.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Up),
    ),
  )
  // This is an ordinary hover move after the click, not a button drag.
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=24.0, y=20.0),
        phase=Move,
      ),
    ),
  )
  inspect(received.join(","), content="clicked")
}

///|
/// A drag nested inside a tap must still let the tap observe a short click,
/// while a real drag cancels the tap before its Up can activate.
test "captured gesture ancestors arbitrate tap versus drag" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=40.0,
      height=40.0,
      padding=0.0,
    )
    .on_drag(event => "drag:" + event.phase.label())
    .on_tap("clicked")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=40.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  let center = @core.Point::new(x=20.0, y=20.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Up),
    ),
  )
  inspect(received.join(","), content="clicked")

  received.clear()
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=20.0),
        phase=Move,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=20.0),
        phase=Up,
      ),
    ),
  )
  inspect(received.join(","), content="drag:Started,drag:Ended")
}

///|
fn runtime_damage_rebuild_program() -> @core.Program[Bool, Unit] {
  @core.Program::simple(init=false, update=(visible, _message) => !visible, view=visible => {
    if visible {
      @views.column(
        [
          @views.button("Open", on_click=(), width=60.0, height=24.0),
          runtime_test_rect(width=120.0, height=56.0, color=@core.Color::blue()),
        ],
        spacing=0.0,
      )
    } else {
      @views.column(
        [
          @views.button("Open", on_click=(), width=60.0, height=24.0),
          runtime_test_rect(
            width=120.0,
            height=56.0,
            color=@core.Color::rgba(r=0.86, g=0.12, b=0.12),
          ),
        ],
        spacing=0.0,
      )
    }
  })
}

///|
test "component rebuild requests full damage after replacing content" {
  let runtime = @runtime.AppRuntime::new_program(
    program=runtime_damage_rebuild_program(),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  ignore(runtime.draw_frame())
  let position = @core.Point::new(x=8.0, y=8.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=Down),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(@core.PointerEvent::new(position~, phase=Up)),
  )
  let frame = runtime.draw_frame()
  assert_true(frame.damage is FullSurface(_))
}

///|
fn[Msg] runtime_pointer_capture_probe(message : Msg) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PointerCaptureProbe"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=40.0, height=24.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([FillRect(ctx.frame, @core.Color::blue())])
    },
    event=ctx => {
      match ctx.event {
        Pointer(event) =>
          match event.phase {
            Down =>
              {
                ..@core.ViewEventResult::ignored(),
                captured: true,
                state: Some({ ..ctx.state, pressed: true, }),
                dirty: ViewPaintDirty,
              }
            Up =>
              if ctx.state.pressed {
                {
                  ..@core.ViewEventResult::message(message),
                  state: Some({ ..ctx.state, pressed: false, }),
                }
              } else {
                @core.ViewEventResult::ignored()
              }
            _ => @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
test "direct pointer input retains a captured non-focusable target" {
  let received : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=runtime_pointer_capture_probe("clicked"),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position=@core.Point::new(x=8.0, y=8.0), phase=Down),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=72.0, y=8.0),
        phase=Move,
      ),
    ),
  )
  let up = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position=@core.Point::new(x=72.0, y=8.0), phase=Up),
  )
  inspect(down.host_flags(), content="3")
  inspect(up.host_flags(), content="5")
  inspect(received.join(","), content="clicked")
}

///|
/// Host backends route right-button presses into the view tree so per-target
/// context menus can observe them before the menu is shown: the secondary tap
/// fires on press (the host trigger phase), not on release.
test "secondary pointer press delivers the context menu target" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=40.0,
    height=40.0,
    padding=0.0,
  ).on_secondary_tap("context")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=40.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  let center = @core.Point::new(x=20.0, y=20.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=center, phase=Down, button=1),
    ),
  )
  inspect(received.join(","), content="context")
}

///|
/// Right/middle presses now reach the view tree; they must not also fire the
/// control's primary activation.
test "secondary pointer press does not activate a button" {
  let received : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.button("Go", on_click="clicked", width=80.0, height=32.0),
    size=@core.Size::new(width=80.0, height=32.0),
    on_message=Some(message => received.push(message)),
  )
  let position = @core.Point::new(x=8.0, y=8.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=Down, button=1),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position~, phase=Up, button=1),
    ),
  )
  assert_true(received.length() == 0)
}

///|
/// The tree view's secondary-tap hook covers the whole row (glyph + label)
/// and reports the row id, so explorers can scope their context menu per row.
test "tree view secondary tap reports the row id" {
  let received : Array[String] = []
  let items = [
    @views.tree_item(id="/tmp/project/notes.md", label="notes.md"),
    @views.tree_item(id="/tmp/project", label="project", children=[
      @views.tree_item(id="/tmp/project/a.md", label="a.md"),
    ]),
  ]
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.tree_view(
      items,
      expanded=["/tmp/project"],
      on_secondary_tap=Some(id => "context:" + id),
      width=200.0,
    ),
    size=@core.Size::new(width=200.0, height=200.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=60.0, y=10.0),
        phase=Down,
        button=1,
      ),
    ),
  )
  inspect(received.join(","), content="context:/tmp/project/notes.md")
}

///|
/// 设计舞台回归：手势覆盖层叠在真实控件之上时，Down 必须由覆盖层认领
/// （拦截指针输入），拖拽手势完整到达覆盖层，且下层按钮不被激活。
/// （MoUI Studio 设计舞台结构：stack([背景画布, 真控件层, 手势覆盖画布])。）
test "设计舞台：覆盖层在真控件之上，拖拽消息完整、按钮不激活" {
  let (received, capture) = pointer_capture_messages()
  let backdrop = @views.canvas(
    measure=fn(_constraints) { @core.Size::new(width=400.0, height=200.0) },
    draw=fn(_ctx, _frame) {  },
  )
  let widgets = @views.container(
    @views.button(
      "RealBtn",
      on_click="button-activated",
      width=120.0,
      height=32.0,
    ),
    width=400.0,
    height=200.0,
    padding=0.0,
  )
  let overlay = @views.canvas(
      measure=fn(_constraints) { @core.Size::new(width=400.0, height=200.0) },
      draw=fn(_ctx, _frame) {  },
    )
    .on_tap_with_frame(fn(_position, _frame) { "overlay-tap" })
    .on_drag_with_frame(fn(event, _frame) {
      match event.phase {
        Started => "drag-started"
        Changed => "drag-changed"
        Ended => "drag-ended"
        _ => ""
      }
    })
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.stack([backdrop, widgets, overlay]),
    size=@core.Size::new(width=400.0, height=200.0),
    on_message=Some(capture),
  )
  // 按钮中心（容器内居中：(400-120)/2+60=200, (200-32)/2+16=100）
  pointer_dispatch(runtime, @core.Point::new(x=200.0, y=100.0), Down)
  pointer_dispatch(runtime, @core.Point::new(x=212.0, y=108.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=228.0, y=120.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=244.0, y=132.0), Up)
  assert_true(received.contains("drag-started"))
  assert_true(received.contains("drag-changed"))
  assert_true(received.contains("drag-ended"))
  assert_true(!received.contains("button-activated"))
}

///|
/// 设计舞台回归（完整嵌套）：CrossStart 行 + frame(600) + flexible 列 +
/// 缩放工具条 + 三层舞台——复刻 MoUI Studio 设计模式的真实嵌套，验证拖拽仍达
/// 手势覆盖层（2026-09 拖拽失效回归的实证夹具）。
test "设计舞台：完整嵌套下拖拽消息仍达覆盖层" {
  let (received, capture) = pointer_capture_messages()
  let backdrop = @views.canvas(
    measure=fn(_constraints) { @core.Size::new(width=400.0, height=200.0) },
    draw=fn(_ctx, _frame) {  },
  )
  let widgets = @views.container(
    @views.button(
      "RealBtn",
      on_click="button-activated",
      width=100.0,
      height=32.0,
    ),
    width=400.0,
    height=200.0,
    padding=0.0,
  )
  let overlay = @views.canvas(
      measure=fn(_constraints) { @core.Size::new(width=400.0, height=200.0) },
      draw=fn(_ctx, _frame) {  },
    )
    .on_tap_with_frame(fn(_position, _frame) { "overlay-tap" })
    .on_drag_with_frame(fn(event, _frame) {
      match event.phase {
        Started => "drag-started"
        Changed => "drag-changed"
        Ended => "drag-ended"
        _ => ""
      }
    })
  // 注意：此处不能给 stage 再套 .flexible()——加权子树在 tight 重排下
  // 丢指针手势（2026-09 拖拽失效回归的根因，设计舞台已改显式高度帧）。
  let stage = @views.stack([backdrop, widgets, overlay]).frame(height=556.0)
  let center = @views.column(
    [
      @views.button("适应窗口", on_click="fit", width=96.0, height=38.0),
      stage,
    ],
    spacing=6.0,
  )
  let root = @views.column([
    @views.row(
      [
        @views.spacer(min_length=24.0, weight=0.0),
        @views.container(
          @views.button("Left", width=200.0, height=560.0),
          width=224.0,
          height=600.0,
          padding=0.0,
        ),
        center.flexible(),
        @views.spacer(min_length=24.0, weight=0.0),
      ],
      align=Start,
    ).frame(height=600.0),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=1280.0, height=800.0),
    on_message=Some(capture),
  )
  // 真实按钮的中心：从绘制命令里取它的文本帧
  let frame = pointer_frame_of(runtime.draw_commands(), "RealBtn")
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  pointer_dispatch(runtime, center, Down)
  pointer_dispatch(
    runtime,
    @core.Point::new(x=center.x + 12.0, y=center.y + 8.0),
    Move,
  )
  pointer_dispatch(
    runtime,
    @core.Point::new(x=center.x + 28.0, y=center.y + 20.0),
    Move,
  )
  pointer_dispatch(
    runtime,
    @core.Point::new(x=center.x + 44.0, y=center.y + 32.0),
    Up,
  )
  assert_true(received.contains("drag-started"))
  assert_true(received.contains("drag-changed"))
  assert_true(received.contains("drag-ended"))
  assert_true(!received.contains("button-activated"))
}
