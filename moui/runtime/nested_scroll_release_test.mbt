///|
/// 嵌套滚动释放回归：点击内层滚动视图中的控件后，外层滚动容器必须解除
/// Down 时武装的拖拽状态（原债务：设置页点击世界条目后，鼠标悬停即滚动
/// 整页，2026-10-24 复现并固定）。
///
/// 根因：capture 把 Up 路由给内层控件；回传去重把释放流只交给最内层滚动
/// 视图，外层的 `drag.active` 残留，而无按键 `Move` 不检查指针状态，悬停
/// 越过 slop 即开始拖动。修复后释放（Up/Cancel）绕过该去重，逐层送达全部
/// 滚动视图祖先。全部经 `AppRuntime` 真实派发验证。

///|
fn join_message_list(messages : Array[String]) -> String {
  let mut joined = ""
  for index, message in messages {
    joined = if index == 0 { message } else { joined + "|" + message }
  }
  joined
}

///|
/// 记录滚动回调上报的偏移：x/y 分开收集，便于断言"哪个轴动了"。
fn scroll_offset_recorder(
  x_moves : Array[String],
  y_moves : Array[String],
) -> (@core.Point) -> String {
  fn(offset : @core.Point) {
    if offset.x != 0.0 {
      x_moves.push("x@" + offset.x.to_string())
    }
    if offset.y != 0.0 {
      y_moves.push("y@" + offset.y.to_string())
    }
    ""
  }
}

///|
/// 设置页同构的嵌套滚动树：外层整页滚动，内层是世界列表（有纵向区间），
/// 列表项是可点击按钮。返回（外层 x 记录, 外层 y 记录, 内层 y 记录, 运行时）。
fn nested_scroll_runtime() -> (
  Array[String],
  Array[String],
  Array[String],
  @runtime.AppRuntime,
) {
  let (received, capture) = pointer_capture_messages()
  ignore(received)
  let outer_x : Array[String] = []
  let outer_y : Array[String] = []
  let inner_y : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.scroll_view(
      @views.column(
        [
          @views.text("设置", width=296.0, height=38.0),
          @views.scroll_view(
            @views.column(
              [
                @views.button(
                  "WorldA",
                  on_click="open-a",
                  width=288.0,
                  height=34.0,
                ),
                @views.button(
                  "WorldB",
                  on_click="open-b",
                  width=288.0,
                  height=34.0,
                ),
                @views.button(
                  "WorldC",
                  on_click="open-c",
                  width=288.0,
                  height=34.0,
                ),
                @views.button(
                  "WorldD",
                  on_click="open-d",
                  width=288.0,
                  height=34.0,
                ),
              ],
              spacing=6.0,
            ),
            width=292.0,
            height=80.0,
            on_scroll=Some(scroll_offset_recorder([], inner_y)),
          ),
          @views.text("填充", width=300.0, height=300.0),
        ],
        spacing=10.0,
      ),
      width=300.0,
      height=200.0,
      on_scroll=Some(scroll_offset_recorder(outer_x, outer_y)),
    ),
    size=@core.Size::new(width=400.0, height=400.0),
    on_message=Some(capture),
  )
  (outer_x, outer_y, inner_y, runtime)
}

///|
test "对照：单层滚动视图内点击按钮后，悬停移动不滚动" {
  let (received, capture) = pointer_capture_messages()
  let outer_x : Array[String] = []
  let outer_y : Array[String] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.scroll_view(
      @views.column(
        [
          @views.button("WorldA", on_click="open-a", width=288.0, height=34.0),
          @views.text("填充", width=300.0, height=300.0),
        ],
        spacing=10.0,
      ),
      width=300.0,
      height=200.0,
      on_scroll=Some(scroll_offset_recorder(outer_x, outer_y)),
    ),
    size=@core.Size::new(width=400.0, height=400.0),
    on_message=Some(capture),
  )
  pointer_click_label(runtime, "WorldA")
  assert_true(received.contains("open-a"))
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=60.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=90.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=130.0), Move)
  assert_true(
    outer_x.length() == 0 && outer_y.length() == 0,
    msg="悬停滚动了单层滚动视图: " + join_message_list(outer_y),
  )
}

///|
test "嵌套滚动：点击内层按钮后，悬停移动不得滚动外层" {
  let (outer_x, outer_y, _inner_y, runtime) = nested_scroll_runtime()
  // 点击世界条目：激活照常。
  pointer_click_label(runtime, "WorldA")
  // 释放后的悬停移动：外层不得有任何滚动。
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=60.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=90.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=130.0), Move)
  assert_true(
    outer_x.length() == 0 && outer_y.length() == 0,
    msg="点击后悬停滚动了外层: " + join_message_list(outer_y),
  )
}

///|
test "嵌套滚动：从内层控件起手的拖拽归内层，释放后悬停不得滚动外层" {
  let (received, _capture) = pointer_capture_messages()
  let (outer_x, outer_y, inner_y, runtime) = nested_scroll_runtime()
  // 按住 WorldB 拖过 slop：内层滚动，外层不动，点击被取消。
  let frame = pointer_frame_of(runtime.draw_commands(), "WorldB")
  let start = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  pointer_dispatch(runtime, start, Down)
  pointer_dispatch(runtime, @core.Point::new(x=start.x, y=start.y - 20.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=start.x, y=start.y - 40.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=start.x, y=start.y - 40.0), Up)
  assert_false(received.contains("open-b"), msg="拖拽不应激活点击")
  assert_true(
    inner_y.length() >= 2,
    msg="内层拖拽应滚动内层: " + join_message_list(inner_y),
  )
  assert_true(
    outer_x.length() == 0 && outer_y.length() == 0,
    msg="内层拖拽不应滚动外层: " + join_message_list(outer_y),
  )
  // 释放后的悬停移动：两层都不得再滚动。
  let inner_before = inner_y.length()
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=180.0), Move)
  pointer_dispatch(runtime, @core.Point::new(x=150.0, y=200.0), Move)
  assert_true(
    outer_x.length() == 0 && outer_y.length() == 0,
    msg="释放后悬停滚动了外层: " + join_message_list(outer_y),
  )
  assert_true(
    inner_y.length() == inner_before,
    msg="释放后悬停滚动了内层: " + join_message_list(inner_y),
  )
}
