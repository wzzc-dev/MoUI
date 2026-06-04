///|
/// Portable image-filter recipes that can be mapped to native Skia filters.
pub(all) enum ImageFilterDescriptor {
  BlurImageFilter(Float, Float)
} derive(Debug, Eq)

///|
pub fn ImageFilterDescriptor::blur(
  sigma_x : Float,
  sigma_y : Float,
) -> ImageFilterDescriptor? {
  if shader_filter_scalar_is_finite(sigma_x) &&
    shader_filter_scalar_is_finite(sigma_y) &&
    sigma_x > 0.0 &&
    sigma_y > 0.0 {
    Some(BlurImageFilter(sigma_x, sigma_y))
  } else {
    None
  }
}

///|
pub fn ImageFilterDescriptor::is_valid(self : ImageFilterDescriptor) -> Bool {
  match self {
    BlurImageFilter(sigma_x, sigma_y) =>
      shader_filter_scalar_is_finite(sigma_x) &&
      shader_filter_scalar_is_finite(sigma_y) &&
      sigma_x > 0.0 &&
      sigma_y > 0.0
  }
}

///|
fn ImageFilterDescriptor::resource_id(self : ImageFilterDescriptor) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    match self {
      BlurImageFilter(sigma_x, sigma_y) =>
        b"moui_skia:image-filter:v1" +
        shader_filter_resource_bytes(b"blur") +
        shader_filter_float_id(sigma_x) +
        shader_filter_float_id(sigma_y)
    }
  }
}

///|
pub fn ImageFilterDescriptor::resource_key(
  self : ImageFilterDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::image_filter(self.resource_id())
}

///|
pub fn ImageFilterDescriptor::resource_descriptor(
  self : ImageFilterDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::image_filter(id, byte_size=measured_byte_size)
}
