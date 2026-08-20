///|
test "native 3D provider exposes experimental GPU status" {
  let value = descriptor()
  match value.status() {
    @render.ThreeDRendererStatus::Available => ()
    _ => fail("native 3D provider should advertise its real GPU path")
  }
  assert_true(create_provider().bind() is None)
}
