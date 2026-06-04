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
pub fn Matrix::pre_rotate_degrees(self : Matrix, degrees : Scalar) -> Matrix {
  self.pre_concat(Matrix::rotate_degrees(degrees))
}

///|
pub fn Matrix::post_rotate_degrees(self : Matrix, degrees : Scalar) -> Matrix {
  self.post_concat(Matrix::rotate_degrees(degrees))
}
