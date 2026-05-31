///|
/// Lightweight text direction used by value-layer text layout contracts.
#warnings("-deprecated_syntax")
pub(all) enum TextDirection {
  LeftToRight
  RightToLeft
} derive(Debug, Eq)

///|
pub impl Default for TextDirection with fn default() {
  LeftToRight
}

///|
pub fn TextDirection::is_left_to_right(self : TextDirection) -> Bool {
  self is LeftToRight
}

///|
pub fn TextDirection::is_right_to_left(self : TextDirection) -> Bool {
  self is RightToLeft
}

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
fn bytes_array_contains(values : Array[Bytes], value : Bytes) -> Bool {
  let mut found = false
  for item in values {
    if item == value {
      found = true
    }
  }
  found
}

///|
fn copy_non_empty_unique_bytes(
  values : Array[Bytes],
  skip? : Bytes = b"",
) -> Array[Bytes] {
  let result : Array[Bytes] = Array::new(capacity=values.length())
  for value in values {
    if !value.is_empty() &&
      value != skip &&
      !bytes_array_contains(result, value) {
      result.push(value)
    }
  }
  result
}

///|
/// Ordered family list used before asking a native font manager for fallback.
pub(all) struct FontFallbackChain {
  primary_family : Bytes
  fallback_families : Array[Bytes]
} derive(Debug, Eq)

///|
pub fn FontFallbackChain::new(
  primary_family? : Bytes = b"",
  fallback_families? : Array[Bytes] = [],
) -> FontFallbackChain {
  {
    primary_family,
    fallback_families: copy_non_empty_unique_bytes(
      fallback_families,
      skip=primary_family,
    ),
  }
}

///|
pub fn FontFallbackChain::length(self : FontFallbackChain) -> Int {
  let primary_count = if self.primary_family.is_empty() { 0 } else { 1 }
  primary_count + self.fallback_families.length()
}

///|
pub fn FontFallbackChain::is_empty(self : FontFallbackChain) -> Bool {
  self.length() == 0
}

///|
pub fn FontFallbackChain::family_at(
  self : FontFallbackChain,
  index : Int,
) -> Bytes? {
  if index < 0 {
    None
  } else if self.primary_family.is_empty() {
    self.fallback_families.get(index)
  } else if index == 0 {
    Some(self.primary_family)
  } else {
    self.fallback_families.get(index - 1)
  }
}

///|
pub fn FontFallbackChain::contains_family(
  self : FontFallbackChain,
  family : Bytes,
) -> Bool {
  !family.is_empty() &&
  (
    self.primary_family == family ||
    bytes_array_contains(self.fallback_families, family)
  )
}

///|
pub fn FontFallbackChain::with_family(
  self : FontFallbackChain,
  family : Bytes,
) -> FontFallbackChain {
  if family.is_empty() || self.contains_family(family) {
    self
  } else {
    let fallbacks : Array[Bytes] = Array::new(
      capacity=self.fallback_families.length() + 1,
    )
    for value in self.fallback_families {
      fallbacks.push(value)
    }
    fallbacks.push(family)
    { ..self, fallback_families: fallbacks }
  }
}

///|
/// Font fallback query for one character or run.
pub(all) struct FontFallbackRequest {
  families : FontFallbackChain
  bcp47 : Array[Bytes]
  character : Int
  style : FontStyleRequest
} derive(Debug, Eq)

///|
pub fn FontFallbackRequest::new(
  families? : FontFallbackChain = FontFallbackChain::new(),
  bcp47? : Array[Bytes] = [],
  character? : Int = 0,
  style? : FontStyleRequest = FontStyleRequest::new(),
) -> FontFallbackRequest {
  {
    families,
    bcp47: copy_non_empty_unique_bytes(bcp47),
    character: Int::max(0, character),
    style,
  }
}

///|
pub fn FontFallbackRequest::language_count(self : FontFallbackRequest) -> Int {
  self.bcp47.length()
}

///|
pub fn FontFallbackRequest::language_at(
  self : FontFallbackRequest,
  index : Int,
) -> Bytes? {
  if index < 0 {
    None
  } else {
    self.bcp47.get(index)
  }
}

///|
pub fn FontFallbackRequest::has_character(self : FontFallbackRequest) -> Bool {
  self.character > 0
}

///|
pub fn FontFallbackRequest::with_character(
  self : FontFallbackRequest,
  character : Int,
) -> FontFallbackRequest {
  { ..self, character: Int::max(0, character) }
}

///|
pub fn FontFallbackRequest::with_style(
  self : FontFallbackRequest,
  style : FontStyleRequest,
) -> FontFallbackRequest {
  { ..self, style, }
}

