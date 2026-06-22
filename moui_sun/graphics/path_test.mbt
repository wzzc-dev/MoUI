///|
test "Path::new creates empty path" {
  let path = Path::new()
  assert_true(path.is_empty())
  assert_eq(path.segment_count(), 0)
}

///|
test "Path::add_rect creates rectangle path" {
  let path = Path::new()
  ignore(path.add_rect(0.0, 0.0, 100.0, 50.0))
  let segments = path.get_segments()
  // move_to + 3 line_to + close = 5 segments
  inspect(path.segment_count(), content="5")
  assert_eq(segments.length(), path.segment_count())
}

///|
test "Path::get_segments returns an isolated segment array" {
  let path = Path::new().move_to(1.0, 2.0).line_to(3.0, 4.0)
  let segments = path.get_segments()
  let replacement_segments = Path::new()
    .move_to(9.0, 9.0)
    .line_to(10.0, 10.0)
    .get_segments()
  segments[0] = replacement_segments[0]
  segments.push(replacement_segments[1])

  assert_eq(path.segment_count(), 2)
  let fresh = path.get_segments()
  assert_eq(fresh.length(), 2)
  assert_move_to(fresh[0], 1.0, 2.0)
  assert_line_to(fresh[1], 3.0, 4.0)
}

///|
test "Path::add_polyline creates open line path" {
  let points = [
    Point::new(x=1.0, y=1.0),
    Point::new(x=3.0, y=1.0),
    Point::new(x=3.0, y=4.0),
  ]
  let path = Path::new().add_polyline(points)
  let segments = path.get_segments()
  inspect(segments.length(), content="3")
  assert_move_to(segments[0], 1.0, 1.0)
  assert_line_to(segments[1], 3.0, 1.0)
  assert_line_to(segments[2], 3.0, 4.0)
}

///|
test "Path::add_polygon creates closed polygon path" {
  let points = [
    Point::new(x=1.0, y=1.0),
    Point::new(x=4.0, y=1.0),
    Point::new(x=2.0, y=4.0),
  ]
  let path = Path::new().add_polygon(points)
  let segments = path.get_segments()
  inspect(segments.length(), content="4")
  assert_move_to(segments[0], 1.0, 1.0)
  assert_line_to(segments[1], 4.0, 1.0)
  assert_line_to(segments[2], 2.0, 4.0)
  assert_close(segments[3])
}

///|
test "Path::add_polyline and add_polygon ignore invalid point counts" {
  let empty_polyline = Path::new().add_polyline([])
  assert_true(empty_polyline.is_empty())

  let line = Path::new().add_polygon([
    Point::new(x=0.0, y=0.0),
    Point::new(x=1.0, y=1.0),
  ])
  assert_true(line.is_empty())
}

///|
test "Path::add_rounded_rect creates cubic corner path" {
  let path = Path::new()
  ignore(path.add_rounded_rect(0.0, 0.0, 10.0, 6.0, 2.0))
  let segments = path.get_segments()
  inspect(segments.length(), content="10")
  assert_move_to(segments[0], 2.0, 0.0)
  assert_line_to(segments[1], 8.0, 0.0)
  assert_cubic_to_end(segments[2], 10.0, 2.0)
  assert_line_to(segments[3], 10.0, 4.0)
  assert_close(segments[9])
}

///|
test "Path::add_rounded_rect clamps radius and falls back to rect" {
  let pill = Path::new().add_rounded_rect(0.0, 0.0, 10.0, 4.0, 9.0)
  let segments = pill.get_segments()
  assert_move_to(segments[0], 2.0, 0.0)
  assert_line_to(segments[1], 8.0, 0.0)

  let rect = Path::new().add_rounded_rect(0.0, 0.0, 10.0, 4.0, 0.0)
  assert_true(rect.get_segments().length() == 5)
}

///|
test "Path::add_rounded_rect_corners creates independent corner path" {
  let path = Path::new().add_rounded_rect_corners(
    0.0, 0.0, 10.0, 6.0, 2.0, 3.0, 0.0, 0.0,
  )
  let segments = path.get_segments()
  inspect(segments.length(), content="8")
  assert_move_to(segments[0], 2.0, 0.0)
  assert_line_to(segments[1], 7.0, 0.0)
  assert_cubic_to_end(segments[2], 10.0, 3.0)
  assert_line_to(segments[3], 10.0, 6.0)
  assert_line_to(segments[4], 0.0, 6.0)
  assert_line_to(segments[5], 0.0, 2.0)
  assert_cubic_to_end(segments[6], 2.0, 0.0)
  assert_close(segments[7])
}

///|
test "Path::add_rounded_rect_corners clamps and falls back to rect" {
  let clamped = Path::new().add_rounded_rect_corners(
    0.0, 0.0, 10.0, 4.0, 9.0, -1.0, 0.0, 0.0,
  )
  let segments = clamped.get_segments()
  assert_move_to(segments[0], 2.0, 0.0)
  assert_line_to(segments[1], 10.0, 0.0)
  assert_cubic_to_end(segments[5], 2.0, 0.0)

  let rect = Path::new().add_rounded_rect_corners(
    0.0, 0.0, 10.0, 4.0, 0.0, 0.0, 0.0, 0.0,
  )
  assert_true(rect.get_segments().length() == 5)
}

///|
test "Path::add_circle creates circle path" {
  let path = Path::new()
  ignore(path.add_circle(50.0, 50.0, 25.0))
  let segments = path.get_segments()
  // move_to + 4 cubic_to + close = 6 segments
  inspect(segments.length(), content="6")
}

///|
test "Path::add_ellipse creates ellipse path" {
  let path = Path::new()
  ignore(path.add_ellipse(10.0, 8.0, 6.0, 3.0))
  let segments = path.get_segments()
  // move_to + 4 cubic_to + close = 6 segments
  inspect(segments.length(), content="6")
  assert_move_to(segments[0], 16.0, 8.0)
  assert_cubic_to_end(segments[1], 10.0, 5.0)
  assert_cubic_to_end(segments[2], 4.0, 8.0)
  assert_cubic_to_end(segments[3], 10.0, 11.0)
  assert_cubic_to_end(segments[4], 16.0, 8.0)
  assert_close(segments[5])
}

