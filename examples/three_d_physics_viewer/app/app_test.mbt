///|
test "physics viewer starts with a dynamic sphere above fixed ground" {
  let model = Model::new()
  assert_eq(model.snapshot.scene().nodes().length(), 2)
  assert_eq(model.snapshot.scene().meshes().length(), 2)
  assert_eq(model.snapshot.scene().materials().length(), 7)
  let position = model.world.body_translation(model.dynamic_body).unwrap()
  assert_true(position.y() > 3.9)
  assert_true(!model.playing)
  assert_true(model.snapshot.bounds().is_valid())
}

///|
test "physics viewer steps Rapier and synchronizes the scene" {
  let model = Model::new()
  let started = update(model, TogglePlayback)
  let advanced = update(started, Advance(0.5))
  let position = advanced.world.body_translation(advanced.dynamic_body).unwrap()
  assert_true(position.y() < 4.0)
  let rendered_position = advanced.snapshot
    .scene()
    .node(@moui_3d.NodeId::new(0))
    .unwrap()
    .local_transform()
    .transform_point(@moui_3d.Vec3::zero())
  assert_true((rendered_position.y() - position.y()).abs() < 1.0e-6)
  assert_true(advanced.ray_hit is Some(_))
  assert_true(advanced.simulation_time > 0.2)
}

///|
test "physics viewer supports paused single steps and reset" {
  let model = Model::new()
  let stepped = update(model, Step)
  let step_position = stepped.world
    .body_translation(stepped.dynamic_body)
    .unwrap()
  assert_true(step_position.y() < 4.0)
  assert_true(!stepped.playing)
  let reset = update(stepped, Reset)
  let reset_position = reset.world.body_translation(reset.dynamic_body).unwrap()
  assert_true((reset_position.y() - 4.0).abs() < 1.0e-6)
  assert_eq(reset.simulation_time, 0.0)
  assert_true(!reset.playing)
}

///|
test "physics viewer makes the sphere bounce visibly" {
  let mut model = update(Model::new(), TogglePlayback)
  for _ in 0..<70 {
    model = update(model, Advance(1.0 / 60.0))
  }
  let after_first_bounce = model.world
    .body_translation(model.dynamic_body)
    .unwrap()
  assert_true(after_first_bounce.y() > 1.0)
  assert_true(model.simulation_time > 1.1)
}
