///|
test "color packs argb channels" {
  let color = @skia_mbt.Color::from_argb(0x80, 0x11, 0x22, 0x33)
  assert_eq(color.argb(), 0x80112233U)
  assert_eq(color.a(), 0x80)
  assert_eq(color.r(), 0x11)
  assert_eq(color.g(), 0x22)
  assert_eq(color.b(), 0x33)
}

///|
test "rect intersection and containment" {
  let outer = @skia_mbt.Rect::from_xywh(0, 0, 10, 10)
  let inner = @skia_mbt.Rect::from_xywh(2, 3, 4, 5)
  let overlap = @skia_mbt.Rect::from_xywh(8, 8, 5, 5)
  assert_true(outer.contains_rect(inner))
  assert_true(
    outer.intersect(overlap) == Some(@skia_mbt.Rect::new(8, 8, 10, 10)),
  )
}

///|
test "matrix maps point" {
  let point = @skia_mbt.Point::new(2, 3)
  let matrix = @skia_mbt.Matrix::scale_translate(2, 4, 10, 20)
  assert_true(matrix.map_point(point) == @skia_mbt.Point::new(14, 32))
  assert_true(matrix.is_scale_translate())
}

///|
test "matrix composes, inverts, and maps rect bounds" {
  let scale = @skia_mbt.Matrix::scale(2, 4)
  let translate = @skia_mbt.Matrix::translate(10, 20)
  let matrix = translate.concat(scale)
  assert_true(matrix == @skia_mbt.Matrix::scale_translate(2, 4, 10, 20))
  assert_true(matrix.post_concat(@skia_mbt.Matrix::identity()) == matrix)
  assert_true(@skia_mbt.Matrix::identity().pre_concat(matrix) == matrix)
  assert_eq(matrix.determinant(), 8.0)
  assert_true(matrix.is_invertible())
  guard matrix.invert() is Some(inverse) else { fail("expected inverse") }
  assert_true(
    inverse.map_point(matrix.map_point(@skia_mbt.Point::new(4, 5))) ==
    @skia_mbt.Point::new(4, 5),
  )
  assert_true(
    matrix.concat(inverse).map_point(@skia_mbt.Point::new(7, 9)) ==
    @skia_mbt.Point::new(7, 9),
  )

  let skew = @skia_mbt.Matrix::skew(1, 0)
  assert_true(
    skew.map_rect(@skia_mbt.Rect::from_xywh(0, 0, 2, 3)) ==
    @skia_mbt.Rect::new(0, 0, 5, 3),
  )

  let collapsed = @skia_mbt.Matrix::scale(0, 1)
  assert_eq(collapsed.determinant(), 0.0)
  assert_true(!collapsed.is_invertible())
  assert_true(collapsed.invert() is None)
}

///|
test "image info computes row and byte sizes" {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(10, 8))
  assert_eq(info.bytes_per_pixel(), 4)
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.min_row_bytes(), 40)
  assert_eq(info.min_row_bytes64(), 40L)
  assert_eq(info.compute_min_byte_size(), 320)
  assert_eq(info.compute_min_byte_size64(), 320L)
  assert_eq(info.compute_byte_size(48), 384)
  assert_eq(info.compute_byte_size64(48), 384L)
  assert_eq(info.compute_byte_size(39), 0)
  assert_true(info.bounds() == @skia_mbt.IRect::from_xywh(0, 0, 10, 8))
  assert_true(info.valid_pixels(40))

  let unknown = @skia_mbt.ImageInfo::unknown(
    dimensions=@skia_mbt.ISize::new(1, 1),
  )
  assert_eq(unknown.bytes_per_pixel(), 0)
  assert_eq(unknown.shift_per_pixel(), 0)
  assert_true(!unknown.valid_pixels(0))

  let alpha = @skia_mbt.ImageInfo::a8(@skia_mbt.ISize::new(3, 2))
  assert_eq(alpha.bytes_per_pixel(), 1)
  assert_eq(alpha.shift_per_pixel(), 0)
  assert_eq(alpha.min_row_bytes(), 3)
  assert_true(alpha.valid_pixels(3))
}

