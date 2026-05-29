///|
/// Member positions in a 3x3 Skia matrix.
#warnings("-deprecated_syntax")
pub(all) enum MatrixMember {
  ScaleX
  SkewX
  TransX
  SkewY
  ScaleY
  TransY
  Persp0
  Persp1
  Persp2
} derive(Debug, Eq)

///|
/// Row-major 3x3 transform matrix matching Skia's public member layout.
pub(all) struct Matrix {
  scale_x : Scalar
  skew_x : Scalar
  trans_x : Scalar
  skew_y : Scalar
  scale_y : Scalar
  trans_y : Scalar
  persp_0 : Scalar
  persp_1 : Scalar
  persp_2 : Scalar
} derive(Debug, Eq)

///|
pub fn Matrix::new_all(
  scale_x : Scalar,
  skew_x : Scalar,
  trans_x : Scalar,
  skew_y : Scalar,
  scale_y : Scalar,
  trans_y : Scalar,
  persp_0 : Scalar,
  persp_1 : Scalar,
  persp_2 : Scalar,
) -> Matrix {
  {
    scale_x,
    skew_x,
    trans_x,
    skew_y,
    scale_y,
    trans_y,
    persp_0,
    persp_1,
    persp_2,
  }
}

///|
pub fn Matrix::identity() -> Matrix {
  Matrix::new_all(1, 0, 0, 0, 1, 0, 0, 0, 1)
}

///|
pub impl Default for Matrix with fn default() {
  Matrix::identity()
}

///|
pub fn Matrix::translate(dx : Scalar, dy : Scalar) -> Matrix {
  Matrix::new_all(1, 0, dx, 0, 1, dy, 0, 0, 1)
}

///|
pub fn Matrix::scale(sx : Scalar, sy : Scalar) -> Matrix {
  Matrix::new_all(sx, 0, 0, 0, sy, 0, 0, 0, 1)
}

///|
pub fn Matrix::scale_translate(
  sx : Scalar,
  sy : Scalar,
  tx : Scalar,
  ty : Scalar,
) -> Matrix {
  Matrix::new_all(sx, 0, tx, 0, sy, ty, 0, 0, 1)
}

///|
pub fn Matrix::skew(kx : Scalar, ky : Scalar) -> Matrix {
  Matrix::new_all(1, kx, 0, ky, 1, 0, 0, 0, 1)
}

///|
pub fn Matrix::is_identity(self : Matrix) -> Bool {
  self == Matrix::identity()
}

///|
pub fn Matrix::has_perspective(self : Matrix) -> Bool {
  self.persp_0 != 0 || self.persp_1 != 0 || self.persp_2 != 1
}

///|
pub fn Matrix::is_translate(self : Matrix) -> Bool {
  self.scale_x == 1 &&
  self.skew_x == 0 &&
  self.skew_y == 0 &&
  self.scale_y == 1 &&
  self.persp_0 == 0 &&
  self.persp_1 == 0 &&
  self.persp_2 == 1
}

///|
pub fn Matrix::is_scale_translate(self : Matrix) -> Bool {
  self.skew_x == 0 &&
  self.skew_y == 0 &&
  self.persp_0 == 0 &&
  self.persp_1 == 0 &&
  self.persp_2 == 1
}

///|
pub fn Matrix::scale_x(self : Matrix) -> Scalar {
  self.scale_x
}

///|
pub fn Matrix::scale_y(self : Matrix) -> Scalar {
  self.scale_y
}

///|
pub fn Matrix::skew_x(self : Matrix) -> Scalar {
  self.skew_x
}

///|
pub fn Matrix::skew_y(self : Matrix) -> Scalar {
  self.skew_y
}

///|
pub fn Matrix::translate_x(self : Matrix) -> Scalar {
  self.trans_x
}

///|
pub fn Matrix::translate_y(self : Matrix) -> Scalar {
  self.trans_y
}

///|
pub fn Matrix::persp_x(self : Matrix) -> Scalar {
  self.persp_0
}

///|
pub fn Matrix::persp_y(self : Matrix) -> Scalar {
  self.persp_1
}

///|
pub fn Matrix::is_finite(self : Matrix) -> Bool {
  geometry_scalar_is_finite(self.scale_x) &&
  geometry_scalar_is_finite(self.skew_x) &&
  geometry_scalar_is_finite(self.trans_x) &&
  geometry_scalar_is_finite(self.skew_y) &&
  geometry_scalar_is_finite(self.scale_y) &&
  geometry_scalar_is_finite(self.trans_y) &&
  geometry_scalar_is_finite(self.persp_0) &&
  geometry_scalar_is_finite(self.persp_1) &&
  geometry_scalar_is_finite(self.persp_2)
}

///|
pub fn Matrix::get(self : Matrix, field : MatrixMember) -> Scalar {
  match field {
    ScaleX => self.scale_x
    SkewX => self.skew_x
    TransX => self.trans_x
    SkewY => self.skew_y
    ScaleY => self.scale_y
    TransY => self.trans_y
    Persp0 => self.persp_0
    Persp1 => self.persp_1
    Persp2 => self.persp_2
  }
}

