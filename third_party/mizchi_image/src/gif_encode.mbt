///|
priv struct GifPaletteEntry {
  r : Int
  g : Int
  b : Int
}

///|
priv struct GifPaletteData {
  indices : Array[Int]
  colors : Array[GifPaletteEntry]
  transparent_index : Int?
}

///|
priv struct GifBitWriter {
  buf : Array[Byte]
  mut bit_buf : Int
  mut bits_count : Int
}

///|
fn GifBitWriter::new() -> GifBitWriter {
  { buf: [], bit_buf: 0, bits_count: 0 }
}

///|
fn GifBitWriter::write_bits(
  self : GifBitWriter,
  value : Int,
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  let masked = value & ((1 << count) - 1)
  self.bit_buf = self.bit_buf | (masked << self.bits_count)
  self.bits_count += count
  while self.bits_count >= 8 {
    self.buf.push((self.bit_buf & 0xFF).to_byte())
    self.bit_buf = self.bit_buf >> 8
    self.bits_count -= 8
  }
}

///|
fn GifBitWriter::flush(self : GifBitWriter) -> Unit {
  if self.bits_count > 0 {
    self.buf.push((self.bit_buf & 0xFF).to_byte())
    self.bit_buf = 0
    self.bits_count = 0
  }
}

///|
fn GifBitWriter::to_bytes(self : GifBitWriter) -> Bytes {
  let out = FixedArray::make(self.buf.length(), b'\x00')
  for i in 0..<self.buf.length() {
    out[i] = self.buf[i]
  }
  Bytes::from_array(out)
}

///|
fn concat_bytes(parts : Array[Bytes]) -> Bytes {
  let mut total_len = 0
  for part in parts {
    total_len += part.length()
  }
  let out = FixedArray::make(total_len, b'\x00')
  let mut pos = 0
  for part in parts {
    out.blit_from_bytes(pos, part, 0, part.length())
    pos += part.length()
  }
  Bytes::from_array(out)
}

///|
fn gif_color_key(r : Int, g : Int, b : Int) -> Int {
  (r & 0xFF) | ((g & 0xFF) << 8) | ((b & 0xFF) << 16)
}

///|
fn gif_next_power_of_two(value : Int) -> Int {
  let mut size = 2
  while size < value {
    size *= 2
  }
  size
}

///|
fn gif_color_table_size_field(table_size : Int) -> Int {
  let mut field = 0
  let mut size = 2
  while size < table_size {
    size *= 2
    field += 1
  }
  field
}

///|
fn gif_min_code_size(color_count : Int) -> Int {
  let mut bits = 0
  let mut size = 1
  while size < color_count {
    size *= 2
    bits += 1
  }
  bits.clamp(min=2, max=8)
}

///|
fn collect_gif_palette(img : ImageData) -> GifPaletteData raise EncodeError {
  let palette_map : Map[Int, Int] = Map([])
  let indices : Array[Int] = []
  let colors : Array[GifPaletteEntry] = []
  let mut transparent_index : Int? = None
  let pixel_count = img.width * img.height

  for i in 0..<pixel_count {
    let offset = i * 4
    let r = img.data[offset].to_int() & 0xFF
    let g = img.data[offset + 1].to_int() & 0xFF
    let b = img.data[offset + 2].to_int() & 0xFF
    let a = img.data[offset + 3].to_int() & 0xFF
    if a == 0 {
      let index = match transparent_index {
        Some(existing) => existing
        None => {
          let new_index = colors.length()
          if new_index >= 256 {
            raise InvalidData("GIF palette exceeded 256 colors")
          }
          colors.push({ r: 0, g: 0, b: 0 })
          transparent_index = Some(new_index)
          new_index
        }
      }
      indices.push(index)
      continue
    }
    if a != 0xFF {
      raise InvalidData("GIF only supports alpha values 0 or 255")
    }
    let key = gif_color_key(r, g, b)
    let index = match palette_map.get(key) {
      Some(existing) => existing
      None => {
        let new_index = colors.length()
        if new_index >= 256 {
          raise InvalidData("GIF palette exceeded 256 colors")
        }
        colors.push({ r, g, b })
        palette_map.set(key, new_index)
        new_index
      }
    }
    indices.push(index)
  }
  { indices, colors, transparent_index }
}

