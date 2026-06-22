///|
test "Pixmap::to_rgba_bytes exports raw RGBA bytes" {
  let pixmap = Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, Color::new(r=1, g=2, b=3, a=4))
  pixmap.set_pixel(1, 0, Color::new(r=5, g=6, b=7, a=8))
  let expected : Array[Byte] = [1, 2, 3, 4, 5, 6, 7, 8]
  assert_eq(pixmap.to_rgba_bytes(), Bytes::from_array(expected))
}

///|
test "Pixmap::from_rgba_bytes decodes packed raw pixels" {
  let bytes = Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8])
  match Pixmap::from_rgba_bytes(2, 1, bytes) {
    Ok(decoded) => {
      assert_eq(decoded.get_width(), 2)
      assert_eq(decoded.get_height(), 1)
      assert_eq(decoded.get_pixel(0, 0), Color::new(r=1, g=2, b=3, a=4))
      assert_eq(decoded.get_pixel(1, 0), Color::new(r=5, g=6, b=7, a=8))
      decoded.set_pixel(0, 0, Color::red())
      assert_eq(bytes, Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8]))
    }
    Err(_) => abort("expected RGBA decode")
  }

  match Pixmap::from_rgba_bytes(0, 0, Bytes::from_array([])) {
    Ok(empty) => {
      assert_eq(empty.get_width(), 0)
      assert_eq(empty.get_height(), 0)
      assert_eq(empty.to_rgba_bytes(), Bytes::from_array([]))
    }
    Err(_) => abort("expected empty RGBA decode")
  }
}

///|
test "Pixmap::from_rgba_bytes reports structural errors" {
  match Pixmap::from_rgba_bytes(-1, 1, Bytes::from_array([])) {
    Err(PixmapDecodeError::InvalidRgbaDimensions(-1, 1)) => ()
    _ => abort("expected RGBA dimensions error")
  }

  match Pixmap::from_rgba_bytes(2, 1, Bytes::from_array([1, 2, 3, 4])) {
    Err(PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected RGBA length mismatch")
  }
}

///|
test "Pixmap::to_ppm_bytes encodes deterministic P6 RGB output" {
  let pixmap = Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, Color::new(r=1, g=2, b=3, a=4))
  pixmap.set_pixel(1, 0, Color::new(r=250, g=251, b=252, a=253))
  let ppm = pixmap.to_ppm_bytes()
  let expected : Array[Byte] = [
    80, 54, 10, 50, 32, 49, 10, 50, 53, 53, 10, 1, 2, 3, 250, 251, 252,
  ]
  assert_eq(ppm, Bytes::from_array(expected))
}

///|
test "Pixmap::to_ppm_bytes encodes empty dimensions" {
  let pixmap = Pixmap::new(0, 0)
  let expected : Array[Byte] = [80, 54, 10, 48, 32, 48, 10, 50, 53, 53, 10]
  assert_eq(pixmap.to_ppm_bytes(), Bytes::from_array(expected))
}

///|
test "Pixmap::to_bmp_bytes encodes deterministic BGRA output" {
  let pixmap = Pixmap::new(2, 2)
  pixmap.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=255))
  pixmap.set_pixel(1, 0, Color::new(r=0, g=255, b=0, a=128))
  pixmap.set_pixel(0, 1, Color::new(r=0, g=0, b=255, a=64))
  pixmap.set_pixel(1, 1, Color::transparent())
  let expected : Array[Byte] = [
    66, 77, 70, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 2, 0, 0, 0, 2, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 255, 0, 0, 64, 0, 0, 0, 0, 0, 0, 255, 255, 0, 255, 0, 128,
  ]
  assert_eq(pixmap.to_bmp_bytes(), Bytes::from_array(expected))
}

///|
test "Pixmap::to_bmp_bytes encodes empty dimensions" {
  let pixmap = Pixmap::new(0, 0)
  let expected : Array[Byte] = [
    66, 77, 54, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
  ]
  assert_eq(pixmap.to_bmp_bytes(), Bytes::from_array(expected))
}

///|
test "Pixmap::to_png_bytes encodes deterministic RGBA output" {
  let pixmap = Pixmap::new(1, 1)
  pixmap.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=255))
  match pixmap.to_png_bytes() {
    Ok(png) => assert_eq(png, Bytes::from_array(make_pixmap_test_red_png()))
    Err(_) => abort("expected PNG encode")
  }
}

///|
test "Pixmap::to_png_bytes rejects empty dimensions" {
  match Pixmap::new(0, 0).to_png_bytes() {
    Err(PixmapEncodeError::InvalidPngDimensions(0, 0)) => ()
    _ => abort("expected PNG dimensions error")
  }
}

