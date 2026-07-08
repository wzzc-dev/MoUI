///|
fn test_float_near(a : Float, b : Float) -> Bool {
  (a - b).abs() <= 0.0001
}

///|
fn test_point_near(a : @moui_skia.Point, b : @moui_skia.Point) -> Bool {
  test_float_near(a.x, b.x) && test_float_near(a.y, b.y)
}

///|
fn test_rect_near(a : @moui_skia.Rect, b : @moui_skia.Rect) -> Bool {
  test_float_near(a.left, b.left) &&
  test_float_near(a.top, b.top) &&
  test_float_near(a.right, b.right) &&
  test_float_near(a.bottom, b.bottom)
}

///|
fn test_optional_rect_near(a : @moui_skia.Rect?, b : @moui_skia.Rect) -> Bool {
  match a {
    None => false
    Some(a) => test_rect_near(a, b)
  }
}

///|
test "color packs argb channels" {
  let color = @moui_skia.Color::from_argb(0x80, 0x11, 0x22, 0x33)
  assert_eq(color.argb(), 0x80112233U)
  assert_eq(color.a(), 0x80)
  assert_eq(color.r(), 0x11)
  assert_eq(color.g(), 0x22)
  assert_eq(color.b(), 0x33)
}

///|
test "point and size expose finite and vector helpers" {
  let a = @moui_skia.Point::new(3, 4)
  let b = @moui_skia.Point::new(-2, 5)
  assert_true(a.is_finite())
  assert_true(!@moui_skia.Point::new(1.0 / 0.0, 0).is_finite())
  assert_eq(a.length_squared(), 25.0)
  assert_eq(a.length(), 5.0)
  assert_eq(a.distance_to_origin_squared(), 25.0)
  assert_eq(a.dot(b), 14.0)
  assert_eq(a.cross(b), 23.0)
  assert_eq(a.distance_to_squared(b), 26.0)
  assert_eq(a.distance_to(b), @moui_skia.Point::new(5, -1).length())
  assert_true(a.normalized() == Some(@moui_skia.Point::new(0.6, 0.8)))
  assert_true(a.with_length(10) == Some(@moui_skia.Point::new(6, 8)))
  assert_true(a.with_length(-1) is None)
  assert_true(@moui_skia.Point::zero().normalized() is None)
  assert_true(a.rotate_cw() == @moui_skia.Point::new(4, -3))
  assert_true(a.rotate_ccw() == @moui_skia.Point::new(-4, 3))

  let size = @moui_skia.Size::new(8, 13)
  assert_true(size.is_finite())
  assert_true(!@moui_skia.Size::new(0.0 / 0.0, 1).is_finite())
}

///|
test "rect intersection and containment" {
  let outer = @moui_skia.Rect::from_xywh(0, 0, 10, 10)
  let inner = @moui_skia.Rect::from_xywh(2, 3, 4, 5)
  let overlap = @moui_skia.Rect::from_xywh(8, 8, 5, 5)
  assert_true(outer.contains_rect(inner))
  assert_true(
    outer.intersect(overlap) == Some(@moui_skia.Rect::new(8, 8, 10, 10)),
  )
}

