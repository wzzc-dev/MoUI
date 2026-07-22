///|
/// Canvas 2D renderer preflight — verifies the renderer runtime environment.
pub fn preflight() -> @render.RendererBackendInfo {
  canvas2d_preflight()
}

///|
test "canvas2d_preflight_reports_ready" {
  let info = preflight()
  assert_eq!(info.backend, @render.RendererBackendKind::Canvas2DWasm)
  assert_eq!(info.status, @render.RendererCapabilityStatus::Supported)
  assert_true!(info.can_render)
  assert_true!(info.can_resize)
  assert_false!(info.owns_surface)
}

///|
test "canvas2d_descriptor_has_correct_family" {
  let descriptor = canvas2d_descriptor()
  assert_eq!(descriptor.backend, @render.RendererBackendKind::Canvas2DWasm)
  assert_eq!(descriptor.family, @render.RendererFamily::Canvas2D)
  assert_eq!(descriptor.presentation, @render.RendererPresentationModel::WebCanvas)
  assert_eq!(descriptor.supported_targets.length(), 1)
  assert_eq!(descriptor.supported_targets[0], @render.RendererTarget::WasmGc)
}