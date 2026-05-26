///|
/// Integer point or vector.
pub(all) struct IPoint {
  x : Int
  y : Int
} derive(Debug, Eq)

///|
pub fn IPoint::new(x : Int, y : Int) -> IPoint {
  { x, y }
}

///|
pub fn IPoint::zero() -> IPoint {
  IPoint::new(0, 0)
}

///|
pub impl Default for IPoint with default() {
  IPoint::zero()
}

///|
pub fn IPoint::is_zero(self : IPoint) -> Bool {
  self.x == 0 && self.y == 0
}

///|
pub fn IPoint::equals(self : IPoint, x : Int, y : Int) -> Bool {
  self == IPoint::new(x, y)
}

///|
pub fn IPoint::offset(self : IPoint, dx : Int, dy : Int) -> IPoint {
  IPoint::new(self.x + dx, self.y + dy)
}

///|
pub fn IPoint::to_point(self : IPoint) -> Point {
  Point::new(Float::from_int(self.x), Float::from_int(self.y))
}

///|
/// Floating-point point or vector.
pub(all) struct Point {
  x : Scalar
  y : Scalar
} derive(Debug, Eq)

///|
pub fn Point::new(x : Scalar, y : Scalar) -> Point {
  { x, y }
}

///|
pub fn Point::zero() -> Point {
  Point::new(0, 0)
}

///|
pub impl Default for Point with default() {
  Point::zero()
}

///|
pub fn Point::is_zero(self : Point) -> Bool {
  self.x == 0 && self.y == 0
}

///|
pub fn Point::equals(self : Point, x : Scalar, y : Scalar) -> Bool {
  self == Point::new(x, y)
}

///|
pub fn Point::offset(self : Point, dx : Scalar, dy : Scalar) -> Point {
  Point::new(self.x + dx, self.y + dy)
}

///|
pub fn Point::scale(self : Point, scale : Scalar) -> Point {
  Point::new(self.x * scale, self.y * scale)
}

///|
pub fn Point::length(self : Point) -> Scalar {
  (self.x * self.x + self.y * self.y).sqrt()
}

///|
pub fn Point::distance_to_origin(self : Point) -> Scalar {
  self.length()
}

///|
pub fn Point::to_ipoint_round(self : Point) -> IPoint {
  IPoint::new(self.x.round().to_int(), self.y.round().to_int())
}

///|
/// Integer width and height.
pub(all) struct ISize {
  width : Int
  height : Int
} derive(Debug, Eq)

///|
pub fn ISize::new(width : Int, height : Int) -> ISize {
  { width, height }
}

///|
pub fn ISize::empty() -> ISize {
  ISize::new(0, 0)
}

///|
pub impl Default for ISize with default() {
  ISize::empty()
}

///|
pub fn ISize::is_zero(self : ISize) -> Bool {
  self.width == 0 && self.height == 0
}

///|
pub fn ISize::is_empty(self : ISize) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
pub fn ISize::area(self : ISize) -> Int64 {
  self.width.to_int64() * self.height.to_int64()
}

///|
pub fn ISize::to_size(self : ISize) -> Size {
  Size::new(Float::from_int(self.width), Float::from_int(self.height))
}

///|
/// Floating-point width and height.
pub(all) struct Size {
  width : Scalar
  height : Scalar
} derive(Debug, Eq)

///|
pub fn Size::new(width : Scalar, height : Scalar) -> Size {
  { width, height }
}

///|
pub fn Size::empty() -> Size {
  Size::new(0, 0)
}

///|
pub fn Size::from_isize(size : ISize) -> Size {
  size.to_size()
}

///|
pub impl Default for Size with default() {
  Size::empty()
}

///|
pub fn Size::is_zero(self : Size) -> Bool {
  self.width == 0 && self.height == 0
}

///|
pub fn Size::is_empty(self : Size) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
pub fn Size::scale(self : Size, scale : Scalar) -> Size {
  Size::new(self.width * scale, self.height * scale)
}

///|
pub fn Size::to_isize_round(self : Size) -> ISize {
  ISize::new(self.width.round().to_int(), self.height.round().to_int())
}

///|
/// Integer rectangle stored as left/top/right/bottom bounds.
pub(all) struct IRect {
  left : Int
  top : Int
  right : Int
  bottom : Int
} derive(Debug, Eq)

///|
pub fn IRect::new(left : Int, top : Int, right : Int, bottom : Int) -> IRect {
  { left, top, right, bottom }
}

///|
pub fn IRect::empty() -> IRect {
  IRect::new(0, 0, 0, 0)
}

///|
pub fn IRect::from_xywh(x : Int, y : Int, width : Int, height : Int) -> IRect {
  IRect::new(x, y, x + width, y + height)
}

///|
pub fn IRect::from_size(size : ISize) -> IRect {
  IRect::from_xywh(0, 0, size.width, size.height)
}

///|
pub impl Default for IRect with default() {
  IRect::empty()
}

///|
pub fn IRect::width(self : IRect) -> Int {
  self.right - self.left
}

///|
pub fn IRect::height(self : IRect) -> Int {
  self.bottom - self.top
}

///|
pub fn IRect::size(self : IRect) -> ISize {
  ISize::new(self.width(), self.height())
}

///|
pub fn IRect::is_empty(self : IRect) -> Bool {
  self.right <= self.left || self.bottom <= self.top
}

///|
pub fn IRect::contains_point(self : IRect, point : IPoint) -> Bool {
  !self.is_empty() &&
  point.x >= self.left &&
  point.x < self.right &&
  point.y >= self.top &&
  point.y < self.bottom
}

