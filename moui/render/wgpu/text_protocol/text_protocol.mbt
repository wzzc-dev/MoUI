///|
pub let native_measure_layout_protocol_version : Int = 1

///|
pub let native_run_layout_protocol_version : Int = 1

///|
pub let native_raster_glyph_protocol_version : Int = 1

///|
pub let native_font_registration_protocol_version : Int = 1

///|
pub(all) struct NativeFontRegistrationPayload {
  family_name : Bytes
  data : Bytes
}

///|
pub let native_font_spec_protocol_version : Int = 1

///|
pub(all) struct NativeFontSpecPayload {
  size : Double
  size_key : Int
  weight : Int
  style : @core.FontStyle
  family_names : Array[Bytes]
}

///|
pub fn native_utf32_bytes(text : String) -> Bytes {
  let out : Array[Byte] = []
  for ch in text {
    let code = ch.to_int()
    out.push((code & 0xFF).to_byte())
    out.push(((code >> 8) & 0xFF).to_byte())
    out.push(((code >> 16) & 0xFF).to_byte())
    out.push(((code >> 24) & 0xFF).to_byte())
  }
  Bytes::from_array(out)
}

///|
pub fn native_font_style_code(style : @core.FontStyle) -> Int {
  match style {
    @core.FontStyle::Normal => 0
    @core.FontStyle::Italic => 1
  }
}

///|
fn native_font_style_from_code(code : Int) -> @core.FontStyle? {
  match code {
    0 => Some(@core.FontStyle::Normal)
    1 => Some(@core.FontStyle::Italic)
    _ => None
  }
}

