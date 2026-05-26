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
pub impl Default for Matrix with default() {
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
