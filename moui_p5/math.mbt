///|
/// Mathematical constants and helpers shared by the sketch API.
///
/// This package is renderer-neutral: it targets every MoonBit backend and is
/// also usable from a plain `moon test` without a window or GPU.

///|
pub const PI : Double = 3.141592653589793

///|
pub const TAU : Double = 6.283185307179586

///|
pub const TWO_PI : Double = 6.283185307179586

///|
pub const HALF_PI : Double = 1.5707963267948966

///|
pub const QUARTER_PI : Double = 0.7853981633974483

///|
pub const DEG_TO_RAD : Double = 0.017453292519943295

///|
pub const RAD_TO_DEG : Double = 57.29577951308232

///|
pub fn degrees(radians : Double) -> Double {
  radians * RAD_TO_DEG
}

///|
pub fn radians(degrees : Double) -> Double {
  degrees * DEG_TO_RAD
}

///|
pub fn constrain(value : Double, low : Double, high : Double) -> Double {
  value.max(low).min(high)
}

///|
pub fn lerp(start : Double, stop : Double, amount : Double) -> Double {
  start + (stop - start) * amount
}

///|
pub fn map(
  value : Double,
  start1 : Double,
  stop1 : Double,
  start2 : Double,
  stop2 : Double,
  within_bounds~ : Bool = false,
) -> Double {
  let mapped = (value - start1) / (stop1 - start1) * (stop2 - start2) + start2
  if within_bounds {
    if start2 < stop2 {
      constrain(mapped, start2, stop2)
    } else {
      constrain(mapped, stop2, start2)
    }
  } else {
    mapped
  }
}

///|
pub fn norm(value : Double, start : Double, stop : Double) -> Double {
  map(value, start, stop, 0.0, 1.0)
}

///|
pub fn dist(x1 : Double, y1 : Double, x2 : Double, y2 : Double) -> Double {
  @cmath.hypot(x2 - x1, y2 - y1)
}

///|
pub fn dist3(
  x1 : Double,
  y1 : Double,
  z1 : Double,
  x2 : Double,
  y2 : Double,
  z2 : Double,
) -> Double {
  let dx = x2 - x1
  let dy = y2 - y1
  let dz = z2 - z1
  (dx * dx + dy * dy + dz * dz).sqrt()
}

///|
pub fn mag(x : Double, y : Double) -> Double {
  @cmath.hypot(x, y)
}

///|
pub fn sq(value : Double) -> Double {
  value * value
}

///|
/// Fractional part with p5/JavaScript semantics (`fract(-1.25) == 0.75`).
pub fn fract(value : Double) -> Double {
  if value.is_nan() || value.is_inf() {
    value
  } else {
    value - value.floor()
  }
}

///|
/// JavaScript `Math.round`: ties go toward positive infinity.
pub fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
pub fn round(value : Double, decimals~ : Int32 = 0) -> Double {
  if decimals == 0 {
    return js_round(value)
  }
  let factor = @cmath.pow(10.0, decimals.to_double())
  js_round(value * factor) / factor
}

// ==== 2D affine transforms ====

///|
/// A 2D affine transform in the same layout MoUI's `Transform2D` uses:
/// `x' = a*x + c*y + tx`, `y' = b*x + d*y + ty`.
#derive(Eq)
pub(all) struct Matrix {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
}

///|
pub fn Matrix::identity() -> Matrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0, }
}

///|
pub fn Matrix::translation(x : Double, y : Double) -> Matrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: x, ty: y, }
}

///|
pub fn Matrix::scaling(x : Double, y : Double) -> Matrix {
  { a: x, b: 0.0, c: 0.0, d: y, tx: 0.0, ty: 0.0, }
}

///|
pub fn Matrix::rotation(angle : Double) -> Matrix {
  let c = @cmath.cos(angle)
  let s = @cmath.sin(angle)
  { a: c, b: s, c: -s, d: c, tx: 0.0, ty: 0.0, }
}

