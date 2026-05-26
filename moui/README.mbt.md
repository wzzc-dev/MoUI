# MoUI

MoUI is a multi-platform MoonBit GUI framework prototype for building
declarative UI apps with shared platform-neutral app logic. Native hosts use
`window + wgpu-native`; the Web host uses a single
`wasm-gc + window/web + browser WebGPU host imports` path.

The runtime pipeline is explicit:

```text
ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
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
- [Examples](docs/examples.md)
- [Markdown Editor](docs/markdown-editor.md)
- [Testing](docs/testing.md)
- [AI collaboration](docs/ai-collaboration.md)
- [2026 roadmap](docs/roadmap-2026.md)
- [Release readiness](docs/release-readiness.md)

The example suite is intentionally small: Showcase is the visual catalog and now
contains the Counter and Todo interaction patterns, while the WYSIWYG Markdown
editor remains a separate practical editing demo.

## Project Shape

- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  and draw command model.
- `views/` exposes public view constructors returning `@core.ViewSpec`.
- `backend/host/` defines shared host contracts; platform backends normalize
  window and input events into `HostEvent`.
- `render/` provides the renderer facade, with native wgpu and WebGPU adapter
  implementations under `render/wgpu/` and `render/webgpu_adapter/`.
- `examples/*/app/` contains shared app logic, while platform subpackages are
  thin entrypoints.

## Quick Start

Set up the local `Milky2018/window` checkout and run the bounded development
check:

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

Windows native examples use the static GNU `wgpu-native` release below. These
builds are useful for platform validation, but they are intentionally treated as
slow checks rather than routine package-level tests.

Install native build/runtime dependencies with MSYS2 UCRT64:

```powershell
C:\msys64\usr\bin\pacman.exe -S --needed --noconfirm `
  mingw-w64-ucrt-x86_64-gcc `
  mingw-w64-ucrt-x86_64-vulkan-loader `
  mingw-w64-ucrt-x86_64-vulkan-headers
```

Use the static Windows GNU `wgpu-native` release expected by the helper script:

```text
.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release
```

Download it manually from:

```text
https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0
```
### Showcase

```powershell
$env:PATH = "C:\msys64\ucrt64\bin;$env:PATH"
$env:CC = "x86_64-w64-mingw32-gcc"
$env:CXX = "x86_64-w64-mingw32-g++"
$env:MBT_WGPU_NATIVE_ROOT = "$PWD\.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release"
moon run examples/showcase/windows --target native
```

The Showcase also has a Windows entrypoint that selects the shared Moon Cosmic
text provider explicitly:

```powershell
moon run examples/showcase/windows_cosmic --target native
```

### Markdown Editor

Build the WYSIWYG Markdown editor with the static helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

Package a native example as a reusable local folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

The output folder includes and validates the same schema version 1
`moui-package.json` manifest plus copied runtime DLL metadata.

Build and run the WYSIWYG Markdown editor with the static helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1
```

Build and run the WYSIWYG Markdown editor:

```powershell
moon build examples/markdown_editor/windows --target native
.\_build\native\debug\build\examples\markdown_editor\windows\windows.exe
```

Optional `moon run` shortcut:

```sh
moon run examples/markdown_editor/windows --target native
```

## Linux Native

Linux native examples use the local fork-owned `window/linux` Wayland backend
and native `wgpu-native` surfaces. Run them on a Linux host with a Wayland
compositor and Vulkan stack:

```sh
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
```

For headless validation, use a compositor such as Weston headless and set
`WAYLAND_DISPLAY` to its socket before running the examples. The default Linux
text path composes the fontconfig provider scaffold with Moon Cosmic fallback;
`linux_cosmic` selects Moon Cosmic directly.
