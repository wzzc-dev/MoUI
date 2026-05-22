# Examples

MoUI examples are runnable documentation. Showcase is the visual catalog and
contains the Counter and Todo interaction patterns. The WYSIWYG Markdown editor
stays separate because it demonstrates a larger editing workflow with its own
model and parser tests.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | Public `views` constructors, built-in Counter/Todo patterns, light Markdown preview, theme, presentation, renderer capability status |
| Markdown Editor | Practical editing demo | `examples/markdown_editor/app/` | Rich text editor, `mizchi/markdown` parsing, source preview |

## Web Wasm-GC

Build any Web example from the repository root, then serve the repository with a
local static server:

```sh
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
moon build examples/markdown_editor/windows --target native
```

The Markdown editor can also use the helper script for the expected static
dependency layout:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

## Example Validation

Use package-level tests for shared app logic and Web builds for browser entry
points:

```sh
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before changing platform entrypoints, include the affected host package tests and
current-platform example builds.
