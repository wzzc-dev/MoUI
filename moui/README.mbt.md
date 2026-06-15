# MoUI

MoUI is a multi-platform MoonBit GUI framework prototype for building
declarative UI apps with shared platform-neutral app logic. Native host cores
own windows, events, services, and lifecycle, then receive concrete renderers
through platform renderer provider packages. The recommended mainline is native
Skia raster plus the single Web `wasm-gc + window/web + browser WebGPU host
imports` path; native WGPU remains available as an experimental diagnostic
route while the MoonBit WGPU ecosystem matures.

The runtime pipeline is explicit:

```text
View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

Current P0/P1 foundations include component state subscriptions, keyed
component-scoped effects with cleanup, scoped saveable string/bool/int state, an
advanced custom child layout delegate, environment accessibility signals,
gesture/action command primitives, a typed host-service bridge, Linux backend
availability tracking, and app-framework helpers for routing, forms, and devtool
snapshots.

Detailed notes live in:

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Platform notes](docs/platform-notes.md)
- [Text system](docs/text-system.md)
- [Renderer capability report](docs/renderer-capability-report.md)
- [View catalog](docs/view-catalog.md)
- [Non-render component cookbook](docs/non-render-component-cookbook.md)
- [App templates](docs/app-templates.md)
- [API surface](docs/api-surface.md)
- [Maintenance mainline](docs/maintenance.md)
- [Examples](docs/examples.md)
- [Markdown Editor](docs/markdown-editor.md)
- [Testing](docs/testing.md)
- [AI collaboration](docs/ai-collaboration.md)
- [2026 roadmap](docs/roadmap-2026.md)
- [Release readiness](docs/release-readiness.md)

The example suite is intentionally small: Showcase is the visual catalog and now
contains the Counter and Todo interaction patterns, Design Systems is the
separate `moui_theme` addon diagnostic preview/parity sampler, the WYSIWYG
Markdown editor remains a practical editing demo, and PDF Workbench exercises document
reading/light editing on the native Skia route with a lightweight UI shell, a
separate `pdflite` adapter package for real PDF model/writeback checks, and a
native-only PDFium adapter for real page bitmap rasterization. The root
`website/` workspace is the MoUI-built bilingual homepage and Web demo surface.

## Screenshots

<div align="center">
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/markdown_editor.png" width="400px"/>
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/showcase.png" width="400px"/>
</div>

## Project Shape

- `core/` owns the platform-neutral contract model, opaque `View`, typed
  events, `Program`, `Effect`, `Subscription`, geometry, draw, semantics, and a
  narrow `RuntimeKernel` contract seam consumed by `moui/runtime` for
  tree/layout/paint handoff.
- `runtime/` exposes the app/host `AppRuntime` construction entrypoints and
  owns program message drain, effect task, subscription lifecycle, and
  diagnostics.
- The root `moui` facade exposes only the curated
  `View`/`Program`/`Effect`/`Subscription`/`Theme` aliases; diagnostics,
  theme builders, runtime handles, and renderer-facing records stay in their
  owning packages.
- `views/` exposes public view constructors returning opaque
  `@moui.View[Msg]` / `@core.View[Msg]` compatible values.
- `moui_theme/` is an optional repo-local addon workspace member for shared
  source-mapped design-system models, package-local Material/Carbon/Primer/Fluent
  entrypoints, and custom theme builders; core MoUI apps do not need it.
- `backend/host/` defines shared host contracts; platform backends normalize
  window and input events into `HostEvent`.
- `backend/<platform>/skia` selects the native Skia raster mainline provider;
  `backend/<platform>/wgpu` keeps the native WGPU experimental provider
  available for diagnostics. Host-core packages do not import concrete renderer
  implementations.
- `render/` provides the renderer facade, with native Skia raster, WebGPU
  adapter, and experimental native wgpu implementations under `render/skia/`,
  `render/webgpu_adapter/`, and `render/wgpu/`.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints. `examples/showcase` stays independent of `moui_theme`;
  `examples/design_systems` is the dedicated addon diagnostic example that
  exercises the official-system entrypoint packages on Web wasm-gc plus macOS,
  Windows, and Linux Skia entrypoints.
- `website/` is a root workspace member for the MoUI homepage, with shared app
  logic in `website/app/` and a Web wasm-gc entrypoint in `website/web_wasm/`.

## Quick Start

Refresh registry packages, verify the repo-local `moui_skia` workspace, then
run the bounded development check:

```sh
moon update
sh scripts/check-local-deps.sh
sh scripts/dev-check.sh
```

The default daily baseline covers the core framework, maintenance baseline
ratchets, Web wasm-gc, native Skia mainline contracts, Showcase, and Markdown
Editor. Design Systems is addon diagnostic coverage; run
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or
`examples/design_systems`.

MoUI resolves `wzzc-dev/window` from the MoonBit registry as
`wzzc-dev/window@0.5.1-0.1.4`; `moon.work` does not include a local window
checkout. The dependency check verifies that package version, the absence of a
repo-local window workspace member, and the `moui_skia` binding workspace's
platform status and native capability contracts via
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`. The MoonBit package
ecosystem is still maturing, so unexplained build or smoke failures may come
from registry cache state or dependency package regressions; include
`moon update` and package-version inspection in the first pass of debugging.
Those Skia guards check the provider lock, fallback parity, FFI ownership/borrow
metadata, native smoke marker coverage, and binding-level wiring; renderer
pixels and platform runtime behavior still come from manual smoke runs or
matching-host logs.

