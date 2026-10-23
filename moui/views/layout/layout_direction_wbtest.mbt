///|
/// 白盒：`views/layout` 的内置布局节点是否真的把 `environment.layout_direction`
/// 交给了 core 的镜像公式。镜像数学本身在 `moui/core` 只有一处实现，所以这里
/// 唯一会静默失效的失败模式是「节点漏传/传错方向」，于是每个用例都成对断言
/// LTR 与 RTL，并检查 y（或主轴）不被镜像影响。

///|
fn direction_test_state() -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
}

///|
fn direction_test_context(
  child_sizes~ : Array[@core.Size],
  constraints~ : @core.Constraints,
  direction~ : @core.LayoutDirection,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes,
    child_flex_weights: child_sizes.map(_ => 0.0),
    state: direction_test_state(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn size_of(width : Double, height : Double) -> @core.Size {
  @core.Size::new(width~, height~)
}

///|
test "padding insets are leading and trailing" {
  let node = PaddingLayout::{
    insets: { top: 1.0, right: 20.0, bottom: 1.0, left: 4.0, },
    kind: "Padding",
    key: None,
  }
  let sizes = [size_of(10.0, 10.0)]
  let loose = @core.Constraints::loose(size_of(200.0, 200.0))
  let ltr = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=LeftToRight,
    ),
  )
  let rtl = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=RightToLeft,
    ),
  )
  assert_eq(ltr.size, rtl.size)
  assert_eq(ltr.child_frames[0].origin.x, 4.0)
  assert_eq(rtl.child_frames[0].origin.x, 20.0)
  assert_eq(rtl.child_frames[0].origin.y, ltr.child_frames[0].origin.y)
}

///|
test "flow mirrors each row inside its own box" {
  let node = Flow::{ width: 100.0, spacing: 8.0, row_spacing: 8.0, }
  let sizes = [size_of(30.0, 10.0), size_of(40.0, 10.0)]
  let loose = @core.Constraints::loose(size_of(100.0, 100.0))
  let ltr = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=LeftToRight,
    ),
  )
  let rtl = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=RightToLeft,
    ),
  )
  assert_eq(ltr.size, rtl.size)
  assert_eq(ltr.child_frames[0].origin.x, 0.0)
  assert_eq(ltr.child_frames[1].origin.x, 38.0)
  // 同一行内的两只盒子关于 100 的中线反射
  for index, left in ltr.child_frames {
    let right = rtl.child_frames[index]
    assert_eq(right.origin.x, 100.0 - left.origin.x - left.size.width)
    assert_eq(right.origin.y, left.origin.y)
  }
}

///|
test "flow wraps before mirroring, not after" {
  let node = Flow::{ width: 100.0, spacing: 8.0, row_spacing: 8.0, }
  let sizes = [size_of(60.0, 10.0), size_of(60.0, 10.0)]
  let loose = @core.Constraints::loose(size_of(100.0, 100.0))
  let ltr = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=LeftToRight,
    ),
  )
  let rtl = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=RightToLeft,
    ),
  )
  // 每个盒子单独占一行：换行用的仍是物理宽度，镜像只改 x
  assert_eq(ltr.child_frames[1].origin.y, 18.0)
  assert_eq(rtl.child_frames[1].origin.y, 18.0)
  assert_eq(ltr.child_frames[0].origin.x, 0.0)
  assert_eq(rtl.child_frames[0].origin.x, 40.0)
  assert_eq(rtl.child_frames[1].origin.x, 40.0)
}

///|
test "grid swaps its columns and keeps its rows" {
  let node = GridLayout::{
    columns: 2,
    row_spacing: 6.0,
    column_spacing: 4.0,
    kind: "Grid",
    key: None,
  }
  let sizes = [
    size_of(10.0, 10.0),
    size_of(10.0, 10.0),
    size_of(10.0, 10.0),
    size_of(10.0, 10.0),
  ]
  let loose = @core.Constraints::loose(size_of(200.0, 200.0))
  let ltr = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=LeftToRight,
    ),
  )
  let rtl = @core.ViewNode::layout(
    node,
    direction_test_context(
      child_sizes=sizes,
      constraints=loose,
      direction=RightToLeft,
    ),
  )
  assert_eq(ltr.size.width, 24.0)
  assert_eq(rtl.size, ltr.size)
  let width = ltr.size.width
  for index, left in ltr.child_frames {
    let right = rtl.child_frames[index]
    assert_eq(right.origin.x, width - left.origin.x - left.size.width)
    assert_eq(right.origin.y, left.origin.y)
  }
  assert_eq(ltr.child_frames[0].origin.x, 0.0)
  assert_eq(rtl.child_frames[0].origin.x, 14.0)
}
