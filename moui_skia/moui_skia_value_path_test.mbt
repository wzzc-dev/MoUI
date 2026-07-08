///|
test "matrix exposes skia-style members and affine conversion" {
  let matrix = @moui_skia.Matrix::new_all(2, 1, 10, 3, 4, 20, 0, 0, 1)
  assert_eq(matrix.scale_x(), 2.0)
  assert_eq(matrix.skew_x(), 1.0)
  assert_eq(matrix.translate_x(), 10.0)
  assert_eq(matrix.skew_y(), 3.0)
  assert_eq(matrix.scale_y(), 4.0)
  assert_eq(matrix.translate_y(), 20.0)
  assert_eq(matrix.persp_x(), 0.0)
  assert_eq(matrix.persp_y(), 0.0)
  assert_true(matrix.is_finite())
  assert_true(
    matrix.values() == [2.0, 1.0, 10.0, 3.0, 4.0, 20.0, 0.0, 0.0, 1.0],
  )
  assert_true(matrix.to_affine() == Some([2.0, 1.0, 10.0, 3.0, 4.0, 20.0]))
  assert_true(
    @moui_skia.Matrix::from_affine([2, 1, 10, 3, 4, 20]) == Some(matrix),
  )
  assert_true(@moui_skia.Matrix::from_affine([1, 2, 3]) is None)

  let perspective = @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1)
  assert_true(perspective.to_affine() is None)
}

///|
test "matrix composes, inverts, and maps rect bounds" {
  let scale = @moui_skia.Matrix::scale(2, 4)
  let translate = @moui_skia.Matrix::translate(10, 20)
  let matrix = translate.concat(scale)
  assert_true(matrix == @moui_skia.Matrix::scale_translate(2, 4, 10, 20))
  assert_true(matrix.post_concat(@moui_skia.Matrix::identity()) == matrix)
  assert_true(@moui_skia.Matrix::identity().pre_concat(matrix) == matrix)
  assert_eq(matrix.determinant(), 8.0)
  assert_true(matrix.is_invertible())
  guard matrix.invert() is Some(inverse) else { fail("expected inverse") }
  assert_true(
    inverse.map_point(matrix.map_point(@moui_skia.Point::new(4, 5))) ==
    @moui_skia.Point::new(4, 5),
  )
  assert_true(
    matrix.concat(inverse).map_point(@moui_skia.Point::new(7, 9)) ==
    @moui_skia.Point::new(7, 9),
  )

  let skew = @moui_skia.Matrix::skew(1, 0)
  assert_true(
    skew.map_rect(@moui_skia.Rect::from_xywh(0, 0, 2, 3)) ==
    @moui_skia.Rect::new(0, 0, 5, 3),
  )

  let base = @moui_skia.Matrix::scale(2, 3)
  assert_true(
    base.pre_translate(10, 20).map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(12, 23),
  )
  assert_true(
    base.post_translate(10, 20).map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(22, 63),
  )
  assert_true(
    @moui_skia.Matrix::identity()
    .pre_scale(2, 3)
    .post_skew(1, 0)
    .map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(4, 3),
  )
  assert_true(
    @moui_skia.Matrix::identity()
    .pre_skew(1, 0)
    .post_scale(2, 3)
    .map_point(@moui_skia.Point::new(1, 1)) ==
    @moui_skia.Point::new(5, 3),
  )
  assert_true(
    test_point_near(
      @moui_skia.Matrix::rotate_degrees(90).map_point(
        @moui_skia.Point::new(2, 0),
      ),
      @moui_skia.Point::new(0, 2),
    ),
  )
  assert_true(
    test_rect_near(
      @moui_skia.Matrix::identity()
      .post_rotate_degrees(90)
      .map_rect(@moui_skia.Rect::from_xywh(1, 1, 4, 2)),
      @moui_skia.Rect::new(-3, 1, -1, 5),
    ),
  )
  assert_true(
    test_point_near(
      @moui_skia.Matrix::translate(10, 0)
      .pre_rotate_degrees(90)
      .map_point(@moui_skia.Point::new(1, 0)),
      @moui_skia.Point::new(0, 11),
    ),
  )
  assert_true(
    @moui_skia.Matrix::translate(1, 2).map_points([
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(3, 4),
    ]) ==
    [@moui_skia.Point::new(1, 2), @moui_skia.Point::new(4, 6)],
  )

  let collapsed = @moui_skia.Matrix::scale(0, 1)
  assert_eq(collapsed.determinant(), 0.0)
  assert_true(!collapsed.is_invertible())
  assert_true(collapsed.invert() is None)
}

