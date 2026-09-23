///|
test "web 3D provider advertises its host-backed GPU path" {
  match @moui_3d_web_renderer.descriptor().status() {
    Available => ()
    _ => fail("web 3D provider should advertise the linked host path")
  }
  assert_true(@moui_3d_web_renderer.create_provider().bind() is None)
}