///|
test "Path::add_circle and add_ellipse ignore invalid radii" {
  assert_true(Path::new().add_circle(0.0, 0.0, 0.0).is_empty())
  assert_true(Path::new().add_circle(0.0, 0.0, -1.0).is_empty())
  assert_true(Path::new().add_circle(0.0, 0.0, 0.0 / 0.0).is_empty())

  assert_true(Path::new().add_ellipse(0.0, 0.0, 0.0, 1.0).is_empty())
  assert_true(Path::new().add_ellipse(0.0, 0.0, 1.0, 0.0).is_empty())
  assert_true(Path::new().add_ellipse(0.0, 0.0, -1.0, 1.0).is_empty())
  assert_true(Path::new().add_ellipse(0.0, 0.0, 1.0, -1.0).is_empty())
  assert_true(Path::new().add_ellipse(0.0, 0.0, 0.0 / 0.0, 1.0).is_empty())
  assert_true(Path::new().add_ellipse(0.0, 0.0, 1.0, 0.0 / 0.0).is_empty())
}

///|
test "Path::add_arc creates open cubic arc path" {
  let path = Path::new().add_arc(4.0, 4.0, 3.0, 0.0, 1.5707963267948966)
  let segments = path.get_segments()
  inspect(segments.length(), content="2")
  assert_move_to(segments[0], 7.0, 4.0)
  assert_cubic_to_end_near(segments[1], 4.0, 7.0)
}

///|
test "Path::add_arc splits long sweeps and ignores invalid arcs" {
  let arc = Path::new().add_arc(0.0, 0.0, 2.0, 0.0, 3.141592653589793)
  let segments = arc.get_segments()
  inspect(segments.length(), content="3")
  assert_move_to(segments[0], 2.0, 0.0)
  assert_cubic_to_end_near(segments[1], 0.0, 2.0)
  assert_cubic_to_end_near(segments[2], -2.0, 0.0)

  assert_true(Path::new().add_arc(0.0, 0.0, 0.0, 0.0, 1.0).is_empty())
  assert_true(Path::new().add_arc(0.0, 0.0, 1.0, 0.0, 0.0).is_empty())
  assert_true(Path::new().add_arc(0.0, 0.0, 1.0, 0.0 / 0.0, 1.0).is_empty())
  assert_true(Path::new().add_arc(0.0, 0.0, 1.0, 0.0, 0.0 / 0.0).is_empty())
}

///|
test "Path::add_arc preserves negative sweeps and clamps full turns" {
  let negative = Path::new().add_arc(0.0, 0.0, 2.0, 0.0, -1.5707963267948966)
  let segments = negative.get_segments()
  assert_eq(segments.length(), 2)
  assert_move_to(segments[0], 2.0, 0.0)
  assert_cubic_to_end_near(segments[1], 0.0, -2.0)

  let clamped = Path::new().add_arc(0.0, 0.0, 2.0, 0.0, 9.0)
  let clamped_segments = clamped.get_segments()
  assert_eq(clamped_segments.length(), 5)
  assert_move_to(clamped_segments[0], 2.0, 0.0)
  assert_cubic_to_end_near(clamped_segments[1], 0.0, 2.0)
  assert_cubic_to_end_near(clamped_segments[2], -2.0, 0.0)
  assert_cubic_to_end_near(clamped_segments[3], 0.0, -2.0)
  assert_cubic_to_end_near(clamped_segments[4], 2.0, 0.0)
}

///|
test "Path::add_pie creates closed slice path" {
  let path = Path::new().add_pie(4.0, 4.0, 3.0, 0.0, 1.5707963267948966)
  let segments = path.get_segments()
  inspect(segments.length(), content="4")
  assert_move_to(segments[0], 4.0, 4.0)
  assert_line_to(segments[1], 7.0, 4.0)
  assert_cubic_to_end_near(segments[2], 4.0, 7.0)
  assert_close(segments[3])
}

///|
test "Path::add_pie preserves negative sweeps and ignores invalid pies" {
  let path = Path::new().add_pie(0.0, 0.0, 2.0, 0.0, -1.5707963267948966)
  let segments = path.get_segments()
  assert_eq(segments.length(), 4)
  assert_move_to(segments[0], 0.0, 0.0)
  assert_line_to(segments[1], 2.0, 0.0)
  assert_cubic_to_end_near(segments[2], 0.0, -2.0)
  assert_close(segments[3])

  assert_true(Path::new().add_pie(0.0, 0.0, 0.0, 0.0, 1.0).is_empty())
  assert_true(Path::new().add_pie(0.0, 0.0, -1.0, 0.0, 1.0).is_empty())
  assert_true(Path::new().add_pie(0.0, 0.0, 0.0 / 0.0, 0.0, 1.0).is_empty())
  assert_true(Path::new().add_pie(0.0, 0.0, 1.0, 0.0 / 0.0, 1.0).is_empty())
  assert_true(Path::new().add_pie(0.0, 0.0, 1.0, 0.0, 0.0).is_empty())
  assert_true(Path::new().add_pie(0.0, 0.0, 1.0, 0.0, 0.0 / 0.0).is_empty())
}

///|
test "Path::control_bounds returns conservative control-point bounds" {
  assert_true(Path::new().control_bounds() == None)

  let rect = Path::new().add_rect(1.0, 2.0, 3.0, 4.0)
  assert_true(
    rect.control_bounds() ==
    Some(Rect::new(x=1.0, y=2.0, width=3.0, height=4.0)),
  )

  let curve = Path::new()
    .move_to(1.0, 2.0)
    .quad_to(-3.0, 7.0, 4.0, 5.0)
    .cubic_to(8.0, -2.0, 6.0, 9.0, 2.0, 1.0)
  assert_true(
    curve.control_bounds() ==
    Some(Rect::new(x=-3.0, y=-2.0, width=11.0, height=11.0)),
  )
}