///|
test "rect constructors and immutable offsets mirror skia helpers" {
  let point = @moui_skia.Point::new(2, 3)
  let size = @moui_skia.Size::new(4, 5)
  let rect = @moui_skia.Rect::from_point_and_size(point, size)
  assert_true(rect == @moui_skia.Rect::from_xywh(2, 3, 4, 5))
  assert_true(rect == @moui_skia.Rect::from_ltrb(2, 3, 6, 8))
  assert_true(
    @moui_skia.Rect::from_wh(4, 5) == @moui_skia.Rect::from_size(size),
  )
  assert_true(@moui_skia.Rect::from_iwh(4, 5) == @moui_skia.Rect::from_wh(4, 5))
  assert_true(
    @moui_skia.Rect::from_isize(@moui_skia.ISize::new(4, 5)) ==
    @moui_skia.Rect::from_wh(4, 5),
  )
  assert_true(
    @moui_skia.Rect::from_points([
      @moui_skia.Point::new(5, 4),
      @moui_skia.Point::new(1, 9),
      @moui_skia.Point::new(3, -2),
    ]) ==
    Some(@moui_skia.Rect::new(1, -2, 5, 9)),
  )
  assert_true(
    @moui_skia.Rect::from_points_or_empty([]) == @moui_skia.Rect::empty(),
  )
  assert_eq(rect.x(), 2.0)
  assert_eq(rect.y(), 3.0)
  assert_eq(rect.left(), 2.0)
  assert_eq(rect.top(), 3.0)
  assert_eq(rect.right(), 6.0)
  assert_eq(rect.bottom(), 8.0)
  assert_true(rect.intersects(@moui_skia.Rect::from_xywh(5, 7, 3, 3)))
  assert_true(!rect.intersects(@moui_skia.Rect::from_xywh(6, 8, 2, 2)))

  let irect = @moui_skia.IRect::from_point_and_size(
    @moui_skia.IPoint::new(2, 3),
    @moui_skia.ISize::new(4, 5),
  )
  assert_true(irect == @moui_skia.IRect::from_xywh(2, 3, 4, 5))
  assert_true(irect == @moui_skia.IRect::from_ltrb(2, 3, 6, 8))
  assert_true(
    @moui_skia.IRect::from_wh(4, 5) ==
    @moui_skia.IRect::from_size(@moui_skia.ISize::new(4, 5)),
  )
  assert_true(@moui_skia.Rect::from_irect(irect) == rect)
  assert_eq(irect.x(), 2)
  assert_eq(irect.y(), 3)
  assert_eq(irect.left(), 2)
  assert_eq(irect.top(), 3)
  assert_eq(irect.right(), 6)
  assert_eq(irect.bottom(), 8)
  assert_eq(irect.width_64(), 4L)
  assert_eq(irect.height_64(), 5L)
  assert_true(!irect.is_empty_64())
  assert_true(irect.intersects(@moui_skia.IRect::from_xywh(5, 7, 3, 3)))
  assert_true(!irect.intersects(@moui_skia.IRect::from_xywh(6, 8, 2, 2)))

  assert_true(
    rect.with_offset(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    rect.with_offset_to(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    rect.with_inset(@moui_skia.Size::new(1, 2)) ==
    @moui_skia.Rect::new(3, 5, 5, 6),
  )
  assert_true(
    rect.with_outset(@moui_skia.Size::new(1, 2)) ==
    @moui_skia.Rect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_offset(@moui_skia.IPoint::new(10, -1)) ==
    @moui_skia.IRect::from_xywh(12, 2, 4, 5),
  )
  assert_true(
    irect.with_offset_to(@moui_skia.IPoint::new(10, -1)) ==
    @moui_skia.IRect::from_xywh(10, -1, 4, 5),
  )
  assert_true(
    irect.with_inset(@moui_skia.ISize::new(1, 2)) ==
    @moui_skia.IRect::new(3, 5, 5, 6),
  )
  assert_true(
    irect.with_outset(@moui_skia.ISize::new(1, 2)) ==
    @moui_skia.IRect::new(1, 1, 7, 10),
  )
  assert_true(
    irect.with_adjustment(1, -2, 3, 4) == @moui_skia.IRect::new(3, 1, 9, 12),
  )

  let wide = @moui_skia.IRect::new(-2000000000, 0, 2000000000, 1)
  assert_eq(wide.width_64(), 4000000000L)
  assert_true(!wide.is_empty_64())
  assert_true(
    @moui_skia.IRect::new(0, 2000000000, 1, -2000000000).is_empty_64(),
  )
}

///|
test "rect exposes skia-style sorted center finite and rounding helpers" {
  let unsorted = @moui_skia.Rect::new(5, 4, 1, 2)
  assert_true(!unsorted.is_sorted())
  assert_true(unsorted.sorted().is_sorted())
  assert_true(unsorted.center() == @moui_skia.Point::new(3, 3))
  assert_eq(unsorted.center_x(), 3.0)
  assert_eq(unsorted.center_y(), 3.0)
  assert_true(unsorted.is_finite())
  assert_true(!@moui_skia.Rect::new(0, 0, 1.0 / 0.0, 1).is_finite())

  let fractional = @moui_skia.Rect::new(1.2, -2.8, 5.7, 3.1)
  assert_true(fractional.round() == @moui_skia.IRect::new(1, -3, 6, 3))
  assert_true(fractional.to_irect_round() == fractional.round())
  assert_true(fractional.round_in() == @moui_skia.IRect::new(2, -2, 5, 3))
  assert_true(fractional.round_out() == @moui_skia.IRect::new(1, -3, 6, 4))

  let unsorted_i = @moui_skia.IRect::new(4, 5, 1, 2)
  assert_true(!unsorted_i.is_sorted())
  assert_true(unsorted_i.sorted().is_sorted())
}

///|
test "rect exposes corner points and quads" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  assert_true(rect.top_left() == @moui_skia.Point::new(1, 2))
  assert_true(rect.tl() == rect.top_left())
  assert_true(rect.top_right() == @moui_skia.Point::new(4, 2))
  assert_true(rect.tr() == rect.top_right())
  assert_true(rect.bottom_right() == @moui_skia.Point::new(4, 6))
  assert_true(rect.br() == rect.bottom_right())
  assert_true(rect.bottom_left() == @moui_skia.Point::new(1, 6))
  assert_true(rect.bl() == rect.bottom_left())
  assert_true(
    rect.to_quad() ==
    [
      @moui_skia.Point::new(1, 2),
      @moui_skia.Point::new(4, 2),
      @moui_skia.Point::new(4, 6),
      @moui_skia.Point::new(1, 6),
    ],
  )
  assert_true(
    rect.to_quad(direction=CCW) ==
    [
      @moui_skia.Point::new(1, 2),
      @moui_skia.Point::new(1, 6),
      @moui_skia.Point::new(4, 6),
      @moui_skia.Point::new(4, 2),
    ],
  )
}

///|
test "matrix maps point" {
  let point = @moui_skia.Point::new(2, 3)
  let matrix = @moui_skia.Matrix::scale_translate(2, 4, 10, 20)
  assert_true(matrix.map_point(point) == @moui_skia.Point::new(14, 32))
  assert_true(matrix.is_scale_translate())
}
