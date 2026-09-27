///|
/// 指针命中回归：`row` 的直接按钮子级、`row` 内的 `scroll_view`，以及
/// `on_drag` / `on_drag_with_frame` 手势（原债务 `row-child-hit-testing`，
/// 2026-09-26 复核不再复现，转为行为回归固定）。
///
/// 场景源自既往积木编辑器 IDE 实践：工具栏 row 内按钮、画布节点拖拽。
/// 全部经 `AppRuntime` 真实布局 + 指针事件派发验证，不依赖具体 host。

///|
fn pointer_capture_messages() -> (Array[String], (String) -> Unit) {
  let received : Array[String] = []
  (received, message => ignore(received.push(message)))
}

///|
fn pointer_frame_of(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) => if value == text { return frame }
      _ => ()
    }
  }
  panic()
}

///|
fn pointer_dispatch(
  runtime : @runtime.AppRuntime,
  position : @core.Point,
  phase : @core.PointerPhase,
) -> Unit {
  runtime.dispatch_event(Pointer(@core.PointerEvent::new(position~, phase~)))
}

///|
/// 在 label 文本帧中心派发 Down/Up（点击）。
fn pointer_click_label(runtime : @runtime.AppRuntime, label : String) -> Unit {
  let frame = pointer_frame_of(runtime.draw_commands(), label)
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  pointer_dispatch(runtime, center, Down)
  pointer_dispatch(runtime, center, Up)
}

///|
/// 在坐标点派发 Down → Move → Move → Up（拖拽）。
fn pointer_drag_path(
  runtime : @runtime.AppRuntime,
  from : @core.Point,
  dx~ : Double,
  dy~ : Double,
) -> Unit {
  pointer_dispatch(runtime, from, Down)
  pointer_dispatch(
    runtime,
    @core.Point::new(x=from.x + dx / 3.0, y=from.y + dy / 3.0),
    Move,
  )
  pointer_dispatch(
    runtime,
    @core.Point::new(x=from.x + dx * 2.0 / 3.0, y=from.y + dy * 2.0 / 3.0),
    Move,
  )
  pointer_dispatch(runtime, @core.Point::new(x=from.x + dx, y=from.y + dy), Up)
}

///|
test "row 的直接按钮子级接收指针点击" {
  let (received, capture) = pointer_capture_messages()
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column([
      @views.row([
        @views.button("InRow", on_click="row-clicked", width=120.0, height=32.0),
      ]),
    ]),
    size=@core.Size::new(width=400.0, height=200.0),
    on_message=Some(capture),
  )
  pointer_click_label(runtime, "InRow")
  assert_true(received.contains("row-clicked"))
}

///|
test "row 内多个按钮各自命中" {
  let (received, capture) = pointer_capture_messages()
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column([
      @views.row([
        @views.button("ZoomIn", on_click="zoom-in", width=100.0, height=32.0),
        @views.text("gap"),
        @views.spacer(),
        @views.button("ZoomOut", on_click="zoom-out", width=100.0, height=32.0),
      ]),
    ]),
    size=@core.Size::new(width=400.0, height=200.0),
    on_message=Some(capture),
  )
  pointer_click_label(runtime, "ZoomIn")
  pointer_click_label(runtime, "ZoomOut")
  assert_true(received.contains("zoom-in"))
  assert_true(received.contains("zoom-out"))
}

///|
test "row 内 scroll_view 的内部按钮命中" {
  let (received, capture) = pointer_capture_messages()
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column([
      @views.row([
        @views.scroll_view(
          @views.column([
            @views.button(
              "InRowScroll",
              on_click="row-scroll-clicked",
              width=120.0,
              height=32.0,
            ),
          ]),
        ),
      ]),
    ]),
    size=@core.Size::new(width=400.0, height=200.0),
    on_message=Some(capture),
  )
  pointer_click_label(runtime, "InRowScroll")
  assert_true(received.contains("row-scroll-clicked"))
}

///|
test "on_drag 手势经 Down/Move/Up 触发（普通 view）" {
  let (received, capture) = pointer_capture_messages()
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column([@views.text("drag-me").on_drag(_event => "dragged")]),
    size=@core.Size::new(width=400.0, height=200.0),
    on_message=Some(capture),
  )
  let frame = pointer_frame_of(runtime.draw_commands(), "drag-me")
  let start = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  pointer_drag_path(runtime, start, dx=24.0, dy=8.0)
  assert_true(received.contains("dragged"))
}

///|
test "canvas + on_drag_with_frame 支持拖拽" {
  let (received, capture) = pointer_capture_messages()
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column([
      @views.canvas(
        measure=fn(constraints) {
          constraints.constrain(@core.Size::new(width=300.0, height=200.0))
        },
        draw=(_ctx, _frame) => (),
        semantics_label="canvas-region",
      ).on_drag_with_frame((_event, _frame) => "canvas-dragged"),
    ]),
    size=@core.Size::new(width=400.0, height=300.0),
    on_message=Some(capture),
  )
  pointer_drag_path(
    runtime,
    @core.Point::new(x=150.0, y=140.0),
    dx=30.0,
    dy=12.0,
  )
  assert_true(received.contains("canvas-dragged"))
}
