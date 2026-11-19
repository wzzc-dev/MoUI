///|
/// Minimal PNG decoder used by `load_image` for synchronous data URIs.
/// Supports 8-bit RGB/RGBA, filter types 0-4, and non-interlaced images.

///|
fn png_u32(bytes : Bytes, offset : Int32) -> Int32 {
  let value = (bytes[offset].to_uint() << 24) |
    (bytes[offset + 1].to_uint() << 16) |
    (bytes[offset + 2].to_uint() << 8) |
    bytes[offset + 3].to_uint()
  value.reinterpret_as_int()
}

///|
fn png_chunk_is(
  bytes : Bytes,
  offset : Int32,
  a : Byte,
  b : Byte,
  c : Byte,
  d : Byte,
) -> Bool {
  bytes[offset] == a &&
  bytes[offset + 1] == b &&
  bytes[offset + 2] == c &&
  bytes[offset + 3] == d
}

///|
fn png_paeth(a : Int32, b : Int32, c : Int32) -> Int32 {
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
fn png_unfilter(
  raw : Bytes,
  width : Int32,
  height : Int32,
  channels : Int32,
) -> FixedArray[Byte]? {
  let stride = width * channels
  let expected = (stride + 1) * height
  if raw.length() < expected {
    return None
  }
  let out = FixedArray::make(width * height * 4, (0 : Byte))
  let previous = FixedArray::make(stride, (0 : Int32))
  let current = FixedArray::make(stride, (0 : Int32))
  for y in 0..<height {
    let row_start = y * (stride + 1)
    let filter = raw[row_start].to_uint().reinterpret_as_int()
    for x in 0..<stride {
      current[x] = raw[row_start + 1 + x].to_uint().reinterpret_as_int()
    }
    for x in 0..<stride {
      let left = if x >= channels { current[x - channels] } else { 0 }
      let up = previous[x]
      let up_left = if x >= channels { previous[x - channels] } else { 0 }
      let value = match filter {
        0 => current[x]
        1 => current[x] + left
        2 => current[x] + up
        3 => current[x] + (left + up) / 2
        4 => current[x] + png_paeth(left, up, up_left)
        _ => return None
      }
      current[x] = value & 0xFF
    }
    for x in 0..<width {
      let source = x * channels
      let destination = (y * width + x) * 4
      out[destination] = current[source].to_byte()
      out[destination + 1] = current[source + 1].to_byte()
      out[destination + 2] = current[source + 2].to_byte()
      out[destination + 3] = if channels == 4 {
        current[source + 3].to_byte()
      } else {
        (255 : Byte)
      }
    }
    for x in 0..<stride {
      previous[x] = current[x]
    }
  }
  Some(out)
}

///|
fn png_base64_decode(payload : String) -> Bytes? {
  try @base64.decode(payload, ignore_whitespace=true) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn png_zlib_decompress(data : Bytes) -> Bytes? {
  try @zlib.decompress(data) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
/// Decodes an 8-bit non-interlaced RGB/RGBA PNG into an Image.
pub fn Image::from_png_bytes(bytes : Bytes) -> Image? {
  if bytes.length() < 8 ||
    bytes[0].to_uint() != 137 ||
    bytes[1].to_uint() != 80 ||
    bytes[2].to_uint() != 78 ||
    bytes[3].to_uint() != 71 ||
    bytes[4].to_uint() != 13 ||
    bytes[5].to_uint() != 10 ||
    bytes[6].to_uint() != 26 ||
    bytes[7].to_uint() != 10 {
    return None
  }
  let idat : Array[Byte] = []
  let mut width = 0
  let mut height = 0
  let mut color_type = 0
  let mut bit_depth = 0
  let mut interlace = 0
  let mut has_header = false
  let mut position = 8
  while position + 8 <= bytes.length() {
    let length = png_u32(bytes, position)
    if length < 0 || position + 8 + length + 4 > bytes.length() {
      return None
    }
    let data_start = position + 8
    if png_chunk_is(bytes, position + 4, 73, 72, 68, 82) {
      if length < 13 {
        return None
      }
      width = png_u32(bytes, data_start)
      height = png_u32(bytes, data_start + 4)
      bit_depth = bytes[data_start + 8].to_uint().reinterpret_as_int()
      color_type = bytes[data_start + 9].to_uint().reinterpret_as_int()
      interlace = bytes[data_start + 12].to_uint().reinterpret_as_int()
      has_header = true
    } else if png_chunk_is(bytes, position + 4, 73, 68, 65, 84) {
      for index in 0..<length {
        idat.push(bytes[data_start + index])
      }
    } else if png_chunk_is(bytes, position + 4, 73, 69, 78, 68) {
      break
    }
    position = data_start + length + 4
  }
  if !has_header ||
    width <= 0 ||
    height <= 0 ||
    bit_depth != 8 ||
    interlace != 0 ||
    (color_type != 2 && color_type != 6) {
    return None
  }
  let channels = if color_type == 6 { 4 } else { 3 }
  let raw = match png_zlib_decompress(Bytes::from_array(idat)) {
    Some(raw) => raw
    None => return None
  }
  match png_unfilter(raw, width, height, channels) {
    Some(pixels) => {
      let image = Image::new(width, height)
      image.pixels = pixels
      Some(image)
    }
    None => None
  }
}

///|
/// Loads a PNG image from a `data:image/png;base64,` URI, a local file path,
/// or a `file://` path. Returns `None` when the source is unsupported, cannot
/// be read through this sketch's `FilePorts`, or does not decode as an 8-bit
/// non-interlaced PNG.
///
/// HTTP(S) URLs are intentionally not fetched here: synchronous host I/O would
/// block the frame. Hosts that need URL loading should download the bytes and
/// call `Image::from_png_bytes`, or wire an async loader at the app layer.
///
/// Local paths are read through the ports injected at construction time (or
/// installed with `set_default_file_ports`), so the addon itself never depends
/// on a concrete filesystem.
pub fn Sketch::try_load_image(self : Sketch, source : String) -> Image? {
  if source.has_prefix("data:image/png;base64,") {
    let payload = source[22:].to_owned()
    match png_base64_decode(payload) {
      Some(bytes) => Image::from_png_bytes(bytes)
      None => None
    }
  } else if source.has_prefix("data:") {
    None
  } else if source.has_prefix("http://") || source.has_prefix("https://") {
    None
  } else {
    let path = if source.has_prefix("file://") {
      source[7:].to_owned()
    } else {
      source
    }
    match self.file_ports.load(path) {
      Some(bytes) => Image::from_png_bytes(bytes)
      None => None
    }
  }
}

///|
/// Synchronous `load_image`. Decodes PNG data URIs and local PNG files; other
/// sources fall back to a 1x1 transparent placeholder, matching p5's
/// "always return an image" contract. Use `try_load_image` to detect failure.
pub fn Sketch::load_image(
  self : Sketch,
  source : String,
  on_load~ : (Image) -> Unit = _ => (),
) -> Image {
  let image = match self.try_load_image(source) {
    Some(image) => image
    None => Image::new(1, 1)
  }
  on_load(image)
  image
}

///|
/// Installs a host byte fetcher used by `load_image_async` when the source
/// cannot be resolved synchronously (typically `https:`).
pub fn Sketch::set_image_fetcher(self : Sketch, fetcher : ImageFetcher) -> Unit {
  self.image_fetcher = Some(fetcher)
}

///|
/// Removes the host byte fetcher; later `load_image_async` calls fall back to
/// the synchronous paths only.
pub fn Sketch::clear_image_fetcher(self : Sketch) -> Unit {
  self.image_fetcher = None
}

///|
/// Non-blocking `load_image`. Data URIs and local files decode synchronously.
/// For other sources the sketch returns a 1x1 transparent placeholder
/// immediately and hands the source to the installed `ImageFetcher`; when the
/// host completes with PNG bytes, the placeholder is filled in place and
/// `on_load` receives that same image object. A failed fetch or decode leaves
/// the placeholder untouched and still calls `on_load`, so callers can poll
/// `image.width() > 1` or keep their own state.
///
/// The completion must run on the host's event loop (the same thread that owns
/// the sketch). p5 marks the sketch for a redraw; a looping view presents it on
/// the next frame, while a paused (`no_loop`) app should also trigger its own
/// repaint from `on_load`.
pub fn Sketch::load_image_async(
  self : Sketch,
  source : String,
  on_load~ : (Image) -> Unit = _ => (),
) -> Image {
  match self.try_load_image(source) {
    Some(image) => {
      on_load(image)
      image
    }
    None => {
      let placeholder = Image::new(1, 1)
      match self.image_fetcher {
        Some(fetch) => {
          let completed = Ref(false)
          fetch(source, bytes => {
            if completed.val {
              return ()
            }
            completed.val = true
            match bytes {
              Some(bytes) =>
                match Image::from_png_bytes(bytes) {
                  Some(loaded) => {
                    placeholder.adopt(loaded)
                    self.request_redraw()
                  }
                  None => ()
                }
              None => ()
            }
            on_load(placeholder)
          })
        }
        None => on_load(placeholder)
      }
      placeholder
    }
  }
}
