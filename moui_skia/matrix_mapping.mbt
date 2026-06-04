///|
pub fn Matrix::map_point(self : Matrix, point : Point) -> Point {
  let x = self.scale_x * point.x + self.skew_x * point.y + self.trans_x
  let y = self.skew_y * point.x + self.scale_y * point.y + self.trans_y
  let z = self.persp_0 * point.x + self.persp_1 * point.y + self.persp_2
  if z == 0 || z == 1 {
    Point::new(x, y)
  } else {
    Point::new(x / z, y / z)
  }
}

///|
pub fn Matrix::map_xy(self : Matrix, x : Scalar, y : Scalar) -> Point {
  self.map_point(Point::new(x, y))
}

///|
pub fn Matrix::map_origin(self : Matrix) -> Point {
  self.map_xy(0, 0)
}

///|
pub fn Matrix::map_point_affine(self : Matrix, point : Point) -> Point? {
  if self.has_perspective() {
    None
  } else {
    Some(
      Point::new(
        self.scale_x * point.x + self.skew_x * point.y + self.trans_x,
        self.skew_y * point.x + self.scale_y * point.y + self.trans_y,
      ),
    )
  }
}

///|
pub fn Matrix::map_points(self : Matrix, points : Array[Point]) -> Array[Point] {
  points.map(fn(point) { self.map_point(point) })
}

///|
pub fn Matrix::map_vector(self : Matrix, vector : Point) -> Point {
  Matrix::new_all(
    self.scale_x,
    self.skew_x,
    0,
    self.skew_y,
    self.scale_y,
    0,
    self.persp_0,
    self.persp_1,
    self.persp_2,
  ).map_point(vector)
}

///|
pub fn Matrix::map_vectors(
  self : Matrix,
  vectors : Array[Point],
) -> Array[Point] {
  vectors.map(fn(vector) { self.map_vector(vector) })
}

///|
pub fn Matrix::map_radius(self : Matrix, radius : Scalar) -> Scalar? {
  if self.has_perspective() ||
    !self.is_finite() ||
    !geometry_scalar_is_finite(radius) {
    None
  } else {
    let area_scale = self.scale_x * self.scale_y - self.skew_x * self.skew_y
    let area_scale = if area_scale < 0 { -area_scale } else { area_scale }
    let radius = radius * area_scale.sqrt()
    if geometry_scalar_is_finite(radius) {
      Some(radius)
    } else {
      None
    }
  }
}

///|
pub fn Matrix::map_rect_to_quad(self : Matrix, rect : Rect) -> Array[Point] {
  let rect = rect.sorted()
  [
    self.map_point(Point::new(rect.left, rect.top)),
    self.map_point(Point::new(rect.right, rect.top)),
    self.map_point(Point::new(rect.right, rect.bottom)),
    self.map_point(Point::new(rect.left, rect.bottom)),
  ]
}

///|
pub fn Matrix::map_rect_scale_translate(self : Matrix, rect : Rect) -> Rect? {
  if self.is_scale_translate() {
    Some(
      Rect::new(
        rect.left * self.scale_x + self.trans_x,
        rect.top * self.scale_y + self.trans_y,
        rect.right * self.scale_x + self.trans_x,
        rect.bottom * self.scale_y + self.trans_y,
      ).sorted(),
    )
  } else {
    None
  }
}

///|
pub fn Matrix::map_rect(self : Matrix, rect : Rect) -> Rect {
  let rect = rect.sorted()
  if rect.is_empty() {
    Rect::empty()
  } else {
    let p0 = self.map_point(Point::new(rect.left, rect.top))
    let p1 = self.map_point(Point::new(rect.right, rect.top))
    let p2 = self.map_point(Point::new(rect.right, rect.bottom))
    let p3 = self.map_point(Point::new(rect.left, rect.bottom))
    Rect::new(
      Float::min(Float::min(p0.x, p1.x), Float::min(p2.x, p3.x)),
      Float::min(Float::min(p0.y, p1.y), Float::min(p2.y, p3.y)),
      Float::max(Float::max(p0.x, p1.x), Float::max(p2.x, p3.x)),
      Float::max(Float::max(p0.y, p1.y), Float::max(p2.y, p3.y)),
    )
  }
}
