# MoUI

MoUI is a multi-platform MoonBit GUI framework prototype. The app/runtime/view model stays platform-neutral, with native hosts using `window + wgpu-native` and the Web host using `wasm-gc + window/web + browser WebGPU host imports`.

Detailed design notes live in:

- [Architecture](docs/architecture.md)
- [Platform notes](docs/platform-notes.md)

The WYSIWYG Markdown example is intentionally layered: `core` provides the
generic multiline rich text editor, while the example app owns Markdown parsing
and conversion into styled text runs.

## Local Dependencies

The upstream `Milky2018/window` package does not currently cover the targets
MoUI needs, so use the modified local checkout instead.

From the repository root:

```sh
mkdir -p .local_repos
git clone git@github.com:wzzc-dev/window.git .local_repos/window
git -C .local_repos/window checkout moui-support
```

## Web Wasm-GC

Build and serve the todo example:

```sh
moon build examples/todo/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/todo/web_wasm/index.html
```

Build and serve the counter example:

```sh
moon build examples/counter/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/counter/web_wasm/index.html
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

Build and run the todo example:

```sh
moon build examples/todo/macos --target native
./_build/native/debug/build/examples/todo/macos/macos.exe
```

Optional `moon run` shortcut:

```sh
moon run examples/todo/macos --target native
```

Build and run the counter example:

```sh
moon build examples/counter/macos --target native
./_build/native/debug/build/examples/counter/macos/macos.exe
```

Optional `moon run` shortcut:

```sh
moon run examples/counter/macos --target native
```

For macOS `moon run` linker errors, see [Platform notes](docs/platform-notes.md#macos-native).

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

Build the counter example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
```

Build and run the counter example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1
```

Build and run the todo example:

```powershell
moon build examples/todo/windows --target native
.\_build\native\debug\build\examples\todo\windows\windows.exe
```

Build and run the WYSIWYG Markdown editor:

```powershell
moon build examples/markdown_editor/windows --target native
.\_build\native\debug\build\examples\markdown_editor\windows\windows.exe
```

## Validation

```sh
moon test render/webgpu --target wasm-gc
moon test backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/todo/web_wasm --target wasm-gc
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon test --target native
moon build examples/todo/macos --target native
moon build examples/counter/macos --target native
moon build examples/showcase/macos --target native
moon build examples/markdown_editor/macos --target native
moon build examples/todo/windows --target native
moon build examples/counter/windows --target native
moon build examples/markdown_editor/windows --target native
```