///|
/// Half-open byte range for a shaped text run.
pub(all) struct TextRange {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
pub fn TextRange::new(start : Int, end : Int) -> TextRange {
  let start = Int::max(0, start)
  { start, end: Int::max(start, end) }
}

///|
pub fn TextRange::length(self : TextRange) -> Int {
  self.end - self.start
}

///|
pub fn TextRange::is_empty(self : TextRange) -> Bool {
  self.length() == 0
}

///|
pub fn TextRange::contains_offset(self : TextRange, offset : Int) -> Bool {
  offset >= self.start && offset < self.end
}

///|
/// Value-layer description of a text run before native shaping or fallback.
pub(all) struct TextRunDescriptor {
  range : TextRange
  direction : TextDirection
  fallback : FontFallbackRequest
} derive(Debug, Eq)

///|
pub fn TextRunDescriptor::new(
  range? : TextRange = TextRange::new(0, 0),
  direction? : TextDirection = LeftToRight,
  fallback? : FontFallbackRequest = FontFallbackRequest::new(),
) -> TextRunDescriptor {
  { range, direction, fallback }
}

///|
pub fn TextRunDescriptor::is_empty(self : TextRunDescriptor) -> Bool {
  self.range.is_empty()
}

///|
pub fn TextRunDescriptor::is_right_to_left(self : TextRunDescriptor) -> Bool {
  self.direction.is_right_to_left()
}

///|
pub fn TextRunDescriptor::with_range(
  self : TextRunDescriptor,
  range : TextRange,
) -> TextRunDescriptor {
  { ..self, range, }
}

///|
pub fn TextRunDescriptor::with_direction(
  self : TextRunDescriptor,
  direction : TextDirection,
) -> TextRunDescriptor {
  { ..self, direction, }
}

///|
pub fn TextRunDescriptor::with_fallback(
  self : TextRunDescriptor,
  fallback : FontFallbackRequest,
) -> TextRunDescriptor {
  { ..self, fallback, }
}

///|
fn text_run_cache_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn text_run_cache_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn RendererResourceKind::text_run_cache_name(
  self : RendererResourceKind,
) -> Bytes {
  match self {
    ImageResource => b"image"
    ShaderResource => b"shader"
    ColorFilterResource => b"color-filter"
    ImageFilterResource => b"image-filter"
    MaskFilterResource => b"mask-filter"
    TypefaceResource => b"typeface"
    FontResource => b"font"
    PathResource => b"path"
    TextRunResource => b"text-run"
    SurfaceResource => b"surface"
    GpuContextResource => b"gpu-context"
    GpuSurfaceResource => b"gpu-surface"
  }
}

///|
fn RendererResourceKey::text_run_cache_id(self : RendererResourceKey) -> Bytes {
  text_run_cache_bytes(self.kind.text_run_cache_name()) +
  text_run_cache_bytes(self.id)
}

///|
fn TextDirection::text_run_cache_id(self : TextDirection) -> Bytes {
  match self {
    LeftToRight => b"ltr"
    RightToLeft => b"rtl"
  }
}

///|
fn FontStyleRequest::text_run_cache_id(self : FontStyleRequest) -> Bytes {
  text_run_cache_u64(self.weight) +
  text_run_cache_u64(self.width) +
  text_run_cache_u64(self.slant)
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

///|
fn FontFallbackChain::text_run_cache_id(self : FontFallbackChain) -> Bytes {
  let mut id = text_run_cache_bytes(self.primary_family) +
    text_run_cache_u64(self.fallback_families.length())
  for family in self.fallback_families {
    id = id + text_run_cache_bytes(family)
  }
  id
}

///|
fn FontFallbackRequest::text_run_cache_id(self : FontFallbackRequest) -> Bytes {
  let mut id = self.families.text_run_cache_id() +
    text_run_cache_u64(self.bcp47.length())
  for language in self.bcp47 {
    id = id + text_run_cache_bytes(language)
  }
  id + text_run_cache_u64(self.character) + self.style.text_run_cache_id()
}

///|
fn FontFallbackRequest::resource_id(self : FontFallbackRequest) -> Bytes {
  b"skia_mbt:font-fallback:v1" + self.text_run_cache_id()
}

///|
/// Deterministic renderer cache key for native font fallback/typeface matching.
pub fn FontFallbackRequest::resource_key(
  self : FontFallbackRequest,
) -> RendererResourceKey {
  RendererResourceKey::typeface(self.resource_id())
}

///|
/// Cache descriptor for a native font fallback/typeface match result.
pub fn FontFallbackRequest::resource_descriptor(
  self : FontFallbackRequest,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::typeface(id, byte_size=measured_byte_size)
}

///|
/// Font descriptor derived from a native fallback/typeface match result.
pub fn FontFallbackRequest::font_descriptor(
  self : FontFallbackRequest,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
) -> FontDescriptor {
  FontDescriptor::new(
    typeface_key=self.resource_key(),
    size~,
    scale_x~,
    skew_x~,
  )
}

///|
/// Combined resource plan for matching a fallback typeface and creating a font.
pub fn FontFallbackRequest::resource_plan(
  self : FontFallbackRequest,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
  fallback_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new([
    self.resource_descriptor(byte_size=fallback_byte_size),
    self
    .font_descriptor(size~, scale_x~, skew_x~)
    .resource_descriptor(byte_size=font_byte_size),
  ])
}

///|
fn TextRange::text_run_cache_id(self : TextRange) -> Bytes {
  text_run_cache_u64(self.start) + text_run_cache_u64(self.end)
}

///|
/// Deterministic renderer cache key for a shaped or measured text run.
pub fn TextRunDescriptor::resource_key(
  self : TextRunDescriptor,
  text : Bytes,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
) -> RendererResourceKey {
  RendererResourceKey::text_run(
    b"skia_mbt:text-run:v1" +
    text_run_cache_bytes(text) +
    self.range.text_run_cache_id() +
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
  let measured_byte_size = if byte_size < 0L {
    text.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(
    self.resource_key(text, font_key~).id,
    byte_size=measured_byte_size,
  )
}
