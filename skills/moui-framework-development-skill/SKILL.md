---
name: moui-framework-development-skill
description: Use this skill when developing or maintaining the MoUI MoonBit GUI framework itself, including core runtime, opaque View/layout/state/input, renderers, platform backends, examples used as framework validation, renderer capability tracking, documentation, and validation commands.
version: 0.1.0
---

# MoUI Framework Development Skill

## Purpose

This skill is for developing MoUI itself. It complements general MoonBit
guidance by pinning MoUI's package boundaries, runtime invariants, renderer
capability rules, platform contract, and validation commands.

## When To Use

Use this skill when editing or reviewing:

- `core/` runtime, state, layout, input, semantics, or draw commands.
- `views/` public constructors and modifiers.
- `backend/host`, `backend/web`, `backend/macos`, `backend/windows`, or
  `backend/linux`.
- `render/`, `render/wgpu`, `render/skia`, or `render/webgpu_adapter`.
- `backend/<platform>/wgpu` or `backend/<platform>/skia` native renderer
  provider packages.
- `examples/*/app` shared app logic or platform example entrypoints when they
  are being used as framework examples or validation coverage.
- `docs/*`, README, roadmap, testing docs, or AI collaboration materials.
- Renderer capability status, Showcase capability display, or validation
  scripts.

## First Files To Read

1. `AGENTS.md`
2. `README.md`
3. `docs/architecture.md`
4. `docs/development.md`
5. `docs/platform-notes.md`
6. `docs/text-system.md` when touching text measurement, shaping, fonts, or
   provider startup options
7. `docs/renderer-capability-report.md`
8. `docs/testing.md` when validation scope matters
9. `docs/release-readiness.md` when planning preview-release gates or gap
   closure
10. `docs/view-catalog.md` when touching `views/`
11. `docs/examples.md` when touching examples
12. `docs/markdown-editor.md` when touching the Markdown Editor

## Project Invariants

- Public view constructors return opaque `@core.View[Msg]`.
- Runtime pipeline:

  ```text
  View[Msg] -> internal view tree -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
  ```

- `core/` stays platform-neutral.
- Platform packages normalize native events into `@host.HostEvent`.
- Backends do not mutate element or render trees directly.
- Renderers consume platform-neutral `@core.DrawCommand` values.
- `examples/*/app` packages own shared app logic.
- Platform example packages should stay thin entrypoints.
- Web is `wasm-gc + window/web + browser WebGPU host imports`; there is no
  JS-target fallback.
- Linux has a minimal Wayland/WGPU backend; keep its remaining clipboard,
  menu, dialog, drag/drop, IME, AT-SPI, and native font provider gaps explicit.
- Public API changes require `moon info` and review of `pkg.generated.mbti`
  diffs.
- Renderer capability changes require synchronized updates to code, tests, docs,
  and Showcase when visible.
- Conformance work uses four layers: `core` contract tests, `backend/host` and
  platform routing tests, renderer/provider implementation tests, and matrix or
  diagnostic tests under `moui/tests/*_conformance` plus
  `scripts/conformance-check.sh`.
- Guidance changes are part of the maintenance surface: when architecture,
  package layout, validation commands, docs placement, examples, renderer
  capabilities, platform behavior, or text architecture changes, check
  `AGENTS.md` and repo-local skills too.

## Package Map

- `core/`: one MoonBit package for platform-neutral runtime, view specs, state,
  layout, input, semantics, rich text editing, draw commands, styles, and theme
  tokens. Keep files grouped by responsibility (`runtime_state`,
  `component_context`, `input_*`, `paint_*`, `rich_text_*`) without adding
  subpackages.
- `style/`: visual token and style compatibility aliases.
- `views/`: public view constructors returning opaque `@core.View[Msg]`.
- `backend/host/`: shared `HostEvent`, surface metrics, input contracts,
  window lifecycle registry, window scene resolver, per-window runtime slot
  collection, platform-window id map, window request/completion queue,
  text-input session, window-event conversion, async host-service queue, and
  redraw driver.
- `backend/web/`: wasm-gc Web host, canvas constraints, resolver-backed
  multi-canvas window slots, browser runtime bridge, and accessibility adapter.
- `backend/macos/`: AppKit/window host, resolver-backed multi-window slots,
  and CAMetalLayer WGPU surface creation.
- `backend/windows/`: Win32/window host, resolver-backed multi-window slots,
  and HWND WGPU surface creation.
- `backend/linux/`: minimal Wayland host over `.local_repos/window/linux`, a
  native WGPU Wayland surface path, shared host event conversion, and explicit
  unsupported-service reporting.
- `render/`: renderer facade, shared draw helpers, and capability report API.
- `render/wgpu/`: native wgpu renderer.
- `render/wgpu/cosmic_text/`: standalone Moon Cosmic provider.
- `render/wgpu/coretext/`: macOS CoreText provider.
- `render/wgpu/directwrite/`: Windows DirectWrite scaffold.
- `render/wgpu/fontconfig/`: Linux fontconfig/HarfBuzz/FreeType scaffold.
- `render/wgpu/text_protocol/`: shared native text provider payload protocol.
- `render/skia/`: native Skia raster renderer over the local `skia_mbt` binding.
- `render/webgpu_adapter/`: wasm-gc bridge to browser WebGPU host imports.
- `moui/tests/skia_renderer_smoke/native`: opt-in real-Skia renderer smoke that
  verifies MoUI draw commands against captured Skia presenter pixels.
