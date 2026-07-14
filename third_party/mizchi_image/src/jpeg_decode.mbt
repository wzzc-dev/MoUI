///|
// JPEG Baseline (SOF0) decoder
// Supports: 8-bit, YCbCr, 4:4:4 and 4:2:0 subsampling

///|
priv struct JpegBitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bits_left : Int
}

///|
fn JpegBitReader::new(data : Bytes, pos : Int) -> JpegBitReader {
  { data, pos, bit_buf: 0, bits_left: 0 }
}

///|
fn JpegBitReader::next_byte(self : JpegBitReader) -> Int raise DecodeError {
  if self.pos >= self.data.length() {
    raise CorruptData("unexpected end of JPEG data")
  }
  let b = self.data[self.pos].to_int()
  self.pos += 1
  // Handle byte stuffing: 0xFF 0x00 → 0xFF
  if b == 0xFF {
    if self.pos >= self.data.length() {
      raise CorruptData("unexpected end of JPEG data after 0xFF")
    }
    let next = self.data[self.pos].to_int()
    if next == 0x00 {
      self.pos += 1
      return 0xFF
    }
    // Marker found inside scan data - should not happen in valid baseline
    raise CorruptData("unexpected marker in scan data: 0xFF" + next.to_string())
  }
  b
}

///|
fn JpegBitReader::read_bits(
  self : JpegBitReader,
  count : Int,
) -> Int raise DecodeError {
  while self.bits_left < count {
    let b = self.next_byte()
    self.bit_buf = (self.bit_buf << 8) | b
    self.bits_left += 8
  }
  self.bits_left -= count
  (self.bit_buf.reinterpret_as_uint() >> self.bits_left).reinterpret_as_int() &
  ((1 << count) - 1)
}

///|
fn JpegBitReader::read_bit(self : JpegBitReader) -> Int raise DecodeError {
  self.read_bits(1)
}

///|
priv struct HuffmanTable {
  // For each code length 1..16, store the symbols
  min_code : FixedArray[Int] // min code value at each length
  max_code : FixedArray[Int] // max code value at each length (-1 if none)
  val_ptr : FixedArray[Int] // index into values for each length
  values : Array[Int]
}

///|
fn build_huffman_table(
  bits : FixedArray[Int],
  values : Array[Int],
) -> HuffmanTable {
  let min_code = FixedArray::make(17, 0)
  let max_code = FixedArray::make(17, -1)
  let val_ptr = FixedArray::make(17, 0)
  let mut code = 0
  let mut vi = 0
  for length in 1..<=16 {
    val_ptr[length] = vi
    if bits[length] > 0 {
      min_code[length] = code
      code += bits[length]
      max_code[length] = code - 1
      vi += bits[length]
    }
    code = code << 1
  }
  { min_code, max_code, val_ptr, values }
}

///|
fn decode_huffman(
  br : JpegBitReader,
  table : HuffmanTable,
) -> Int raise DecodeError {
  let mut code = 0
  for length in 1..<=16 {
    code = (code << 1) | br.read_bit()
    if table.max_code[length] >= 0 && code <= table.max_code[length] {
      let idx = table.val_ptr[length] + code - table.min_code[length]
      return table.values[idx]
    }
  }
  raise CorruptData("invalid Huffman code")
}

///|
fn receive_extend(br : JpegBitReader, nbits : Int) -> Int raise DecodeError {
  if nbits == 0 {
    return 0
  }
  let value = br.read_bits(nbits)
  if value < 1 << (nbits - 1) {
    // negative
    value - (1 << nbits) + 1
  } else {
    value
  }
}

///|
// Pre-computed IDCT cosine table: cos((2*n+1)*k*PI/16) for n,k in 0..7
// idct_cos_table[n * 8 + k] = cos((2*n+1)*k*PI/16)
let idct_cos_table : FixedArray[Double] = {
  let t = FixedArray::make(64, 0.0)
  for n in 0..<8 {
    for k in 0..<8 {
      t[n * 8 + k] = @math.cos(
        (2.0 * n.to_double() + 1.0) * k.to_double() * @math.PI / 16.0,
      )
    }
  }
  t
}

