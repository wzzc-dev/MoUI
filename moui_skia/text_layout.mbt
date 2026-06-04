///|
/// Lightweight text direction used by value-layer text layout contracts.
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
