///|
fn draw_canvas_primitive_smoke(canvas : @native.Canvas) -> Unit {
  canvas.clear(@skia.Color::white())
  canvas.draw_rect(
    @skia.Rect::from_xywh(4, 4, 10, 10),
    @skia.Paint::new(color=@skia.Color::red()),
  )
  canvas.draw_rect(
    @skia.Rect::from_xywh(18, 4, 10, 10),
    @skia.Paint::new(color=@skia.Color::green()),
  )
  canvas.draw_rect(
    @skia.Rect::from_xywh(4, 18, 10, 10),
    @skia.Paint::new(color=@skia.Color::blue()),
  )
  canvas.draw_points(
    [@skia.Point::new(30, 1)],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
  )
  canvas.draw_points(
    [
      @skia.Point::new(28, 3),
      @skia.Point::new(31, 3),
      @skia.Point::new(28, 5),
      @skia.Point::new(31, 5),
    ],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
    mode=@skia.Lines,
  )
  canvas.draw_points(
    [@skia.Point::new(28, 7), @skia.Point::new(31, 7), @skia.Point::new(31, 10)],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
    mode=@skia.Polygon,
  )

  guard @native.Font::default(size=9.0) is Some(glyph_font) else {
    fail_smoke("failed to create native font for glyph drawing")
  }
  let glyph_text = smoke_text_bytes()
  let glyphs = glyph_font.text_to_glyphs_utf8(glyph_text)
  if glyphs.length() != glyph_font.count_text_utf8(glyph_text) ||
    glyphs.length() != 4 {
    fail_smoke("native font did not produce the expected glyph run")
  }
  let glyph_positions = glyph_font.glyph_positions(glyphs)
  if glyph_positions.length() != glyphs.length() {
    fail_smoke("native font did not produce positions for every glyph")
  }
  canvas.draw_glyphs(
    glyphs,
    glyph_positions,
    glyph_font,
    @skia.Paint::new(color=@skia.Color::black(), anti_alias=false),
    origin=@skia.Point::new(1, 31),
  )

  let save_count_before_clip = canvas.save_count()
  ignore(canvas.save())
  if canvas.save_count() != save_count_before_clip + 1 {
    fail_smoke("canvas save count did not increase after save")
  }
  let clip_bounds = @skia.Rect::from_xywh(28, 14, 4, 4)
  canvas.clip_rect(clip_bounds)
  if !canvas.quick_reject_rect(@skia.Rect::from_xywh(0, 14, 4, 4)) {
    fail_smoke("canvas did not reject a rect outside the active clip")
  }
  guard canvas.device_clip_bounds() is Some(device_clip) else {
    fail_smoke("canvas did not report device clip bounds")
  }
  if device_clip != @skia.IRect::from_xywh(28, 14, 4, 4) {
    fail_smoke("canvas device clip bounds do not match clipped rect")
  }
  println("native smoke canvas clip device width")
  println(device_clip.width())
  canvas.draw_rect(
    @skia.Rect::from_xywh(0, 0, 32, 32),
    @skia.Paint::new(color=@skia.Color::black()),
  )
  canvas.restore_to_count(save_count_before_clip)
  if canvas.save_count() != save_count_before_clip {
    fail_smoke("canvas save count did not restore after restore_to_count")
  }
  println("native smoke canvas state restored")
  println(canvas.save_count())
  canvas.draw_rect(
    @skia.Rect::from_xywh(28, 18, 4, 4),
    @skia.Paint::new(color=@skia.Color::black()),
  )
}