///|
// C(k) scaling factor: 1/sqrt(2) for k=0, 1.0 otherwise
let idct_c : FixedArray[Double] = {
  let c = FixedArray::make(8, 1.0)
  c[0] = 1.0 / 2.0.sqrt()
  c
}

///|
// IDCT using pre-computed cosine table
fn idct_block(coeff : FixedArray[Int], output : FixedArray[Int]) -> Unit {
  let tmp = FixedArray::make(64, 0.0)
  // First pass: columns
  for x in 0..<8 {
    for y in 0..<8 {
      let mut sum = 0.0
      for u in 0..<8 {
        sum += idct_c[u] *
          coeff[u * 8 + x].to_double() *
          idct_cos_table[y * 8 + u]
      }
      tmp[y * 8 + x] = sum
    }
  }
  // Second pass: rows
  for y in 0..<8 {
    for x in 0..<8 {
      let mut sum = 0.0
      for v in 0..<8 {
        sum += idct_c[v] * tmp[y * 8 + v] * idct_cos_table[x * 8 + v]
      }
      let val = (sum / 4.0 + 128.0).to_int()
      output[y * 8 + x] = if val < 0 {
        0
      } else if val > 255 {
        255
      } else {
        val
      }
    }
  }
}

///|
priv struct JpegComponent {
  id : Int
  h_sample : Int
  v_sample : Int
  quant_id : Int
}

///|
priv struct JpegFrameInfo {
  width : Int
  height : Int
  components : Array[JpegComponent]
  max_h : Int
  max_v : Int
}

///|
priv struct JpegScanComponent {
  comp_idx : Int
  dc_table_id : Int
  ac_table_id : Int
}

///|
fn read_u16be_at(data : Bytes, pos : Int) -> Int {
  ((data[pos].to_int() & 0xFF) << 8) | (data[pos + 1].to_int() & 0xFF)
}

