# Examples

MoUI examples are runnable documentation. Showcase is the visual catalog and
contains the Counter and Todo interaction patterns. The WYSIWYG Markdown editor
stays separate because it demonstrates a larger editing workflow with its own
model and parser tests.

| Example | Purpose | Shared app package | Main coverage |
| --- | --- | --- | --- |
| Showcase | Full view catalog and reusable example index | `examples/showcase/app/` | Public `views` constructors, built-in Counter/Todo patterns, light Markdown preview, theme, presentation, renderer capability status |
| Markdown Editor | Typora-style editing prototype | `examples/markdown_editor/app/` | Editor snapshot core, `mizchi/markdown` parsing, source-range mapping, rich text editor, source preview |

The Markdown editor keeps Markdown source as the saved value, but its shared app
package now has an explicit editor core. `MarkdownEditorSnapshot` parses source
into blocks with source/content ranges, rich text output, line and word counts,
and the current document title. Core rich text blocks can carry source/content
ranges so the focused editor and IME request use the formatted visual position
for hidden Markdown block and inline markers, and pointer hit-testing maps
formatted visual positions back into Markdown source offsets. Mapped selection
painting now highlights formatted ranges while leaving hidden markers out of the
visual selection, including pointer drag selections mapped back to Markdown source
ranges. Toolbar inline commands and keyboard shortcuts toggle the tracked
selection for bold, italic, code, strikethrough, link, and image marks, wrapping
plain selections and unwrapping matching hidden marker pairs. Link and image
commands can also update the saved URL/source target while preserving the
selected visible text or alt text; the example app exposes those targets through
a contextual editing bar that switches between link URL editing, image source
editing, and plain-selection creation actions based on the current selection.
The contextual bar also reports the active block kind, and a paragraph command
strips heading/list/quote markers from the current or selected source lines.
Heading, list, task, ordered-list, quote, and code-block commands also have
keyboard shortcuts; heading commands transform the current source line, and
paragraph, list, task, ordered-list, and quote commands transform either the
current line or all selected source lines. The code block command wraps the
current line or selected source lines in fences, and unwraps the containing
fenced block when the caret is already inside one. Task-list visual checkbox
prefixes are clickable and toggle
the saved `- [ ]` / `- [x]` marker in the canonical source. The next line in
bullet, task, ordered-list, and quote blocks automatically continues the current
marker on Enter, while pressing Enter on an empty marker line exits that block.
The Markdown editor accepts Tab as text-editor input so Tab indents the current
or selected source lines and Shift-Tab outdents them instead of moving focus
away. Backspace at the visual start of formatted heading, list, task,
ordered-list, quote, bold, italic, or code content removes the hidden Markdown
marker pair/prefix; Backspace at the start of a plain visual block merges it
with the previous block and strips hidden block markers into paragraph text. Copy
and cut export the formatted visual text without hidden Markdown delimiters,
while multiline paste continues bullet, task, quote, ordered-list, and code-block
context. Toolbar and contextual target-editing commands keep their own undo/redo
history so structured Markdown transforms can be reverted separately from raw
text input. The next Typora milestones are upgrading the contextual target
editing bar into a true inline/floating affordance and more complete block-mode
interactions.

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
