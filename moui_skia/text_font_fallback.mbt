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
  if self.is_empty() {
    b""
  } else {
    b"moui_skia:font-fallback:v1" + self.text_run_cache_id()
  }
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
    b"moui_skia:font-fallback-match:v1" + self.text_run_cache_id()
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
  if self.is_empty() {
    RendererResourcePlan::new([
      self.resource_descriptor(byte_size=fallback_byte_size),
    ])
  } else {
    RendererResourcePlan::new([
      self.resource_descriptor(byte_size=fallback_byte_size),
      self
      .font_descriptor(size~, scale_x~, skew_x~)
      .resource_descriptor(byte_size=font_byte_size),
    ])
  }
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
  if self.is_valid() {
    RendererResourcePlan::new([
      self.resource_descriptor(byte_size=match_byte_size),
      self
      .font_descriptor(size~, scale_x~, skew_x~)
      .resource_descriptor(byte_size=font_byte_size),
    ])
  } else {
    RendererResourcePlan::new([
      self.resource_descriptor(byte_size=match_byte_size),
    ])
  }
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
    b"moui_skia:font-fallback-resolution:v1" +
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
  if self.is_valid() {
    RendererResourcePlan::new([
      self.request.resource_descriptor(byte_size=request_byte_size),
      self.resource_descriptor(byte_size=resolution_byte_size),
      self.resolved_match.resource_descriptor(byte_size=match_byte_size),
      self
      .font_descriptor(size~, scale_x~, skew_x~)
      .resource_descriptor(byte_size=font_byte_size),
    ])
  } else {
    RendererResourcePlan::new([
      self.resource_descriptor(byte_size=resolution_byte_size),
    ])
  }
}