///|
test "Path::rect_bounds recognizes closed axis-aligned rectangles" {
  let rect = Path::new().add_rect(1.0, 2.0, 3.0, 4.0)
  assert_true(
    rect.rect_bounds() == Some(Rect::new(x=1.0, y=2.0, width=3.0, height=4.0)),
  )

  let negative = Path::new().add_rect(4.0, 6.0, -3.0, -4.0)
  assert_true(
    negative.rect_bounds() ==
    Some(Rect::new(x=1.0, y=2.0, width=3.0, height=4.0)),
  )

  let explicit = Path::new()
    .move_to(1.0, 2.0)
    .line_to(1.0, 6.0)
    .line_to(4.0, 6.0)
    .line_to(4.0, 2.0)
    .line_to(1.0, 2.0)
  assert_true(
    explicit.rect_bounds() ==
    Some(Rect::new(x=1.0, y=2.0, width=3.0, height=4.0)),
  )
}

///|
test "Path::rect_bounds rejects non-rectangle paths" {
  assert_true(Path::new().rect_bounds() == None)
  assert_true(
    Path::new()
    .add_polyline([
      Point::new(x=0.0, y=0.0),
      Point::new(x=2.0, y=0.0),
      Point::new(x=2.0, y=2.0),
    ])
    .rect_bounds() ==
    None,
  )

  let rounded = Path::new().add_rounded_rect(0.0, 0.0, 4.0, 4.0, 1.0)
  assert_true(rounded.rect_bounds() == None)

  let multi = Path::new()
    .add_rect(0.0, 0.0, 1.0, 1.0)
    .add_rect(2.0, 0.0, 1.0, 1.0)
  assert_true(multi.rect_bounds() == None)

  let l_shape = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(2.0, 1.0)
    .line_to(1.0, 1.0)
    .line_to(1.0, 2.0)
    .line_to(0.0, 2.0)
    .close()
  assert_true(l_shape.rect_bounds() == None)
}

///|
test "Path::line_polygon_points returns isolated simplified points" {
  let path = Path::new()
    .move_to(9.0, 9.0)
    .close()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(2.0, 1.0)
    .line_to(0.0, 1.0)
    .line_to(0.0, 0.0)
  assert_true(path.is_line_polygon())
  match path.line_polygon_points() {
    Some(points) => {
      assert_eq(points.length(), 4)
      assert_true(points[0] == Point::new(x=0.0, y=0.0))
      assert_true(points[1] == Point::new(x=2.0, y=0.0))
      assert_true(points[2] == Point::new(x=2.0, y=1.0))
      assert_true(points[3] == Point::new(x=0.0, y=1.0))
      points[0] = Point::new(x=99.0, y=99.0)
    }
    None => abort("expected line polygon points")
  }
  match path.line_polygon_points() {
    Some(fresh) => assert_true(fresh[0] == Point::new(x=0.0, y=0.0))
    None => abort("expected fresh line polygon points")
  }
}

///|
test "Path::line_polygon_area reports signed and absolute area" {
  let forward = Path::new()
    .move_to(0.0, 0.0)
    .line_to(3.0, 0.0)
    .line_to(3.0, 2.0)
    .line_to(0.0, 2.0)
    .close()
  assert_true(forward.line_polygon_signed_area() == Some(6.0))
  assert_true(forward.line_polygon_area() == Some(6.0))

  let reversed = Path::new()
    .move_to(0.0, 0.0)
    .line_to(0.0, 2.0)
    .line_to(3.0, 2.0)
    .line_to(3.0, 0.0)
    .close()
  assert_true(reversed.line_polygon_signed_area() == Some(-6.0))
  assert_true(reversed.line_polygon_area() == Some(6.0))

  let degenerate = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(4.0, 0.0)
    .close()
  assert_true(degenerate.is_line_polygon())
  assert_true(degenerate.line_polygon_signed_area() == Some(0.0))
  assert_true(degenerate.line_polygon_area() == Some(0.0))
}

///|
test "Path::line_polygon_points rejects non-single-line polygons" {
  let open = Path::new().move_to(0.0, 0.0).line_to(1.0, 0.0)
  assert_true(!open.is_line_polygon())
  assert_true(open.line_polygon_points() is None)
  assert_true(open.line_polygon_signed_area() == None)
  assert_true(open.line_polygon_area() == None)

  let curved = Path::new().move_to(0.0, 0.0).quad_to(1.0, 1.0, 2.0, 0.0).close()
  assert_true(!curved.is_line_polygon())

  let multi = Path::new()
    .add_rect(0.0, 0.0, 1.0, 1.0)
    .add_rect(2.0, 0.0, 1.0, 1.0)
  assert_true(!multi.is_line_polygon())
  assert_true(multi.line_polygon_points() is None)
}

///|
test "Path::rect_bounds consumes simplified line polygon points" {
  let noisy_rect = Path::new()
    .move_to(5.0, 5.0)
    .close()
    .move_to(0.0, 0.0)
    .quad_to(2.0, 0.0, 4.0, 0.0)
    .line_to(4.0, 3.0)
    .line_to(0.0, 3.0)
    .line_to(0.0, 0.0)
    .close()
  assert_true(
    noisy_rect.rect_bounds() ==
    Some(Rect::new(x=0.0, y=0.0, width=4.0, height=3.0)),
  )
}

///|
test "Path::rect_boolean intersects rect-like paths" {
  let a = Path::new().add_rect(0.0, 0.0, 3.0, 2.0)
  let b = Path::new().add_rect(2.0, 1.0, 3.0, 2.0)
  match a.rect_boolean(b, PathBooleanOp::Intersection) {
    Some(intersection) => {
      assert_true(
        intersection.rect_bounds() ==
        Some(Rect::new(x=2.0, y=1.0, width=1.0, height=1.0)),
      )
      assert_true(intersection.contains_point(2.5, 1.5, FillRule::NonZero))
      assert_true(!intersection.contains_point(1.5, 1.5, FillRule::NonZero))
    }
    None => abort("expected rect intersection")
  }

  match
    a.rect_boolean(
      Path::new().add_rect(8.0, 8.0, 1.0, 1.0),
      PathBooleanOp::Intersection,
    ) {
    Some(empty) => assert_true(empty.is_empty())
    None => abort("expected empty rect intersection path")
  }
}

///|
test "Path::rect_boolean unions overlapping rect-like paths" {
  let a = Path::new().add_rect(0.0, 0.0, 3.0, 2.0)
  let b = Path::new().add_rect(2.0, 1.0, 3.0, 2.0)
  match a.rect_boolean(b, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.control_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=5.0, height=3.0)),
      )
      assert_true(union.contains_point(0.5, 0.5, FillRule::NonZero))
      assert_true(union.contains_point(2.5, 1.5, FillRule::NonZero))
      assert_true(union.contains_point(4.5, 2.5, FillRule::NonZero))
      assert_true(!union.contains_point(0.5, 2.5, FillRule::NonZero))
      assert_true(!union.is_line_polygon())
    }
    None => abort("expected rect union")
  }
}

