///|
test "Rect::is_empty reports non-positive rectangles" {
  assert_true(!Rect::new(x=0.0, y=0.0, width=1.0, height=1.0).is_empty())
  assert_true(Rect::new(x=0.0, y=0.0, width=0.0, height=1.0).is_empty())
  assert_true(Rect::new(x=0.0, y=0.0, width=1.0, height=-1.0).is_empty())
}

///|
test "Rect::intersection returns overlapping area" {
  let left = Rect::new(x=0.0, y=1.0, width=4.0, height=3.0)
  let right = Rect::new(x=2.0, y=0.0, width=3.0, height=2.0)
  assert_true(
    left.intersection(right) ==
    Some(Rect::new(x=2.0, y=1.0, width=2.0, height=1.0)),
  )
  assert_true(right.intersection(left) == left.intersection(right))
}

///|
test "Rect::intersection rejects touching or disjoint rectangles" {
  let base = Rect::new(x=0.0, y=0.0, width=2.0, height=2.0)
  assert_true(
    base.intersection(Rect::new(x=2.0, y=0.0, width=1.0, height=1.0)) == None,
  )
  assert_true(
    base.intersection(Rect::new(x=3.0, y=0.0, width=1.0, height=1.0)) == None,
  )
  assert_true(
    base.intersection(Rect::new(x=0.0, y=0.0, width=0.0, height=1.0)) == None,
  )
}
