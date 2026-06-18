# Development

This page is the root maintainer guide for local setup, workspace shape,
documentation sync, app iteration, and validation. Product-facing website docs
are generated from this `docs/` directory by `scripts/sync-website-docs.mjs`.

## Local Setup

From the repository root, refresh registry packages and check repo-local
dependency contracts:

```sh
moon update
sh scripts/check-local-deps.sh
```

`moon update` refreshes registry packages. `scripts/check-local-deps.sh`
verifies the expected `wzzc-dev/window` and `wzzc-dev/moui_skia` wiring,
confirms `moon.work` does not reintroduce a local window checkout, checks the
editable `moui_skia` acceptance surface, and validates the Skia capability
contract. Current dependency versions live in `moui/moon.mod` and
`moui_skia/moon.mod`; do not duplicate those versions in prose without checking
the files first.

The MoonBit package ecosystem moves quickly. If a dependency-related build
fails, first run `moon update`, inspect the resolved package version, and check
whether the failure is a registry/cache/dependency issue before changing MoUI
code.

## Workspace Members

`moon.work` currently includes:

- `./moui`
- `./moui_richtext`
- `./moui_tester`
- `./moui_devtools`
- `./moui_agent`
- `./moui_agent_mcp`
- `./tools`
- `./moui_skia`
- `./moui_theme`
- `./examples/agent_counter`
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

For Web preview iteration:

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