///|
test "Path::rect_boolean coalesces adjacent rect cells" {
  let left = Path::new().add_rect(0.0, 0.0, 2.0, 2.0)
  let right = Path::new().add_rect(2.0, 0.0, 3.0, 2.0)
  match left.rect_boolean(right, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(union.is_line_polygon())
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=5.0, height=2.0)),
      )
      assert_eq(union.segment_count(), 5)
    }
    None => abort("expected adjacent horizontal rect union")
  }

  let top = Path::new().add_rect(0.0, 0.0, 2.0, 2.0)
  let bottom = Path::new().add_rect(0.0, 2.0, 2.0, 3.0)
  match top.rect_boolean(bottom, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(union.is_line_polygon())
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=5.0)),
      )
      assert_eq(union.segment_count(), 5)
    }
    None => abort("expected adjacent vertical rect union")
  }
}

///|
test "Path::rect_boolean subtracts rect-like paths into cell subpaths" {
  let a = Path::new().add_rect(0.0, 0.0, 4.0, 3.0)
  let b = Path::new().add_rect(1.0, 0.0, 2.0, 3.0)
  match a.rect_boolean(b, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(diff.contains_point(0.5, 1.5, FillRule::NonZero))
      assert_true(diff.contains_point(3.5, 1.5, FillRule::NonZero))
      assert_true(!diff.contains_point(2.0, 1.5, FillRule::NonZero))
      assert_true(!diff.is_line_polygon())
      assert_eq(diff.segment_count(), 10)
    }
    None => abort("expected rect difference")
  }
}

///|
test "Path::rect_boolean rejects non-rect operands" {
  let rect = Path::new().add_rect(0.0, 0.0, 2.0, 2.0)
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(1.0, 2.0)
    .close()
  assert_true(rect.rect_boolean(triangle, PathBooleanOp::Union) is None)
  assert_true(triangle.rect_boolean(rect, PathBooleanOp::Difference) is None)
}

///|
test "Path::boolean dispatches rect-like union intersection and difference" {
  let a = Path::new().add_rect(0.0, 0.0, 3.0, 2.0)
  let b = Path::new().add_rect(2.0, 0.0, 2.0, 2.0)
  match a.boolean(b, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.control_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=4.0, height=2.0)),
      )
      assert_true(union.contains_point(3.5, 1.0, FillRule::NonZero))
    }
    None => abort("expected boolean rect union")
  }
  match a.boolean(b, PathBooleanOp::Intersection) {
    Some(intersection) =>
      assert_true(
        intersection.rect_bounds() ==
        Some(Rect::new(x=2.0, y=0.0, width=1.0, height=2.0)),
      )
    None => abort("expected boolean rect intersection")
  }
  match a.boolean(b, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(diff.contains_point(1.0, 1.0, FillRule::NonZero))
      assert_true(!diff.contains_point(2.5, 1.0, FillRule::NonZero))
    }
    None => abort("expected boolean rect difference")
  }
  match a.boolean(b, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(xor.contains_point(1.0, 1.0, FillRule::NonZero))
      assert_true(xor.contains_point(3.5, 1.0, FillRule::NonZero))
      assert_true(!xor.contains_point(2.5, 1.0, FillRule::NonZero))
      assert_eq(xor.segment_count(), 10)
    }
    None => abort("expected boolean rect xor")
  }
}

///|
test "Path::boolean treats edge-touching rects as non-overlapping" {
  let left = Path::new().add_rect(0.0, 0.0, 2.0, 2.0)
  let right = Path::new().add_rect(2.0, 0.0, 3.0, 2.0)

  match left.boolean(right, PathBooleanOp::Intersection) {
    Some(intersection) => assert_true(intersection.is_empty())
    None => abort("expected touching rect intersection")
  }

  match left.boolean(right, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(
        diff.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=2.0)),
      )
      assert_true(diff.contains_point(1.0, 1.0, FillRule::NonZero))
      assert_true(!diff.contains_point(3.0, 1.0, FillRule::NonZero))
      assert_eq(diff.segment_count(), 5)
    }
    None => abort("expected touching rect difference")
  }

  match left.boolean(right, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(
        xor.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=5.0, height=2.0)),
      )
      assert_true(xor.contains_point(1.0, 1.0, FillRule::NonZero))
      assert_true(xor.contains_point(3.0, 1.0, FillRule::NonZero))
      assert_eq(xor.segment_count(), 5)
    }
    None => abort("expected touching rect xor")
  }
}

///|
test "Path::boolean handles empty operands as identities" {
  let empty = Path::new()
  let empty_noise = Path::new().move_to(8.0, 8.0).line_to(8.0, 8.0).close()
  let rect = Path::new().move_to(9.0, 9.0).close().add_rect(0.0, 0.0, 2.0, 1.0)

  match empty.boolean(rect, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_eq(union.segment_count(), 5)
      assert_true(union.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected empty-left union identity")
  }
  match rect.boolean(empty_noise, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_eq(union.segment_count(), 5)
    }
    None => abort("expected empty-right union identity")
  }
  match empty.boolean(rect, PathBooleanOp::Intersection) {
    Some(intersection) => assert_true(intersection.is_empty())
    None => abort("expected empty-left intersection")
  }
  match rect.boolean(empty_noise, PathBooleanOp::Intersection) {
    Some(intersection) => assert_true(intersection.is_empty())
    None => abort("expected empty-right intersection")
  }
  match empty.boolean(rect, PathBooleanOp::Difference) {
    Some(diff) => assert_true(diff.is_empty())
    None => abort("expected empty-left difference")
  }
  match rect.boolean(empty_noise, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(
        diff.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_eq(diff.segment_count(), 5)
    }
    None => abort("expected empty-right difference identity")
  }
  match empty.boolean(rect, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(
        xor.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_eq(xor.segment_count(), 5)
    }
    None => abort("expected empty-left xor identity")
  }
  match rect.boolean(empty_noise, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(
        xor.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_eq(xor.segment_count(), 5)
    }
    None => abort("expected empty-right xor identity")
  }
}

