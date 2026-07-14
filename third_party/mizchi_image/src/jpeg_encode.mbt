///|
priv struct JpegBitWriter {
  buf : Array[Byte]
  mut bit_buf : Int
  mut bits_count : Int
}

///|
fn JpegBitWriter::new() -> JpegBitWriter {
  { buf: [], bit_buf: 0, bits_count: 0 }
}

///|
fn JpegBitWriter::write_byte(self : JpegBitWriter, value : Int) -> Unit {
  let b = value & 0xFF
  self.buf.push(b.to_byte())
  if b == 0xFF {
    self.buf.push(b'\x00')
  }
}

///|
fn JpegBitWriter::write_bits(
  self : JpegBitWriter,
  value : Int,
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  let masked = value & ((1 << count) - 1)
  self.bit_buf = (self.bit_buf << count) | masked
  self.bits_count += count
  while self.bits_count >= 8 {
    let shift = self.bits_count - 8
    let out = (self.bit_buf >> shift) & 0xFF
    self.write_byte(out)
    self.bits_count -= 8
    if self.bits_count == 0 {
      self.bit_buf = 0
    } else {
      self.bit_buf = self.bit_buf & ((1 << self.bits_count) - 1)
    }
  }
}

///|
fn JpegBitWriter::flush(self : JpegBitWriter) -> Unit {
  if self.bits_count > 0 {
    let pad_len = 8 - self.bits_count
    let padded = (self.bit_buf << pad_len) | ((1 << pad_len) - 1)
    self.write_byte(padded)
    self.bit_buf = 0
    self.bits_count = 0
  }
}

///|
fn JpegBitWriter::to_bytes(self : JpegBitWriter) -> Bytes {
  let out = FixedArray::make(self.buf.length(), b'\x00')
  for i in 0..<self.buf.length() {
    out[i] = self.buf[i]
  }
  Bytes::from_array(out)
}

///|
priv struct HuffmanEncodeTable {
  codes : FixedArray[Int]
  lengths : FixedArray[Int]
}

///|
fn build_huffman_encode_table(
  bits : FixedArray[Int],
  vals : FixedArray[Int],
) -> HuffmanEncodeTable {
  let codes = FixedArray::make(256, 0)
  let lengths = FixedArray::make(256, 0)
  let mut code = 0
  let mut vi = 0
  for length in 1..<=16 {
    let count = bits[length]
    for _ in 0..<count {
      let symbol = vals[vi]
      codes[symbol] = code
      lengths[symbol] = length
      code += 1
      vi += 1
    }
    code = code << 1
  }
  { codes, lengths }
}

///|
// Annex K.3
let jpeg_huff_bits_dc_luma : FixedArray[Int] = [
  0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
]

///|
// Annex K.4
let jpeg_huff_bits_dc_chroma : FixedArray[Int] = [
  0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
]

///|
// Annex K.5
let jpeg_huff_bits_ac_luma : FixedArray[Int] = [
  0, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7D,
]

///|
// Annex K.6
let jpeg_huff_bits_ac_chroma : FixedArray[Int] = [
  0, 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77,
]

///|
let jpeg_huff_vals_dc_luma : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
]

///|
let jpeg_huff_vals_dc_chroma : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
]

///|
let jpeg_huff_vals_ac_luma : FixedArray[Int] = [
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51,
  0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1,
  0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18,
  0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57,
  0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
  0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92,
  0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
  0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3,
  0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8,
  0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2,
  0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
]

///|
let jpeg_huff_vals_ac_chroma : FixedArray[Int] = [
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07,
  0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xA1, 0xB1, 0xC1, 0x09,
  0x23, 0x33, 0x52, 0xF0, 0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25,
  0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38,
  0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56,
  0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74,
  0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5,
  0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA,
  0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6,
  0xD7, 0xD8, 0xD9, 0xDA, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2,
  0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
]

///|
fn round_to_int(v : Double) -> Int {
  if v >= 0.0 {
    (v + 0.5).to_int()
  } else {
    (v - 0.5).to_int()
  }
}

///|
fn clamp_u8(v : Int) -> Int {
  v.clamp(min=0, max=255)
}

///|
fn write_u16be(buf : FixedArray[Byte], offset : Int, value : Int) -> Unit {
  buf[offset] = ((value >> 8) & 0xFF).to_byte()
  buf[offset + 1] = (value & 0xFF).to_byte()
}

