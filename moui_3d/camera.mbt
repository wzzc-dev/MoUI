///|
/// Perspective camera with the glTF-compatible Y-up, right-handed convention.
pub(all) struct PerspectiveCamera {
  fov_y_radians : Double
  aspect : Double
  near : Double
  far : Double
} derive(Eq, Debug, ToJson)

///|
pub fn PerspectiveCamera::new(
  fov_y_radians? : Double = 0.7853981633974483,
  aspect? : Double = 1.0,
  near? : Double = 0.01,
  far? : Double = 1000.0,
) -> PerspectiveCamera {
  {
    fov_y_radians: clamp(fov_y_radians, 0.05, 3.0),
    aspect: if aspect <= 0.0 {
      1.0
    } else {
      aspect
    },
    near: if near <= 0.0 {
      0.01
    } else {
      near
    },
    far: if far <= near {
      near + 1.0
    } else {
      far
    },
  }
}

///|
pub fn PerspectiveCamera::projection(self : PerspectiveCamera) -> Mat4 {
  Mat4::perspective(
    fov_y_radians=self.fov_y_radians,
    aspect=self.aspect,
    near=self.near,
    far=self.far,
  )
}

///|
pub fn PerspectiveCamera::with_aspect(
  self : PerspectiveCamera,
  aspect : Double,
) -> PerspectiveCamera {
  { ..self, aspect: if aspect <= 0.0 { 1.0 } else { aspect } }
}

///|
pub fn PerspectiveCamera::fov_y_radians(self : PerspectiveCamera) -> Double {
  self.fov_y_radians
}

///|
pub fn PerspectiveCamera::near(self : PerspectiveCamera) -> Double {
  self.near
}

///|
pub fn PerspectiveCamera::far(self : PerspectiveCamera) -> Double {
  self.far
}

///|
/// Orbit camera state. `polar` is measured from the positive Y axis and is
/// clamped away from the poles so orbiting cannot flip the view upside down.
pub(all) struct OrbitCamera {
  target : Vec3
  radius : Double
  azimuth : Double
  polar : Double
  perspective : PerspectiveCamera
} derive(Eq, Debug, ToJson)

///|
pub fn OrbitCamera::new(
  target? : Vec3 = Vec3::zero(),
  radius? : Double = 3.0,
  azimuth? : Double = 0.0,
  polar? : Double = 1.1,
  perspective? : PerspectiveCamera = PerspectiveCamera::new(),
) -> OrbitCamera {
  {
    target,
    radius: clamp(radius, 0.01, 1.0e9),
    azimuth,
    polar: clamp(polar, 0.01, @math.PI - 0.01),
    perspective,
  }
}

///|
pub fn OrbitCamera::target(self : OrbitCamera) -> Vec3 {
  self.target
}

///|
pub fn OrbitCamera::radius(self : OrbitCamera) -> Double {
  self.radius
}

///|
pub fn OrbitCamera::azimuth(self : OrbitCamera) -> Double {
  self.azimuth
}

///|
pub fn OrbitCamera::polar(self : OrbitCamera) -> Double {
  self.polar
}

///|
pub fn OrbitCamera::perspective(self : OrbitCamera) -> PerspectiveCamera {
  self.perspective
}

///|
pub fn OrbitCamera::position(self : OrbitCamera) -> Vec3 {
  let sine = @math.sin(self.polar)
  Vec3::new(
    x=self.target.x + self.radius * sine * @math.sin(self.azimuth),
    y=self.target.y + self.radius * @math.cos(self.polar),
    z=self.target.z + self.radius * sine * @math.cos(self.azimuth),
  )
}

///|
pub fn OrbitCamera::view(self : OrbitCamera) -> Mat4 {
  Mat4::look_at(
    eye=self.position(),
    target=self.target,
    up=Vec3::new(x=0.0, y=1.0, z=0.0),
  )
}

///|
pub fn OrbitCamera::projection(self : OrbitCamera) -> Mat4 {
  self.perspective.projection()
}

///|
pub fn OrbitCamera::orbit(
  self : OrbitCamera,
  delta_azimuth : Double,
  delta_polar : Double,
) -> OrbitCamera {
  {
    ..self,
    azimuth: self.azimuth + delta_azimuth,
    polar: clamp(self.polar + delta_polar, 0.01, @math.PI - 0.01),
  }
}

///|
pub fn OrbitCamera::zoom(self : OrbitCamera, amount : Double) -> OrbitCamera {
  { ..self, radius: clamp(self.radius * amount, 0.01, 1.0e9) }
}

///|
pub fn OrbitCamera::pan(self : OrbitCamera, delta : Vec2) -> OrbitCamera {
  let forward = self.target.sub(self.position()).normalized()
  let right = forward.cross(Vec3::new(x=0.0, y=1.0, z=0.0)).normalized()
  let up = right.cross(forward).normalized()
  let scale = self.radius * 0.0025
  {
    ..self,
    target: self.target
    .add(right.scale(-delta.x * scale))
    .add(up.scale(delta.y * scale)),
  }
}

///|
pub fn OrbitCamera::with_aspect(
  self : OrbitCamera,
  aspect : Double,
) -> OrbitCamera {
  { ..self, perspective: self.perspective.with_aspect(aspect) }
}

///|
pub fn OrbitCamera::fit(
  self : OrbitCamera,
  bounds : Aabb,
  padding? : Double = 1.2,
) -> OrbitCamera {
  if !bounds.is_valid() {
    self
  } else {
    let radius = clamp(bounds.radius() * clamp(padding, 1.0, 10.0), 0.01, 1.0e9)
    let half_fov = self.perspective.fov_y_radians() / 2.0
    let distance = radius / @math.sin(half_fov)
    { ..self, target: bounds.center(), radius: clamp(distance, 0.01, 1.0e9) }
  }
}

///|
/// Construct a world-space ray through a logical viewport point.
pub fn OrbitCamera::ray_for_viewport(
  self : OrbitCamera,
  point : Vec2,
  viewport : Vec2,
) -> Ray {
  let width = if viewport.x <= 0.0 { 1.0 } else { viewport.x }
  let height = if viewport.y <= 0.0 { 1.0 } else { viewport.y }
  let normalized_x = point.x / width * 2.0 - 1.0
  let normalized_y = 1.0 - point.y / height * 2.0
  let forward = self.target.sub(self.position()).normalized()
  let right = forward.cross(Vec3::new(x=0.0, y=1.0, z=0.0)).normalized()
  let up = right.cross(forward).normalized()
  let half_fov = self.perspective.fov_y_radians() / 2.0
  let half_height = @math.tan(half_fov)
  let half_width = half_height * width / height
  let direction = forward
    .add(right.scale(normalized_x * half_width))
    .add(up.scale(normalized_y * half_height))
    .normalized()
  Ray::new(origin=self.position(), direction~)
}

///|
fn clamp(value : Double, minimum : Double, maximum : Double) -> Double {
  if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}
