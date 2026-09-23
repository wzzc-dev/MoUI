///|
test "Rect::is_empty reports non-positive rectangles" {
  assert_true(
    !@graphics.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0).is_empty(),
  )
  assert_true(
    @graphics.Rect::new(x=0.0, y=0.0, width=0.0, height=1.0).is_empty(),
  )
  assert_true(
    @graphics.Rect::new(x=0.0, y=0.0, width=1.0, height=-1.0).is_empty(),
  )
}

///|
test "Rect::intersection returns overlapping area" {
  let left = @graphics.Rect::new(x=0.0, y=1.0, width=4.0, height=3.0)
  let right = @graphics.Rect::new(x=2.0, y=0.0, width=3.0, height=2.0)
  assert_true(
    left.intersection(right) ==
    Some(@graphics.Rect::new(x=2.0, y=1.0, width=2.0, height=1.0)),
  )
  assert_true(right.intersection(left) == left.intersection(right))
}

///|
test "Rect::intersection rejects touching or disjoint rectangles" {
  let base = @graphics.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0)
  assert_true(
    base.intersection(@graphics.Rect::new(x=2.0, y=0.0, width=1.0, height=1.0)) ==
    None,
  )
  assert_true(
    base.intersection(@graphics.Rect::new(x=3.0, y=0.0, width=1.0, height=1.0)) ==
    None,
  )
  assert_true(
    base.intersection(@graphics.Rect::new(x=0.0, y=0.0, width=0.0, height=1.0)) ==
    None,
  )
}
