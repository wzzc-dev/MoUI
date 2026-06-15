///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Size {
  width : Double
  height : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Rect {
  origin : Point
  size : Size
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Insets {
  top : Double
  right : Double
  bottom : Double
  left : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Constraints {
  min : Size
  max : Size
} derive(Eq, Debug, ToJson)

///|
pub(all) enum Axis {
  Horizontal
  Vertical
} derive(Eq, Debug, ToJson)

///|
pub fn Point::new(x~ : Double, y~ : Double) -> Point {
  { x, y }
}

///|
pub fn Size::new(width~ : Double, height~ : Double) -> Size {
  { width, height }
}

///|
pub fn Rect::new(
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
) -> Rect {
  { origin: Point::new(x~, y~), size: Size::new(width~, height~) }
}

///|
pub fn Insets::all(value : Double) -> Insets {
  { top: value, right: value, bottom: value, left: value }
}

///|
pub fn Insets::symmetric(
  horizontal? : Double = 0.0,
  vertical? : Double = 0.0,
) -> Insets {
  { top: vertical, right: horizontal, bottom: vertical, left: horizontal }
}

///|
pub fn Constraints::tight(size : Size) -> Constraints {
  { min: size, max: size }
}

///|
pub fn Constraints::loose(max : Size) -> Constraints {
  { min: Size::new(width=0.0, height=0.0), max }
}

///|
pub fn Constraints::unbounded() -> Constraints {
  {
    min: Size::new(width=0.0, height=0.0),
    max: Size::new(width=1.0e9, height=1.0e9),
  }
}

///|
pub fn Constraints::is_tight(self : Constraints) -> Bool {
  self.min == self.max
}

///|
pub fn Constraints::loosen(self : Constraints) -> Constraints {
  { min: Size::new(width=0.0, height=0.0), max: self.max }
}

///|
pub fn Constraints::tighten(
  self : Constraints,
  width? : Double,
  height? : Double,
) -> Constraints {
  let min_width = width.unwrap_or(self.min.width)
  let max_width = width.unwrap_or(self.max.width)
  let min_height = height.unwrap_or(self.min.height)
  let max_height = height.unwrap_or(self.max.height)
  {
    min: Size::new(
      width=clamp_double(min_width, self.min.width, self.max.width),
      height=clamp_double(min_height, self.min.height, self.max.height),
    ),
    max: Size::new(
      width=clamp_double(max_width, self.min.width, self.max.width),
      height=clamp_double(max_height, self.min.height, self.max.height),
    ),
  }
}

///|
pub fn Constraints::constrain(self : Constraints, size : Size) -> Size {
  size.clamp(self)
}

///|
pub fn Size::clamp(self : Size, constraints : Constraints) -> Size {
  {
    width: clamp_double(
      self.width,
      constraints.min.width,
      constraints.max.width,
    ),
    height: clamp_double(
      self.height,
      constraints.min.height,
      constraints.max.height,
    ),
  }
}

///|
pub fn Rect::contains(self : Rect, point : Point) -> Bool {
  point.x >= self.origin.x &&
  point.y >= self.origin.y &&
  point.x <= self.origin.x + self.size.width &&
  point.y <= self.origin.y + self.size.height
}

///|
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.size.width <= 0.0 || self.size.height <= 0.0
}

///|
pub fn Rect::area(self : Rect) -> Double {
  if self.is_empty() {
    0.0
  } else {
    self.size.width * self.size.height
  }
}

///|
pub fn Rect::max_x(self : Rect) -> Double {
  self.origin.x + self.size.width
}

///|
pub fn Rect::max_y(self : Rect) -> Double {
  self.origin.y + self.size.height
}

///|
pub fn Rect::union(self : Rect, other : Rect) -> Rect {
  if self.is_empty() {
    other
  } else if other.is_empty() {
    self
  } else {
    let min_x = self.origin.x.min(other.origin.x)
    let min_y = self.origin.y.min(other.origin.y)
    let max_x = self.max_x().max(other.max_x())
    let max_y = self.max_y().max(other.max_y())
    Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
  }
}

///|
pub fn Rect::intersection(self : Rect, other : Rect) -> Rect? {
  let min_x = self.origin.x.max(other.origin.x)
  let min_y = self.origin.y.max(other.origin.y)
  let max_x = self.max_x().min(other.max_x())
  let max_y = self.max_y().min(other.max_y())
  if max_x <= min_x || max_y <= min_y {
    None
  } else {
    Some(Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y))
  }
}

///|
pub fn Rect::inflate(self : Rect, value : Double) -> Rect {
  Rect::new(
    x=self.origin.x - value,
    y=self.origin.y - value,
    width=self.size.width + value * 2.0,
    height=self.size.height + value * 2.0,
  )
}

///|
pub fn Rect::clamp_to(self : Rect, bounds : Rect) -> Rect? {
  self.intersection(bounds)
}

///|
pub fn Rect::inset(self : Rect, insets : Insets) -> Rect {
  Rect::new(
    x=self.origin.x + insets.left,
    y=self.origin.y + insets.top,
    width=max_double(0.0, self.size.width - insets.left - insets.right),
    height=max_double(0.0, self.size.height - insets.top - insets.bottom),
  )
}

///|
pub fn Rect::offset(
  self : Rect,
  dx? : Double = 0.0,
  dy? : Double = 0.0,
) -> Rect {
  Rect::new(
    x=self.origin.x + dx,
    y=self.origin.y + dy,
    width=self.size.width,
    height=self.size.height,
  )
}

///|
pub fn Constraints::deflate(self : Constraints, insets : Insets) -> Constraints {
  let horizontal = insets.left + insets.right
  let vertical = insets.top + insets.bottom
  {
    min: Size::new(
      width=max_double(0.0, self.min.width - horizontal),
      height=max_double(0.0, self.min.height - vertical),
    ),
    max: Size::new(
      width=max_double(0.0, self.max.width - horizontal),
      height=max_double(0.0, self.max.height - vertical),
    ),
  }
}

///|
pub fn Size::inflate(self : Size, insets : Insets) -> Size {
  Size::new(
    width=self.width + insets.left + insets.right,
    height=self.height + insets.top + insets.bottom,
  )
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
