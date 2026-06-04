///|
/// Portable color-filter recipes that mirror the native filter constructors.
pub(all) enum ColorFilterDescriptor {
  ColorMatrixFilter(Array[Float])
  SaturationFilter(Float)
  BrightnessFilter(Float)
  ContrastFilter(Float)
} derive(Debug, Eq)

///|
pub fn ColorFilterDescriptor::matrix(
  values : Array[Float],
) -> ColorFilterDescriptor? {
  if values.length() == 20 && shader_filter_float_array_is_finite(values) {
    Some(ColorMatrixFilter(values.copy()))
  } else {
    None
  }
}

///|
pub fn ColorFilterDescriptor::saturation(
  amount : Float,
) -> ColorFilterDescriptor? {
  if shader_filter_scalar_is_finite(amount) {
    Some(SaturationFilter(amount))
  } else {
    None
  }
}

///|
pub fn ColorFilterDescriptor::brightness(
  amount : Float,
) -> ColorFilterDescriptor? {
  if shader_filter_scalar_is_finite(amount) {
    Some(BrightnessFilter(amount))
  } else {
    None
  }
}

///|
pub fn ColorFilterDescriptor::contrast(
  amount : Float,
) -> ColorFilterDescriptor? {
  if shader_filter_scalar_is_finite(amount) {
    Some(ContrastFilter(amount))
  } else {
    None
  }
}

///|
pub fn ColorFilterDescriptor::is_valid(self : ColorFilterDescriptor) -> Bool {
  match self {
    ColorMatrixFilter(values) =>
      values.length() == 20 && shader_filter_float_array_is_finite(values)
    SaturationFilter(amount)
    | BrightnessFilter(amount)
    | ContrastFilter(amount) => shader_filter_scalar_is_finite(amount)
  }
}

///|
fn ColorFilterDescriptor::resource_id(self : ColorFilterDescriptor) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    match self {
      ColorMatrixFilter(values) =>
        b"skia_mbt:color-filter:v1" +
        shader_filter_resource_bytes(b"matrix") +
        shader_filter_float_array_id(values)
      SaturationFilter(amount) =>
        b"skia_mbt:color-filter:v1" +
        shader_filter_resource_bytes(b"saturation") +
        shader_filter_float_id(amount)
      BrightnessFilter(amount) =>
        b"skia_mbt:color-filter:v1" +
        shader_filter_resource_bytes(b"brightness") +
        shader_filter_float_id(amount)
      ContrastFilter(amount) =>
        b"skia_mbt:color-filter:v1" +
        shader_filter_resource_bytes(b"contrast") +
        shader_filter_float_id(amount)
    }
  }
}

///|
pub fn ColorFilterDescriptor::resource_key(
  self : ColorFilterDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::color_filter(self.resource_id())
}

///|
pub fn ColorFilterDescriptor::resource_descriptor(
  self : ColorFilterDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::color_filter(id, byte_size=measured_byte_size)
}