///|
pub fn IRect::contains_rect(self : IRect, other : IRect) -> Bool {
  !self.is_empty() &&
  !other.is_empty() &&
  self.left <= other.left &&
  self.top <= other.top &&
  self.right >= other.right &&
  self.bottom >= other.bottom
}

///|
pub fn IRect::offset(self : IRect, dx : Int, dy : Int) -> IRect {
  IRect::new(self.left + dx, self.top + dy, self.right + dx, self.bottom + dy)
}

///|
pub fn IRect::inset(self : IRect, dx : Int, dy : Int) -> IRect {
  IRect::new(self.left + dx, self.top + dy, self.right - dx, self.bottom - dy)
}

///|
pub fn IRect::outset(self : IRect, dx : Int, dy : Int) -> IRect {
  self.inset(-dx, -dy)
}

///|
pub fn IRect::sorted(self : IRect) -> IRect {
  IRect::new(
    Int::min(self.left, self.right),
    Int::min(self.top, self.bottom),
    Int::max(self.left, self.right),
    Int::max(self.top, self.bottom),
  )
}

///|
pub fn IRect::intersect(self : IRect, other : IRect) -> IRect? {
  let result = IRect::new(
    Int::max(self.left, other.left),
    Int::max(self.top, other.top),
    Int::min(self.right, other.right),
    Int::min(self.bottom, other.bottom),
  )
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
pub fn IRect::join(self : IRect, other : IRect) -> IRect {
  if self.is_empty() {
    other
  } else if other.is_empty() {
    self
  } else {
    IRect::new(
      Int::min(self.left, other.left),
      Int::min(self.top, other.top),
      Int::max(self.right, other.right),
      Int::max(self.bottom, other.bottom),
    )
  }
}

///|
pub fn IRect::to_rect(self : IRect) -> Rect {
  Rect::new(
    Float::from_int(self.left),
    Float::from_int(self.top),
    Float::from_int(self.right),
    Float::from_int(self.bottom),
  )
}

///|
/// Floating-point rectangle stored as left/top/right/bottom bounds.
pub(all) struct Rect {
  left : Scalar
  top : Scalar
  right : Scalar
  bottom : Scalar
} derive(Debug, Eq)

///|
pub fn Rect::new(
  left : Scalar,
  top : Scalar,
  right : Scalar,
  bottom : Scalar,
) -> Rect {
  { left, top, right, bottom }
}

///|
pub fn Rect::empty() -> Rect {
  Rect::new(0, 0, 0, 0)
}

///|
pub fn Rect::from_xywh(
  x : Scalar,
  y : Scalar,
  width : Scalar,
  height : Scalar,
) -> Rect {
  Rect::new(x, y, x + width, y + height)
}

///|
pub fn Rect::from_size(size : Size) -> Rect {
  Rect::from_xywh(0, 0, size.width, size.height)
}

///|
pub impl Default for Rect with default() {
  Rect::empty()
}

///|
pub fn Rect::width(self : Rect) -> Scalar {
  self.right - self.left
}

///|
pub fn Rect::height(self : Rect) -> Scalar {
  self.bottom - self.top
}

///|
pub fn Rect::size(self : Rect) -> Size {
  Size::new(self.width(), self.height())
}

///|
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.right <= self.left || self.bottom <= self.top
}

///|
pub fn Rect::contains_point(self : Rect, point : Point) -> Bool {
  !self.is_empty() &&
  point.x >= self.left &&
  point.x < self.right &&
  point.y >= self.top &&
  point.y < self.bottom
}

///|
pub fn Rect::contains_rect(self : Rect, other : Rect) -> Bool {
  !self.is_empty() &&
  !other.is_empty() &&
  self.left <= other.left &&
  self.top <= other.top &&
  self.right >= other.right &&
  self.bottom >= other.bottom
}

///|
pub fn Rect::offset(self : Rect, dx : Scalar, dy : Scalar) -> Rect {
  Rect::new(self.left + dx, self.top + dy, self.right + dx, self.bottom + dy)
}

///|
pub fn Rect::inset(self : Rect, dx : Scalar, dy : Scalar) -> Rect {
  Rect::new(self.left + dx, self.top + dy, self.right - dx, self.bottom - dy)
}

///|
pub fn Rect::outset(self : Rect, dx : Scalar, dy : Scalar) -> Rect {
  self.inset(-dx, -dy)
}

///|
pub fn Rect::sorted(self : Rect) -> Rect {
  Rect::new(
    Float::min(self.left, self.right),
    Float::min(self.top, self.bottom),
    Float::max(self.left, self.right),
    Float::max(self.top, self.bottom),
  )
}

///|
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect? {
  let result = Rect::new(
    Float::max(self.left, other.left),
    Float::max(self.top, other.top),
    Float::min(self.right, other.right),
    Float::min(self.bottom, other.bottom),
  )
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
pub fn Rect::join(self : Rect, other : Rect) -> Rect {
  if self.is_empty() {
    other
  } else if other.is_empty() {
    self
  } else {
    Rect::new(
      Float::min(self.left, other.left),
      Float::min(self.top, other.top),
      Float::max(self.right, other.right),
      Float::max(self.bottom, other.bottom),
    )
  }
}

///|
pub fn Rect::to_irect_round(self : Rect) -> IRect {
  IRect::new(
    self.left.round().to_int(),
    self.top.round().to_int(),
    self.right.round().to_int(),
    self.bottom.round().to_int(),
  )
}