///|
test "matrix maps origins vectors radii and rectangle quads" {
  let matrix = @moui_skia.Matrix::scale_translate(2, 3, 10, 20)
  let point = @moui_skia.Point::new(4, 5)
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)

  assert_true(matrix.map_xy(4, 5) == @moui_skia.Point::new(18, 35))
  assert_true(matrix.map_origin() == @moui_skia.Point::new(10, 20))
  assert_true(
    matrix.map_point_affine(point) == Some(@moui_skia.Point::new(18, 35)),
  )
  assert_true(matrix.map_vector(point) == @moui_skia.Point::new(8, 15))
  assert_true(
    matrix.map_vectors([
      @moui_skia.Point::new(1, 1),
      @moui_skia.Point::new(2, 3),
    ]) ==
    [@moui_skia.Point::new(2, 3), @moui_skia.Point::new(4, 9)],
  )
  assert_true(@moui_skia.Matrix::scale(2, 8).map_radius(3) == Some(12.0))
  assert_true(
    @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_point_affine(
      point,
    )
    is None,
  )
  assert_true(
    @moui_skia.Matrix::new_all(1, 0, 0, 0, 1, 0, 0.5, 0, 1).map_radius(3)
    is None,
  )

  assert_true(
    matrix.map_rect_to_quad(rect) ==
    [
      @moui_skia.Point::new(12, 26),
      @moui_skia.Point::new(18, 26),
      @moui_skia.Point::new(18, 38),
      @moui_skia.Point::new(12, 38),
    ],
  )
  assert_true(
    matrix.map_rect_scale_translate(rect) ==
    Some(@moui_skia.Rect::from_xywh(12, 26, 6, 12)),
  )
  assert_true(
    @moui_skia.Matrix::skew(1, 0).map_rect_scale_translate(rect) is None,
  )
}

///|
test "image info computes row and byte sizes" {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(10, 8))
  assert_eq(info.bytes_per_pixel(), 4)
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.min_row_bytes(), 40)
  assert_eq(info.min_row_bytes64(), 40L)
  assert_eq(info.compute_min_byte_size(), 320)
  assert_eq(info.compute_min_byte_size64(), 320L)
  assert_eq(info.compute_byte_size(48), 384)
  assert_eq(info.compute_byte_size64(48), 384L)
  assert_eq(info.compute_byte_size(39), 0)
  assert_true(info.bounds() == @moui_skia.IRect::from_xywh(0, 0, 10, 8))
  assert_true(info.valid_pixels(40))

  let unknown = @moui_skia.ImageInfo::unknown(
    dimensions=@moui_skia.ISize::new(1, 1),
  )
  assert_eq(unknown.bytes_per_pixel(), 0)
  assert_eq(unknown.shift_per_pixel(), 0)
  assert_true(!unknown.valid_pixels(0))

  let alpha = @moui_skia.ImageInfo::a8(@moui_skia.ISize::new(3, 2))
  assert_eq(alpha.bytes_per_pixel(), 1)
  assert_eq(alpha.shift_per_pixel(), 0)
  assert_eq(alpha.min_row_bytes(), 3)
  assert_true(alpha.valid_pixels(3))
}

