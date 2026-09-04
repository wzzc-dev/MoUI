# Markdown Editor

<div align="center">
  <img src="../../resource/screenshots/markdown_editor.png" width="600px" alt="Markdown Editor screenshot"/>
</div>

Markdown Editor is a Typora-style WYSIWYG editing prototype. A single typed
Markdown application model is shared between source and visual editing modes,
plus a toolbar, format palette, find/replace, outline, file sidebar, toasts,
and HTML export. It is the largest end-to-end MoUI example and the primary
proof of the `@moui_richtext` markdown editing surface.

## Package Shape

- `app/` — shared app logic. `MarkdownEditorApp` owns the document session
  (`@moui_richtext.MarkdownDocumentSession`), selection, link/image/
  footnote/html targets, outline visibility, focus/typewriter/zen modes,
  toasts, and the action command catalog. The bulk of the code is split across
  `editor_*.mbt` (commands, navigation, settings, snapshot, target-sync),
  `view_*.mbt` (chrome, editor surface, folding, format bubble, inspectors,
  toolbar, toasts), and a large `*_wbtest.mbt` runtime suite.
- `composition/` — light runtime assembly shared by retained entrypoints.
- `web_wasm/`, `macos_skia/`, `macos_wgpu/`, `windows_skia/`, `windows_wgpu/`,
  `linux_skia/`, `linux_wgpu/` — thin platform entrypoints that run the same
  app. Each native entrypoint takes an optional `<document.md>` argument and
  opens it through the same recent-file open path as the menu.
- `docs/` — long-form editor walkthrough copied under `docs/` for the website.

## Dependencies

```toml
import {
  "wzzc-dev/moui@0.1.12",
  "wzzc-dev/moui_richtext@0.1.10",
  "wzzc-dev/window@0.5.4-0.1.7",
  "wzzc-dev/moui_skia_renderer@0.1.11",
  "wzzc-dev/moui_web_renderer@0.1.10",
  "wzzc-dev/moui_wgpu_renderer@0.1.10",
}
```

`wzzc-dev/window` is resolved from mooncakes.io by default. To edit window
source locally, use `sh scripts/window-dev-mode.sh on`, then turn it off
again before committing.

## Running

### Commands

```sh
# Web (wasm-gc)
moon build examples/markdown_editor/web_wasm --target wasm-gc

# macOS Skia
moon run examples/markdown_editor/macos_skia --target native

# macOS WGPU
moon run examples/markdown_editor/macos_wgpu --target native

# Windows Skia (MSVC toolchain; MOUI_FIRST_FRAME_EXIT=1 smoke-runs the first frame)
moon run examples/markdown_editor/windows_skia --target native

# Windows WGPU
moon run examples/markdown_editor/windows_wgpu --target native

# Linux Skia (MOUI_FIRST_FRAME_EXIT=1 smoke-runs the first frame)
moon run examples/markdown_editor/linux_skia --target native

# Linux WGPU
moon run examples/markdown_editor/linux_wgpu --target native

```

## Tests

```sh
moon test examples/markdown_editor/app --target native
```

The app package ships an extensive runtime whitebox suite covering keyboard
input, block/inline targets, table paste, folding, find/replace, clipboard,
file sidebar, contextual bubbles, command-click, and snapshot formatting.

## Platform Coverage

| Target               | Entrypoint            | Status |
| -------------------- | --------------------- | ------ |
| Web wasm-gc          | `web_wasm`            | Wired  |
| macOS Skia           | `macos_skia`          | Wired  |
| macOS WGPU           | `macos_wgpu`          | Wired  |
| Windows Skia         | `windows_skia`        | Wired  |
| Windows WGPU         | `windows_wgpu`        | Wired  |
| Linux Skia           | `linux_skia`          | Wired  |
| Linux WGPU           | `linux_wgpu`          | Wired  |

See [docs/markdown-editor.md](../../docs/markdown-editor.md) for the editing
model narrative.