- `moui/tests/text_conformance/{native,web}`: opt-in diagnostic text matrix
  packages for comparing supported text systems and documented gaps.
- `examples/*/app`: shared application logic.
- `examples/*/{web_wasm,macos,windows,linux}`: platform entrypoints where an
  example has a runnable host package.
- `examples/showcase/{macos_cosmic,windows_cosmic,linux_cosmic}`: explicit Moon
  Cosmic text provider comparison entrypoints.
- `examples/showcase/macos_skia`: explicit native Skia renderer showcase
  entrypoint.

## Development Workflow

1. Confirm the user goal and non-goals.
2. Read the relevant docs and `moon.pkg` package boundary.
3. Prefer `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` for MoonBit API discovery.
4. Keep edits small and package-local.
5. Preserve `///|` delimiters.
6. Add or update focused package tests.
7. Run targeted validation first.
8. Run `moon fmt`.
9. Run `moon info` after public API changes.
10. Update docs, `AGENTS.md`, and repo-local skills when guidance changes.
11. Report changed files, validation commands, and remaining risks.

## Validation Commands

Daily check:

```sh
sh scripts/dev-check.sh
```

Focused checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test moui/render --target native
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test moui/render/wgpu/cosmic_text --target native
moon test moui/render/webgpu_adapter --target wasm-gc
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node --check scripts/validate-package-manifest.mjs
```

Platform validation:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
```

Use `--platform-examples-test` for normal current-host backend/provider checks.
Run `moui/backend/<platform>/{wgpu,skia}` tests directly only on the matching
host/toolchain when investigating that provider.

Real macOS Skia renderer smoke:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
scripts/macos-skia-renderer-smoke.sh --skia-provider source
```

The helper resolves JetBrains, existing, or source-built Skia providers,
temporarily configures the local `skia_mbt` and MoUI Skia smoke packages, runs
the renderer pixel smoke, optionally launches `examples/showcase/macos_skia` to
verify its first presented frame, and restores touched `moon.pkg` files.

Public API review:

```sh
moon info
```

## Playbooks

### Add A View

- Implement in `views/` using public `@core.View[Msg]` constructors and modifiers,
  styles, and bindings.
- Add focused tests in `views/views_test.mbt`.
- Add Showcase coverage if the view is user-facing and visual.
- Update `docs/view-catalog.md`.
- Run `moon test moui/views --target native`, `moon fmt`, and `moon info` if public.

### Change Renderer Capability

- Keep the boundary at `@core.DrawCommand`.
- Update renderer implementation and tests.
- Update `render/capabilities.mbt`.
- Update `render/capabilities_test.mbt`.
- Update `docs/renderer-capability-report.md`.
- Update Showcase if the capability is visible.
- Run renderer tests and a Showcase Web wasm-gc build.

### Change Text System Or Provider

- Keep `core/` limited to `TextSystem`, `FontSpec`, fallback measurement, and
  platform-neutral text geometry.
- Put native provider work in the relevant `render/wgpu/*` package.
- Keep `render/wgpu` responsible for provider validation, fallback composition,
  glyph atlas upload, and cache-key discipline.
- Keep Web measurement and glyph drawing aligned through `backend/web` and
  `render/webgpu_adapter`.
- Update `docs/text-system.md` and renderer capability docs when shaping,
  provider behavior, embedded fonts, or text gaps change.
- Run focused core, renderer, Web adapter, backend, provider, and text
  conformance tests.

### Change Backend Event Handling

- Keep platform-specific code inside the platform backend.
- Normalize through `backend/host` and `HostEvent`.
- Add or update `backend/host` tests when shared behavior changes.
- Use `HostServiceAsyncQueue` for permission- or callback-driven services
  instead of pretending browser/platform async work completed synchronously.
- Run the affected backend package tests.
- Update `docs/platform-notes.md` when constraints or setup change.

### Update Examples

- Keep shared behavior under `examples/<name>/app`.
- Keep platform packages as entrypoints.
- Add app-package tests for model or runtime behavior.
- Build the affected Web wasm-gc entrypoint when browser output changes.
- Update `docs/examples.md` when commands, paths, or coverage change.

### Update Documentation

- Keep the root `README.md` short; its source is `moui/README.mbt.md`.
- Put architecture in `docs/architecture.md`.
- Put setup and command loops in `docs/development.md`.
- Put platform caveats in `docs/platform-notes.md`.
- Put example scope in `docs/examples.md`.
- Put text architecture in `docs/text-system.md`.
- Put Markdown Editor behavior in `docs/markdown-editor.md`.
- Put validation policy in `docs/testing.md`.
- Put renderer status in `docs/renderer-capability-report.md`.
- Put preview-release gates and gap-closure slices in
  `docs/release-readiness.md`.
- Check `AGENTS.md` and repo-local skills for stale guidance.

## Common Mistakes

- Adding platform logic to `core/`.
- Returning anything other than `@core.View[Msg]` from public view constructors.
- Skipping `moon info` after public API changes.
- Updating renderer support without updating capability docs and tests.
- Treating the minimal Linux Wayland backend as complete platform support while
  clipboard, menu, dialog, drag/drop, IME, AT-SPI, and native font provider
  work remains.
- Moving shared example logic into platform entrypoints.
- Running broad native checks before focused package validation.
- Letting `AGENTS.md` or repo-local skills drift after package, docs, example,
  validation, renderer, platform, or text-system changes.
