///|
#cfg(any(target="native", target="llvm"))
extern "c" fn exit_with_code(code : Int) -> Unit = "exit"

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
#cfg(not(any(target="native", target="llvm")))
fn exit_with_code(code : Int) -> Unit {
  ignore(code)
  abort("native smoke test must be run with --target native")
}

///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  exit_with_code(1)
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
    println(b0.to_hex() + " " + b1.to_hex() + " " + b2.to_hex() + " " + b3.to_hex())
    println("actual")
    println(
      pixmap.pixels[offset].to_hex() + " " +
      pixmap.pixels[offset + 1].to_hex() + " " +
      pixmap.pixels[offset + 2].to_hex() + " " +
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
    [
      @skia.Point::new(28, 7),
      @skia.Point::new(31, 7),
      @skia.Point::new(31, 10),
    ],
    @skia.Paint::new(color=@skia.Color::black(), stroke_width=1),
    mode=@skia.Polygon,
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
  ) is Some(linear_shader) else {
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
  ) is Some(radial_shader) else {
    fail_smoke("failed to create native radial gradient shader")
  }
  canvas.draw_rect_shader(
    @skia.Rect::from_xywh(24, 22, 4, 4),
    radial_shader,
    @skia.Paint::new(),
  )

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

  let portable_path = @skia.Path::new().add_rect(@skia.Rect::from_xywh(22, 26, 4, 4))
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
  if pixmap.color_type() != @skia.RGBA8888 || pixmap.alpha_type() != @skia.Premul {
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
  guard surface.read_pixels(bounds=@skia.IRect::from_xywh(12, 28, 8, 4)) is Some(image_draw_pixmap) else {
    fail_smoke("failed to read image drawback pixels")
  }
  assert_pixel(image_draw_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  assert_pixel(image_draw_pixmap, @skia.IPoint::new(4, 0), 0xff, 0x00, 0x00, 0xff)
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
  if bitmap.row_bytes() < size.width * 4 || bitmap.byte_size() < size.width * size.height * 4 {
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
      guard @native.Font::from_typeface(typeface, size=9.0) is Some(typeface_font) else {
        fail_smoke("failed to create native font from default typeface")
      }
      smoke_mark(b"font from typeface")
      canvas.draw_text_utf8(
        smoke_text_bytes(),
        @skia.Point::new(16, 31),
        typeface_font,
        @skia.Paint::new(color=@skia.Color::black()),
      )
      smoke_mark(b"drew typeface text")
    }
  }

  smoke_mark(b"done")
  println("skia_mbt native smoke test passed")
}
