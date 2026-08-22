///|
pub fn backend_id() -> String {
  "rapier3d-0.5.1"
}

///|
pub fn supports_native_world() -> Bool {
  true
}

///|
/// Native Rapier 3D adapter. Rapier handles stay private so applications keep
/// the stable neutral `BodyId`/`ColliderId` contract from `moui_3d_physics`.
pub struct RapierWorld {
  gravity : @moui_3d.Vec3
  bodies : @rapier_dynamics.RigidBodySet3D
  colliders : @rapier_collision.ColliderSet3D
  pipeline : @rapier_pipeline.PhysicsPipeline3DReal
  islands : @rapier_dynamics.IslandManager3D
  broad_phase : @rapier_collision.BroadPhase3D
  narrow_phase : @rapier_collision.NarrowPhase3D
  body_handles : Map[@moui_3d_physics.BodyId, @rapier_dynamics.RigidBodyHandle]
  collider_handles : Map[
    @moui_3d_physics.ColliderId,
    @rapier_collision.ColliderHandle3D,
  ]
  mut next_body : Int64
  mut next_collider : Int64
}

///|
pub fn RapierWorld::new(
  gravity? : @moui_3d.Vec3 = @moui_3d.Vec3::new(x=0.0, y=-9.81, z=0.0),
) -> RapierWorld {
  {
    gravity,
    bodies: @rapier_dynamics.RigidBodySet3D::RigidBodySet3D(),
    colliders: @rapier_collision.ColliderSet3D::ColliderSet3D(),
    pipeline: @rapier_pipeline.PhysicsPipeline3DReal::PhysicsPipeline3DReal(),
    islands: @rapier_dynamics.IslandManager3D::IslandManager3D(),
    broad_phase: @rapier_collision.BroadPhase3D::BroadPhase3D(),
    narrow_phase: @rapier_collision.NarrowPhase3D::NarrowPhase3D(),
    body_handles: {},
    collider_handles: {},
    next_body: 1L,
    next_collider: 1L,
  }
}

///|
pub fn RapierWorld::gravity(self : RapierWorld) -> @moui_3d.Vec3 {
  self.gravity
}

///|
pub fn RapierWorld::create_body(
  self : RapierWorld,
  desc : @moui_3d_physics.BodyDesc,
) -> @moui_3d_physics.BodyId {
  let builder = match desc.body_type() {
    @moui_3d_physics.BodyType::Dynamic =>
      @rapier_dynamics.RigidBodyBuilder3D::dynamic()
    @moui_3d_physics.BodyType::Fixed =>
      @rapier_dynamics.RigidBodyBuilder3D::fixed()
    @moui_3d_physics.BodyType::Kinematic =>
      @rapier_dynamics.RigidBodyBuilder3D::kinematic_position_based()
  }
  let rapier_body = builder
    .translation(to_rapier_vec3(desc.position()))
    .rotation(to_rapier_quat(desc.rotation()))
    .gravity_scale(Float::from_double(desc.gravity_scale()))
    .build()
  let handle = self.bodies.insert(rapier_body)
  let id = @moui_3d_physics.BodyId::new(self.next_body)
  self.next_body = self.next_body + 1L
  self.body_handles[id] = handle
  id
}

///|
pub fn RapierWorld::create_collider(
  self : RapierWorld,
  desc : @moui_3d_physics.ColliderDesc,
) -> @moui_3d_physics.ColliderId? {
  let builder = match desc.shape() {
    @moui_3d_physics.Shape::Ball(radius) =>
      @rapier_collision.ColliderBuilder3D::ball(Float::from_double(radius))
    @moui_3d_physics.Shape::Cuboid(half_extents) =>
      @rapier_collision.ColliderBuilder3D::cuboid(
        Float::from_double(half_extents.x()),
        Float::from_double(half_extents.y()),
        Float::from_double(half_extents.z()),
      )
    @moui_3d_physics.Shape::CapsuleX(radius, half_height) =>
      @rapier_collision.ColliderBuilder3D::capsule_x(
        Float::from_double(radius),
        Float::from_double(half_height),
      )
    @moui_3d_physics.Shape::CapsuleY(radius, half_height) =>
      @rapier_collision.ColliderBuilder3D::capsule_y(
        Float::from_double(radius),
        Float::from_double(half_height),
      )
    @moui_3d_physics.Shape::CapsuleZ(radius, half_height) =>
      @rapier_collision.ColliderBuilder3D::capsule_z(
        Float::from_double(radius),
        Float::from_double(half_height),
      )
    @moui_3d_physics.Shape::Triangle(a, b, c) =>
      @rapier_collision.ColliderBuilder3D::triangle(
        to_rapier_vec3(a),
        to_rapier_vec3(b),
        to_rapier_vec3(c),
      )
    @moui_3d_physics.Shape::Trimesh(vertices, indices) =>
      match
        @rapier_collision.ColliderBuilder3D::trimesh(
          vertices.map(to_rapier_vec3),
          indices,
        ) {
        None => return None
        Some(value) => value
      }
  }
  let collider = builder
    .sensor(desc.sensor())
    .friction(Float::from_double(desc.friction()))
    .restitution(Float::from_double(desc.restitution()))
    .build()
  let handle = match desc.body() {
    None => self.colliders.insert(collider)
    Some(body_id) =>
      match self.body_handles.get(body_id) {
        None => return None
        Some(body) =>
          self.colliders.insert_with_parent(collider, body, self.bodies)
      }
  }
  let id = @moui_3d_physics.ColliderId::new(self.next_collider)
  self.next_collider = self.next_collider + 1L
  self.collider_handles[id] = handle
  Some(id)
}

