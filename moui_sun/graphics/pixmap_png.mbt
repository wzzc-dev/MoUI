///|
/// Encode this pixmap as a deterministic 8-bit RGBA PNG image.
///
/// The encoder writes filter-0 scanlines into uncompressed DEFLATE blocks, so
/// the output is dependency-free and stable for headless render fixtures.
pub fn Pixmap::to_png_bytes(self : Pixmap) -> Result[Bytes, PixmapEncodeError] {
  guard self.width > 0 && self.height > 0 else {
    return Err(PixmapEncodeError::InvalidPngDimensions(self.width, self.height))
  }
  let out : Array[Byte] = []
  append_png_signature(out)

  let ihdr : Array[Byte] = []
  append_png_u32_be(ihdr, self.width.reinterpret_as_uint())
  append_png_u32_be(ihdr, self.height.reinterpret_as_uint())
  ihdr.push(8) // bit depth
  ihdr.push(6) // RGBA truecolor with alpha
  ihdr.push(0) // compression method
  ihdr.push(0) // filter method
  ihdr.push(0) // no interlace
  append_png_chunk(out, [73, 72, 68, 82], ihdr) // IHDR

  let scanlines = png_rgba_filter0_scanlines(self)
  let idat = png_zlib_stored_stream(scanlines)
  append_png_chunk(out, [73, 68, 65, 84], idat) // IDAT
  append_png_chunk(out, [73, 69, 78, 68], []) // IEND
  Ok(Bytes::from_array(out))
}

///|
/// Decode an 8-bit RGBA PNG image into a pixmap.
///
/// This decoder supports non-interlaced PNGs with RGBA color, standard
/// scanline filters, and zlib-wrapped DEFLATE image data. It is
/// intentionally paired with `to_png_bytes` for portable fixture roundtrips.
pub fn Pixmap::from_png_bytes(
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  match decode_png_info(data) {
    Err(error) => Err(error)
    Ok(info) =>
      match png_zlib_stream_decode(info.idat) {
        Err(error) => Err(error)
        Ok(scanlines) => decode_png_rgba_pixmap(info, scanlines)
      }
  }
}

///|
fn append_png_signature(out : Array[Byte]) -> Unit {
  let signature : Array[Byte] = [137, 80, 78, 71, 13, 10, 26, 10]
  append_png_bytes(out, signature)
}

///|
fn append_png_chunk(
  out : Array[Byte],
  chunk_type : Array[Byte],
  data : Array[Byte],
) -> Unit {
  append_png_u32_be(out, data.length().reinterpret_as_uint())
  append_png_bytes(out, chunk_type)
  append_png_bytes(out, data)
  append_png_u32_be(out, png_crc32_chunk(chunk_type, data))
}

///|
fn append_png_bytes(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn append_png_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value >> 8).land(0xFF).to_byte())
}

///|
fn append_png_u32_be(out : Array[Byte], value : UInt) -> Unit {
  out.push((value >> 24).to_byte())
  out.push((value >> 16).to_byte())
  out.push((value >> 8).to_byte())
  out.push(value.to_byte())
}

///|
fn png_rgba_filter0_scanlines(pixmap : Pixmap) -> Array[Byte] {
  let out : Array[Byte] = []
  for y in 0..<pixmap.height {
    out.push(0)
    let row = y * pixmap.width * 4
    for x in 0..<pixmap.width {
      let offset = row + x * 4
      out.push(pixmap.pixels[offset])
      out.push(pixmap.pixels[offset + 1])
      out.push(pixmap.pixels[offset + 2])
      out.push(pixmap.pixels[offset + 3])
    }
  }
  out
}