///|
test "pixmap validates copied pixel layout" {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(2, 2))
  let pixmap = @moui_skia.Pixmap::new(
    info, 8, b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f",
  )
  guard pixmap is Some(pixmap) else { fail("expected pixmap") }
  assert_eq(pixmap.width(), 2)
  assert_eq(pixmap.height(), 2)
  assert_eq(pixmap.row_bytes(), 8)
  assert_true(pixmap.color_type() == RGBA8888)
  assert_true(pixmap.alpha_type() == Premul)
  assert_eq(pixmap.bytes_per_pixel(), 4)
  assert_eq(pixmap.shift_per_pixel(), 2)
  assert_eq(pixmap.byte_size(), 16)
  assert_eq(pixmap.byte_size64(), 16L)
  assert_true(pixmap.contains(@moui_skia.IPoint::new(1, 1)))
  assert_true(pixmap.offset(@moui_skia.IPoint::new(1, 1)) == Some(12))
  assert_true(
    pixmap.sample(@moui_skia.IPoint::new(1, 1)) == Some(b"\x0c\x0d\x0e\x0f"),
  )
  assert_true(
    pixmap.matches_sample(@moui_skia.IPoint::new(1, 1), b"\x0c\x0d\x0e\x0f"),
  )
  assert_true(
    !pixmap.matches_sample(@moui_skia.IPoint::new(1, 1), b"\x0c\x0d\x0e\x10"),
  )
  assert_true(pixmap.sample(@moui_skia.IPoint::new(2, 0)) is None)
  assert_true(@moui_skia.Pixmap::new(info, 4, b"\x00") is None)
}

///|
test "paint builder updates value state" {
  let paint = @moui_skia.Paint::new()
    .set_anti_alias(true)
    .set_stroke(true)
    .set_stroke_width(2.5)
    .set_color(@moui_skia.Color::red())
    .set_alpha(0x40)
  assert_true(paint.anti_alias)
  assert_true(paint.style == Stroke)
  assert_eq(paint.stroke_width, 2.5)
  assert_true(paint.color == @moui_skia.Color::red().with_alpha(0x40))
}

///|
test "skia enum ordinals match expected native order" {
  assert_eq(@moui_skia.SrcOver.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.Fill.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Stroke.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeCap::Round.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeJoin::Round.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.StrokeJoin::Bevel.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.Points.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Lines.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.Polygon.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.PNG.to_skia_ordinal(), 4)
  assert_eq(@moui_skia.JPEG.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.AVIF.to_skia_ordinal(), 12)
  assert_true(@moui_skia.EncodedImageFormat::from_skia_ordinal(4) == Some(PNG))
  assert_true(@moui_skia.EncodedImageFormat::from_skia_ordinal(-1) is None)
  assert_eq(@moui_skia.Clamp.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.Repeat.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.Mirror.to_skia_ordinal(), 2)
  assert_eq(@moui_skia.Decal.to_skia_ordinal(), 3)
  assert_eq(@moui_skia.ClipOp::Difference.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.ClipOp::Intersect.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.FilterMode::Nearest.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.FilterMode::Linear.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.MipmapMode::None.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.MipmapMode::Nearest.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.MipmapMode::Linear.to_skia_ordinal(), 2)
}

///|
test "sampling options expose skia-compatible state" {
  let nearest = @moui_skia.SamplingOptions::new()
  assert_eq(nearest.filter_ordinal(), 0)
  assert_eq(nearest.mipmap_ordinal(), 0)
  assert_true(!nearest.uses_cubic())
  let linear_mipmap = @moui_skia.SamplingOptions::new(
    filter=Linear,
    mipmap=Linear,
  )
  assert_eq(linear_mipmap.filter_ordinal(), 1)
  assert_eq(linear_mipmap.mipmap_ordinal(), 2)
  let cubic = @moui_skia.SamplingOptions::catmull_rom()
  assert_true(cubic.uses_cubic())
  assert_eq(cubic.cubic_b(), 0.0)
  assert_eq(cubic.cubic_c(), 0.5)
}

