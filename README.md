# MoUI

MoUI is a MoonBit GUI framework prototype. The current architecture keeps the app/runtime/view model platform-neutral, with native hosts using `window + wgpu-native` and the Web host using a single `wasm-gc + window/web + browser WebGPU host imports` path.

## Scope

- Platform-neutral `core` runtime, view specs, layout, hit testing, and draw commands.
- Basic views in `views`, including labels, buttons, layout containers, and controlled text fields.
- Unified host boundaries in `backend/host`, with shared `backend/common` window-event mapping and platform hosts normalizing events into `HostEvent`.
- Native rendering through `render/wgpu`.
- Web rendering through `render/webgpu` on `wasm-gc` only. The old JS-target WebGPU path is intentionally removed.

## Packages

```text
core/                         platform-neutral runtime and view model
views/                        public view constructors
backend/host/                 shared HostEvent, metrics, input, redraw driver
backend/common/               shared window/core + dpi event conversion
backend/windows/              Windows native host
backend/macos/                macOS native host
backend/linux/                Linux host scaffold
backend/web/                  canonical Web host on wasm-gc
render/                       renderer facade and shared draw helpers
render/wgpu/                  native wgpu renderer
render/webgpu/                browser WebGPU host-import renderer for wasm-gc
examples/counter_windows/     Windows native counter
examples/counter_macos/       macOS native counter
examples/todo_windows/        Windows native todo
examples/counter_web_wasm/    Web counter on wasm-gc
```

## Web Wasm-GC

Build the Web example:

```powershell
moon build examples/counter_web_wasm --target wasm-gc
python -m http.server 8080 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:8080/examples/counter_web_wasm/index.html
```

The Web path requires browser WebGPU. Startup fails clearly if `navigator.gpu`, an adapter, or a device is unavailable. There is no JS-target fallback branch.

Note: The Milky2018/window package does not support Windows/Web targets. Instead, clone the wzzc-dev/window repository to `.local_repos/window` using: `git clone git@github.com:wzzc-dev/window.git .local_repos/window`. 

## macOS Native

Build the native counter:

```sh
moon build examples/counter_macos --target native
```

Run it:

```sh
moon run examples/counter_macos --target native
```

The macOS host uses `Milky2018/window/macos` for AppKit windows and installs a `CAMetalLayer` on the window `NSView` for the native `render/wgpu` renderer.

## Windows Native

Install the native build/runtime dependencies with MSYS2 UCRT64:

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

Build only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
```

Build and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1
```

Build todo on Windows:

```powershell
moon build examples/todo_windows --target native
.\_build\native\debug\build\examples\todo_windows\todo_windows.exe
```

## Validation

```powershell
moon test render/webgpu --target wasm-gc
moon test backend/web --target wasm-gc
moon build examples/counter_web_wasm --target wasm-gc
moon test --target native
moon build examples/counter_macos --target native
moon build examples/counter_windows --target native
moon build examples/todo_windows --target native
```
