///|
pub fn webxr_descriptor() -> XrProviderDescriptor {
  XrProviderDescriptor::new(
    backend=WebXr,
    id="moui-3d-webxr",
    status="contract-only",
  )
}

///|
pub fn openxr_descriptor() -> XrProviderDescriptor {
  XrProviderDescriptor::new(
    backend=OpenXr,
    id="moui-3d-openxr",
    status="contract-only",
  )
}