///|
test "path value layer records portable verbs" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(10, 0))
    .quad_to(@moui_skia.Point::new(12, 5), @moui_skia.Point::new(10, 10))
    .conic_to(@moui_skia.Point::new(12, 12), @moui_skia.Point::new(10, 14), 0.5)
    .cubic_to(
      @moui_skia.Point::new(7, 12),
      @moui_skia.Point::new(3, 12),
      @moui_skia.Point::new(0, 10),
    )
    .close()
  assert_true(!path.is_empty())
  assert_eq(path.verb_count(), 6)
  assert_eq(path.count_verbs(), path.verb_count())
  assert_eq(path.count_points(), 9)
  assert_true(path.is_last_contour_closed())
  assert_true(path.is_finite())
  assert_true(path.fill_type == EvenOdd)
  assert_true(path.last_point() == Some(@moui_skia.Point::new(0, 10)))
  assert_true(path.bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 14)))
  let segments = path.segment_masks()
  assert_true(segments.contains(@moui_skia.PathSegmentMask::line()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::quad()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::conic()))
  assert_true(segments.contains(@moui_skia.PathSegmentMask::cubic()))
  assert_eq(segments.bits(), 15)
  assert_eq(path.fill_type.to_skia_ordinal(), 1)
  assert_eq(@moui_skia.CW.to_skia_ordinal(), 0)
  assert_eq(@moui_skia.CCW.to_skia_ordinal(), 1)
  assert_true(!path.fill_type.is_inverse())
  assert_true(!path.is_inverse_fill_type())
  assert_true(@moui_skia.InverseEvenOdd.is_inverse())
  let key = path.resource_key()
  assert_true(key.kind == PathResource)
  assert_true(!key.is_empty())
  assert_true(key == path.resource_key())
  assert_true(key != path.with_fill_type(Winding).resource_key())
  assert_true(
    key != path.transform(@moui_skia.Matrix::translate(1, 0)).resource_key(),
  )
  let descriptor = path.resource_descriptor()
  assert_true(descriptor.key == key)
  assert_true(descriptor.byte_size > 0L)
  assert_true(descriptor.is_cacheable())
  assert_true(!@moui_skia.Path::new().resource_descriptor().is_cacheable())
  let non_finite_path = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(1.0 / 0.0, 1))
  assert_true(!non_finite_path.is_finite())
  assert_true(non_finite_path.resource_key().is_empty())
  assert_true(!non_finite_path.resource_descriptor().is_cacheable())
  let target = @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(16, 16),
  )
  let non_finite_commands = @moui_skia.RenderCommandList::for_target(target)
    .clip_path(non_finite_path)
    .draw_path(non_finite_path)
  let non_finite_plan = non_finite_commands.resource_plan()
  assert_eq(non_finite_plan.count_kind(PathResource), 0)
  assert_eq(non_finite_plan.count_kind(SurfaceResource), 1)
}

///|
test "path recognizes a single line segment" {
  let line = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
  assert_true(
    line.is_line() ==
    Some(
      @moui_skia.PathLine::new(
        @moui_skia.Point::new(1, 2),
        @moui_skia.Point::new(3, 4),
      ),
    ),
  )
  assert_true(@moui_skia.Path::new().is_line() is None)
  assert_true(
    @moui_skia.Path::new()
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 2, 2))
    .is_line()
    is None,
  )
}

