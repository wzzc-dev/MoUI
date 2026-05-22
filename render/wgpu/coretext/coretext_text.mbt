///|
let coretext_run_protocol_version : Int = 1

///|
let coretext_glyph_payload_protocol_version : Int = 1

///|
priv struct CoreTextGlyphKey {
  glyph_id : Int
  font_name : Bytes
  size_key : Int
  weight : Int
  style : @core.FontStyle
  scale_key : Int
}

///|
pub fn coretext_text_engine() -> @wgpu_renderer.NativeTextEngine {
  @wgpu_renderer.native_platform_text_engine(
    @wgpu_renderer.NativePlatformTextProvider::new(
      id="native-wgpu-coretext-system",
      measure=coretext_measure_layout,
      layout_run=coretext_layout_for_run,
      raster_glyph=payload => {
        match coretext_glyph_key_from_payload(payload) {
          Some(key) => coretext_raster_glyph(key)
          None => None
        }
      },
      register_font_data=coretext_register_font_data,
    ),
  )
}

///|
fn coretext_register_font_data(family : @core.FontFamily, data : Bytes) -> Unit {
  ignore(
    macos_coretext_register_font_data(
      @text_protocol.native_font_registration_bytes(
        family_name=@utf8.encode(family.css_name()[:], bom=false),
        data~,
      ),
    ),
  )
}

///|
fn coretext_style_code(style : @core.FontStyle) -> Int {
  @text_protocol.native_font_style_code(style)
}

///|
fn coretext_style_from_code(code : Int) -> @core.FontStyle? {
  match code {
    0 => Some(@core.FontStyle::Normal)
    1 => Some(@core.FontStyle::Italic)
    _ => None
  }
}

///|
fn coretext_size_key(size : Double) -> Int {
  (size * 64.0).to_int()
}

///|
fn coretext_scale_key(scale : Double) -> Int {
  (scale * 64.0).to_int()
}

///|
fn coretext_text_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn coretext_glyph_cache_key(key : CoreTextGlyphKey) -> String {
  "ctg:\{key.glyph_id}:\{coretext_font_cache_key(key.font_name)}:\{key.size_key}:\{key.weight}:\{coretext_style_code(key.style)}:\{key.scale_key}"
}

///|
fn coretext_glyph_payload(key : CoreTextGlyphKey) -> Bytes {
  let out : Array[Byte] = []
  push_i32_le(out, coretext_glyph_payload_protocol_version)
  push_i32_le(out, key.glyph_id)
  push_i32_le(out, key.size_key)
  push_i32_le(out, key.weight)
  push_i32_le(out, coretext_style_code(key.style))
  push_i32_le(out, key.scale_key)
  push_i32_le(out, key.font_name.length())
  for byte in key.font_name {
    out.push(byte)
  }
  Bytes::from_array(out)
}

///|
fn coretext_glyph_key_from_payload(payload : Bytes) -> CoreTextGlyphKey? {
  if payload.length() < 28 ||
    i32_le(payload, 0) != coretext_glyph_payload_protocol_version {
    return None
  }
  let font_name_len = i32_le(payload, 24)
  if font_name_len <= 0 || payload.length() != 28 + font_name_len {
    return None
  }
  match coretext_style_from_code(i32_le(payload, 16)) {
    Some(style) =>
      Some({
        glyph_id: i32_le(payload, 4),
        font_name: Bytes::from_array(payload[28:].to_array()),
        size_key: i32_le(payload, 8),
        weight: i32_le(payload, 12),
        style,
        scale_key: i32_le(payload, 20),
      })
    None => None
  }
}

///|
fn coretext_font_cache_key(font_name : Bytes) -> String {
  let mut out = "\{font_name.length()}:"
  for byte in font_name {
    out = out + "\{byte.to_int()},"
  }
  out
}

///|
fn coretext_native_glyph_key(
  key : CoreTextGlyphKey,
) -> @wgpu_renderer.NativeGlyphKey {
  @wgpu_renderer.native_platform_glyph_key(
    cache_key=coretext_glyph_cache_key(key),
    payload=coretext_glyph_payload(key),
  )
}

///|
fn coretext_measure_layout(
  input : @core.TextLayoutInput,
) -> @wgpu_renderer.NativeTextLayout? {
  @text_protocol.native_measure_layout_from_bytes(
    input,
    macos_coretext_measure_utf32(
      @text_protocol.native_utf32_bytes(input.text),
      @text_protocol.native_font_spec_bytes(input.font),
    ),
  )
}

