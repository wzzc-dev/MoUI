# 2026-07-14: DrawFrame Damage Clip Fix

## Goal

Fix intermittent blank text in Markdown Editor and Code Editor when pointer
hover updates nearby buttons, and cover the missing renderer integration tests.

## Root Cause

Skia partially cleared damage rects and skipped cached layers outside them, but
did not clip the rest of the command stream. Runtime also supplied a leading
full-surface `Clear`. That clear, or an ordinary full-surface background,
erased retained editor pixels before their cached layers were skipped.

## Changes

- Made `DrawFrame.clear_color` authoritative and removed runtime's duplicate
  frame `Clear`; legacy `draw_commands()` remains unchanged.
- Added explicit clear lowering in command-only host/Web adapters and Linux
  client decoration composition.
- Applied Skia damage clipping to the complete command stream after logical
  canvas scaling, with conservative unioning for multiple rects.
- Added protocol, adapter, HiDPI, compatibility-clear, and hover/cached-sibling
  pixel regression tests.
- Added ADR 0009 to record the corrected long-term contract.

## Validation

- `moon test moui/runtime --target native`
- `moon test moui/backend/host --target native`
- `moon test moui/render/webgpu_adapter --target wasm-gc`
- `moon test moui/render/skia --target native`
- `moon test examples/markdown_editor/app --target native`
- `moon test examples/code_editor/app --target native`
- `sh scripts/check.sh --profile platform` (passed on macOS)
- `scripts/macos-skia-renderer-smoke.sh --link-mode static
  --require-skparagraph --run-showcase-smoke --run-markdown-smoke` (passed)

`sh scripts/check.sh --profile daily` reached the pre-existing modified
`examples/showcase/macos_skia/moon.pkg` and stopped because that file lacks the
validator-required `@skia_renderer` import. The unrelated local change was
preserved; all preceding daily steps and the remaining affected package checks
were run separately.