///|
test "path add poly builds open and closed contours" {
  let points = [
    @moui_skia.Point::new(0, 0),
    @moui_skia.Point::new(10, 0),
    @moui_skia.Point::new(10, 10),
  ]
  let open = @moui_skia.Path::new().add_poly(points)
  assert_eq(open.count_verbs(), 3)
  assert_eq(open.count_points(), 3)
  assert_true(!open.is_last_contour_closed())
  assert_true(open.last_point() == Some(@moui_skia.Point::new(10, 10)))
  assert_true(open.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 10, 10)))
  assert_true(open.segment_masks().contains(@moui_skia.PathSegmentMask::line()))

  let closed = @moui_skia.Path::new(fill_type=EvenOdd).add_poly(
    points,
    close=true,
  )
  assert_eq(closed.count_verbs(), 4)
  assert_eq(closed.count_points(), 3)
  assert_true(closed.is_last_contour_closed())
  assert_true(closed.fill_type == EvenOdd)
  assert_true(closed.contains(@moui_skia.Point::new(8, 2)))
  assert_true(!closed.contains(@moui_skia.Point::new(2, 8)))

  let empty : Array[@moui_skia.Point] = []
  assert_true(@moui_skia.Path::new().add_poly(empty).is_empty())
}

///|
test "path add path appends transformed verbs" {
  let base = @moui_skia.Path::new(fill_type=EvenOdd).add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 2, 2),
  )
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )
  let combined = base.add_path(
    triangle,
    matrix=@moui_skia.Matrix::translate(10, 0),
  )
  assert_true(combined.fill_type == EvenOdd)
  assert_eq(combined.count_verbs(), base.count_verbs() + triangle.count_verbs())
  assert_eq(
    combined.count_points(),
    base.count_points() + triangle.count_points(),
  )
  assert_true(combined.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(combined.last_point() == Some(@moui_skia.Point::new(20, 10)))
  assert_true(combined.contains(@moui_skia.Point::new(18, 2)))
  assert_true(!combined.contains(@moui_skia.Point::new(4, 8)))
  assert_true(
    base.add_path_matrix(triangle, @moui_skia.Matrix::translate(10, 0)) ==
    combined,
  )
  assert_true(
    base.add_path_offset(triangle, @moui_skia.Point::new(10, 0)) == combined,
  )
  assert_true(base.add_path(@moui_skia.Path::new()) == base)

  let open = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .line_to(@moui_skia.Point::new(2, 0))
  let segment = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(10, 0))
    .line_to(@moui_skia.Point::new(12, 0))
  let extended = open.add_path(segment, mode=Extend)
  assert_true(extended.verbs[2] == LineTo(@moui_skia.Point::new(10, 0)))
  assert_true(extended.verbs[3] == LineTo(@moui_skia.Point::new(12, 0)))
  assert_eq(extended.count_verbs(), 4)
  assert_true(
    extended.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 12, 0)),
  )
  assert_true(@moui_skia.Path::new().add_path(segment, mode=Extend) == segment)
}

///|
test "path recognizes closed rectangle contours" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  let cw = @moui_skia.Path::new().add_rect(rect)
  assert_true(cw.is_rect() == Some(@moui_skia.PathRect::new(rect, true, CW)))
  let ccw = @moui_skia.Path::new().add_rect(rect, direction=CCW)
  assert_true(ccw.is_rect() == Some(@moui_skia.PathRect::new(rect, true, CCW)))
  assert_true(
    @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
    .is_rect()
    is None,
  )
}

///|
test "path reset returns an empty winding path" {
  let path = @moui_skia.Path::new(fill_type=InverseWinding)
    .move_to(@moui_skia.Point::new(1, 2))
    .reset()
  assert_true(path.is_empty())
  assert_true(path.is_finite())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(path.segment_masks() == @moui_skia.PathSegmentMask::empty())
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == Winding)
  assert_true(path.last_point() is None)
  assert_true(path.bounds() is None)
}

///|
test "path rewind clears path for reuse" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 4))
    .rewind()
  assert_true(path.is_empty())
  assert_eq(path.count_verbs(), 0)
  assert_eq(path.count_points(), 0)
  assert_true(!path.is_last_contour_closed())
  assert_true(path.fill_type == Winding)
  assert_true(path.bounds() is None)
}