///|
fn png_zlib_stored_stream(data : Array[Byte]) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(0x78)
  out.push(0x01)
  if data.length() == 0 {
    out.push(1)
    append_png_u16_le(out, 0)
    append_png_u16_le(out, 0xFFFF)
    append_png_u32_be(out, png_adler32(data))
    return out
  }
  let mut offset = 0
  while offset < data.length() {
    let remaining = data.length() - offset
    let block_len = remaining.min(65535)
    let is_final = offset + block_len >= data.length()
    out.push(if is_final { 1 } else { 0 })
    append_png_u16_le(out, block_len)
    append_png_u16_le(out, 0xFFFF - block_len)
    for i in 0..<block_len {
      out.push(data[offset + i])
    }
    offset = offset + block_len
  }
  append_png_u32_be(out, png_adler32(data))
  out
}

///|
fn png_adler32(data : Array[Byte]) -> UInt {
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
fn png_crc32_chunk(chunk_type : Array[Byte], data : Array[Byte]) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for byte in chunk_type {
    crc = png_crc32_update(crc, byte)
  }
  for byte in data {
    crc = png_crc32_update(crc, byte)
  }
  crc ^ 0xFFFFFFFF
}

///|
fn png_crc32_update(crc : UInt, byte : Byte) -> UInt {
  let mut c = crc ^ byte.to_uint()
  for _ in 0..<8 {
    c = if (c & 1) != 0 { (c >> 1) ^ 0xEDB88320 } else { c >> 1 }
  }
  c
}

///|
struct PngInfo {
  width : Int
  height : Int
  idat : Array[Byte]
} derive(Debug)

///|
struct PngHeader {
  width : Int
  height : Int
} derive(Debug)

///|
struct PngDeflateBitReader {
  data : Array[Byte]
  stream_end : Int
  mut byte_offset : Int
  mut bit_offset : Int
} derive(Debug)

///|
struct PngDeflateHuffmanEntry {
  symbol : Int
  length : Int
  code : Int
} derive(Debug)

///|
struct PngDeflateHuffman {
  entries : Array[PngDeflateHuffmanEntry]
  max_bits : Int
} derive(Debug)

///|
struct PngDeflateTables {
  literal_lengths : PngDeflateHuffman
  distances : PngDeflateHuffman
} derive(Debug)

///|
fn decode_png_info(data : Bytes) -> Result[PngInfo, PixmapDecodeError] {
  match require_png_available(data, 0, 8) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  guard has_png_signature(data) else {
    return Err(PixmapDecodeError::InvalidPngSignature)
  }

  let mut offset = 8
  let mut seen_ihdr = false
  let mut seen_iend = false
  let mut width = 0
  let mut height = 0
  let idat : Array[Byte] = []
  while offset < data.length() && !seen_iend {
    match require_png_available(data, offset, 8) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let length = read_png_u32_be_int_at(data, offset)
    let type_offset = offset + 4
    let data_offset = offset + 8
    let crc_offset = data_offset + length
    match require_png_available(data, data_offset, length + 4) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let expected_crc = read_png_u32_be_uint_at(data, crc_offset)
    let actual_crc = png_crc32_chunk_at(data, type_offset, data_offset, length)
    guard expected_crc == actual_crc else {
      return Err(PixmapDecodeError::PngCrcMismatch(expected_crc, actual_crc))
    }

    if png_chunk_type_is(data, type_offset, 73, 72, 68, 82) {
      match decode_png_header(data, data_offset, length) {
        Err(error) => return Err(error)
        Ok(header) => {
          seen_ihdr = true
          width = header.width
          height = header.height
        }
      }
    } else if !seen_ihdr {
      return Err(PixmapDecodeError::MissingPngImageHeader)
    } else if png_chunk_type_is(data, type_offset, 73, 68, 65, 84) {
      append_png_chunk_data(idat, data, data_offset, length)
    } else if png_chunk_type_is(data, type_offset, 73, 69, 78, 68) {
      seen_iend = true
    } else if png_chunk_is_unsupported_critical(data, type_offset) {
      return Err(
        PixmapDecodeError::UnsupportedPngChunk(
          data[type_offset].to_int(),
          data[type_offset + 1].to_int(),
          data[type_offset + 2].to_int(),
          data[type_offset + 3].to_int(),
        ),
      )
    }
    offset = crc_offset + 4
  }

  guard seen_ihdr else { return Err(PixmapDecodeError::MissingPngImageHeader) }
  guard seen_iend else { return Err(PixmapDecodeError::MissingPngImageEnd) }
  guard idat.length() > 0 else {
    return Err(PixmapDecodeError::MissingPngImageData)
  }
  Ok({ width, height, idat })
}