///|
fn run_canvas_readback_smoke(
  surface : @native.Surface,
  canvas : @native.Canvas,
  size : @skia.ISize,
) -> @skia.IRect? {
  let save_count_before_transform = canvas.save_count()
  ignore(canvas.save())
  canvas.translate(@skia.Point::new(12, 24))
  canvas.draw_rect(
    @skia.Rect::from_xywh(0, 0, 3, 3),
    @skia.Paint::new(color=@skia.Color::cyan()),
  )
  canvas.restore_to_count(save_count_before_transform)

  if !surface.flush_and_submit() {
    fail_smoke("failed to flush and submit native surface")
  }
  println("native smoke surface flush-and-submit")
  println(1)

  guard surface.read_pixels() is Some(pixmap) else {
    fail_smoke("failed to read surface pixels")
    None
  }
  smoke_mark(b"read pixels")
  if pixmap.dimensions() != size {
    fail_smoke("readback pixmap dimensions do not match the surface")
  }
  if pixmap.bytes_per_pixel() != 4 {
    fail_smoke("readback pixmap is not N32")
  }
  if pixmap.color_type() != @skia.RGBA8888 ||
    pixmap.alpha_type() != @skia.Premul {
    fail_smoke("readback pixmap color info is not N32 premul")
  }
  if pixmap.row_bytes() < size.width * 4 {
    fail_smoke("readback pixmap row bytes are too small")
  }

  assert_smoke_pixels(pixmap)
  assert_pixel(pixmap, @skia.IPoint::new(27, 15), 0xff, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(29, 15), 0x00, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(29, 19), 0x00, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(19, 19), 0x00, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(18, 26), 0xff, 0x00, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(13, 25), 0x00, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(23, 27), 0xff, 0xff, 0x00, 0xff)
  println("native smoke pixmap readback sample proof")
  println(1)
  println("native smoke readback width")
  println(pixmap.width())
  println("native smoke readback height")
  println(pixmap.height())
  println("native smoke readback row_bytes")
  println(pixmap.row_bytes())

  let red_bounds = @skia.IRect::from_xywh(4, 4, 4, 4)
  guard surface.read_pixels(bounds=red_bounds) is Some(red_pixmap) else {
    fail_smoke("failed to read bounded surface pixels")
    None
  }
  if red_pixmap.dimensions() != red_bounds.size() {
    fail_smoke("bounded readback dimensions do not match requested bounds")
  }
  assert_pixel(red_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  println("native smoke bounded readback width")
  println(red_pixmap.width())
  println("native smoke bounded readback height")
  println(red_pixmap.height())
  if surface.read_pixels(bounds=@skia.IRect::from_xywh(-1, 0, 4, 4)) is Some(_) ||
    surface.read_pixels(bounds=@skia.IRect::from_xywh(30, 30, 4, 4)) is Some(_) {
    fail_smoke("out-of-bounds surface readback should be rejected")
  }
  Some(red_bounds)
}

///|
fn run_non_finite_canvas_guard_smoke() -> Unit {
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(4, 4))
    is Some(non_finite_canvas_surface) else {
    fail_smoke("failed to create non-finite canvas guard surface")
  }
  guard non_finite_canvas_surface.canvas() is Some(non_finite_canvas) else {
    fail_smoke("failed to create non-finite canvas guard canvas")
  }
  let invalid_canvas_paint = @skia.Paint::new(color=@skia.Color::red())
  non_finite_canvas.clear(@skia.Color::white())
  non_finite_canvas.translate(@skia.Point::new(1.0 / 0.0, 0))
  non_finite_canvas.scale(@skia.Size::new(1, 0.0 / 0.0))
  non_finite_canvas.rotate(1.0 / 0.0)
  non_finite_canvas.skew(@skia.Point::new(0, 0.0 / 0.0))
  non_finite_canvas.concat(@skia.Matrix::translate(1.0 / 0.0, 0))
  non_finite_canvas.clip_rect(@skia.Rect::new(0, 0, 1.0 / 0.0, 1))
  non_finite_canvas.draw_point(
    @skia.Point::new(0.0 / 0.0, 0),
    invalid_canvas_paint,
  )
  non_finite_canvas.draw_line(
    @skia.Point::new(0, 0),
    @skia.Point::new(1.0 / 0.0, 1),
    invalid_canvas_paint,
  )
  non_finite_canvas.draw_rect(
    @skia.Rect::new(0, 0, 1.0 / 0.0, 1),
    invalid_canvas_paint,
  )
  non_finite_canvas.draw_circle(
    @skia.Point::new(0, 0),
    1.0 / 0.0,
    invalid_canvas_paint,
  )
  guard non_finite_canvas_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(0, 0, 1, 1),
    )
    is Some(non_finite_canvas_pixmap) else {
    fail_smoke("failed to read non-finite canvas guard pixel")
  }
  assert_pixel(
    non_finite_canvas_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0xff,
    0xff,
    0xff,
  )
  println("native smoke non-finite canvas direct geometry skipped")
  println(1)
  let non_finite_canvas_save_count = non_finite_canvas.save_count()
  let non_finite_paint = @skia.Paint::new(
    color=@skia.Color::blue(),
    stroke_width=1.0 / 0.0,
    stroke_miter=0.0 / 0.0,
  )
  ignore(
    non_finite_canvas.save_layer(
      bounds=Some(@skia.Rect::new(0, 0, 1.0 / 0.0, 1)),
      paint=non_finite_paint,
    ),
  )
  non_finite_canvas.draw_line(
    @skia.Point::new(0, 0),
    @skia.Point::new(3, 0),
    non_finite_paint,
  )
  non_finite_canvas.restore_to_count(non_finite_canvas_save_count)
  guard non_finite_canvas_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(0, 0, 1, 1),
    )
    is Some(non_finite_paint_pixmap) else {
    fail_smoke("failed to read non-finite canvas paint guard pixel")
  }
  assert_pixel(
    non_finite_paint_pixmap,
    @skia.IPoint::new(0, 0),
    0x00,
    0x00,
    0xff,
    0xff,
  )
  println("native smoke non-finite canvas paint layer sanitized")
  println(1)
}
