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