///|
fn decode_png_header(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[PngHeader, PixmapDecodeError] {
  guard length == 13 else {
    return Err(PixmapDecodeError::UnsupportedPngHeaderSize(length))
  }
  let width = read_png_u32_be_int_at(data, offset)
  let height = read_png_u32_be_int_at(data, offset + 4)
  guard width > 0 && height > 0 else {
    return Err(PixmapDecodeError::InvalidPngDimensions(width, height))
  }
  let bit_depth = data[offset + 8].to_int()
  let color_type = data[offset + 9].to_int()
  let compression = data[offset + 10].to_int()
  let filter = data[offset + 11].to_int()
  let interlace = data[offset + 12].to_int()
  guard bit_depth == 8 else {
    return Err(PixmapDecodeError::UnsupportedPngBitDepth(bit_depth))
  }
  guard color_type == 6 else {
    return Err(PixmapDecodeError::UnsupportedPngColorType(color_type))
  }
  guard compression == 0 else {
    return Err(PixmapDecodeError::UnsupportedPngCompression(compression))
  }
  guard filter == 0 else {
    return Err(PixmapDecodeError::UnsupportedPngFilter(filter))
  }
  guard interlace == 0 else {
    return Err(PixmapDecodeError::UnsupportedPngInterlace(interlace))
  }
  Ok({ width, height })
}

///|
fn png_zlib_stream_decode(
  data : Array[Byte],
) -> Result[Array[Byte], PixmapDecodeError] {
  match require_png_array_available(data, 0, 6) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let cmf = data[0].to_int()
  let flg = data[1].to_int()
  guard (cmf * 256 + flg) % 31 == 0 else {
    return Err(PixmapDecodeError::InvalidPngZlibHeader(cmf, flg))
  }
  let compression = cmf.land(0x0F)
  guard compression == 8 else {
    return Err(PixmapDecodeError::UnsupportedPngDeflateCompression(compression))
  }
  guard flg.land(0x20) == 0 else {
    return Err(PixmapDecodeError::UnsupportedPngDeflatePresetDictionary)
  }

  let stream_end = data.length() - 4
  let out : Array[Byte] = []
  let reader : PngDeflateBitReader = {
    data,
    stream_end,
    byte_offset: 2,
    bit_offset: 0,
  }
  let mut is_final = false
  while !is_final {
    match png_deflate_read_bits(reader, 1) {
      Err(error) => return Err(error)
      Ok(bit) => is_final = bit != 0
    }
    let block_type = match png_deflate_read_bits(reader, 2) {
      Err(error) => return Err(error)
      Ok(bits) => bits
    }
    match block_type {
      0 =>
        match png_deflate_decode_stored_block(reader, out) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      1 => {
        let tables = png_deflate_fixed_tables()
        match
          png_deflate_decode_compressed_block(
            reader,
            out,
            tables.literal_lengths,
            tables.distances,
          ) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      2 =>
        match png_deflate_decode_dynamic_tables(reader) {
          Err(error) => return Err(error)
          Ok(tables) =>
            match
              png_deflate_decode_compressed_block(
                reader,
                out,
                tables.literal_lengths,
                tables.distances,
              ) {
              Err(error) => return Err(error)
              Ok(_) => ()
            }
        }
      _ =>
        return Err(
          PixmapDecodeError::UnsupportedPngDeflateBlockType(block_type),
        )
    }
  }
  png_deflate_align_to_byte(reader)
  guard reader.byte_offset == stream_end else {
    return Err(
      PixmapDecodeError::PngInflateLengthMismatch(
        stream_end,
        reader.byte_offset,
      ),
    )
  }
  let expected_adler = read_png_u32_be_uint_array_at(data, stream_end)
  let actual_adler = png_adler32(out)
  guard expected_adler == actual_adler else {
    return Err(
      PixmapDecodeError::PngAdlerMismatch(expected_adler, actual_adler),
    )
  }
  Ok(out)
}

///|
fn png_deflate_read_bits(
  reader : PngDeflateBitReader,
  count : Int,
) -> Result[Int, PixmapDecodeError] {
  let mut value = 0
  for shift in 0..<count {
    guard reader.byte_offset < reader.stream_end else {
      return Err(
        PixmapDecodeError::UnexpectedEndOfData(
          reader.byte_offset,
          1,
          reader.data.length(),
        ),
      )
    }
    let bit = (reader.data[reader.byte_offset].to_int() >> reader.bit_offset).land(
      1,
    )
    value = value | (bit << shift)
    reader.bit_offset = reader.bit_offset + 1
    if reader.bit_offset == 8 {
      reader.bit_offset = 0
      reader.byte_offset = reader.byte_offset + 1
    }
  }
  Ok(value)
}

///|
fn png_deflate_align_to_byte(reader : PngDeflateBitReader) -> Unit {
  if reader.bit_offset != 0 {
    reader.bit_offset = 0
    reader.byte_offset = reader.byte_offset + 1
  }
}

///|
fn png_deflate_decode_stored_block(
  reader : PngDeflateBitReader,
  out : Array[Byte],
) -> Result[Unit, PixmapDecodeError] {
  png_deflate_align_to_byte(reader)
  match require_png_array_available(reader.data, reader.byte_offset, 4) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  guard reader.byte_offset + 4 <= reader.stream_end else {
    return Err(
      PixmapDecodeError::UnexpectedEndOfData(
        reader.byte_offset,
        4,
        reader.data.length(),
      ),
    )
  }
  let block_len = read_png_u16_le_array_at(reader.data, reader.byte_offset)
  let inverse_len = read_png_u16_le_array_at(
    reader.data,
    reader.byte_offset + 2,
  )
  reader.byte_offset = reader.byte_offset + 4
  guard block_len + inverse_len == 0xFFFF else {
    return Err(
      PixmapDecodeError::PngStoredBlockLengthMismatch(block_len, inverse_len),
    )
  }
  guard reader.byte_offset + block_len <= reader.stream_end else {
    return Err(
      PixmapDecodeError::UnexpectedEndOfData(
        reader.byte_offset,
        block_len,
        reader.data.length(),
      ),
    )
  }
  for i in 0..<block_len {
    out.push(reader.data[reader.byte_offset + i])
  }
  reader.byte_offset = reader.byte_offset + block_len
  Ok(())
}

///|
fn png_deflate_fixed_tables() -> PngDeflateTables {
  let literal_lengths : Array[Int] = []
  for symbol in 0..<288 {
    let length = if symbol < 144 {
      8
    } else if symbol < 256 {
      9
    } else if symbol < 280 {
      7
    } else {
      8
    }
    literal_lengths.push(length)
  }
  let distance_lengths : Array[Int] = []
  for _ in 0..<32 {
    distance_lengths.push(5)
  }
  {
    literal_lengths: png_deflate_build_huffman(literal_lengths),
    distances: png_deflate_build_huffman(distance_lengths),
  }
}

///|
fn png_deflate_decode_dynamic_tables(
  reader : PngDeflateBitReader,
) -> Result[PngDeflateTables, PixmapDecodeError] {
  let hlit = match png_deflate_read_bits(reader, 5) {
    Err(error) => return Err(error)
    Ok(bits) => bits + 257
  }
  let hdist = match png_deflate_read_bits(reader, 5) {
    Err(error) => return Err(error)
    Ok(bits) => bits + 1
  }
  let hclen = match png_deflate_read_bits(reader, 4) {
    Err(error) => return Err(error)
    Ok(bits) => bits + 4
  }
  let code_length_order : Array[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let code_length_lengths : Array[Int] = []
  for _ in 0..<19 {
    code_length_lengths.push(0)
  }
  for i in 0..<hclen {
    match png_deflate_read_bits(reader, 3) {
      Err(error) => return Err(error)
      Ok(length) => code_length_lengths[code_length_order[i]] = length
    }
  }
  let code_length_huffman = png_deflate_build_huffman(code_length_lengths)
  let total_lengths = hlit + hdist
  let lengths : Array[Int] = []
  let mut previous = 0
  while lengths.length() < total_lengths {
    let symbol = match png_deflate_decode_huffman(reader, code_length_huffman) {
      Err(error) => return Err(error)
      Ok(symbol) => symbol
    }
    if symbol <= 15 {
      lengths.push(symbol)
      previous = symbol
    } else if symbol == 16 {
      guard lengths.length() > 0 else {
        return Err(PixmapDecodeError::InvalidPngDeflateCode)
      }
      let repeat = match png_deflate_read_bits(reader, 2) {
        Err(error) => return Err(error)
        Ok(bits) => bits + 3
      }
      for _ in 0..<repeat {
        lengths.push(previous)
      }
    } else if symbol == 17 {
      let repeat = match png_deflate_read_bits(reader, 3) {
        Err(error) => return Err(error)
        Ok(bits) => bits + 3
      }
      for _ in 0..<repeat {
        lengths.push(0)
      }
      previous = 0
    } else if symbol == 18 {
      let repeat = match png_deflate_read_bits(reader, 7) {
        Err(error) => return Err(error)
        Ok(bits) => bits + 11
      }
      for _ in 0..<repeat {
        lengths.push(0)
      }
      previous = 0
    } else {
      return Err(PixmapDecodeError::InvalidPngDeflateCode)
    }
    guard lengths.length() <= total_lengths else {
      return Err(PixmapDecodeError::InvalidPngDeflateCode)
    }
  }

  let literal_lengths : Array[Int] = []
  for i in 0..<hlit {
    literal_lengths.push(lengths[i])
  }
  let distance_lengths : Array[Int] = []
  for i in 0..<hdist {
    distance_lengths.push(lengths[hlit + i])
  }
  Ok({
    literal_lengths: png_deflate_build_huffman(literal_lengths),
    distances: png_deflate_build_huffman(distance_lengths),
  })
}

///|
fn png_deflate_build_huffman(code_lengths : Array[Int]) -> PngDeflateHuffman {
  let bit_counts = FixedArray::make(16, 0)
  let mut max_bits = 0
  for length in code_lengths {
    if length > 0 {
      bit_counts[length] = bit_counts[length] + 1
      max_bits = max_bits.max(length)
    }
  }
  let next_codes = FixedArray::make(16, 0)
  let mut code = 0
  for bits in 1..<=15 {
    code = (code + bit_counts[bits - 1]) << 1
    next_codes[bits] = code
  }
  let entries : Array[PngDeflateHuffmanEntry] = []
  for symbol in 0..<code_lengths.length() {
    let length = code_lengths[symbol]
    if length > 0 {
      let canonical = next_codes[length]
      next_codes[length] = canonical + 1
      entries.push({
        symbol,
        length,
        code: png_deflate_reverse_bits(canonical, length),
      })
    }
  }
  { entries, max_bits }
}

///|
fn png_deflate_reverse_bits(value : Int, length : Int) -> Int {
  let mut input = value
  let mut output = 0
  for _ in 0..<length {
    output = (output << 1) | input.land(1)
    input = input >> 1
  }
  output
}

///|
fn png_deflate_decode_huffman(
  reader : PngDeflateBitReader,
  huffman : PngDeflateHuffman,
) -> Result[Int, PixmapDecodeError] {
  guard huffman.max_bits > 0 else {
    return Err(PixmapDecodeError::InvalidPngDeflateCode)
  }
  let mut code = 0
  for length in 1..<=huffman.max_bits {
    let bit = match png_deflate_read_bits(reader, 1) {
      Err(error) => return Err(error)
      Ok(bit) => bit
    }
    code = code | (bit << (length - 1))
    for entry in huffman.entries {
      if entry.length == length && entry.code == code {
        return Ok(entry.symbol)
      }
    }
  }
  Err(PixmapDecodeError::InvalidPngDeflateCode)
}

///|
fn png_deflate_decode_compressed_block(
  reader : PngDeflateBitReader,
  out : Array[Byte],
  literal_lengths : PngDeflateHuffman,
  distances : PngDeflateHuffman,
) -> Result[Unit, PixmapDecodeError] {
  let length_bases : Array[Int] = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
    83, 99, 115, 131, 163, 195, 227, 258,
  ]
  let length_extra_bits : Array[Int] = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5,
    5, 5, 0,
  ]
  let distance_bases : Array[Int] = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
    1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
  ]
  let distance_extra_bits : Array[Int] = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11,
    11, 12, 12, 13, 13,
  ]

  let mut reached_end = false
  while !reached_end {
    let symbol = match png_deflate_decode_huffman(reader, literal_lengths) {
      Err(error) => return Err(error)
      Ok(symbol) => symbol
    }
    if symbol < 256 {
      out.push(symbol.to_byte())
    } else if symbol == 256 {
      reached_end = true
    } else {
      let length_index = symbol - 257
      guard length_index >= 0 && length_index < length_bases.length() else {
        return Err(PixmapDecodeError::InvalidPngDeflateCode)
      }
      let length_extra = match
        png_deflate_read_bits(reader, length_extra_bits[length_index]) {
        Err(error) => return Err(error)
        Ok(bits) => bits
      }
      let length = length_bases[length_index] + length_extra
      let distance_symbol = match
        png_deflate_decode_huffman(reader, distances) {
        Err(error) => return Err(error)
        Ok(symbol) => symbol
      }
      guard distance_symbol >= 0 && distance_symbol < distance_bases.length() else {
        return Err(PixmapDecodeError::InvalidPngDeflateCode)
      }
      let distance_extra = match
        png_deflate_read_bits(reader, distance_extra_bits[distance_symbol]) {
        Err(error) => return Err(error)
        Ok(bits) => bits
      }
      let distance = distance_bases[distance_symbol] + distance_extra
      guard distance > 0 && distance <= out.length() else {
        return Err(PixmapDecodeError::InvalidPngDeflateCode)
      }
      for _ in 0..<length {
        let source = out.length() - distance
        out.push(out[source])
      }
    }
  }
  Ok(())
}