///|
test "Pixmap::from_png_bytes decodes exported RGBA PNG bytes" {
  let pixmap = Pixmap::new(2, 2)
  pixmap.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=255))
  pixmap.set_pixel(1, 0, Color::new(r=0, g=255, b=0, a=128))
  pixmap.set_pixel(0, 1, Color::new(r=0, g=0, b=255, a=64))
  pixmap.set_pixel(1, 1, Color::new(r=10, g=20, b=30, a=40))

  match pixmap.to_png_bytes() {
    Ok(png) =>
      match Pixmap::from_png_bytes(png) {
        Ok(decoded) => {
          assert_eq(decoded.get_width(), 2)
          assert_eq(decoded.get_height(), 2)
          assert_eq(decoded.to_rgba_bytes(), pixmap.to_rgba_bytes())
        }
        Err(_) => abort("expected PNG decode")
      }
    Err(_) => abort("expected PNG encode")
  }
}

///|
test "Pixmap::from_png_bytes decodes RGBA scanline filters" {
  let png = make_pixmap_test_rgba_png_from_scanlines(2, 5, [
    0, 10, 20, 30, 40, 50, 60, 70, 80, 1, 1, 2, 3, 4, 5, 6, 7, 8, 2, 2, 3, 4, 5,
    4, 5, 6, 7, 3, 19, 18, 17, 16, 45, 44, 42, 41, 4, 5, 6, 7, 8, 10, 11, 12, 13,
  ])
  let expected = Pixmap::new(2, 5)
  expected.set_pixel(0, 0, Color::new(r=10, g=20, b=30, a=40))
  expected.set_pixel(1, 0, Color::new(r=50, g=60, b=70, a=80))
  expected.set_pixel(0, 1, Color::new(r=1, g=2, b=3, a=4))
  expected.set_pixel(1, 1, Color::new(r=6, g=8, b=10, a=12))
  expected.set_pixel(0, 2, Color::new(r=3, g=5, b=7, a=9))
  expected.set_pixel(1, 2, Color::new(r=10, g=13, b=16, a=19))
  expected.set_pixel(0, 3, Color::new(r=20, g=20, b=20, a=20))
  expected.set_pixel(1, 3, Color::new(r=60, g=60, b=60, a=60))
  expected.set_pixel(0, 4, Color::new(r=25, g=26, b=27, a=28))
  expected.set_pixel(1, 4, Color::new(r=70, g=71, b=72, a=73))

  match Pixmap::from_png_bytes(png) {
    Ok(decoded) => assert_eq(decoded.to_rgba_bytes(), expected.to_rgba_bytes())
    Err(_) => abort("expected filtered PNG decode")
  }
}

///|
test "Pixmap::from_png_bytes decodes fixed Huffman DEFLATE data" {
  let png = make_pixmap_test_rgba_png_from_zlib_stream(2, 2, [
    120, 1, 99, 248, 207, 192, 240, 31, 8, 27, 24, 128, 180, 3, 151, 136, 156, 6,
    0, 55, 233, 5, 33,
  ])
  let expected = Pixmap::new(2, 2)
  expected.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=255))
  expected.set_pixel(1, 0, Color::new(r=0, g=255, b=0, a=128))
  expected.set_pixel(0, 1, Color::new(r=0, g=0, b=255, a=64))
  expected.set_pixel(1, 1, Color::new(r=10, g=20, b=30, a=40))

  match Pixmap::from_png_bytes(png) {
    Ok(decoded) => assert_eq(decoded.to_rgba_bytes(), expected.to_rgba_bytes())
    Err(_) => abort("expected fixed-Huffman PNG decode")
  }
}

///|
test "Pixmap::from_png_bytes decodes dynamic Huffman DEFLATE data" {
  let png = make_pixmap_test_rgba_png_from_zlib_stream(64, 8, [
    120, 218, 237, 208, 89, 66, 1, 80, 0, 0, 192, 103, 77, 246, 72, 73, 100, 41,
    75, 33, 89, 66, 164, 238, 127, 42, 230, 30, 222, 199, 92, 96, 66, 8, 225, 156,
    32, 73, 138, 52, 25, 178, 220, 144, 227, 150, 60, 5, 138, 148, 40, 83, 161, 202,
    29, 53, 234, 220, 211, 224, 129, 71, 154, 60, 209, 226, 153, 54, 29, 94, 232,
    210, 163, 207, 128, 87, 222, 24, 50, 98, 204, 132, 119, 62, 152, 50, 99, 206,
    39, 11, 190, 88, 178, 98, 205, 134, 111, 182, 236, 216, 243, 195, 129, 35, 191,
    156, 248, 227, 159, 16, 3, 98, 64, 12, 136, 1, 49, 32, 6, 92, 111, 192, 5, 57,
    152, 61, 31,
  ])
  let expected = Pixmap::new(64, 8)
  for y in 0..<8 {
    for x in 0..<64 {
      expected.set_pixel(x, y, Color::new(r=x.to_byte(), g=0, b=0, a=255))
    }
  }

  match Pixmap::from_png_bytes(png) {
    Ok(decoded) => assert_eq(decoded.to_rgba_bytes(), expected.to_rgba_bytes())
    Err(_) => abort("expected dynamic-Huffman PNG decode")
  }
}

