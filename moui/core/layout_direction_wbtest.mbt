///|
/// 白盒：RTL 镜像的单一公式。`Rect::mirrored_x` 是唯一一份反射数学，
/// `CustomPlacementContext::mirror_x`、阅读顺序 guide 集与 `AlignModifier`
/// 的水平符号都从它派生 —— 所以必须成对断言（LTR 恒等，RTL 关于 frame
/// 中线反射），任何一处各写一份公式都会在这里露出来。

///|
fn mirror_frame() -> Rect {
  Rect::new(x=10.0, y=0.0, width=100.0, height=20.0)
}

///|
fn placement_context(
  frame : Rect,
  direction : LayoutDirection,
) -> CustomPlacementContext {
  {
    frame,
    measured_size: frame.size,
    children: [],
    layout_direction: direction,
    safe_area: Insets::symmetric(),
    viewport: None,
  }
}

///|
test "mirrored_x is identity in ltr and reflects the box in rtl" {
  let frame = mirror_frame()
  assert_eq(frame.mirrored_x(x=30.0, width=8.0, direction=LeftToRight), 30.0)
  // frame 中线是 60：左边缘 30 的宽 8 盒子反射后落在 82..90。
  assert_eq(frame.mirrored_x(x=30.0, width=8.0, direction=RightToLeft), 82.0)
  // 占满 frame 的盒子反射后不动，点反射（宽 0）给出对边。
  assert_eq(frame.mirrored_x(x=10.0, width=100.0, direction=RightToLeft), 10.0)
  assert_eq(frame.mirrored_x(x=10.0, width=0.0, direction=RightToLeft), 110.0)
}

///|
test "mirror_x and mirrored_x agree so delegates share one formula" {
  let frame = mirror_frame()
  assert_eq(
    placement_context(frame, RightToLeft).mirror_x(x=30.0, width=8.0),
    frame.mirrored_x(x=30.0, width=8.0, direction=RightToLeft),
  )
  assert_eq(
    placement_context(frame, LeftToRight).mirror_x(x=30.0, width=8.0),
    30.0,
  )
}

///|
test "mirrored insets swap the horizontal pair only" {
  let insets : Insets = { top: 1.0, right: 2.0, bottom: 3.0, left: 4.0, }
  assert_eq(insets.mirrored(LeftToRight), insets)
  let mirrored = insets.mirrored(RightToLeft)
  assert_eq(mirrored.left, 2.0)
  assert_eq(mirrored.right, 4.0)
  assert_eq(mirrored.top, 1.0)
  assert_eq(mirrored.bottom, 3.0)
}

///|
test "alignment guides are reading-order edges" {
  let size = Size::new(width=40.0, height=10.0)
  let ltr = AlignmentGuideSet::from_size(size)
  assert_eq(ltr.leading, 0.0)
  assert_eq(ltr.trailing, 40.0)
  let rtl = AlignmentGuideSet::from_size(size, direction=RightToLeft)
  assert_eq(rtl.leading, 40.0)
  assert_eq(rtl.trailing, 0.0)
  // center 与基线是方向无关的，且 runtime 走的构造器把方向透传给 guide 集。
  assert_eq(rtl.center, ltr.center)
  assert_eq(
    ChildLayoutInfo::new(size~, direction=RightToLeft).alignment_guides,
    rtl,
  )
}

///|
test "aligned rect mirrors the horizontal axis" {
  let bounds = Rect::new(x=0.0, y=0.0, width=100.0, height=40.0)
  let child = Size::new(width=20.0, height=10.0)
  let start : Alignment = { x: -1.0, y: 0.0, }
  assert_eq(
    mod_aligned_rect(bounds, child, start, direction=LeftToRight).origin.x,
    0.0,
  )
  assert_eq(
    mod_aligned_rect(bounds, child, start, direction=RightToLeft).origin.x,
    80.0,
  )
  // 垂直轴不参与镜像。
  let top : Alignment = { x: 0.0, y: -1.0, }
  assert_eq(
    mod_aligned_rect(bounds, child, top, direction=RightToLeft).origin.y,
    0.0,
  )
  assert_eq(
    mod_aligned_rect(bounds, child, top, direction=RightToLeft).origin.x,
    40.0,
  )
}