///|
test "path add rect expands in requested direction" {
  let rect = @moui_skia.Rect::from_xywh(1, 2, 3, 4)
  let cw = @moui_skia.Path::new().add_rect(rect)
  assert_eq(cw.verb_count(), 5)
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(1, 6)))
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.contains(@moui_skia.Point::new(2, 3)))
  assert_true(!cw.contains(@moui_skia.Point::new(9, 9)))
  assert_true(
    cw.verbs ==
    [
      MoveTo(@moui_skia.Point::new(1, 2)),
      LineTo(@moui_skia.Point::new(4, 2)),
      LineTo(@moui_skia.Point::new(4, 6)),
      LineTo(@moui_skia.Point::new(1, 6)),
      Close,
    ],
  )
  let ccw = @moui_skia.Path::new().add_rect(rect, direction=CCW)
  assert_true(ccw.contains(@moui_skia.Point::new(2, 3)))
  let inverse = cw.with_fill_type(InverseWinding)
  assert_true(inverse.is_inverse_fill_type())
  assert_true(!inverse.contains(@moui_skia.Point::new(2, 3)))
  assert_true(inverse.contains(@moui_skia.Point::new(9, 9)))
  assert_true(
    ccw.verbs ==
    [
      MoveTo(@moui_skia.Point::new(1, 2)),
      LineTo(@moui_skia.Point::new(1, 6)),
      LineTo(@moui_skia.Point::new(4, 6)),
      LineTo(@moui_skia.Point::new(4, 2)),
      Close,
    ],
  )
}

///|
test "path add oval and circle expand to conics" {
  let oval = @moui_skia.Rect::from_xywh(0, 0, 10, 20)
  let cw = @moui_skia.Path::new().add_oval(oval)
  assert_eq(cw.verb_count(), 6)
  assert_true(cw.bounds() == Some(oval))
  assert_true(cw.is_oval() == Some(oval))
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(10, 10)))
  assert_true(cw.verbs[0] == MoveTo(@moui_skia.Point::new(10, 10)))
  assert_true(
    cw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(10, 20),
      @moui_skia.Point::new(5, 20),
      0.70710677,
    ),
  )
  let ccw = @moui_skia.Path::new().add_oval(oval, direction=CCW)
  assert_true(ccw.is_oval() == Some(oval))
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(5, 0),
      0.70710677,
    ),
  )
  let circle = @moui_skia.Path::new().add_circle(@moui_skia.Point::new(5, 5), 3)
  assert_true(circle.bounds() == Some(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(circle.is_oval() == Some(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(
    @moui_skia.Path::new().add_circle(@moui_skia.Point::zero(), 0).is_empty(),
  )
  assert_true(
    @moui_skia.Path::new()
    .add_rect(@moui_skia.Rect::from_xywh(0, 0, 10, 20))
    .is_oval()
    is None,
  )
}

///|
test "path add round rect expands to lines and conics" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 20)
  let cw = @moui_skia.Path::new().add_round_rect(rect, 2, 3)
  assert_eq(cw.verb_count(), 10)
  assert_true(cw.bounds() == Some(rect))
  assert_true(cw.last_point() == Some(@moui_skia.Point::new(2, 0)))
  assert_true(cw.verbs[0] == MoveTo(@moui_skia.Point::new(2, 0)))
  assert_true(cw.verbs[1] == LineTo(@moui_skia.Point::new(8, 0)))
  assert_true(
    cw.verbs[2] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 3),
      0.70710677,
    ),
  )
  let ccw = @moui_skia.Path::new().add_round_rect(rect, 2, 3, direction=CCW)
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(0, 3),
      0.70710677,
    ),
  )
  assert_true(
    @moui_skia.Path::new().add_round_rect(rect, 0, 3).verb_count() == 5,
  )
}