///|
test "Pixmap::from_png_bytes reports structural errors" {
  match Pixmap::from_png_bytes(Bytes::from_array([137, 80])) {
    Err(PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected short PNG error")
  }

  let bad_signature = make_pixmap_test_red_png()
  bad_signature[0] = 0
  match Pixmap::from_png_bytes(Bytes::from_array(bad_signature)) {
    Err(PixmapDecodeError::InvalidPngSignature) => ()
    _ => abort("expected PNG signature error")
  }

  let bad_crc = make_pixmap_test_red_png()
  bad_crc[32] = 0
  match Pixmap::from_png_bytes(Bytes::from_array(bad_crc)) {
    Err(PixmapDecodeError::PngCrcMismatch(0x1F15C400, 0x1F15C489)) => ()
    _ => abort("expected PNG CRC mismatch")
  }

  let bad_filter = make_pixmap_test_rgba_png_from_scanlines(1, 1, [
    5, 0, 0, 0, 0,
  ])
  match Pixmap::from_png_bytes(bad_filter) {
    Err(PixmapDecodeError::UnsupportedPngFilterType(5)) => ()
    _ => abort("expected PNG filter type error")
  }
}

///|
test "Pixmap::from_bmp_bytes decodes exported 32-bit BMP bytes" {
  let pixmap = Pixmap::new(2, 2)
  pixmap.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=255))
  pixmap.set_pixel(1, 0, Color::new(r=0, g=255, b=0, a=128))
  pixmap.set_pixel(0, 1, Color::new(r=0, g=0, b=255, a=64))
  pixmap.set_pixel(1, 1, Color::new(r=10, g=20, b=30, a=40))

  match Pixmap::from_bmp_bytes(pixmap.to_bmp_bytes()) {
    Ok(decoded) => {
      assert_eq(decoded.get_width(), 2)
      assert_eq(decoded.get_height(), 2)
      assert_eq(decoded.to_rgba_bytes(), pixmap.to_rgba_bytes())
    }
    Err(_) => abort("expected BMP decode to succeed")
  }
}

///|
test "Pixmap::from_bmp_bytes accepts top-down BMP row order" {
  let top_down_bmp : Array[Byte] = [
    66, 77, 62, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 254, 255,
    255, 255, 1, 0, 32, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 7, 8, 9, 6, 3, 2, 1, 4,
  ]

  match Pixmap::from_bmp_bytes(Bytes::from_array(top_down_bmp)) {
    Ok(decoded) => {
      assert_eq(decoded.get_width(), 1)
      assert_eq(decoded.get_height(), 2)
      assert_eq(decoded.get_pixel(0, 0), Color::new(r=9, g=8, b=7, a=6))
      assert_eq(decoded.get_pixel(0, 1), Color::new(r=1, g=2, b=3, a=4))
    }
    Err(_) => abort("expected top-down BMP decode")
  }
}

///|
test "Pixmap::from_bmp_bytes decodes padded 24-bit BMP rows" {
  let bmp : Array[Byte] = [
    66, 77, 70, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 2, 0, 0, 0, 2, 0,
    0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 255, 0, 0, 255, 255, 255, 12, 34, 0, 0, 255, 0, 255, 0, 56, 78,
  ]

  match Pixmap::from_bmp_bytes(Bytes::from_array(bmp)) {
    Ok(decoded) => {
      assert_eq(decoded.get_width(), 2)
      assert_eq(decoded.get_height(), 2)
      assert_eq(decoded.get_pixel(0, 0), Color::red())
      assert_eq(decoded.get_pixel(1, 0), Color::green())
      assert_eq(decoded.get_pixel(0, 1), Color::blue())
      assert_eq(decoded.get_pixel(1, 1), Color::white())
    }
    Err(_) => abort("expected padded 24-bit BMP decode")
  }
}