///|
test "pixmap validates copied pixel layout" {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(2, 2))
  let pixmap = @skia_mbt.Pixmap::new(
    info, 8, b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
  )
  guard pixmap is Some(pixmap) else { fail("expected pixmap") }
  assert_eq(pixmap.width(), 2)
  assert_eq(pixmap.height(), 2)
  assert_eq(pixmap.row_bytes(), 8)
  assert_true(pixmap.color_type() == @skia_mbt.RGBA8888)
  assert_true(pixmap.alpha_type() == @skia_mbt.Premul)
  assert_eq(pixmap.bytes_per_pixel(), 4)
  assert_eq(pixmap.shift_per_pixel(), 2)
  assert_eq(pixmap.byte_size(), 16)
  assert_eq(pixmap.byte_size64(), 16L)
  assert_true(pixmap.contains(@skia_mbt.IPoint::new(1, 1)))
  assert_true(pixmap.offset(@skia_mbt.IPoint::new(1, 1)) == Some(12))
  assert_true(@skia_mbt.Pixmap::new(info, 4, b"\x00") is None)
}

///|
test "paint builder updates value state" {
  let paint = @skia_mbt.Paint::new()
    .set_anti_alias(true)
    .set_stroke(true)
    .set_stroke_width(2.5)
    .set_color(@skia_mbt.Color::red())
    .set_alpha(0x40)
  assert_true(paint.anti_alias)
  assert_true(paint.style == @skia_mbt.Stroke)
  assert_eq(paint.stroke_width, 2.5)
  assert_true(paint.color == @skia_mbt.Color::red().with_alpha(0x40))
}

///|
test "skia enum ordinals match expected native order" {
  assert_eq(@skia_mbt.SrcOver.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.Fill.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Stroke.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeCap::Round.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeJoin::Round.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.StrokeJoin::Bevel.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.Points.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Lines.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.Polygon.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.PNG.to_skia_ordinal(), 4)
  assert_eq(@skia_mbt.JPEG.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.AVIF.to_skia_ordinal(), 12)
  assert_true(@skia_mbt.EncodedImageFormat::from_skia_ordinal(4) == Some(PNG))
  assert_true(@skia_mbt.EncodedImageFormat::from_skia_ordinal(-1) is None)
  assert_eq(@skia_mbt.Clamp.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.Repeat.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.Mirror.to_skia_ordinal(), 2)
  assert_eq(@skia_mbt.Decal.to_skia_ordinal(), 3)
  assert_eq(@skia_mbt.ClipOp::Difference.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.ClipOp::Intersect.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.FilterMode::Nearest.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.FilterMode::Linear.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.MipmapMode::None.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.MipmapMode::Nearest.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.MipmapMode::Linear.to_skia_ordinal(), 2)
}

///|
test "sampling options expose skia-compatible state" {
  let nearest = @skia_mbt.SamplingOptions::new()
  assert_eq(nearest.filter_ordinal(), 0)
  assert_eq(nearest.mipmap_ordinal(), 0)
  assert_true(!nearest.uses_cubic())
  let linear_mipmap = @skia_mbt.SamplingOptions::new(
    filter=@skia_mbt.FilterMode::Linear,
    mipmap=@skia_mbt.MipmapMode::Linear,
  )
  assert_eq(linear_mipmap.filter_ordinal(), 1)
  assert_eq(linear_mipmap.mipmap_ordinal(), 2)
  let cubic = @skia_mbt.SamplingOptions::catmull_rom()
  assert_true(cubic.uses_cubic())
  assert_eq(cubic.cubic_b(), 0.0)
  assert_eq(cubic.cubic_c(), 0.5)
}