///|
test "rrect value layer normalizes per-corner radii" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @moui_skia.RRect::new(
    rect,
    @moui_skia.Size::new(8, 8),
    @moui_skia.Size::new(8, 8),
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(-1, 4),
  )
  assert_true(rrect.bounds() == rect)
  assert_true(rrect.upper_left == @moui_skia.Size::new(5, 5))
  assert_true(rrect.upper_right == @moui_skia.Size::new(5, 5))
  assert_true(rrect.lower_right == @moui_skia.Size::new(1.25, 1.25))
  assert_true(rrect.lower_left == @moui_skia.Size::empty())
  assert_true(!rrect.is_rect())
  assert_true(!rrect.is_simple())
  assert_eq(rrect.width(), 10)
  assert_eq(rrect.height(), 8)

  let simple = @moui_skia.RRect::from_rect_xy(rect, 2, 3)
  assert_true(simple.is_simple())
  assert_true(!simple.is_oval())

  let oval = @moui_skia.RRect::from_oval(rect)
  assert_true(oval.is_oval())
  assert_true(oval.upper_left == @moui_skia.Size::new(5, 4))

  let plain = @moui_skia.RRect::from_rect(rect)
  assert_true(plain.is_rect())
  assert_true(plain.offset(1, 2).bounds() == rect.offset(1, 2))
}

///|
test "rrect immutable geometry helpers preserve value semantics" {
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(0, 0, 10, 8),
    2,
    3,
  )

  let shifted = rrect.with_offset(@moui_skia.Point::new(5, -2))
  assert_true(shifted.bounds() == @moui_skia.Rect::from_xywh(5, -2, 10, 8))
  assert_true(shifted.upper_left == rrect.upper_left)
  assert_true(
    rrect.with_offset_to(@moui_skia.Point::new(20, 30)).bounds() ==
    @moui_skia.Rect::from_xywh(20, 30, 10, 8),
  )

  let inset = rrect.with_inset(@moui_skia.Size::new(1, 2))
  assert_true(inset.bounds() == @moui_skia.Rect::from_xywh(1, 2, 8, 4))
  assert_true(inset.upper_left == @moui_skia.Size::new(1, 1))

  let outset = rrect.with_outset(@moui_skia.Size::new(1, 2))
  assert_true(outset.bounds() == @moui_skia.Rect::from_xywh(-1, -2, 12, 12))
  assert_true(outset.upper_left == @moui_skia.Size::new(3, 5))
}

///|
test "rrect contains rectangles inside rounded corners" {
  let rrect = @moui_skia.RRect::from_rect_xy(
    @moui_skia.Rect::from_xywh(0, 0, 10, 10),
    4,
    4,
  )

  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(4, 4, 2, 2)))
  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(2, 2, 6, 6)))
  assert_true(!rrect.contains_rect(@moui_skia.Rect::from_xywh(0, 0, 1, 1)))
  assert_true(!rrect.contains_rect(@moui_skia.Rect::from_xywh(-1, 4, 2, 2)))
  assert_true(
    @moui_skia.RRect::from_rect(@moui_skia.Rect::from_xywh(0, 0, 10, 10)).contains_rect(
      @moui_skia.Rect::from_xywh(0, 0, 10, 10),
    ),
  )
}

