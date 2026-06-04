///|
/// Member positions in a 3x3 Skia matrix.
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