///|
test "path value layer records portable verbs" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .move_to(@skia_mbt.Point::new(0, 0))
    .line_to(@skia_mbt.Point::new(10, 0))
    .quad_to(@skia_mbt.Point::new(12, 5), @skia_mbt.Point::new(10, 10))
    .conic_to(@skia_mbt.Point::new(12, 12), @skia_mbt.Point::new(10, 14), 0.5)
    .cubic_to(
      @skia_mbt.Point::new(7, 12),
      @skia_mbt.Point::new(3, 12),
      @skia_mbt.Point::new(0, 10),
    )
    .close()
  assert_true(!path.is_empty())
  assert_eq(path.verb_count(), 6)
  assert_eq(path.count_verbs(), path.verb_count())
  assert_eq(path.count_points(), 9)
  assert_true(path.is_last_contour_closed())
  assert_true(path.is_finite())
  assert_true(path.fill_type == @skia_mbt.EvenOdd)
  assert_true(path.last_point() == Some(@skia_mbt.Point::new(0, 10)))
  assert_true(path.bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 14)))
  let segments = path.segment_masks()
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::line()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::quad()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::conic()))
  assert_true(segments.contains(@skia_mbt.PathSegmentMask::cubic()))
  assert_eq(segments.bits(), 15)
  assert_eq(path.fill_type.to_skia_ordinal(), 1)
  assert_eq(@skia_mbt.CW.to_skia_ordinal(), 0)
  assert_eq(@skia_mbt.CCW.to_skia_ordinal(), 1)
  assert_true(!path.fill_type.is_inverse())
  assert_true(!path.is_inverse_fill_type())
  assert_true(@skia_mbt.InverseEvenOdd.is_inverse())
}

///|
test "path recognizes a single line segment" {
  let line = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
  assert_true(
    line.is_line() ==
    Some(
      @skia_mbt.PathLine::new(
        @skia_mbt.Point::new(1, 2),
        @skia_mbt.Point::new(3, 4),
      ),
    ),
  )
  assert_true(@skia_mbt.Path::new().is_line() is None)
  assert_true(
    @skia_mbt.Path::new()
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 2, 2))
    .is_line()
    is None,
  )
}

///|
test "path recognizes closed rectangle contours" {
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)
  let cw = @skia_mbt.Path::new().add_rect(rect)
  assert_true(
    cw.is_rect() == Some(@skia_mbt.PathRect::new(rect, true, @skia_mbt.CW)),
  )
  let ccw = @skia_mbt.Path::new().add_rect(rect, direction=@skia_mbt.CCW)
  assert_true(
    ccw.is_rect() == Some(@skia_mbt.PathRect::new(rect, true, @skia_mbt.CCW)),
  )
  assert_true(
    @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
    .is_rect()
    is None,
  )
}

///|
test "path reset returns an empty winding path" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.InverseWinding)
    .move_to(@skia_mbt.Point::new(1, 2))
    .reset()
  assert_true(path.is_empty())
  assert_true(path.is_finite())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(path.segment_masks() == @skia_mbt.PathSegmentMask::empty())
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == @skia_mbt.Winding)
  assert_true(path.last_point() is None)
  assert_true(path.bounds() is None)
}

///|
test "path rewind clears path for reuse" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 4, 4))
    .rewind()
  assert_true(path.is_empty())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == @skia_mbt.Winding)
  assert_true(path.bounds() is None)
}

///|
test "path add rect expands in requested direction" {
  let rect = @skia_mbt.Rect::from_xywh(1, 2, 3, 4)
  let cw = @skia_mbt.Path::new().add_rect(rect)
  assert_eq(cw.verb_count(), 5)
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(1, 6)))
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.contains(@skia_mbt.Point::new(2, 3)))
  assert_true(!cw.contains(@skia_mbt.Point::new(9, 9)))
  assert_true(
    cw.verbs ==
    [
      @skia_mbt.MoveTo(@skia_mbt.Point::new(1, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(1, 6)),
      @skia_mbt.Close,
    ],
  )
  let ccw = @skia_mbt.Path::new().add_rect(rect, direction=@skia_mbt.CCW)
  assert_true(ccw.contains(@skia_mbt.Point::new(2, 3)))
  let inverse = cw.with_fill_type(@skia_mbt.InverseWinding)
  assert_true(inverse.is_inverse_fill_type())
  assert_true(!inverse.contains(@skia_mbt.Point::new(2, 3)))
  assert_true(inverse.contains(@skia_mbt.Point::new(9, 9)))
  assert_true(
    ccw.verbs ==
    [
      @skia_mbt.MoveTo(@skia_mbt.Point::new(1, 2)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(1, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 6)),
      @skia_mbt.LineTo(@skia_mbt.Point::new(4, 2)),
      @skia_mbt.Close,
    ],
  )
}