///|
pub fn RapierWorld::body_translation(
  self : RapierWorld,
  id : @moui_3d_physics.BodyId,
) -> @moui_3d.Vec3? {
  match self.body_handles.get(id) {
    None => None
    Some(handle) =>
      self.bodies.get(handle).map(body => from_rapier_vec3(body.translation()))
  }
}

///|
pub fn RapierWorld::body_rotation(
  self : RapierWorld,
  id : @moui_3d_physics.BodyId,
) -> @moui_3d.Quat? {
  match self.body_handles.get(id) {
    None => None
    Some(handle) =>
      self.bodies.get(handle).map(body => from_rapier_quat(body.rotation()))
  }
}

///|
pub fn RapierWorld::step(self : RapierWorld, delta_seconds : Double) -> Int {
  if delta_seconds <= 0.0 {
    return 0
  }
  let params = @rapier_dynamics.IntegrationParameters::default().set_dt(
    Float::from_double(delta_seconds),
  )
  self.pipeline.step(
    to_rapier_vec3(self.gravity),
    params,
    self.islands,
    self.broad_phase,
    self.narrow_phase,
    self.bodies,
    self.colliders,
  )
  1
}

///|
pub fn RapierWorld::cast_ray(
  self : RapierWorld,
  ray : @moui_3d.Ray,
  max_distance : Double,
) -> @moui_3d_physics.RayHit? {
  if max_distance <= 0.0 {
    return None
  }
  let query = @rapier_collision.QueryPipeline3DReal::QueryPipeline3DReal(
    @rapier_collision.QueryFilter3DReal::QueryFilter3DReal(),
    self.bodies,
    self.colliders,
  )
  let rapier_ray = @rapier_collision.Ray3::Ray3(
    to_rapier_vec3(ray.origin()),
    to_rapier_vec3(ray.direction()),
  )
  match
    query.cast_ray_and_get_normal(
      self.bodies,
      self.colliders,
      rapier_ray,
      Float::from_double(max_distance),
      true,
    ) {
    None => None
    Some((handle, intersection)) => {
      let collider = find_collider_id(self.collider_handles, handle)
      match collider {
        None => None
        Some(id) => {
          let distance = intersection.toi().to_double()
          Some(
            @moui_3d_physics.RayHit::new(
              collider=id,
              distance~,
              position=ray.at(distance),
              normal=from_rapier_vec3(intersection.normal()),
            ),
          )
        }
      }
    }
  }
}

///|
fn to_rapier_vec3(value : @moui_3d.Vec3) -> @rapier_core.Vec3 {
  @rapier_core.Vec3::Vec3(
    Float::from_double(value.x()),
    Float::from_double(value.y()),
    Float::from_double(value.z()),
  )
}

///|
fn from_rapier_vec3(value : @rapier_core.Vec3) -> @moui_3d.Vec3 {
  @moui_3d.Vec3::new(
    x=value.x.to_double(),
    y=value.y.to_double(),
    z=value.z.to_double(),
  )
}

///|
fn to_rapier_quat(value : @moui_3d.Quat) -> @rapier_core.Quat {
  @rapier_core.Quat::Quat(
    Float::from_double(value.x),
    Float::from_double(value.y),
    Float::from_double(value.z),
    Float::from_double(value.w),
  )
}

///|
fn from_rapier_quat(value : @rapier_core.Quat) -> @moui_3d.Quat {
  @moui_3d.Quat::new(
    x=value.x.to_double(),
    y=value.y.to_double(),
    z=value.z.to_double(),
    w=value.w.to_double(),
  )
}

///|
fn find_collider_id(
  handles : Map[@moui_3d_physics.ColliderId, @rapier_collision.ColliderHandle3D],
  wanted : @rapier_collision.ColliderHandle3D,
) -> @moui_3d_physics.ColliderId? {
  for id in handles.keys() {
    match handles.get(id) {
      Some(handle) if handle.equals(wanted) => return Some(id)
      _ => ()
    }
  }
  None
}
