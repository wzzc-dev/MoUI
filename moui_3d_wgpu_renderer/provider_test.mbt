///|
test "native 3D provider exposes experimental GPU status" {
  let value = @moui_3d_wgpu_renderer.descriptor()
  match value.status() {
    Available => ()
    _ => fail("native 3D provider should advertise its real GPU path")
  }
  assert_true(@moui_3d_wgpu_renderer.create_provider().bind() is None)
}
