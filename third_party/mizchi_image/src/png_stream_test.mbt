///|
fn make_stream_test_image(width : Int, height : Int) -> ImageData {
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
fn concat_rows(rows : Array[Bytes], width : Int, height : Int) -> Bytes raise {
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
test "decode_png_stream rows match decode_png" {
  let original = make_stream_test_image(8, 6)
  let png = encode_png(original)
  let rows : Array[Bytes] = []
  let ihdr = decode_png_stream(png, on_row=fn(_y, row) { rows.push(row) })
  assert_eq(ihdr.width, 8)
  assert_eq(ihdr.height, 6)
  assert_eq(rows.length(), 6)

  let stream_data = concat_rows(rows, 8, 6)
  let decoded = decode_png(png)
  assert_eq(decoded.width, 8)
  assert_eq(decoded.height, 6)
  assert_eq(stream_data, decoded.data)
}

///|
test "decode_png_stream invalid signature" {
  let r : Result[IhdrData, _] = try? decode_png_stream(b"\x00\x00\x00\x00", on_row=fn(
    _,
    _,
  ) {

  })
  assert_true(r is Err(_))
}
