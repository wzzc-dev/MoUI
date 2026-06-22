///|
/// 2D rectangle defined by origin and size
pub struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Create a rectangle
pub fn Rect::new(
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
) -> Rect {
  { x, y, width, height }
}

///|
/// Get the right edge (x + width)
pub fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
/// Get the bottom edge (y + height)
pub fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
/// Check whether this rectangle has no positive area.
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.width <= 0.0 || self.height <= 0.0
}

///|
/// Return the overlapping rectangle, if both rectangles overlap with area.
pub fn Rect::intersection(self : Rect, other : Rect) -> Rect? {
  let left = self.x.max(other.x)
  let top = self.y.max(other.y)
  let right = self.right().min(other.right())
  let bottom = self.bottom().min(other.bottom())
  let width = right - left
  let height = bottom - top
  guard width > 0.0 && height > 0.0 else { return None }
  Some(Rect::new(x=left, y=top, width~, height~))
}

///|
/// Check if a point is inside the rectangle
pub fn Rect::contains(self : Rect, px : Double, py : Double) -> Bool {
  !self.is_empty() &&
  px >= self.x &&
  px < self.right() &&
  py >= self.y &&
  py < self.bottom()
}

///|
/// 2D size (width and height)
pub struct Size {
  width : Double
  height : Double
} derive(Eq, Debug)

///|
pub fn Size::new(width~ : Double, height~ : Double) -> Size {
  { width, height }
}
