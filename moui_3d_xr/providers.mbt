///|
pub fn webxr_descriptor() -> XrProviderDescriptor {
  XrProviderDescriptor::new(
    backend=XrBackend::WebXr,
    id="moui-3d-webxr",
    status="contract-only",
  )
}

///|
pub fn openxr_descriptor() -> XrProviderDescriptor {
  XrProviderDescriptor::new(
    backend=XrBackend::OpenXr,
    id="moui-3d-openxr",
    status="contract-only",
  )
}
