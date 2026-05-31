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
}

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
}

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
}

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