///|
fn decode_png_rgba_pixmap(
  info : PngInfo,
  scanlines : Array[Byte],
) -> Result[Pixmap, PixmapDecodeError] {
  let row_bytes = info.width * 4
  let source_row_bytes = row_bytes + 1
  let expected_len = source_row_bytes * info.height
  guard scanlines.length() == expected_len else {
    return Err(
      PixmapDecodeError::PngScanlineLengthMismatch(
        expected_len,
        scanlines.length(),
      ),
    )
  }
  let pixmap = Pixmap::new(info.width, info.height)
  let dst = pixmap.get_pixels()
  for y in 0..<info.height {
    let source_row = y * source_row_bytes
    let filter_type = scanlines[source_row].to_int()
    guard filter_type >= 0 && filter_type <= 4 else {
      return Err(PixmapDecodeError::UnsupportedPngFilterType(filter_type))
    }
    let dst_row = y * row_bytes
    for i in 0..<row_bytes {
      let left = if i >= 4 { dst[dst_row + i - 4].to_int() } else { 0 }
      let up = if y > 0 { dst[dst_row - row_bytes + i].to_int() } else { 0 }
      let upper_left = if y > 0 && i >= 4 {
        dst[dst_row - row_bytes + i - 4].to_int()
      } else {
        0
      }
      let predictor = match filter_type {
        0 => 0
        1 => left
        2 => up
        3 => (left + up) / 2
        4 => png_paeth_predictor(left, up, upper_left)
        _ => 0
      }
      dst[dst_row + i] = (scanlines[source_row + 1 + i].to_int() + predictor)
        .land(0xFF)
        .to_byte()
    }
  }
  Ok(pixmap)
}

