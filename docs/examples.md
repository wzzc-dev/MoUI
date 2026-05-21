# Examples

MoUI examples are runnable documentation. Shared application logic lives in
`examples/*/app/`; platform subpackages are thin entrypoints for Web wasm-gc,
macOS native, and Windows native hosts.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Counter | Minimal app state and event handling | `examples/counter/app/` | `State`, text, button, click events |
| Todo | Basic application structure | `examples/todo/app/` | Text field, list layout, app-owned data |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | Public `views` constructors, embedded Counter/Todo/Markdown previews, theme, presentation, renderer capability status |
| Markdown Editor | Practical editing demo | `examples/markdown_editor/app/` | Rich text editor, `mizchi/markdown` parsing, source preview |

## Web Wasm-GC

Build any Web example from the repository root, then serve the repository with a
local static server:

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/todo/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open the corresponding `examples/*/web_wasm/index.html` page from the local
server. The Web path uses `wasm-gc + window/web + browser WebGPU host imports`;
there is no JS-target fallback.

## macOS Native

macOS examples use the shared app package plus `backend/macos` and native
`render/wgpu` surface setup:

```sh
moon build examples/counter/macos --target native
moon build examples/todo/macos --target native
moon build examples/showcase/macos --target native
moon build examples/markdown_editor/macos --target native
```

Run the generated executable under `_build/native/debug/build/...` for the
example you built. If `moon run` exposes linker issues, use the build-and-execute
flow described in `platform-notes.md`.

## Windows Native

Windows examples use MSYS2 UCRT64 and the static Windows GNU `wgpu-native`
release documented in `platform-notes.md`:

```sh
moon build examples/counter/windows --target native
moon build examples/todo/windows --target native
moon build examples/markdown_editor/windows --target native
```

The counter example also has a helper script for the expected static dependency
layout:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
```

## Example Validation

Use package-level tests for shared app logic and Web builds for browser entry
points:

```sh
moon test examples/counter/app --target native
moon test examples/todo/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