///|
test "path add rrect expands mixed corners" {
  let rect = @moui_skia.Rect::from_xywh(0, 0, 10, 8)
  let rrect = @moui_skia.RRect::new(
    rect,
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(3, 1),
    @moui_skia.Size::new(1, 2),
    @moui_skia.Size::empty(),
  )
  let path = @moui_skia.Path::new().add_rrect(rrect)
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rect))
  assert_true(path.last_point() == Some(@moui_skia.Point::new(2, 0)))
  assert_true(path.verbs[0] == MoveTo(@moui_skia.Point::new(2, 0)))
  assert_true(path.verbs[1] == LineTo(@moui_skia.Point::new(7, 0)))
  assert_true(
    path.verbs[2] ==
    ConicTo(
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 1),
      0.70710677,
    ),
  )
  assert_true(path.verbs[6] == LineTo(@moui_skia.Point::new(0, 8)))

  let ccw = @moui_skia.Path::new().add_rrect(rrect, direction=CCW)
  assert_true(
    ccw.verbs[1] ==
    ConicTo(
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(0, 2),
      0.70710677,
    ),
  )

  let rect_path = @moui_skia.Path::new().add_rrect(
    @moui_skia.RRect::from_rect(rect),
  )
  assert_true(rect_path.verbs == @moui_skia.Path::new().add_rect(rect).verbs)
}

///|
test "path transform maps every verb point" {
  let path = @moui_skia.Path::new(fill_type=EvenOdd)
    .move_to(@moui_skia.Point::new(1, 2))
    .line_to(@moui_skia.Point::new(3, 4))
    .quad_to(@moui_skia.Point::new(5, 6), @moui_skia.Point::new(7, 8))
    .conic_to(@moui_skia.Point::new(9, 10), @moui_skia.Point::new(11, 12), 0.5)
    .cubic_to(
      @moui_skia.Point::new(13, 14),
      @moui_skia.Point::new(15, 16),
      @moui_skia.Point::new(17, 18),
    )
    .close()
  let transformed = path.transform(
    @moui_skia.Matrix::scale_translate(2, 3, 10, 20),
  )
  assert_true(transformed.fill_type == EvenOdd)
  assert_true(transformed.last_point() == Some(@moui_skia.Point::new(44, 74)))
  assert_true(transformed.verbs[0] == MoveTo(@moui_skia.Point::new(12, 26)))
  assert_true(
    transformed.verbs[3] ==
    ConicTo(@moui_skia.Point::new(28, 50), @moui_skia.Point::new(32, 56), 0.5),
  )
  assert_true(transformed.verbs[5] == Close)

  let offset = path.offset(2, 3)
  assert_true(offset.bounds() == Some(@moui_skia.Rect::new(3, 5, 19, 21)))
}

///|
test "path stroke bounds conservatively outsets geometry" {
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(1, 2, 3, 4),
  )
  let fill = @moui_skia.Paint::new(style=Fill, stroke_width=10)
  assert_true(path.stroke_bounds(fill) == path.bounds())
  let stroke = @moui_skia.Paint::new(style=Stroke, stroke_width=6)
  assert_true(
    path.stroke_bounds(stroke) == Some(@moui_skia.Rect::new(-2, -1, 7, 9)),
  )
  let stroke_and_fill = @moui_skia.Paint::new(
    style=StrokeAndFill,
    stroke_width=2,
  )
  assert_true(
    path.stroke_bounds(stroke_and_fill) ==
    Some(@moui_skia.Rect::new(0, 1, 5, 7)),
  )
  assert_true(@moui_skia.Path::new().stroke_bounds(stroke) is None)
}

///|
test "path compute tight bounds excludes off-curve controls" {
  let quad = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .quad_to(@moui_skia.Point::new(10, 10), @moui_skia.Point::new(20, 0))
  assert_true(quad.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(
    quad.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 5)),
  )

  let conic = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .conic_to(@moui_skia.Point::new(10, 10), @moui_skia.Point::new(20, 0), 1)
  assert_true(conic.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(
    conic.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 5)),
  )

  let cubic = @moui_skia.Path::new()
    .move_to(@moui_skia.Point::new(0, 0))
    .cubic_to(
      @moui_skia.Point::new(0, 12),
      @moui_skia.Point::new(12, 12),
      @moui_skia.Point::new(12, 0),
    )
  assert_true(cubic.bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 12)))
  assert_true(
    cubic.compute_tight_bounds() == Some(@moui_skia.Rect::new(0, 0, 12, 9)),
  )
}
