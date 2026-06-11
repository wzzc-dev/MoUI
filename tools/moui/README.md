# MoUI Tools

This directory is reserved for MoUI framework-specific MoonBit tools.

Do not place `moui_skia` binding checks here; keep those under
`tools/moui_skia/` so the binding tools can move with the binding repository.

Current tools:

- `validate_package_manifest/` validates schema version 1 packaging manifests
  emitted by macOS app-bundle and Windows portable-folder packaging helpers.
- `validate_renderer_provider_manifests/` keeps native platform backend,
  Skia-provider, and WGPU-provider package manifests from depending on the
  wrong renderer or binding packages.
- `validate_renderer_proof_manifest/` validates schema version 1 renderer proof
  manifests, including required proof tokens, provenance, emoji metadata, and
  optional uploaded artifact existence checks.
- `validate_platform_evidence_manifest/` validates schema version 2 platform
  runtime evidence manifests, including matching-host provenance, native IME
  observations, and native Skia evidence boundaries.
- `validate_skia_entrypoints/` statically checks native Skia example
  entrypoint packages and `main.mbt` files for the expected renderer,
  platform-backend, first-frame, and font-resolution wiring.
- `validate_conformance_capture_manifest/` validates schema version 1
  conformance capture manifests for golden screenshot and Web benchmark
  capture handoffs.
- `validate_web_runtime_handoff_manifest/` validates schema version 1 static
  Web runtime handoff evidence manifests without broadening them into browser
  WebGPU, wasm-instantiation, canvas, or pixel proof.
- `validate_web_runtime_presentation_manifest/` validates schema version 1
  browser-session Web runtime presentation manifests, including WebGPU, wasm
  startup, canvas, resize/input, screenshot, renderer proof, and clean target
  close evidence boundaries.
- `validate_checked_conformance_artifacts/` validates the checked-in
  conformance capture, Web handoff, Web presentation, platform-runtime
  evidence, and renderer-proof artifact set so committed evidence does not
  drift behind current schema and boundary rules.
- `record_renderer_proof_manifest/` folds renderer proof smoke logs into schema
  version 1 renderer proof manifests while preserving the original
  `scripts/record-renderer-proof-manifest.mjs` command path.
