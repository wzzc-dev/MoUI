///|
/// 白盒：滚动偏移的阅读方向契约。`offset.x` 记的是内容相对*前缘*的距离——LTR 的
/// 前缘是左边缘，RTL 是右边缘；滚轮与手指位移始终是物理向量，只在换算成前缘
/// 距离时翻一次符号。所以下面每个用例都成对断言，并检查 y 不被镜像牵连。

///|
fn scroll_direction_viewport() -> @core.Size {
  @core.Size::new(width=100.0, height=100.0)
}

///|
fn scroll_direction_child() -> @core.Size {
  @core.Size::new(width=200.0, height=100.0)
}

///|
test "a scroll offset measures from the reading edge" {
  let frame = @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)
  let ltr_start = scroll_child_frame(
    frame~,
    offset=@core.Point::new(x=0.0, y=0.0),
    viewport=scroll_direction_viewport(),
    child_size=scroll_direction_child(),
    direction=LeftToRight,
  )
  let rtl_start = scroll_child_frame(
    frame~,
    offset=@core.Point::new(x=0.0, y=0.0),
    viewport=scroll_direction_viewport(),
    child_size=scroll_direction_child(),
    direction=RightToLeft,
  )
  // 前缘距离为 0 时，LTR 露出左端，RTL 露出右端
  assert_eq(ltr_start.origin.x, 0.0)
  assert_eq(rtl_start.origin.x, -100.0)
  assert_eq(rtl_start.origin.y, ltr_start.origin.y)
  let ltr_end = scroll_child_frame(
    frame~,
    offset=@core.Point::new(x=100.0, y=0.0),
    viewport=scroll_direction_viewport(),
    child_size=scroll_direction_child(),
    direction=LeftToRight,
  )
  let rtl_end = scroll_child_frame(
    frame~,
    offset=@core.Point::new(x=100.0, y=0.0),
    viewport=scroll_direction_viewport(),
    child_size=scroll_direction_child(),
    direction=RightToLeft,
  )
  // 滚到底正好是另一端：LTR 的终点等于 RTL 的起点，反之亦然
  assert_true(ltr_end == rtl_start)
  assert_true(rtl_end == ltr_start)
}

///|
test "a physical wheel delta is mirrored only in offset space" {
  let delta = @core.Point::new(x=30.0, y=0.0)
  let middle = scroll_offset_after_wheel(
    @core.Point::new(x=50.0, y=0.0),
    delta,
    scroll_direction_viewport(),
    scroll_direction_child(),
    direction=LeftToRight,
  )
  let mirrored = scroll_offset_after_wheel(
    @core.Point::new(x=50.0, y=0.0),
    delta,
    scroll_direction_viewport(),
    scroll_direction_child(),
    direction=RightToLeft,
  )
  assert_eq(middle.x, 20.0)
  assert_eq(mirrored.x, 80.0)
  assert_eq(mirrored.y, middle.y)
  let head_ltr = scroll_offset_after_wheel(
    @core.Point::new(x=0.0, y=0.0),
    delta,
    scroll_direction_viewport(),
    scroll_direction_child(),
    direction=LeftToRight,
  )
  let head_rtl = scroll_offset_after_wheel(
    @core.Point::new(x=0.0, y=0.0),
    delta,
    scroll_direction_viewport(),
    scroll_direction_child(),
    direction=RightToLeft,
  )
  // 同一次手势：在 LTR 的前缘已经滚不动了，在 RTL 却是滚进内容
  assert_eq(head_ltr.x, 0.0)
  assert_eq(head_rtl.x, 30.0)
}

///|
test "the container layout reads the direction off the environment" {
  let view : @core.View[@core.Point] = scroll_container(
    child=scroll_test_rect(width=200.0, height=100.0).map(_ => {
      @core.Point::new(x=0.0, y=0.0)
    }),
    offset=@core.Point::new(x=30.0, y=0.0),
    viewport=Some(scroll_direction_viewport()),
    on_scroll=Some(next => next),
  )
  let ltr = view.layout(
    scroll_test_layout_context(child_size=scroll_direction_child()),
  )
  let rtl = view.layout(
    scroll_test_layout_context(
      child_size=scroll_direction_child(),
      direction=RightToLeft,
    ),
  )
  assert_eq(ltr.child_frames[0].origin.x, -30.0)
  assert_eq(rtl.child_frames[0].origin.x, -70.0)
  assert_eq(rtl.child_frames[0].origin.y, ltr.child_frames[0].origin.y)
}

///|
fn scroll_direction_wheel(
  direction~ : @core.LayoutDirection,
) -> @core.ViewEventResult[@core.Point] {
  let view : @core.View[@core.Point] = scroll_container(
    child=scroll_test_rect(width=200.0, height=100.0).map(_ => {
      @core.Point::new(x=0.0, y=0.0)
    }),
    offset=@core.Point::new(x=0.0, y=0.0),
    viewport=Some(scroll_direction_viewport()),
    on_scroll=Some(next => next),
  )
  let layout = view.layout(
    scroll_test_layout_context(child_size=scroll_direction_child(), direction~),
  )
  let result = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=50.0, y=50.0, phase=Move, wheel_x=30.0),
      child_frames=layout.child_frames,
      direction~,
    ),
  )
  result
}

///|
test "a wheel gesture at the rtl leading edge scrolls inward" {
  let ltr = scroll_direction_wheel(direction=LeftToRight)
  assert_false(ltr.changed)
  assert_true(ltr.messages.is_empty())
  let rtl = scroll_direction_wheel(direction=RightToLeft)
  assert_true(rtl.messages == [@core.Point::new(x=30.0, y=0.0)])
}

///|
fn scroll_direction_drag_raw_offset(
  direction~ : @core.LayoutDirection,
) -> Double {
  let view : @core.View[Unit] = scroll_container(
    child=scroll_test_rect(width=200.0, height=100.0),
    viewport=Some(scroll_direction_viewport()),
  )
  let layout = view.layout(
    scroll_test_layout_context(child_size=scroll_direction_child(), direction~),
  )
  let after_down = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=80.0, y=50.0, phase=Down),
      child_frames=layout.child_frames,
      direction~,
      now_ms=100.0,
    ),
  ).state.unwrap()
  let after_pull = view.event(
    scroll_test_event_context(
      event=scroll_test_pointer(x=10.0, y=50.0, phase=Move),
      child_frames=layout.child_frames,
      state=after_down,
      direction~,
      now_ms=120.0,
    ),
  ).state.unwrap()
  after_pull.read_slot(scroll_drag_state_slot()).raw_offset.x
}

///|
test "a finger pull moves the surface the same physical way in both directions" {
  // 手指左移 70px：内容必须左移。LTR 把前缘距离加大，RTL 把它推向负值（越界带），
  // 所以存下来的 raw_offset 符号相反，物理位移却一致。
  assert_eq(scroll_direction_drag_raw_offset(direction=LeftToRight), 70.0)
  assert_eq(scroll_direction_drag_raw_offset(direction=RightToLeft), -70.0)
}
