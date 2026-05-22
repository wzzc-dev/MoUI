///|
let coretext_layout_protocol_version : Int = 1

///|
let coretext_raster_protocol_version : Int = 1

///|
let coretext_glyph_payload_protocol_version : Int = 1

///|
priv struct CoreTextGlyphKey {
  codepoint : Int
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
      register_font_data=(_family, _data) => (),
    ),
  )
}

///|
fn native_utf32_bytes(text : String) -> Bytes {
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
fn coretext_style_code(style : @core.FontStyle) -> Int {
  match style {
    @core.FontStyle::Normal => 0
    @core.FontStyle::Italic => 1
  }
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
pub fn coretext_size_key(size : Double) -> Int {
  (size * 64.0).to_int()
}

///|
pub fn coretext_scale_key(scale : Double) -> Int {
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
  "ct:\{key.codepoint}:\{key.size_key}:\{key.weight}:\{coretext_style_code(key.style)}:\{key.scale_key}"
}

///|
fn coretext_glyph_payload(key : CoreTextGlyphKey) -> Bytes {
  let out : Array[Byte] = []
  push_i32_le(out, coretext_glyph_payload_protocol_version)
  push_i32_le(out, key.codepoint)
  push_i32_le(out, key.size_key)
  push_i32_le(out, key.weight)
  push_i32_le(out, coretext_style_code(key.style))
  push_i32_le(out, key.scale_key)
  Bytes::from_array(out)
}

///|
fn coretext_glyph_key_from_payload(payload : Bytes) -> CoreTextGlyphKey? {
  if payload.length() != 24 ||
    i32_le(payload, 0) != coretext_glyph_payload_protocol_version {
    return None
  }
  match coretext_style_from_code(i32_le(payload, 16)) {
    Some(style) =>
      Some({
        codepoint: i32_le(payload, 4),
        size_key: i32_le(payload, 8),
        weight: i32_le(payload, 12),
        style,
        scale_key: i32_le(payload, 20),
      })
    None => None
  }
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
pub fn coretext_measure_layout(
  input : @core.TextLayoutInput,
) -> @wgpu_renderer.NativeTextLayout? {
  let bytes = macos_coretext_measure_utf32(
    native_utf32_bytes(input.text),
    input.font.size,
    input.font.weight,
    coretext_style_code(input.font.style),
  )
  if bytes.length() < 24 {
    return None
  }
  let count = i32_le(bytes, 0)
  let version = i32_le(bytes, 4)
  let height = double_le(bytes, 8)
  let baseline = double_le(bytes, 16)
  let caret_count = count + 1
  if version != coretext_layout_protocol_version ||
    count < 0 ||
    height <= 0.0 ||
    baseline <= 0.0 ||
    !coretext_payload_covers_records(
      total_len=bytes.length(),
      header=24,
      count=caret_count,
      record_size=8,
    ) {
    return None
  }
  let carets : Array[Double] = []
  for index in 0..<caret_count {
    carets.push(double_le(bytes, 24 + index * 8))
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
    Some(layout) => {
      let glyphs : Array[@wgpu_renderer.NativeGlyphPlacement] = []
      let chars = run.text.to_array()
      let scale = coretext_text_scale(scale_factor)
      let size_key = coretext_size_key(run.font.size)
      let scale_key = coretext_scale_key(scale)
      for index, ch in chars {
        let x = if index < layout.caret_positions.length() {
          layout.caret_positions[index]
        } else {
          0.0
        }
        glyphs.push(
          @wgpu_renderer.NativeGlyphPlacement::new(
            key=coretext_native_glyph_key({
              codepoint: ch.to_int(),
              size_key,
              weight: run.font.weight,
              style: run.font.style,
              scale_key,
            }),
            x~,
          ),
        )
      }
      Some(
        @wgpu_renderer.NativeTextLayout::new(
          size=layout.size,
          baseline=layout.baseline,
          caret_positions=layout.caret_positions,
          glyphs~,
        ),
      )
    }
    None => None
  }
}

///|
pub fn coretext_raster_system_glyph(
  codepoint~ : Int,
  size~ : Double,
  weight~ : Int,
  style~ : @core.FontStyle,
  scale_factor~ : Double,
) -> @wgpu_renderer.NativeRasterGlyph? {
  coretext_raster_glyph({
    codepoint,
    size_key: coretext_size_key(size),
    weight,
    style,
    scale_key: coretext_scale_key(coretext_text_scale(scale_factor)),
  })
}

///|
fn coretext_raster_glyph(
  key : CoreTextGlyphKey,
) -> @wgpu_renderer.NativeRasterGlyph? {
  let bytes = macos_coretext_raster_glyph(
    key.codepoint,
    key.size_key.to_double() / 64.0,
    key.weight,
    coretext_style_code(key.style),
    key.scale_key.to_double() / 64.0,
  )
  if bytes.length() < 32 {
    return None
  }
  let width = i32_le(bytes, 0)
  let height = i32_le(bytes, 4)
  let version = i32_le(bytes, 16)
  if version != coretext_raster_protocol_version ||
    !coretext_payload_covers_pixels(total_len=bytes.length(), width~, height~) {
    return None
  }
  let pixel_len = width * height
  Some(
    @wgpu_renderer.NativeRasterGlyph::new(
      width~,
      height~,
      bearing_x=i32_le(bytes, 8),
      bearing_y=i32_le(bytes, 12),
      pixels=Bytes::from_array(bytes[32:32 + pixel_len].to_array()),
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
fn coretext_payload_covers_pixels(
  total_len~ : Int,
  width~ : Int,
  height~ : Int,
) -> Bool {
  if total_len < 32 || width <= 0 || height <= 0 {
    return false
  }
  width <= (total_len - 32) / height
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
#borrow(utf32)
extern "C" fn macos_coretext_measure_utf32(
  utf32 : Bytes,
  size : Double,
  weight : Int,
  style : Int,
) -> Bytes = "moui_macos_coretext_measure_utf32"

///|
extern "C" fn macos_coretext_raster_glyph(
  codepoint : Int,
  size : Double,
  weight : Int,
  style : Int,
  scale_factor : Double,
) -> Bytes = "moui_macos_coretext_raster_glyph"
