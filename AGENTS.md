# Project Agents.md Guide

This repository is a MoonBit multi-platform GUI framework prototype. Keep
changes small, package-local, and consistent with the public `View[Msg]` /
internal runtime tree split.

The project is still in an early prototype stage. Backward compatibility is not
a requirement unless a task explicitly asks for it. Prefer clear, simple
architecture and direct API cleanup over compatibility shims, duplicate legacy
paths, or abstractions that only preserve old shapes.

## Project Shape

- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  draw command model, opaque public `View[Msg]`, typed events, `Program`, and
  `Effect`.
  It remains one MoonBit package; internal files are grouped by responsibility
  (`runtime_state`, `component_context`, `input_*`, `paint_*`, `rich_text_*`,
  etc.) rather than by additional package boundaries.
- `views/` is a facade over core primitive builders. Public constructors return
  opaque `@core.View[Msg]`; `ViewSpec` and node payloads stay inside `core`.
- `backend/host/` defines shared host event, surface, input, async
  host-service, window lifecycle, window scene resolution,
  per-window runtime slot collection, platform-window id mapping,
  request/completion, window event conversion, and renderer-neutral
  `HostWindowRenderer` diagnostics contracts.
- `backend/macos/`, `backend/windows/`, and `backend/linux/` are native host
  cores: platform windows, event conversion, services, lifecycle, runtime slots,
  and renderer-neutral provider hooks. They must not import `render/wgpu`,
  `render/skia`, `wgpu_mbt`, or `skia_mbt`. `backend/web/` is the browser
  wasm-gc host.
- `backend/macos/wgpu`, `backend/windows/wgpu`, and `backend/linux/wgpu`
  provide native WGPU renderer providers. `backend/macos/skia`,
  `backend/windows/skia`, and `backend/linux/skia` provide native Skia renderer
  providers.
- `render/` is the renderer facade and shared reporting layer.
- `render/wgpu/` is the native wgpu renderer. `render/webgpu_adapter/` is the
  wasm-gc browser WebGPU host-import bridge. `render/skia/` is the native Skia
  raster renderer facade over the local `wzzc-dev/skia_mbt` binding.
- Native text providers live in `render/wgpu/cosmic_text/`,
  `render/wgpu/coretext/`, `render/wgpu/directwrite/`,
  `render/wgpu/fontconfig/`, and the shared `render/wgpu/text_protocol/`
  package. `core/` owns only the neutral `TextSystem` contract.
- `examples/*/app/` packages are shared app logic. Platform subpackages are
  entrypoints only. Showcase also has `macos_cosmic`, `windows_cosmic`, and
  `linux_cosmic` entrypoints for explicit Moon Cosmic text-provider comparison.
  Showcase has `macos_skia`, `windows_skia`, and `linux_skia` entrypoints for
  explicitly selecting the native Skia renderer. Markdown Editor has
  `macos_skia` for its explicit native Skia renderer entrypoint.

## Local Dependencies

The project expects the modified local `wzzc-dev/window` checkout at
`.local_repos/window` and the editable `wzzc-dev/skia_mbt` checkout at
`.local_repos/skia_mbt`, as described in `docs/development.md`. Local
`moon.mod`, `moon.work`, and `moon.pkg` files are the source of truth for
imports, workspace members, and supported targets.

Use `sh scripts/setup-local-deps.sh` to create or repair the local checkouts and
`sh scripts/check-local-deps.sh` to verify that `window` points at the
`wzzc-dev/window` fork on the `moui-support` branch and `skia_mbt` points at the
`wzzc-dev/skia_mbt` repo on `master`. The upstream window remote is
`https://github.com/moonbit-community/window.git`; the MoUI window fork remote
is `git@github.com:wzzc-dev/window.git`.
`scripts/setup-local-deps.sh` also fast-forwards existing clean local dependency
checkouts to their expected origin branches; it stops before overwriting local
changes in `.local_repos/`.
The local-dependency check also verifies the window fork's MoUI-oriented smoke
and evidence files such as `docs/moui-integration-smoke.md`,
`scripts/check_moui_*_smoke.sh`, and `scripts/record_moui_evidence.sh` are
present and still wired to the expected smoke contract: macOS through
`moon run examples/moui_macos_smoke --target native`, Web wasm-gc artifacts
under module-qualified `wzzc-dev/window/examples/...` paths, and MoUI Web smoke
consumer sentinel lines. Treat those as dependency-level matching-host evidence
entrypoints; they do not replace MoUI Showcase or Markdown Editor platform
validation.
It also verifies the Skia binding acceptance surface, including
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, and `.local_repos/skia_mbt/scripts/verify-platform-status.sh`.
That status proves the editable binding checkout has a pinned platform-status
contract and CI evidence wiring; it does not replace MoUI real-Skia smoke or
platform runtime evidence.