///|
test "Path::boolean treats zero-area line polygons as empty operands" {
  let degenerate = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(4.0, 0.0)
    .close()
  let rect = Path::new().add_rect(0.0, 0.0, 2.0, 1.0)

  match degenerate.boolean(rect, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_true(union.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected zero-area-left union identity")
  }
  match rect.boolean(degenerate, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_true(union.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected zero-area-right union identity")
  }
  match degenerate.boolean(rect, PathBooleanOp::Intersection) {
    Some(intersection) => assert_true(intersection.is_empty())
    None => abort("expected zero-area-left intersection")
  }
  match rect.boolean(degenerate, PathBooleanOp::Intersection) {
    Some(intersection) => assert_true(intersection.is_empty())
    None => abort("expected zero-area-right intersection")
  }
  match degenerate.boolean(rect, PathBooleanOp::Difference) {
    Some(diff) => assert_true(diff.is_empty())
    None => abort("expected zero-area-left difference")
  }
  match rect.boolean(degenerate, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(
        diff.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_true(diff.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected zero-area-right difference identity")
  }
  match degenerate.boolean(rect, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(
        xor.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_true(xor.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected zero-area-left xor identity")
  }
  match rect.boolean(degenerate, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(
        xor.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=2.0, height=1.0)),
      )
      assert_true(xor.contains_point(1.0, 0.5, FillRule::NonZero))
    }
    None => abort("expected zero-area-right xor identity")
  }
}

///|
test "Path boolean convenience helpers dispatch supported operations" {
  let left = Path::new().add_rect(0.0, 0.0, 3.0, 2.0)
  let right = Path::new().add_rect(2.0, 0.0, 2.0, 2.0)

  match left.union(right) {
    Some(union) => {
      assert_true(
        union.control_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=4.0, height=2.0)),
      )
      assert_true(union.contains_point(3.5, 1.0, FillRule::NonZero))
    }
    None => abort("expected helper rect union")
  }

  match left.intersection(right) {
    Some(intersection) =>
      assert_true(
        intersection.rect_bounds() ==
        Some(Rect::new(x=2.0, y=0.0, width=1.0, height=2.0)),
      )
    None => abort("expected helper rect intersection")
  }

  match left.difference(right) {
    Some(difference) => {
      assert_true(difference.contains_point(1.0, 1.0, FillRule::NonZero))
      assert_true(!difference.contains_point(2.5, 1.0, FillRule::NonZero))
    }
    None => abort("expected helper rect difference")
  }

  match left.xor(right) {
    Some(xor) => {
      assert_true(xor.contains_point(0.5, 1.0, FillRule::NonZero))
      assert_true(xor.contains_point(3.5, 1.0, FillRule::NonZero))
      assert_true(!xor.contains_point(2.5, 1.0, FillRule::NonZero))
    }
    None => abort("expected helper rect xor")
  }
}

///|
test "Path boolean convenience helpers preserve unsupported shape None" {
  let curved = Path::new().move_to(0.0, 0.0).quad_to(1.0, 2.0, 2.0, 0.0).close()
  let rect = Path::new().add_rect(0.0, 0.0, 2.0, 2.0)

  assert_true(curved.union(rect) is None)
  assert_true(curved.intersection(rect) is None)
  assert_true(curved.difference(rect) is None)
  assert_true(curved.xor(rect) is None)
}

///|
test "Path::boolean intersects convex line polygons" {
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(2.0, 4.0)
    .close()
  let clip = Path::new().add_rect(1.0, 0.0, 2.0, 2.0)
  match triangle.boolean(clip, PathBooleanOp::Intersection) {
    Some(intersection) => {
      assert_true(intersection.is_line_polygon())
      assert_true(
        intersection.rect_bounds() ==
        Some(Rect::new(x=1.0, y=0.0, width=2.0, height=2.0)),
      )
      assert_true(intersection.line_polygon_area() == Some(4.0))
      assert_true(intersection.contains_point(2.0, 1.0, FillRule::NonZero))
      assert_true(!intersection.contains_point(0.5, 1.0, FillRule::NonZero))
      assert_true(!intersection.contains_point(2.0, 3.0, FillRule::NonZero))
    }
    None => abort("expected convex polygon intersection")
  }
}

///|
test "Path::boolean returns empty convex intersection path" {
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(1.0, 2.0)
    .close()
  let far = Path::new().add_rect(8.0, 8.0, 2.0, 2.0)
  match triangle.boolean(far, PathBooleanOp::Intersection) {
    Some(empty) => assert_true(empty.is_empty())
    None => abort("expected empty convex intersection")
  }
}

///|
test "Path::boolean handles identical convex line polygons" {
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 1.0)
    .line_to(0.0, 2.0)
    .close()
  let same = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 1.0)
    .line_to(0.0, 2.0)
    .close()

  match triangle.boolean(same, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(union.is_line_polygon())
      assert_true(union.line_polygon_area() == Some(2.0))
      assert_true(union.contains_point(0.5, 1.0, FillRule::NonZero))
      assert_true(!union.contains_point(1.5, 1.8, FillRule::NonZero))
    }
    None => abort("expected identical convex polygon union")
  }
  match triangle.boolean(same, PathBooleanOp::Intersection) {
    Some(intersection) => {
      assert_true(intersection.is_line_polygon())
      assert_true(intersection.line_polygon_area() == Some(2.0))
      assert_true(intersection.contains_point(0.5, 1.0, FillRule::NonZero))
      assert_true(!intersection.contains_point(1.5, 1.8, FillRule::NonZero))
    }
    None => abort("expected identical convex polygon intersection")
  }
  match triangle.boolean(same, PathBooleanOp::Difference) {
    Some(diff) => assert_true(diff.is_empty())
    None => abort("expected identical convex polygon difference")
  }
  match triangle.boolean(same, PathBooleanOp::Xor) {
    Some(xor) => assert_true(xor.is_empty())
    None => abort("expected identical convex polygon xor")
  }
}

