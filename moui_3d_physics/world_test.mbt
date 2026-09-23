///|
test "physics world allocates stable handles and validates descriptors" {
  let world = @moui_3d_physics.PhysicsWorld::new()
  let body = world.create_body(@moui_3d_physics.BodyDesc::new())
  let collider = world.create_collider(
    @moui_3d_physics.ColliderDesc::new(shape=Ball(1.0), body=Some(body)),
  )
  assert_eq(body.value(), 1L)
  assert_eq(collider.value(), 1L)
  assert_true(world.body(body) is Some(_))
  assert_true(world.collider(collider) is Some(_))
  assert_eq(world.step(0.0), 0)
  assert_eq(world.step(1.0 / 60.0), 1)
}
