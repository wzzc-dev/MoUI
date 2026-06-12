# Maintenance Mainline

MoUI keeps a narrow default maintenance baseline so the framework can keep
growing without turning every diagnostic route into daily release pressure.

## Status Classes

- `mainline`: covered by the default `sh scripts/dev-check.sh` path. Mainline
  work must stay green before ordinary handoff.
- `diagnostic`: runnable, testable, and allowed to record observation, but not a
  default daily gate. Run the matching opt-in flag or focused command when the
  diagnostic route changes.
- `pending`: documented scaffold or capability note exists, but the route must
  not be described as ready until matching smoke has run.

## Default Baseline

The default daily baseline covers:

- `moui/core` and `moui/views`
- `moui/backend/host` and `moui/backend/web`
- `moui/render`, `moui/render/skia`, and `moui/render/webgpu_adapter`
- fallback-safe `moui_skia` checks
- Showcase app/Web wasm-gc validation
- Markdown Editor app/Web wasm-gc validation
- renderer/provider static checks and lightweight Web handoff validation

Complete platform runtime smoke is a release or matching-host gate, not a
default daily gate. Daily checks do not require fresh matching-host promotion.

## Diagnostic Routes

Native WGPU is a renderer diagnostic route. It stays available through
`sh scripts/dev-check.sh --wgpu-experimental` and focused renderer/provider
commands, but it is not the native mainline.

Design Systems is addon diagnostic coverage. `moui_theme` and
`examples/design_systems` remain important source-mapped preview/parity
surfaces, but they are not part of the core MoUI framework baseline. Run
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or
the Design Systems example.

Slow native example builds and matching-host platform runtime collection remain
opt-in through `--platform-examples-build`, real-Skia smoke helpers, and direct
runtime logs.
