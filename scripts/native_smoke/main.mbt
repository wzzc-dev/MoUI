///|
#cfg(any(target="native", target="llvm"))
#borrow(message)
extern "c" fn smoke_mark(message : Bytes) -> Unit = "skia_mbt_native_smoke_mark"

///|
#cfg(not(any(target="native", target="llvm")))
fn smoke_mark(message : Bytes) -> Unit {
  ignore(message)
}

///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("native smoke test failed")
}

///|
fn assert_pixel(
  pixmap : @skia.Pixmap,
  point : @skia.IPoint,
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
) -> Unit {
  guard pixmap.offset(point) is Some(offset) else {
    fail_smoke("pixel is outside the smoke-test pixmap")
  }
  if pixmap.pixels[offset] != b0 ||
    pixmap.pixels[offset + 1] != b1 ||
    pixmap.pixels[offset + 2] != b2 ||
    pixmap.pixels[offset + 3] != b3 {
    println(
      "unexpected pixel at " + point.x.to_string() + "," + point.y.to_string(),
    )
    println("expected")
    println(
      b0.to_hex() + " " + b1.to_hex() + " " + b2.to_hex() + " " + b3.to_hex(),
    )
    println("actual")
    println(
      pixmap.pixels[offset].to_hex() +
      " " +
      pixmap.pixels[offset + 1].to_hex() +
      " " +
      pixmap.pixels[offset + 2].to_hex() +
      " " +
      pixmap.pixels[offset + 3].to_hex(),
    )
    fail_smoke("unexpected pixel value in native smoke test")
  }
}

///|
fn assert_png_signature(bytes : Bytes) -> Unit {
  if bytes.length() < 8 {
    fail_smoke("encoded PNG data is too small")
  }
  if bytes[0] != 0x89 ||
    bytes[1] != 0x50 ||
    bytes[2] != 0x4e ||
    bytes[3] != 0x47 ||
    bytes[4] != 0x0d ||
    bytes[5] != 0x0a ||
    bytes[6] != 0x1a ||
    bytes[7] != 0x0a {
    fail_smoke("encoded image does not have a PNG signature")
  }
}

///|
fn assert_smoke_pixels(pixmap : @skia.Pixmap) -> Unit {
  assert_pixel(pixmap, @skia.IPoint::new(0, 0), 0xff, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 8), 0xff, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(22, 8), 0x00, 0xff, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 22), 0x00, 0x00, 0xff, 0xff)
}

///|
fn smoke_text_bytes() -> Bytes {
  Bytes::from_array([0x53, 0x6b, 0x69, 0x61])
}