///|
pub fn Matrix::shear(x : Double, y : Double) -> Matrix {
  { a: 1.0, b: y, c: x, d: 1.0, tx: 0.0, ty: 0.0, }
}

///|
/// `self * other`: apply `other` first, then `self`.
pub fn Matrix::compose(self : Matrix, other : Matrix) -> Matrix {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    tx: self.a * other.tx + self.c * other.ty + self.tx,
    ty: self.b * other.tx + self.d * other.ty + self.ty,
  }
}

///|
pub fn Matrix::inverse(self : Matrix) -> Matrix {
  let det = self.a * self.d - self.b * self.c
  if det.abs() < 1.0e-12 {
    return Matrix::identity()
  }
  let a = self.d / det
  let b = -self.b / det
  let c = -self.c / det
  let d = self.a / det
  {
    a,
    b,
    c,
    d,
    tx: -(a * self.tx + c * self.ty),
    ty: -(b * self.tx + d * self.ty),
  }
}

///|
pub fn Matrix::transform_point(
  self : Matrix,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (self.a * x + self.c * y + self.tx, self.b * x + self.d * y + self.ty)
}

///|
/// Average scale factor, used for stroke widths and text sizes.
pub fn Matrix::scale_factor(self : Matrix) -> Double {
  let sx = @cmath.hypot(self.a, self.b)
  let sy = @cmath.hypot(self.c, self.d)
  (sx + sy) / 2.0
}

///|
pub fn Matrix::is_identity(self : Matrix) -> Bool {
  self == Matrix::identity()
}

// ==== Deterministic random (p5.js LCG) ====

///|
const LCG_A : UInt32 = 1664525

///|
const LCG_C : UInt32 = 1013904223

///|
const LCG_M : Double = 4294967296.0

///|
pub fn to_uint32(value : Double) -> UInt32 {
  if value.is_nan() || value.is_inf() {
    return 0
  }
  let truncated = value.trunc()
  let modulo = truncated - (truncated / LCG_M).floor() * LCG_M
  modulo.to_uint64().to_uint()
}

///|
/// A seedable pseudo-random generator matching p5.js's `randomSeed` /
/// `random` sequence (Numerical Recipes LCG).
pub struct Random {
  priv mut state : UInt32
  priv mut gaussian_previous : Bool
  priv mut gaussian_y2 : Double
}

///|
pub fn Random::new(seed : Double) -> Random {
  { state: to_uint32(seed), gaussian_previous: false, gaussian_y2: 0.0, }
}

///|
pub fn Random::set_seed(self : Random, seed : Double) -> Unit {
  self.state = to_uint32(seed)
  self.gaussian_previous = false
}

///|
pub fn Random::next(self : Random) -> Double {
  self.state = LCG_A * self.state + LCG_C
  self.state.to_double() / LCG_M
}

///|
pub fn Random::range(self : Random, min : Double, max : Double) -> Double {
  let (low, high) = if min > max { (max, min) } else { (min, max) }
  self.next() * (high - low) + low
}

///|
pub fn[T] Random::choice(self : Random, choices : ArrayView[T]) -> T {
  let index = (self.next() * choices.length().to_double()).floor().to_int()
  choices[index]
}

///|
/// Marsaglia polar method, as in p5.js `randomGaussian`.
pub fn Random::gaussian(
  self : Random,
  mean~ : Double = 0.0,
  sd~ : Double = 1.0,
) -> Double {
  let value = if self.gaussian_previous {
    self.gaussian_previous = false
    self.gaussian_y2
  } else {
    let (x1, x2, w) = for ;; {
      let x1 = self.next() * 2.0 - 1.0
      let x2 = self.next() * 2.0 - 1.0
      let w = x1 * x1 + x2 * x2
      if w < 1.0 && w > 0.0 {
        break (x1, x2, w)
      }
    }
    let scale = (-2.0 * @cmath.ln(w) / w).sqrt()
    self.gaussian_y2 = x2 * scale
    self.gaussian_previous = true
    x1 * scale
  }
  value * sd + mean
}

