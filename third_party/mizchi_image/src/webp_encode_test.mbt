///|
let webp_test_code_length_code_order : FixedArray[Int] = [
  17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
]

///|
fn read_u32le_at_for_webp_test(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() & 0xFF) |
  ((data[pos + 1].to_int() & 0xFF) << 8) |
  ((data[pos + 2].to_int() & 0xFF) << 16) |
  ((data[pos + 3].to_int() & 0xFF) << 24)
}

///|
fn webp_reverse_bits_for_test(value : Int, count : Int) -> Int {
  let mut out = 0
  let mut v = value
  for _ in 0..<count {
    out = (out << 1) | (v & 1)
    v = v >> 1
  }
  out
}

///|
fn webp_pack_argb_for_test(r : Int, g : Int, b : Int, a : Int) -> Int {
  (a << 24) | (r << 16) | (g << 8) | b
}

///|
fn webp_color_cache_index_for_test(color : Int, bits : Int) -> Int {
  let hash = (color * 0x1E35A7BD) >> (32 - bits)
  hash & ((1 << bits) - 1)
}

///|
priv struct WebPTestPrefixCode {
  lengths : FixedArray[Int]
  codes : FixedArray[Int]
  single_symbol : Int?
}

///|
fn webp_test_prefix_code_from_lengths(
  lengths : FixedArray[Int],
) -> WebPTestPrefixCode {
  let codes = FixedArray::make(lengths.length(), 0)
  let mut used_count = 0
  let mut single_symbol = -1
  let mut max_len = 0
  for symbol in 0..<lengths.length() {
    let len = lengths[symbol]
    if len > 0 {
      used_count += 1
      single_symbol = symbol
      if len > max_len {
        max_len = len
      }
    }
  }
  if used_count <= 1 {
    return {
      lengths,
      codes,
      single_symbol: Some(if single_symbol >= 0 { single_symbol } else { 0 }),
    }
  }

  let bl_count = FixedArray::make(max_len + 1, 0)
  for symbol in 0..<lengths.length() {
    let len = lengths[symbol]
    if len > 0 {
      bl_count[len] += 1
    }
  }
  let next_code = FixedArray::make(max_len + 1, 0)
  let mut code = 0
  for bits in 1..<=max_len {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  for symbol in 0..<lengths.length() {
    let len = lengths[symbol]
    if len > 0 {
      codes[symbol] = webp_reverse_bits_for_test(next_code[len], len)
      next_code[len] += 1
    }
  }
  { lengths, codes, single_symbol: None }
}

///|
priv struct WebPTestBitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bits_count : Int
}

///|
fn WebPTestBitReader::new(data : Bytes, pos : Int) -> WebPTestBitReader {
  { data, pos, bit_buf: 0, bits_count: 0 }
}

///|
fn WebPTestBitReader::read_bits(
  self : WebPTestBitReader,
  count : Int,
) -> Int raise {
  while self.bits_count < count {
    assert_true(self.pos < self.data.length())
    self.bit_buf = self.bit_buf |
      ((self.data[self.pos].to_int() & 0xFF) << self.bits_count)
    self.bits_count += 8
    self.pos += 1
  }
  let value = self.bit_buf & ((1 << count) - 1)
  self.bit_buf = self.bit_buf >> count
  self.bits_count -= count
  value
}

///|
fn decode_webp_symbol_for_test(
  br : WebPTestBitReader,
  prefix : WebPTestPrefixCode,
) -> Int raise {
  match prefix.single_symbol {
    Some(symbol) => symbol
    None => {
      let mut code = 0
      let mut max_len = 0
      for len in prefix.lengths {
        if len > max_len {
          max_len = len
        }
      }
      for len in 1..<=max_len {
        code = code | (br.read_bits(1) << (len - 1))
        for symbol in 0..<prefix.lengths.length() {
          if prefix.lengths[symbol] == len && prefix.codes[symbol] == code {
            return symbol
          }
        }
      }
      panic()
    }
  }
}

///|
fn decode_prefix_code_for_webp_test(
  br : WebPTestBitReader,
  alphabet_size : Int,
) -> WebPTestPrefixCode raise {
  let is_simple = br.read_bits(1)
  let lengths = FixedArray::make(alphabet_size, 0)
  if is_simple == 1 {
    let num_symbols = br.read_bits(1) + 1
    let is_first_8bits = br.read_bits(1)
    let symbol0 = br.read_bits(1 + 7 * is_first_8bits)
    lengths[symbol0] = 1
    if num_symbols == 2 {
      let symbol1 = br.read_bits(8)
      lengths[symbol1] = 1
    }
    return webp_test_prefix_code_from_lengths(lengths)
  }

  let code_length_code_lengths = FixedArray::make(19, 0)
  let num_code_lengths = 4 + br.read_bits(4)
  for i in 0..<num_code_lengths {
    code_length_code_lengths[webp_test_code_length_code_order[i]] = br.read_bits(
      3,
    )
  }
  let code_length_prefix = webp_test_prefix_code_from_lengths(
    code_length_code_lengths,
  )
  let use_default_max_symbol = br.read_bits(1) == 0
  let max_symbol = if use_default_max_symbol {
    alphabet_size
  } else {
    let length_nbits = 2 + 2 * br.read_bits(3)
    2 + br.read_bits(length_nbits)
  }
  for i in 0..<max_symbol {
    let token = decode_webp_symbol_for_test(br, code_length_prefix)
    assert_true(token <= 15)
    lengths[i] = token
  }
  webp_test_prefix_code_from_lengths(lengths)
}