///|
test "path add oval and circle expand to conics" {
  let oval = @skia_mbt.Rect::from_xywh(0, 0, 10, 20)
  let cw = @skia_mbt.Path::new().add_oval(oval)
  assert_eq(cw.verb_count(), 6)
  assert_true(cw.bounds() == Some(oval))
  assert_true(cw.is_oval() == Some(oval))
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(10, 10)))
  assert_true(cw.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(10, 10)))
  assert_true(
    cw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 20),
      @skia_mbt.Point::new(5, 20),
      0.70710677,
    ),
  )
  let ccw = @skia_mbt.Path::new().add_oval(oval, direction=@skia_mbt.CCW)
  assert_true(ccw.is_oval() == Some(oval))
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(5, 0),
      0.70710677,
    ),
  )
  let circle = @skia_mbt.Path::new().add_circle(@skia_mbt.Point::new(5, 5), 3)
  assert_true(circle.bounds() == Some(@skia_mbt.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(circle.is_oval() == Some(@skia_mbt.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(
    @skia_mbt.Path::new().add_circle(@skia_mbt.Point::zero(), 0).is_empty(),
  )
  assert_true(
    @skia_mbt.Path::new()
    .add_rect(@skia_mbt.Rect::from_xywh(0, 0, 10, 20))
    .is_oval()
    is None,
  )
}

///|
test "path add round rect expands to lines and conics" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 20)
  let cw = @skia_mbt.Path::new().add_round_rect(rect, 2, 3)
  assert_eq(cw.verb_count(), 10)
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.last_point() == Some(@skia_mbt.Point::new(2, 0)))
  assert_true(cw.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(2, 0)))
  assert_true(cw.verbs[1] == @skia_mbt.LineTo(@skia_mbt.Point::new(8, 0)))
  assert_true(
    cw.verbs[2] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(10, 3),
      0.70710677,
    ),
  )
  let ccw = @skia_mbt.Path::new().add_round_rect(
    rect,
    2,
    3,
    direction=@skia_mbt.CCW,
  )
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(0, 3),
      0.70710677,
    ),
  )
  assert_true(
    @skia_mbt.Path::new().add_round_rect(rect, 0, 3).verb_count() == 5,
  )
}

///|
test "rrect value layer normalizes per-corner radii" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @skia_mbt.RRect::new(
    rect,
    @skia_mbt.Size::new(8, 8),
    @skia_mbt.Size::new(8, 8),
    @skia_mbt.Size::new(2, 2),
    @skia_mbt.Size::new(-1, 4),
  )
  assert_true(rrect.bounds() == rect)
  assert_true(rrect.upper_left == @skia_mbt.Size::new(5, 5))
  assert_true(rrect.upper_right == @skia_mbt.Size::new(5, 5))
  assert_true(rrect.lower_right == @skia_mbt.Size::new(1.25, 1.25))
  assert_true(rrect.lower_left == @skia_mbt.Size::empty())
  assert_true(!rrect.is_rect())
  assert_true(!rrect.is_simple())
  assert_eq(rrect.width(), 10)
  assert_eq(rrect.height(), 8)

  let simple = @skia_mbt.RRect::from_rect_xy(rect, 2, 3)
  assert_true(simple.is_simple())
  assert_true(!simple.is_oval())

  let oval = @skia_mbt.RRect::from_oval(rect)
  assert_true(oval.is_oval())
  assert_true(oval.upper_left == @skia_mbt.Size::new(5, 4))

  let plain = @skia_mbt.RRect::from_rect(rect)
  assert_true(plain.is_rect())
  assert_true(plain.offset(1, 2).bounds() == rect.offset(1, 2))
}

///|
test "path add rrect expands mixed corners" {
  let rect = @skia_mbt.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @skia_mbt.RRect::new(
    rect,
    @skia_mbt.Size::new(2, 2),
    @skia_mbt.Size::new(3, 1),
    @skia_mbt.Size::new(1, 2),
    @skia_mbt.Size::empty(),
  )
  let path = @skia_mbt.Path::new().add_rrect(rrect)
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rect))
  assert_true(path.last_point() == Some(@skia_mbt.Point::new(2, 0)))
  assert_true(path.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(2, 0)))
  assert_true(path.verbs[1] == @skia_mbt.LineTo(@skia_mbt.Point::new(7, 0)))
  assert_true(
    path.verbs[2] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(10, 0),
      @skia_mbt.Point::new(10, 1),
      0.70710677,
    ),
  )
  assert_true(path.verbs[6] == @skia_mbt.LineTo(@skia_mbt.Point::new(0, 8)))

  let ccw = @skia_mbt.Path::new().add_rrect(rrect, direction=@skia_mbt.CCW)
  assert_true(
    ccw.verbs[1] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(0, 0),
      @skia_mbt.Point::new(0, 2),
      0.70710677,
    ),
  )

  let rect_path = @skia_mbt.Path::new().add_rrect(
    @skia_mbt.RRect::from_rect(rect),
  )
  assert_true(rect_path.verbs == @skia_mbt.Path::new().add_rect(rect).verbs)
}

