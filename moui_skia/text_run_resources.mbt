///|
fn TextRange::text_run_cache_id(self : TextRange) -> Bytes {
  text_run_cache_u64(self.start) + text_run_cache_u64(self.end)
}

///|
fn TextRange::clamp_to_text(self : TextRange, text : Bytes) -> TextRange {
  let text_length = text.length()
  let start = self.start.clamp(min=0, max=text_length)
  { start, end: self.end.clamp(min=start, max=text_length) }
}

///|
fn TextRange::bytes_from_text(self : TextRange, text : Bytes) -> Bytes {
  let range = self.clamp_to_text(text)
  if range.is_empty() {
    b""
  } else {
    let bytes : Array[Byte] = Array::new(capacity=range.length())
    for index in range.start..<range.end {
      bytes.push(text[index])
    }
    Bytes::from_array(bytes)
  }
}

///|
/// Deterministic renderer cache key for a shaped or measured text run.
pub fn TextRunDescriptor::resource_key(
  self : TextRunDescriptor,
  text : Bytes,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
) -> RendererResourceKey {
  let range = self.range.clamp_to_text(text)
  let run_text = range.bytes_from_text(text)
  RendererResourceKey::text_run(
    b"moui_skia:text-run:v1" +
    text_run_cache_bytes(run_text) +
    range.text_run_cache_id() +
    text_run_cache_bytes(self.direction.text_run_cache_id()) +
    self.fallback.text_run_cache_id() +
    font_key.text_run_cache_id(),
  )
}

///|
/// Cache descriptor for a shaped or measured text run resource.
pub fn TextRunDescriptor::resource_descriptor(
  self : TextRunDescriptor,
  text : Bytes,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let run_text = self.range.bytes_from_text(text)
  let measured_byte_size = if byte_size < 0L {
    run_text.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(
    self.resource_key(text, font_key~).id,
    byte_size=measured_byte_size,
  )
}

///|
pub fn TextRunDescriptor::resource_plan(
  self : TextRunDescriptor,
  text : Bytes,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(
    self.resource_descriptor(text, font_key~, byte_size=text_byte_size),
  )
  if font_key.kind == FontResource && !font_key.is_empty() {
    descriptors.push(
      RendererResourceDescriptor::new(font_key, byte_size=font_byte_size),
    )
  }
  if !self.fallback.is_empty() {
    descriptors.push(
      self.fallback.resource_descriptor(byte_size=fallback_byte_size),
    )
  }
  RendererResourcePlan::new(descriptors)
}
