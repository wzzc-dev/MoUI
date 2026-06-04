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
fn matrix_degrees_to_radians(degrees : Scalar) -> Scalar {
  Float::from_double(degrees.to_double() * @math.PI / 180.0)
}

///|
pub fn Matrix::rotate_degrees(degrees : Scalar) -> Matrix {
  let radians = matrix_degrees_to_radians(degrees).to_double()
  let c = Float::from_double(@math.cos(radians))
  let s = Float::from_double(@math.sin(radians))
  Matrix::new_all(c, -s, 0, s, c, 0, 0, 0, 1)
}
