///|
fn read_u16le_at_for_ico_test(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() & 0xFF) | ((data[pos + 1].to_int() & 0xFF) << 8)
}

///|
fn read_u32le_at_for_ico_test(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() & 0xFF) |
  ((data[pos + 1].to_int() & 0xFF) << 8) |
  ((data[pos + 2].to_int() & 0xFF) << 16) |
  ((data[pos + 3].to_int() & 0xFF) << 24)
}

///|
fn decode_ico_png_payload_for_test(data : Bytes) -> ImageData raise {
  assert_true(data.length() >= 22)
  assert_eq(read_u16le_at_for_ico_test(data, 0), 0)
  assert_eq(read_u16le_at_for_ico_test(data, 2), 1)
  assert_eq(read_u16le_at_for_ico_test(data, 4), 1)
  let payload_size = read_u32le_at_for_ico_test(data, 14)
  let payload_offset = read_u32le_at_for_ico_test(data, 18)
  assert_eq(payload_offset, 22)
  assert_true(payload_offset + payload_size <= data.length())
  let payload = data[payload_offset:payload_offset + payload_size]
  decode_png(payload.to_bytes())
}

///|
fn make_ico_test_image(width : Int, height : Int) -> ImageData {
  let data = Bytes::makei(width * height * 4, fn(i) {
    match i % 4 {
      0 => (i / 4 * 17 % 256).to_byte()
      1 => (i / 4 * 31 % 256).to_byte()
      2 => (i / 4 * 47 % 256).to_byte()
      _ => if i / 4 % 5 == 0 { b'\x80' } else { b'\xFF' }
    }
  })
  { width, height, data }
}

///|
test "ico_encode single png entry roundtrip" {
  let original = make_ico_test_image(16, 16)
  let ico = encode_ico(original)
  assert_eq(read_u16le_at_for_ico_test(ico, 0), 0)
  assert_eq(read_u16le_at_for_ico_test(ico, 2), 1)
  assert_eq(read_u16le_at_for_ico_test(ico, 4), 1)
  assert_eq(ico[6].to_int() & 0xFF, 16)
  assert_eq(ico[7].to_int() & 0xFF, 16)
  assert_eq(read_u16le_at_for_ico_test(ico, 10), 1)
  assert_eq(read_u16le_at_for_ico_test(ico, 12), 32)
  let decoded = decode_ico_png_payload_for_test(ico)
  assert_eq(decoded, original)
}

///|
test "ico_encode 256px uses zero directory size" {
  let original = make_ico_test_image(256, 256)
  let ico = encode_ico(original)
  assert_eq(ico[6].to_int() & 0xFF, 0)
  assert_eq(ico[7].to_int() & 0xFF, 0)
}

///|
test "ico_encode rejects too large dimensions" {
  let original = make_ico_test_image(257, 1)
  let mut got_error = false
  try {
    let _ = encode_ico(original)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}

///|
test "ico_encode rejects invalid data length" {
  let img : ImageData = { width: 2, height: 2, data: b"\x00\x11\x22\x33" }
  let mut got_error = false
  try {
    let _ = encode_ico(img)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}
