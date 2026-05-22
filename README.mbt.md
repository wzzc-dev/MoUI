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
- [Renderer capability report](docs/renderer-capability-report.md)
- [View catalog](docs/view-catalog.md)
- [Examples](docs/examples.md)
- [Testing](docs/testing.md)
- [AI collaboration](docs/ai-collaboration.md)
- [2026 roadmap](docs/roadmap-2026.md)

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
mkdir -p .local_repos
git clone git@github.com:wzzc-dev/window.git .local_repos/window
git -C .local_repos/window checkout moui-support
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

Build and run the WYSIWYG Markdown editor:

```sh
moon build examples/markdown_editor/macos --target native
./_build/native/debug/build/examples/markdown_editor/macos/macos.exe
```

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

Build the WYSIWYG Markdown editor with the static helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

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
