# Development

This page is the root maintainer guide for local setup, workspace shape,
documentation sync, app iteration, and validation. Product-facing website docs
are generated from this `docs/` directory by `scripts/sync-website-docs.mjs`.

## Local Setup

The MoonBit package ecosystem moves quickly. If a dependency-related build
fails, first run `moon update`, inspect the resolved package version, and check
whether the failure is a registry/cache/dependency issue before changing MoUI
code.

## Workspace Members

`moon.work` currently includes:

- `./moui`
- `./moui_richtext`
- `./moui_tester`
- `./moui_webview`
- `./moui_devtools`
- `./moui_agent`
- `./moui_agent_mcp`
- `./examples/agent_counter`
- `./tools`
- `./moui_skia`
- `./moui_theme`
- `./moui_sun`
- `./examples/counter`
- `./examples/button_freeze_probe`
- `./examples/showcase`
- `./examples/design_systems`
- `./examples/markdown_editor`
- `./examples/pdf_workbench`
- `./examples/settings`
- `./examples/data_table`
- `./examples/file_importer`
- `./examples/command_palette`
- `./examples/mo_workbench`
- `./openseek`
- `./examples/code_editor`
- `./examples/webview_demo`
- `./benchmarks/app_cached_layer`
- `./website`

When adding or removing a workspace member, update this list,
`docs/examples.md` for example packages, and any guidance rules in
`tools/moui/validate_guidance_consistency`.

## App Iteration

Shared app logic belongs in `examples/<name>/app`. Platform entrypoints should
stay thin and live under names such as `web_wasm`, `macos_skia`,
`windows_skia`, or `linux_skia`.

Use the smallest useful loop:

```sh
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

`moon update` refreshes registry packages, including the `window` fork package.
The default `sh scripts/dev-check.sh` path guards dependency shape and the
repo-local `moui_skia` acceptance surface. The Skia binding is part of the main
checkout at `moui_skia`.

This keeps `wzzc-dev/window` and `wzzc-dev/moui_skia` declared in
`moui/moon.mod`, keeps `wzzc-dev/moui_theme` as an addon module, and resolves
the local workspace members in `moon.work`:

```moonbit
import {
  "wzzc-dev/window@0.5.1-0.1.6",
  "wzzc-dev/moui_skia@0.1.4",
}
```

```toml
members = [
  "./moui",
  "./moui_richtext",
  "./moui_tester",
  "./moui_webview",
  "./moui_devtools",
  "./moui_agent",
  "./moui_agent_mcp",
  "./examples/agent_counter",
  "./tools",
  "./moui_skia",
  "./moui_theme",
  "./moui_sun",
  "./examples/counter",
  "./examples/button_freeze_probe",
  "./examples/showcase",
  "./examples/design_systems",
  "./examples/markdown_editor",
  "./examples/pdf_workbench",
  "./examples/settings",
  "./examples/data_table",
  "./examples/file_importer",
  "./examples/command_palette",
  "./examples/mo_workbench",
  "./openseek",
  "./examples/code_editor",
  "./examples/webview_demo",
  "./benchmarks/app_cached_layer",
  "./website",
]
```

The MoonBit package ecosystem is still not as mature as older language
ecosystems. A failing build can come from registry cache state, package
publication mistakes, or dependency regressions as well as from MoUI code. When
dependency-related failures appear, first run `moon update`, inspect the
resolved package versions, and check whether `wzzc-dev/window@0.5.1-0.1.6` or
another package changed behavior.

The `window` package still carries MoUI smoke helpers and evidence docs. Use
`scripts/run-window-package-smoke.sh <platform>` to extract the resolved
registry package into a temporary directory and run those helpers without
creating a local checkout. For example, on macOS:

```sh
WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=artifacts/platform-evidence/macos/window-macos-runtime-smoke.log \
  scripts/run-window-package-smoke.sh macos --run
```

The Skia binding is editable in the main repository at `moui_skia`. The default
daily check validates fallback-safe Skia package tests (`moon test moui_skia
--target native`) and the binding workspace's platform status contract. The
binding workspace itself ships
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`, which require
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, and `native/ownership.json`
to prove the editable binding workspace still has a pinned real-Skia
artifact/status contract, CI evidence wiring, fallback parity, FFI
ownership/borrow coverage, and native smoke marker coverage. That does not prove
a MoUI platform entrypoint has rendered with real Skia; use `--skia-real-smoke`
after configuring real Skia native link flags for that renderer-level proof.
The binding's GitHub Actions workflows are maintained at the repository root as
`.github/workflows/moui-skia-*.yml`; the root
`.github/workflows/copilot-setup-steps.yml` sets up MoonBit from the
`moui_skia` workspace for GitHub Copilot coding agent runs. Keep workflow files
in the root `.github/workflows` directory so GitHub discovers them in this
monorepo layout.

