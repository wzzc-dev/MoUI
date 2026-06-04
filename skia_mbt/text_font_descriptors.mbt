///|
/// Skia-style font style request shared by native typeface matching and fallback.
pub(all) struct FontStyleRequest {
  weight : Int
  width : Int
  slant : Int
} derive(Debug, Eq)

///|
pub impl Default for FontStyleRequest with fn default() {
  FontStyleRequest::new()
}

///|
pub fn FontStyleRequest::new(
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> FontStyleRequest {
  {
    weight: weight.clamp(min=1, max=1000),
    width: width.clamp(min=1, max=9),
    slant: slant.clamp(min=0, max=2),
  }
}

///|
pub fn FontStyleRequest::normal() -> FontStyleRequest {
  FontStyleRequest::new()
}

///|
pub fn FontStyleRequest::bold() -> FontStyleRequest {
  FontStyleRequest::new(weight=700)
}

///|
pub fn FontStyleRequest::italic() -> FontStyleRequest {
  FontStyleRequest::new(slant=1)
}

///|
pub fn FontStyleRequest::is_bold(self : FontStyleRequest) -> Bool {
  self.weight >= 600
}

///|
pub fn FontStyleRequest::is_italic(self : FontStyleRequest) -> Bool {
  self.slant != 0
}

///|
fn font_descriptor_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn normalized_font_descriptor_positive_scalar(value : Float) -> Float {
  if font_descriptor_scalar_is_finite(value) && value > 0.0 {
    value
  } else {
    0.0
  }
}

///|
fn normalized_font_descriptor_skew(value : Float) -> Float {
  if font_descriptor_scalar_is_finite(value) {
    value
  } else {
    0.0 / 0.0
  }
}

///|
/// Value-layer description of a native font handle derived from a typeface.
pub(all) struct FontDescriptor {
  typeface_key : RendererResourceKey
  size : Float
  scale_x : Float
  skew_x : Float
} derive(Debug, Eq)

///|
pub fn FontDescriptor::new(
  typeface_key? : RendererResourceKey = RendererResourceKey::typeface(
    b"default",
  ),
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
) -> FontDescriptor {
  {
    typeface_key,
    size: normalized_font_descriptor_positive_scalar(size),
    scale_x: normalized_font_descriptor_positive_scalar(scale_x),
    skew_x: normalized_font_descriptor_skew(skew_x),
  }
}

///|
pub fn FontDescriptor::from_typeface(
  typeface_key : RendererResourceKey,
  size? : Float = 12.0,
) -> FontDescriptor {
  FontDescriptor::new(typeface_key~, size~)
}

///|
pub fn FontDescriptor::default(size? : Float = 12.0) -> FontDescriptor {
  FontDescriptor::new(size~)
}

///|
pub fn FontDescriptor::is_valid(self : FontDescriptor) -> Bool {
  self.typeface_key.kind == TypefaceResource &&
  !self.typeface_key.is_empty() &&
  self.size > 0.0 &&
  self.scale_x > 0.0 &&
  font_descriptor_scalar_is_finite(self.skew_x)
}

///|
pub fn FontDescriptor::with_typeface_key(
  self : FontDescriptor,
  typeface_key : RendererResourceKey,
) -> FontDescriptor {
  FontDescriptor::new(
    typeface_key~,
    size=self.size,
    scale_x=self.scale_x,
    skew_x=self.skew_x,
  )
}

///|
pub fn FontDescriptor::with_size(
  self : FontDescriptor,
  size : Float,
) -> FontDescriptor {
  FontDescriptor::new(
    typeface_key=self.typeface_key,
    size~,
    scale_x=self.scale_x,
    skew_x=self.skew_x,
  )
}

///|
pub fn FontDescriptor::with_scale_x(
  self : FontDescriptor,
  scale_x : Float,
) -> FontDescriptor {
  FontDescriptor::new(
    typeface_key=self.typeface_key,
    size=self.size,
    scale_x~,
    skew_x=self.skew_x,
  )
}

///|
pub fn FontDescriptor::with_skew_x(
  self : FontDescriptor,
  skew_x : Float,
) -> FontDescriptor {
  FontDescriptor::new(
    typeface_key=self.typeface_key,
    size=self.size,
    scale_x=self.scale_x,
    skew_x~,
  )
}

///|
fn FontDescriptor::resource_id(self : FontDescriptor) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:font:v1" +
    self.typeface_key.text_run_cache_id() +
    self.size.to_be_bytes() +
    self.scale_x.to_be_bytes() +
    self.skew_x.to_be_bytes()
  }
}

///|
pub fn FontDescriptor::resource_key(
  self : FontDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::font(self.resource_id())
}

///|
pub fn FontDescriptor::resource_descriptor(
  self : FontDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::font(id, byte_size=measured_byte_size)
}
