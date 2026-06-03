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
- `Program`, `Effect[Msg]`, and `Subscription[Msg]` are the default app model
  surface: pure apps use `Program::simple`, environment-aware apps use the
  `*_with_environment` constructors, effect-capable apps use `Program::new`
  with `Effect::send`, `Effect::dispatch`, or structured `Effect::run`, and
  app-level ongoing event sources use `subscriptions=model => ...` with stable keys so callbacks
  re-enter the typed message loop without exposing runtime internals. Effect
  diagnostics stay platform-neutral through `Effect::plan_summary`,
  `Effect::run` descriptors, duplicate descriptor-key counts, and aggregate
  program-runtime inspector counters; message
  queue diagnostics stay
  platform-neutral through enqueue/drain/pending counters; pipeline cost
  diagnostics stay platform-neutral through rebuild/layout/paint/draw-command
  pass counters; subscription diagnostics stay platform-neutral through
  `Subscription::plan_summary`, active subscription descriptors, subscription
  lifecycle/plan counters, and ignored stale-dispatch counters for callbacks
  captured by canceled or destroyed subscription lifetimes; effect runners and
  subscription adapters still own any concrete async work outside `core`.
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
  app-owned route/history helpers, `Program` / `Effect` / `Subscription`,
  layout, input, semantics, rich text editing, draw commands, styles, and theme
  tokens. Keep files grouped by responsibility
  (`runtime_state`,
  `component_context`, `input_*`, `paint_*`, `rich_text_*`) without adding
  subpackages.
- `style/`: visual token and style compatibility aliases.
- `views/`: public view constructors returning opaque `@core.View[Msg]`.
- `backend/host/`: shared `HostEvent`, surface metrics, input contracts,
  window lifecycle registry, window scene resolver, per-window runtime slot
  collection, platform-window id map, renderer-neutral `HostWindowRenderer`
  diagnostics, image-resource repaint routing, window request/completion queue,
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
- `examples/showcase/{macos_skia,windows_skia,linux_skia}` and
  `examples/markdown_editor/{macos_skia,windows_skia,linux_skia}`: explicit
  native Skia renderer example entrypoints.

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

