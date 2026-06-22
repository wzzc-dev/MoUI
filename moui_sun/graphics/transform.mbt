///|
/// 2D affine transformation matrix
/// | a  b  tx |
/// | c  d  ty |
/// | 0  0  1  |
pub struct Transform {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
} derive(Eq, Debug)

///|
/// Create an identity transform
pub fn Transform::identity() -> Transform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0 }
}

///|
/// Create an arbitrary affine transform.
pub fn Transform::affine(
  a~ : Double,
  b~ : Double,
  c~ : Double,
  d~ : Double,
  tx~ : Double,
  ty~ : Double,
) -> Transform {
  { a, b, c, d, tx, ty }
}

///|
/// Create a translation transform
pub fn Transform::translate(tx~ : Double, ty~ : Double) -> Transform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx, ty }
}

///|
/// Create a scale transform
pub fn Transform::scale(sx~ : Double, sy~ : Double) -> Transform {
  { a: sx, b: 0.0, c: 0.0, d: sy, tx: 0.0, ty: 0.0 }
}

///|
/// Create a rotation transform (angle in radians)
pub fn Transform::rotate(angle : Double) -> Transform {
  let cos_a = @math.cos(angle)
  let sin_a = @math.sin(angle)
  { a: cos_a, b: -sin_a, c: sin_a, d: cos_a, tx: 0.0, ty: 0.0 }
}

///|
/// Apply transform to a point
pub fn Transform::apply(
  self : Transform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let new_x = self.a * x + self.b * y + self.tx
  let new_y = self.c * x + self.d * y + self.ty
  (new_x, new_y)
}

///|
/// Multiply two transforms
pub fn Transform::multiply(self : Transform, other : Transform) -> Transform {
  {
    a: self.a * other.a + self.b * other.c,
    b: self.a * other.b + self.b * other.d,
    c: self.c * other.a + self.d * other.c,
    d: self.c * other.b + self.d * other.d,
    tx: self.a * other.tx + self.b * other.ty + self.tx,
    ty: self.c * other.tx + self.d * other.ty + self.ty,
  }
}

///|
/// Return the inverse transform if this matrix is invertible.
pub fn Transform::inverse(self : Transform) -> Transform? {
  let determinant = self.a * self.d - self.b * self.c
  guard determinant.abs() > 0.000000001 else { return None }
  Some({
    a: self.d / determinant,
    b: -self.b / determinant,
    c: -self.c / determinant,
    d: self.a / determinant,
    tx: (self.b * self.ty - self.d * self.tx) / determinant,
    ty: (self.c * self.tx - self.a * self.ty) / determinant,
  })
}
