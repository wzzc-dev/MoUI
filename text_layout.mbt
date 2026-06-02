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
fn FontFallbackChain::index_of_family(
  self : FontFallbackChain,
  family : Bytes,
) -> Int {
  if family.is_empty() {
    -1
  } else if self.primary_family == family {
    0
  } else {
    let mut index = -1
    for fallback_index, fallback_family in self.fallback_families {
      if index < 0 && fallback_family == family {
        index = if self.primary_family.is_empty() {
          fallback_index
        } else {
          fallback_index + 1
        }
      }
    }
    index
  }
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
pub fn FontFallbackRequest::is_empty(self : FontFallbackRequest) -> Bool {
  self.families.is_empty() && self.bcp47.is_empty() && !self.has_character()
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
/// Value-layer metadata for a native font fallback/typeface match result.
pub(all) struct FontFallbackMatchDescriptor {
  request : FontFallbackRequest
  matched_family : Bytes
  fallback_index : Int
  synthetic : Bool
} derive(Debug, Eq)

///|
fn normalized_font_fallback_index(
  request : FontFallbackRequest,
  matched_family : Bytes,
  fallback_index : Int,
) -> Int {
  if fallback_index >= 0 && fallback_index < request.families.length() {
    fallback_index
  } else {
    request.families.index_of_family(matched_family)
  }
}

///|
pub fn FontFallbackMatchDescriptor::new(
  request? : FontFallbackRequest = FontFallbackRequest::new(),
  matched_family? : Bytes = b"",
  fallback_index? : Int = -1,
  synthetic? : Bool = false,
) -> FontFallbackMatchDescriptor {
  {
    request,
    matched_family,
    fallback_index: normalized_font_fallback_index(
      request, matched_family, fallback_index,
    ),
    synthetic,
  }
}

///|
pub fn FontFallbackRequest::match_descriptor(
  self : FontFallbackRequest,
  matched_family : Bytes,
  fallback_index? : Int = -1,
  synthetic? : Bool = false,
) -> FontFallbackMatchDescriptor {
  FontFallbackMatchDescriptor::new(
    request=self,
    matched_family~,
    fallback_index~,
    synthetic~,
  )
}

///|
pub fn FontFallbackMatchDescriptor::is_valid(
  self : FontFallbackMatchDescriptor,
) -> Bool {
  !self.matched_family.is_empty()
}

///|
pub fn FontFallbackMatchDescriptor::source_family(
  self : FontFallbackMatchDescriptor,
) -> Bytes? {
  if self.fallback_index < 0 {
    None
  } else {
    self.request.families.family_at(self.fallback_index)
  }
}

///|
pub fn FontFallbackMatchDescriptor::matched_in_request(
  self : FontFallbackMatchDescriptor,
) -> Bool {
  self.request.families.contains_family(self.matched_family)
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
fn text_run_cache_bool(value : Bool) -> Bytes {
  if value {
    b"true"
  } else {
    b"false"
  }
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
fn FontFallbackMatchDescriptor::text_run_cache_id(
  self : FontFallbackMatchDescriptor,
) -> Bytes {
  self.request.text_run_cache_id() +
  text_run_cache_bytes(self.matched_family) +
  text_run_cache_bool(self.fallback_index >= 0) +
  text_run_cache_u64(self.fallback_index) +
  text_run_cache_bool(self.synthetic)
}

///|
fn FontFallbackMatchDescriptor::resource_id(
  self : FontFallbackMatchDescriptor,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:font-fallback-match:v1" + self.text_run_cache_id()
  }
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
/// Deterministic renderer cache key for a resolved native fallback match.
pub fn FontFallbackMatchDescriptor::resource_key(
  self : FontFallbackMatchDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::typeface(self.resource_id())
}

///|
/// Cache descriptor for resolved fallback/typeface match metadata.
pub fn FontFallbackMatchDescriptor::resource_descriptor(
  self : FontFallbackMatchDescriptor,
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
/// Font descriptor derived from a resolved fallback/typeface match.
pub fn FontFallbackMatchDescriptor::font_descriptor(
  self : FontFallbackMatchDescriptor,
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
/// Combined resource plan for retaining a fallback match and derived font.
pub fn FontFallbackMatchDescriptor::resource_plan(
  self : FontFallbackMatchDescriptor,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
  match_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new([
    self.resource_descriptor(byte_size=match_byte_size),
    self
    .font_descriptor(size~, scale_x~, skew_x~)
    .resource_descriptor(byte_size=font_byte_size),
  ])
}

///|
/// Value-layer metadata for a completed font fallback resolution.
pub(all) struct FontFallbackResolutionDescriptor {
  request : FontFallbackRequest
  resolved_match : FontFallbackMatchDescriptor
} derive(Debug, Eq)

///|
fn font_fallback_resolution_normalized_match(
  request : FontFallbackRequest,
  resolved_match : FontFallbackMatchDescriptor,
) -> FontFallbackMatchDescriptor {
  if resolved_match.request == request {
    resolved_match
  } else {
    request.match_descriptor(
      resolved_match.matched_family,
      fallback_index=resolved_match.fallback_index,
      synthetic=resolved_match.synthetic,
    )
  }
}

///|
pub fn FontFallbackResolutionDescriptor::new(
  request? : FontFallbackRequest = FontFallbackRequest::new(),
  resolved_match? : FontFallbackMatchDescriptor = FontFallbackMatchDescriptor::new(),
) -> FontFallbackResolutionDescriptor {
  {
    request,
    resolved_match: font_fallback_resolution_normalized_match(
      request, resolved_match,
    ),
  }
}

///|
pub fn FontFallbackRequest::resolution_descriptor(
  self : FontFallbackRequest,
  matched_family : Bytes,
  fallback_index? : Int = -1,
  synthetic? : Bool = false,
) -> FontFallbackResolutionDescriptor {
  FontFallbackResolutionDescriptor::new(
    request=self,
    resolved_match=self.match_descriptor(
      matched_family,
      fallback_index~,
      synthetic~,
    ),
  )
}

///|
pub fn FontFallbackResolutionDescriptor::is_valid(
  self : FontFallbackResolutionDescriptor,
) -> Bool {
  self.resolved_match.request == self.request && self.resolved_match.is_valid()
}

///|
pub fn FontFallbackResolutionDescriptor::matched_in_request(
  self : FontFallbackResolutionDescriptor,
) -> Bool {
  self.resolved_match.matched_in_request()
}

///|
pub fn FontFallbackResolutionDescriptor::source_family(
  self : FontFallbackResolutionDescriptor,
) -> Bytes? {
  self.resolved_match.source_family()
}

///|
fn FontFallbackResolutionDescriptor::resource_id(
  self : FontFallbackResolutionDescriptor,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:font-fallback-resolution:v1" +
    text_run_cache_bytes(self.request.resource_key().id) +
    text_run_cache_bytes(self.resolved_match.resource_key().id)
  }
}

///|
pub fn FontFallbackResolutionDescriptor::resource_key(
  self : FontFallbackResolutionDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::typeface(self.resource_id())
}

///|
pub fn FontFallbackResolutionDescriptor::resource_descriptor(
  self : FontFallbackResolutionDescriptor,
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
pub fn FontFallbackResolutionDescriptor::font_descriptor(
  self : FontFallbackResolutionDescriptor,
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
pub fn FontFallbackResolutionDescriptor::resource_plan(
  self : FontFallbackResolutionDescriptor,
  size? : Float = 12.0,
  scale_x? : Float = 1.0,
  skew_x? : Float = 0.0,
  request_byte_size? : Int64 = -1L,
  resolution_byte_size? : Int64 = -1L,
  match_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new([
    self.request.resource_descriptor(byte_size=request_byte_size),
    self.resource_descriptor(byte_size=resolution_byte_size),
    self.resolved_match.resource_descriptor(byte_size=match_byte_size),
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
    b"skia_mbt:text-run:v1" +
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

///|
fn normalized_text_measurement_width(width : Float) -> Float {
  if font_descriptor_scalar_is_finite(width) && width > 0.0 {
    width
  } else {
    1000000000.0
  }
}

///|
/// Value-layer request for measuring or shaping a text run with stable cache
/// identity and explicit font/fallback dependencies.
pub(all) struct TextMeasurementDescriptor {
  run : TextRunDescriptor
  font_key : RendererResourceKey
  width : Float
  measure_bounds : Bool
  shape : Bool
} derive(Debug, Eq)

///|
pub fn TextMeasurementDescriptor::new(
  run? : TextRunDescriptor = TextRunDescriptor::new(),
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  width? : Float = 1000000000.0,
  measure_bounds? : Bool = true,
  shape? : Bool = false,
) -> TextMeasurementDescriptor {
  {
    run,
    font_key,
    width: normalized_text_measurement_width(width),
    measure_bounds,
    shape,
  }
}

///|
pub fn TextMeasurementDescriptor::is_shaped(
  self : TextMeasurementDescriptor,
) -> Bool {
  self.shape
}

///|
pub fn TextMeasurementDescriptor::with_run(
  self : TextMeasurementDescriptor,
  run : TextRunDescriptor,
) -> TextMeasurementDescriptor {
  { ..self, run, }
}

///|
pub fn TextMeasurementDescriptor::with_font_key(
  self : TextMeasurementDescriptor,
  font_key : RendererResourceKey,
) -> TextMeasurementDescriptor {
  { ..self, font_key, }
}

///|
pub fn TextMeasurementDescriptor::with_width(
  self : TextMeasurementDescriptor,
  width : Float,
) -> TextMeasurementDescriptor {
  { ..self, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextMeasurementDescriptor::with_measure_bounds(
  self : TextMeasurementDescriptor,
  measure_bounds : Bool,
) -> TextMeasurementDescriptor {
  { ..self, measure_bounds, }
}

///|
pub fn TextMeasurementDescriptor::with_shape(
  self : TextMeasurementDescriptor,
  shape : Bool,
) -> TextMeasurementDescriptor {
  { ..self, shape, }
}

///|
pub fn TextMeasurementDescriptor::resource_key(
  self : TextMeasurementDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(
    b"skia_mbt:text-measurement:v1" +
    text_run_cache_bytes(self.run.resource_key(text, font_key=self.font_key).id) +
    self.width.to_be_bytes() +
    text_run_cache_bytes(text_run_cache_bool(self.measure_bounds)) +
    text_run_cache_bytes(text_run_cache_bool(self.shape)),
  )
}

///|
pub fn TextMeasurementDescriptor::resource_descriptor(
  self : TextMeasurementDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_key(text).id
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn TextMeasurementDescriptor::resource_plan(
  self : TextMeasurementDescriptor,
  text : Bytes,
  measurement_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(
    self.resource_descriptor(text, byte_size=measurement_byte_size),
  )
  for
    descriptor in self.run.resource_plan(
      text,
      font_key=self.font_key,
      text_byte_size~,
      font_byte_size~,
      fallback_byte_size~,
    ).descriptors {
    descriptors.push(descriptor)
  }
  RendererResourcePlan::new(descriptors)
}

///|
fn normalized_measured_text_advance(advance : Float) -> Float {
  if font_descriptor_scalar_is_finite(advance) && advance >= 0.0 {
    advance
  } else {
    0.0
  }
}

///|
fn normalized_measured_text_bounds(bounds : Rect?) -> Rect? {
  match bounds {
    None => None
    Some(bounds) =>
      if bounds.is_finite() {
        Some(bounds.sorted())
      } else {
        None
      }
  }
}

///|
fn measured_text_bounds_cache_id(bounds : Rect?) -> Bytes {
  match bounds {
    None => b"none"
    Some(bounds) =>
      b"some" +
      bounds.left().to_be_bytes() +
      bounds.top().to_be_bytes() +
      bounds.right().to_be_bytes() +
      bounds.bottom().to_be_bytes()
  }
}

///|
/// Value-layer metadata for a native text measurement result.
pub(all) struct MeasuredTextRunDescriptor {
  measurement : TextMeasurementDescriptor
  advance : Float
  bounds : Rect?
} derive(Debug, Eq)

///|
pub fn MeasuredTextRunDescriptor::new(
  measurement? : TextMeasurementDescriptor = TextMeasurementDescriptor::new(),
  advance? : Float = 0.0,
  bounds? : Rect? = None,
) -> MeasuredTextRunDescriptor {
  {
    measurement,
    advance: normalized_measured_text_advance(advance),
    bounds: normalized_measured_text_bounds(bounds),
  }
}

///|
pub fn TextMeasurementDescriptor::measured_run_descriptor(
  self : TextMeasurementDescriptor,
  advance? : Float = 0.0,
  bounds? : Rect? = None,
) -> MeasuredTextRunDescriptor {
  MeasuredTextRunDescriptor::new(measurement=self, advance~, bounds~)
}

///|
pub fn MeasuredTextRunDescriptor::has_bounds(
  self : MeasuredTextRunDescriptor,
) -> Bool {
  self.bounds is Some(_)
}

///|
pub fn MeasuredTextRunDescriptor::is_valid(
  self : MeasuredTextRunDescriptor,
) -> Bool {
  let bounds_valid = match self.bounds {
    None => true
    Some(bounds) => bounds.is_finite() && bounds.is_sorted()
  }
  font_descriptor_scalar_is_finite(self.advance) &&
  self.advance >= 0.0 &&
  bounds_valid
}

///|
fn MeasuredTextRunDescriptor::resource_id(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:measured-text-run:v1" +
    text_run_cache_bytes(self.measurement.resource_key(text).id) +
    self.advance.to_be_bytes() +
    measured_text_bounds_cache_id(self.bounds)
  }
}

///|
pub fn MeasuredTextRunDescriptor::resource_key(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn MeasuredTextRunDescriptor::resource_descriptor(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id(text)
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn MeasuredTextRunDescriptor::resource_plan(
  self : MeasuredTextRunDescriptor,
  text : Bytes,
  measured_byte_size? : Int64 = -1L,
  measurement_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=measured_byte_size))
  for
    descriptor in self.measurement.resource_plan(
      text,
      measurement_byte_size~,
      text_byte_size~,
      font_byte_size~,
      fallback_byte_size~,
    ).descriptors {
    descriptors.push(descriptor)
  }
  RendererResourcePlan::new(descriptors)
}

///|
/// Value-layer request for shaping a text run with stable cache identity and
/// explicit font/fallback dependencies.
pub(all) struct TextShapingDescriptor {
  run : TextRunDescriptor
  font_key : RendererResourceKey
  width : Float
} derive(Debug, Eq)

///|
pub fn TextShapingDescriptor::new(
  run? : TextRunDescriptor = TextRunDescriptor::new(),
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  width? : Float = 1000000000.0,
) -> TextShapingDescriptor {
  { run, font_key, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextShapingDescriptor::with_run(
  self : TextShapingDescriptor,
  run : TextRunDescriptor,
) -> TextShapingDescriptor {
  { ..self, run, }
}

///|
pub fn TextShapingDescriptor::with_font_key(
  self : TextShapingDescriptor,
  font_key : RendererResourceKey,
) -> TextShapingDescriptor {
  { ..self, font_key, }
}

///|
pub fn TextShapingDescriptor::with_width(
  self : TextShapingDescriptor,
  width : Float,
) -> TextShapingDescriptor {
  { ..self, width: normalized_text_measurement_width(width) }
}

///|
pub fn TextShapingDescriptor::measurement_descriptor(
  self : TextShapingDescriptor,
) -> TextMeasurementDescriptor {
  TextMeasurementDescriptor::new(
    run=self.run,
    font_key=self.font_key,
    width=self.width,
    measure_bounds=false,
    shape=true,
  )
}

///|
pub fn TextShapingDescriptor::resource_key(
  self : TextShapingDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(
    b"skia_mbt:text-shaping:v1" +
    text_run_cache_bytes(self.run.resource_key(text, font_key=self.font_key).id) +
    self.width.to_be_bytes(),
  )
}

///|
pub fn TextShapingDescriptor::resource_descriptor(
  self : TextShapingDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_key(text).id
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn TextShapingDescriptor::resource_plan(
  self : TextShapingDescriptor,
  text : Bytes,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=shaping_byte_size))
  for
    descriptor in self.run.resource_plan(
      text,
      font_key=self.font_key,
      text_byte_size~,
      font_byte_size~,
      fallback_byte_size~,
    ).descriptors {
    descriptors.push(descriptor)
  }
  RendererResourcePlan::new(descriptors)
}

///|
fn normalized_shaped_text_advance(advance : Point) -> Point {
  if advance.is_finite() {
    advance
  } else {
    Point::zero()
  }
}

///|
/// Value-layer metadata for a native shaped text run result.
pub(all) struct ShapedTextRunDescriptor {
  shaping : TextShapingDescriptor
  glyph_count : Int
  cluster_count : Int
  advance : Point
} derive(Debug, Eq)

///|
pub fn ShapedTextRunDescriptor::new(
  shaping? : TextShapingDescriptor = TextShapingDescriptor::new(),
  glyph_count? : Int = 0,
  cluster_count? : Int = 0,
  advance? : Point = Point::zero(),
) -> ShapedTextRunDescriptor {
  {
    shaping,
    glyph_count: Int::max(0, glyph_count),
    cluster_count: Int::max(0, cluster_count),
    advance: normalized_shaped_text_advance(advance),
  }
}

///|
pub fn TextShapingDescriptor::shaped_run_descriptor(
  self : TextShapingDescriptor,
  glyph_count? : Int = 0,
  cluster_count? : Int = 0,
  advance? : Point = Point::zero(),
) -> ShapedTextRunDescriptor {
  ShapedTextRunDescriptor::new(
    shaping=self,
    glyph_count~,
    cluster_count~,
    advance~,
  )
}

///|
pub fn ShapedTextRunDescriptor::is_valid(
  self : ShapedTextRunDescriptor,
) -> Bool {
  self.glyph_count > 0 && self.cluster_count >= 0 && self.advance.is_finite()
}

///|
fn ShapedTextRunDescriptor::resource_id(
  self : ShapedTextRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    b"skia_mbt:shaped-text-run:v1" +
    text_run_cache_bytes(self.shaping.resource_key(text).id) +
    text_run_cache_u64(self.glyph_count) +
    text_run_cache_u64(self.cluster_count) +
    self.advance.x.to_be_bytes() +
    self.advance.y.to_be_bytes()
  }
}

///|
pub fn ShapedTextRunDescriptor::resource_key(
  self : ShapedTextRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn ShapedTextRunDescriptor::resource_descriptor(
  self : ShapedTextRunDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id(text)
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn ShapedTextRunDescriptor::resource_plan(
  self : ShapedTextRunDescriptor,
  text : Bytes,
  shaped_byte_size? : Int64 = -1L,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(self.resource_descriptor(text, byte_size=shaped_byte_size))
  if self.is_valid() {
    for
      descriptor in self.shaping.resource_plan(
        text,
        shaping_byte_size~,
        text_byte_size~,
        font_byte_size~,
        fallback_byte_size~,
      ).descriptors {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}

///|
fn normalized_shaped_glyph_run_count(
  glyph_ids : Array[Int],
  positions : Array[Point],
  clusters : Array[Int],
) -> Int {
  let mut count = glyph_ids.length()
  if positions.length() < count {
    count = positions.length()
  }
  if clusters.length() < count {
    count = clusters.length()
  }
  count
}

///|
fn normalized_shaped_glyph_ids(
  glyph_ids : Array[Int],
  count : Int,
) -> Array[Int] {
  let result : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    result.push(Int::max(0, glyph_ids[index]))
  }
  result
}

///|
fn normalized_shaped_glyph_positions(
  positions : Array[Point],
  count : Int,
) -> Array[Point] {
  let result : Array[Point] = Array::new(capacity=count)
  for index in 0..<count {
    let position = positions[index]
    result.push(if position.is_finite() { position } else { Point::zero() })
  }
  result
}

///|
fn normalized_shaped_glyph_clusters(
  clusters : Array[Int],
  count : Int,
) -> Array[Int] {
  let result : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    result.push(Int::max(0, clusters[index]))
  }
  result
}

///|
fn normalized_shaped_glyph_text_run(
  shaped_run : ShapedTextRunDescriptor,
  glyph_count : Int,
  cluster_count : Int,
) -> ShapedTextRunDescriptor {
  ShapedTextRunDescriptor::new(
    shaping=shaped_run.shaping,
    glyph_count~,
    cluster_count~,
    advance=shaped_run.advance,
  )
}

///|
/// Detailed glyph IDs, positions, and clusters for a shaped text run.
pub(all) struct ShapedGlyphRunDescriptor {
  shaped_run : ShapedTextRunDescriptor
  glyph_ids : Array[Int]
  positions : Array[Point]
  clusters : Array[Int]
} derive(Debug, Eq)

///|
pub fn ShapedGlyphRunDescriptor::new(
  shaped_run? : ShapedTextRunDescriptor = ShapedTextRunDescriptor::new(),
  glyph_ids? : Array[Int] = [],
  positions? : Array[Point] = [],
  clusters? : Array[Int] = [],
) -> ShapedGlyphRunDescriptor {
  let count = normalized_shaped_glyph_run_count(glyph_ids, positions, clusters)
  let glyph_ids = normalized_shaped_glyph_ids(glyph_ids, count)
  let positions = normalized_shaped_glyph_positions(positions, count)
  let clusters = normalized_shaped_glyph_clusters(clusters, count)
  {
    shaped_run: normalized_shaped_glyph_text_run(
      shaped_run,
      count,
      clusters.length(),
    ),
    glyph_ids,
    positions,
    clusters,
  }
}

///|
pub fn ShapedTextRunDescriptor::glyph_run_descriptor(
  self : ShapedTextRunDescriptor,
  glyph_ids? : Array[Int] = [],
  positions? : Array[Point] = [],
  clusters? : Array[Int] = [],
) -> ShapedGlyphRunDescriptor {
  ShapedGlyphRunDescriptor::new(
    shaped_run=self,
    glyph_ids~,
    positions~,
    clusters~,
  )
}

///|
pub fn ShapedGlyphRunDescriptor::glyph_count(
  self : ShapedGlyphRunDescriptor,
) -> Int {
  self.glyph_ids.length()
}

///|
pub fn ShapedGlyphRunDescriptor::cluster_count(
  self : ShapedGlyphRunDescriptor,
) -> Int {
  self.clusters.length()
}

///|
pub fn ShapedGlyphRunDescriptor::is_empty(
  self : ShapedGlyphRunDescriptor,
) -> Bool {
  self.glyph_ids.is_empty()
}

///|
pub fn ShapedGlyphRunDescriptor::is_valid(
  self : ShapedGlyphRunDescriptor,
) -> Bool {
  let glyph_count = self.glyph_count()
  let mut valid = self.shaped_run.is_valid() &&
    glyph_count > 0 &&
    self.positions.length() == glyph_count &&
    self.clusters.length() == glyph_count &&
    self.shaped_run.glyph_count == glyph_count &&
    self.shaped_run.cluster_count == self.cluster_count()
  for glyph_id in self.glyph_ids {
    if glyph_id < 0 {
      valid = false
    }
  }
  for position in self.positions {
    if !position.is_finite() {
      valid = false
    }
  }
  for cluster in self.clusters {
    if cluster < 0 {
      valid = false
    }
  }
  valid
}

///|
fn ShapedGlyphRunDescriptor::resource_id(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
) -> Bytes {
  if !self.is_valid() {
    b""
  } else {
    let mut id = b"skia_mbt:shaped-glyph-run:v1" +
      text_run_cache_bytes(self.shaped_run.resource_key(text).id) +
      text_run_cache_u64(self.glyph_count())
    for glyph_id in self.glyph_ids {
      id = id + text_run_cache_u64(glyph_id)
    }
    for position in self.positions {
      id = id + position.x.to_be_bytes() + position.y.to_be_bytes()
    }
    for cluster in self.clusters {
      id = id + text_run_cache_u64(cluster)
    }
    id
  }
}

///|
pub fn ShapedGlyphRunDescriptor::resource_key(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
) -> RendererResourceKey {
  RendererResourceKey::text_run(self.resource_id(text))
}

///|
pub fn ShapedGlyphRunDescriptor::resource_descriptor(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id(text)
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::text_run(id, byte_size=measured_byte_size)
}

///|
pub fn ShapedGlyphRunDescriptor::resource_plan(
  self : ShapedGlyphRunDescriptor,
  text : Bytes,
  glyph_run_byte_size? : Int64 = -1L,
  shaped_byte_size? : Int64 = -1L,
  shaping_byte_size? : Int64 = -1L,
  text_byte_size? : Int64 = -1L,
  font_byte_size? : Int64 = 0L,
  fallback_byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  descriptors.push(
    self.resource_descriptor(text, byte_size=glyph_run_byte_size),
  )
  if self.is_valid() {
    for
      descriptor in self.shaped_run.resource_plan(
        text,
        shaped_byte_size~,
        shaping_byte_size~,
        text_byte_size~,
        font_byte_size~,
        fallback_byte_size~,
      ).descriptors {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}
