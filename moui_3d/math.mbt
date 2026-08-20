///|
/// A two-dimensional vector used by the 3D addon for texture coordinates and
/// screen-space input.
pub(all) struct Vec2 {
  x : Double
  y : Double
} derive(Eq, Debug, ToJson)

///|
/// A three-dimensional vector. Public scene coordinates use `Double` so
/// camera and picking calculations stay deterministic before GPU packing.
pub(all) struct Vec3 {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug, ToJson)

///|
/// A four-dimensional vector used for colors and homogeneous coordinates.
pub(all) struct Vec4 {
  x : Double
  y : Double
  z : Double
  w : Double
} derive(Eq, Debug, ToJson)

///|
pub fn Vec2::new(x~ : Double, y~ : Double) -> Vec2 {
  { x, y }
}

///|
pub fn Vec3::new(x~ : Double, y~ : Double, z~ : Double) -> Vec3 {
  { x, y, z }
}

///|
pub fn Vec4::new(x~ : Double, y~ : Double, z~ : Double, w~ : Double) -> Vec4 {
  { x, y, z, w }
}

///|
pub fn Vec2::zero() -> Vec2 {
  { x: 0.0, y: 0.0 }
}

///|
pub fn Vec2::x(self : Vec2) -> Double {
  self.x
}

///|
pub fn Vec2::y(self : Vec2) -> Double {
  self.y
}

///|
pub fn Vec3::zero() -> Vec3 {
  { x: 0.0, y: 0.0, z: 0.0 }
}

///|
pub fn Vec3::x(self : Vec3) -> Double {
  self.x
}

///|
pub fn Vec3::y(self : Vec3) -> Double {
  self.y
}

///|
pub fn Vec3::z(self : Vec3) -> Double {
  self.z
}

///|
pub fn Vec4::zero() -> Vec4 {
  { x: 0.0, y: 0.0, z: 0.0, w: 0.0 }
}

///|
pub fn Vec4::x(self : Vec4) -> Double {
  self.x
}

///|
pub fn Vec4::y(self : Vec4) -> Double {
  self.y
}

///|
pub fn Vec4::z(self : Vec4) -> Double {
  self.z
}

///|
pub fn Vec4::w(self : Vec4) -> Double {
  self.w
}

///|
pub fn Vec3::add(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x + other.x, y: self.y + other.y, z: self.z + other.z }
}

///|
pub fn Vec3::sub(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x - other.x, y: self.y - other.y, z: self.z - other.z }
}

///|
pub fn Vec3::scale(self : Vec3, amount : Double) -> Vec3 {
  { x: self.x * amount, y: self.y * amount, z: self.z * amount }
}