///|
fn decode_webp_for_test_impl(data : Bytes) -> (ImageData, Bool, Int) raise {
  assert_true(data.length() >= 21)
  assert_eq(data[0].to_int(), 0x52)
  assert_eq(data[1].to_int(), 0x49)
  assert_eq(data[2].to_int(), 0x46)
  assert_eq(data[3].to_int(), 0x46)
  let file_size = read_u32le_at_for_webp_test(data, 4)
  assert_eq(file_size, data.length() - 8)
  assert_eq(data[8].to_int(), 0x57)
  assert_eq(data[9].to_int(), 0x45)
  assert_eq(data[10].to_int(), 0x42)
  assert_eq(data[11].to_int(), 0x50)
  assert_eq(data[12].to_int(), 0x56)
  assert_eq(data[13].to_int(), 0x50)
  assert_eq(data[14].to_int(), 0x38)
  assert_eq(data[15].to_int(), 0x4C)
  let chunk_size = read_u32le_at_for_webp_test(data, 16)
  let payload_start = 20
  let payload_end = payload_start + chunk_size
  assert_true(payload_end <= data.length())

  let br = WebPTestBitReader::new(data, payload_start)
  assert_eq(br.read_bits(8), 0x2F)
  let width = br.read_bits(14) + 1
  let height = br.read_bits(14) + 1
  ignore(br.read_bits(1))
  assert_eq(br.read_bits(3), 0)
  let mut subtract_green = false
  while br.read_bits(1) == 1 {
    let transform_type = br.read_bits(2)
    match transform_type {
      2 => subtract_green = true
      _ => panic()
    }
  }
  let color_cache_bits = if br.read_bits(1) == 1 { br.read_bits(4) } else { 0 }
  assert_eq(br.read_bits(1), 0) // single prefix group

  let green_alphabet_size = 256 +
    24 +
    (if color_cache_bits > 0 { 1 << color_cache_bits } else { 0 })
  let green_prefix = decode_prefix_code_for_webp_test(br, green_alphabet_size)
  let red_prefix = decode_prefix_code_for_webp_test(br, 256)
  let blue_prefix = decode_prefix_code_for_webp_test(br, 256)
  let alpha_prefix = decode_prefix_code_for_webp_test(br, 256)
  ignore(decode_prefix_code_for_webp_test(br, 40))

  let rgba = FixedArray::make(width * height * 4, b'\x00')
  let color_cache = FixedArray::make(
    if color_cache_bits > 0 {
      1 << color_cache_bits
    } else {
      0
    },
    0,
  )
  let color_cache_valid = FixedArray::make(
    if color_cache_bits > 0 {
      1 << color_cache_bits
    } else {
      0
    },
    0,
  )
  for i in 0..<(width * height) {
    let green_or_op = decode_webp_symbol_for_test(br, green_prefix)
    let offset = i * 4
    let encoded_pixel = if green_or_op < 256 {
      let green = green_or_op
      let enc_red = decode_webp_symbol_for_test(br, red_prefix)
      let enc_blue = decode_webp_symbol_for_test(br, blue_prefix)
      let alpha = decode_webp_symbol_for_test(br, alpha_prefix)
      (enc_red, green, enc_blue, alpha)
    } else if green_or_op >= 280 && color_cache_bits > 0 {
      let cache_idx = green_or_op - 280
      assert_eq(color_cache_valid[cache_idx], 1)
      let color = color_cache[cache_idx]
      let alpha = (color >> 24) & 0xFF
      let red = (color >> 16) & 0xFF
      let green = (color >> 8) & 0xFF
      let blue = color & 0xFF
      (red, green, blue, alpha)
    } else {
      panic()
    }
    let enc_red = encoded_pixel.0
    let green = encoded_pixel.1
    let enc_blue = encoded_pixel.2
    let alpha = encoded_pixel.3
    let red = if subtract_green { (enc_red + green) & 0xFF } else { enc_red }
    let blue = if subtract_green { (enc_blue + green) & 0xFF } else { enc_blue }
    rgba[offset] = red.to_byte()
    rgba[offset + 1] = green.to_byte()
    rgba[offset + 2] = blue.to_byte()
    rgba[offset + 3] = alpha.to_byte()
    if color_cache_bits > 0 {
      let color = webp_pack_argb_for_test(enc_red, green, enc_blue, alpha)
      let cache_idx = webp_color_cache_index_for_test(color, color_cache_bits)
      color_cache[cache_idx] = color
      color_cache_valid[cache_idx] = 1
    }
  }
  assert_true(br.pos <= payload_end)
  if chunk_size % 2 == 1 {
    assert_eq(data[payload_end].to_int(), 0)
  }
  (
    { width, height, data: Bytes::from_array(rgba) },
    subtract_green,
    color_cache_bits,
  )
}

