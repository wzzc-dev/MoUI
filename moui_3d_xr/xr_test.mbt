///|
test "xr descriptors expose independent backend identities" {
  assert_eq(webxr_descriptor().id(), "moui-3d-webxr")
  assert_eq(openxr_descriptor().id(), "moui-3d-openxr")
}
