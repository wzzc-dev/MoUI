///|
fn png_test_u32_be(data : Bytes, offset : Int32) -> Int32 {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn png_test_contains(data : Bytes, needle : Bytes) -> Bool {
  if needle.length() == 0 || needle.length() > data.length() {
    return false
  }
  for start in 0..<=(data.length() - needle.length()) {
    let mut matches = true
    for index in 0..<needle.length() {
      if data[start + index] != needle[index] {
        matches = false
        break
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
test "png encoder writes an rgba container with the requested size" {
  let width = 2
  let height = 2
  let pixels = Bytes::from_array([
    b'\xff', b'\x00', b'\x00', b'\xff', b'\x00', b'\xff', b'\x00', b'\xff', b'\x00',
    b'\x00', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
  ])
  let png = png_encode_rgba(width, height, width * 4, pixels) catch {
    error => fail("png encode failed: \{error}")
  }
  let signature = [b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1a', b'\n']
  let mut signature_matches = true
  for index in 0..<signature.length() {
    if png[index] != signature[index] {
      signature_matches = false
    }
  }
  assert_true(signature_matches)
  assert_true(png_test_contains(png, b"IHDR"))
  assert_true(png_test_contains(png, b"IDAT"))
  assert_true(png_test_contains(png, b"IEND"))
  // Signature (8) + length (4) + "IHDR" (4) + width.
  assert_true(png_test_u32_be(png, 16) == width)
  assert_true(png_test_u32_be(png, 20) == height)
}

///|
test "png encoder rejects short pixel buffers" {
  let pixels = Bytes::make(4, b'\x00')
  let result = try png_encode_rgba(2, 2, 8, pixels) catch {
    _ => "rejected"
  } noraise {
    _ => "encoded"
  }
  assert_true(result == "rejected")
}
