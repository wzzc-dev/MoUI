///|
/// Portable shader recipes that can be planned before native Skia handles are
/// created.
pub(all) enum ShaderDescriptor {
  ColorShader(Color)
  LinearGradientShader(Point, Point, Color, Color, TileMode)
  RadialGradientShader(Point, Float, Color, Color, TileMode)
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
fn shader_filter_points_are_distinct(start : Point, end : Point) -> Bool {
  start.distance_to_squared(end) > 0.0
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
  if shader_filter_point_is_finite(start) &&
    shader_filter_point_is_finite(end) &&
    shader_filter_points_are_distinct(start, end) {
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
pub fn ShaderDescriptor::is_valid(self : ShaderDescriptor) -> Bool {
  match self {
    ColorShader(_) => true
    LinearGradientShader(start, end, _, _, _) =>
      shader_filter_point_is_finite(start) &&
      shader_filter_point_is_finite(end) &&
      shader_filter_points_are_distinct(start, end)
    RadialGradientShader(center, radius, _, _, _) =>
      shader_filter_point_is_finite(center) &&
      shader_filter_scalar_is_finite(radius) &&
      radius > 0.0
  }
}

///|
fn ShaderDescriptor::resource_id(self : ShaderDescriptor) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    match self {
      ColorShader(color) =>
        b"moui_skia:shader:v1" +
        shader_filter_resource_bytes(b"color") +
        shader_filter_color_id(color)
      LinearGradientShader(start, end, start_color, end_color, tile_mode) =>
        b"moui_skia:shader:v1" +
        shader_filter_resource_bytes(b"linear-gradient") +
        shader_filter_point_id(start) +
        shader_filter_point_id(end) +
        shader_filter_color_id(start_color) +
        shader_filter_color_id(end_color) +
        tile_mode.shader_filter_id()
      RadialGradientShader(center, radius, inner_color, outer_color, tile_mode) =>
        b"moui_skia:shader:v1" +
        shader_filter_resource_bytes(b"radial-gradient") +
        shader_filter_point_id(center) +
        shader_filter_float_id(radius) +
        shader_filter_color_id(inner_color) +
        shader_filter_color_id(outer_color) +
        tile_mode.shader_filter_id()
    }
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
