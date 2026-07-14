///|
fn byte_array_to_bytes(arr : Array[Byte]) -> Bytes {
  let out = FixedArray::make(arr.length(), b'\x00')
  for i in 0..<arr.length() {
    out[i] = arr[i]
  }
  Bytes::from_array(out)
}

///|
fn read_u16le_at_for_test(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() & 0xFF) | ((data[pos + 1].to_int() & 0xFF) << 8)
}

///|
priv struct GifTestBitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bits_count : Int
}

///|
fn GifTestBitReader::new(data : Bytes) -> GifTestBitReader {
  { data, pos: 0, bit_buf: 0, bits_count: 0 }
}

///|
fn GifTestBitReader::read_bits(self : GifTestBitReader, count : Int) -> Int? {
  while self.bits_count < count {
    if self.pos >= self.data.length() {
      return None
    }
    self.bit_buf = self.bit_buf |
      ((self.data[self.pos].to_int() & 0xFF) << self.bits_count)
    self.bits_count += 8
    self.pos += 1
  }
  let value = self.bit_buf & ((1 << count) - 1)
  self.bit_buf = self.bit_buf >> count
  self.bits_count -= count
  Some(value)
}

///|
fn decode_gif_lzw_for_test(
  data : Bytes,
  min_code_size : Int,
  expected_count : Int,
) -> Array[Int] {
  let clear = 1 << min_code_size
  let eoi = clear + 1
  let prefixes = FixedArray::make(4096, -1)
  let suffixes = FixedArray::make(4096, 0)
  let stack = FixedArray::make(4096, 0)
  let reader = GifTestBitReader::new(data)
  let output : Array[Int] = []

  let mut code_size = min_code_size + 1
  let mut next_code = eoi + 1
  let mut prev_code = -1
  let mut first_value = 0

  while output.length() < expected_count {
    let code = match reader.read_bits(code_size) {
      Some(value) => value
      None => break
    }
    if code == clear {
      code_size = min_code_size + 1
      next_code = eoi + 1
      prev_code = -1
      continue
    }
    if code == eoi {
      break
    }

    let mut current = code
    let mut stack_len = 0
    if code == next_code && prev_code >= 0 {
      stack[stack_len] = first_value
      stack_len += 1
      current = prev_code
    }
    while current >= clear {
      stack[stack_len] = suffixes[current]
      stack_len += 1
      current = prefixes[current]
    }
    first_value = current
    stack[stack_len] = current
    stack_len += 1
    for i in 0..<stack_len {
      output.push(stack[stack_len - 1 - i])
    }

    if prev_code >= 0 && next_code < 4096 {
      prefixes[next_code] = prev_code
      suffixes[next_code] = first_value
      next_code += 1
      if next_code == 1 << code_size && code_size < 12 {
        code_size += 1
      }
    }
    prev_code = code
  }
  output
}

///|
fn collect_gif_sub_blocks_for_test(data : Bytes, pos : Int) -> (Bytes, Int) {
  let out : Array[Byte] = []
  let mut cursor = pos
  while true {
    let block_len = data[cursor].to_int() & 0xFF
    cursor += 1
    if block_len == 0 {
      break
    }
    for i in 0..<block_len {
      out.push(data[cursor + i])
    }
    cursor += block_len
  }
  (byte_array_to_bytes(out), cursor)
}

