///|
fn make_solid_image(
  width : Int,
  height : Int,
  r : Int,
  g : Int,
  b : Int,
) -> ImageData {
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for i in 0..<(width * height) {
    let idx = i * 4
    buf[idx] = r.to_byte()
    buf[idx + 1] = g.to_byte()
    buf[idx + 2] = b.to_byte()
    buf[idx + 3] = b'\xFF'
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
fn make_gradient_image(width : Int, height : Int) -> ImageData {
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      let r = x * 255 / (width - 1)
      let g = y * 255 / (height - 1)
      let b = (x + y) * 255 / (width + height - 2)
      buf[idx] = r.to_byte()
      buf[idx + 1] = g.to_byte()
      buf[idx + 2] = b.to_byte()
      buf[idx + 3] = b'\xFF'
    }
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
fn assert_image_rgb_close(
  actual : ImageData,
  expected : ImageData,
  tol : Int,
) -> Unit raise {
  assert_eq(actual.width, expected.width)
  assert_eq(actual.height, expected.height)
  assert_eq(actual.data.length(), expected.data.length())
  for i in 0..<(actual.width * actual.height) {
    let idx = i * 4
    let dr = (actual.data[idx].to_int() - expected.data[idx].to_int()).abs()
    let dg = (actual.data[idx + 1].to_int() - expected.data[idx + 1].to_int()).abs()
    let db = (actual.data[idx + 2].to_int() - expected.data[idx + 2].to_int()).abs()
    assert_true(dr <= tol)
    assert_true(dg <= tol)
    assert_true(db <= tol)
    assert_eq(actual.data[idx + 3].to_int(), 255)
  }
}

///|
test "jpeg_encode 8x8 solid roundtrip" {
  let original = make_solid_image(8, 8, 220, 40, 90)
  let jpeg = encode_jpeg(original, quality=95)
  let decoded = decode_jpeg(jpeg)
  assert_image_rgb_close(decoded, original, 3)
}

///|
test "jpeg_encode 16x16 gradient roundtrip" {
  let original = make_gradient_image(16, 16)
  let jpeg = encode_jpeg(original, quality=90)
  let decoded = decode_jpeg(jpeg)
  assert_image_rgb_close(decoded, original, 20)
}

///|
test "jpeg_encode non 8 multiple roundtrip" {
  let original = make_gradient_image(10, 10)
  let jpeg = encode_jpeg(original, quality=90)
  let decoded = decode_jpeg(jpeg)
  assert_image_rgb_close(decoded, original, 20)
}

///|
test "jpeg_encode invalid dimensions and data length" {
  let img_invalid_dim : ImageData = { width: 0, height: 1, data: Bytes::new(0) }
  let r1 : Result[Bytes, _] = try? encode_jpeg(img_invalid_dim)
  assert_true(r1 is Err(_))

  let img_invalid_data : ImageData = {
    width: 2,
    height: 2,
    data: Bytes::new(4),
  }
  let r2 : Result[Bytes, _] = try? encode_jpeg(img_invalid_data)
  assert_true(r2 is Err(_))
}

///|
test "jpeg_encode quality affects file size" {
  let img = make_gradient_image(32, 32)
  let jpeg_q10 = encode_jpeg(img, quality=10)
  let jpeg_q95 = encode_jpeg(img, quality=95)
  assert_true(jpeg_q10.length() < jpeg_q95.length())
}
