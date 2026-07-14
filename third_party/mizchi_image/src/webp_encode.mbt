///|
let webp_code_length_code_order : FixedArray[Int] = [
  17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
]

///|
priv struct WebPBitWriter {
  buf : Array[Byte]
  mut bit_buf : Int
  mut bits_count : Int
}

///|
priv struct WebPPrefixCode {
  lengths : FixedArray[Int]
  codes : FixedArray[Int]
  single_symbol : Int?
}

///|
priv struct WebPEncodingPlan {
  subtract_green : Bool
  color_cache_bits : Int
  green_code : WebPPrefixCode
  red_code : WebPPrefixCode
  blue_code : WebPPrefixCode
  alpha_code : WebPPrefixCode
}

///|
fn WebPBitWriter::new() -> WebPBitWriter {
  { buf: [], bit_buf: 0, bits_count: 0 }
}

///|
fn WebPBitWriter::put_bits(
  self : WebPBitWriter,
  value : Int,
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  self.bit_buf = self.bit_buf |
    ((value & ((1 << count) - 1)) << self.bits_count)
  self.bits_count += count
  while self.bits_count >= 8 {
    self.buf.push((self.bit_buf & 0xFF).to_byte())
    self.bit_buf = self.bit_buf >> 8
    self.bits_count -= 8
  }
}

///|
fn WebPBitWriter::flush(self : WebPBitWriter) -> Unit {
  if self.bits_count > 0 {
    self.buf.push((self.bit_buf & 0xFF).to_byte())
    self.bit_buf = 0
    self.bits_count = 0
  }
}

///|
fn WebPBitWriter::to_bytes(self : WebPBitWriter) -> Bytes {
  let out = FixedArray::make(self.buf.length(), b'\x00')
  for i in 0..<self.buf.length() {
    out[i] = self.buf[i]
  }
  Bytes::from_array(out)
}

///|
fn webp_reverse_bits(value : Int, count : Int) -> Int {
  let mut out = 0
  let mut v = value
  for _ in 0..<count {
    out = (out << 1) | (v & 1)
    v = v >> 1
  }
  out
}

///|
fn webp_floor_log2(value : Int) -> Int {
  let mut v = value
  let mut out = -1
  while v > 0 {
    v = v >> 1
    out += 1
  }
  out
}

///|
fn webp_pack_argb(r : Int, g : Int, b : Int, a : Int) -> Int {
  (a << 24) | (r << 16) | (g << 8) | b
}

///|
fn webp_color_cache_index(color : Int, bits : Int) -> Int {
  let hash = (color * 0x1E35A7BD) >> (32 - bits)
  hash & ((1 << bits) - 1)
}

///|
fn webp_prefix_code_from_lengths(lengths : FixedArray[Int]) -> WebPPrefixCode {
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
      codes[symbol] = webp_reverse_bits(next_code[len], len)
      next_code[len] += 1
    }
  }
  { lengths, codes, single_symbol: None }
}

///|
fn webp_build_prefix_code(freqs : FixedArray[Int]) -> WebPPrefixCode {
  let lengths = FixedArray::make(freqs.length(), 0)
  let symbols : Array[(Int, Int)] = []
  for symbol in 0..<freqs.length() {
    let freq = freqs[symbol]
    if freq > 0 {
      symbols.push((symbol, freq))
    }
  }

  if symbols.is_empty() {
    lengths[0] = 1
    return webp_prefix_code_from_lengths(lengths)
  }
  if symbols.length() == 1 {
    lengths[symbols[0].0] = 1
    return webp_prefix_code_from_lengths(lengths)
  }

  symbols.sort_by(fn(a, b) {
    let freq_cmp = b.1 - a.1
    if freq_cmp != 0 {
      freq_cmp
    } else {
      a.0 - b.0
    }
  })
  let leaf_count = symbols.length()
  let short_len = webp_floor_log2(leaf_count)
  let short_count = (1 << (short_len + 1)) - leaf_count
  for i in 0..<leaf_count {
    let symbol = symbols[i].0
    lengths[symbol] = if i < short_count { short_len } else { short_len + 1 }
  }
  webp_prefix_code_from_lengths(lengths)
}

///|
fn webp_prefix_used_symbols(prefix : WebPPrefixCode) -> Array[Int] {
  let out : Array[Int] = []
  for symbol in 0..<prefix.lengths.length() {
    if prefix.lengths[symbol] > 0 {
      out.push(symbol)
    }
  }
  out
}

