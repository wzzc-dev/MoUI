///|
test "web 3D provider advertises its host-backed GPU path" {
  match descriptor().status() {
    @render.ThreeDRendererStatus::Available => ()
    _ => fail("web 3D provider should advertise the linked host path")
  }
  assert_true(create_provider().bind() is None)
}