// ==== Perlin noise (p5.js octave lattice) ====

///|
const PERLIN_YWRAPB : Int32 = 4

///|
const PERLIN_YWRAP : Int32 = 16

///|
const PERLIN_ZWRAPB : Int32 = 8

///|
const PERLIN_ZWRAP : Int32 = 256

///|
const PERLIN_SIZE : Int32 = 4095

///|
/// A Perlin noise generator matching p5.js's `noise`, `noiseSeed`, and
/// `noiseDetail`.
pub struct Noise {
  priv perlin : FixedArray[Double]
  priv mut octaves : Int32
  priv mut amp_falloff : Double
}

///|
pub fn Noise::new(seed : Double) -> Noise {
  let noise = {
    perlin: FixedArray::make(PERLIN_SIZE + 1, 0.0),
    octaves: 4,
    amp_falloff: 0.5,
  }
  noise.set_seed(seed)
  noise
}

///|
pub fn Noise::set_seed(self : Noise, seed : Double) -> Unit {
  let rng = Random::new(seed)
  for index in 0..<=PERLIN_SIZE {
    self.perlin[index] = rng.next()
  }
}

///|
pub fn Noise::detail(
  self : Noise,
  octaves : Int32,
  falloff~ : Double = 0.5,
) -> Unit {
  if octaves > 0 {
    self.octaves = octaves
  }
  if falloff > 0.0 {
    self.amp_falloff = falloff
  }
}

///|
fn scaled_cosine(value : Double) -> Double {
  0.5 * (1.0 - @cmath.cos(value * PI))
}

///|
pub fn Noise::noise(
  self : Noise,
  x : Double,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
) -> Double {
  let x = x.abs()
  let y = y.abs()
  let z = z.abs()
  let mut xi = x.floor().to_int()
  let mut yi = y.floor().to_int()
  let mut zi = z.floor().to_int()
  let mut xf = x - x.floor()
  let mut yf = y - y.floor()
  let mut zf = z - z.floor()
  let mut result = 0.0
  let mut amplitude = 0.5
  for _ in 0..<self.octaves {
    let mut offset = xi + (yi << PERLIN_YWRAPB) + (zi << PERLIN_ZWRAPB)
    let rx = scaled_cosine(xf)
    let ry = scaled_cosine(yf)
    let mut n1 = self.perlin[offset & PERLIN_SIZE]
    n1 = n1 + rx * (self.perlin[(offset + 1) & PERLIN_SIZE] - n1)
    let mut n2 = self.perlin[(offset + PERLIN_YWRAP) & PERLIN_SIZE]
    n2 = n2 + rx * (self.perlin[(offset + PERLIN_YWRAP + 1) & PERLIN_SIZE] - n2)
    n1 = n1 + ry * (n2 - n1)
    offset = offset + PERLIN_ZWRAP
    n2 = self.perlin[offset & PERLIN_SIZE]
    n2 = n2 + rx * (self.perlin[(offset + 1) & PERLIN_SIZE] - n2)
    let mut n3 = self.perlin[(offset + PERLIN_YWRAP) & PERLIN_SIZE]
    n3 = n3 + rx * (self.perlin[(offset + PERLIN_YWRAP + 1) & PERLIN_SIZE] - n3)
    n2 = n2 + ry * (n3 - n2)
    n1 = n1 + scaled_cosine(zf) * (n2 - n1)
    result = result + n1 * amplitude
    amplitude = amplitude * self.amp_falloff
    xi = xi << 1
    yi = yi << 1
    zi = zi << 1
    xf = xf * 2.0
    yf = yf * 2.0
    zf = zf * 2.0
    if xf >= 1.0 {
      xi = xi + 1
      xf = xf - 1.0
    }
    if yf >= 1.0 {
      yi = yi + 1
      yf = yf - 1.0
    }
    if zf >= 1.0 {
      zi = zi + 1
      zf = zf - 1.0
    }
  }
  result
}

