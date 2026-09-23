///|
/// Canvas 2D renderer preflight — verifies the renderer runtime environment.
pub fn preflight() -> @render.RendererBackendInfo {
  canvas2d_preflight()
}

///|
#skip("requires the JS-host `canvas2d` wasm import module; run via `moon test --include-skipped` under a JS host")
test "canvas2d_preflight_reports_ready" {
  let info = preflight()
  assert_eq(info.backend, Canvas2DWasm)
  assert_eq(info.status, Supported)
  assert_true(info.can_render)
  assert_true(info.can_resize)
  assert_false(info.owns_surface)
}

///|
#skip("requires the JS-host `canvas2d` wasm import module; run via `moon test --include-skipped` under a JS host")
test "canvas2d_descriptor_has_correct_family" {
  let descriptor = canvas2d_descriptor()
  assert_eq(descriptor.backend, Canvas2DWasm)
  assert_eq(descriptor.family, Canvas2D)
  assert_eq(descriptor.presentation, WebCanvas)
  assert_eq(descriptor.supported_targets.length(), 1)
  assert_eq(descriptor.supported_targets[0], WasmGc)
}