///|
fn decode_webp_for_test(data : Bytes) -> ImageData raise {
  let (image, _, _) = decode_webp_for_test_impl(data)
  image
}

///|
fn make_webp_test_image() -> ImageData {
  let width = 3
  let height = 2
  let data = b"\xFF\x00\x00\xFF\x00\x80\xFF\xFF\x10\x20\x30\x40\x11\x22\x33\x44\xFE\xDC\xBA\x98\x01\x02\x03\x00"
  { width, height, data }
}

///|
fn make_webp_solid_image(
  width : Int,
  height : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> ImageData {
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for i in 0..<(width * height) {
    let offset = i * 4
    buf[offset] = r.to_byte()
    buf[offset + 1] = g.to_byte()
    buf[offset + 2] = b.to_byte()
    buf[offset + 3] = a.to_byte()
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
fn make_webp_subtract_green_test_image() -> ImageData {
  let width = 4
  let height = 1
  let data = b"\x0B\x0A\x0C\xFF\x15\x14\x16\xFF\x1F\x1E\x20\xFF\x29\x28\x2A\xFF"
  { width, height, data }
}

///|
fn make_webp_color_cache_test_image() -> ImageData {
  let width = 32
  let height = 32
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let offset = (y * width + x) * 4
      let tile = x % 2 + y % 2 * 2
      match tile {
        0 => {
          buf[offset] = b'\x10'
          buf[offset + 1] = b'\x20'
          buf[offset + 2] = b'\x30'
        }
        1 => {
          buf[offset] = b'\x90'
          buf[offset + 1] = b'\x10'
          buf[offset + 2] = b'\xB0'
        }
        2 => {
          buf[offset] = b'\x12'
          buf[offset + 1] = b'\x34'
          buf[offset + 2] = b'\xF0'
        }
        _ => {
          buf[offset] = b'\xBA'
          buf[offset + 1] = b'\xDA'
          buf[offset + 2] = b'\x55'
        }
      }
      buf[offset + 3] = b'\xFF'
    }
  }
  { width, height, data: Bytes::from_array(buf) }
}

///|
test "webp_encode basic signature" {
  let img : ImageData = { width: 1, height: 1, data: b"\xAA\xBB\xCC\xDD" }
  let webp = encode_webp(img)
  assert_eq(webp[0].to_int(), 0x52)
  assert_eq(webp[1].to_int(), 0x49)
  assert_eq(webp[2].to_int(), 0x46)
  assert_eq(webp[3].to_int(), 0x46)
  assert_eq(webp[8].to_int(), 0x57)
  assert_eq(webp[9].to_int(), 0x45)
  assert_eq(webp[10].to_int(), 0x42)
  assert_eq(webp[11].to_int(), 0x50)
  assert_eq(webp[12].to_int(), 0x56)
  assert_eq(webp[13].to_int(), 0x50)
  assert_eq(webp[14].to_int(), 0x38)
  assert_eq(webp[15].to_int(), 0x4C)
}

///|
test "webp_encode restricted roundtrip" {
  let original = make_webp_test_image()
  let webp = encode_webp(original)
  let decoded = decode_webp_for_test(webp)
  assert_eq(decoded, original)
}

///|
test "webp_encode optimizes solid image size" {
  let img = make_webp_solid_image(16, 16, 0x80, 0x80, 0x80, 0xFF)
  let webp = encode_webp(img)
  assert_true(webp.length() < 128)
}

///|
test "webp_encode uses subtract-green transform when beneficial" {
  let img = make_webp_subtract_green_test_image()
  let webp = encode_webp(img)
  let (decoded, uses_subtract_green, _) = decode_webp_for_test_impl(webp)
  assert_true(uses_subtract_green)
  assert_eq(decoded, img)
}

///|
test "webp_encode uses color cache when beneficial" {
  let img = make_webp_color_cache_test_image()
  let webp = encode_webp(img)
  let (decoded, _, color_cache_bits) = decode_webp_for_test_impl(webp)
  assert_true(color_cache_bits > 0)
  assert_true(webp.length() < 512)
  assert_eq(decoded, img)
}

///|
test "webp_encode preserves transparent rgb" {
  let img : ImageData = {
    width: 2,
    height: 1,
    data: b"\x10\x20\x30\x00\xAA\xBB\xCC\xFF",
  }
  let webp = encode_webp(img)
  let decoded = decode_webp_for_test(webp)
  assert_eq(decoded, img)
}

///|
test "webp_encode invalid dimensions and data length" {
  let img_invalid_dim : ImageData = { width: 0, height: 1, data: Bytes::new(0) }
  let r1 : Result[Bytes, _] = try? encode_webp(img_invalid_dim)
  assert_true(r1 is Err(_))

  let img_invalid_data : ImageData = {
    width: 2,
    height: 2,
    data: Bytes::new(4),
  }
  let r2 : Result[Bytes, _] = try? encode_webp(img_invalid_data)
  assert_true(r2 is Err(_))
}
