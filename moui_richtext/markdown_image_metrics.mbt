///|
/// Synchronous intrinsic-size lookup for images rendered by markdown.
///
/// The rich-text layout must reserve an image's final box before the
/// renderer ever decodes it, so percentage-width galleries and plain inline
/// images need the intrinsic aspect ratio at projection time. The host
/// registers a byte reader (the native backends read image files from the
/// filesystem); this module only inspects image headers, never pixel data,
/// and stays pure so it compiles for every target. When no reader is
/// registered, or a source cannot be read (remote URLs, missing files,
/// unknown formats), the lookup yields `None` and callers fall back to the
/// placeholder box.
let markdown_image_metrics_reader : Ref[(String) -> Bytes?] = Ref(_ => None)

///|
/// Header sizes keyed by source. `None` values are cached too, so a missing
/// or unreadable file is probed once instead of on every layout pass.
let markdown_image_metrics_sizes : Map[String, @core.Size?] = Map([])

///|
/// Register the host reader that returns the leading bytes of a local image
/// source. Passing a `None`-returning reader restores pure-fallback mode.
pub fn markdown_set_image_metrics_reader(reader : (String) -> Bytes?) -> Unit {
  markdown_image_metrics_reader.val = reader
  markdown_image_metrics_sizes.clear()
}

///|
/// Return the intrinsic pixel size of a resolved image source, or `None`
/// when the format is unknown, the source is remote, or it cannot be read.
pub fn markdown_image_metrics_size(source : String) -> @core.Size? {
  if source == "" ||
    source.has_prefix("http://") ||
    source.has_prefix("https://") ||
    source.has_prefix("data:") ||
    source.has_prefix("file://") {
    None
  } else {
    match markdown_image_metrics_sizes.get(source) {
      Some(cached) => cached
      None => {
        let size = match (markdown_image_metrics_reader.val)(source) {
          Some(bytes) => markdown_image_metrics_size_from_bytes(bytes)
          None => None
        }
        if markdown_image_metrics_sizes.length() >= 1024 {
          markdown_image_metrics_sizes.clear()
        }
        markdown_image_metrics_sizes.set(source, size)
        size
      }
    }
  }
}

///|
/// Parse the intrinsic size from the leading bytes of a PNG, JPEG, GIF,
/// BMP, or WebP image.
pub fn markdown_image_metrics_size_from_bytes(bytes : Bytes) -> @core.Size? {
  let length = bytes.length()
  let size = if length >= 24 &&
    markdown_image_metrics_bytes_are(bytes, 0, [0x89, 0x50, 0x4e, 0x47]) &&
    markdown_image_metrics_bytes_are(bytes, 12, [0x49, 0x48, 0x44, 0x52]) {
    Some(
      @core.Size::new(
        width=markdown_image_metrics_be32(bytes, 16).to_double(),
        height=markdown_image_metrics_be32(bytes, 20).to_double(),
      ),
    )
  } else if length >= 10 &&
    markdown_image_metrics_bytes_are(bytes, 0, [0x47, 0x49, 0x46]) {
    Some(
      @core.Size::new(
        width=markdown_image_metrics_le16(bytes, 6).to_double(),
        height=markdown_image_metrics_le16(bytes, 8).to_double(),
      ),
    )
  } else if length >= 26 &&
    markdown_image_metrics_bytes_are(bytes, 0, [0x42, 0x4d]) {
    let height = markdown_image_metrics_le32(bytes, 22)
    Some(
      @core.Size::new(
        width=markdown_image_metrics_le32(bytes, 18).to_double(),
        height=(if height < 0 { -height } else { height }).to_double(),
      ),
    )
  } else if length >= 25 &&
    markdown_image_metrics_bytes_are(bytes, 0, [0x52, 0x49, 0x46, 0x46]) &&
    markdown_image_metrics_bytes_are(bytes, 8, [0x57, 0x45, 0x42, 0x50]) {
    markdown_image_metrics_webp_size(bytes, length)
  } else if length >= 12 &&
    markdown_image_metrics_bytes_are(bytes, 0, [0xff, 0xd8]) {
    markdown_image_metrics_jpeg_size(bytes, length)
  } else {
    None
  }
  match size {
    Some(size) if size.width > 0.0 && size.height > 0.0 => Some(size)
    _ => None
  }
}