// ==== Vector ====

///|
/// p5-style 2D/3D vector. Mutating methods return `Unit`; `copy` returns a
/// new vector.
pub struct Vector {
  mut x : Double
  mut y : Double
  mut z : Double
}

///|
pub fn Vector::new(
  x~ : Double = 0.0,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
) -> Vector {
  { x, y, z, }
}

///|
pub fn Vector::copy(self : Vector) -> Vector {
  { x: self.x, y: self.y, z: self.z, }
}

///|
pub fn Vector::set(
  self : Vector,
  x : Double,
  y : Double,
  z~ : Double = 0.0,
) -> Unit {
  self.x = x
  self.y = y
  self.z = z
}

///|
pub fn Vector::add(self : Vector, other : Vector) -> Unit {
  self.x = self.x + other.x
  self.y = self.y + other.y
  self.z = self.z + other.z
}

///|
pub fn Vector::sub(self : Vector, other : Vector) -> Unit {
  self.x = self.x - other.x
  self.y = self.y - other.y
  self.z = self.z - other.z
}

///|
pub fn Vector::mult(self : Vector, scalar : Double) -> Unit {
  self.x = self.x * scalar
  self.y = self.y * scalar
  self.z = self.z * scalar
}

///|
pub fn Vector::div(self : Vector, scalar : Double) -> Unit {
  if scalar != 0.0 {
    self.x = self.x / scalar
    self.y = self.y / scalar
    self.z = self.z / scalar
  }
}

///|
pub fn Vector::mag(self : Vector) -> Double {
  (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
}

///|
pub fn Vector::mag_sq(self : Vector) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z
}

///|
pub fn Vector::dot(self : Vector, other : Vector) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
pub fn Vector::cross(self : Vector, other : Vector) -> Vector {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///|
pub fn Vector::normalize(self : Vector) -> Unit {
  let length = self.mag()
  if length > 0.0 {
    self.div(length)
  }
}

///|
pub fn Vector::set_mag(self : Vector, length : Double) -> Unit {
  self.normalize()
  self.mult(length)
}

///|
pub fn Vector::limit(self : Vector, maximum : Double) -> Unit {
  let length = self.mag()
  if length > maximum && length > 0.0 {
    self.mult(maximum / length)
  }
}

///|
pub fn Vector::heading(self : Vector) -> Double {
  @cmath.atan2(self.y, self.x)
}

///|
pub fn Vector::rotate(self : Vector, angle : Double) -> Unit {
  let c = @cmath.cos(angle)
  let s = @cmath.sin(angle)
  let x = self.x * c - self.y * s
  let y = self.x * s + self.y * c
  self.x = x
  self.y = y
}

///|
pub fn Vector::dist(self : Vector, other : Vector) -> Double {
  let dx = self.x - other.x
  let dy = self.y - other.y
  let dz = self.z - other.z
  (dx * dx + dy * dy + dz * dz).sqrt()
}

///|
pub fn Vector::lerp(self : Vector, other : Vector, amount : Double) -> Unit {
  self.x = self.x + (other.x - self.x) * amount
  self.y = self.y + (other.y - self.y) * amount
  self.z = self.z + (other.z - self.z) * amount
}

///|
pub fn Vector::angle_between(self : Vector, other : Vector) -> Double {
  let denominator = self.mag() * other.mag()
  if denominator == 0.0 {
    0.0
  } else {
    @cmath.acos(constrain(self.dot(other) / denominator, -1.0, 1.0))
  }
}

///|
pub fn Vector::array(self : Vector) -> Array[Double] {
  [self.x, self.y, self.z]
}

///|
pub extend Matrix with Eq::{not_equal, equal}
