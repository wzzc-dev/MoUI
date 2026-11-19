///|
test "RgbaBuffer is a writable clipped RGBA buffer" {
  let buffer = @core.RgbaBuffer::new(width=2, height=1)
  assert_eq(buffer.width, 2)
  assert_eq(buffer.height, 1)
  assert_eq(buffer.row_bytes(), 8)
  assert_eq(buffer.pixels.length(), 8)
  buffer.set(0, 0, @core.Color::rgba(r=1.0, g=0.0, b=0.5, a=1.0))
  let pixel = buffer.get(0, 0)
  inspect(pixel.r, content="1")
  inspect(pixel.g, content="0")
  assert_true((pixel.b - 0.5).abs() < 0.01)
  inspect(buffer.pixels[0].to_uint(), content="255")
  inspect(buffer.pixels[2].to_uint(), content="128")
  // Out-of-bounds writes are ignored and reads are transparent.
  buffer.set(9, 9, @core.Color::white())
  assert_eq(buffer.get(9, 9), @core.Color::transparent())
  let wrapped = @core.RgbaBuffer::from_rgba(
    width=2,
    height=1,
    pixels=buffer.pixels.copy(),
  ).unwrap()
  inspect(wrapped.get(0, 0).r, content="1")
  match
    @core.RgbaBuffer::from_rgba(width=2, height=2, pixels=buffer.pixels.copy()) {
    None => ()
    Some(_) => fail("mismatched RGBA length must not wrap")
  }
}

///|
test "RgbaBuffer encodes an 8-bit RGBA PNG with IHDR width and height" {
  let buffer = @core.RgbaBuffer::new(width=3, height=2)
  buffer.set(1, 1, @core.Color::rgba(r=0.0, g=1.0, b=0.25, a=1.0))
  let png = buffer.to_png_bytes()
  assert_true(png.length() > 8)
  assert_eq(png[0].to_uint(), 137U)
  assert_eq(png[1].to_uint(), 80U)
  assert_eq(png[2].to_uint(), 78U)
  assert_eq(png[3].to_uint(), 71U)
  // IHDR data starts at byte 16: 4-byte big-endian width, then height.
  let width = (png[16].to_uint() << 24) |
    (png[17].to_uint() << 16) |
    (png[18].to_uint() << 8) |
    png[19].to_uint()
  let height = (png[20].to_uint() << 24) |
    (png[21].to_uint() << 16) |
    (png[22].to_uint() << 8) |
    png[23].to_uint()
  assert_eq(width, 3U)
  assert_eq(height, 2U)
}