///|
pub fn Vec3::dot(self : Vec3, other : Vec3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
pub fn Vec3::cross(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///|
pub fn Vec3::length_squared(self : Vec3) -> Double {
  self.dot(self)
}

///|
pub fn Vec3::length(self : Vec3) -> Double {
  self.length_squared().sqrt()
}

///|
pub fn Vec3::normalized(self : Vec3) -> Vec3 {
  let length = self.length()
  if length <= 1.0e-12 {
    Vec3::zero()
  } else {
    self.scale(1.0 / length)
  }
}

///|
pub fn Vec3::lerp(self : Vec3, other : Vec3, progress : Double) -> Vec3 {
  self.add(other.sub(self).scale(progress))
}

///|
pub fn Vec4::scale(self : Vec4, amount : Double) -> Vec4 {
  {
    x: self.x * amount,
    y: self.y * amount,
    z: self.z * amount,
    w: self.w * amount,
  }
}

///|
/// Row-major 4x4 matrix. Translation occupies indices 3, 7 and 11.
pub(all) struct Mat4 {
  values : Array[Double]
} derive(Debug)

///|
pub fn Mat4::identity() -> Mat4 {
  let values = Array::make(16, 0.0)
  values[0] = 1.0
  values[5] = 1.0
  values[10] = 1.0
  values[15] = 1.0
  { values, }
}

///|
pub fn Mat4::from_values(values : Array[Double]) -> Mat4 {
  if values.length() == 16 {
    { values: values.copy() }
  } else {
    Mat4::identity()
  }
}

///|
pub fn Mat4::values(self : Mat4) -> Array[Double] {
  self.values.copy()
}

///|
pub fn Mat4::at(self : Mat4, row : Int, column : Int) -> Double {
  if row < 0 || row >= 4 || column < 0 || column >= 4 {
    0.0
  } else {
    self.values[row * 4 + column]
  }
}

///|
pub fn Mat4::translation(offset : Vec3) -> Mat4 {
  let matrix = Mat4::identity()
  matrix.values[3] = offset.x
  matrix.values[7] = offset.y
  matrix.values[11] = offset.z
  matrix
}

///|
pub fn Mat4::scale_uniform(amount : Double) -> Mat4 {
  let matrix = Mat4::identity()
  matrix.values[0] = amount
  matrix.values[5] = amount
  matrix.values[10] = amount
  matrix
}

///|
pub fn Mat4::mul(self : Mat4, other : Mat4) -> Mat4 {
  let values = Array::make(16, 0.0)
  for row in 0..<4 {
    for column in 0..<4 {
      let mut value = 0.0
      for index in 0..<4 {
        value = value +
          self.values[row * 4 + index] * other.values[index * 4 + column]
      }
      values[row * 4 + column] = value
    }
  }
  { values, }
}

///|
pub fn Mat4::transform_point(self : Mat4, point : Vec3) -> Vec3 {
  let x = self.values[0] * point.x +
    self.values[1] * point.y +
    self.values[2] * point.z +
    self.values[3]
  let y = self.values[4] * point.x +
    self.values[5] * point.y +
    self.values[6] * point.z +
    self.values[7]
  let z = self.values[8] * point.x +
    self.values[9] * point.y +
    self.values[10] * point.z +
    self.values[11]
  let w = self.values[12] * point.x +
    self.values[13] * point.y +
    self.values[14] * point.z +
    self.values[15]
  if w.abs() <= 1.0e-12 {
    Vec3::new(x~, y~, z~)
  } else {
    Vec3::new(x=x / w, y=y / w, z=z / w)
  }
}

///|
pub fn Mat4::look_at(eye~ : Vec3, target~ : Vec3, up~ : Vec3) -> Mat4 {
  let forward = target.sub(eye).normalized()
  let right = forward.cross(up).normalized()
  let corrected_up = right.cross(forward)
  let values = [
    right.x,
    right.y,
    right.z,
    -right.dot(eye),
    corrected_up.x,
    corrected_up.y,
    corrected_up.z,
    -corrected_up.dot(eye),
    -forward.x,
    -forward.y,
    -forward.z,
    forward.dot(eye),
    0.0,
    0.0,
    0.0,
    1.0,
  ]
  { values, }
}

///|
pub fn Mat4::perspective(
  fov_y_radians~ : Double,
  aspect~ : Double,
  near~ : Double,
  far~ : Double,
) -> Mat4 {
  let safe_aspect = if aspect <= 1.0e-12 { 1.0 } else { aspect }
  let safe_near = if near <= 1.0e-9 { 1.0e-9 } else { near }
  let safe_far = if far <= safe_near { safe_near + 1.0 } else { far }
  let f = 1.0 / @math.tan(fov_y_radians / 2.0)
  let values = Array::make(16, 0.0)
  values[0] = f / safe_aspect
  values[5] = f
  values[10] = (safe_far + safe_near) / (safe_near - safe_far)
  values[11] = 2.0 * safe_far * safe_near / (safe_near - safe_far)
  values[14] = -1.0
  { values, }
}

///|
pub(all) struct Quat {
  x : Double
  y : Double
  z : Double
  w : Double
} derive(Eq, Debug, ToJson)

///|
pub fn Quat::new(x~ : Double, y~ : Double, z~ : Double, w~ : Double) -> Quat {
  { x, y, z, w }
}

///|
pub fn Quat::identity() -> Quat {
  { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
}

///|
pub fn Quat::from_axis_angle(axis~ : Vec3, angle~ : Double) -> Quat {
  let half = angle / 2.0
  let sine = @math.sin(half)
  let unit = axis.normalized()
  { x: unit.x * sine, y: unit.y * sine, z: unit.z * sine, w: @math.cos(half) }
}

///|
pub fn Quat::mul(self : Quat, other : Quat) -> Quat {
  {
    x: self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
    y: self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
    z: self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
    w: self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
  }
}

///|
pub fn Quat::rotate(self : Quat, vector : Vec3) -> Vec3 {
  let q_vector = Quat::{ x: vector.x, y: vector.y, z: vector.z, w: 0.0 }
  let inverse = Quat::{ x: -self.x, y: -self.y, z: -self.z, w: self.w }
  let rotated = self.mul(q_vector).mul(inverse)
  Vec3::new(x=rotated.x, y=rotated.y, z=rotated.z)
}

///|
pub fn Quat::to_mat4(self : Quat) -> Mat4 {
  let xx = self.x * self.x
  let yy = self.y * self.y
  let zz = self.z * self.z
  let xy = self.x * self.y
  let xz = self.x * self.z
  let yz = self.y * self.z
  let wx = self.w * self.x
  let wy = self.w * self.y
  let wz = self.w * self.z
  Mat4::from_values([
    1.0 - 2.0 * (yy + zz),
    2.0 * (xy - wz),
    2.0 * (xz + wy),
    0.0,
    2.0 * (xy + wz),
    1.0 - 2.0 * (xx + zz),
    2.0 * (yz - wx),
    0.0,
    2.0 * (xz - wy),
    2.0 * (yz + wx),
    1.0 - 2.0 * (xx + yy),
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
  ])
}

///|
pub(all) struct Aabb {
  min : Vec3
  max : Vec3
  valid : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn Aabb::empty() -> Aabb {
  { min: Vec3::zero(), max: Vec3::zero(), valid: false }
}

///|
pub fn Aabb::from_points(points : Array[Vec3]) -> Aabb {
  let mut result = Aabb::empty()
  for point in points {
    result = result.include_point(point)
  }
  result
}

///|
pub fn Aabb::include_point(self : Aabb, point : Vec3) -> Aabb {
  if !self.valid {
    { min: point, max: point, valid: true }
  } else {
    {
      min: Vec3::new(
        x=if point.x < self.min.x { point.x } else { self.min.x },
        y=if point.y < self.min.y { point.y } else { self.min.y },
        z=if point.z < self.min.z { point.z } else { self.min.z },
      ),
      max: Vec3::new(
        x=if point.x > self.max.x { point.x } else { self.max.x },
        y=if point.y > self.max.y { point.y } else { self.max.y },
        z=if point.z > self.max.z { point.z } else { self.max.z },
      ),
      valid: true,
    }
  }
}

///|
pub fn Aabb::union(self : Aabb, other : Aabb) -> Aabb {
  if !self.valid {
    other
  } else if !other.valid {
    self
  } else {
    self.include_point(other.min).include_point(other.max)
  }
}

///|
pub fn Aabb::is_valid(self : Aabb) -> Bool {
  self.valid
}

///|
pub fn Aabb::min(self : Aabb) -> Vec3 {
  self.min
}

///|
pub fn Aabb::max(self : Aabb) -> Vec3 {
  self.max
}

///|
pub fn Aabb::center(self : Aabb) -> Vec3 {
  self.min.add(self.max).scale(0.5)
}

///|
pub fn Aabb::extent(self : Aabb) -> Vec3 {
  self.max.sub(self.min)
}

///|
pub fn Aabb::radius(self : Aabb) -> Double {
  self.extent().length() * 0.5
}

///|
pub fn Aabb::transformed(self : Aabb, matrix : Mat4) -> Aabb {
  if !self.valid {
    return self
  }
  let mut result = Aabb::empty()
  for x in [self.min.x, self.max.x] {
    for y in [self.min.y, self.max.y] {
      for z in [self.min.z, self.max.z] {
        result = result.include_point(
          matrix.transform_point(Vec3::new(x~, y~, z~)),
        )
      }
    }
  }
  result
}

///|
pub(all) struct Ray {
  origin : Vec3
  direction : Vec3
} derive(Eq, Debug, ToJson)

///|
pub fn Ray::new(origin~ : Vec3, direction~ : Vec3) -> Ray {
  { origin, direction: direction.normalized() }
}

///|
pub fn Ray::origin(self : Ray) -> Vec3 {
  self.origin
}

///|
pub fn Ray::direction(self : Ray) -> Vec3 {
  self.direction
}

///|
pub fn Ray::at(self : Ray, distance : Double) -> Vec3 {
  self.origin.add(self.direction.scale(distance))
}

///|
pub fn Ray::intersect_aabb(self : Ray, bounds : Aabb) -> Bool {
  if !bounds.valid {
    return false
  }
  let mut near = -1.0e30
  let mut far = 1.0e30
  for axis in 0..<3 {
    let origin = if axis == 0 {
      self.origin.x
    } else if axis == 1 {
      self.origin.y
    } else {
      self.origin.z
    }
    let direction = if axis == 0 {
      self.direction.x
    } else if axis == 1 {
      self.direction.y
    } else {
      self.direction.z
    }
    let minimum = if axis == 0 {
      bounds.min.x
    } else if axis == 1 {
      bounds.min.y
    } else {
      bounds.min.z
    }
    let maximum = if axis == 0 {
      bounds.max.x
    } else if axis == 1 {
      bounds.max.y
    } else {
      bounds.max.z
    }
    if direction.abs() <= 1.0e-12 {
      if origin < minimum || origin > maximum {
        return false
      }
    } else {
      let inverse = 1.0 / direction
      let first = (minimum - origin) * inverse
      let second = (maximum - origin) * inverse
      let lower = if first < second { first } else { second }
      let upper = if first > second { first } else { second }
      if lower > near {
        near = lower
      }
      if upper < far {
        far = upper
      }
      if near > far || far < 0.0 {
        return false
      }
    }
  }
  true
}

///|
/// Moller-Trumbore ray/triangle intersection. Returns the positive distance.
pub fn Ray::intersect_triangle(
  self : Ray,
  a : Vec3,
  b : Vec3,
  c : Vec3,
) -> Double? {
  let edge1 = b.sub(a)
  let edge2 = c.sub(a)
  let h = self.direction.cross(edge2)
  let determinant = edge1.dot(h)
  if determinant.abs() <= 1.0e-12 {
    return None
  }
  let inverse = 1.0 / determinant
  let s = self.origin.sub(a)
  let u = inverse * s.dot(h)
  if u < 0.0 || u > 1.0 {
    return None
  }
  let q = s.cross(edge1)
  let v = inverse * self.direction.dot(q)
  if v < 0.0 || u + v > 1.0 {
    return None
  }
  let distance = inverse * edge2.dot(q)
  if distance >= 0.0 {
    Some(distance)
  } else {
    None
  }
}