///|
fn coretext_layout_for_run(
  run : @core.TextRun,
  scale_factor : Double,
) -> @wgpu_renderer.NativeTextLayout? {
  match
    coretext_measure_layout(
      @core.TextLayoutInput::new(
        text=run.text,
        font=run.font,
        max_width=run.frame.size.width,
      ),
    ) {
    Some(layout) =>
      match coretext_layout_glyphs_for_run(run, scale_factor) {
        Some(glyphs) =>
          Some(
            @wgpu_renderer.NativeTextLayout::new(
              size=layout.size,
              baseline=layout.baseline,
              caret_positions=layout.caret_positions,
              glyphs~,
            ),
          )
        None => None
      }
    None => None
  }
}

///|
fn coretext_layout_glyphs_for_run(
  run : @core.TextRun,
  scale_factor : Double,
) -> Array[@wgpu_renderer.NativeGlyphPlacement]? {
  let bytes = macos_coretext_layout_glyphs_utf32(
    @text_protocol.native_utf32_bytes(run.text),
    @text_protocol.native_font_spec_bytes(run.font),
  )
  coretext_layout_glyphs_from_bytes(run, scale_factor, bytes)
}

///|
fn coretext_layout_glyphs_from_bytes(
  run : @core.TextRun,
  scale_factor : Double,
  bytes : Bytes,
) -> Array[@wgpu_renderer.NativeGlyphPlacement]? {
  if bytes.length() < 32 {
    return None
  }
  let version = i32_le(bytes, 0)
  let glyph_count = i32_le(bytes, 4)
  let height = double_le(bytes, 8)
  let baseline = double_le(bytes, 16)
  if version != coretext_run_protocol_version ||
    glyph_count < 0 ||
    height <= 0.0 ||
    baseline < 0.0 ||
    !coretext_payload_covers_records(
      total_len=bytes.length(),
      header=32,
      count=glyph_count,
      record_size=28,
    ) {
    return None
  }
  let glyphs : Array[@wgpu_renderer.NativeGlyphPlacement] = []
  let scale = coretext_text_scale(scale_factor)
  let size_key = coretext_size_key(run.font.size)
  let scale_key = coretext_scale_key(scale)
  let mut offset = 32
  for index in 0..<glyph_count {
    let _ = index
    if offset + 28 > bytes.length() {
      return None
    }
    let glyph_id = i32_le(bytes, offset)
    let font_name_len = i32_le(bytes, offset + 24)
    if font_name_len <= 0 ||
      !coretext_payload_covers_records(
        total_len=bytes.length(),
        header=offset + 28,
        count=font_name_len,
        record_size=1,
      ) {
      return None
    }
    let font_name = Bytes::from_array(
      bytes[offset + 28:offset + 28 + font_name_len].to_array(),
    )
    if glyph_id > 0 {
      glyphs.push(
        @wgpu_renderer.NativeGlyphPlacement::new(
          key=coretext_native_glyph_key({
            glyph_id,
            font_name,
            size_key,
            weight: run.font.weight,
            style: run.font.style,
            scale_key,
          }),
          x=double_le(bytes, offset + 8),
          y=double_le(bytes, offset + 16),
        ),
      )
    } else {
      ()
    }
    offset = offset + 28 + font_name_len
  }
  if offset != bytes.length() {
    return None
  }
  Some(glyphs)
}

///|
fn coretext_raster_glyph(
  key : CoreTextGlyphKey,
) -> @wgpu_renderer.NativeRasterGlyph? {
  @text_protocol.native_raster_glyph_from_bytes(
    macos_coretext_raster_glyph(
      key.glyph_id,
      key.font_name,
      key.size_key.to_double() / 64.0,
      key.weight,
      coretext_style_code(key.style),
      key.scale_key.to_double() / 64.0,
    ),
  )
}

///|
fn coretext_payload_covers_records(
  total_len~ : Int,
  header~ : Int,
  count~ : Int,
  record_size~ : Int,
) -> Bool {
  if total_len < header || header < 0 || count < 0 || record_size <= 0 {
    return false
  }
  count <= (total_len - header) / record_size
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

///|
#borrow(utf32, font_spec)
extern "C" fn macos_coretext_measure_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
) -> Bytes = "moui_macos_coretext_measure_utf32"

///|
#borrow(utf32, font_spec)
extern "C" fn macos_coretext_layout_glyphs_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
) -> Bytes = "moui_macos_coretext_layout_glyphs_utf32"

///|
#borrow(font_name)
extern "C" fn macos_coretext_raster_glyph(
  glyph_id : Int,
  font_name : Bytes,
  size : Double,
  weight : Int,
  style : Int,
  scale_factor : Double,
) -> Bytes = "moui_macos_coretext_raster_glyph"

///|
#borrow(payload)
extern "C" fn macos_coretext_register_font_data(payload : Bytes) -> Int = "moui_macos_coretext_register_font_data"