///|
test "Pixmap::from_bmp_bytes reports structural errors" {
  match Pixmap::from_bmp_bytes(Bytes::from_array([66, 77])) {
    Err(PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected BMP short-data error")
  }

  let bad_signature : Array[Byte] = [
    0, 0, 54, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0,
  ]
  match Pixmap::from_bmp_bytes(Bytes::from_array(bad_signature)) {
    Err(PixmapDecodeError::InvalidBmpSignature(0, 0)) => ()
    _ => abort("expected BMP signature error")
  }

  let unsupported_bpp : Array[Byte] = [
    66, 77, 54, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 1, 0,
    0, 0, 1, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
  ]
  match Pixmap::from_bmp_bytes(Bytes::from_array(unsupported_bpp)) {
    Err(PixmapDecodeError::UnsupportedBmpBitsPerPixel(16)) => ()
    _ => abort("expected BMP bits-per-pixel error")
  }

  let truncated_pixels : Array[Byte] = [
    66, 77, 54, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 1, 0,
    0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
  ]
  match Pixmap::from_bmp_bytes(Bytes::from_array(truncated_pixels)) {
    Err(PixmapDecodeError::BmpPixelDataOutOfBounds(54, 58, 54)) => ()
    _ => abort("expected BMP pixel-data bounds error")
  }
}

///|
fn make_pixmap_test_rgba_png_from_scanlines(
  width : Int,
  height : Int,
  scanlines : Array[Byte],
) -> Bytes {
  make_pixmap_test_rgba_png_from_zlib_stream(
    width,
    height,
    pixmap_test_png_zlib_stored_stream(scanlines),
  )
}

///|
fn make_pixmap_test_rgba_png_from_zlib_stream(
  width : Int,
  height : Int,
  zlib_stream : Array[Byte],
) -> Bytes {
  let out : Array[Byte] = []
  append_pixmap_test_png_bytes(out, [137, 80, 78, 71, 13, 10, 26, 10])
  let ihdr : Array[Byte] = []
  append_pixmap_test_png_u32_be(ihdr, width.reinterpret_as_uint())
  append_pixmap_test_png_u32_be(ihdr, height.reinterpret_as_uint())
  ihdr.push(8)
  ihdr.push(6)
  ihdr.push(0)
  ihdr.push(0)
  ihdr.push(0)
  append_pixmap_test_png_chunk(out, [73, 72, 68, 82], ihdr)
  append_pixmap_test_png_chunk(out, [73, 68, 65, 84], zlib_stream)
  append_pixmap_test_png_chunk(out, [73, 69, 78, 68], [])
  Bytes::from_array(out)
}

///|
fn append_pixmap_test_png_chunk(
  out : Array[Byte],
  chunk_type : Array[Byte],
  data : Array[Byte],
) -> Unit {
  append_pixmap_test_png_u32_be(out, data.length().reinterpret_as_uint())
  append_pixmap_test_png_bytes(out, chunk_type)
  append_pixmap_test_png_bytes(out, data)
  append_pixmap_test_png_u32_be(
    out,
    pixmap_test_png_crc32_chunk(chunk_type, data),
  )
}

///|
fn append_pixmap_test_png_bytes(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn append_pixmap_test_png_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value >> 8).land(0xFF).to_byte())
}

///|
fn append_pixmap_test_png_u32_be(out : Array[Byte], value : UInt) -> Unit {
  out.push((value >> 24).to_byte())
  out.push((value >> 16).to_byte())
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
fn pixmap_test_png_zlib_stored_stream(data : Array[Byte]) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(0x78)
  out.push(0x01)
  out.push(1)
  append_pixmap_test_png_u16_le(out, data.length())
  append_pixmap_test_png_u16_le(out, 0xFFFF - data.length())
  append_pixmap_test_png_bytes(out, data)
  append_pixmap_test_png_u32_be(out, pixmap_test_png_adler32(data))
  out
}

///|
fn pixmap_test_png_adler32(data : Array[Byte]) -> UInt {
  let mod_adler = 65521
  let mut s1 = 1
  let mut s2 = 0
  for byte in data {
    s1 = (s1 + byte.to_int()) % mod_adler
    s2 = (s2 + s1) % mod_adler
  }
  (s2.reinterpret_as_uint() << 16) | s1.reinterpret_as_uint()
}

///|
fn pixmap_test_png_crc32_chunk(
  chunk_type : Array[Byte],
  data : Array[Byte],
) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for byte in chunk_type {
    crc = pixmap_test_png_crc32_update(crc, byte)
  }
  for byte in data {
    crc = pixmap_test_png_crc32_update(crc, byte)
  }
  crc ^ 0xFFFFFFFF
}

///|
fn pixmap_test_png_crc32_update(crc : UInt, byte : Byte) -> UInt {
  let mut c = crc ^ byte.to_uint()
  for _ in 0..<8 {
    c = if (c & 1) != 0 { (c >> 1) ^ 0xEDB88320 } else { c >> 1 }
  }
  c
}

///|
fn make_pixmap_test_red_png() -> Array[Byte] {
  [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0,
    0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 16, 73, 68, 65, 84, 120, 1,
    1, 5, 0, 250, 255, 0, 255, 0, 0, 255, 5, 0, 1, 255, 250, 92, 136, 209, 0, 0,
    0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]
}