///|
fn rgba_to_ycbcr(r : Int, g : Int, b : Int) -> (Int, Int, Int) {
  let y = round_to_int(
    0.299 * r.to_double() + 0.587 * g.to_double() + 0.114 * b.to_double(),
  )
  let cb = round_to_int(
    -0.168736 * r.to_double() -
    0.331264 * g.to_double() +
    0.5 * b.to_double() +
    128.0,
  )
  let cr = round_to_int(
    0.5 * r.to_double() -
    0.418688 * g.to_double() -
    0.081312 * b.to_double() +
    128.0,
  )
  (clamp_u8(y), clamp_u8(cb), clamp_u8(cr))
}

///|
// Forward DCT matching the decoder's idct_cos_table / idct_c convention.
fn fdct_block(input : FixedArray[Int], output : FixedArray[Double]) -> Unit {
  let tmp = FixedArray::make(64, 0.0)
  for y in 0..<8 {
    for v in 0..<8 {
      let mut sum = 0.0
      for x in 0..<8 {
        sum += (input[y * 8 + x] - 128).to_double() * idct_cos_table[x * 8 + v]
      }
      tmp[y * 8 + v] = sum
    }
  }
  for u in 0..<8 {
    for v in 0..<8 {
      let mut sum = 0.0
      for y in 0..<8 {
        sum += tmp[y * 8 + v] * idct_cos_table[y * 8 + u]
      }
      output[u * 8 + v] = 0.25 * idct_c[u] * idct_c[v] * sum
    }
  }
}

///|
fn jpeg_scale_quant_table(
  base : FixedArray[Int],
  quality : Int,
) -> FixedArray[Int] {
  let q = quality.clamp(min=1, max=100)
  let scale = if q < 50 { 5000 / q } else { 200 - 2 * q }
  let out = FixedArray::make(64, 0)
  for i in 0..<64 {
    let v = (base[i] * scale + 50) / 100
    out[i] = v.clamp(min=1, max=255)
  }
  out
}

///|
fn quantize_and_zigzag(
  dct : FixedArray[Double],
  quant : FixedArray[Int],
  output : FixedArray[Int],
) -> Unit {
  for i in 0..<64 {
    let idx = jpeg_zigzag[i]
    let q = quant[idx].to_double()
    output[i] = round_to_int(dct[idx] / q)
  }
}

///|
fn jpeg_bit_category(value : Int) -> Int {
  if value == 0 {
    return 0
  }
  let mut v = if value < 0 { -value } else { value }
  let mut cat = 0
  while v > 0 {
    cat += 1
    v = v >> 1
  }
  cat
}

///|
fn jpeg_bit_payload(value : Int, category : Int) -> Int {
  if category == 0 {
    0
  } else if value >= 0 {
    value
  } else {
    value - 1 + (1 << category)
  }
}

///|
fn encode_dc(
  bw : JpegBitWriter,
  diff : Int,
  table : HuffmanEncodeTable,
) -> Unit {
  let cat = jpeg_bit_category(diff)
  bw.write_bits(table.codes[cat], table.lengths[cat])
  if cat > 0 {
    bw.write_bits(jpeg_bit_payload(diff, cat), cat)
  }
}

///|
fn encode_ac(
  bw : JpegBitWriter,
  coeffs : FixedArray[Int],
  table : HuffmanEncodeTable,
) -> Unit {
  let mut run = 0
  for i in 1..<64 {
    let v = coeffs[i]
    if v == 0 {
      run += 1
      if run == 16 {
        bw.write_bits(table.codes[0xF0], table.lengths[0xF0])
        run = 0
      }
    } else {
      let cat = jpeg_bit_category(v)
      let symbol = (run << 4) | cat
      bw.write_bits(table.codes[symbol], table.lengths[symbol])
      bw.write_bits(jpeg_bit_payload(v, cat), cat)
      run = 0
    }
  }
  if run > 0 {
    // EOB
    bw.write_bits(table.codes[0], table.lengths[0])
  }
}

///|
fn jpeg_marker_soi() -> Bytes {
  Bytes::from_array([b'\xFF', b'\xD8'])
}