///|
test "Path::boolean unions and subtracts convex line polygons" {
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(1.0, 2.0)
    .close()
  let other = Path::new()
    .move_to(1.0, 0.0)
    .line_to(3.0, 0.0)
    .line_to(2.0, 2.0)
    .close()
  match triangle.boolean(other, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(union.is_line_polygon())
      assert_true(union.line_polygon_area() == Some(3.5))
      assert_true(union.contains_point(0.5, 0.5, FillRule::NonZero))
      assert_true(union.contains_point(2.5, 0.5, FillRule::NonZero))
      assert_true(union.contains_point(1.5, 0.75, FillRule::NonZero))
      assert_true(!union.contains_point(1.5, 2.5, FillRule::NonZero))
    }
    None => abort("expected convex polygon union")
  }
  match triangle.boolean(other, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(diff.is_line_polygon())
      assert_true(diff.line_polygon_area() == Some(1.5))
      assert_true(diff.contains_point(0.5, 0.5, FillRule::NonZero))
      assert_true(diff.contains_point(1.0, 1.5, FillRule::NonZero))
      assert_true(!diff.contains_point(1.5, 0.5, FillRule::NonZero))
      assert_true(!diff.contains_point(2.5, 0.5, FillRule::NonZero))
    }
    None => abort("expected convex polygon difference")
  }
  match triangle.boolean(other, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(!xor.is_line_polygon())
      assert_true(xor.contains_point(0.5, 0.5, FillRule::NonZero))
      assert_true(xor.contains_point(2.5, 0.5, FillRule::NonZero))
      assert_true(!xor.contains_point(1.5, 0.5, FillRule::NonZero))
      assert_true(!xor.contains_point(1.5, 2.5, FillRule::NonZero))
    }
    None => abort("expected convex polygon xor")
  }
}

///|
test "Path::boolean subtracts contained convex line polygon as a hole" {
  let outer = Path::new()
    .move_to(0.0, 0.0)
    .line_to(6.0, 0.0)
    .line_to(3.0, 6.0)
    .close()
  let inner = Path::new()
    .move_to(2.0, 1.0)
    .line_to(4.0, 1.0)
    .line_to(3.0, 3.0)
    .close()
  match outer.boolean(inner, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(!diff.is_line_polygon())
      assert_eq(diff.segment_count(), 8)
      assert_true(diff.contains_point(3.0, 0.5, FillRule::NonZero))
      assert_true(diff.contains_point(3.0, 4.0, FillRule::NonZero))
      assert_true(!diff.contains_point(3.0, 1.5, FillRule::NonZero))
    }
    None => abort("expected contained convex polygon difference")
  }
}

///|
test "Path::boolean combines axis-aligned non-convex line polygons" {
  let l_shape = Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(4.0, 1.0)
    .line_to(1.0, 1.0)
    .line_to(1.0, 4.0)
    .line_to(0.0, 4.0)
    .close()
  let filler = Path::new().add_rect(1.0, 1.0, 3.0, 3.0)
  match l_shape.boolean(filler, PathBooleanOp::Union) {
    Some(union) => {
      assert_true(union.is_line_polygon())
      assert_true(
        union.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=4.0, height=4.0)),
      )
      assert_true(union.contains_point(3.5, 3.5, FillRule::NonZero))
      assert_eq(union.segment_count(), 5)
    }
    None => abort("expected orthogonal polygon union")
  }

  let clip = Path::new().add_rect(0.5, 0.5, 2.0, 2.0)
  match l_shape.boolean(clip, PathBooleanOp::Intersection) {
    Some(intersection) => {
      assert_true(!intersection.is_line_polygon())
      assert_true(intersection.contains_point(0.75, 2.0, FillRule::NonZero))
      assert_true(intersection.contains_point(2.0, 0.75, FillRule::NonZero))
      assert_true(!intersection.contains_point(2.0, 2.0, FillRule::NonZero))
    }
    None => abort("expected orthogonal polygon intersection")
  }

  let left_arm = Path::new().add_rect(0.0, 1.0, 1.0, 3.0)
  match l_shape.boolean(left_arm, PathBooleanOp::Difference) {
    Some(diff) => {
      assert_true(diff.is_line_polygon())
      assert_true(
        diff.rect_bounds() ==
        Some(Rect::new(x=0.0, y=0.0, width=4.0, height=1.0)),
      )
      assert_true(diff.contains_point(3.5, 0.5, FillRule::NonZero))
      assert_true(!diff.contains_point(0.5, 2.0, FillRule::NonZero))
    }
    None => abort("expected orthogonal polygon difference")
  }

  match l_shape.boolean(clip, PathBooleanOp::Xor) {
    Some(xor) => {
      assert_true(xor.contains_point(3.5, 0.5, FillRule::NonZero))
      assert_true(xor.contains_point(2.0, 2.0, FillRule::NonZero))
      assert_true(!xor.contains_point(0.75, 0.75, FillRule::NonZero))
      assert_true(!xor.contains_point(3.0, 3.0, FillRule::NonZero))
    }
    None => abort("expected orthogonal polygon xor")
  }
}

///|
test "Path::boolean rejects unsupported slanted non-convex and curved operands" {
  let triangle = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(1.0, 2.0)
    .close()

  let slanted_nonconvex = Path::new()
    .move_to(0.0, 0.0)
    .line_to(3.0, 0.0)
    .line_to(1.5, 1.0)
    .line_to(3.0, 3.0)
    .line_to(0.0, 3.0)
    .close()
  assert_true(
    slanted_nonconvex.boolean(triangle, PathBooleanOp::Intersection) is None,
  )
  assert_true(slanted_nonconvex.boolean(triangle, PathBooleanOp::Union) is None)
  assert_true(
    slanted_nonconvex.boolean(triangle, PathBooleanOp::Difference) is None,
  )
  assert_true(slanted_nonconvex.boolean(triangle, PathBooleanOp::Xor) is None)

  let curved = Path::new().move_to(0.0, 0.0).quad_to(1.0, 2.0, 2.0, 0.0).close()
  assert_true(curved.boolean(triangle, PathBooleanOp::Intersection) is None)
  assert_true(curved.boolean(triangle, PathBooleanOp::Xor) is None)
}