///|
fn main {
  smoke_mark(b"start")
  if !@native.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure native/moon.pkg with SKIA_MBT_HAS_SKIA, Skia headers, and linker flags",
    )
  }

  let size = @skia.ISize::new(32, 32)
  guard @native.Surface::raster_n32_premul(size) is Some(surface) else {
    fail_smoke("failed to create raster N32 premul surface")
  }
  if surface.dimensions() != size ||
    surface.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("surface metadata does not match requested N32 premul size")
  }
  let descriptor = surface.descriptor()
  if !descriptor.is_raster() ||
    descriptor.image_info != surface.image_info() ||
    descriptor.dimensions() != size {
    fail_smoke("surface descriptor does not match the raster surface")
  }
  println("native smoke surface descriptor backend")
  println("raster")
  guard surface.canvas() is Some(canvas) else {
    fail_smoke("failed to borrow native canvas")
  }

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

  guard @native.Shader::color(@skia.Color::cyan()) is Some(color_shader) else {
    fail_smoke("failed to create native color shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(18, 18, 4, 4),
    color_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::linear_gradient(
      @skia.Point::new(22, 18),
      @skia.Point::new(26, 18),
      @skia.Color::yellow(),
      @skia.Color::magenta(),
    )
    is Some(linear_shader) else {
    fail_smoke("failed to create native linear gradient shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(22, 18, 4, 4),
    linear_shader,
    @skia.Paint::new(),
  )
  guard @native.Shader::radial_gradient(
      @skia.Point::new(26, 24),
      2.0,
      @skia.Color::white(),
      @skia.Color::black(),
    )
    is Some(radial_shader) else {
    fail_smoke("failed to create native radial gradient shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(24, 22, 4, 4),
    radial_shader,
    @skia.Paint::new(),
  )
  println("native smoke shader draws")
  println(3)

  guard @native.Path::new() is Some(native_path) else {
    fail_smoke("failed to create native path")
  }
  native_path.add_rect(@skia.Rect::from_xywh(16, 24, 4, 4))
  if !native_path.contains(@skia.Point::new(18, 26)) {
    fail_smoke("native path does not contain a point inside its rect")
  }
  guard native_path.bounds() is Some(native_path_bounds) else {
    fail_smoke("native path did not report bounds")
  }
  if native_path_bounds != @skia.Rect::from_xywh(16, 24, 4, 4) {
    fail_smoke("native path bounds do not match its rect")
  }
  canvas.draw_path(native_path, @skia.Paint::new(color=@skia.Color::magenta()))

  guard @native.Path::new() is Some(native_poly) else {
    fail_smoke("failed to create native polygon path")
  }
  native_poly.add_poly(
    [
      @skia.Point::new(12, 28),
      @skia.Point::new(16, 28),
      @skia.Point::new(16, 31),
    ],
    close=true,
  )
  if !native_poly.is_last_contour_closed() ||
    native_poly.count_verbs() != 4 ||
    native_poly.count_points() != 3 {
    fail_smoke("native polygon path did not record the expected contour")
  }
  if !native_poly.contains(@skia.Point::new(15, 29)) {
    fail_smoke("native polygon path does not contain an interior point")
  }
  canvas.draw_path(native_poly, @skia.Paint::new(color=@skia.Color::magenta()))

  let portable_path = @skia.Path::new().add_rect(
    @skia.Rect::from_xywh(22, 26, 4, 4),
  )
  guard @native.Path::from_value(portable_path) is Some(replayed_path) else {
    fail_smoke("failed to replay portable path into native path")
  }
  if !replayed_path.contains(@skia.Point::new(24, 28)) {
    fail_smoke("replayed portable path does not contain an interior point")
  }
  canvas.draw_path_value(
    portable_path,
    @skia.Paint::new(color=@skia.Color::yellow()),
  )

  guard @native.Path::new() is Some(appended_path) else {
    fail_smoke("failed to create native add-path target")
  }
  appended_path.add_rect(@skia.Rect::from_xywh(28, 22, 2, 2))
  appended_path.add_path_value(
    @skia.Path::new().add_poly(
      [
        @skia.Point::new(0, 0),
        @skia.Point::new(3, 0),
        @skia.Point::new(3, 3),
      ],
      close=true,
    ),
    matrix=@skia.Matrix::translate(28, 26),
  )
  if appended_path.count_verbs() != 9 ||
    appended_path.count_points() != 7 ||
    appended_path.bounds() != Some(@skia.Rect::new(28, 22, 31, 29)) {
    fail_smoke("native add_path_value did not append the expected geometry")
  }
  if !appended_path.contains(@skia.Point::new(30, 27)) {
    fail_smoke("native add_path_value does not contain appended geometry")
  }
  println("native smoke path verbs")
  println(appended_path.count_verbs())
  canvas.draw_path(appended_path, @skia.Paint::new(color=@skia.Color::cyan()))

  let save_count_before_transform = canvas.save_count()
  ignore(canvas.save())
  canvas.translate(@skia.Point::new(12, 24))
  canvas.draw_rect(
    @skia.Rect::from_xywh(0, 0, 3, 3),
    @skia.Paint::new(color=@skia.Color::cyan()),
  )
  canvas.restore_to_count(save_count_before_transform)

  guard surface.read_pixels() is Some(pixmap) else {
    fail_smoke("failed to read surface pixels")
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
  println("native smoke readback width")
  println(pixmap.width())
  println("native smoke readback height")
  println(pixmap.height())
  println("native smoke readback row_bytes")
  println(pixmap.row_bytes())

  let red_bounds = @skia.IRect::from_xywh(4, 4, 4, 4)
  guard surface.read_pixels(bounds=red_bounds) is Some(red_pixmap) else {
    fail_smoke("failed to read bounded surface pixels")
  }
  if red_pixmap.dimensions() != red_bounds.size() {
    fail_smoke("bounded readback dimensions do not match requested bounds")
  }
  assert_pixel(red_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  println("native smoke bounded readback width")
  println(red_pixmap.width())
  println("native smoke bounded readback height")
  println(red_pixmap.height())

  guard surface.image_snapshot() is Some(image) else {
    fail_smoke("failed to snapshot surface")
  }
  if image.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("snapshot image metadata does not match N32 premul size")
  }
  guard surface.image_snapshot_with_bounds(red_bounds) is Some(red_image) else {
    fail_smoke("failed to snapshot bounded surface rectangle")
  }
  if red_image.dimensions() != red_bounds.size() {
    fail_smoke("bounded snapshot dimensions do not match requested bounds")
  }
  canvas.draw_image(red_image, @skia.Point::new(12, 28))
  canvas.draw_image_rect(
    red_image,
    @skia.Rect::from_xywh(0, 0, 4, 4),
    @skia.Rect::from_xywh(16, 28, 4, 4),
    @skia.Paint::new(),
    sampling=@skia.SamplingOptions::new(),
  )
  guard surface.read_pixels(bounds=@skia.IRect::from_xywh(12, 28, 8, 4))
    is Some(image_draw_pixmap) else {
    fail_smoke("failed to read image drawback pixels")
  }
  assert_pixel(
    image_draw_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  assert_pixel(
    image_draw_pixmap,
    @skia.IPoint::new(4, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  println("native smoke bounded snapshot width")
  println(red_image.width())
  println("native smoke bounded snapshot height")
  println(red_image.height())
  guard image.encode_to_data(format=@skia.PNG, quality=100) is Some(data) else {
    fail_smoke("failed to encode surface snapshot as PNG")
  }
  smoke_mark(b"encoded image")
  let encoded = data.to_bytes()
  if encoded.length() != data.size() {
    fail_smoke("encoded PNG byte length does not match Data::size")
  }
  assert_png_signature(encoded)
  println("native smoke encoded PNG bytes")
  println(encoded.length())

  guard @native.Image::from_encoded_bytes(encoded) is Some(decoded) else {
    fail_smoke("failed to decode encoded PNG bytes")
  }
  if decoded.dimensions() != size {
    fail_smoke("decoded PNG dimensions do not match the source surface")
  }
  println("native smoke decoded image width")
  println(decoded.width())
  println("native smoke decoded image height")
  println(decoded.height())

  guard @native.Codec::from_bytes(encoded) is Some(codec) else {
    fail_smoke("failed to create Codec from encoded PNG bytes")
  }
  if codec.encoded_format() != Some(@skia.PNG) {
    fail_smoke("Codec did not report PNG format")
  }
  if codec.dimensions() != size {
    fail_smoke("Codec dimensions do not match the source surface")
  }
  if codec.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("Codec image info does not match N32 premul size")
  }
  println("native smoke codec encoded format PNG")
  println("native smoke codec width")
  println(codec.width())
  println("native smoke codec height")
  println(codec.height())
  guard codec.decode_n32_premul() is Some(bitmap) else {
    fail_smoke("failed to decode PNG bytes into an N32 premul bitmap")
  }
  if bitmap.image_info() != @skia.ImageInfo::n32_premul(size) {
    fail_smoke("decoded bitmap metadata does not match N32 premul size")
  }
  if bitmap.row_bytes() < size.width * 4 ||
    bitmap.byte_size() < size.width * size.height * 4 {
    fail_smoke("decoded bitmap storage is too small for N32 pixels")
  }
  guard bitmap.to_pixmap() is Some(decoded_pixmap) else {
    fail_smoke("failed to copy decoded bitmap pixels")
  }
  assert_smoke_pixels(decoded_pixmap)
  smoke_mark(b"decoded bitmap")
  println("native smoke decoded bitmap width")
  println(decoded_pixmap.width())
  println("native smoke decoded bitmap height")
  println(decoded_pixmap.height())

  guard @native.Font::default(size=10.0) is Some(font) else {
    fail_smoke("failed to create default native font")
  }
  smoke_mark(b"font default")
  font.set_size(11.0)
  if font.size() != 11.0 {
    fail_smoke("native font size did not update")
  }
  let font_metrics = font.metrics()
  if font_metrics.ascent > 0.0 || font_metrics.descent < 0.0 {
    fail_smoke("native font metrics have unexpected ascent/descent signs")
  }
  let font_spacing = font.spacing()
  if font_spacing <= 0.0 {
    fail_smoke("native font spacing is not positive")
  }
  println("native smoke font spacing")
  println(font_spacing)
  let measured_text_width = font.measure_text_utf8(smoke_text_bytes())
  if measured_text_width <= 0.0 {
    fail_smoke("native font did not report a positive text width")
  }
  println("native smoke measured text width")
  println(measured_text_width)
  let measured_text_glyphs = font.count_text_utf8(smoke_text_bytes())
  if measured_text_glyphs != 4 {
    fail_smoke("native font did not report the expected text glyph count")
  }
  println("native smoke text glyph count")
  println(measured_text_glyphs)
  let glyphs = font.text_to_glyphs_utf8(smoke_text_bytes())
  if glyphs.length() != measured_text_glyphs || glyphs[0].to_int() <= 0 {
    fail_smoke("native font did not map text to expected glyph ids")
  }
  println("native smoke first glyph id")
  println(glyphs[0].to_int())
  let glyph_widths = font.glyph_widths(glyphs)
  if glyph_widths.length() != glyphs.length() || glyph_widths[0] <= 0.0 {
    fail_smoke("native font did not report expected glyph widths")
  }
  println("native smoke first glyph width")
  println(glyph_widths[0])
  let glyph_positions = font.text_glyph_positions_utf8(
    smoke_text_bytes(),
    origin=@skia.Point::new(2.0, 3.0),
  )
  if glyph_positions.length() != glyphs.length() ||
    glyph_positions[0] != @skia.Point::new(2.0, 3.0) ||
    glyph_positions[1].x <= glyph_positions[0].x {
    fail_smoke("native font did not report expected glyph positions")
  }
  println("native smoke second glyph position x")
  println(glyph_positions[1].x)
  let glyph_x_positions = font.text_glyph_x_positions_utf8(
    smoke_text_bytes(),
    origin=2.0,
  )
  if glyph_x_positions.length() != glyphs.length() ||
    glyph_x_positions[0] != 2.0 ||
    glyph_x_positions[1] <= glyph_x_positions[0] {
    fail_smoke("native font did not report expected glyph x positions")
  }
  println("native smoke second glyph x position")
  println(glyph_x_positions[1])
  let glyph_bounds = font.glyph_bounds_many(glyphs)
  if glyph_bounds.length() != glyphs.length() ||
    glyph_bounds[0].width() <= 0.0 ||
    glyph_bounds[0].height() <= 0.0 {
    fail_smoke("native font did not report expected glyph bounds")
  }
  println("native smoke first glyph bounds width")
  println(glyph_bounds[0].width())
  guard font.measure_text_bounds_utf8(smoke_text_bytes()) is Some(text_bounds) else {
    fail_smoke("native font did not report text bounds")
  }
  if text_bounds.width() <= 0.0 || text_bounds.height() < 0.0 {
    fail_smoke("native font text bounds are invalid")
  }
  println("native smoke measured text bounds width")
  println(text_bounds.width())
  if @native.skia_shaper_available() {
    smoke_mark(b"skshaper available")
    guard font.shape_text_utf8(smoke_text_bytes()) is Some(shaped_run) else {
      fail_smoke("native SkShaper was available but did not shape text")
    }
    let shaped_glyph_count = shaped_run.glyph_count()
    let shaped_glyphs = shaped_run.glyphs()
    let shaped_positions = shaped_run.positions()
    let shaped_clusters = shaped_run.clusters()
    if shaped_glyph_count <= 0 ||
      shaped_glyphs.length() != shaped_glyph_count ||
      shaped_positions.length() != shaped_glyph_count ||
      shaped_clusters.length() != shaped_glyph_count ||
      shaped_glyphs[0].to_int() <= 0 ||
      shaped_run.advance().x <= 0.0 {
      fail_smoke("native SkShaper did not produce a valid shaped glyph run")
    }
    println("native smoke shaped glyph count")
    println(shaped_glyph_count)
    canvas.draw_glyphs(
      shaped_glyphs,
      shaped_positions,
      font,
      @skia.Paint::new(color=@skia.Color::black()),
      origin=@skia.Point::new(0, 23),
    )
    smoke_mark(b"drew shaped text")
  }
  canvas.draw_text_utf8(
    smoke_text_bytes(),
    @skia.Point::new(0, 31),
    font,
    @skia.Paint::new(color=@skia.Color::black()),
  )
  smoke_mark(b"drew default text")
  match @native.Typeface::default() {
    None => println("native smoke default typeface unavailable")
    Some(typeface) => {
      smoke_mark(b"typeface default")
      guard @native.Font::from_typeface(typeface, size=9.0)
        is Some(typeface_font) else {
        fail_smoke("failed to create native font from default typeface")
      }
      smoke_mark(b"font from typeface")
      if typeface_font.spacing() <= 0.0 {
        fail_smoke("native typeface font spacing is not positive")
      }
      if typeface_font.measure_text_utf8(smoke_text_bytes()) <= 0.0 {
        fail_smoke("native typeface font did not report a positive text width")
      }
      if typeface_font.count_text_utf8(smoke_text_bytes()) != 4 {
        fail_smoke(
          "native typeface font did not report the expected glyph count",
        )
      }
      let typeface_glyphs = typeface_font.text_to_glyphs_utf8(
        smoke_text_bytes(),
      )
      if typeface_glyphs.length() != 4 || typeface_glyphs[0].to_int() <= 0 {
        fail_smoke(
          "native typeface font did not map text to expected glyph ids",
        )
      }
      let typeface_glyph_widths = typeface_font.glyph_widths(typeface_glyphs)
      if typeface_glyph_widths.length() != 4 || typeface_glyph_widths[0] <= 0.0 {
        fail_smoke("native typeface font did not report expected glyph widths")
      }
      let typeface_glyph_positions = typeface_font.text_glyph_positions_utf8(
        smoke_text_bytes(),
        origin=@skia.Point::new(2.0, 3.0),
      )
      if typeface_glyph_positions.length() != 4 ||
        typeface_glyph_positions[0] != @skia.Point::new(2.0, 3.0) ||
        typeface_glyph_positions[1].x <= typeface_glyph_positions[0].x {
        fail_smoke(
          "native typeface font did not report expected glyph positions",
        )
      }
      let typeface_glyph_bounds = typeface_font.glyph_bounds_many(
        typeface_glyphs,
      )
      if typeface_glyph_bounds.length() != 4 ||
        typeface_glyph_bounds[0].width() <= 0.0 ||
        typeface_glyph_bounds[0].height() <= 0.0 {
        fail_smoke("native typeface font did not report expected glyph bounds")
      }
      match typeface_font.measure_text_bounds_utf8(smoke_text_bytes()) {
        None => fail_smoke("native typeface font did not report text bounds")
        Some(bounds) =>
          if bounds.width() <= 0.0 || bounds.height() < 0.0 {
            fail_smoke("native typeface font text bounds are invalid")
          }
      }
      canvas.draw_text_utf8(
        smoke_text_bytes(),
        @skia.Point::new(16, 31),
        typeface_font,
        @skia.Paint::new(color=@skia.Color::black()),
      )
      smoke_mark(b"drew typeface text")
    }
  }

  guard @native.FontMgr::default() is Some(font_mgr) else {
    fail_smoke("failed to create native font manager")
  }
  smoke_mark(b"font manager default")
  if !font_mgr.is_available() {
    fail_smoke("native font manager is not available")
  }
  let family_count = font_mgr.count_families()
  if family_count <= 0 {
    fail_smoke("native font manager did not report font families")
  }
  println("native smoke font family count")
  println(family_count)
  guard font_mgr.family_name(0) is Some(first_family) else {
    fail_smoke("native font manager did not report first family name")
  }
  if first_family.is_empty() {
    fail_smoke("native font manager reported an empty first family name")
  }
  println("native smoke first font family bytes")
  println(first_family.length())
  guard font_mgr.match_family_style(first_family) is Some(family_typeface) else {
    fail_smoke("native font manager did not match first family typeface")
  }
  guard @native.Font::from_typeface(family_typeface, size=8.0) is Some(family_font) else {
    fail_smoke("failed to create native font from font manager family")
  }
  if family_font.measure_text_utf8(smoke_text_bytes()) <= 0.0 {
    fail_smoke("native font manager family font did not measure text")
  }
  smoke_mark(b"font manager family")

  smoke_mark(b"done")
  println("skia_mbt native smoke test passed")
}