When asked to update the repository, treat it as a multi-checkout update:
update the main MoUI checkout, initialize/update any Git submodules such as
`.agents/skills/moonbit-skills`, and update every editable checkout under
`.local_repos/`. Do not assume updating the root repository also updates these
nested repositories. On Windows, use
`powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1`
from the repository root for this routine; it also creates or updates
`.local_repos/window` on `moui-support` and `.local_repos/skia_mbt` on
`master`.

`.local_repos/window` is an editable local dependency, not a vendored snapshot
or submodule. It exists because upstream `moonbit-community/window` currently
only covers macOS, while MoUI needs Web, Windows, and Linux support. Changes in
that checkout should stay limited to the `web/`, `windows/`, and `linux/`
platform packages and their package-local tests/docs when possible. Avoid
changing `macos/`, shared packages such as `core/` and `dpi/`, or common
behavior unless the task explicitly requires it; keeping the fork narrow makes
future upstreaming safer. The local checkout must declare
`name = wzzc-dev/window` in `moon.mod` or `moon.mod.json` so workspace imports
bind to the editable fork.

`.local_repos/skia_mbt` is also an editable local dependency, not a submodule.
It carries native Skia binding work needed by `render/skia`, including
fallback-safe APIs that compile when real Skia link flags are absent. Keep
missing Skia FFI surface area in `skia_mbt` instead of adding large private Skia
stubs inside MoUI. A fallback compile is not renderer readiness:
`skia_available() == false` must keep Skia renderer creation unavailable.
The checkout owns its binding-level platform acceptance status in
`skia-platform-status.json` and `SKIA_PLATFORM_STATUS.md`, validated by
`scripts/verify-platform-status.sh`/`.ps1`. Treat those files as dependency
evidence for the Skia binding and provider artifact lock, not as MoUI
Showcase/Markdown Editor runtime evidence.

When asked to merge upstream `window` changes, work inside `.local_repos/window`
on `moui-support`, fetch `upstream`, and merge the upstream branch into the fork
branch. Preserve upstream macOS and shared behavior where possible; resolve
conflicts by keeping MoUI-specific additions scoped to Web, Windows, and Linux
unless the user explicitly approves broader fork changes.

## MoonBit Package Rules

MoonBit package boundaries are directories with `moon.pkg` files. File names do
not create modules or namespaces, and declarations in the same package can
refer to each other regardless of file. Imports use module/package paths such
as `wzzc-dev/moui/core`, never source file names.

Before adding new APIs or refactoring existing ones, discover local symbols with
the MoonBit IDE tools where practical:

```sh
moon ide doc <query>
moon ide outline <file>
moon ide peek-def <file>:<line>:<col>
moon ide find-references <file>:<line>:<col>
```

## Development Checks

Use the daily validation script for routine work:

```sh
sh scripts/dev-check.sh
```

This intentionally avoids all-repository `moon test --target native`,
`moon test --target wasm-gc`, and native platform example builds by default.
Those commands can pull in incompatible platform stubs, browser-only wasm-gc
host imports, or slow native links. Prefer package-level tests and Web wasm-gc
example builds for daily work. Use
`sh scripts/dev-check.sh --platform-examples-test` when you need
current-platform backend tests too. Use
`sh scripts/dev-check.sh --platform-examples-build` only when you explicitly
need slow current-platform native example builds.

Useful focused checks:

