///|
/// 白盒：flex 子帧的 RTL 镜像。约定是「先把子帧按阅读顺序从主轴起点排出来，
/// 再把每只盒子关于 container 中线反射」，所以 LTR/RTL 必须成对出现：盒子尺寸
/// 与 y 完全相同，x 满足 `rtl = width - ltr - box`。这条不变式覆盖 MainEnd 与
/// Space*，也覆盖列方向的 Cross*，不需要为每种对齐另写一套数学。

///|
fn flex_sizes() -> Array[@core.Size] {
  [
    @core.Size::new(width=10.0, height=5.0),
    @core.Size::new(width=20.0, height=5.0),
    @core.Size::new(width=30.0, height=5.0),
  ]
}

///|
fn frames_at(
  alignment : @core.MainAxisAlignment,
  direction : @core.LayoutDirection,
) -> Array[@core.Rect] {
  flex_child_frames(
    Horizontal,
    0.0,
    alignment,
    CrossStart,
    flex_sizes(),
    [],
    @core.Size::new(width=100.0, height=5.0),
    direction~,
  )
}

///|
fn flex_layout_context(
  direction : @core.LayoutDirection,
) -> @core.ViewLayoutContext {
  let sizes = flex_sizes()
  {
    constraints: @core.Constraints::tight(
      @core.Size::new(width=100.0, height=5.0),
    ),
    child_sizes: sizes,
    child_flex_weights: sizes.map(_ => 0.0),
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
  }
}

///|
test "every main-axis alignment mirrors the whole frame set" {
  let alignments : Array[@core.MainAxisAlignment] = [
    MainStart,
    MainCenter,
    MainEnd,
    SpaceBetween,
    SpaceAround,
    SpaceEvenly,
  ]
  for alignment in alignments {
    let ltr = frames_at(alignment, LeftToRight)
    let rtl = frames_at(alignment, RightToLeft)
    assert_eq(ltr.length(), 3)
    assert_eq(rtl.length(), ltr.length())
    for index, left in ltr {
      let right = rtl[index]
      assert_eq(right.size.width, left.size.width)
      assert_eq(right.origin.y, left.origin.y)
      assert_eq(right.origin.x, 100.0 - left.origin.x - left.size.width)
    }
  }
}

///|
test "the leading flex child sits against the reading edge" {
  let ltr = frames_at(MainStart, LeftToRight)
  let rtl = frames_at(MainStart, RightToLeft)
  assert_eq(ltr[0].origin.x, 0.0)
  assert_eq(ltr[2].origin.x, 30.0)
  assert_eq(rtl[0].origin.x, 90.0)
  assert_eq(rtl[2].origin.x, 40.0)
}

///|
test "a column mirrors its cross axis" {
  let sizes = [
    @core.Size::new(width=10.0, height=5.0),
    @core.Size::new(width=20.0, height=5.0),
  ]
  let ltr = flex_child_frames(
    Vertical,
    0.0,
    MainStart,
    CrossStart,
    sizes,
    [],
    @core.Size::new(width=100.0, height=40.0),
    direction=LeftToRight,
  )
  let rtl = flex_child_frames(
    Vertical,
    0.0,
    MainStart,
    CrossStart,
    sizes,
    [],
    @core.Size::new(width=100.0, height=40.0),
    direction=RightToLeft,
  )
  assert_eq(ltr[0].origin.x, 0.0)
  assert_eq(ltr[1].origin.x, 0.0)
  assert_eq(rtl[0].origin.x, 90.0)
  assert_eq(rtl[1].origin.x, 80.0)
  // 主轴（垂直）不受方向影响
  assert_eq(rtl[0].origin.y, ltr[0].origin.y)
  assert_eq(rtl[1].origin.y, ltr[1].origin.y)
}

///|
test "flex layout reads the direction off the environment" {
  let node = FlexLayout::{
    axis: Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    kind: "Flex",
    key: None,
  }
  let ltr = @core.ViewNode::layout(node, flex_layout_context(LeftToRight))
  let rtl = @core.ViewNode::layout(node, flex_layout_context(RightToLeft))
  assert_eq(ltr.child_frames[0].origin.x, 0.0)
  assert_eq(rtl.child_frames[0].origin.x, 90.0)
}
