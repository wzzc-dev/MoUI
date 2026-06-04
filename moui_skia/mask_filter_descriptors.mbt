///|
/// Portable mask-filter recipes that can be mapped to native Skia filters.
pub(all) enum MaskFilterDescriptor {
  BlurMaskFilter(Float)
} derive(Debug, Eq)

///|
pub fn MaskFilterDescriptor::blur(sigma : Float) -> MaskFilterDescriptor? {
  if shader_filter_scalar_is_finite(sigma) && sigma > 0.0 {
    Some(BlurMaskFilter(sigma))
  } else {
    None
  }
}

///|
pub fn MaskFilterDescriptor::is_valid(self : MaskFilterDescriptor) -> Bool {
  match self {
    BlurMaskFilter(sigma) =>
      shader_filter_scalar_is_finite(sigma) && sigma > 0.0
  }
}

///|
fn MaskFilterDescriptor::resource_id(self : MaskFilterDescriptor) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    match self {
      BlurMaskFilter(sigma) =>
        b"moui_skia:mask-filter:v1" +
        shader_filter_resource_bytes(b"blur") +
        shader_filter_float_id(sigma)
    }
  }
}

///|
pub fn MaskFilterDescriptor::resource_key(
  self : MaskFilterDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::mask_filter(self.resource_id())
}

///|
pub fn MaskFilterDescriptor::resource_descriptor(
  self : MaskFilterDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::mask_filter(id, byte_size=measured_byte_size)
}
