///|
pub(all) enum BodyType {
  Dynamic
  Fixed
  Kinematic
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BodyId {
  value : Int64
} derive(Eq, Debug, Hash, ToJson)

///|
pub fn BodyId::new(value : Int64) -> BodyId {
  { value, }
}

///|
pub fn BodyId::value(self : BodyId) -> Int64 {
  self.value
}

///|
pub(all) struct ColliderId {
  value : Int64
} derive(Eq, Debug, Hash, ToJson)

///|
pub fn ColliderId::new(value : Int64) -> ColliderId {
  { value, }
}

///|
pub fn ColliderId::value(self : ColliderId) -> Int64 {
  self.value
}

///|
pub(all) enum Shape {
  Ball(Double)
  Cuboid(@moui_3d.Vec3)
  CapsuleX(Double, Double)
  CapsuleY(Double, Double)
  CapsuleZ(Double, Double)
  Triangle(@moui_3d.Vec3, @moui_3d.Vec3, @moui_3d.Vec3)
  Trimesh(Array[@moui_3d.Vec3], Array[(Int, Int, Int)])
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BodyDesc {
  body_type : BodyType
  position : @moui_3d.Vec3
  rotation : @moui_3d.Quat
  gravity_scale : Double
} derive(Eq, Debug, ToJson)

///|
pub fn BodyDesc::new(
  body_type? : BodyType = BodyType::Dynamic,
  position? : @moui_3d.Vec3 = @moui_3d.Vec3::zero(),
  rotation? : @moui_3d.Quat = @moui_3d.Quat::identity(),
  gravity_scale? : Double = 1.0,
) -> BodyDesc {
  { body_type, position, rotation, gravity_scale }
}

///|
pub fn BodyDesc::body_type(self : BodyDesc) -> BodyType {
  self.body_type
}

///|
pub fn BodyDesc::position(self : BodyDesc) -> @moui_3d.Vec3 {
  self.position
}

///|
pub fn BodyDesc::rotation(self : BodyDesc) -> @moui_3d.Quat {
  self.rotation
}

///|
pub fn BodyDesc::gravity_scale(self : BodyDesc) -> Double {
  self.gravity_scale
}

///|
pub(all) struct ColliderDesc {
  shape : Shape
  body : BodyId?
  sensor : Bool
  friction : Double
  restitution : Double
} derive(Eq, Debug, ToJson)

///|
pub fn ColliderDesc::new(
  shape~ : Shape,
  body? : BodyId? = None,
  sensor? : Bool = false,
  friction? : Double = 0.5,
  restitution? : Double = 0.0,
) -> ColliderDesc {
  {
    shape,
    body,
    sensor,
    friction: friction.max(0.0),
    restitution: restitution.max(0.0).min(1.0),
  }
}

///|
pub fn ColliderDesc::shape(self : ColliderDesc) -> Shape {
  self.shape
}

///|
pub fn ColliderDesc::body(self : ColliderDesc) -> BodyId? {
  self.body
}

///|
pub fn ColliderDesc::sensor(self : ColliderDesc) -> Bool {
  self.sensor
}

///|
pub fn ColliderDesc::friction(self : ColliderDesc) -> Double {
  self.friction
}

///|
pub fn ColliderDesc::restitution(self : ColliderDesc) -> Double {
  self.restitution
}

///|
pub(all) struct RayHit {
  collider : ColliderId
  distance : Double
  position : @moui_3d.Vec3
  normal : @moui_3d.Vec3
} derive(Debug)

///|
pub fn RayHit::collider(self : RayHit) -> ColliderId {
  self.collider
}

///|
pub fn RayHit::distance(self : RayHit) -> Double {
  self.distance
}

///|
pub fn RayHit::position(self : RayHit) -> @moui_3d.Vec3 {
  self.position
}

///|
pub fn RayHit::normal(self : RayHit) -> @moui_3d.Vec3 {
  self.normal
}

///|
pub fn RayHit::new(
  collider~ : ColliderId,
  distance~ : Double,
  position~ : @moui_3d.Vec3,
  normal~ : @moui_3d.Vec3,
) -> RayHit {
  { collider, distance, position, normal }
}

///|
pub(all) struct PhysicsWorld {
  gravity : @moui_3d.Vec3
  mut next_body : Int64
  mut next_collider : Int64
  bodies : Map[BodyId, BodyDesc]
  colliders : Map[ColliderId, ColliderDesc]
} derive(Debug)

///|
pub fn PhysicsWorld::new(
  gravity? : @moui_3d.Vec3 = @moui_3d.Vec3::new(x=0.0, y=-9.81, z=0.0),
) -> PhysicsWorld {
  { gravity, next_body: 1L, next_collider: 1L, bodies: {}, colliders: {} }
}

///|
pub fn PhysicsWorld::gravity(self : PhysicsWorld) -> @moui_3d.Vec3 {
  self.gravity
}

///|
pub fn PhysicsWorld::create_body(
  self : PhysicsWorld,
  desc : BodyDesc,
) -> BodyId {
  let id = BodyId::new(self.next_body)
  self.next_body = self.next_body + 1L
  self.bodies[id] = desc
  id
}

///|
pub fn PhysicsWorld::create_collider(
  self : PhysicsWorld,
  desc : ColliderDesc,
) -> ColliderId {
  let id = ColliderId::new(self.next_collider)
  self.next_collider = self.next_collider + 1L
  self.colliders[id] = desc
  id
}

///|
pub fn PhysicsWorld::body(self : PhysicsWorld, id : BodyId) -> BodyDesc? {
  self.bodies.get(id)
}

///|
pub fn PhysicsWorld::collider(
  self : PhysicsWorld,
  id : ColliderId,
) -> ColliderDesc? {
  self.colliders.get(id)
}

///|
/// Backend hook. The neutral world does not guess physics; an adapter owns the
/// actual integration and returns a deterministic step count.
pub fn PhysicsWorld::step(self : PhysicsWorld, delta_seconds : Double) -> Int {
  ignore(self)
  if delta_seconds <= 0.0 {
    0
  } else {
    1
  }
}
