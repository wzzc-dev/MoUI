# MoUI Tools

This directory is reserved for MoUI framework-specific MoonBit tools.

Do not place `moui_skia` binding checks here; keep those under
`tools/moui_skia/` so the binding tools can move with the binding repository.

Current tools:

- `validate_api_surface/` audits generated `pkg.generated.mbti` files for
  package-size budgets, root facade boundaries, and app-facing view constructor
  return types.
- `validate_package_manifest/` validates schema version 1 packaging manifests
  emitted by macOS app-bundle and Windows portable-folder packaging helpers.
- `validate_renderer_provider_manifests/` keeps native platform backend,
  Skia-provider, and WGPU-provider package manifests from depending on the
  wrong renderer or binding packages.
- `validate_skia_entrypoints/` statically checks native Skia example
  entrypoint packages and `main.mbt` files for the expected renderer,
  platform-backend, first-frame, and font-resolution wiring.
- `validate_conformance_capture_manifest/` validates schema version 1
  conformance capture manifests for golden screenshot and Web benchmark
  capture handoffs.
- `validate_web_runtime_handoff_manifest/` validates schema version 1 static
  Web runtime handoff observation manifests without broadening them into browser
  WebGPU, wasm-instantiation, canvas, or pixel smoke.
- `validate_web_runtime_presentation_manifest/` validates schema version 1
  browser-session Web runtime presentation manifests, including WebGPU, wasm
  startup, canvas, resize/input, screenshot markers, and clean target close
  boundaries for local smoke runs.
