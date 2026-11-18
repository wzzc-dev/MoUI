///|
test "RgbaImage is a writable clipped RGBA buffer" {
  let image = @core.RgbaImage::new(width=2, height=1)
  assert_eq(image.width, 2)
  assert_eq(image.height, 1)
  assert_eq(image.row_bytes(), 8)
  assert_eq(image.pixels.length(), 8)
  image.set(0, 0, @core.Color::rgba(r=1.0, g=0.0, b=0.5, a=1.0))
  let pixel = image.get(0, 0)
  inspect(pixel.r, content="1")
  inspect(pixel.g, content="0")
  assert_true((pixel.b - 0.5).abs() < 0.01)
  inspect(image.pixels[0].to_uint(), content="255")
  inspect(image.pixels[2].to_uint(), content="128")
  // Out-of-bounds writes are ignored and reads are transparent.
  image.set(9, 9, @core.Color::white())
  assert_eq(image.get(9, 9), @core.Color::transparent())
  let wrapped = @core.RgbaImage::from_rgba(
    width=2,
    height=1,
    pixels=image.pixels.copy(),
  ).unwrap()
  inspect(wrapped.get(0, 0).r, content="1")
  match
    @core.RgbaImage::from_rgba(width=2, height=2, pixels=image.pixels.copy()) {
    None => ()
    Some(_) => fail("mismatched RGBA length must not wrap")
  }
}
