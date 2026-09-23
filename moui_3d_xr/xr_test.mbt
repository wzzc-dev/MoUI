///|
test "xr descriptors expose independent backend identities" {
  assert_eq(@moui_3d_xr.webxr_descriptor().id(), "moui-3d-webxr")
  assert_eq(@moui_3d_xr.openxr_descriptor().id(), "moui-3d-openxr")
}