///|
fn png_paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn has_png_signature(data : Bytes) -> Bool {
  data[0] == 137 &&
  data[1] == 80 &&
  data[2] == 78 &&
  data[3] == 71 &&
  data[4] == 13 &&
  data[5] == 10 &&
  data[6] == 26 &&
  data[7] == 10
}

///|
fn append_png_chunk_data(
  out : Array[Byte],
  data : Bytes,
  offset : Int,
  length : Int,
) -> Unit {
  for i in 0..<length {
    out.push(data[offset + i])
  }
}

///|
fn png_chunk_type_is(
  data : Bytes,
  offset : Int,
  b0 : Int,
  b1 : Int,
  b2 : Int,
  b3 : Int,
) -> Bool {
  data[offset].to_int() == b0 &&
  data[offset + 1].to_int() == b1 &&
  data[offset + 2].to_int() == b2 &&
  data[offset + 3].to_int() == b3
}

///|
fn png_chunk_is_unsupported_critical(data : Bytes, offset : Int) -> Bool {
  let is_critical = data[offset].to_int().land(0x20) == 0
  is_critical && !png_chunk_type_is(data, offset, 80, 76, 84, 69)
}

///|
fn png_crc32_chunk_at(
  data : Bytes,
  type_offset : Int,
  data_offset : Int,
  length : Int,
) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for i in 0..<4 {
    crc = png_crc32_update(crc, data[type_offset + i])
  }
  for i in 0..<length {
    crc = png_crc32_update(crc, data[data_offset + i])
  }
  crc ^ 0xFFFFFFFF
}