The daily check runs `sh scripts/check-local-deps.sh`, which verifies the local
`window` fork, `skia_mbt` checkout, and the `window` fork's MoUI-oriented smoke
and evidence files are present, including `scripts/record_moui_evidence.sh`.
It also checks that the fork's current MoUI smoke contract still uses the
`moon run examples/moui_macos_smoke --target native` macOS path, the
module-qualified `wzzc-dev/window/examples/...` Web wasm-gc artifact paths, and
the MoUI Web smoke consumer sentinel lines.
Run `sh scripts/setup-local-deps.sh` first when a checkout is missing or stale;
it fast-forwards clean local dependency checkouts and refuses to overwrite
local `.local_repos/` edits.
Treat those window smoke helpers as dependency-level matching-host evidence,
not as a replacement for MoUI Showcase/Markdown Editor platform entrypoint
validation.
The same local-dependency check also requires the `skia_mbt` binding checkout's
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
and verifier scripts, then runs
`.local_repos/skia_mbt/scripts/verify-platform-status.sh` and
`.local_repos/skia_mbt/scripts/verify-native-capability-contract.sh`. Treat
that as binding-level Skia provider/status and native capability evidence; MoUI
renderer pixels and platform runtime behavior still need the opt-in real-Skia
smoke or matching-host example runs.
For Web runtime evidence, use `record-web-runtime-presentation.mjs` to collect
the browser-session artifact, then fold it into
`platform-runtime-evidence.json` with
`record-platform-evidence-manifest.mjs ... web --web-presentation-manifest ...`.
The platform evidence manifest is schema v2 and records the window fork's
monitor/cursor probe as `monitorCursor`; native passed entries must set it to
`yes`, while Web browser-session evidence may leave it pending. Native entries
also record a `skiaEvidence` block for Skia provider/preflight commands,
fallback-unavailable checks, real-renderer smoke, and Showcase/Markdown
first-frame status. `skiaEvidence.status=passed` is Skia-route evidence, not a
complete platform-services claim by itself, but native platform entries cannot
be marked `passed` unless their Skia evidence is also `passed`. Use
`record-native-skia-evidence.mjs` for matching-host Skia logs when you only
want to validate and update `skiaEvidence`; it deliberately leaves the broader
platform runtime status unchanged. Its provider-preflight log check requires
both the matching Skia provider identity and a passing preflight, test, or build
marker; do not use generic passing test output as provider evidence.
A passed presentation manifest must include WebGPU startup, wasm startup,
canvas sizing, resize/input event-bridge delivery, Markdown Editor text input,
clean target close, clean console, and nonblank screenshots for the named
browser session before the Web platform entry can be marked passed.

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
node scripts/validate-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json
node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...
node scripts/record-native-skia-evidence.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...
node scripts/validate-skia-entrypoints.mjs
node scripts/test-validate-skia-entrypoints.mjs
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/markdown_editor/macos_skia --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/markdown_editor/linux_skia --target native
node --check scripts/validate-conformance-capture-manifest.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/validate-platform-evidence-manifest.mjs
node scripts/test-validate-platform-evidence-manifest.mjs
node --check scripts/record-platform-evidence-manifest.mjs
node scripts/test-record-platform-evidence-manifest.mjs
node --check scripts/validate-web-runtime-handoff.mjs
node scripts/test-validate-web-runtime-handoff.mjs
node --check scripts/validate-web-runtime-handoff-manifest.mjs
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node --check scripts/record-web-runtime-presentation.mjs
node scripts/test-record-web-runtime-presentation.mjs
node --check scripts/validate-web-runtime-presentation-manifest.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
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
macOS/Windows/Linux Skia provider tests cover the public
`*_skia_provider_preflight_summary()` package-audit surface for renderer
availability, `skia_mbt/native` availability, selected font resolution, and
presenter identity, the `HostWindowRenderer` bridge that forwards Skia
text-system, image-resource, present-count, and disposal diagnostics, inherited
host service/input/window readiness,
clipboard/menu/file-dialog/open URL/system-theme/async-service readiness,
text-input/IME/drag-drop readiness, native context-menu readiness, host-modal
file-dialog readiness, native accessibility status, and the
first-frame smoke option state. Treat those
summaries as preflight evidence only; the macOS first-frame smoke and matching
Windows/Linux Showcase or Markdown Editor runtime runs are still required before
claiming Skia presentation. Windows/Linux Skia entrypoints use
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`, or
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for matching-host
auto-exit first-frame logs.

Windows native uses the MSVC dynamic WGPU path. Use
`scripts/windows/msvc_env.ps1` through the MSVC helpers and validate with
`scripts/windows/build_windows_msvc.ps1` or
`scripts/windows/package_windows_app_msvc.ps1` after installing vcpkg
`zlib:x64-windows`.

Real macOS Skia renderer smoke:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke \
  --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log \
  --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log \
  --markdown-log artifacts/platform-evidence/macos/markdown-macos-skia-first-frame.log \
  --record-platform-evidence artifacts/conformance/platform-runtime-evidence.json
scripts/macos-skia-renderer-smoke.sh --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
scripts/macos-skia-renderer-smoke.sh --skia-provider source
```

The helper resolves JetBrains, existing, or source-built Skia providers,
temporarily configures the local `skia_mbt` and MoUI Skia smoke packages, runs
the renderer pixel smoke, optionally launches `examples/showcase/macos_skia` to
verify its first presented frame, optionally launches
`examples/markdown_editor/macos_skia` with `--run-markdown-smoke`, and restores
touched `moon.pkg` files. It also writes/restores
`examples/mo_workbench/macos_skia` so direct local Mo Workbench runs can use
the same real-Skia configuration. In `auto` link mode, persistent
`--write-local-config` defaults to dynamic `libskia.dylib` flags for direct
`moon run`, while temporary smoke/build setup defaults to static `libskia.a`
flags when available; set `SKIA_MBT_MACOS_LINK_MODE=dynamic|static` or pass
`--link-mode dynamic|static` to override. With explicit artifact log paths,
`--record-platform-evidence` updates only the macOS `skiaEvidence` block after a
successful full smoke; it does not mark the broader platform-service entry
passed. Normal macOS Skia entrypoints default to the system
`FontMgr` text path; first-frame smoke entrypoints explicitly select
`EmptyTypeface` only while their exit-after-first-present flag is set. Windows
and Linux Skia entrypoints follow the same smoke-only font-resolution switch.

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
- Put Skia-backed measurement, glyph-run, font fallback, and diagnostic text
  system work in `render/skia`.
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
- For app-owned pending services, expose a typed completion path through
  `HostAppServices::on_completed` so callbacks re-enter an app `Effect::run`
  or `Effect::dispatch` runner instead of teaching `HostRuntimeDriver` about
  app messages.
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
