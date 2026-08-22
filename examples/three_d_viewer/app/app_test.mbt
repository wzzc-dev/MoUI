///|
test "viewer starts with a fitted static scene" {
  let model = Model::new()
  assert_eq(model.snapshot.scene().nodes().length(), 1)
  assert_true(model.fixture_loaded)
  assert_eq(model.snapshot.scene().animations().length(), 1)
  assert_eq(model.snapshot.scene().materials().length(), 6)
  assert_eq(model.snapshot.scene().materials()[0].roughness(), 0.72)
  let mesh = model.snapshot.scene().mesh(@moui_3d.MeshId::new(0)).unwrap()
  assert_eq(mesh.primitives().length(), 6)
  for primitive in mesh.primitives() {
    assert_eq(primitive.indices().length(), 6)
  }
  // Each cube face must own its position/normal data. Sharing the first
  // accessor across primitives silently collapses the fixture to one face.
  let expected_positions = [
    @moui_3d.Vec3::new(x=-1.0, y=-1.0, z=1.0),
    @moui_3d.Vec3::new(x=1.0, y=-1.0, z=-1.0),
    @moui_3d.Vec3::new(x=1.0, y=-1.0, z=1.0),
    @moui_3d.Vec3::new(x=-1.0, y=-1.0, z=-1.0),
    @moui_3d.Vec3::new(x=-1.0, y=1.0, z=1.0),
    @moui_3d.Vec3::new(x=-1.0, y=-1.0, z=-1.0),
  ]
  let expected_normals = [
    @moui_3d.Vec3::new(x=0.0, y=0.0, z=1.0),
    @moui_3d.Vec3::new(x=0.0, y=0.0, z=-1.0),
    @moui_3d.Vec3::new(x=1.0, y=0.0, z=0.0),
    @moui_3d.Vec3::new(x=-1.0, y=0.0, z=0.0),
    @moui_3d.Vec3::new(x=0.0, y=1.0, z=0.0),
    @moui_3d.Vec3::new(x=0.0, y=-1.0, z=0.0),
  ]
  for face, primitive in mesh.primitives() {
    assert_eq(primitive.vertices().length(), 4)
    assert_eq(primitive.vertices()[0].position(), expected_positions[face])
    assert_eq(primitive.vertices()[0].normal(), expected_normals[face])
    let material_id = primitive.material().unwrap()
    assert_eq(material_id.value(), face)
  }
  assert_true(model.snapshot.bounds().is_valid())
  assert_eq(model.binding.status(), @moui_3d.ViewportStatus::Loading)
}

///|
test "viewer playback and picking controls update model state" {
  let model = Model::new()
  let playing = update(model, TogglePlayback)
  assert_true(playing.player.playing())
  let paused = update(playing, TogglePlayback)
  assert_true(!paused.player.playing())
  let picked = update(
    paused,
    Viewport(@moui_3d.ViewportEvent::Pick(@moui_3d.NodeId::new(0))),
  )
  assert_eq(picked.picked_node, Some(@moui_3d.NodeId::new(0)))
  let reset = update(picked, SeekStart)
  assert_eq(reset.player.time(), 0.0)
  assert_true(!reset.player.playing())
  let started = update(reset, TogglePlayback)
  let sample = update(started, Advance(1.5))
  let sample_position = sample.snapshot
    .scene()
    .node(@moui_3d.NodeId::new(0))
    .unwrap()
    .local_transform()
    .transform_point(@moui_3d.Vec3::zero())
  assert_true(sample_position.x() > 0.35)
  assert_true(sample_position.y().abs() > 0.15)
  assert_true(sample_position.z() > 0.15)
  let start_matrix = reset.snapshot
    .scene()
    .node(@moui_3d.NodeId::new(0))
    .unwrap()
    .local_transform()
    .values()
  let sample_matrix = sample.snapshot
    .scene()
    .node(@moui_3d.NodeId::new(0))
    .unwrap()
    .local_transform()
    .values()
  assert_true(start_matrix[0] != sample_matrix[0])
  assert_true(start_matrix[2] != sample_matrix[2])
  let advanced = update(sample, Advance(2.5))
  let position = advanced.snapshot
    .scene()
    .node(@moui_3d.NodeId::new(0))
    .unwrap()
    .local_transform()
    .transform_point(@moui_3d.Vec3::zero())
  assert_true(position.x().abs() < 0.04)
  assert_true(position.z() > 0.6)
  let looped = update(advanced, Advance(1.1))
  assert_true(looped.player.playing())
  assert_true(looped.player.time() < 0.02)
}

///|
test "viewer playback subscription follows the play state" {
  let timer = @services.TimerSource::new(start=(_interval, _dispatch) => None)
  let model = Model::new()
  let environment = @services.AppEnvironment::new(timer=Some(timer))
  let program = program_with_binding(model.binding, environment~)
  assert_eq(program.runtime_subscriptions(model).descriptors().length(), 0)
  let playing = update(model, TogglePlayback)
  let subscription = program.runtime_subscriptions(playing)
  assert_eq(subscription.descriptors().length(), 1)
  assert_eq(subscription.descriptors()[0].key(), "three-d-viewer:playback")
  let paused = update(playing, TogglePlayback)
  assert_eq(program.runtime_subscriptions(paused).descriptors().length(), 0)
}