///|
pub fn Matrix::values(self : Matrix) -> Array[Scalar] {
  [
    self.scale_x,
    self.skew_x,
    self.trans_x,
    self.skew_y,
    self.scale_y,
    self.trans_y,
    self.persp_0,
    self.persp_1,
    self.persp_2,
  ]
}

///|
pub fn Matrix::from_affine(values : Array[Scalar]) -> Matrix? {
  if values.length() == 6 {
    Some(
      Matrix::new_all(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
        0,
        0,
        1,
      ),
    )
  } else {
    None
  }
}

///|
pub fn Matrix::to_affine(self : Matrix) -> Array[Scalar]? {
  if self.has_perspective() {
    None
  } else {
    Some([
      self.scale_x,
      self.skew_x,
      self.trans_x,
      self.skew_y,
      self.scale_y,
      self.trans_y,
    ])
  }
}

///|
pub fn Matrix::concat(self : Matrix, other : Matrix) -> Matrix {
  Matrix::new_all(
    self.scale_x * other.scale_x +
    self.skew_x * other.skew_y +
    self.trans_x * other.persp_0,
    self.scale_x * other.skew_x +
    self.skew_x * other.scale_y +
    self.trans_x * other.persp_1,
    self.scale_x * other.trans_x +
    self.skew_x * other.trans_y +
    self.trans_x * other.persp_2,
    self.skew_y * other.scale_x +
    self.scale_y * other.skew_y +
    self.trans_y * other.persp_0,
    self.skew_y * other.skew_x +
    self.scale_y * other.scale_y +
    self.trans_y * other.persp_1,
    self.skew_y * other.trans_x +
    self.scale_y * other.trans_y +
    self.trans_y * other.persp_2,
    self.persp_0 * other.scale_x +
    self.persp_1 * other.skew_y +
    self.persp_2 * other.persp_0,
    self.persp_0 * other.skew_x +
    self.persp_1 * other.scale_y +
    self.persp_2 * other.persp_1,
    self.persp_0 * other.trans_x +
    self.persp_1 * other.trans_y +
    self.persp_2 * other.persp_2,
  )
}

///|
pub fn Matrix::pre_concat(self : Matrix, other : Matrix) -> Matrix {
  other.concat(self)
}

///|
pub fn Matrix::post_concat(self : Matrix, other : Matrix) -> Matrix {
  self.concat(other)
}

///|
pub fn Matrix::pre_translate(self : Matrix, dx : Scalar, dy : Scalar) -> Matrix {
  self.pre_concat(Matrix::translate(dx, dy))
}

///|
pub fn Matrix::post_translate(
  self : Matrix,
  dx : Scalar,
  dy : Scalar,
) -> Matrix {
  self.post_concat(Matrix::translate(dx, dy))
}

///|
pub fn Matrix::pre_scale(self : Matrix, sx : Scalar, sy : Scalar) -> Matrix {
  self.pre_concat(Matrix::scale(sx, sy))
}

///|
pub fn Matrix::post_scale(self : Matrix, sx : Scalar, sy : Scalar) -> Matrix {
  self.post_concat(Matrix::scale(sx, sy))
}

///|
pub fn Matrix::pre_skew(self : Matrix, kx : Scalar, ky : Scalar) -> Matrix {
  self.pre_concat(Matrix::skew(kx, ky))
}

///|
pub fn Matrix::post_skew(self : Matrix, kx : Scalar, ky : Scalar) -> Matrix {
  self.post_concat(Matrix::skew(kx, ky))
}

///|
pub fn Matrix::determinant(self : Matrix) -> Scalar {
  self.scale_x * (self.scale_y * self.persp_2 - self.trans_y * self.persp_1) -
  self.skew_x * (self.skew_y * self.persp_2 - self.trans_y * self.persp_0) +
  self.trans_x * (self.skew_y * self.persp_1 - self.scale_y * self.persp_0)
}

///|
pub fn Matrix::is_invertible(self : Matrix) -> Bool {
  self.determinant() != 0.0
}

///|
pub fn Matrix::invert(self : Matrix) -> Matrix? {
  let det = self.determinant()
  if det == 0.0 {
    None
  } else {
    Some(
      Matrix::new_all(
        (self.scale_y * self.persp_2 - self.trans_y * self.persp_1) / det,
        (self.trans_x * self.persp_1 - self.skew_x * self.persp_2) / det,
        (self.skew_x * self.trans_y - self.trans_x * self.scale_y) / det,
        (self.trans_y * self.persp_0 - self.skew_y * self.persp_2) / det,
        (self.scale_x * self.persp_2 - self.trans_x * self.persp_0) / det,
        (self.trans_x * self.skew_y - self.scale_x * self.trans_y) / det,
        (self.skew_y * self.persp_1 - self.scale_y * self.persp_0) / det,
        (self.skew_x * self.persp_0 - self.scale_x * self.persp_1) / det,
        (self.scale_x * self.scale_y - self.skew_x * self.skew_y) / det,
      ),
    )
  }
}

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