```sh
moon check
moon check --warn-list +unnecessary_annotation
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui/render/skia --target native
moon test .local_repos/skia_mbt --target native
moon test moui/render/wgpu/cosmic_text --target native
node scripts/validate-renderer-provider-manifests.mjs
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon build examples/showcase/web_wasm --target wasm-gc
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

Conformance work should stay layered: `core` owns platform-neutral contracts,
`backend/host` owns event/service/window routing, renderer/provider packages own
implementation validation, and `moui/tests/*_conformance` plus
`scripts/conformance-check.sh` own cross-engine or cross-platform matrix
evidence. Platform runtime claims should use the validated
`artifacts/conformance/platform-runtime-evidence.json` contract generated by
`scripts/conformance-check.sh --platform-services` and updated through
`scripts/record-platform-evidence-manifest.mjs`; pending entries are not runtime
proof until a matching host records passed observations and artifacts. The
manifest is schema v2 and mirrors the local window recorder's monitor/cursor
field as `monitorCursor`; native passed evidence must set it to `yes`, while
Web browser evidence may leave it pending because CDP does not prove native
monitor/current-monitor or cursor behavior. The Web runtime handoff validator
checks static HTML/runtime/wasm delivery for Showcase and Markdown Editor, not
browser WebGPU presentation. Use
`scripts/record-web-runtime-presentation.mjs` and
`scripts/validate-web-runtime-presentation-manifest.mjs` to collect passed
browser-session WebGPU, wasm startup, canvas, resize/input event-bridge,
Markdown Editor text input, clean target close, console, and screenshot
evidence; fold that artifact into
`artifacts/conformance/platform-runtime-evidence.json` with
`scripts/record-platform-evidence-manifest.mjs ... web
--web-presentation-manifest ...`. Failed or missing presentation manifests must
stay out of passed Web runtime claims. Examples demonstrate workflows but should
not be the only proof for a
shared contract.
If CDP is unavailable during Web presentation startup, the recorder writes a
validated failed manifest before exiting nonzero; use that artifact to document
the environment limit without broadening it into passed Web runtime evidence.

Run `moon info` after public API changes and review generated
`pkg.generated.mbti` diffs.

For narrow validation, prefer package or file scoped tests:

```sh
moon test <dir-or-file> --target native
moon test <dir-or-file> --filter '<glob>'
```

If a change touches `render/wgpu/`, also run:

```sh
moon test moui/render/wgpu --target native
```

If a change touches `render/skia/` or `.local_repos/skia_mbt`, also run the
fallback-safe Skia checks. Use `sh scripts/dev-check.sh --skia-real-smoke` only
after configuring real native Skia link flags; that opt-in path also runs
`moui/tests/skia_renderer_smoke/native` to verify MoUI `DrawCommand` rendering
against captured Skia presenter pixels.
On macOS, `scripts/macos-skia-renderer-smoke.sh` can resolve Skia from an
existing build, the pinned JetBrains binary provider, or a source build; it then
temporarily wires the resolved link flags into the local `skia_mbt` and MoUI
packages, runs the renderer pixel smoke, builds `examples/showcase/macos_skia`,
and restores the package files. Pass `--run-showcase-smoke` to also launch the
Showcase entrypoint, verify that the macOS Skia renderer presents its first
frame, and exit automatically. Pass `--write-local-config` only when you want to
persist local absolute Skia paths so direct commands such as
`moon run examples/showcase/macos_skia --target native` use real Skia; keep those
machine-local `moon.pkg` edits out of commits.

Windows native uses the MSVC WGPU toolchain path: Visual Studio C++ build
tools, vcpkg `zlib:x64-windows`, and `wgpu_mbt` dynamic mode with the official
MSVC `wgpu_native.dll`. Use `scripts/windows/setup_msvc_deps.ps1`,
`scripts/windows/build_windows_msvc.ps1`, and
`scripts/windows/package_windows_app_msvc.ps1` for setup, build, and packaging.
When changing Windows native setup, keep docs, CI, and repo-local skills aligned
with this MSVC-only route.

## Renderer Capability Tracking

Renderer feature status is tracked per backend in `render/capabilities.mbt` and
summarized in `docs/renderer-capability-report.md`. Update both the structured
report and tests when changing image, clip, opacity, transform, or other draw
command support. `RendererDescriptor` and `RendererSelection` are reporting and
matching concepts, not native host runtime assembly. Native runtime assembly
belongs to `backend/<platform>/wgpu` or `backend/<platform>/skia` renderer
provider packages; `core`, `ViewSpec`, `Program`, and host cores must not depend
on concrete renderer choices.

Use `pkg.generated.mbti` as the public API contract baseline and focused
contract/conformance tests as behavior evidence. Do not add long-lived
`*_spec.mbt` files for ordinary implementation structure; prefer responsibility
names such as `*_tree.mbt`, `*_descriptor.mbt`, `*_input.mbt`, `*_protocol.mbt`,
or `*_capabilities.mbt` when organizing package-local source.

## Documentation Updates

When development changes affect package layout, build commands, validation
commands, platform setup, renderer capabilities, or user-facing behavior, update
the relevant files under `docs/` in the same change. Keep the root `README.md`
as a short entry point; its source is `moui/README.mbt.md`. Move detailed
development guidance into `docs/development.md`.

The project moves quickly, so guidance files are part of the maintenance
surface. When changes affect architecture, package boundaries, docs placement,
validation commands, platform behavior, examples, renderer capabilities, or the
text system, also check whether `AGENTS.md` and the repo-local skills under
`skills/` need updates. If they do not need edits, say they were checked and
left unchanged in the handoff.

Current focused docs:

- `docs/text-system.md` covers `TextSystem`, native provider composition,
  Web text measurement/drawing, embedded fonts, and shaping gaps.
- `docs/markdown-editor.md` covers the WYSIWYG Markdown Editor model,
  source/visual mapping, commands, platform entrypoints, and validation.
- `docs/release-readiness.md` tracks preview-release gates, current evidence,
  known gaps, and next implementation slices.

## Editing Notes

- Preserve the `///|` delimiter style in MoonBit files.
- Keep public API additions intentional and covered by tests.
- Put new tests in focused `*_test.mbt` files inside the package being changed.
- Do not remove generated `pkg.generated.mbti` files.
- Do not run platform entrypoint tests through the generic wasm-gc runner when
  they require browser host imports.
