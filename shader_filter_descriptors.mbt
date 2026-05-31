///|
/// Portable shader recipes that can be planned before native Skia handles are
/// created.
#warnings("-deprecated_syntax")
pub(all) enum ShaderDescriptor {
  ColorShader(Color)
  LinearGradientShader(Point, Point, Color, Color, TileMode)
  RadialGradientShader(Point, Float, Color, Color, TileMode)
} derive(Debug, Eq)

///|
/// Portable color-filter recipes that mirror the native filter constructors.
#warnings("-deprecated_syntax")
pub(all) enum ColorFilterDescriptor {
  ColorMatrixFilter(Array[Float])
  SaturationFilter(Float)
  BrightnessFilter(Float)
  ContrastFilter(Float)
} derive(Debug, Eq)

///|
/// Portable image-filter recipes that can be mapped to native Skia filters.
#warnings("-deprecated_syntax")
pub(all) enum ImageFilterDescriptor {
  BlurImageFilter(Float, Float)
} derive(Debug, Eq)

///|
/// Portable mask-filter recipes that can be mapped to native Skia filters.
#warnings("-deprecated_syntax")
pub(all) enum MaskFilterDescriptor {
  BlurMaskFilter(Float)
} derive(Debug, Eq)

///|
fn shader_filter_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn shader_filter_point_is_finite(point : Point) -> Bool {
  shader_filter_scalar_is_finite(point.x) &&
  shader_filter_scalar_is_finite(point.y)
}

///|
fn shader_filter_resource_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn shader_filter_resource_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn shader_filter_color_id(color : Color) -> Bytes {
  color.argb().to_uint64().to_be_bytes()
}

///|
fn shader_filter_point_id(point : Point) -> Bytes {
  point.x.to_be_bytes() + point.y.to_be_bytes()
}

///|
fn TileMode::shader_filter_id(self : TileMode) -> Bytes {
  shader_filter_resource_u64(self.to_skia_ordinal())
}

///|
fn shader_filter_float_id(value : Float) -> Bytes {
  value.to_be_bytes()
}

///|
fn shader_filter_float_array_id(values : Array[Float]) -> Bytes {
  let mut id = shader_filter_resource_u64(values.length())
  for value in values {
    id = id + shader_filter_float_id(value)
  }
  id
}

///|
fn shader_filter_float_array_is_finite(values : Array[Float]) -> Bool {
  let mut finite = true
  for value in values {
    if !shader_filter_scalar_is_finite(value) {
      finite = false
    }
  }
  finite
}

///|
pub fn ShaderDescriptor::color(color : Color) -> ShaderDescriptor {
  ColorShader(color)
}

///|
pub fn ShaderDescriptor::linear_gradient(
  start : Point,
  end : Point,
  start_color : Color,
  end_color : Color,
  tile_mode? : TileMode = Clamp,
) -> ShaderDescriptor? {
  if shader_filter_point_is_finite(start) && shader_filter_point_is_finite(end) {
    Some(LinearGradientShader(start, end, start_color, end_color, tile_mode))
  } else {
    None
  }
}

///|
pub fn ShaderDescriptor::radial_gradient(
  center : Point,
  radius : Float,
  inner_color : Color,
  outer_color : Color,
  tile_mode? : TileMode = Clamp,
) -> ShaderDescriptor? {
  if shader_filter_point_is_finite(center) &&
    shader_filter_scalar_is_finite(radius) &&
    radius > 0.0 {
    Some(
      RadialGradientShader(center, radius, inner_color, outer_color, tile_mode),
    )
  } else {
    None
  }
}

///|
fn ShaderDescriptor::resource_id(self : ShaderDescriptor) -> Bytes {
  match self {
    ColorShader(color) =>
      b"skia_mbt:shader:v1" +
      shader_filter_resource_bytes(b"color") +
      shader_filter_color_id(color)
    LinearGradientShader(start, end, start_color, end_color, tile_mode) =>
      b"skia_mbt:shader:v1" +
      shader_filter_resource_bytes(b"linear-gradient") +
      shader_filter_point_id(start) +
      shader_filter_point_id(end) +
      shader_filter_color_id(start_color) +
      shader_filter_color_id(end_color) +
      tile_mode.shader_filter_id()
    RadialGradientShader(center, radius, inner_color, outer_color, tile_mode) =>
      b"skia_mbt:shader:v1" +
      shader_filter_resource_bytes(b"radial-gradient") +
      shader_filter_point_id(center) +
      shader_filter_float_id(radius) +
      shader_filter_color_id(inner_color) +
      shader_filter_color_id(outer_color) +
      tile_mode.shader_filter_id()
  }
}

///|
pub fn ShaderDescriptor::resource_key(
  self : ShaderDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::shader(self.resource_id())
}

///|
pub fn ShaderDescriptor::resource_descriptor(
  self : ShaderDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::shader(id, byte_size=measured_byte_size)
}

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
fn ColorFilterDescriptor::resource_id(self : ColorFilterDescriptor) -> Bytes {
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
fn ImageFilterDescriptor::resource_id(self : ImageFilterDescriptor) -> Bytes {
  match self {
    BlurImageFilter(sigma_x, sigma_y) =>
      b"skia_mbt:image-filter:v1" +
      shader_filter_resource_bytes(b"blur") +
      shader_filter_float_id(sigma_x) +
      shader_filter_float_id(sigma_y)
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

///|
pub fn MaskFilterDescriptor::blur(sigma : Float) -> MaskFilterDescriptor? {
  if shader_filter_scalar_is_finite(sigma) && sigma > 0.0 {
    Some(BlurMaskFilter(sigma))
  } else {
    None
  }
}

///|
fn MaskFilterDescriptor::resource_id(self : MaskFilterDescriptor) -> Bytes {
  match self {
    BlurMaskFilter(sigma) =>
      b"skia_mbt:mask-filter:v1" +
      shader_filter_resource_bytes(b"blur") +
      shader_filter_float_id(sigma)
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
