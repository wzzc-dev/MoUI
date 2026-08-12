///|
extern "C" fn native_shader_color(color_argb : UInt) -> ShaderHandle = "moonbit_skia_shader_color"

///|
extern "C" fn native_color_filter_null() -> ColorFilterHandle = "moonbit_skia_color_filter_null"

///|
#borrow(color_filter)
extern "C" fn native_color_filter_is_null(
  color_filter : ColorFilterHandle,
) -> Bool = "moonbit_skia_color_filter_is_null"

///|
#borrow(values)
extern "C" fn native_color_filter_matrix(
  values : FixedArray[Float],
) -> ColorFilterHandle = "moonbit_skia_color_filter_matrix"

///|
extern "C" fn native_image_filter_null() -> ImageFilterHandle = "moonbit_skia_image_filter_null"

///|
#borrow(image_filter)
extern "C" fn native_image_filter_is_null(
  image_filter : ImageFilterHandle,
) -> Bool = "moonbit_skia_image_filter_is_null"

///|
extern "C" fn native_image_filter_blur(
  sigma_x : Float,
  sigma_y : Float,
) -> ImageFilterHandle = "moonbit_skia_image_filter_blur"

///|
extern "C" fn native_mask_filter_null() -> MaskFilterHandle = "moonbit_skia_mask_filter_null"

///|
#borrow(mask_filter)
extern "C" fn native_mask_filter_is_null(
  mask_filter : MaskFilterHandle,
) -> Bool = "moonbit_skia_mask_filter_is_null"

///|
extern "C" fn native_mask_filter_blur(sigma : Float) -> MaskFilterHandle = "moonbit_skia_mask_filter_blur"

///|
extern "C" fn native_shader_linear_gradient(
  x0 : Float,
  y0 : Float,
  x1 : Float,
  y1 : Float,
  color0_argb : UInt,
  color1_argb : UInt,
  tile_mode : Int,
) -> ShaderHandle = "moonbit_skia_shader_linear_gradient"

///|
extern "C" fn native_shader_radial_gradient(
  center_x : Float,
  center_y : Float,
  radius : Float,
  color0_argb : UInt,
  color1_argb : UInt,
  tile_mode : Int,
) -> ShaderHandle = "moonbit_skia_shader_radial_gradient"

///|
#borrow(shader)
extern "C" fn native_shader_is_null(shader : ShaderHandle) -> Bool = "moonbit_skia_shader_is_null"

///|
fn ColorFilter::from_handle(handle : ColorFilterHandle) -> ColorFilter? {
  if native_color_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn ColorFilter::matrix(values : Array[Float]) -> ColorFilter? {
  if values.length() != 20 || !skia_float_array_is_finite(values) {
    None
  } else {
    ColorFilter::from_handle(
      native_color_filter_matrix(FixedArray::from_array(values)),
    )
  }
}

///|
pub fn ColorFilter::saturation(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let one : Float = 1.0
    let zero : Float = 0.0
    let inv = one - amount
    let r : Float = 0.2126 * inv
    let g : Float = 0.7152 * inv
    let b : Float = 0.0722 * inv
    ColorFilter::matrix([
      r + amount,
      g,
      b,
      zero,
      zero,
      r,
      g + amount,
      b,
      zero,
      zero,
      r,
      g,
      b + amount,
      zero,
      zero,
      zero,
      zero,
      zero,
      one,
      zero,
    ])
  }
}

///|
pub fn ColorFilter::brightness(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let zero : Float = 0.0
    let one : Float = 1.0
    ColorFilter::matrix([
      amount, zero, zero, zero, zero, zero, amount, zero, zero, zero, zero, zero,
      amount, zero, zero, zero, zero, zero, one, zero,
    ])
  }
}

///|
pub fn ColorFilter::contrast(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let zero : Float = 0.0
    let one : Float = 1.0
    let offset : Float = 0.5 * (one - amount)
    ColorFilter::matrix([
      amount, zero, zero, zero, offset, zero, amount, zero, zero, offset, zero, zero,
      amount, zero, offset, zero, zero, zero, one, zero,
    ])
  }
}

///|
pub fn ColorFilter::is_available(self : ColorFilter) -> Bool {
  !native_color_filter_is_null(self.handle)
}

///|
fn ImageFilter::from_handle(handle : ImageFilterHandle) -> ImageFilter? {
  if native_image_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn ImageFilter::blur(sigma_x : Float, sigma_y : Float) -> ImageFilter? {
  if !skia_scalar_is_finite(sigma_x) ||
    !skia_scalar_is_finite(sigma_y) ||
    sigma_x <= 0.0 ||
    sigma_y <= 0.0 {
    None
  } else {
    ImageFilter::from_handle(native_image_filter_blur(sigma_x, sigma_y))
  }
}

///|
pub fn ImageFilter::is_available(self : ImageFilter) -> Bool {
  !native_image_filter_is_null(self.handle)
}

///|
fn MaskFilter::from_handle(handle : MaskFilterHandle) -> MaskFilter? {
  if native_mask_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn MaskFilter::blur(sigma : Float) -> MaskFilter? {
  if !skia_scalar_is_finite(sigma) || sigma <= 0.0 {
    None
  } else {
    MaskFilter::from_handle(native_mask_filter_blur(sigma))
  }
}

///|
pub fn MaskFilter::is_available(self : MaskFilter) -> Bool {
  !native_mask_filter_is_null(self.handle)
}

///|
fn Shader::from_handle(handle : ShaderHandle) -> Shader? {
  if native_shader_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Shader::color(color : @skia.Color) -> Shader? {
  Shader::from_handle(native_shader_color(color.argb()))
}

///|
pub fn Shader::linear_gradient(
  start : @skia.Point,
  end : @skia.Point,
  start_color : @skia.Color,
  end_color : @skia.Color,
  tile_mode? : @skia.TileMode = Clamp,
) -> Shader? {
  if !start.is_finite() ||
    !end.is_finite() ||
    start.distance_to_squared(end) <= 0.0 {
    None
  } else {
    Shader::from_handle(
      native_shader_linear_gradient(
        start.x,
        start.y,
        end.x,
        end.y,
        start_color.argb(),
        end_color.argb(),
        tile_mode.to_skia_ordinal(),
      ),
    )
  }
}

///|
pub fn Shader::radial_gradient(
  center : @skia.Point,
  radius : Float,
  inner_color : @skia.Color,
  outer_color : @skia.Color,
  tile_mode? : @skia.TileMode = Clamp,
) -> Shader? {
  if !center.is_finite() || !skia_scalar_is_finite(radius) || radius <= 0.0 {
    None
  } else {
    Shader::from_handle(
      native_shader_radial_gradient(
        center.x,
        center.y,
        radius,
        inner_color.argb(),
        outer_color.argb(),
        tile_mode.to_skia_ordinal(),
      ),
    )
  }
}

///|
pub fn Shader::is_available(self : Shader) -> Bool {
  !native_shader_is_null(self.handle)
}

///|
fn skia_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn skia_float_array_is_finite(values : Array[Float]) -> Bool {
  let mut finite = true
  for value in values {
    if !skia_scalar_is_finite(value) {
      finite = false
    }
  }
  finite
}