///|
fn decode_gif_for_test(data : Bytes) -> ImageData raise {
  assert_true(data.length() >= 20)
  assert_eq(data[0].to_int(), 0x47)
  assert_eq(data[1].to_int(), 0x49)
  assert_eq(data[2].to_int(), 0x46)
  assert_eq(data[3].to_int(), 0x38)
  let width = read_u16le_at_for_test(data, 6)
  let height = read_u16le_at_for_test(data, 8)
  let packed = data[10].to_int() & 0xFF
  assert_true((packed & 0x80) != 0)
  let color_table_size = 1 << ((packed & 0x07) + 1)
  let palette_offset = 13
  let palette = FixedArray::make(color_table_size * 3, b'\x00')
  for i in 0..<(color_table_size * 3) {
    palette[i] = data[palette_offset + i]
  }

  let mut pos = palette_offset + color_table_size * 3
  let mut transparent_index : Int? = None
  if data[pos].to_int() == 0x21 && data[pos + 1].to_int() == 0xF9 {
    assert_eq(data[pos + 2].to_int(), 0x04)
    let gce_packed = data[pos + 3].to_int() & 0xFF
    if (gce_packed & 0x01) != 0 {
      transparent_index = Some(data[pos + 6].to_int() & 0xFF)
    }
    assert_eq(data[pos + 7].to_int(), 0x00)
    pos += 8
  }

  assert_eq(data[pos].to_int(), 0x2C)
  assert_eq(read_u16le_at_for_test(data, pos + 1), 0)
  assert_eq(read_u16le_at_for_test(data, pos + 3), 0)
  assert_eq(read_u16le_at_for_test(data, pos + 5), width)
  assert_eq(read_u16le_at_for_test(data, pos + 7), height)
  assert_eq(data[pos + 9].to_int(), 0x00)
  let min_code_size = data[pos + 10].to_int() & 0xFF
  let (image_data, after_blocks) = collect_gif_sub_blocks_for_test(
    data,
    pos + 11,
  )
  assert_eq(data[after_blocks].to_int(), 0x3B)

  let indices = decode_gif_lzw_for_test(
    image_data,
    min_code_size,
    width * height,
  )
  assert_eq(indices.length(), width * height)

  let rgba = FixedArray::make(width * height * 4, b'\x00')
  for i in 0..<indices.length() {
    let idx = indices[i]
    let out = i * 4
    match transparent_index {
      Some(ti) if idx == ti => ()
      _ => {
        rgba[out] = palette[idx * 3]
        rgba[out + 1] = palette[idx * 3 + 1]
        rgba[out + 2] = palette[idx * 3 + 2]
        rgba[out + 3] = b'\xFF'
      }
    }
  }
  { width, height, data: Bytes::from_array(rgba) }
}

///|
fn make_palette_test_image() -> ImageData {
  let width = 4
  let height = 2
  let data = b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\x00\x00\xFF\x00\xFF\x00\xFF"
  { width, height, data }
}

///|
fn make_transparent_test_image() -> ImageData {
  let width = 2
  let height = 2
  let data = b"\xFF\x00\x00\xFF\x00\x00\x00\x00\x00\xFF\x00\xFF\x00\x00\x00\x00"
  { width, height, data }
}

///|
test "gif_encode basic signature and trailer" {
  let img : ImageData = { width: 1, height: 1, data: b"\xAA\xBB\xCC\xFF" }
  let gif = encode_gif(img)
  assert_eq(gif[0].to_int(), 0x47)
  assert_eq(gif[1].to_int(), 0x49)
  assert_eq(gif[2].to_int(), 0x46)
  assert_eq(gif[3].to_int(), 0x38)
  assert_eq(gif[4].to_int(), 0x39)
  assert_eq(gif[5].to_int(), 0x61)
  assert_eq(gif[gif.length() - 1].to_int(), 0x3B)
}

///|
test "gif_encode palette roundtrip" {
  let original = make_palette_test_image()
  let gif = encode_gif(original)
  let decoded = decode_gif_for_test(gif)
  assert_eq(decoded, original)
}

///|
test "gif_encode transparent roundtrip" {
  let original = make_transparent_test_image()
  let gif = encode_gif(original)
  let decoded = decode_gif_for_test(gif)
  assert_eq(decoded, original)
}

///|
test "gif_encode invalid dimensions and data length" {
  let img_invalid_dim : ImageData = { width: 0, height: 1, data: Bytes::new(0) }
  let r1 : Result[Bytes, _] = try? encode_gif(img_invalid_dim)
  assert_true(r1 is Err(_))

  let img_invalid_data : ImageData = {
    width: 2,
    height: 2,
    data: Bytes::new(4),
  }
  let r2 : Result[Bytes, _] = try? encode_gif(img_invalid_data)
  assert_true(r2 is Err(_))
}

///|
test "gif_encode rejects partial alpha" {
  let img : ImageData = { width: 1, height: 1, data: b"\x10\x20\x30\x80" }
  let result : Result[Bytes, _] = try? encode_gif(img)
  assert_true(result is Err(_))
}

///|
test "gif_encode rejects more than 256 colors" {
  let width = 257
  let height = 1
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for i in 0..<width {
    let idx = i * 4
    buf[idx] = (i & 0xFF).to_byte()
    buf[idx + 1] = (i / 256).to_byte()
    buf[idx + 2] = b'\x00'
    buf[idx + 3] = b'\xFF'
  }
  let img : ImageData = { width, height, data: Bytes::from_array(buf) }
  let result : Result[Bytes, _] = try? encode_gif(img)
  assert_true(result is Err(_))
}
