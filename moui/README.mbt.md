# MoUI

MoUI is a multi-platform MoonBit GUI framework for building declarative UI
apps with shared platform-neutral app logic. Native host cores own windows,
events, services, and lifecycle, then receive concrete renderers through
platform renderer provider packages. The current mainline is native Skia
raster plus the Web `wasm-gc + window/web + browser WebGPU host imports` path;
native WGPU remains available as an experimental diagnostic route while the
MoonBit WGPU ecosystem matures.

The runtime pipeline is explicit:

```text
View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

Current P0/P1 foundations include component state subscriptions, keyed
component-scoped effects with cleanup, scoped saveable string/bool/int state, an
advanced custom child layout delegate, environment accessibility signals,
gesture/action command primitives, a typed host-service bridge, native Skia and
experimental Sun raster providers, Linux backend readiness tracking, and
app-framework helpers for routing, forms, and devtool snapshots.

Detailed notes live in:

- [Architecture](https://github.com/wzzc-dev/MoUI/blob/main/docs/architecture.md)
- [Development](https://github.com/wzzc-dev/MoUI/blob/main/docs/development.md)
- [Platform notes](https://github.com/wzzc-dev/MoUI/blob/main/docs/platform-notes.md)
- [Text system](https://github.com/wzzc-dev/MoUI/blob/main/docs/text-system.md)
- [Renderer capability report](https://github.com/wzzc-dev/MoUI/blob/main/docs/renderer-capability-report.md)
- [View catalog](https://github.com/wzzc-dev/MoUI/blob/main/docs/view-catalog.md)
- [Views API guide](https://github.com/wzzc-dev/MoUI/blob/main/docs/views-api-guide.md)
- [Non-render component cookbook](https://github.com/wzzc-dev/MoUI/blob/main/docs/non-render-component-cookbook.md)
- [App templates](https://github.com/wzzc-dev/MoUI/blob/main/docs/app-templates.md)
- [API surface](https://github.com/wzzc-dev/MoUI/blob/main/docs/api-surface.md)
- [Maintenance mainline](https://github.com/wzzc-dev/MoUI/blob/main/docs/maintenance.md)
- [Examples](https://github.com/wzzc-dev/MoUI/blob/main/docs/examples.md)
- [Markdown Editor](https://github.com/wzzc-dev/MoUI/blob/main/docs/markdown-editor.md)
- [Mo Workbench](https://github.com/wzzc-dev/MoUI/blob/main/docs/mo-workbench.md)
- [Showcases](https://github.com/wzzc-dev/MoUI/blob/main/docs/showcases.md)
- [Testing](https://github.com/wzzc-dev/MoUI/blob/main/docs/testing.md)
- [AI collaboration](https://github.com/wzzc-dev/MoUI/blob/main/docs/ai-collaboration.md)
- [2026 roadmap](https://github.com/wzzc-dev/MoUI/blob/main/docs/roadmap-2026.md)
- [Release readiness](https://github.com/wzzc-dev/MoUI/blob/main/docs/release-readiness.md)

The example suite is intentionally small but covers the breadth of the
runtime. Showcase is the visual component catalog; Markdown Editor is the
large WYSIWYG editing demo; Mo Workbench is the native-Skia-first desktop
agent dogfood app; Excel Viewer renders `bobzhang/mbtexcel` workbooks with
the MoUI data table surface; PDF Workbench exercises document reading/light
editing on the native Skia route with a lightweight UI shell, a separate
`pdflite` adapter package for real PDF model/writeback checks, and a
native-only PDFium adapter for real page bitmap rasterization; Design Systems
is the separate `moui_theme` addon diagnostic preview/parity sampler. The
root `website/` workspace member is the MoUI-built homepage and Web demo
surface, written in MoUI itself.

## Screenshots

<div align="center">
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/mo_workbench.png" width="400px"/>
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/markdown_editor.png" width="400px"/>
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/showcase.png" width="400px"/>
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/excel.png" width="400px"/>
</div>

## Project Shape

- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  draw command model, typed events, `Program`, `Effect`, and `Subscription`.
- The root `moui` facade re-exports the high-frequency app-loop kernel types
  (`View`, `Program`, `Effect`, `Subscription`, `Theme`, `Environment`,
  `ViewEnvironment`) from `core`; geometry/graphics/text/state sugar stays in
  the sibling `moui/{geometry,graphics,text,state}` packages. There is no
  separate `style` package.
- `views/` exposes public view constructors returning opaque `@core.View[Msg]`,
  including layout, controls, data tables, navigation, and
  `custom_layout`/`custom_children_layout` escapes for advanced app usage.
- `runtime/` exposes app/host `AppRuntime` construction entrypoints and owns
  runtime state, tree/layout/paint, event dispatch, program message drain,
  effect task, subscription lifecycle, and diagnostics.
- `moui_theme/` is an optional repo-local addon workspace member for shared
  source-mapped design-system models, package-local Material/Carbon/Primer/
  Fluent entrypoints, and custom theme builders; core MoUI apps do not need
  it.
- `moui_skia/` (published as `wzzc-dev/moui_skia@0.1.7`) is the native Skia
  raster binding workspace; `moui_sun/` (published as
  `wzzc-dev/moui_sun@0.1.7`) is an experimental native raster alternative.
  They are depended on by app platform entrypoints, not by `moui` core.
- `backend/host/` defines shared host contracts; platform backends normalize
  window and input events into `HostEvent`.
  - `backend/<platform>/skia` selects the native Skia raster mainline provider
    (the recommended route).
  - `backend/<platform>/wgpu` keeps native WGPU available as an experimental
    diagnostic provider.
  - Host-core packages do not import concrete renderer implementations.
- `render/` provides the renderer facade, with native Skia raster, WebGPU
  adapter, and experimental native WGPU implementations under `render/skia/`,
  `render/webgpu_adapter/`, and `render/wgpu/`.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints. Featured examples: `examples/showcase` (visual catalog,
  Skia mainline + WGPU/Sun diagnostics), `examples/markdown_editor` (WYSIWYG),
  `examples/mo_workbench` (macOS-Skia agent desktop), `examples/excel`
  (`mbtexcel` workbook renderer), `examples/pdf_workbench` (native PDF
  read/edit). `examples/showcase` stays independent of `moui_theme`;
  `examples/design_systems` is the dedicated addon diagnostic example that
  exercises the official-system entrypoint packages on Web wasm-gc plus macOS,
  Windows, and Linux Skia entrypoints.
- `website/` is a root workspace member for the MoUI homepage, with shared app
  logic in `website/app/` and a Web wasm-gc entrypoint in
  `website/web_wasm/`. The homepage is rendered by MoUI itself and contains a
  screenshot-driven Showcases page sizing native MoonBit views.

## Quick Start

Refresh registry packages, verify the window dependency pin, then run the
bounded development check:

```sh
moon update
node scripts/validate-window-dependency.mjs
sh scripts/check.sh --profile daily
```

The default daily baseline covers the core framework, Web wasm-gc, native
Skia mainline contracts, Showcase, and Markdown Editor. Design Systems is
addon diagnostic coverage; run `sh scripts/check.sh --profile theme`
when changing `moui_theme` or `examples/design_systems`.

MoUI resolves `wzzc-dev/window` from the MoonBit registry as
`wzzc-dev/window@0.5.1-0.1.7`; `moon.work` does not include a local window
checkout. `scripts/validate-window-dependency.mjs` enforces that pin and the
absence of a repo-local window workspace member. To edit window source
locally, run `sh scripts/window-dev-mode.sh on` (adds `./window` to
`moon.work`), then run `sh scripts/window-dev-mode.sh off` before committing.
The `moui_skia` binding workspace's platform status and native capability
contracts are validated by
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`, both wired into
`check.sh --profile daily`. Those Skia guards prove the provider lock, fallback parity,
FFI ownership/borrow metadata, native smoke marker coverage, and
binding-level evidence wiring are present; renderer pixels and platform
runtime behavior still come from the opt-in Skia smoke or matching-host
example runs.