///|
fn jpeg_marker_app0() -> Bytes {
  let buf = FixedArray::make(18, b'\x00')
  buf[0] = b'\xFF'
  buf[1] = b'\xE0'
  write_u16be(buf, 2, 16)
  buf[4] = b'\x4A' // J
  buf[5] = b'\x46' // F
  buf[6] = b'\x49' // I
  buf[7] = b'\x46' // F
  buf[8] = b'\x00'
  buf[9] = b'\x01' // version major
  buf[10] = b'\x01' // version minor
  buf[11] = b'\x00' // units
  write_u16be(buf, 12, 1) // X density
  write_u16be(buf, 14, 1) // Y density
  buf[16] = b'\x00' // thumbnail width
  buf[17] = b'\x00' // thumbnail height
  Bytes::from_array(buf)
}

///|
fn jpeg_marker_dqt(id : Int, quant : FixedArray[Int]) -> Bytes {
  let buf = FixedArray::make(69, b'\x00')
  buf[0] = b'\xFF'
  buf[1] = b'\xDB'
  write_u16be(buf, 2, 67)
  buf[4] = id.to_byte() // 8-bit precision + table id
  for i in 0..<64 {
    buf[5 + i] = quant[jpeg_zigzag[i]].to_byte()
  }
  Bytes::from_array(buf)
}

///|
fn jpeg_marker_sof0(width : Int, height : Int) -> Bytes {
  let buf = FixedArray::make(19, b'\x00')
  buf[0] = b'\xFF'
  buf[1] = b'\xC0'
  write_u16be(buf, 2, 17)
  buf[4] = b'\x08' // precision
  write_u16be(buf, 5, height)
  write_u16be(buf, 7, width)
  buf[9] = b'\x03' // components
  // Y
  buf[10] = b'\x01'
  buf[11] = b'\x11'
  buf[12] = b'\x00'
  // Cb
  buf[13] = b'\x02'
  buf[14] = b'\x11'
  buf[15] = b'\x01'
  // Cr
  buf[16] = b'\x03'
  buf[17] = b'\x11'
  buf[18] = b'\x01'
  Bytes::from_array(buf)
}

///|
fn jpeg_marker_dht(
  class : Int,
  id : Int,
  bits : FixedArray[Int],
  vals : FixedArray[Int],
) -> Bytes {
  let payload_len = 1 + 16 + vals.length()
  let seg_len = payload_len + 2
  let buf = FixedArray::make(seg_len + 2, b'\x00')
  buf[0] = b'\xFF'
  buf[1] = b'\xC4'
  write_u16be(buf, 2, seg_len)
  buf[4] = ((class << 4) | id).to_byte()
  for i in 0..<16 {
    buf[5 + i] = bits[i + 1].to_byte()
  }
  for i in 0..<vals.length() {
    buf[21 + i] = vals[i].to_byte()
  }
  Bytes::from_array(buf)
}

///|
fn jpeg_marker_sos() -> Bytes {
  let buf = FixedArray::make(14, b'\x00')
  buf[0] = b'\xFF'
  buf[1] = b'\xDA'
  write_u16be(buf, 2, 12)
  buf[4] = b'\x03' // components
  // Y uses DC0 / AC0
  buf[5] = b'\x01'
  buf[6] = b'\x00'
  // Cb uses DC1 / AC1
  buf[7] = b'\x02'
  buf[8] = b'\x11'
  // Cr uses DC1 / AC1
  buf[9] = b'\x03'
  buf[10] = b'\x11'
  buf[11] = b'\x00' // Ss
  buf[12] = b'\x3F' // Se
  buf[13] = b'\x00' // Ah/Al
  Bytes::from_array(buf)
}

///|
fn jpeg_marker_eoi() -> Bytes {
  Bytes::from_array([b'\xFF', b'\xD9'])
}

///|
fn encode_component_block(
  bw : JpegBitWriter,
  input : FixedArray[Int],
  dct : FixedArray[Double],
  coeffs : FixedArray[Int],
  quant : FixedArray[Int],
  dc_table : HuffmanEncodeTable,
  ac_table : HuffmanEncodeTable,
  prev_dc : FixedArray[Int],
  comp_idx : Int,
) -> Unit {
  fdct_block(input, dct)
  quantize_and_zigzag(dct, quant, coeffs)
  let diff = coeffs[0] - prev_dc[comp_idx]
  prev_dc[comp_idx] = coeffs[0]
  encode_dc(bw, diff, dc_table)
  encode_ac(bw, coeffs, ac_table)
}