///|
test "path transform maps every verb point" {
  let path = @skia_mbt.Path::new(fill_type=@skia_mbt.EvenOdd)
    .move_to(@skia_mbt.Point::new(1, 2))
    .line_to(@skia_mbt.Point::new(3, 4))
    .quad_to(@skia_mbt.Point::new(5, 6), @skia_mbt.Point::new(7, 8))
    .conic_to(@skia_mbt.Point::new(9, 10), @skia_mbt.Point::new(11, 12), 0.5)
    .cubic_to(
      @skia_mbt.Point::new(13, 14),
      @skia_mbt.Point::new(15, 16),
      @skia_mbt.Point::new(17, 18),
    )
    .close()
  let transformed = path.transform(
    @skia_mbt.Matrix::scale_translate(2, 3, 10, 20),
  )
  assert_true(transformed.fill_type == @skia_mbt.EvenOdd)
  assert_true(transformed.last_point() == Some(@skia_mbt.Point::new(44, 74)))
  assert_true(
    transformed.verbs[0] == @skia_mbt.MoveTo(@skia_mbt.Point::new(12, 26)),
  )
  assert_true(
    transformed.verbs[3] ==
    @skia_mbt.ConicTo(
      @skia_mbt.Point::new(28, 50),
      @skia_mbt.Point::new(32, 56),
      0.5,
    ),
  )
  assert_true(transformed.verbs[5] == @skia_mbt.Close)

  let offset = path.offset(2, 3)
  assert_true(offset.bounds() == Some(@skia_mbt.Rect::new(3, 5, 19, 21)))
}

///|
test "path stroke bounds conservatively outsets geometry" {
  let path = @skia_mbt.Path::new().add_rect(
    @skia_mbt.Rect::from_xywh(1, 2, 3, 4),
  )
  let fill = @skia_mbt.Paint::new(style=@skia_mbt.Fill, stroke_width=10)
  assert_true(path.stroke_bounds(fill) == path.bounds())
  let stroke = @skia_mbt.Paint::new(style=@skia_mbt.Stroke, stroke_width=6)
  assert_true(
    path.stroke_bounds(stroke) == Some(@skia_mbt.Rect::new(-2, -1, 7, 9)),
  )
  let stroke_and_fill = @skia_mbt.Paint::new(
    style=@skia_mbt.StrokeAndFill,
    stroke_width=2,
  )
  assert_true(
    path.stroke_bounds(stroke_and_fill) == Some(@skia_mbt.Rect::new(0, 1, 5, 7)),
  )
  assert_true(@skia_mbt.Path::new().stroke_bounds(stroke) is None)
}

///|
test "path compute tight bounds excludes off-curve controls" {
  let quad = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .quad_to(@skia_mbt.Point::new(10, 10), @skia_mbt.Point::new(20, 0))
  assert_true(quad.bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 10)))
  assert_true(
    quad.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 5)),
  )

  let conic = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .conic_to(@skia_mbt.Point::new(10, 10), @skia_mbt.Point::new(20, 0), 1)
  assert_true(conic.bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 10)))
  assert_true(
    conic.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 20, 5)),
  )

  let cubic = @skia_mbt.Path::new()
    .move_to(@skia_mbt.Point::new(0, 0))
    .cubic_to(
      @skia_mbt.Point::new(0, 12),
      @skia_mbt.Point::new(12, 12),
      @skia_mbt.Point::new(12, 0),
    )
  assert_true(cubic.bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 12)))
  assert_true(
    cubic.compute_tight_bounds() == Some(@skia_mbt.Rect::new(0, 0, 12, 9)),
  )
}