For current-host backend/provider evidence, run:

```sh
sh scripts/check.sh --profile platform
```

The `platform` profile also runs platform-service checks against
`artifacts/conformance/platform-runtime-evidence.json`, the schema v2
matching-host evidence contract for Web, macOS, Windows, and Linux runtime
claims. Entries start as pending until a matching host records passed or
failed observations before a preview handoff. The checked-in manifest
currently marks macOS `status=passed` from local matching-host AppKit/Skia
artifacts with every runtime and native IME observation set to `yes` plus
`skiaEvidence.status=passed`; a non-skipped manual GitHub Actions dispatch
also recorded the macOS platform runtime evidence with `github-actions`
provenance and uploaded the matching artifact bundle. Windows and Linux
remain pending until their matching hosts record equivalent
platform-runtime artifacts. Native passed entries include the
`wzzc-dev/window@0.5.1-0.1.7` package smoke monitor/cursor probe as
`monitorCursor=yes`; Web browser-session evidence may leave that field
pending because CDP does not prove native monitor/current-monitor or cursor
behavior. A passed entry must carry provenance from either a non-skipped
successful GitHub Actions job/run, including run URL, workflow, job,
runner, and uploaded artifacts, or a local matching-host artifact bundle.
For Web, the fold derives this from the browser-session presentation
manifest and the environment that performed the fold. Skipped CI jobs,
build-only/package-only jobs, and provider/preflight checks cannot be used
as passed runtime evidence. See `docs/release-readiness.md` for the
recorded GitHub Actions macOS-only evidence run, the latest all-green
`MoUI CI` run, and their head-SHA boundaries.