///|
pub fn decode_jpeg(data : Bytes) -> ImageData raise DecodeError {
  if data.length() < 2 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    raise InvalidSignature("not a JPEG file")
  }
  let mut pos = 2
  let quant_tables : FixedArray[FixedArray[Int]?] = FixedArray::make(4, None)
  let dc_tables : FixedArray[HuffmanTable?] = FixedArray::make(4, None)
  let ac_tables : FixedArray[HuffmanTable?] = FixedArray::make(4, None)
  let mut frame_info : JpegFrameInfo? = None
  let mut scan_components : Array[JpegScanComponent] = []
  let mut scan_start = 0
  // Parse markers
  while pos + 1 < data.length() {
    if data[pos].to_int() != 0xFF {
      pos += 1
      continue
    }
    let marker = data[pos + 1].to_int()
    pos += 2
    if marker == 0xD9 {
      // EOI
      break
    }
    if marker == 0x00 || marker == 0xFF {
      continue
    }
    if marker >= 0xD0 && marker <= 0xD7 {
      // RST markers
      continue
    }
    if pos + 1 >= data.length() {
      break
    }
    let seg_len = read_u16be_at(data, pos)
    if marker == 0xDB {
      // DQT - Define Quantization Table
      let mut qpos = pos + 2
      let qend = pos + seg_len
      while qpos < qend {
        let pq_tq = data[qpos].to_int()
        let tq = pq_tq & 0x0F
        let pq = (pq_tq.reinterpret_as_uint() >> 4).reinterpret_as_int()
        qpos += 1
        let qt = FixedArray::make(64, 0)
        if pq == 0 {
          // 8-bit
          for i in 0..<64 {
            qt[jpeg_zigzag[i]] = data[qpos + i].to_int()
          }
          qpos += 64
        } else {
          // 16-bit
          for i in 0..<64 {
            qt[jpeg_zigzag[i]] = read_u16be_at(data, qpos + i * 2)
          }
          qpos += 128
        }
        quant_tables[tq] = Some(qt)
      }
    } else if marker == 0xC0 {
      // SOF0 - Start Of Frame (Baseline DCT)
      let precision = data[pos + 2].to_int()
      if precision != 8 {
        raise UnsupportedFeature(
          "unsupported bit depth: " + precision.to_string(),
        )
      }
      let height = read_u16be_at(data, pos + 3)
      let width = read_u16be_at(data, pos + 5)
      let ncomp = data[pos + 7].to_int()
      if ncomp != 3 && ncomp != 1 {
        raise UnsupportedFeature(
          "unsupported component count: " + ncomp.to_string(),
        )
      }
      let components : Array[JpegComponent] = []
      let mut max_h = 1
      let mut max_v = 1
      for i in 0..<ncomp {
        let coff = pos + 8 + i * 3
        let id = data[coff].to_int()
        let sampling = data[coff + 1].to_int()
        let h = (sampling.reinterpret_as_uint() >> 4).reinterpret_as_int()
        let v = sampling & 0x0F
        let qid = data[coff + 2].to_int()
        if h > max_h {
          max_h = h
        }
        if v > max_v {
          max_v = v
        }
        components.push({ id, h_sample: h, v_sample: v, quant_id: qid })
      }
      frame_info = Some({ width, height, components, max_h, max_v })
    } else if marker == 0xC4 {
      // DHT - Define Huffman Table
      let mut hpos = pos + 2
      let hend = pos + seg_len
      while hpos < hend {
        let tc_th = data[hpos].to_int()
        let tc = (tc_th.reinterpret_as_uint() >> 4).reinterpret_as_int() // 0=DC, 1=AC
        let th = tc_th & 0x0F
        hpos += 1
        let bits = FixedArray::make(17, 0)
        let mut total = 0
        for i in 1..<=16 {
          bits[i] = data[hpos + i - 1].to_int()
          total += bits[i]
        }
        hpos += 16
        let values : Array[Int] = []
        for i in 0..<total {
          values.push(data[hpos + i].to_int())
        }
        hpos += total
        let table = build_huffman_table(bits, values)
        if tc == 0 {
          dc_tables[th] = Some(table)
        } else {
          ac_tables[th] = Some(table)
        }
      }
    } else if marker == 0xDA {
      // SOS - Start Of Scan
      let ns = data[pos + 2].to_int()
      scan_components = []
      for i in 0..<ns {
        let soff = pos + 3 + i * 2
        let cs = data[soff].to_int()
        let td_ta = data[soff + 1].to_int()
        // Find component index
        let fi = match frame_info {
          Some(fi) => fi
          None => raise MissingChunk("SOF0 must precede SOS")
        }
        let mut comp_idx = 0
        for j in 0..<fi.components.length() {
          if fi.components[j].id == cs {
            comp_idx = j
          }
        }
        scan_components.push({
          comp_idx,
          dc_table_id: (td_ta.reinterpret_as_uint() >> 4).reinterpret_as_int(),
          ac_table_id: td_ta & 0x0F,
        })
      }
      scan_start = pos + seg_len
      break
    }
    pos += seg_len
  }
  let fi = match frame_info {
    Some(fi) => fi
    None => raise MissingChunk("SOF0")
  }
  if scan_start == 0 {
    raise MissingChunk("SOS")
  }
  // Decode scan data
  let br = JpegBitReader::new(data, scan_start)
  let mcu_w = fi.max_h * 8
  let mcu_h = fi.max_v * 8
  let mcu_cols = (fi.width + mcu_w - 1) / mcu_w
  let mcu_rows = (fi.height + mcu_h - 1) / mcu_h
  // Allocate component buffers
  let ncomp = fi.components.length()
  let comp_bufs : Array[FixedArray[Int]] = []
  for i in 0..<ncomp {
    let c = fi.components[i]
    let cw = mcu_cols * c.h_sample * 8
    let ch = mcu_rows * c.v_sample * 8
    comp_bufs.push(FixedArray::make(cw * ch, 128))
    ignore(i)
  }
  let prev_dc = FixedArray::make(ncomp, 0)
  let block = FixedArray::make(64, 0)
  let idct_out = FixedArray::make(64, 0)
  for mcu_y in 0..<mcu_rows {
    for mcu_x in 0..<mcu_cols {
      for si in 0..<scan_components.length() {
        let sc = scan_components[si]
        let ci = sc.comp_idx
        let c = fi.components[ci]
        let dc_tab = match dc_tables[sc.dc_table_id] {
          Some(t) => t
          None =>
            raise MissingChunk("DC Huffman table " + sc.dc_table_id.to_string())
        }
        let ac_tab = match ac_tables[sc.ac_table_id] {
          Some(t) => t
          None =>
            raise MissingChunk("AC Huffman table " + sc.ac_table_id.to_string())
        }
        let qt = match quant_tables[c.quant_id] {
          Some(t) => t
          None =>
            raise MissingChunk("quantization table " + c.quant_id.to_string())
        }
        for bv in 0..<c.v_sample {
          for bh in 0..<c.h_sample {
            // Decode one 8x8 block
            // DC coefficient
            let dc_cat = decode_huffman(br, dc_tab)
            let dc_diff = receive_extend(br, dc_cat)
            prev_dc[ci] += dc_diff
            // Clear block
            for i in 0..<64 {
              block[i] = 0
            }
            block[0] = prev_dc[ci] * qt[0]
            // AC coefficients
            let mut k = 1
            while k < 64 {
              let rs = decode_huffman(br, ac_tab)
              let run = (rs.reinterpret_as_uint() >> 4).reinterpret_as_int()
              let size = rs & 0x0F
              if size == 0 {
                if run == 0 {
                  break // EOB
                }
                if run == 0x0F {
                  k += 16
                  continue
                }
                break
              }
              k += run
              if k >= 64 {
                break
              }
              let ac_val = receive_extend(br, size)
              block[jpeg_zigzag[k]] = ac_val * qt[jpeg_zigzag[k]]
              k += 1
            }
            // IDCT
            idct_block(block, idct_out)
            // Write block to component buffer
            let comp_stride = mcu_cols * c.h_sample * 8
            let bx = (mcu_x * c.h_sample + bh) * 8
            let by = (mcu_y * c.v_sample + bv) * 8
            for yy in 0..<8 {
              for xx in 0..<8 {
                comp_bufs[ci][(by + yy) * comp_stride + bx + xx] = idct_out[yy *
                  8 +
                  xx]
              }
            }
          }
        }
      }
    }
  }
  // Convert to RGBA
  let out_buf = FixedArray::make(fi.width * fi.height * 4, b'\x00')
  if ncomp == 1 {
    // Grayscale
    for y in 0..<fi.height {
      for x in 0..<fi.width {
        let comp_stride = mcu_cols * fi.components[0].h_sample * 8
        let v = comp_bufs[0][y * comp_stride + x]
        let val = clamp_byte(v)
        let idx = (y * fi.width + x) * 4
        out_buf[idx] = val
        out_buf[idx + 1] = val
        out_buf[idx + 2] = val
        out_buf[idx + 3] = b'\xFF'
      }
    }
  } else {
    // YCbCr to RGB
    let c0 = fi.components[0]
    let c1 = fi.components[1]
    let c2 = fi.components[2]
    let stride_y = mcu_cols * c0.h_sample * 8
    let stride_cb = mcu_cols * c1.h_sample * 8
    let stride_cr = mcu_cols * c2.h_sample * 8
    for py in 0..<fi.height {
      for px in 0..<fi.width {
        // Map pixel to component coordinates (handle subsampling)
        let yy = comp_bufs[0][py * stride_y + px]
        let cb_x = px * c1.h_sample / fi.max_h
        let cb_y = py * c1.v_sample / fi.max_v
        let cr_x = px * c2.h_sample / fi.max_h
        let cr_y = py * c2.v_sample / fi.max_v
        let cb = comp_bufs[1][cb_y * stride_cb + cb_x]
        let cr = comp_bufs[2][cr_y * stride_cr + cr_x]
        // YCbCr to RGB conversion
        let y_val = yy.to_double()
        let cb_val = (cb - 128).to_double()
        let cr_val = (cr - 128).to_double()
        let r = (y_val + 1.402 * cr_val).to_int()
        let g = (y_val - 0.344136 * cb_val - 0.714136 * cr_val).to_int()
        let b = (y_val + 1.772 * cb_val).to_int()
        let idx = (py * fi.width + px) * 4
        out_buf[idx] = clamp_byte(r)
        out_buf[idx + 1] = clamp_byte(g)
        out_buf[idx + 2] = clamp_byte(b)
        out_buf[idx + 3] = b'\xFF'
      }
    }
  }
  { width: fi.width, height: fi.height, data: Bytes::from_array(out_buf) }
}

///|
fn clamp_byte(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}
