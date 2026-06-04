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