For current-host backend/provider checks, run:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/conformance-check.sh --platform-services
```

For release-oriented screenshot and benchmark handoffs, use
`sh scripts/conformance-check.sh --golden` and
`sh scripts/conformance-check.sh --bench`. These generate local scaffold
manifests and logs under `artifacts/`, but those files are not checked in and
are not capability declarations. `artifacts/ is ignored` so release notes should
cite a CI run, uploaded artifact, or local smoke log directly.

Browser runtime checks are also smoke-level. Use
`sh scripts/ci-web-runtime-presentation.sh` or run
`node scripts/record-web-runtime-presentation.mjs` with a local static server
and Chrome DevTools Protocol, then validate the generated local manifest with
`node scripts/validate-web-runtime-presentation-manifest.mjs`. The result says
whether that named browser session started WebGPU/wasm, produced a nonblank
canvas, delivered representative input, and closed cleanly; it is not a
checked-in platform claim.

## Web Wasm-GC

Build and serve the MoUI homepage:

```sh
moon build website/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/website/web_wasm/index.html
```

Build and serve the visual showcase:

```sh
moon build examples/showcase/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/showcase/web_wasm/index.html
```

Build and serve the WYSIWYG Markdown editor:

```sh
moon build examples/markdown_editor/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/markdown_editor/web_wasm/index.html
```

## macOS Native

Native macOS examples use the platform window backend; the recommended
mainline entrypoints select the native Skia raster provider. Cold builds can be
noticeably slower than package tests or Web wasm-gc example builds, so they are
kept out of the default development check.

For macOS `moon run` linker errors, see
[Platform notes](docs/platform-notes.md#macos-native).

Build the visual showcase on the Skia mainline:

```sh
moon build examples/showcase/macos_skia --target native
```

The `examples/showcase/macos_wgpu` and `examples/showcase/macos_wgpu_cosmic` entrypoints
remain available as native WGPU diagnostics:

```sh
moon build examples/showcase/macos_wgpu --target native
moon build examples/showcase/macos_wgpu_cosmic --target native
```

Build and run the WYSIWYG Markdown editor on the Skia mainline:

```sh
moon build examples/markdown_editor/macos_skia --target native
./_build/native/debug/build/examples/markdown_editor/macos_skia/macos_skia.exe
```

Build and run PDF Workbench on the Skia mainline:

```sh
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/app --target native
MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon build examples/pdf_workbench/macos_skia --target native
./_build/native/debug/build/examples/pdf_workbench/macos_skia/macos_skia.exe
```

The WGPU Markdown editor entrypoint is still available for diagnostics:

```sh
moon build examples/markdown_editor/macos_wgpu --target native
./_build/native/debug/build/examples/markdown_editor/macos_wgpu/macos_wgpu.exe
```

Wrap a native example as a local `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

The bundle includes and validates a schema version 1 `moui-package.json`
manifest under `Contents/Resources`.

## Windows Native

Windows native examples use the MSVC toolchain and vcpkg `zlib:x64-windows`.
The recommended mainline entrypoints select native Skia raster. Native WGPU
entrypoints still use `wgpu_mbt` dynamic mode with the official MSVC
`wgpu_native.dll` release, but they are experimental diagnostics rather than the
default validation route.

Setup, build, and package the default Showcase:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The Showcase also has Windows WGPU/Cosmic diagnostic entrypoints:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_wgpu `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_wgpu_cosmic `
  -BuildOnly
```

Build the WYSIWYG Markdown editor with the same MSVC helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows_skia `
  -BuildOnly
```

The WGPU Markdown editor entrypoint remains available for diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows_wgpu `
  -BuildOnly
```

To run a Windows entrypoint directly, import the MSVC environment in the same
PowerShell process. The helper routes `.c` native stubs through C11 atomics and
keeps Skia `.cpp` stubs on their own C++ standard flags:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

The MSVC package is written under `dist\windows-msvc\MoUIShowcase` and includes
`run.cmd` and the vcpkg zlib runtime DLL. WGPU diagnostic packages additionally
include `wgpu_native.dll`, WGPU release metadata, and a `run.cmd` wrapper that
sets `MBT_WGPU_NATIVE_ROOT` to the bundled WGPU release.
When Visual Studio's bundled vcpkg refuses direct classic installs, run the
setup helper from the repository root; it creates an ignored manifest workspace
under `.tools\vcpkg-msvc` and installs `zlib:x64-windows` there.

## Linux Native

Linux native examples use the `wzzc-dev/window@0.5.1-0.1.4` Wayland backend.
The recommended mainline entrypoints select native Skia raster and present CPU
pixel frames through Wayland `wl_shm`. Run them on a Linux host with a Wayland
compositor and configured real Skia link flags:

```sh
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

The `examples/showcase/linux_wgpu` and `examples/showcase/linux_wgpu_cosmic` entrypoints
remain available as native WGPU diagnostics when a Vulkan/WGPU stack is
configured.

For headless validation, use a compositor such as Weston headless and set
`WAYLAND_DISPLAY` to its socket before running the examples. The WGPU Linux
text path composes the fontconfig/FreeType provider with Moon Cosmic fallback;
that provider currently has a narrow native color-emoji path for explicit emoji
family runs, while general text still falls back to Cosmic. `linux_wgpu_cosmic`
selects Moon Cosmic directly.