///|
fn webp_prefix_max_symbol(prefix : WebPPrefixCode) -> Int {
  let mut max_symbol = 1
  for symbol in 0..<prefix.lengths.length() {
    if prefix.lengths[symbol] > 0 {
      max_symbol = symbol + 1
    }
  }
  max_symbol
}

///|
fn webp_choose_length_nbits(max_symbol : Int) -> Int {
  if max_symbol <= 5 {
    2
  } else if max_symbol <= 17 {
    4
  } else if max_symbol <= 65 {
    6
  } else if max_symbol <= 257 {
    8
  } else if max_symbol <= 1025 {
    10
  } else if max_symbol <= 4097 {
    12
  } else if max_symbol <= 16385 {
    14
  } else {
    16
  }
}

///|
fn webp_write_symbol(
  bw : WebPBitWriter,
  prefix : WebPPrefixCode,
  symbol : Int,
) -> Unit {
  match prefix.single_symbol {
    Some(expected) => ignore(expected)
    None => bw.put_bits(prefix.codes[symbol], prefix.lengths[symbol])
  }
}

///|
fn encode_webp_simple_prefix_code(
  bw : WebPBitWriter,
  prefix : WebPPrefixCode,
) -> Unit {
  let symbols = webp_prefix_used_symbols(prefix)
  symbols.sort_by((a, b) => a - b)
  bw.put_bits(1, 1)
  bw.put_bits(symbols.length() - 1, 1)
  let first = symbols[0]
  if first <= 1 {
    bw.put_bits(0, 1)
    bw.put_bits(first, 1)
  } else {
    bw.put_bits(1, 1)
    bw.put_bits(first, 8)
  }
  if symbols.length() == 2 {
    bw.put_bits(symbols[1], 8)
  }
}

///|
fn encode_webp_normal_prefix_code(
  bw : WebPBitWriter,
  prefix : WebPPrefixCode,
) -> Unit {
  let max_symbol = webp_prefix_max_symbol(prefix)
  let token_freqs = FixedArray::make(19, 0)
  let tokens : Array[Int] = []
  for symbol in 0..<max_symbol {
    let token = prefix.lengths[symbol]
    tokens.push(token)
    token_freqs[token] += 1
  }
  let token_prefix = webp_build_prefix_code(token_freqs)

  bw.put_bits(0, 1)
  let mut num_code_lengths = 4
  for i in 0..<webp_code_length_code_order.length() {
    if token_prefix.lengths[webp_code_length_code_order[i]] > 0 {
      num_code_lengths = i + 1
    }
  }
  bw.put_bits(num_code_lengths - 4, 4)
  for i in 0..<num_code_lengths {
    bw.put_bits(token_prefix.lengths[webp_code_length_code_order[i]], 3)
  }

  bw.put_bits(1, 1)
  let length_nbits = webp_choose_length_nbits(max_symbol)
  bw.put_bits((length_nbits - 2) / 2, 3)
  bw.put_bits(max_symbol - 2, length_nbits)

  for token in tokens {
    webp_write_symbol(bw, token_prefix, token)
  }
}

///|
fn encode_webp_prefix_code(bw : WebPBitWriter, prefix : WebPPrefixCode) -> Unit {
  let used = webp_prefix_used_symbols(prefix)
  if used.length() <= 2 {
    encode_webp_simple_prefix_code(bw, prefix)
  } else {
    encode_webp_normal_prefix_code(bw, prefix)
  }
}

///|
fn webp_estimate_data_bits(
  freqs : FixedArray[Int],
  prefix : WebPPrefixCode,
) -> Int {
  match prefix.single_symbol {
    Some(_) => 0
    None => {
      let mut bits = 0
      for symbol in 0..<freqs.length() {
        let freq = freqs[symbol]
        if freq > 0 {
          bits += freq * prefix.lengths[symbol]
        }
      }
      bits
    }
  }
}

