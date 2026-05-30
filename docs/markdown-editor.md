# Markdown Editor

The Markdown Editor is MoUI's practical editing demo. It keeps Markdown source
as the saved value while presenting a formatted editor surface as the primary
screen. The example is intentionally separate from Showcase because it exercises
larger document state, rich text input, source-to-visual mapping, keyboard and
contextual commands, and editing workflows.

## Package Shape

- `examples/markdown_editor/app/`: shared app state plus package-local editor
  model, source/visual mapping, command behavior, input transforms, Markdown
  parsing adapter, rich text document mapping, and focused white-box tests.
- `examples/markdown_editor/web_wasm/`: Web wasm-gc entrypoint.
- `examples/markdown_editor/macos/`: macOS native entrypoint.
- `examples/markdown_editor/macos_skia/`: macOS native entrypoint using the
  Skia renderer provider.
- `examples/markdown_editor/windows/`: Windows native entrypoint.
- `views/markdown_editor.mbt`: public rich text editor wrappers used by the
  example.
- `core/rich_text_*.mbt` plus `core/text_editing*.mbt`: platform-neutral rich
  text painting, geometry, selection, and editing model.

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
  Typed bold markers support both `**` and `__` input forms; selected text can
  be wrapped with `*` or `_` italic markers. Reapplying an inline formatting
  command inside the current formatted span removes that span's Markdown
  markers, matching the expected visual-editing toggle behavior.
- Contextual editing for link URLs, autolink targets, image sources, reference
  definitions, footnotes, raw HTML blocks, and tables. Link and image target
  controls activate from either selected visible text or the caret inside the
  formatted span, and reapplying the link/image command at that caret unwraps
  the current Markdown reference.
- Heading, paragraph, list, task-list, ordered-list, quote, and code-block
  commands with keyboard shortcuts.
- Inline, link, and heading commands support the existing app shortcuts plus
  common Windows writing shortcuts such as `Ctrl+B`, `Ctrl+I`, `Ctrl+E`,
  `Ctrl+K`, `Ctrl+Shift+X`, and `Ctrl+1` through `Ctrl+6`.
- A quiet writing shell with a lightweight active-block/status strip, word/line
  counts, estimated reading time, current inline format/reference feedback, and
  a minimal source toggle while keeping the formatted page as the primary
  surface.
- The formatted surface keeps Markdown markers hidden in inactive spans, then
  temporarily reveals the active inline span's markers while the caret or
  selection is inside bold, italic, code, strikethrough, link, image, or
  autolink text.
- The active block also temporarily reveals its Markdown prefix, including
  heading markers, list and task markers, ordered-list numbers, and blockquote
  markers, while inactive blocks keep their cleaner visual presentation.
- Setext heading handling, list and quote-list continuation on Enter,
  ordered-list renumbering, Tab and Shift-Tab indentation, inline marker
  pairing/skip, and marker-aware Backspace.
- Fenced code editing supports both backtick and tilde fences, including Enter
  completion for `~~~`/`~~~~` openers with optional language info.
- Typed-space block shortcuts recognize common Markdown marker variants,
  including `+ ` bullets and `1) ` ordered-list markers, and normalize them to
  the editor's canonical Markdown source. Natural task-list marker forms such
  as `- [ ] `, `* [x] `, and `+ [ ] ` are accepted as well. Consecutive quote
  markers such as `>> ` are expanded into nested blockquote prefixes.
  Horizontal rule markers such as `--- `, `*** `, and `___ ` complete
  immediately on Space or Enter.
- Typing or pasting bare HTTP(S) URLs and email addresses autocompletes them
  into Markdown autolinks outside code blocks, while common trailing sentence
  punctuation and surrounding `()`, `[]`, or `{}` wrappers stay outside the
  generated autolink. Pasting a URL, email address, or image source over
  selected text turns that selection into a link or image.
- Typora-like paired delimiter input for brackets, parentheses, braces, quotes,
  and backticks, including selection wrapping.
- Table previews with source-mapped cells, row/column insertion and deletion,
  alignment changes, Tab cell navigation, and Enter row insertion.
- Structured shortcut/contextual command history so Markdown transforms can be
  undone separately from raw text input.

Source preview remains available from the top chrome for inspection, but the
formatted surface is the primary user flow.

The editor shell centers a white writing page in a quiet workspace, keeping the
rich-text editor as the direct pointer target while the visual surface provides
the paper, border, and shadow. The source preview remains opt-in and opens as a
full-height side inspector so the default screen stays focused on formatted
writing.

On macOS, the editor page sizes itself from the formatted rich-text document and
uses ScrollSpec wheel handling so longer documents scroll inside the clean
writing viewport instead of clipping at a fixed editor height.

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

macOS native with the Skia renderer:

```sh
moon build examples/markdown_editor/macos_skia --target native
./_build/native/debug/build/examples/markdown_editor/macos_skia/macos_skia.exe
```

The Skia entrypoint requires the same real native Skia link setup used by
`examples/showcase/macos_skia`; `scripts/macos-skia-renderer-smoke.sh` can
configure those flags temporarily while running Skia smoke checks.

Windows native:

```powershell
moon build examples/markdown_editor/windows --target native
.\_build\native\debug\build\examples\markdown_editor\windows\windows.exe
```

The Windows helper configures MSYS2 and lets `wgpu_mbt` manage the
default `wgpu-native` prebuild; pass `-WgpuNativeRoot` only when using a
preseeded local release root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\markdown_editor_windows_static.ps1 -BuildOnly
```

## Validation

Focused checks:

```sh
moon test examples/markdown_editor/app --target native
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/markdown_editor/macos_skia --target native
```

When editor work changes public view wrappers, also run:

```sh
moon test moui/views --target native
moon info
```

When platform entrypoints change, include the affected backend tests and current
platform example build.