///|
test "Path::contains_point evaluates fill rules" {
  let rect = Path::new().add_rect(1.0, 1.0, 3.0, 2.0)
  assert_true(rect.contains_point(2.0, 2.0, FillRule::NonZero))
  assert_true(!rect.contains_point(0.0, 0.0, FillRule::NonZero))
  assert_true(!Path::new().contains_point(0.0, 0.0, FillRule::EvenOdd))

  let nested = Path::new()
    .add_rect(0.0, 0.0, 4.0, 4.0)
    .add_rect(1.0, 1.0, 2.0, 2.0)
  assert_true(nested.contains_point(2.0, 2.0, FillRule::NonZero))
  assert_true(!nested.contains_point(2.0, 2.0, FillRule::EvenOdd))
}

///|
test "Path::contains_point evaluates curved contours" {
  let circle = Path::new().add_circle(0.0, 0.0, 10.0)
  assert_true(circle.contains_point(0.0, 0.0, FillRule::NonZero))
  assert_true(circle.contains_point(6.0, 0.0, FillRule::EvenOdd))
  assert_true(!circle.contains_point(12.0, 0.0, FillRule::NonZero))

  let ellipse = Path::new().add_ellipse(10.0, 8.0, 6.0, 3.0)
  assert_true(ellipse.contains_point(10.0, 8.0, FillRule::NonZero))
  assert_true(ellipse.contains_point(15.0, 8.0, FillRule::NonZero))
  assert_true(!ellipse.contains_point(10.0, 12.0, FillRule::NonZero))

  let nested = Path::new().add_circle(0.0, 0.0, 10.0).add_circle(0.0, 0.0, 4.0)
  assert_true(nested.contains_point(0.0, 0.0, FillRule::NonZero))
  assert_true(!nested.contains_point(0.0, 0.0, FillRule::EvenOdd))
  assert_true(nested.contains_point(7.0, 0.0, FillRule::EvenOdd))
}

///|
test "Path::contains_point implicitly closes open fill contours" {
  let triangle = Path::new()
    .move_to(1.0, 1.0)
    .line_to(4.0, 1.0)
    .line_to(4.0, 4.0)
  assert_true(triangle.contains_point(3.0, 2.0, FillRule::NonZero))
  assert_true(!triangle.contains_point(1.5, 3.0, FillRule::NonZero))
}

///|
test "Path::contains_point treats opposite-winding inner contours as NonZero holes" {
  let path = Path::new()
    .add_rect(0.0, 0.0, 5.0, 5.0)
    .move_to(1.0, 1.0)
    .line_to(1.0, 4.0)
    .line_to(4.0, 4.0)
    .line_to(4.0, 1.0)
    .close()
  assert_true(path.contains_point(0.5, 0.5, FillRule::NonZero))
  assert_true(!path.contains_point(2.0, 2.0, FillRule::NonZero))
  assert_true(!path.contains_point(2.0, 2.0, FillRule::EvenOdd))
}

