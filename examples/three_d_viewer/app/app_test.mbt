///|
test "viewer starts with a fitted static scene" {
  let model = Model::new()
  assert_eq(model.snapshot.scene().nodes().length(), 1)
  assert_eq(model.snapshot.scene().materials().length(), 6)
  assert_eq(model.snapshot.scene().meshes()[0].primitives().length(), 6)
  assert_true(model.snapshot.bounds().is_valid())
  assert_eq(model.binding.status(), @moui_3d.ViewportStatus::Loading)
}