///|
fn require_png_available(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Result[Unit, PixmapDecodeError] {
  guard offset >= 0 && length >= 0 && offset + length <= data.length() else {
    return Err(
      PixmapDecodeError::UnexpectedEndOfData(offset, length, data.length()),
    )
  }
  Ok(())
}

///|
fn require_png_array_available(
  data : Array[Byte],
  offset : Int,
  length : Int,
) -> Result[Unit, PixmapDecodeError] {
  guard offset >= 0 && length >= 0 && offset + length <= data.length() else {
    return Err(
      PixmapDecodeError::UnexpectedEndOfData(offset, length, data.length()),
    )
  }
  Ok(())
}

///|
fn read_png_u16_le_array_at(data : Array[Byte], offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_png_u32_be_int_at(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() * 16777216 +
  data[offset + 1].to_int() * 65536 +
  data[offset + 2].to_int() * 256 +
  data[offset + 3].to_int()
}

///|
fn read_png_u32_be_uint_at(data : Bytes, offset : Int) -> UInt {
  let b0 = data[offset].to_uint()
  let b1 = data[offset + 1].to_uint()
  let b2 = data[offset + 2].to_uint()
  let b3 = data[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn read_png_u32_be_uint_array_at(data : Array[Byte], offset : Int) -> UInt {
  let b0 = data[offset].to_uint()
  let b1 = data[offset + 1].to_uint()
  let b2 = data[offset + 2].to_uint()
  let b3 = data[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}