///|
test "Path::simplified removes exact no-op drawing segments" {
  let path = Path::new()
    .move_to(1.0, 1.0)
    .line_to(1.0, 1.0)
    .quad_to(1.0, 1.0, 1.0, 1.0)
    .cubic_to(1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    .line_to(4.0, 1.0)
  assert_eq(path.segment_count(), 5)
  let simplified = path.simplified()
  let segments = simplified.get_segments()
  inspect(simplified.segment_count(), content="2")
  assert_eq(segments.length(), simplified.segment_count())
  assert_move_to(segments[0], 1.0, 1.0)
  assert_line_to(segments[1], 4.0, 1.0)
}

///|
test "Path::simplified coalesces move and close noise" {
  let path = Path::new()
    .line_to(9.0, 9.0)
    .move_to(0.0, 0.0)
    .move_to(1.0, 1.0)
    .line_to(4.0, 1.0)
    .close()
    .close()
  let segments = path.simplified().get_segments()
  inspect(segments.length(), content="3")
  assert_move_to(segments[0], 1.0, 1.0)
  assert_line_to(segments[1], 4.0, 1.0)
  assert_close(segments[2])
}

///|
test "Path::simplified drops empty subpaths" {
  let empty = Path::new()
    .move_to(1.0, 1.0)
    .close()
    .move_to(2.0, 2.0)
    .line_to(2.0, 2.0)
    .close()
    .move_to(3.0, 3.0)
  let simplified_empty = empty.simplified()
  assert_true(simplified_empty.is_empty())
  assert_true(simplified_empty.control_bounds() == None)
  assert_true(!simplified_empty.contains_point(1.0, 1.0, FillRule::NonZero))

  let mixed = Path::new()
    .move_to(0.0, 0.0)
    .close()
    .move_to(1.0, 1.0)
    .line_to(3.0, 1.0)
    .move_to(7.0, 7.0)
  let segments = mixed.simplified().get_segments()
  inspect(segments.length(), content="2")
  assert_move_to(segments[0], 1.0, 1.0)
  assert_line_to(segments[1], 3.0, 1.0)
}

///|
test "Path::simplified preserves non-degenerate curves returning to start" {
  let path = Path::new()
    .move_to(0.0, 0.0)
    .quad_to(1.0, 1.0, 0.0, 0.0)
    .cubic_to(2.0, 2.0, 3.0, 3.0, 0.0, 0.0)
  let segments = path.simplified().get_segments()
  inspect(segments.length(), content="3")
  assert_move_to(segments[0], 0.0, 0.0)
  assert_quad_to_end(segments[1], 0.0, 0.0)
  assert_cubic_to_end(segments[2], 0.0, 0.0)
}

///|
test "Path::simplified folds straight monotonic curves into lines" {
  let path = Path::new()
    .move_to(0.0, 0.0)
    .quad_to(2.0, 0.0, 4.0, 0.0)
    .cubic_to(5.0, 0.0, 7.0, 0.0, 8.0, 0.0)
  let segments = path.simplified().get_segments()
  inspect(segments.length(), content="2")
  assert_move_to(segments[0], 0.0, 0.0)
  assert_line_to(segments[1], 8.0, 0.0)
}

///|
test "Path::simplified coalesces monotonic collinear line runs" {
  let rect = Path::new()
    .move_to(0.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(4.0, 3.0)
    .line_to(0.0, 3.0)
    .close()
  let simplified = rect.simplified()
  let segments = simplified.get_segments()
  inspect(segments.length(), content="5")
  assert_move_to(segments[0], 0.0, 0.0)
  assert_line_to(segments[1], 4.0, 0.0)
  assert_line_to(segments[2], 4.0, 3.0)
  assert_line_to(segments[3], 0.0, 3.0)
  assert_close(segments[4])
  assert_true(
    simplified.rect_bounds() ==
    Some(Rect::new(x=0.0, y=0.0, width=4.0, height=3.0)),
  )
  assert_true(simplified.contains_point(2.0, 1.0, FillRule::NonZero))

  let backtrack = Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(2.0, 0.0)
    .line_to(6.0, 0.0)
  let backtrack_segments = backtrack.simplified().get_segments()
  inspect(backtrack_segments.length(), content="4")
  assert_line_to(backtrack_segments[1], 4.0, 0.0)
  assert_line_to(backtrack_segments[2], 2.0, 0.0)
  assert_line_to(backtrack_segments[3], 6.0, 0.0)
}

///|
test "Path::simplified folds explicit closing lines into close" {
  let explicit_closed = Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(4.0, 3.0)
    .line_to(0.0, 3.0)
    .line_to(0.0, 0.0)
    .close()
  let simplified = explicit_closed.simplified()
  let segments = simplified.get_segments()
  inspect(segments.length(), content="5")
  assert_move_to(segments[0], 0.0, 0.0)
  assert_line_to(segments[1], 4.0, 0.0)
  assert_line_to(segments[2], 4.0, 3.0)
  assert_line_to(segments[3], 0.0, 3.0)
  assert_close(segments[4])
  assert_true(
    simplified.rect_bounds() ==
    Some(Rect::new(x=0.0, y=0.0, width=4.0, height=3.0)),
  )
  assert_true(simplified.contains_point(2.0, 1.0, FillRule::NonZero))

  let open_explicit = Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(4.0, 3.0)
    .line_to(0.0, 3.0)
    .line_to(0.0, 0.0)
  let open_segments = open_explicit.simplified().get_segments()
  inspect(open_segments.length(), content="5")
  assert_line_to(open_segments[4], 0.0, 0.0)
  assert_true(
    open_explicit.simplified().rect_bounds() ==
    Some(Rect::new(x=0.0, y=0.0, width=4.0, height=3.0)),
  )
}

///|
test "Path::simplified preserves curved and non-monotonic curves" {
  let path = Path::new()
    .move_to(0.0, 0.0)
    .quad_to(6.0, 0.0, 4.0, 0.0)
    .move_to(0.0, 0.0)
    .cubic_to(3.0, 0.0, 1.0, 0.0, 4.0, 0.0)
    .move_to(0.0, 0.0)
    .quad_to(2.0, 1.0, 4.0, 0.0)
  let segments = path.simplified().get_segments()
  inspect(segments.length(), content="6")
  assert_move_to(segments[0], 0.0, 0.0)
  assert_quad_to(segments[1], 6.0, 0.0, 4.0, 0.0)
  assert_move_to(segments[2], 0.0, 0.0)
  assert_cubic_to(segments[3], 3.0, 0.0, 1.0, 0.0, 4.0, 0.0)
  assert_move_to(segments[4], 0.0, 0.0)
  assert_quad_to(segments[5], 2.0, 1.0, 4.0, 0.0)
}

///|
test "Path::transformed applies affine transform to all segment coordinates" {
  let path = Path::new()
    .move_to(1.0, 2.0)
    .line_to(3.0, 4.0)
    .quad_to(5.0, 6.0, 7.0, 8.0)
    .cubic_to(9.0, 10.0, 11.0, 12.0, 13.0, 14.0)
    .close()
  let transform = Transform::translate(tx=10.0, ty=20.0).multiply(
    Transform::scale(sx=2.0, sy=3.0),
  )
  let transformed = path.transformed(transform)
  let segments = transformed.get_segments()

  inspect(segments.length(), content="5")
  assert_move_to(segments[0], 12.0, 26.0)
  assert_line_to(segments[1], 16.0, 32.0)
  assert_quad_to(segments[2], 20.0, 38.0, 24.0, 44.0)
  assert_cubic_to(segments[3], 28.0, 50.0, 32.0, 56.0, 36.0, 62.0)
  assert_close(segments[4])

  let original = path.get_segments()
  assert_move_to(original[0], 1.0, 2.0)
  assert_line_to(original[1], 3.0, 4.0)
}

///|
fn assert_move_to(
  segment : PathSegment,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::MoveTo(x, y) => {
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected MoveTo")
  }
}

///|
fn assert_line_to(
  segment : PathSegment,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::LineTo(x, y) => {
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected LineTo")
  }
}

///|
fn assert_quad_to(
  segment : PathSegment,
  expected_cx : Double,
  expected_cy : Double,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::QuadTo(cx, cy, x, y) => {
      assert_eq(cx, expected_cx)
      assert_eq(cy, expected_cy)
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected QuadTo")
  }
}

///|
fn assert_quad_to_end(
  segment : PathSegment,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::QuadTo(_, _, x, y) => {
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected QuadTo")
  }
}

///|
fn assert_cubic_to(
  segment : PathSegment,
  expected_cx1 : Double,
  expected_cy1 : Double,
  expected_cx2 : Double,
  expected_cy2 : Double,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::CubicTo(cx1, cy1, cx2, cy2, x, y) => {
      assert_eq(cx1, expected_cx1)
      assert_eq(cy1, expected_cy1)
      assert_eq(cx2, expected_cx2)
      assert_eq(cy2, expected_cy2)
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected CubicTo")
  }
}

///|
fn assert_cubic_to_end(
  segment : PathSegment,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::CubicTo(_, _, _, _, x, y) => {
      assert_eq(x, expected_x)
      assert_eq(y, expected_y)
    }
    _ => abort("expected CubicTo")
  }
}

///|
fn assert_cubic_to_end_near(
  segment : PathSegment,
  expected_x : Double,
  expected_y : Double,
) -> Unit raise {
  match segment {
    PathSegment::CubicTo(_, _, _, _, x, y) => {
      assert_true((x - expected_x).abs() < 0.000001)
      assert_true((y - expected_y).abs() < 0.000001)
    }
    _ => abort("expected CubicTo")
  }
}

///|
fn assert_close(segment : PathSegment) -> Unit {
  match segment {
    PathSegment::Close => ()
    _ => abort("expected Close")
  }
}
