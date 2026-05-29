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
pub impl Default for IPoint with fn default() {
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
pub impl Default for Point with fn default() {
  Point::zero()
}

///|
pub fn Point::is_zero(self : Point) -> Bool {
  self.x == 0 && self.y == 0
}

///|
pub fn Point::is_finite(self : Point) -> Bool {
  geometry_scalar_is_finite(self.x) && geometry_scalar_is_finite(self.y)
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
pub fn Point::dot(self : Point, other : Point) -> Scalar {
  self.x * other.x + self.y * other.y
}

///|
pub fn Point::cross(self : Point, other : Point) -> Scalar {
  self.x * other.y - self.y * other.x
}

///|
pub fn Point::length_squared(self : Point) -> Scalar {
  self.dot(self)
}

///|
pub fn Point::length(self : Point) -> Scalar {
  self.length_squared().sqrt()
}

///|
pub fn Point::distance_to_origin(self : Point) -> Scalar {
  self.length()
}

///|
pub fn Point::distance_to(self : Point, other : Point) -> Scalar {
  Point::new(self.x - other.x, self.y - other.y).length()
}

///|
pub fn Point::distance_to_squared(self : Point, other : Point) -> Scalar {
  Point::new(self.x - other.x, self.y - other.y).length_squared()
}

///|
pub fn Point::distance_to_origin_squared(self : Point) -> Scalar {
  self.length_squared()
}

///|
pub fn Point::with_length(self : Point, length : Scalar) -> Point? {
  if !self.is_finite() || !geometry_scalar_is_finite(length) || length < 0.0 {
    None
  } else {
    let current_length = self.length()
    if current_length == 0.0 || !geometry_scalar_is_finite(current_length) {
      None
    } else {
      Some(self.scale(length / current_length))
    }
  }
}

///|
pub fn Point::normalized(self : Point) -> Point? {
  self.with_length(1.0)
}

///|
pub fn Point::rotate_cw(self : Point) -> Point {
  Point::new(self.y, -self.x)
}

///|
pub fn Point::rotate_ccw(self : Point) -> Point {
  Point::new(-self.y, self.x)
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
pub impl Default for ISize with fn default() {
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
pub impl Default for Size with fn default() {
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
pub fn Size::is_finite(self : Size) -> Bool {
  geometry_scalar_is_finite(self.width) &&
  geometry_scalar_is_finite(self.height)
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
pub fn IRect::from_ltrb(
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> IRect {
  IRect::new(left, top, right, bottom)
}

///|
pub fn IRect::empty() -> IRect {
  IRect::new(0, 0, 0, 0)
}

///|
pub fn IRect::from_wh(width : Int, height : Int) -> IRect {
  IRect::from_xywh(0, 0, width, height)
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
pub fn IRect::from_point_and_size(point : IPoint, size : ISize) -> IRect {
  IRect::from_xywh(point.x, point.y, size.width, size.height)
}

///|
pub impl Default for IRect with fn default() {
  IRect::empty()
}

///|
pub fn IRect::x(self : IRect) -> Int {
  self.left
}

///|
pub fn IRect::y(self : IRect) -> Int {
  self.top
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
pub fn IRect::is_sorted(self : IRect) -> Bool {
  self.left <= self.right && self.top <= self.bottom
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
pub fn IRect::with_offset(self : IRect, offset : IPoint) -> IRect {
  self.offset(offset.x, offset.y)
}

///|
pub fn IRect::with_offset_to(self : IRect, point : IPoint) -> IRect {
  IRect::from_xywh(point.x, point.y, self.width(), self.height())
}

///|
pub fn IRect::inset(self : IRect, dx : Int, dy : Int) -> IRect {
  IRect::new(self.left + dx, self.top + dy, self.right - dx, self.bottom - dy)
}

///|
pub fn IRect::with_inset(self : IRect, inset : ISize) -> IRect {
  self.inset(inset.width, inset.height)
}

///|
pub fn IRect::outset(self : IRect, dx : Int, dy : Int) -> IRect {
  self.inset(-dx, -dy)
}

///|
pub fn IRect::with_outset(self : IRect, outset : ISize) -> IRect {
  self.outset(outset.width, outset.height)
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
pub fn Rect::from_ltrb(
  left : Scalar,
  top : Scalar,
  right : Scalar,
  bottom : Scalar,
) -> Rect {
  Rect::new(left, top, right, bottom)
}

///|
pub fn Rect::empty() -> Rect {
  Rect::new(0, 0, 0, 0)
}

///|
pub fn Rect::from_wh(width : Scalar, height : Scalar) -> Rect {
  Rect::from_xywh(0, 0, width, height)
}

///|
pub fn Rect::from_iwh(width : Int, height : Int) -> Rect {
  Rect::from_wh(Float::from_int(width), Float::from_int(height))
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
pub fn Rect::from_isize(size : ISize) -> Rect {
  Rect::from_size(size.to_size())
}

///|
pub fn Rect::from_point_and_size(point : Point, size : Size) -> Rect {
  Rect::from_xywh(point.x, point.y, size.width, size.height)
}

///|
pub fn Rect::from_points(points : Array[Point]) -> Rect? {
  if points.is_empty() {
    None
  } else {
    let first = points[0]
    let mut left = first.x
    let mut top = first.y
    let mut right = first.x
    let mut bottom = first.y
    for i in 1..<points.length() {
      let point = points[i]
      left = Float::min(left, point.x)
      top = Float::min(top, point.y)
      right = Float::max(right, point.x)
      bottom = Float::max(bottom, point.y)
    }
    Some(Rect::new(left, top, right, bottom))
  }
}

///|
pub fn Rect::from_points_or_empty(points : Array[Point]) -> Rect {
  match Rect::from_points(points) {
    Some(rect) => rect
    None => Rect::empty()
  }
}

///|
pub fn Rect::from_irect(rect : IRect) -> Rect {
  rect.to_rect()
}

///|
pub impl Default for Rect with fn default() {
  Rect::empty()
}

///|
pub fn Rect::x(self : Rect) -> Scalar {
  self.left
}

///|
pub fn Rect::y(self : Rect) -> Scalar {
  self.top
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
pub fn Rect::center_x(self : Rect) -> Scalar {
  self.left * 0.5 + self.right * 0.5
}

///|
pub fn Rect::center_y(self : Rect) -> Scalar {
  self.top * 0.5 + self.bottom * 0.5
}

///|
pub fn Rect::center(self : Rect) -> Point {
  Point::new(self.center_x(), self.center_y())
}

///|
pub fn Rect::top_left(self : Rect) -> Point {
  Point::new(self.left, self.top)
}

///|
pub fn Rect::top_right(self : Rect) -> Point {
  Point::new(self.right, self.top)
}

///|
pub fn Rect::bottom_right(self : Rect) -> Point {
  Point::new(self.right, self.bottom)
}

///|
pub fn Rect::bottom_left(self : Rect) -> Point {
  Point::new(self.left, self.bottom)
}

///|
pub fn Rect::to_quad(
  self : Rect,
  direction? : PathDirection = CW,
) -> Array[Point] {
  if direction is CW {
    [self.top_left(), self.top_right(), self.bottom_right(), self.bottom_left()]
  } else {
    [self.top_left(), self.bottom_left(), self.bottom_right(), self.top_right()]
  }
}

///|
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.right <= self.left || self.bottom <= self.top
}

///|
pub fn Rect::is_sorted(self : Rect) -> Bool {
  self.left <= self.right && self.top <= self.bottom
}

///|
fn geometry_scalar_is_finite(value : Scalar) -> Bool {
  value == value && value - value == 0.0
}

///|
pub fn Rect::is_finite(self : Rect) -> Bool {
  geometry_scalar_is_finite(self.left) &&
  geometry_scalar_is_finite(self.top) &&
  geometry_scalar_is_finite(self.right) &&
  geometry_scalar_is_finite(self.bottom)
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
pub fn Rect::with_offset(self : Rect, offset : Point) -> Rect {
  self.offset(offset.x, offset.y)
}

///|
pub fn Rect::with_offset_to(self : Rect, point : Point) -> Rect {
  Rect::from_xywh(point.x, point.y, self.width(), self.height())
}

///|
pub fn Rect::inset(self : Rect, dx : Scalar, dy : Scalar) -> Rect {
  Rect::new(self.left + dx, self.top + dy, self.right - dx, self.bottom - dy)
}

///|
pub fn Rect::with_inset(self : Rect, inset : Size) -> Rect {
  self.inset(inset.width, inset.height)
}

///|
pub fn Rect::outset(self : Rect, dx : Scalar, dy : Scalar) -> Rect {
  self.inset(-dx, -dy)
}

///|
pub fn Rect::with_outset(self : Rect, outset : Size) -> Rect {
  self.outset(outset.width, outset.height)
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
pub fn Rect::round(self : Rect) -> IRect {
  IRect::new(
    self.left.round().to_int(),
    self.top.round().to_int(),
    self.right.round().to_int(),
    self.bottom.round().to_int(),
  )
}

///|
pub fn Rect::round_in(self : Rect) -> IRect {
  IRect::new(
    self.left.ceil().to_int(),
    self.top.ceil().to_int(),
    self.right.floor().to_int(),
    self.bottom.floor().to_int(),
  )
}

///|
pub fn Rect::round_out(self : Rect) -> IRect {
  IRect::new(
    self.left.floor().to_int(),
    self.top.floor().to_int(),
    self.right.ceil().to_int(),
    self.bottom.ceil().to_int(),
  )
}

///|
pub fn Rect::to_irect_round(self : Rect) -> IRect {
  self.round()
}

///|
/// Rounded rectangle bounds plus per-corner x/y radii.
///
/// Corners are stored in Skia order: upper-left, upper-right, lower-right,
/// lower-left.
pub(all) struct RRect {
  rect : Rect
  upper_left : Size
  upper_right : Size
  lower_right : Size
  lower_left : Size
} derive(Debug, Eq)

///|
fn normalize_rrect_radius(radius : Size) -> Size {
  if radius.width <= 0.0 || radius.height <= 0.0 {
    Size::empty()
  } else {
    radius
  }
}

///|
fn scale_rrect_radius(radius : Size, scale : Scalar) -> Size {
  Size::new(radius.width * scale, radius.height * scale)
}

///|
pub fn RRect::new(
  rect : Rect,
  upper_left : Size,
  upper_right : Size,
  lower_right : Size,
  lower_left : Size,
) -> RRect {
  let rect = rect.sorted()
  if rect.is_empty() {
    RRect::empty()
  } else {
    let upper_left = normalize_rrect_radius(upper_left)
    let upper_right = normalize_rrect_radius(upper_right)
    let lower_right = normalize_rrect_radius(lower_right)
    let lower_left = normalize_rrect_radius(lower_left)
    let width = rect.width()
    let height = rect.height()
    let top_width = upper_left.width + upper_right.width
    let bottom_width = lower_left.width + lower_right.width
    let left_height = upper_left.height + lower_left.height
    let right_height = upper_right.height + lower_right.height
    let scale : Scalar = 1.0
    let scale = if top_width > width && top_width > 0.0 {
      Float::min(scale, width / top_width)
    } else {
      scale
    }
    let scale = if bottom_width > width && bottom_width > 0.0 {
      Float::min(scale, width / bottom_width)
    } else {
      scale
    }
    let scale = if left_height > height && left_height > 0.0 {
      Float::min(scale, height / left_height)
    } else {
      scale
    }
    let scale = if right_height > height && right_height > 0.0 {
      Float::min(scale, height / right_height)
    } else {
      scale
    }
    {
      rect,
      upper_left: scale_rrect_radius(upper_left, scale),
      upper_right: scale_rrect_radius(upper_right, scale),
      lower_right: scale_rrect_radius(lower_right, scale),
      lower_left: scale_rrect_radius(lower_left, scale),
    }
  }
}

///|
pub fn RRect::empty() -> RRect {
  {
    rect: Rect::empty(),
    upper_left: Size::empty(),
    upper_right: Size::empty(),
    lower_right: Size::empty(),
    lower_left: Size::empty(),
  }
}

///|
pub fn RRect::from_rect(rect : Rect) -> RRect {
  RRect::new(rect, Size::empty(), Size::empty(), Size::empty(), Size::empty())
}

///|
pub fn RRect::from_rect_xy(rect : Rect, rx : Scalar, ry : Scalar) -> RRect {
  let radius = Size::new(rx, ry)
  RRect::new(rect, radius, radius, radius, radius)
}

///|
pub fn RRect::from_oval(oval : Rect) -> RRect {
  let oval = oval.sorted()
  if oval.is_empty() {
    RRect::empty()
  } else {
    RRect::from_rect_xy(oval, oval.width() / 2.0, oval.height() / 2.0)
  }
}

///|
pub impl Default for RRect with fn default() {
  RRect::empty()
}

///|
pub fn RRect::bounds(self : RRect) -> Rect {
  self.rect
}

///|
pub fn RRect::width(self : RRect) -> Scalar {
  self.rect.width()
}

///|
pub fn RRect::height(self : RRect) -> Scalar {
  self.rect.height()
}

///|
pub fn RRect::is_empty(self : RRect) -> Bool {
  self.rect.is_empty()
}

///|
pub fn RRect::is_rect(self : RRect) -> Bool {
  !self.is_empty() &&
  self.upper_left.is_zero() &&
  self.upper_right.is_zero() &&
  self.lower_right.is_zero() &&
  self.lower_left.is_zero()
}

///|
pub fn RRect::is_simple(self : RRect) -> Bool {
  !self.is_empty() &&
  !self.is_rect() &&
  !self.is_oval() &&
  self.upper_left == self.upper_right &&
  self.upper_left == self.lower_right &&
  self.upper_left == self.lower_left
}

///|
pub fn RRect::is_oval(self : RRect) -> Bool {
  !self.is_empty() &&
  self.upper_left == Size::new(self.width() / 2.0, self.height() / 2.0) &&
  self.upper_left == self.upper_right &&
  self.upper_left == self.lower_right &&
  self.upper_left == self.lower_left
}

///|
pub fn RRect::offset(self : RRect, dx : Scalar, dy : Scalar) -> RRect {
  RRect::new(
    self.rect.offset(dx, dy),
    self.upper_left,
    self.upper_right,
    self.lower_right,
    self.lower_left,
  )
}

///|
pub fn RRect::with_offset(self : RRect, delta : Point) -> RRect {
  self.offset(delta.x, delta.y)
}

///|
pub fn RRect::with_offset_to(self : RRect, point : Point) -> RRect {
  let rect = self.bounds()
  self.with_offset(Point::new(point.x - rect.x(), point.y - rect.y()))
}

///|
pub fn RRect::with_inset(self : RRect, inset : Size) -> RRect {
  RRect::new(
    self.bounds().with_inset(inset),
    Size::new(
      Float::max(self.upper_left.width - inset.width, 0.0),
      Float::max(self.upper_left.height - inset.height, 0.0),
    ),
    Size::new(
      Float::max(self.upper_right.width - inset.width, 0.0),
      Float::max(self.upper_right.height - inset.height, 0.0),
    ),
    Size::new(
      Float::max(self.lower_right.width - inset.width, 0.0),
      Float::max(self.lower_right.height - inset.height, 0.0),
    ),
    Size::new(
      Float::max(self.lower_left.width - inset.width, 0.0),
      Float::max(self.lower_left.height - inset.height, 0.0),
    ),
  )
}

///|
pub fn RRect::with_outset(self : RRect, outset : Size) -> RRect {
  RRect::new(
    self.bounds().with_outset(outset),
    Size::new(
      self.upper_left.width + outset.width,
      self.upper_left.height + outset.height,
    ),
    Size::new(
      self.upper_right.width + outset.width,
      self.upper_right.height + outset.height,
    ),
    Size::new(
      self.lower_right.width + outset.width,
      self.lower_right.height + outset.height,
    ),
    Size::new(
      self.lower_left.width + outset.width,
      self.lower_left.height + outset.height,
    ),
  )
}

///|
pub fn RRect::contains_rect(self : RRect, rect : Rect) -> Bool {
  let rect = rect.sorted()
  if self.is_empty() || rect.is_empty() || !self.bounds().contains_rect(rect) {
    false
  } else {
    self.contains_xy(rect.left, rect.top) &&
    self.contains_xy(rect.right, rect.top) &&
    self.contains_xy(rect.right, rect.bottom) &&
    self.contains_xy(rect.left, rect.bottom)
  }
}

///|
fn RRect::contains_xy(self : RRect, x : Scalar, y : Scalar) -> Bool {
  let rect = self.bounds()
  let left = rect.left
  let top = rect.top
  let right = rect.right
  let bottom = rect.bottom
  if x < left || x > right || y < top || y > bottom {
    false
  } else {
    let contains_corner = fn(
      corner_x : Scalar,
      corner_y : Scalar,
      radius : Size,
    ) -> Bool {
      if radius.is_zero() {
        true
      } else {
        let dx = x - corner_x
        let dy = y - corner_y
        dx * dx / (radius.width * radius.width) +
        dy * dy / (radius.height * radius.height) <=
        1.0
      }
    }

    if x < left + self.upper_left.width && y < top + self.upper_left.height {
      contains_corner(
        left + self.upper_left.width,
        top + self.upper_left.height,
        self.upper_left,
      )
    } else if x > right - self.upper_right.width &&
      y < top + self.upper_right.height {
      contains_corner(
        right - self.upper_right.width,
        top + self.upper_right.height,
        self.upper_right,
      )
    } else if x > right - self.lower_right.width &&
      y > bottom - self.lower_right.height {
      contains_corner(
        right - self.lower_right.width,
        bottom - self.lower_right.height,
        self.lower_right,
      )
    } else if x < left + self.lower_left.width &&
      y > bottom - self.lower_left.height {
      contains_corner(
        left + self.lower_left.width,
        bottom - self.lower_left.height,
        self.lower_left,
      )
    } else {
      true
    }
  }
}
