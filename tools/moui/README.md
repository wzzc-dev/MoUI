# MoUI Tools

This directory is reserved for MoUI framework-specific MoonBit tools.

Do not place `moui_skia` binding checks here; keep those under
`tools/moui_skia/` so the binding tools can move with the binding repository.

Current tools:

- `validate_maintenance_baseline/` audits source-maintenance ratchets for
  oversized implementation/test files, source-level `pub(all)` counts, and root
  facade type-forwarding counts.
- `validate_api_surface/` audits generated `pkg.generated.mbti` files for
  package-size budgets, root facade boundaries, and app-facing view constructor
  return types.
- `validate_check_profiles/` validates `checks/profiles.json`, the source
  catalog for `scripts/check.mjs` PR, daily, platform, theme, and full gates.
- `validate_package_manifest/` validates schema version 1 packaging manifests
  emitted by macOS app-bundle and Windows portable-folder packaging helpers.
- `validate_renderer_provider_manifests/` keeps native platform backend,
  Skia-provider, and WGPU-provider package manifests from depending on the
  wrong renderer or binding packages.
- `validate_window_dependency/` checks that `wzzc-dev/window` resolves from
  mooncakes.io by default and that all known consumers pin the same published
  version.
- `validate_skia_entrypoints/` statically checks featured native Skia
  entrypoints for executable/runtime/provider wiring, keeps platform link and
  macOS route selection owned by provider packages, and rejects repo-only smoke
  behavior in production entrypoints.
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
- `scripts/smoke-check.mjs` validates the checked-in `smoke/gates.json`
  catalog that maps daily, nightly, and release smoke suites to commands,
  structured result shapes, docs, workflows, and ignored `artifacts/` outputs.
- `scripts/smoke-gate.mjs` is the catalog-backed dry-run/run entrypoint for
  selected smoke suites; CI uses it to avoid duplicating suite commands in
  workflow YAML.
