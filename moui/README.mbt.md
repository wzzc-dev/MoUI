# MoUI

MoUI is a multi-platform MoonBit GUI framework prototype for building
declarative UI apps with shared platform-neutral app logic. Native host cores
own windows, events, services, and lifecycle, then receive concrete renderers
through platform WGPU or Skia provider packages. The Web host uses a single
`wasm-gc + window/web + browser WebGPU host imports` path.

The runtime pipeline is explicit:

```text
View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

Current P0/P1 foundations include component state subscriptions, keyed
component-scoped effects with cleanup, scoped saveable string/bool/int state, an
advanced custom child layout delegate, environment accessibility signals,
gesture/action command primitives, a typed host-service bridge, Linux backend
readiness tracking, and app-framework helpers for routing, forms, and devtool
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
- [Examples](docs/examples.md)
- [Markdown Editor](docs/markdown-editor.md)
- [Testing](docs/testing.md)
- [AI collaboration](docs/ai-collaboration.md)
- [2026 roadmap](docs/roadmap-2026.md)
- [Release readiness](docs/release-readiness.md)

The example suite is intentionally small: Showcase is the visual catalog and now
contains the Counter and Todo interaction patterns, while the WYSIWYG Markdown
editor remains a separate practical editing demo.

## Screenshots

<div align="center">
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/markdown_editor.png" width="400px"/>
  <img src="https://raw.githubusercontent.com/wzzc-dev/MoUI/refs/heads/main/resource/screenshots/showcase.png" width="400px"/>
</div>

## Project Shape

- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  draw command model, typed events, `Program`, and `Effect`.
- `style/` owns visual tokens and style aliases during the split from `core`.
- `views/` exposes public view constructors returning opaque `@core.View[Msg]`.
- `backend/host/` defines shared host contracts; platform backends normalize
  window and input events into `HostEvent`.
- `backend/<platform>/wgpu` and `backend/<platform>/skia` select native WGPU or
  native Skia renderer providers; host-core packages do not import concrete
  renderer implementations.
- `render/` provides the renderer facade, with native wgpu, native Skia raster,
  and WebGPU adapter implementations under `render/wgpu/`, `render/skia/`, and
  `render/webgpu_adapter/`.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints.

## Quick Start

Set up the local `wzzc-dev/window` and `wzzc-dev/skia_mbt` checkouts, then run
the bounded development check:

```sh
sh scripts/setup-local-deps.sh
sh scripts/check-local-deps.sh
sh scripts/dev-check.sh
```

## Web Wasm-GC

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

Native example builds link the platform window backend and `wgpu-native`.
Cold builds can be noticeably slower than package tests or Web wasm-gc example
builds, so they are kept out of the default development check.

For macOS `moon run` linker errors, see
[Platform notes](docs/platform-notes.md#macos-native).

Build the visual showcase:

```sh
moon build examples/showcase/macos --target native
```

Build the visual showcase with the shared Moon Cosmic text provider selected
explicitly:

```sh
moon build examples/showcase/macos_cosmic --target native
```

Build the visual showcase with the native Skia raster renderer selected
explicitly:

```sh
moon build examples/showcase/macos_skia --target native
```

Build and run the WYSIWYG Markdown editor:

```sh
moon build examples/markdown_editor/macos --target native
./_build/native/debug/build/examples/markdown_editor/macos/macos.exe
```

Wrap a native example as a local `.app` bundle:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

The bundle includes and validates a schema version 1 `moui-package.json`
manifest under `Contents/Resources`.

## Windows Native

Windows native examples use the MSVC toolchain, vcpkg `zlib:x64-windows`, and
`wgpu_mbt` dynamic mode with the official MSVC `wgpu_native.dll` release. These
builds are useful for platform validation, but they are intentionally treated as
slow checks rather than routine package-level tests.

Setup, build, and package the Showcase:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The Showcase also has a Windows entrypoint that selects the shared Moon Cosmic
text provider explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_cosmic `
  -BuildOnly
```

Build the WYSIWYG Markdown editor with the same MSVC helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows `
  -BuildOnly
```

To run a Windows entrypoint directly, import the MSVC environment in the same
PowerShell process:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }"
```

The MSVC package is written under `dist\windows-msvc\MoUIShowcase` and includes
`run.cmd`, `wgpu_native.dll`, WGPU release metadata, and the vcpkg zlib runtime
DLL. Use `run.cmd` so `MBT_WGPU_NATIVE_ROOT` points at the bundled WGPU release.
When Visual Studio's bundled vcpkg refuses direct classic installs, run the
setup helper from the repository root; it creates an ignored manifest workspace
under `.tools\vcpkg-msvc` and installs `zlib:x64-windows` there.

## Linux Native

Linux native examples use the local fork-owned `window/linux` Wayland backend.
The default and `linux_cosmic` Showcase entrypoints use native `wgpu-native`
surfaces; `linux_skia` selects the native Skia raster provider and presents CPU
pixel frames through Wayland `wl_shm`. Run them on a Linux host with a Wayland
compositor and renderer stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
moon run examples/showcase/linux_skia --target native
```

For headless validation, use a compositor such as Weston headless and set
`WAYLAND_DISPLAY` to its socket before running the examples. The default Linux
text path composes the fontconfig provider scaffold with Moon Cosmic fallback;
`linux_cosmic` selects Moon Cosmic directly. Configure real Skia link flags
before relying on Skia-rendered pixels from `linux_skia`.