GitHub Actions installs MoonBit through the repository-local
`.github/actions/setup-moonbit` action. The pinned compiler version lives in
the root `.moonbit-toolchain` file; update that file when moving CI to a new
MoonBit toolchain version instead of hard-coding installer arguments in each
workflow.

When updating this repository, update all Git checkouts that participate in the
workspace, not just the root checkout. That includes the main MoUI repository
and Git submodules such as `.agents/skills/moonbit-skills`, `window`, and
`openseek`. Then
run `moon update` so registry dependencies are refreshed. `moui_skia` updates
with the main MoUI checkout.

The `window` submodule is **not** a `moon.work` workspace member by default.
MoonBit resolves `wzzc-dev/window` from mooncakes.io (the published version
pinned in each consumer's `moon.mod`). The `window/` submodule checkout exists
only so developers can switch to local-source dev mode when they need to edit
window source and validate changes inside MoUI before publishing.

To edit window source locally:

```sh
sh scripts/window-dev-mode.sh on      # add ./window to moon.work (local override)
# edit window/ source; moon test/run picks up changes immediately
sh scripts/window-dev-mode.sh off     # remove ./window; resolve from mooncakes.io
```

`scripts/validate-window-dependency.mjs` (run by `dev-check.sh` and CI) fails
if `moon.work` lists `./window` on the main branch, so the default state stays
on the published dependency. After publishing a new window version, update the
pinned version in `moui/moon.mod`, `moui_skia/moon.mod`, `moui_webview/moon.mod`,
and `examples/markdown_editor/moon.mod`, then run `moon update` to refresh the
registry cache.

On Windows, use the repository update helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

The `moui_skia` workspace member is updated by the root repository pull; the
window dependency resolves from mooncakes.io (or from the `window` submodule
checkout when dev mode is on).

Mo Workbench resolves `bobzhang/openseek` from the `openseek/` git submodule
while `./openseek` is listed in `moon.work` (required until the package is
published on mooncakes.io). CI initializes submodules in
`.github/actions/setup-moonbit`. Initialize locally once:

```sh
git submodule update --init openseek
```

`scripts/validate-openseek-workbench.mjs` (in `dev-check.sh`) requires
`moon.work` to list `./openseek` and the submodule checkout to exist. Pin
`bobzhang/openseek@…` in `examples/mo_workbench/moon.mod` when the registry
version becomes available. Run Mo Workbench native:

```sh
export OPENAI_API_KEY=...   # or DEEPSEEK=...
export OPENAI_BASE_URL=...  # optional OpenAI-compatible API URL
moon run examples/mo_workbench/macos_skia --target native
```

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/dev-check.sh
```

It runs stable package-level tests, native renderer contract tests, native Skia
fallback-safe checks, guidance consistency checks, and Showcase/Markdown Editor
Web wasm-gc example builds without invoking all-repository native or wasm-gc
test targets.
Fallback-safe Skia checks prove API shape and unavailable diagnostics; they do
not mean a real Skia renderer is ready. The local dependency check also runs
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`, which
validate the binding workspace's `skia-platform-status.json`, provider lock,
native capability manifest, fallback parity, ownership, FFI borrow annotations,
and native smoke marker coverage before the MoUI daily baseline can pass.
Design Systems is addon diagnostic coverage; run
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or the
Design Systems example.

## Script Tooling Policy

Keep scripts simple, clear, and maintainable first. When two approaches are
similarly clear, prefer MoonBit for repository rules, static validation,
structure scans, deterministic generators, and any logic that benefits from
`moon check`/`moon test` coverage.

Use `tools/...` MoonBit packages for long-lived CI tools. Keep the checked-in
Node entrypoints as compatibility wrappers over
`scripts/lib/moonbit-tool-runner.mjs` when users or CI already call
`node scripts/*.mjs`. Use `.mbtx` only for short standalone developer scripts;
promote it to a `tools/...` package once it becomes a maintained gate.

Keep Node for browser/CDP, Web smoke capture, HTTP/GitHub artifact work, npm
ecosystem tools, and command execution that is clearer in JavaScript. Keep
sh/PowerShell as thin orchestration for environment variables, shell syntax,
platform setup, and OS-specific command dispatch. Windows MSVC, vcpkg, and zlib
setup stay in PowerShell helpers such as `scripts/windows/setup_msvc_deps.ps1`
and `scripts/windows/msvc_env.ps1`; MoonBit may validate manifests or guidance
around those flows, but it should not install machine tools.

Use `rule`/`dev_build` only for deterministic package build inputs: a declared
input creates a declared output before package build. Do not use
`rule`/`dev_build` to install MSVC, vcpkg, zlib, Chrome, CI runners, or other
machine environment dependencies; do not use it to run smoke tests, access the
network, or mutate global/user state.

Run the real Skia native smoke only after configuring local Skia link flags:

```sh
sh scripts/dev-check.sh --skia-real-smoke
```

That opt-in check runs both the `moui_skia` native binding smoke and MoUI's
renderer-level smoke at `moui/tests/skia_renderer_smoke/native`, which renders a
small `DrawCommand` frame through `render/skia` and verifies presenter pixels.
The renderer smoke includes bounded `TextRun.frame` text clipping alongside the
general glyph-run text pixel check.
The script builds those smoke packages and runs the produced native executables
directly so failures propagate through the process exit status.

On macOS, use the dedicated helper when you want the script to resolve Skia and
wire the temporary package link flags for you. By default it uses the pinned
JetBrains Skia binary provider from `moui_skia`:

```sh
scripts/macos-skia-renderer-smoke.sh
```

The repository default package files intentionally avoid machine-local Skia
paths. Direct local commands use the `moui_skia` prebuild hook to resolve the
pinned release provider and link mode at build time:

```sh
export MOUI_SKIA_LINK_MODE=dynamic
moon run examples/showcase/macos_skia --target native
moon run examples/mo_workbench/macos_skia --target native
```

Use `MOUI_SKIA_LINK_MODE=dynamic|static|auto` for direct `moon run`/`moon build`
commands. The `--link-mode dynamic|static|auto` script option remains available
for helper-driven smoke runs and overrides the environment for that invocation.
Use `--write-local-config` only when intentionally writing machine-local
absolute Skia paths into package files; keep those edits out of commits.

Pass `--enable-skshaper` when the selected Skia library directory includes the
SkShaper module libraries. The helper then configures `moui_skia/native` with
the SkShaper define, links `libskshaper`, `libskunicode_core`,
`libskunicode_icu`, `libharfbuzz`, and `libicu`, and verifies the MoUI renderer
smoke log proves the optional shaped-run path was available.

Add `--run-showcase-smoke` when you want the helper to launch the built
`examples/showcase/macos_skia` executable, wait for the first Skia-presented
frame, and then exit automatically. Add `--run-markdown-smoke` to do the same
for `examples/markdown_editor/macos_skia`:

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

The renderer smoke and normal macOS Skia app entrypoints use the default
system-FontMgr text path, including optional SkShaper when enabled. The
first-frame Showcase and Markdown Editor smokes set each entrypoint's
exit-after-first-present flag, and those entrypoints explicitly select
`EmptyTypeface` only for the smoke run. This keeps first-frame AppKit
presentation evidence on the safer default-font retry path while preserving the
normal app default that exercises platform font lookup, emoji retry, and
optional SkShaper when linked.

Use `--skia-provider existing` when you already have a Skia checkout or binary
package:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Use `--skia-provider source` to build the small CPU Skia library through
`moui_skia/scripts/macos-build-skia.sh` before running the same
MoUI renderer smoke:

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

It temporarily configures `moui_skia/native`,
`moui/tests/skia_renderer_smoke/native`, `examples/showcase/macos_skia`,
`examples/markdown_editor/macos_skia`, and
`examples/mo_workbench/macos_skia`, runs the MoUI renderer pixel smoke, builds
the macOS Skia Showcase entrypoint, and restores all touched `moon.pkg` files
before exiting.

## Preview Loop

Use the lightweight preview loop when iterating on Showcase or another Web
wasm-gc example:

```sh
sh scripts/preview-loop.sh
sh scripts/preview-loop.sh --watch
sh scripts/preview-loop.sh --package examples/counter/web_wasm --watch
sh scripts/preview-loop.sh --package examples/markdown_editor/web_wasm --watch
sh scripts/preview-loop.sh --package website/web_wasm --watch
```

When previewing the website, run `node scripts/sync-website-docs.mjs` first or
use the preview loop for `website/web_wasm`; the website fetches same-origin
Markdown files from `website/web_wasm/docs/`.

## Framework Iteration

Use focused package tests while editing internals:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/backend/host --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui_skia --target native
```

Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
`moon ide find-references` before introducing new public names. Keep edits
package-local where possible. If public API changes, run `moon info` and review
the `pkg.generated.mbti` diff.

## Documentation Sync

Root `docs/` is the source for maintainer and website Markdown pages.
`website/web_wasm/docs/` is the local preview copy consumed by the website app.

After editing docs:

```sh
node scripts/sync-website-docs.mjs
node scripts/sync-website-docs.mjs --check
```

GitHub Pages stages `docs/*.md`, root `README.mbt.md` as `moui-readme.md`, and
`moui_skia/README.mbt.md` as `moui-skia-readme.md`. Keep root docs free of
machine-local paths and generated `artifacts/` evidence.

## Daily Validation

Run the daily validation script for routine handoff:

```sh
sh scripts/dev-check.sh
```

It includes dependency guards, guidance consistency, maintenance baseline
ratchets, API surface checks, smoke catalog validation, `moon check`, core
package tests, native Skia package tests, Web wasm-gc package tests, tester and
devtools checks, Showcase/Markdown Editor app tests, and Web builds.

Design Systems is addon diagnostic coverage; run:

```sh
sh scripts/dev-check.sh --theme-diagnostics
```

when changing `moui_theme` or `examples/design_systems`.

Native WGPU remains diagnostic:

```sh
sh scripts/dev-check.sh --wgpu-experimental
```

Current-host backend tests can be included without native example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/conformance-check.sh --platform-services
```

## Real Renderer And Platform Smoke

Run real Skia native smoke only when local Skia link flags or the helper script
are configured:

```sh
sh scripts/dev-check.sh --skia-real-smoke
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

For Web runtime presentation smoke:

```sh
sh scripts/ci-web-runtime-presentation.sh
```

For the window package smoke, use the resolved registry package without adding a
local checkout:

```sh
WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=artifacts/platform-observation/macos/window-macos-runtime-smoke.log \
  scripts/run-window-package-smoke.sh macos --run
```

Smoke commands write logs and manifests under `artifacts/`. Do not commit
artifacts; cite the CI run, uploaded artifact, or local smoke log in release
notes.

## CI And Toolchain

GitHub Actions installs MoonBit through `.github/actions/setup-moonbit`. The
pinned compiler version lives in `.moonbit-toolchain`; update that file when
moving CI to a new MoonBit toolchain version.

The binding workflows for `moui_skia` live in root `.github/workflows/` so
GitHub discovers them in this monorepo layout. Do not move workflow files into
sub-workspace `.github/workflows` directories.

On Windows, use the repository update helper when refreshing local checkouts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

On Windows, use the native PowerShell entry point for daily checks (no MSYS
required). It initializes the `window` submodule on first run and runs the
same bounded mainline package checks as `scripts/dev-check.sh`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\dev_check.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\windows\dev_check.ps1 -PlatformExamplesTest
```

Alternatively, run the shell version under Git Bash:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Native platform example builds such as
`moon build examples/showcase/macos_skia --target native` or
`moon build examples/showcase/linux_skia --target native` link platform stubs
and native renderer libraries, so cold builds can be slow. Include them only
when validating the current host platform's executable examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

## Native Packaging Helpers

The packaging helpers wrap already-supported native example packages into
platform-shaped output directories. They are intentionally thin wrappers around
`moon build` and do not replace release signing, notarization, installers, or
store packaging.

macOS `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0 \
  --build-version 1
```

The bundle is written under `dist/macos/<name>.app` by default. Pass
`--no-build` to package an already-built executable from `_build/native`. The
bundle includes `Contents/Resources/moui-package.json` using schema version 1
with platform, output kind, app name, source MoonBit package, bundle id,
version, build number, executable, bundle name, and runtime file metadata. The
helper validates that manifest before reporting success.

Windows native uses Visual Studio C++ build tools and vcpkg `zlib:x64-windows`.
The build/package helpers are renderer-aware: native Skia packages stay on the
Skia route and do not download or bundle `wgpu_native.dll`, while explicit WGPU
diagnostic packages keep the MSVC dynamic WGPU setup. Build the entrypoint once,
then package the portable folder:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase `
  -Version 0.1.0 `
  -BuildNumber 1
```

The helper imports `vcvarsall.bat`, sets `CC` and `CXX` to `cl.exe`, applies
shared MSVC `CL`/`LINK` flags for native stubs, and uses vcpkg
`zlib:x64-windows`. When the package imports WGPU, it also sets
`MBT_WGPU_LINK_MODE=dynamic` and extracts the official
`wgpu-windows-x86_64-msvc-release.zip` release when no `-WgpuNativeRoot` is
supplied. Its folder is written under `dist\windows-msvc\<AppName>` and
includes `run.cmd`, the schema manifest, and the runtime DLLs needed by the
selected renderer. Skia packages omit `wgpu_native.dll`; WGPU packages include
the WGPU release metadata and set `MBT_WGPU_NATIVE_ROOT` through `run.cmd`.
If Visual Studio's bundled vcpkg reports that classic mode is unavailable,
use `setup_msvc_deps.ps1 -InstallZlib` from the repository root; the script
creates a small ignored manifest workspace under `.tools\vcpkg-msvc` and uses
manifest mode to install `zlib:x64-windows`.

To run the Showcase Skia mainline directly after setup, dot-source the MSVC
environment in the same PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
```

Use the `windows_wgpu` entrypoint only for explicit native WGPU diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_wgpu --target native }"
```

Manual manifest validation:

```sh
node scripts/validate-package-manifest.mjs \
  "dist/macos/MoUI Showcase.app/Contents/Resources/moui-package.json" \
  --platform macos
```

Useful focused commands:

```sh
moon test moui/render/wgpu --target native
moon test moui/render/skia --target native
moon test moui/render/sun --target native
moon test moui_skia --target native
sh scripts/dev-check.sh --theme-diagnostics
moon test moui_sun/graphics --target native
moon test moui_sun/text --target native
moon test moui_sun/renderer --target native
moon test moui_sun/softbuffer --target native
moon build moui/tests/skia_renderer_smoke/native --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/tests/tooling --target native
moon test moui/backend/web --target wasm-gc
node scripts/validate-renderer-provider-manifests.mjs
sh scripts/dev-check.sh --platform-examples-test
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
sh scripts/dev-check.sh --platform-examples-build
moon build examples/showcase/macos_skia --target native
moon build examples/design_systems/macos_skia --target native
moon build examples/showcase/windows_skia --target native
moon build examples/design_systems/windows_skia --target native
moon build examples/design_systems/linux_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
moon build examples/showcase/macos_sun --target native
moon build examples/showcase/windows_sun --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/showcase/linux_skia --target native
moon build examples/showcase/linux_sun --target native
moon build examples/markdown_editor/linux_skia --target native
```

For PDF Workbench app-only or `pdflite_adapter` checks, set
`MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1` unless the native PDFium raster adapter
is the thing being validated.

Use the direct native example builds only on a matching configured host. The
helper flags keep current-platform backend/provider checks separate from slow
native example builds. Run native WGPU and Cosmic text-provider entrypoint
builds only when explicitly validating the experimental WGPU diagnostic route.

## Mooncakes Integration Notes

MoUI keeps production runtime boundaries explicit when using Mooncakes
frontends and tooling:

- Layout stays platform-neutral, but concrete flex/grid/list/stack placement now
  lives in `moui/views` via `View::node`; `core/` should not grow layout-engine
  dependencies for individual controls.
- `Milky2018/moon_accesskit` is the native accessibility tree representation
  used by `backend/host`; `@core.SemanticsNode` remains platform-neutral, and
  Web continues to use its ARIA adapter.
- `Milky2018/moon_zeno` powers renderer path tessellation from MoUI
  `DrawPath` / `PathSpec` values into triangle meshes. SVG parsing remains the
  importer frontend's job.
- `mizchi/markdown` powers the Markdown Editor's package-local parser adapter
  and rich text mapping. See [Markdown Editor](markdown-editor.md) for the
  app-level editing model.
- `mizchi/svg` powers `render.import_svg(String) -> SvgImportResult`, lowering
  parsed SVG scene graph nodes into MoUI `DrawCommand` values.
- `moonbitlang/quickcheck` and `mizchi/pixelmatch` are exercised from
  `moui/tests/tooling/` for property and pixel-diff coverage.

The text stack has its own maintenance page because it spans `core`,
native Skia, diagnostic `render/wgpu` providers, and browser host assets. See
[Text system](text-system.md) before changing `TextSystem`, native text
providers, embedded font registration, or Web text measurement.

## Guidance Maintenance

When a development change affects package layout, docs placement, validation
commands, platform setup, renderer capability status, example structure, or the
text system, also check `AGENTS.md` and the repo-local skills under `skills/`.
Update them in the same change when their instructions would otherwise become
stale.