///|
fn encode_gif_logical_screen_descriptor(
  width : Int,
  height : Int,
  color_table_size : Int,
  background_index : Int,
) -> Bytes {
  let buf = FixedArray::make(13, b'\x00')
  buf[0] = b'\x47'
  buf[1] = b'\x49'
  buf[2] = b'\x46'
  buf[3] = b'\x38'
  buf[4] = b'\x39'
  buf[5] = b'\x61'
  write_u16le(buf, 6, width)
  write_u16le(buf, 8, height)
  let size_field = gif_color_table_size_field(color_table_size)
  buf[10] = (0x80 | (7 << 4) | size_field).to_byte()
  buf[11] = background_index.to_byte()
  buf[12] = b'\x00'
  Bytes::from_array(buf)
}

///|
fn encode_gif_global_color_table(
  colors : Array[GifPaletteEntry],
  color_table_size : Int,
) -> Bytes {
  let table = FixedArray::make(color_table_size * 3, b'\x00')
  for i in 0..<colors.length() {
    let offset = i * 3
    table[offset] = colors[i].r.to_byte()
    table[offset + 1] = colors[i].g.to_byte()
    table[offset + 2] = colors[i].b.to_byte()
  }
  Bytes::from_array(table)
}

///|
fn encode_gif_graphics_control_extension(transparent_index : Int?) -> Bytes? {
  match transparent_index {
    None => None
    Some(index) => {
      let buf = FixedArray::make(8, b'\x00')
      buf[0] = b'\x21'
      buf[1] = b'\xF9'
      buf[2] = b'\x04'
      buf[3] = b'\x01'
      buf[6] = index.to_byte()
      Some(Bytes::from_array(buf))
    }
  }
}

///|
fn encode_gif_image_descriptor(width : Int, height : Int) -> Bytes {
  let buf = FixedArray::make(10, b'\x00')
  buf[0] = b'\x2C'
  write_u16le(buf, 5, width)
  write_u16le(buf, 7, height)
  Bytes::from_array(buf)
}

///|
fn encode_gif_lzw(indices : Array[Int], min_code_size : Int) -> Bytes {
  let clear = 1 << min_code_size
  let eoi = clear + 1
  let writer = GifBitWriter::new()
  let code_size = min_code_size + 1

  for index in indices {
    writer.write_bits(clear, code_size)
    writer.write_bits(index, code_size)
  }
  writer.write_bits(eoi, code_size)
  writer.flush()
  writer.to_bytes()
}

///|
fn encode_gif_sub_blocks(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut pos = 0
  while pos < data.length() {
    let remaining = data.length() - pos
    let chunk_len = if remaining > 255 { 255 } else { remaining }
    out.push(chunk_len.to_byte())
    for i in 0..<chunk_len {
      out.push(data[pos + i])
    }
    pos += chunk_len
  }
  out.push(b'\x00')
  let buf = FixedArray::make(out.length(), b'\x00')
  for i in 0..<out.length() {
    buf[i] = out[i]
  }
  Bytes::from_array(buf)
}

///|
pub fn encode_gif(img : ImageData) -> Bytes raise EncodeError {
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

  let palette = collect_gif_palette(img)
  let color_table_size = gif_next_power_of_two(palette.colors.length())
  let background_index = match palette.transparent_index {
    Some(index) => index
    None => 0
  }
  let min_code_size = gif_min_code_size(palette.colors.length())
  let compressed = encode_gif_lzw(palette.indices, min_code_size)

  let parts : Array[Bytes] = []
  parts.push(
    encode_gif_logical_screen_descriptor(
      width, height, color_table_size, background_index,
    ),
  )
  parts.push(encode_gif_global_color_table(palette.colors, color_table_size))
  match encode_gif_graphics_control_extension(palette.transparent_index) {
    Some(gce) => parts.push(gce)
    None => ()
  }
  parts.push(encode_gif_image_descriptor(width, height))
  parts.push(Bytes::from_array([min_code_size.to_byte()]))
  parts.push(encode_gif_sub_blocks(compressed))
  parts.push(b"\x3B")
  concat_bytes(parts)
}
