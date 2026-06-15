# Development

This page collects local setup, example run commands, and validation guidance
for MoUI development.

## Local Dependencies

The upstream `moonbit-community/window` package does not currently cover the targets 
MoUI needs, so use the `wzzc-dev/window` fork checkout instead. 
MoUI resolves the window host dependency from the MoonBit registry as `wzzc-dev/window@0.5.1-0.1.4`.
MoUI also carries `wzzc-dev/moui_skia` as a repo-local editable workspace member
while the Skia renderer backend and binding surface evolve together. The
optional `wzzc-dev/moui_theme` addon is another repo-local workspace member for
source-mapped design-system preview packages. `wzzc-dev/moui_tester` carries
repo-local harnesses/fixtures/smoke entrypoints, and `wzzc-dev/moui_devtools`
contains inspector snapshot summaries and debug helpers.

From the repository root:

```sh
moon update
sh scripts/check-local-deps.sh
```

`moon update` refreshes registry packages, including the `window` fork package.
`scripts/check-local-deps.sh` verifies the expected package versions, confirms
that `moon.work` does not reintroduce a local window checkout, and checks the
repo-local `moui_skia` acceptance surface. The Skia binding is part of the main
checkout at `moui_skia`.

This keeps `wzzc-dev/window` and `wzzc-dev/moui_skia` declared in
`moui/moon.mod`, keeps `wzzc-dev/moui_theme` as an addon module, and resolves
the local workspace members in `moon.work`:

```moonbit
import {
  "wzzc-dev/window@0.5.1-0.1.4",
  "wzzc-dev/moui_skia@0.1.4",
}
```

```toml
members = [
  "./moui",
  "./tools",
  "./moui_skia",
  "./moui_theme",
  "./moui_tester",
  "./moui_devtools",
  "./examples/counter",
  "./examples/button_freeze_probe",
  "./examples/showcase",
  "./examples/design_systems",
  "./examples/markdown_editor",
  "./examples/settings",
  "./examples/data_table",
  "./examples/file_importer",
  "./examples/pdf_workbench",
  "./examples/webview_demo",
  "./examples/command_palette",
  "./examples/mo_workbench",
  "./benchmarks/app_cached_layer",
  "./website",
]
```

The MoonBit package ecosystem is still not as mature as older language
ecosystems. A failing build can come from registry cache state, package
publication mistakes, or dependency regressions as well as from MoUI code. When
dependency-related failures appear, first run `moon update`, inspect the
resolved package versions, and check whether `wzzc-dev/window@0.5.1-0.1.4` or
another package changed behavior.

The `window` package still carries MoUI smoke helpers and observation docs. Use
`scripts/run-window-package-smoke.sh <platform>` to extract the resolved
registry package into a temporary directory and run those helpers without
creating a local checkout. For example, on macOS:

```sh
WINDOW_MOUI_MACOS_SMOKE_LOG_PATH=artifacts/platform-observation/macos/window-macos-runtime-smoke.log \
  scripts/run-window-package-smoke.sh macos --run
```

The Skia binding is editable in the main repository at `moui_skia`. The default
daily check validates fallback-safe Skia package tests and the binding
workspace's platform status contract. `scripts/check-local-deps.sh` requires
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
and the verifier scripts, then runs
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`. That
checks the editable binding workspace still has a pinned real-Skia
artifact/status contract, CI smoke wiring, fallback parity, FFI
ownership/borrow coverage, and native smoke marker coverage. It does not prove
a MoUI platform entrypoint has rendered with real Skia; use `--skia-real-smoke`
after configuring real Skia native link flags for that renderer-level smoke.
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
and Git submodules such as `.agents/skills/moonbit-skills`. Then run
`moon update` so registry dependencies such as `wzzc-dev/window@0.5.1-0.1.4`
are refreshed. `moui_skia` updates with the main MoUI checkout.

On Windows, use the repository update helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1
```

The `moui_skia` workspace member is updated by the root repository pull; the
window dependency is refreshed by `moon update`.

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/dev-check.sh
```

It runs stable package-level tests, native renderer contract tests, native Skia
fallback-safe checks, maintenance baseline ratchets, guidance consistency
checks, and Showcase/Markdown Editor Web wasm-gc example builds without
invoking all-repository native or wasm-gc test targets.
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

Add `--run-showcase-smoke` when you want the helper to build Showcase and then
run the `moui_tester` first-frame smoke. Add `--run-markdown-smoke` to build
Markdown Editor and run the same tester-owned first-frame check:

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

The renderer smoke and normal macOS Skia app entrypoints use the default
system-FontMgr text path, including optional SkShaper when enabled.
Tester-owned first-frame smoke entrypoints explicitly select `EmptyTypeface`,
keeping the smoke text-resolution intent separate from normal app defaults that
exercise platform font lookup, emoji retry, and optional SkShaper when linked.

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

The loop rebuilds the selected package with `moon build` and watches MoonBit,
docs, and browser asset inputs by modification time. It is intentionally a
hot-reload-like developer loop rather than VM state preservation: app state is
rebuilt with the package, while the command gives fast feedback and keeps the
preview target explicit. When previewing Website Docs, `scripts/preview-loop.sh`
runs `node scripts/sync-website-docs.mjs` before building so runtime Markdown
fetches can read same-origin files from `website/web_wasm/docs/*.md`.

Implementation skeletons live in `docs/tutorials.md`, and reusable package,
host-service, renderer, and Showcase checklists live in `docs/templates.md`.

Current-platform backend tests can be included without native example builds:

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

The helper imports `vcvarsall.bat`, sets `CC` and `CXX` to the repository's
MSVC wrapper, enables C11 atomics only for `.c` native stubs, and uses vcpkg
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
moon test moui_skia --target native
sh scripts/dev-check.sh --theme-diagnostics
moon build moui/tests/skia_renderer_smoke/native --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/tests/tooling --target native
moon test moui/backend/web --target wasm-gc
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-maintenance-baseline.mjs
sh scripts/dev-check.sh --platform-examples-test
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
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
moon build examples/markdown_editor/windows_skia --target native
moon build examples/showcase/linux_skia --target native
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

- `Milky2018/moon_taffy` is allowed in `moui/runtime` because layout is
  platform-neutral runtime logic. MoUI maps ordinary flex/grid/list/stack
  placement through Taffy and keeps custom layout delegates, dirty marking, and
  render tree ownership in the runtime package.
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