///|
fn webp_collect_channel_freqs(
  img : ImageData,
  subtract_green : Bool,
  color_cache_bits : Int,
) -> (FixedArray[Int], FixedArray[Int], FixedArray[Int], FixedArray[Int]) {
  let green_alphabet_size = if color_cache_bits > 0 {
    256 + 24 + (1 << color_cache_bits)
  } else {
    256
  }
  let green_freqs = FixedArray::make(green_alphabet_size, 0)
  let red_freqs = FixedArray::make(256, 0)
  let blue_freqs = FixedArray::make(256, 0)
  let alpha_freqs = FixedArray::make(256, 0)
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
  let pixel_count = img.width * img.height
  for i in 0..<pixel_count {
    let offset = i * 4
    let r = img.data[offset].to_int() & 0xFF
    let g = img.data[offset + 1].to_int() & 0xFF
    let b = img.data[offset + 2].to_int() & 0xFF
    let a = img.data[offset + 3].to_int() & 0xFF
    let enc_r = if subtract_green { (r - g) & 0xFF } else { r }
    let enc_b = if subtract_green { (b - g) & 0xFF } else { b }
    let color = webp_pack_argb(enc_r, g, enc_b, a)
    if color_cache_bits > 0 {
      let cache_idx = webp_color_cache_index(color, color_cache_bits)
      if color_cache_valid[cache_idx] == 1 && color_cache[cache_idx] == color {
        green_freqs[280 + cache_idx] += 1
      } else {
        green_freqs[g] += 1
        red_freqs[enc_r] += 1
        blue_freqs[enc_b] += 1
        alpha_freqs[a] += 1
      }
      color_cache[cache_idx] = color
      color_cache_valid[cache_idx] = 1
    } else {
      let enc_r = if subtract_green { (r - g) & 0xFF } else { r }
      let enc_b = if subtract_green { (b - g) & 0xFF } else { b }
      green_freqs[g] += 1
      red_freqs[enc_r] += 1
      blue_freqs[enc_b] += 1
      alpha_freqs[a] += 1
    }
  }
  (green_freqs, red_freqs, blue_freqs, alpha_freqs)
}

///|
fn webp_build_plan_candidate(
  img : ImageData,
  subtract_green : Bool,
  color_cache_bits : Int,
) -> (WebPEncodingPlan, Int) {
  let (green_freqs, red_freqs, blue_freqs, alpha_freqs) = webp_collect_channel_freqs(
    img, subtract_green, color_cache_bits,
  )
  let green_code = webp_build_prefix_code(green_freqs)
  let red_code = webp_build_prefix_code(red_freqs)
  let blue_code = webp_build_prefix_code(blue_freqs)
  let alpha_code = webp_build_prefix_code(alpha_freqs)
  let estimated_bits = webp_estimate_data_bits(green_freqs, green_code) +
    webp_estimate_data_bits(red_freqs, red_code) +
    webp_estimate_data_bits(blue_freqs, blue_code) +
    webp_estimate_data_bits(alpha_freqs, alpha_code)
  (
    {
      subtract_green,
      color_cache_bits,
      green_code,
      red_code,
      blue_code,
      alpha_code,
    },
    estimated_bits,
  )
}

///|
fn webp_build_plan(img : ImageData) -> WebPEncodingPlan {
  let initial = webp_build_plan_candidate(img, false, 0)
  let mut best_plan = initial.0
  let mut best_score = initial.1
  for subtract_green_index in 0..<2 {
    let subtract_green = subtract_green_index == 1
    for color_cache_bits in 0..<=4 {
      let candidate = webp_build_plan_candidate(
        img, subtract_green, color_cache_bits,
      )
      if candidate.1 < best_score {
        best_plan = candidate.0
        best_score = candidate.1
      }
    }
  }
  best_plan
}

