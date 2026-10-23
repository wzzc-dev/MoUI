///|
/// 白盒：浮层摆放的阅读方向语义。`Start`/`End` 命名的是锚点的前缘与后缘，
/// `Left`/`Right` 命名的是物理边，所以 RTL 下前者跟着翻、后者也翻——但翻的方式
/// 不同。视口 margin 同样按前缘/后缘书写，RTL 下可用区要从镜像后的 inset 起算。

///|
fn placement_anchor() -> @core.Rect {
  @core.Rect::new(x=90.0, y=90.0, width=20.0, height=20.0)
}

///|
fn placement_content() -> @core.Size {
  @core.Size::new(width=30.0, height=10.0)
}

///|
test "reading-order candidates flip, physical side candidates change side" {
  let anchor = placement_anchor()
  let size = placement_content()
  let flips : Array[
    (PresentationPlacementCandidate, PresentationPlacementCandidate),
  ] = [
    (AboveStart, AboveEnd),
    (BelowStart, BelowEnd),
    (LeftCenter, RightCenter),
    (RightStart, LeftStart),
  ]
  for flip in flips {
    let (left, right) = flip
    let ltr = presentation_candidate_rect(left, anchor, size, LeftToRight)
    let rtl = presentation_candidate_rect(left, anchor, size, RightToLeft)
    let expected = presentation_candidate_rect(right, anchor, size, LeftToRight)
    assert_true(rtl == expected)
    assert_false(ltr == rtl)
  }
  // 居中候选本身对称，镜像后仍是自己
  for centered in [AboveCenter, BelowCenter, Center] {
    assert_true(
      presentation_candidate_rect(centered, anchor, size, LeftToRight) ==
      presentation_candidate_rect(centered, anchor, size, RightToLeft),
    )
  }
}

///|
test "resolve lands the surface against the reading edge" {
  let viewport = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=200.0)
  let placement = PresentationPlacement::new(candidates=[BelowStart])
  let ltr = placement.resolve(
    placement_anchor(),
    viewport,
    placement_content(),
    direction=LeftToRight,
  )
  let rtl = placement.resolve(
    placement_anchor(),
    viewport,
    placement_content(),
    direction=RightToLeft,
  )
  assert_eq(ltr.origin.x, 90.0)
  assert_eq(rtl.origin.x, 80.0)
  assert_eq(rtl.origin.y, ltr.origin.y)
}

///|
test "asymmetric viewport insets are mirrored too" {
  // 前缘留 4、后缘留 30：LTR 的可用区左移，RTL 的可用区右移。选一个必定越界的
  // 内容尺寸，让 resolve 走回退夹紧路径，落点才暴露出用的是哪一组 inset。
  let placement = PresentationPlacement::new(candidates=[BelowStart], viewport_insets={
    top: 0.0,
    right: 30.0,
    bottom: 0.0,
    left: 4.0,
  })
  let viewport = @core.Rect::new(x=0.0, y=0.0, width=100.0, height=60.0)
  let wide = @core.Size::new(width=200.0, height=10.0)
  let ltr = placement.resolve(
    @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
    viewport,
    wide,
    direction=LeftToRight,
  )
  let rtl = placement.resolve(
    @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
    viewport,
    wide,
    direction=RightToLeft,
  )
  assert_eq(ltr.origin.x, 4.0)
  assert_eq(rtl.origin.x, 30.0)
  assert_eq(rtl.size.width, ltr.size.width)
  assert_eq(rtl.origin.y, ltr.origin.y)
}

///|
test "a mirrored candidate keeps the anchor gap on the same axis" {
  let anchor = placement_anchor()
  let size = placement_content()
  let directions : Array[@core.LayoutDirection] = [LeftToRight, RightToLeft]
  for direction in directions {
    let above = presentation_candidate_rect(AboveStart, anchor, size, direction)
    let below = presentation_candidate_rect(BelowStart, anchor, size, direction)
    // Above/Below 是方向无关的轴：两种读序下 y 完全一致
    assert_eq(above.origin.y, anchor.origin.y - size.height)
    assert_eq(below.origin.y, anchor.max_y())
  }
}
