///|
/// Error returned when decoding pixmap bytes.
pub(all) enum PixmapDecodeError {
  UnexpectedEndOfData(Int, Int, Int)
  InvalidRgbaDimensions(Int, Int)
  RgbaByteLengthMismatch(Int, Int)
  InvalidBmpSignature(Byte, Byte)
  UnsupportedBmpHeaderSize(Int)
  UnsupportedBmpColorPlanes(Int)
  UnsupportedBmpBitsPerPixel(Int)
  UnsupportedBmpCompression(Int)
  InvalidBmpDimensions(Int, Int)
  BmpPixelDataOutOfBounds(Int, Int, Int)
  InvalidPngSignature
  MissingPngImageHeader
  MissingPngImageData
  MissingPngImageEnd
  UnsupportedPngHeaderSize(Int)
  UnsupportedPngBitDepth(Int)
  UnsupportedPngColorType(Int)
  UnsupportedPngCompression(Int)
  UnsupportedPngFilter(Int)
  UnsupportedPngInterlace(Int)
  UnsupportedPngChunk(Int, Int, Int, Int)
  UnsupportedPngDeflateCompression(Int)
  UnsupportedPngDeflatePresetDictionary
  UnsupportedPngDeflateBlockType(Int)
  InvalidPngDeflateCode
  UnsupportedPngFilterType(Int)
  InvalidPngDimensions(Int, Int)
  InvalidPngZlibHeader(Int, Int)
  PngCrcMismatch(UInt, UInt)
  PngAdlerMismatch(UInt, UInt)
  PngStoredBlockLengthMismatch(Int, Int)
  PngInflateLengthMismatch(Int, Int)
  PngScanlineLengthMismatch(Int, Int)
} derive(Eq, Debug)

///|
/// Error returned when encoding pixmap bytes.
pub(all) enum PixmapEncodeError {
  InvalidPngDimensions(Int, Int)
} derive(Eq, Debug)

///|
/// Return an isolated copy of the raw RGBA pixel bytes in row-major order.
pub fn Pixmap::to_rgba_bytes(self : Pixmap) -> Bytes {
  rgba_bytes_from_pixels(self.pixels)
}

///|
/// Encode this pixmap as a binary PPM (P6) image, dropping the alpha channel.
/// The result is a deterministic, dependency-free fixture format for headless
/// render tests and simple CPU-rendered pixel dumps.
pub fn Pixmap::to_ppm_bytes(self : Pixmap) -> Bytes {
  let out : Array[Byte] = []
  append_ppm_header(out, self.width, self.height)
  for y in 0..<self.height {
    for x in 0..<self.width {
      let offset = (y * self.width + x) * 4
      out.push(self.pixels[offset])
      out.push(self.pixels[offset + 1])
      out.push(self.pixels[offset + 2])
    }
  }
  Bytes::from_array(out)
}

///|
/// Encode this pixmap as a deterministic 32-bit BMP image.
///
/// Pixels are written in standard bottom-up BMP row order with BGRA channels,
/// preserving the pixmap alpha channel for tools that understand 32-bit BMP.
pub fn Pixmap::to_bmp_bytes(self : Pixmap) -> Bytes {
  let out : Array[Byte] = []
  append_bmp_header(out, self.width, self.height)
  for y_offset in 0..<self.height {
    let y = self.height - 1 - y_offset
    for x in 0..<self.width {
      let offset = (y * self.width + x) * 4
      out.push(self.pixels[offset + 2])
      out.push(self.pixels[offset + 1])
      out.push(self.pixels[offset])
      out.push(self.pixels[offset + 3])
    }
  }
  Bytes::from_array(out)
}

///|
/// Decode tightly packed RGBA bytes into a pixmap.
///
/// The input must contain exactly `width * height * 4` bytes in row-major
/// RGBA order. Decoded pixels are copied so later mutations to the returned
/// pixmap cannot alias caller-owned byte storage.
pub fn Pixmap::from_rgba_bytes(
  width : Int,
  height : Int,
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  guard width >= 0 && height >= 0 else {
    return Err(PixmapDecodeError::InvalidRgbaDimensions(width, height))
  }
  let expected_len = width * height * 4
  guard data.length() == expected_len else {
    return Err(
      PixmapDecodeError::RgbaByteLengthMismatch(expected_len, data.length()),
    )
  }
  let pixmap = Pixmap::new(width, height)
  let pixels = pixmap.get_pixels()
  for i in 0..<expected_len {
    pixels[i] = data[i]
  }
  Ok(pixmap)
}

///|
/// Decode a 24-bit or 32-bit BMP image into an RGBA pixmap.
///
/// This intentionally supports uncompressed BMP images with BGR/BGRA pixels.
/// Both bottom-up and top-down BMP row order are accepted.
pub fn Pixmap::from_bmp_bytes(
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  match decode_bmp_info(data) {
    Err(error) => Err(error)
    Ok(info) => Ok(decode_bmp_pixmap(data, info))
  }
}

///|
fn rgba_bytes_from_pixels(pixels : FixedArray[Byte]) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<pixels.length() {
    out.push(pixels[i])
  }
  Bytes::from_array(out)
}

///|
fn append_ppm_header(out : Array[Byte], width : Int, height : Int) -> Unit {
  append_ppm_byte(out, 80) // P
  append_ppm_byte(out, 54) // 6
  append_ppm_byte(out, 10)
  append_ppm_decimal(out, width)
  append_ppm_byte(out, 32)
  append_ppm_decimal(out, height)
  append_ppm_byte(out, 10)
  append_ppm_byte(out, 50) // 2
  append_ppm_byte(out, 53) // 5
  append_ppm_byte(out, 53) // 5
  append_ppm_byte(out, 10)
}

