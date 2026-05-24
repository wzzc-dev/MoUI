# Markdown Editor

The Markdown Editor is MoUI's practical editing demo. It keeps Markdown source
as the saved value while presenting a formatted editor surface as the primary
screen. The example is intentionally separate from Showcase because it exercises
larger document state, rich text input, source-to-visual mapping, toolbar
commands, and editing workflows.

## Package Shape

- `examples/markdown_editor/app/`: shared editor model, Markdown parsing adapter,
  rich text document mapping, command behavior, and app tests.
- `examples/markdown_editor/web_wasm/`: Web wasm-gc entrypoint.
- `examples/markdown_editor/macos/`: macOS native entrypoint.
- `examples/markdown_editor/windows/`: Windows native entrypoint.
- `views/markdown_editor.mbt`: public rich text editor wrappers used by the
  example.
- `core/rich_text_editor.mbt`: platform-neutral rich text editing model.

Platform packages should stay thin. Shared editor behavior belongs in the app
package or the framework package that owns the reusable capability.

## Editing Model

The editor stores canonical Markdown source, then parses it into a
`MarkdownEditorSnapshot` with blocks, source/content ranges, rich text output,
line counts, word counts, and document title metadata.

Core rich text blocks can carry source and content ranges. This lets the editor:

- render formatted visual text while hiding Markdown delimiters;
- map pointer hit testing from formatted positions back into Markdown source
  offsets;
- paint selections over visible formatted ranges without highlighting hidden
  markers;
- request IME and caret geometry from the formatted visual position;
- copy and cut formatted visual text without Markdown delimiters.

## Current Behavior

The editor supports formatted editing for common block and inline structures:

- Inline commands for bold, italic, code, strikethrough, links, and images.
- Contextual editing for link URLs, image sources, reference definitions,
  footnotes, raw HTML blocks, and tables.
- Heading, paragraph, list, task-list, ordered-list, quote, and code-block
  commands with keyboard shortcuts.
- Setext heading handling, list continuation on Enter, ordered-list
  renumbering, Tab and Shift-Tab indentation, and marker-aware Backspace.
- Table previews with source-mapped cells, row/column insertion and deletion,
  alignment changes, Tab cell navigation, and Enter row insertion.
- Structured toolbar/contextual command history so Markdown transforms can be
  undone separately from raw text input.

Source preview remains available from the toolbar for inspection, but the
formatted surface is the primary user flow.

## Platform Commands

Web wasm-gc:

```sh
moon build examples/markdown_editor/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/markdown_editor/web_wasm/index.html
```

macOS native:

```sh
moon build examples/markdown_editor/macos --target native
./_build/native/debug/build/examples/markdown_editor/macos/macos.exe
```

Windows native:

```powershell
moon build examples/markdown_editor/windows --target native
.\_build\native\debug\build\examples\markdown_editor\windows\windows.exe
```

The Windows static helper documents the expected `wgpu-native` layout:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

## Validation

Focused checks:

```sh
moon test examples/markdown_editor/app --target native
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

When editor work changes public view wrappers, also run:

```sh
moon test views --target native
moon info
```

When platform entrypoints change, include the affected backend tests and current
platform example build.