///|
pub fn native_font_spec_bytes(font : @core.FontSpec) -> Bytes {
  let families = if font.families.families.is_empty() {
    [@core.FontFamily::SystemUi]
  } else {
    font.families.families
  }
  let out : Array[Byte] = []
  push_i32_le(out, native_font_spec_protocol_version)
  push_i32_le(out, native_font_size_key(font.size))
  push_i32_le(out, font.weight)
  push_i32_le(out, native_font_style_code(font.style))
  push_i32_le(out, families.length())
  for family in families {
    let name = @utf8.encode(family.css_name()[:], bom=false)
    push_i32_le(out, name.length())
    for byte in name {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}

///|
pub fn native_font_spec_from_bytes(bytes : Bytes) -> NativeFontSpecPayload? {
  if bytes.length() < 20 {
    return None
  }
  let version = i32_le(bytes, 0)
  let size_key = i32_le(bytes, 4)
  let weight = i32_le(bytes, 8)
  let style_code = i32_le(bytes, 12)
  let family_count = i32_le(bytes, 16)
  guard native_font_style_from_code(style_code) is Some(style) else {
    return None
  }
  if version != native_font_spec_protocol_version ||
    size_key <= 0 ||
    family_count <= 0 {
    return None
  }
  let family_names : Array[Bytes] = []
  let mut offset = 20
  for index in 0..<family_count {
    let _ = index
    if offset + 4 > bytes.length() {
      return None
    }
    let name_len = i32_le(bytes, offset)
    if name_len <= 0 || name_len > bytes.length() - offset - 4 {
      return None
    }
    let name_start = offset + 4
    family_names.push(
      Bytes::from_array(bytes[name_start:name_start + name_len].to_array()),
    )
    offset = name_start + name_len
  }
  if offset != bytes.length() {
    return None
  }
  Some({
    size: size_key.to_double() / 64.0,
    size_key,
    weight,
    style,
    family_names,
  })
}

///|
pub fn native_font_registration_bytes(
  family_name~ : Bytes,
  data~ : Bytes,
) -> Bytes {
  let out : Array[Byte] = []
  push_i32_le(out, native_font_registration_protocol_version)
  push_i32_le(out, family_name.length())
  push_i32_le(out, data.length())
  for byte in family_name {
    out.push(byte)
  }
  for byte in data {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
fn native_font_size_key(size : Double) -> Int {
  (size * 64.0).to_int()
}

///|
pub fn native_font_registration_from_bytes(
  bytes : Bytes,
) -> NativeFontRegistrationPayload? {
  if bytes.length() < 12 {
    return None
  }
  let version = i32_le(bytes, 0)
  let family_name_len = i32_le(bytes, 4)
  let data_len = i32_le(bytes, 8)
  if version != native_font_registration_protocol_version ||
    family_name_len <= 0 ||
    data_len <= 0 ||
    family_name_len > bytes.length() - 12 ||
    data_len > bytes.length() - 12 - family_name_len ||
    bytes.length() != 12 + family_name_len + data_len {
    return None
  }
  Some({
    family_name: Bytes::from_array(bytes[12:12 + family_name_len].to_array()),
    data: Bytes::from_array(
      bytes[12 + family_name_len:12 + family_name_len + data_len].to_array(),
    ),
  })
}

///|
pub fn native_measure_layout_from_bytes(
  input : @core.TextLayoutInput,
  bytes : Bytes,
) -> @wgpu_renderer.NativeTextLayout? {
  if bytes.length() < 24 {
    return None
  }
  let count = i32_le(bytes, 0)
  let version = i32_le(bytes, 4)
  let height = double_le(bytes, 8)
  let baseline = double_le(bytes, 16)
  let caret_count = count + 1
  if version != native_measure_layout_protocol_version ||
    count < 0 ||
    height <= 0.0 ||
    baseline <= 0.0 ||
    bytes.length() != 24 + caret_count * 8 {
    return None
  }
  let carets : Array[Double] = []
  for index in 0..<caret_count {
    let caret = double_le(bytes, 24 + index * 8)
    if index > 0 && caret < carets[index - 1] {
      return None
    }
    carets.push(caret)
  }
  let width = if carets.is_empty() { 0.0 } else { carets[carets.length() - 1] }
  let final_width = match input.max_width {
    Some(max_width) => width.min(max_width)
    None => width
  }
  match input.max_width {
    Some(max_width) =>
      for index in 0..<carets.length() {
        carets[index] = carets[index].min(max_width)
      }
    None => ()
  }
  Some(
    @wgpu_renderer.NativeTextLayout::new(
      size=@core.Size::new(width=final_width, height~),
      baseline~,
      caret_positions=carets,
    ),
  )
}

///|
pub fn native_run_layout_from_bytes(
  bytes : Bytes,
) -> @wgpu_renderer.NativeTextLayout? {
  if bytes.length() < 32 {
    return None
  }
  let version = i32_le(bytes, 0)
  let glyph_count = i32_le(bytes, 4)
  let width = double_le(bytes, 8)
  let height = double_le(bytes, 16)
  let baseline = double_le(bytes, 24)
  if version != native_run_layout_protocol_version ||
    glyph_count < 0 ||
    width < 0.0 ||
    height <= 0.0 ||
    baseline < 0.0 {
    return None
  }
  let glyphs : Array[@wgpu_renderer.NativeGlyphPlacement] = []
  let mut offset = 32
  for index in 0..<glyph_count {
    let _ = index
    if offset + 24 > bytes.length() {
      return None
    }
    let cache_key_len = i32_le(bytes, offset + 16)
    let payload_len = i32_le(bytes, offset + 20)
    if cache_key_len <= 0 ||
      payload_len <= 0 ||
      cache_key_len > bytes.length() - offset - 24 ||
      payload_len > bytes.length() - offset - 24 - cache_key_len {
      return None
    }
    let data_offset = offset + 24
    let cache_key = bytes_to_cache_key(
      bytes,
      offset=data_offset,
      length=cache_key_len,
    )
    let payload_bytes : Array[Byte] = []
    for payload_offset in 0..<payload_len {
      payload_bytes.push(bytes[data_offset + cache_key_len + payload_offset])
    }
    let payload = Bytes::from_array(payload_bytes)
    glyphs.push(
      @wgpu_renderer.NativeGlyphPlacement::new(
        key=@wgpu_renderer.native_platform_glyph_key(cache_key~, payload~),
        x=double_le(bytes, offset),
        y=double_le(bytes, offset + 8),
      ),
    )
    offset = offset + 24 + cache_key_len + payload_len
  }
  if offset != bytes.length() {
    return None
  }
  Some(
    @wgpu_renderer.NativeTextLayout::new(
      size=@core.Size::new(width~, height~),
      baseline~,
      glyphs~,
    ),
  )
}

///|
pub fn native_raster_glyph_from_bytes(
  bytes : Bytes,
) -> @wgpu_renderer.NativeRasterGlyph? {
  if bytes.length() < 32 {
    return None
  }
  let width = i32_le(bytes, 0)
  let height = i32_le(bytes, 4)
  let version = i32_le(bytes, 16)
  if version != native_raster_glyph_protocol_version ||
    width <= 0 ||
    height <= 0 ||
    width > (bytes.length() - 32) / height {
    return None
  }
  let pixel_len = width * height
  let pixels : Array[Byte] = []
  for index in 0..<pixel_len {
    pixels.push(bytes[32 + index])
  }
  Some(
    @wgpu_renderer.NativeRasterGlyph::new(
      width~,
      height~,
      bearing_x=i32_le(bytes, 8),
      bearing_y=i32_le(bytes, 12),
      pixels=Bytes::from_array(pixels),
    ),
  )
}

///|
fn i32_le(bytes : Bytes, offset : Int) -> Int {
  if offset + 3 >= bytes.length() {
    return 0
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  let b2 = bytes[offset + 2].to_int()
  let b3 = bytes[offset + 3].to_int()
  let value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  if b3 >= 128 {
    value - 2147483647 - 2147483647 - 2
  } else {
    value
  }
}

///|
fn push_i32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn bytes_to_cache_key(bytes : Bytes, offset~ : Int, length~ : Int) -> String {
  let mut out = "\{length}:"
  for index in 0..<length {
    out = out + "\{bytes[offset + index].to_int()},"
  }
  out
}

///|
fn double_le(bytes : Bytes, offset : Int) -> Double {
  if offset + 7 >= bytes.length() {
    return 0.0
  }
  let mut bits : UInt64 = 0UL
  for index in 0..<8 {
    bits = bits | (bytes[offset + index].to_uint64() << (index * 8))
  }
  bits.reinterpret_as_double()
}