///|
fn append_ppm_decimal(out : Array[Byte], value : Int) -> Unit {
  let mut n = value
  if n == 0 {
    append_ppm_byte(out, 48)
  } else {
    if n < 0 {
      append_ppm_byte(out, 45)
      n = 0 - n
    }
    let digits : Array[Byte] = []
    while n > 0 {
      digits.push((48 + n % 10).to_byte())
      n = n / 10
    }
    for i in 0..<digits.length() {
      out.push(digits[digits.length() - 1 - i])
    }
  }
}

///|
fn append_ppm_byte(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
}

///|
fn append_bmp_header(out : Array[Byte], width : Int, height : Int) -> Unit {
  let pixel_byte_count = width * height * 4
  append_bmp_u16_le(out, 0x4D42) // BM
  append_bmp_u32_le(out, 54 + pixel_byte_count)
  append_bmp_u16_le(out, 0)
  append_bmp_u16_le(out, 0)
  append_bmp_u32_le(out, 54)

  append_bmp_u32_le(out, 40)
  append_bmp_u32_le(out, width)
  append_bmp_u32_le(out, height)
  append_bmp_u16_le(out, 1)
  append_bmp_u16_le(out, 32)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, pixel_byte_count)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
  append_bmp_u32_le(out, 0)
}

///|
fn append_bmp_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value / 256).land(0xFF).to_byte())
}

///|
fn append_bmp_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
  out.push((value / 256).land(0xFF).to_byte())
  out.push((value / 65536).land(0xFF).to_byte())
  out.push((value / 16777216).land(0xFF).to_byte())
}

///|
struct BmpInfo {
  pixel_offset : Int
  width : Int
  height : Int
  is_top_down : Bool
  bytes_per_pixel : Int
  source_row_bytes : Int
} derive(Debug)

///|
fn decode_bmp_info(data : Bytes) -> Result[BmpInfo, PixmapDecodeError] {
  guard data.length() >= 54 else {
    return Err(PixmapDecodeError::UnexpectedEndOfData(0, 54, data.length()))
  }
  guard data[0] == 66 && data[1] == 77 else {
    return Err(PixmapDecodeError::InvalidBmpSignature(data[0], data[1]))
  }
  let pixel_offset = read_u32_le_at(data, 10)
  let header_size = read_u32_le_at(data, 14)
  guard header_size >= 40 else {
    return Err(PixmapDecodeError::UnsupportedBmpHeaderSize(header_size))
  }
  let width = read_i32_le_at(data, 18)
  let raw_height = read_i32_le_at(data, 22)
  guard width > 0 && raw_height != 0 else {
    return Err(PixmapDecodeError::InvalidBmpDimensions(width, raw_height))
  }
  let color_planes = read_u16_le_at(data, 26)
  guard color_planes == 1 else {
    return Err(PixmapDecodeError::UnsupportedBmpColorPlanes(color_planes))
  }
  let bits_per_pixel = read_u16_le_at(data, 28)
  guard bits_per_pixel == 24 || bits_per_pixel == 32 else {
    return Err(PixmapDecodeError::UnsupportedBmpBitsPerPixel(bits_per_pixel))
  }
  let compression = read_u32_le_at(data, 30)
  guard compression == 0 else {
    return Err(PixmapDecodeError::UnsupportedBmpCompression(compression))
  }
  let height = raw_height.abs()
  let bytes_per_pixel = bits_per_pixel / 8
  let source_row_bytes = (width * bits_per_pixel + 31) / 32 * 4
  let required_len = pixel_offset + source_row_bytes * height
  guard data.length() >= required_len else {
    return Err(
      PixmapDecodeError::BmpPixelDataOutOfBounds(
        pixel_offset,
        required_len,
        data.length(),
      ),
    )
  }
  Ok({
    pixel_offset,
    width,
    height,
    is_top_down: raw_height < 0,
    bytes_per_pixel,
    source_row_bytes,
  })
}

///|
fn decode_bmp_pixmap(data : Bytes, info : BmpInfo) -> Pixmap {
  let pixmap = Pixmap::new(info.width, info.height)
  let dst = pixmap.get_pixels()
  let dst_row_bytes = info.width * 4
  for y in 0..<info.height {
    let source_y = if info.is_top_down { y } else { info.height - 1 - y }
    let source_row = info.pixel_offset + source_y * info.source_row_bytes
    let dst_row = y * dst_row_bytes
    for x in 0..<info.width {
      let source_offset = source_row + x * info.bytes_per_pixel
      let dst_offset = dst_row + x * 4
      dst[dst_offset] = data[source_offset + 2]
      dst[dst_offset + 1] = data[source_offset + 1]
      dst[dst_offset + 2] = data[source_offset]
      dst[dst_offset + 3] = if info.bytes_per_pixel == 4 {
        data[source_offset + 3]
      } else {
        255
      }
    }
  }
  pixmap
}

///|
fn read_u16_le_at(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_u32_le_at(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn read_i32_le_at(data : Bytes, offset : Int) -> Int {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let signed_b3 = if b3 >= 128 { b3 - 256 } else { b3 }
  b0 + b1 * 256 + b2 * 65536 + signed_b3 * 16777216
}