///|
fn markdown_image_metrics_webp_size(bytes : Bytes, length : Int) -> @core.Size? {
  if markdown_image_metrics_byte(bytes, 12) != 0x56 ||
    markdown_image_metrics_byte(bytes, 13) != 0x50 ||
    markdown_image_metrics_byte(bytes, 14) != 0x38 {
    return None
  }
  match markdown_image_metrics_byte(bytes, 15) {
    // "VP8 ": lossy; the dimensions sit behind the start-code at 23..25.
    0x20 =>
      if length >= 30 {
        Some(
          @core.Size::new(
            width=(markdown_image_metrics_le16(bytes, 26) & 0x3fff).to_double(),
            height=(markdown_image_metrics_le16(bytes, 28) & 0x3fff).to_double(),
          ),
        )
      } else {
        None
      }
    // "VP8L": the 14-bit width-1/height-1 pair follows the 0x2f signature.
    0x4c =>
      if length >= 25 {
        let bits = markdown_image_metrics_le32(bytes, 21)
        Some(
          @core.Size::new(
            width=((bits & 0x3fff) + 1).to_double(),
            height=(((bits >> 14) & 0x3fff) + 1).to_double(),
          ),
        )
      } else {
        None
      }
    // "VP8X": 24-bit canvas size minus one at 24 and 27.
    0x58 =>
      if length >= 30 {
        Some(
          @core.Size::new(
            width=(markdown_image_metrics_le24(bytes, 24) + 1).to_double(),
            height=(markdown_image_metrics_le24(bytes, 27) + 1).to_double(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
/// Scan JPEG marker segments for a start-of-frame carrying the dimensions.
fn markdown_image_metrics_jpeg_size(bytes : Bytes, length : Int) -> @core.Size? {
  let mut index = 2
  while index + 9 <= length {
    if markdown_image_metrics_byte(bytes, index) != 0xff {
      index = index + 1
      continue
    }
    let marker = markdown_image_metrics_byte(bytes, index + 1)
    if marker == 0xff {
      index = index + 1
      continue
    }
    // Standalone markers (RST, SOI, EOI, TEM) carry no length field.
    if (marker >= 0xd0 && marker <= 0xd9) || marker == 0x01 {
      index = index + 2
      continue
    }
    if (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf) {
      return Some(
        @core.Size::new(
          width=markdown_image_metrics_be16(bytes, index + 7).to_double(),
          height=markdown_image_metrics_be16(bytes, index + 5).to_double(),
        ),
      )
    }
    index = index + 2 + markdown_image_metrics_be16(bytes, index + 2)
  }
  None
}

///|
fn markdown_image_metrics_byte(bytes : Bytes, index : Int) -> Int {
  match bytes.get(index) {
    Some(byte) => byte.to_int()
    None => -1
  }
}

///|
fn markdown_image_metrics_bytes_are(
  bytes : Bytes,
  start : Int,
  expected : Array[Int],
) -> Bool {
  for offset, want in expected {
    if markdown_image_metrics_byte(bytes, start + offset) != want {
      return false
    }
  }
  true
}

///|
fn markdown_image_metrics_be16(bytes : Bytes, start : Int) -> Int {
  (markdown_image_metrics_byte(bytes, start) << 8) |
  markdown_image_metrics_byte(bytes, start + 1)
}

///|
fn markdown_image_metrics_be32(bytes : Bytes, start : Int) -> Int {
  (markdown_image_metrics_be16(bytes, start) << 16) |
  markdown_image_metrics_be16(bytes, start + 2)
}

///|
fn markdown_image_metrics_le16(bytes : Bytes, start : Int) -> Int {
  markdown_image_metrics_byte(bytes, start) |
  (markdown_image_metrics_byte(bytes, start + 1) << 8)
}

///|
fn markdown_image_metrics_le24(bytes : Bytes, start : Int) -> Int {
  markdown_image_metrics_le16(bytes, start) |
  (markdown_image_metrics_byte(bytes, start + 2) << 16)
}

///|
fn markdown_image_metrics_le32(bytes : Bytes, start : Int) -> Int {
  markdown_image_metrics_le16(bytes, start) |
  (markdown_image_metrics_le16(bytes, start + 2) << 16)
}
