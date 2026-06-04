///|
pub fn Shader::color(color : @skia.Color) -> Shader? {
  ignore(color)
  None
}

///|
pub fn Shader::linear_gradient(
  start : @skia.Point,
  end : @skia.Point,
  start_color : @skia.Color,
  end_color : @skia.Color,
  tile_mode? : @skia.TileMode = Clamp,
) -> Shader? {
  ignore(start)
  ignore(end)
  ignore(start_color)
  ignore(end_color)
  ignore(tile_mode)
  None
}

///|
pub fn Shader::radial_gradient(
  center : @skia.Point,
  radius : Float,
  inner_color : @skia.Color,
  outer_color : @skia.Color,
  tile_mode? : @skia.TileMode = Clamp,
) -> Shader? {
  ignore(center)
  ignore(radius)
  ignore(inner_color)
  ignore(outer_color)
  ignore(tile_mode)
  None
}

///|
pub fn Shader::is_available(self : Shader) -> Bool {
  ignore(self)
  false
}

///|
pub fn ColorFilter::matrix(values : Array[Float]) -> ColorFilter? {
  ignore(values)
  None
}

///|
pub fn ColorFilter::saturation(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::brightness(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::contrast(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::is_available(self : ColorFilter) -> Bool {
  ignore(self)
  false
}

///|
pub fn ImageFilter::blur(sigma_x : Float, sigma_y : Float) -> ImageFilter? {
  ignore(sigma_x)
  ignore(sigma_y)
  None
}

///|
pub fn ImageFilter::is_available(self : ImageFilter) -> Bool {
  ignore(self)
  false
}

///|
pub fn MaskFilter::blur(sigma : Float) -> MaskFilter? {
  ignore(sigma)
  None
}

///|
pub fn MaskFilter::is_available(self : MaskFilter) -> Bool {
  ignore(self)
  false
}
