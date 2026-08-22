///|
test "rapier adapter integrates gravity and preserves neutral ids" {
  let world = RapierWorld::new()
  let body = world.create_body(
    @moui_3d_physics.BodyDesc::new(
      position=@moui_3d.Vec3::new(x=0.0, y=2.0, z=0.0),
    ),
  )
  let collider = world.create_collider(
    @moui_3d_physics.ColliderDesc::new(
      shape=@moui_3d_physics.Shape::Ball(0.5),
      body=Some(body),
    ),
  )
  assert_true(collider is Some(_))
  let initial = world.body_translation(body).unwrap()
  for _ in 0..<30 {
    ignore(world.step(1.0 / 60.0))
  }
  let after = world.body_translation(body).unwrap()
  assert_true(after.y() < initial.y())
  assert_eq(world.body_translation(@moui_3d_physics.BodyId::new(999L)), None)
}

///|
test "rapier adapter collides with fixed ground and casts rays" {
  let world = RapierWorld::new()
  let ground = world.create_body(
    @moui_3d_physics.BodyDesc::new(
      body_type=@moui_3d_physics.BodyType::Fixed,
      position=@moui_3d.Vec3::new(x=0.0, y=-0.5, z=0.0),
    ),
  )
  let ground_collider = world
    .create_collider(
      @moui_3d_physics.ColliderDesc::new(
        shape=@moui_3d_physics.Shape::Cuboid(
          @moui_3d.Vec3::new(x=5.0, y=0.5, z=5.0),
        ),
        body=Some(ground),
      ),
    )
    .unwrap()
  let body = world.create_body(
    @moui_3d_physics.BodyDesc::new(
      position=@moui_3d.Vec3::new(x=0.0, y=3.0, z=0.0),
    ),
  )
  ignore(
    world.create_collider(
      @moui_3d_physics.ColliderDesc::new(
        shape=@moui_3d_physics.Shape::Ball(0.5),
        body=Some(body),
      ),
    ),
  )
  for _ in 0..<120 {
    ignore(world.step(1.0 / 60.0))
  }
  let position = world.body_translation(body).unwrap()
  assert_true(position.y() > -0.1)
  let hit = world
    .cast_ray(
      @moui_3d.Ray::new(
        origin=@moui_3d.Vec3::new(x=4.0, y=4.0, z=0.0),
        direction=@moui_3d.Vec3::new(x=0.0, y=-1.0, z=0.0),
      ),
      10.0,
    )
    .unwrap()
  assert_eq(hit.collider(), ground_collider)
  assert_true(hit.distance() > 0.0)
}
