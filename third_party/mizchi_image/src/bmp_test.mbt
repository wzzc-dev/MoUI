///|
test "bmp roundtrip 1x1" {
  let original : ImageData = { width: 1, height: 1, data: b"\xFF\x00\x80\xC0" }
  let bmp = encode_bmp(original)
  let decoded = decode_bmp(bmp) catch { _ => panic() }
  assert_eq(decoded.width, original.width)
  assert_eq(decoded.height, original.height)
  assert_eq(decoded.data, original.data)
}

///|
test "bmp roundtrip 2x2" {
  // red, green, blue, white
  let data = b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF"
  let original : ImageData = { width: 2, height: 2, data }
  let bmp = encode_bmp(original)
  let decoded = decode_bmp(bmp) catch { _ => panic() }
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 2)
  assert_eq(decoded.data, original.data)
}

///|
test "decode_bmp 24-bit" {
  // Construct a 1x1 24-bit BMP: red pixel (BGR = 00 00 FF)
  let buf = FixedArray::make(58, b'\x00')
  // File header
  buf[0] = b'\x42' // 'B'
  buf[1] = b'\x4D' // 'M'
  buf[2] = (58).to_byte() // file size LE
  buf[10] = (54).to_byte() // pixel offset LE
  // DIB header
  buf[14] = (40).to_byte() // header size
  buf[18] = (1).to_byte() // width
  buf[22] = (1).to_byte() // height (bottom-up)
  buf[26] = (1).to_byte() // planes
  buf[28] = (24).to_byte() // bpp
  buf[34] = (4).to_byte() // image size (padded row)
  // Pixel data: BGR for red
  buf[54] = b'\x00' // B
  buf[55] = b'\x00' // G
  buf[56] = b'\xFF' // R
  // buf[57] = padding
  let bmp = Bytes::from_array(buf)
  let img = decode_bmp(bmp) catch { _ => panic() }
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.data[0].to_int(), 255) // R
  assert_eq(img.data[1].to_int(), 0) // G
  assert_eq(img.data[2].to_int(), 0) // B
  assert_eq(img.data[3].to_int(), 255) // A
}

///|
test "decode_bmp 32-bit" {
  // Construct a 1x1 32-bit BMP: semi-transparent green (BGRA = 00 FF 00 80)
  let buf = FixedArray::make(58, b'\x00')
  // File header
  buf[0] = b'\x42'
  buf[1] = b'\x4D'
  buf[2] = (58).to_byte()
  buf[10] = (54).to_byte()
  // DIB header
  buf[14] = (40).to_byte()
  buf[18] = (1).to_byte()
  buf[22] = (1).to_byte()
  buf[26] = (1).to_byte()
  buf[28] = (32).to_byte()
  buf[34] = (4).to_byte()
  // Pixel data: BGRA
  buf[54] = b'\x00' // B
  buf[55] = b'\xFF' // G
  buf[56] = b'\x00' // R
  buf[57] = b'\x80' // A
  let bmp = Bytes::from_array(buf)
  let img = decode_bmp(bmp) catch { _ => panic() }
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.data[0].to_int(), 0) // R
  assert_eq(img.data[1].to_int(), 255) // G
  assert_eq(img.data[2].to_int(), 0) // B
  assert_eq(img.data[3].to_int(), 128) // A
}

///|
test "bmp to png roundtrip" {
  let original : ImageData = {
    width: 2,
    height: 2,
    data: b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF",
  }
  let bmp = encode_bmp(original)
  let img1 = decode_bmp(bmp) catch { _ => panic() }
  let png = encode_png(img1)
  let img2 = decode_png(png) catch { _ => panic() }
  assert_eq(img2.width, original.width)
  assert_eq(img2.height, original.height)
  assert_eq(img2.data, original.data)
}

///|
test "decode_bmp invalid signature" {
  let buf = FixedArray::make(58, b'\x00')
  buf[0] = b'\x00'
  buf[1] = b'\x00'
  let bmp = Bytes::from_array(buf)
  let mut got_error = false
  try {
    let _ = decode_bmp(bmp)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}

///|
test "decode_bmp too short" {
  let bmp = Bytes::new(10)
  let mut got_error = false
  try {
    let _ = decode_bmp(bmp)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}

///|
test "decode_bmp unsupported bpp" {
  let buf = FixedArray::make(58, b'\x00')
  buf[0] = b'\x42'
  buf[1] = b'\x4D'
  buf[2] = (58).to_byte()
  buf[10] = (54).to_byte()
  buf[14] = (40).to_byte()
  buf[18] = (1).to_byte()
  buf[22] = (1).to_byte()
  buf[26] = (1).to_byte()
  buf[28] = (16).to_byte() // 16-bit not supported
  let bmp = Bytes::from_array(buf)
  let mut got_error = false
  try {
    let _ = decode_bmp(bmp)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}