For release-oriented screenshot and benchmark handoffs, use
`node scripts/conformance-capture-scaffold.mjs --mode golden` and
`node scripts/conformance-capture-scaffold.mjs --mode benchmark`; these write validated capture
manifests under `artifacts/conformance/`. The benchmark handoff also
validates the static Web runtime delivery chain for Showcase and Markdown
Editor with `node scripts/validate-web-runtime-handoff.mjs`, while browser
WebGPU/canvas presentation evidence is collected separately with
`node scripts/record-web-runtime-presentation.mjs` and validated with
`node scripts/validate-web-runtime-presentation-manifest.mjs`. A passed
`artifacts/conformance/web-runtime-presentation.json` proves the named
browser session reached WebGPU startup, wasm app startup, sized canvas,
resize/input event-bridge delivery, Markdown Editor text input, clean
target close, clean console, and nonblank screenshot thresholds. Fold the
browser artifact into
`artifacts/conformance/platform-runtime-evidence.json` with
`node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json`
so Web platform claims cite one validated evidence manifest and
browser-session artifact provenance. A failed browser manifest records
failed Web platform evidence; a missing browser manifest keeps the Web
platform entry pending.

For a minimal starting template, clone the standalone `moui_example`
counter repo (it is not a workspace member here and is not built by
`check.sh --profile daily`):

```sh
git clone git@github.com:moui-mbt/moui_example.git
cd moui_example
moon update
```

## Mobile Packaging

Android and iOS packaging support is published inside this package under
`moui/mobile` and `moui/scripts/mobile`. An application project owns its own
shared app package, mobile platform entrypoint packages, `mobile.json`, Android
Gradle project, and iOS Xcode project; the MoUI package supplies the reusable
Gradle/JNI/CMake and UIKit/native build templates.

Start from the copyable files in:

```text
.mooncakes/wzzc-dev/moui/mobile/template.mobile.json
.mooncakes/wzzc-dev/moui/mobile/android/template/
.mooncakes/wzzc-dev/moui/mobile/ios/template/
```

Android debug APK from an app workspace:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --android-project "$PWD/android_app"
```

iOS Simulator app from an app workspace:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --xcode-project "$PWD/ios_app/MoUIMobileApp.xcodeproj" \
  --scheme MoUIMobileApp \
  --product-name MoUIMobileApp
```

`mobile.json` must include the app id, package paths, bundle/application ids,
and the native export contract under `android.native` and `ios.native` unless
the app is one of this repository's built-in examples. Fallback Skia builds
(`--fallback-skia`) prove packaging only; passed Android/iOS runtime claims
still require a non-fallback build plus matching emulator/simulator or device
smoke evidence.

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
mainline entrypoints select the native Skia raster provider. Cold builds can
be noticeably slower than package tests or Web wasm-gc example builds, so
they are kept out of the default development check.

