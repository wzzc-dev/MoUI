///|
fn make_bmp_stream_test_image(width : Int, height : Int) -> ImageData {
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      buf[idx] = (x * 255 / (width - 1)).to_byte()
      buf[idx + 1] = (y * 255 / (height - 1)).to_byte()
      buf[idx + 2] = ((x + y) * 255 / (width + height - 2)).to_byte()
      buf[idx + 3] = b'\xFF'
    }
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
fn concat_bmp_rows(
  rows : Array[Bytes],
  width : Int,
  height : Int,
) -> Bytes raise {
  let total = width * height * 4
  let buf = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for row in rows {
    let row_len = width * 4
    assert_eq(row.length(), row_len)
    buf.blit_from_bytes(offset, row, 0, row_len)
    offset += row_len
  }
  assert_eq(offset, total)
  Bytes::from_array(buf)
}

///|
test "decode_bmp_stream rows match decode_bmp" {
  let original = make_bmp_stream_test_image(8, 6)
  let bmp = encode_bmp(original)
  let rows : Array[Bytes] = []
  let (width, height) = decode_bmp_stream(bmp, on_row=fn(_y, row) {
    rows.push(row)
  })
  assert_eq(width, 8)
  assert_eq(height, 6)
  assert_eq(rows.length(), 6)

  let stream_data = concat_bmp_rows(rows, 8, 6)
  let decoded = decode_bmp(bmp)
  assert_eq(stream_data, decoded.data)
}

///|
test "decode_bmp_stream top_down row order" {
  let buf = FixedArray::make(62, b'\x00')
  // File header
  buf[0] = b'\x42'
  buf[1] = b'\x4D'
  buf[2] = (62).to_byte()
  buf[10] = (54).to_byte()
  // DIB header
  buf[14] = (40).to_byte()
  buf[18] = (1).to_byte() // width = 1
  // height = -2 (top-down)
  buf[22] = b'\xFE'
  buf[23] = b'\xFF'
  buf[24] = b'\xFF'
  buf[25] = b'\xFF'
  buf[26] = (1).to_byte() // planes
  buf[28] = (32).to_byte() // bpp
  buf[34] = (8).to_byte() // image size
  // Top row: red (BGRA)
  buf[54] = b'\x00'
  buf[55] = b'\x00'
  buf[56] = b'\xFF'
  buf[57] = b'\xFF'
  // Bottom row: green (BGRA)
  buf[58] = b'\x00'
  buf[59] = b'\xFF'
  buf[60] = b'\x00'
  buf[61] = b'\xFF'

  let bmp = Bytes::from_array(buf)
  let rows : Array[Bytes] = []
  let (width, height) = decode_bmp_stream(bmp, on_row=fn(_y, row) {
    rows.push(row)
  })
  assert_eq(width, 1)
  assert_eq(height, 2)
  assert_eq(rows.length(), 2)

  // Row 0 should be top (red), row 1 bottom (green)
  assert_eq(rows[0], b"\xFF\x00\x00\xFF")
  assert_eq(rows[1], b"\x00\xFF\x00\xFF")
}

///|
test "decode_bmp_stream invalid signature" {
  let r : Result[(Int, Int), _] = try? decode_bmp_stream(b"\x00\x00\x00\x00", on_row=fn(
    _,
    _,
  ) {

  })
  assert_true(r is Err(_))
}
