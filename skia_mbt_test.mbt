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
test "image info computes row and byte sizes" {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(10, 8))
  assert_eq(info.bytes_per_pixel(), 4)
  assert_eq(info.min_row_bytes(), 40)
  assert_eq(info.compute_min_byte_size(), 320)
  assert_eq(info.compute_byte_size(48), 384)
  assert_eq(info.compute_byte_size(39), 0)
  assert_true(info.bounds() == @skia_mbt.IRect::from_xywh(0, 0, 10, 8))
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
  assert_eq(pixmap.byte_size(), 16)
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