For macOS `moon run` linker errors, see
[macOS platform notes](https://github.com/wzzc-dev/MoUI/blob/main/docs/platform-notes-macos.md).

Build and run the visual showcase on the Skia mainline:

```sh
moon run examples/showcase/macos_skia --target native
```

The `examples/showcase/macos_wgpu`, `examples/showcase/macos_wgpu_cosmic`,
and `examples/showcase/macos_sun` entrypoints remain available as native
diagnostics:

```sh
moon build examples/showcase/macos_wgpu --target native
moon build examples/showcase/macos_wgpu_cosmic --target native
moon build examples/showcase/macos_sun --target native
```

Build and run the WYSIWYG Markdown editor on the Skia mainline:

```sh
moon run examples/markdown_editor/macos_skia --target native
```

Build and run Excel Viewer on the Skia mainline:

```sh
moon run examples/excel/macos_skia --target native
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

Mo Workbench currently ships the macOS Skia entrypoint only. The
`bobzhang/openseek` dependency resolves from mooncakes.io; no submodule
override is needed:

```sh
moon run examples/mo_workbench/macos_skia --target native
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
`wgpu_native.dll` release, but they are experimental diagnostics rather than
the default validation route.

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

The Showcase also has Windows WGPU/Cosmic and Sun diagnostic entrypoints:

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
PowerShell process. The helper imports `vcvarsall.bat`, sets `CC` and `CXX` to
`cl.exe`, and applies shared `CL`/`LINK` flags for MoonBit native stubs. Skia
C++ stubs still use their own `/std:c++20` flags from the `moui_skia` prebuild.

This package ships `scripts/windows/msvc_env.ps1` so it is available after
`moon publish` / `moon add wzzc-dev/moui`. The script walks up from the current
directory to find your project root (`moon.mod` or `moon.work`) for
`.tools\vcpkg-msvc` and WGPU bundles, or set `MOUI_MSVC_WORKSPACE_ROOT`
explicitly.

MoUI repository checkout (wrapper forwards to the copy under `moui/`):

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

Consumer project with only the published `wzzc-dev/moui` dependency (run from
your app root; adjust the path to the resolved package directory on disk):

```powershell
. (Join-Path (Resolve-Path ".\.mooncakes\wzzc-dev\moui").Path "scripts\windows\msvc_env.ps1")
moon run your_app/windows_skia --target native
```

Consumer project with only the published `wzzc-dev/moui` dependency (run from
your app root; adjust the path to the resolved package directory on disk):

```powershell
. (Join-Path (Resolve-Path ".\.mooncakes\wzzc-dev\moui").Path "scripts\windows\msvc_env.ps1")
moon run your_app/windows_skia --target native
```

The MSVC package is written under `dist\windows-msvc\MoUIShowcase` and
includes `run.cmd` and the vcpkg zlib runtime DLL. WGPU diagnostic packages
additionally include `wgpu_native.dll`, WGPU release metadata, and a
`run.cmd` wrapper that sets `MBT_WGPU_NATIVE_ROOT` to the bundled WGPU
release. When Visual Studio's bundled vcpkg refuses direct classic installs,
run the setup helper from the repository root; it creates an ignored
manifest workspace under `.tools\vcpkg-msvc` and installs
`zlib:x64-windows` there.

Excel Viewer does not currently ship a Windows entrypoint; it runs on
macOS Skia and Linux Skia only.

## Linux Native

Linux native examples use the `wzzc-dev/window@0.5.1-0.1.7` Wayland backend.
The recommended mainline entrypoints select native Skia raster and present
CPU pixel frames through Wayland `wl_shm`. Run them on a Linux host with a
Wayland compositor and configured real Skia link flags:

```sh
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
moon run examples/excel/linux_skia --target native
```

The `examples/showcase/linux_wgpu`, `examples/showcase/linux_wgpu_cosmic`,
and `examples/showcase/linux_sun` entrypoints remain available as native
WGPU / Sun diagnostics when a Vulkan/WGPU stack is configured.

For headless validation, use a compositor such as Weston headless and set
`WAYLAND_DISPLAY` to its socket before running the examples. The WGPU Linux
text path composes the fontconfig/FreeType provider with Moon Cosmic
fallback; that provider currently has a narrow native color-emoji path for
explicit emoji family runs, while general text still falls back to Cosmic.
`linux_wgpu_cosmic` selects Moon Cosmic directly.