///|
pub fn encode_jpeg(
  img : ImageData,
  quality? : Int = 85,
) -> Bytes raise EncodeError {
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
  let expected_len = width * height * 4
  if img.data.length() != expected_len {
    raise InvalidData(
      "expected " +
      expected_len.to_string() +
      " bytes, got " +
      img.data.length().to_string(),
    )
  }

  let q = quality.clamp(min=1, max=100)
  let quant_luma = jpeg_scale_quant_table(jpeg_std_lum_quant, q)
  let quant_chroma = jpeg_scale_quant_table(jpeg_std_chrom_quant, q)

  let dc_luma = build_huffman_encode_table(
    jpeg_huff_bits_dc_luma, jpeg_huff_vals_dc_luma,
  )
  let dc_chroma = build_huffman_encode_table(
    jpeg_huff_bits_dc_chroma, jpeg_huff_vals_dc_chroma,
  )
  let ac_luma = build_huffman_encode_table(
    jpeg_huff_bits_ac_luma, jpeg_huff_vals_ac_luma,
  )
  let ac_chroma = build_huffman_encode_table(
    jpeg_huff_bits_ac_chroma, jpeg_huff_vals_ac_chroma,
  )

  let parts : Array[Bytes] = []
  parts.push(jpeg_marker_soi())
  parts.push(jpeg_marker_app0())
  parts.push(jpeg_marker_dqt(0, quant_luma))
  parts.push(jpeg_marker_dqt(1, quant_chroma))
  parts.push(jpeg_marker_sof0(width, height))
  parts.push(
    jpeg_marker_dht(0, 0, jpeg_huff_bits_dc_luma, jpeg_huff_vals_dc_luma),
  )
  parts.push(
    jpeg_marker_dht(0, 1, jpeg_huff_bits_dc_chroma, jpeg_huff_vals_dc_chroma),
  )
  parts.push(
    jpeg_marker_dht(1, 0, jpeg_huff_bits_ac_luma, jpeg_huff_vals_ac_luma),
  )
  parts.push(
    jpeg_marker_dht(1, 1, jpeg_huff_bits_ac_chroma, jpeg_huff_vals_ac_chroma),
  )
  parts.push(jpeg_marker_sos())

  let bw = JpegBitWriter::new()
  let prev_dc = FixedArray::make(3, 0)
  let y_block = FixedArray::make(64, 0)
  let cb_block = FixedArray::make(64, 0)
  let cr_block = FixedArray::make(64, 0)
  let dct = FixedArray::make(64, 0.0)
  let coeffs = FixedArray::make(64, 0)
  let mcu_cols = (width + 7) / 8
  let mcu_rows = (height + 7) / 8

  for mcu_y in 0..<mcu_rows {
    for mcu_x in 0..<mcu_cols {
      for by in 0..<8 {
        for bx in 0..<8 {
          let px = (mcu_x * 8 + bx).clamp(min=0, max=width - 1)
          let py = (mcu_y * 8 + by).clamp(min=0, max=height - 1)
          let idx = (py * width + px) * 4
          let r = img.data[idx].to_int()
          let g = img.data[idx + 1].to_int()
          let b = img.data[idx + 2].to_int()
          let (y, cb, cr) = rgba_to_ycbcr(r, g, b)
          let block_idx = by * 8 + bx
          y_block[block_idx] = y
          cb_block[block_idx] = cb
          cr_block[block_idx] = cr
        }
      }

      encode_component_block(
        bw, y_block, dct, coeffs, quant_luma, dc_luma, ac_luma, prev_dc, 0,
      )
      encode_component_block(
        bw, cb_block, dct, coeffs, quant_chroma, dc_chroma, ac_chroma, prev_dc, 1,
      )
      encode_component_block(
        bw, cr_block, dct, coeffs, quant_chroma, dc_chroma, ac_chroma, prev_dc, 2,
      )
    }
  }

  bw.flush()
  parts.push(bw.to_bytes())
  parts.push(jpeg_marker_eoi())

  let mut total_len = 0
  for p in parts {
    total_len += p.length()
  }
  let out = FixedArray::make(total_len, b'\x00')
  let mut pos = 0
  for p in parts {
    out.blit_from_bytes(pos, p, 0, p.length())
    pos += p.length()
  }
  Bytes::from_array(out)
}