///|
fn encode_webp_lossless_payload(img : ImageData) -> Bytes {
  let bw = WebPBitWriter::new()
  let pixel_count = img.width * img.height
  let plan = webp_build_plan(img)
  let color_cache = FixedArray::make(
    if plan.color_cache_bits > 0 {
      1 << plan.color_cache_bits
    } else {
      0
    },
    0,
  )
  let color_cache_valid = FixedArray::make(
    if plan.color_cache_bits > 0 {
      1 << plan.color_cache_bits
    } else {
      0
    },
    0,
  )
  let mut alpha_is_used = false
  for i in 0..<pixel_count {
    if img.data[i * 4 + 3].to_int() != 0xFF {
      alpha_is_used = true
      break
    }
  }

  bw.put_bits(0x2F, 8)
  bw.put_bits(img.width - 1, 14)
  bw.put_bits(img.height - 1, 14)
  bw.put_bits(if alpha_is_used { 1 } else { 0 }, 1)
  bw.put_bits(0, 3)
  if plan.subtract_green {
    bw.put_bits(1, 1)
    bw.put_bits(2, 2)
  }
  bw.put_bits(0, 1)
  if plan.color_cache_bits > 0 {
    bw.put_bits(1, 1)
    bw.put_bits(plan.color_cache_bits, 4)
  } else {
    bw.put_bits(0, 1)
  }
  bw.put_bits(0, 1)

  encode_webp_prefix_code(bw, plan.green_code)
  encode_webp_prefix_code(bw, plan.red_code)
  encode_webp_prefix_code(bw, plan.blue_code)
  encode_webp_prefix_code(bw, plan.alpha_code)
  encode_webp_prefix_code(bw, webp_build_prefix_code(FixedArray::make(40, 0)))

  for i in 0..<pixel_count {
    let offset = i * 4
    let red = img.data[offset].to_int() & 0xFF
    let green = img.data[offset + 1].to_int() & 0xFF
    let blue = img.data[offset + 2].to_int() & 0xFF
    let alpha = img.data[offset + 3].to_int() & 0xFF
    let enc_red = if plan.subtract_green { (red - green) & 0xFF } else { red }
    let enc_blue = if plan.subtract_green {
      (blue - green) & 0xFF
    } else {
      blue
    }
    let color = webp_pack_argb(enc_red, green, enc_blue, alpha)
    if plan.color_cache_bits > 0 {
      let cache_idx = webp_color_cache_index(color, plan.color_cache_bits)
      if color_cache_valid[cache_idx] == 1 && color_cache[cache_idx] == color {
        webp_write_symbol(bw, plan.green_code, 280 + cache_idx)
      } else {
        webp_write_symbol(bw, plan.green_code, green)
        webp_write_symbol(bw, plan.red_code, enc_red)
        webp_write_symbol(bw, plan.blue_code, enc_blue)
        webp_write_symbol(bw, plan.alpha_code, alpha)
      }
      color_cache[cache_idx] = color
      color_cache_valid[cache_idx] = 1
    } else {
      let enc_red = if plan.subtract_green { (red - green) & 0xFF } else { red }
      let enc_blue = if plan.subtract_green {
        (blue - green) & 0xFF
      } else {
        blue
      }
      webp_write_symbol(bw, plan.green_code, green)
      webp_write_symbol(bw, plan.red_code, enc_red)
      webp_write_symbol(bw, plan.blue_code, enc_blue)
      webp_write_symbol(bw, plan.alpha_code, alpha)
    }
  }
  bw.flush()
  bw.to_bytes()
}

///|
pub fn encode_webp(img : ImageData) -> Bytes raise EncodeError {
  let width = img.width
  let height = img.height
  if width <= 0 || height <= 0 {
    raise InvalidDimensions(
      "width and height must be positive: " +
      width.to_string() +
      "x" +
      height.to_string(),
    )
  }
  if width > 16384 || height > 16384 {
    raise InvalidDimensions(
      "WebP lossless dimensions must be <= 16384: " +
      width.to_string() +
      "x" +
      height.to_string(),
    )
  }
  let expected_len = width * height * 4
  if img.data.length() != expected_len {
    raise InvalidData(
      "expected " +
      expected_len.to_string() +
      " bytes, got " +
      img.data.length().to_string(),
    )
  }

  let payload = encode_webp_lossless_payload(img)
  let pad_len = if payload.length() % 2 == 1 { 1 } else { 0 }
  let file_size = 4 + 8 + payload.length() + pad_len
  let out = FixedArray::make(8 + file_size, b'\x00')

  out[0] = b'\x52'
  out[1] = b'\x49'
  out[2] = b'\x46'
  out[3] = b'\x46'
  write_u32le(out, 4, file_size.reinterpret_as_uint())
  out[8] = b'\x57'
  out[9] = b'\x45'
  out[10] = b'\x42'
  out[11] = b'\x50'
  out[12] = b'\x56'
  out[13] = b'\x50'
  out[14] = b'\x38'
  out[15] = b'\x4C'
  write_u32le(out, 16, payload.length().reinterpret_as_uint())
  out.blit_from_bytes(20, payload, 0, payload.length())
  Bytes::from_array(out)
}
