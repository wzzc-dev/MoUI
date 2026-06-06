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
- `examples/markdown_editor/windows_skia/`: Windows native entrypoint using the
  Skia renderer provider.
- `examples/markdown_editor/linux_skia/`: Linux native entrypoint using the
  Skia renderer provider.
- `views/markdown_editor.mbt`: public rich text editor wrappers used by the
  example.
- `core/rich_text_*.mbt` plus `core/text_editing*.mbt`: platform-neutral rich
  text painting, geometry, selection, and editing model.

Platform packages should stay thin. Shared editor behavior belongs in the app
package or the framework package that owns the reusable capability.

The shared app runtime is installed with `Program::simple` and
`AppRuntime::new_program`. Editor input, toolbar actions, shortcuts, target
field edits, selection changes, task toggles, and scroll updates enter through
typed `MarkdownEditorMsg` values. The package still keeps a small internal
`View::component` adapter at the app boundary so the demo/test
`MarkdownEditorApp` handle can expose mutable document and target-state helpers
while the mounted runtime rebuilds from the same state cells. Ordinary app code
should treat this as a rich-editor integration detail, not the default app
shape.

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
  the current Markdown reference. The active link or image target can also be
  opened through host services from the target bar or with `Cmd+Shift+O` /
  `Ctrl+Shift+O`.
- Heading, paragraph, list, task-list, ordered-list, quote, and code-block
  commands with keyboard shortcuts. When list, task-list, or ordered-list
  commands are applied to a multi-line selection, blank separator lines stay
  blank, nested indentation stays attached to the converted lines, and ordered
  numbering advances only for non-empty selected lines at the same indentation
  level. Inside blockquotes, the same current-line or selected-line list
  commands preserve the active `> ` or `> > ` quote context and replace only
  the inner block marker, so quoted prose can become quoted bullet, task, or
  ordered lists without leaving the quote block. Current-line heading commands
  use the same layered marker replacement, so `> Title` can become
  `> ## Title` and same-level heading commands toggle back to quoted prose.
  The paragraph command follows the same layering: plain quoted paragraphs can
  still exit the quote, while quoted list items or headings become ordinary
  quoted paragraphs by removing only their inner marker. Backspace/Delete at
  the inner marker edge of quoted list, task, heading, or ordered-list content
  follows the same rule: it removes the inner marker first while keeping the
  quote prefix active. Delete at the start of ordinary heading, quote, list,
  task-list, or ordered-list markers removes the whole block marker instead of
  exposing a partial Markdown delimiter.
- Ordered lists automatically renumber after structural edits, including
  inserts before nested ordered sublists, while nested list numbering keeps its
  own starting value and the parent list resumes after the child block. The
  same renumbering pass runs through blockquote prefixes, so quoted and nested
  quoted ordered lists keep their local numbering after Enter, Backspace, and
  Delete edits.
- Task list checkboxes can be toggled from the keyboard with `Cmd+Enter` or
  `Ctrl+Enter` while the caret is inside the current task item, matching the
  quick writing flow of visual Markdown editors.
- Typora-like block editing commands can duplicate the active non-empty block
  or selected non-empty block range with `Cmd+Shift+D` or `Ctrl+Shift+D`, and
  move it across neighboring non-empty blocks with `Alt+ArrowUp` or
  `Alt+ArrowDown`, preserving blank-line separators, caret/selection position,
  and undo/redo history.
- Inline, link, and heading commands support the existing app shortcuts plus
  common Windows writing shortcuts such as `Ctrl+B`, `Ctrl+I`, `Ctrl+E`,
  `Ctrl+K`, `Ctrl+Shift+I`, `Ctrl+Shift+K`, `Ctrl+Shift+X`, and `Ctrl+1`
  through `Ctrl+6`.
- A quiet writing shell with a lightweight active-block/status strip, word/line
  counts, estimated reading time, current document title, saved/unsaved state,
  caret-aware current section, current inline format/reference feedback, and a
  minimal source toggle available from chrome or `Cmd+/`/`Ctrl+/` while keeping
  the formatted page as the primary surface.
- An optional `Nav` outline sidebar built from parsed headings. It shows the
  heading hierarchy as compact indented rows, can sit beside the formatted
  editor without opening the source inspector, and clicking a heading moves the
  caret and scrolls the editor to that block. `Cmd+Alt+O` / `Ctrl+Alt+O` toggles
  the sidebar, while `Cmd+Alt+ArrowDown` / `Ctrl+Alt+ArrowDown` and
  `Cmd+Alt+ArrowUp` / `Ctrl+Alt+ArrowUp` jump through next/previous headings
  with wraparound.
- A document-level Find/Replace bar, toggled from the chrome and opened from
  `Cmd+F`/`Ctrl+F`, with `Cmd+Alt+F`/`Ctrl+H` opening the replace-ready bar.
  Keyboard openings keep the bar visible instead of toggling it closed. The bar
  searches canonical Markdown source positions while keeping the formatted
  editor as the active surface. Matching ignores ASCII letter case while
  preserving the original source range for selection and
  replacement. Opening Find from a non-empty single-line selection seeds the
  query with that selected source text; without a usable selection, opening
  from a caret inside or just after an ASCII word seeds and selects that word.
  Typing in the query field selects the live match in the formatted editor and
  keeps that match active as the query is refined. Clearing the query or typing
  a query with no matches collapses the
  active find selection while keeping the caret at the match endpoint. The
  status readout distinguishes the ready empty-query state, no matches, and the
  active match count. `Cmd+G`/`Ctrl+G` and `Cmd+Shift+G`/`Ctrl+Shift+G` move
  through matches with wraparound, `Escape` closes the bar, then dismisses
  source/outline auxiliary panels, then collapses the active selection once no
  auxiliary UI remains, current replacement advances to the next remaining
  match with wraparound when one exists, replacement preserves the saved
  Markdown source model, and current/all replacements participate in the
  structured undo/redo history.
- Document-session state tracks the current path, saved Markdown baseline,
  dirty status, clean new-document resets, and `Save`/`Cmd+S` or `Ctrl+S`
  text-file writes when the current document has a path. For unnamed
  documents, the same `Save` command opens the save-location flow before
  writing, matching normal editor first-save behavior. `Open`/`Cmd+O` or
  `Ctrl+O` asks host file-dialog services for a Markdown file path and reads
  its text through the shared host text-file service. `Save As`/
  `Cmd+Shift+S` or `Ctrl+Shift+S` asks host file-dialog services for a
  Markdown save location, writes the canonical Markdown source through the
  host text-file service, records the selected path, and updates the saved
  baseline so the document identity follows normal editor workflow while
  platform entrypoints stay thin. New, Open, and Import clear stale
  document-session UI by closing the Find bar, clearing query/replacement text,
  and dropping previous transfer status before the new transfer result is
  reported.
- Clipboard-based Markdown Import/Export is available through the shared app's
  host-service runtime path. `Import`/`Cmd+Alt+I` or `Ctrl+Alt+I` reads
  Markdown text from the host clipboard as a clean document, while
  `Export`/`Cmd+Alt+S` or `Ctrl+Alt+S` writes the canonical Markdown source to
  the clipboard. The app exposes `MarkdownEditorApp::runtime_with_services`
  for hosts/tests that inject `HostAppServices`. The macOS and Windows native
  entrypoints pass their platform service bridges so file-dialog, text-file,
  clipboard, and target-opening transfer works in those hosts; the Web wasm-gc
  entrypoint injects `web_app_services` so browser async clipboard/file-dialog
  transfer uses the backend-owned Web host-service queue. Open target commands
  use the edited link or image target field when it is active, otherwise they
  resolve the link or image under the current selection or caret before asking
  the host to open it. Web `Open` imports the selected Markdown file's
  browser-provided `File.text()` content through the shared text-file read
  contract. When the browser exposes File System
  Access handles, Web `Save As` and subsequent `Save` write through the same
  text-file service; Linux text-file content access currently reports
  unavailable.
- The formatted surface keeps Markdown markers hidden in inactive spans, then
  temporarily reveals the active inline span's markers while the caret or
  selection is inside bold, italic, code, strikethrough, link, image, or
  autolink text.
- The active block also temporarily reveals its Markdown prefix, including
  heading markers, list and task markers, ordered-list numbers, and blockquote
  markers, while inactive blocks keep their cleaner visual presentation. Fenced
  code blocks reveal their full source, including opening and closing fences,
  so language info and fence text are edited directly in the code area.
- Setext heading handling, including Space/Enter completion for `===` or `---`
  underlines beneath paragraph text, list and quote-list continuation on Enter,
  empty heading-marker exit on Enter, including inside blockquote prefixes,
  ordered-list renumbering, Tab/Shift-Tab plus `Cmd`/`Ctrl` bracket indentation
  shortcuts for the current line or selection, inline marker pairing/skip, and
  marker-aware Backspace/Delete from block, inline, autolink, footnote, and
  reference-style marker edges.
- Blank Markdown source lines are preserved as visible editable paragraph lines,
  so pressing Enter after a heading or paragraph immediately creates a blank
  line for the caret before any further text is typed.
- Plain `Shift+Enter` inserts a Markdown hard line break inside the current
  paragraph, quote, or list item by writing the canonical two-space line break
  marker and carrying the appropriate quote or list continuation prefix to the
  next source line.
- Fenced code editing supports both backtick and tilde fences, including Enter
  completion for `~~~`/`~~~~` openers with optional language info. Code content
  preserves intentional leading and trailing blank lines, so pressing Enter
  inside a non-empty code line immediately creates a visible empty code line.
  Pressing Enter on the empty content line immediately before the closing fence
  exits the code block and places the caret on the following writing line.
  The same Enter flow works when the fence is typed inside a blockquote: the
  generated content and closing fence keep the quote prefix, code-line Enter and
  multiline paste preserve the quoted code indentation, and the empty quoted
  code line exits back to a quoted writing line.
  Applying the code-block command inside a blockquote keeps the fence inside the
  active quote context by prefixing the opening fence, content lines, and
  closing fence with the same quote marker rather than moving the code block
  out of the quote. Applying the command again inside that quoted fenced block
  unwraps it back to quoted writing lines while preserving the selection.
- Typed-space block shortcuts recognize common Markdown marker variants,
  including `+ ` bullets and `1) ` ordered-list markers, and normalize them to
  the editor's canonical Markdown source. Natural task-list marker forms such
  as `- [ ] `, `* [x] `, and `+ [ ] ` are accepted as well. Consecutive quote
  markers such as `>> ` are expanded into nested blockquote prefixes, and
  heading/list/task/ordered shortcuts typed after a blockquote prefix normalize
  in place, such as `> * ` becoming `> - `.
  Empty continuation markers exit on Enter, Backspace, or Delete one writing
  layer at a time, so `> > - ` exits the list while keeping `> > ` active,
  and an empty `> > ` line backs out to `> `.
  Multiline paste keeps the active list or quote context and increments ordered
  list numbers even inside nested blockquotes, while blank pasted separator
  lines stay blank instead of becoming empty list items. Inside blockquotes,
  those blank pasted lines keep the `> ` quote prefix without adding a nested
  list marker. Pasted nested list lines keep their own indentation and marker
  shape, so child items stay nested instead of being flattened into the active
  parent list. Backspace/Delete at block boundaries also understands nested
  blockquote prefixes, so merging `> > ` quote lines or quoted list items joins
  the writing text without leaking quote, list, task, or ordered markers into
  the paragraph body.
  Horizontal rule markers such as `--- `, `*** `, and `___ ` complete
  immediately on Space or Enter.
- Typing or pasting bare HTTP(S) URLs and email addresses autocompletes them
  into Markdown autolinks outside code blocks, including when Space or Enter
  finishes the typed target. Common trailing sentence punctuation and
  surrounding `()`, `[]`, or `{}` wrappers stay outside the generated autolink,
  and Enter keeps the current list or quote continuation active. Pasting a URL,
  email address, or image source over
  selected text turns that selection into a link or image. Pasting a complete
  Markdown link or image over selected text reuses the pasted target while
  preserving the current selected link text or image alt text. Reference-style
  Markdown links and images such as `[text][label]`, `[text]`, and
  `![alt][label]` preserve the selected visible text while carrying over the
  pasted reference label. Pasted reference definition lines such as
  `[label]: https://example.com` turn the current selection or active link into
  a reference-style link and append the definition when it is not already
  present. Pasted footnote definition lines such as `[^note]: text` preserve
  selected prose by adding a footnote reference after it, or update the current
  footnote definition when the caret is already inside a footnote reference.
  Pasting a link, image target, or reference-style Markdown reference while the
  caret is inside an existing reference updates that reference without replacing
  its visible text. Pasting a single raw HTML block such as
  `<section>Note</section>` inserts it as an isolated block, or replaces the
  current HTML block when the caret is already inside one, while inline HTML
  tags continue through the ordinary text-input path.
- Typora-like paired delimiter input for brackets, parentheses, braces, quotes,
  and backticks, including selection wrapping plus empty-pair Backspace/Delete
  cleanup. Empty inline marker pairs such as bold, code, or strikethrough
  markers also clean up from the inside or either edge with Backspace/Delete.
- Table previews with source-mapped cells, row/column insertion and deletion,
  alignment changes from the table tools or `Cmd+Shift+L/E/R/0` /
  `Ctrl+Shift+L/E/R/0`, row/column structure shortcuts on both
  `Cmd+Shift` and `Ctrl+Shift`, Tab/Shift+Tab cell navigation, Enter row
  insertion, and Enter-based table creation from pipe-delimited header rows.
  Tab from the final table cell appends a new empty row and moves into its
  first cell, so tabbing can continue table entry without reaching for a row
  command.
  Enter or an insert-row command from a header cell inserts the first data row
  after the separator line, preserving the Markdown table shape.
  Delete-row commands from a header cell clear the header cells rather than
  removing the required Markdown table header row.
  Shift+Tab from the first table cell exits to the writing line before the
  table, inserting that blank line when needed. Pressing Enter in an empty
  trailing data row exits the table onto the following writing line; if the
  table already has real data rows, the extra empty trailing row is removed.
  Row/column commands are contextual and no-op outside table cells, so creating
  a new table remains an explicit `Table` command.
  Backspace/Delete in that extra empty trailing row removes it and returns the
  caret to the previous row. Explicit pipe-wrapped headers can include empty
  placeholder cells, so
  `| Name | |` still expands into a two-column table. Pasting inside a table
  cell flattens pasted line breaks and escapes literal pipe characters so prose
  like `A | B` stays in the current cell instead of silently changing the table
  shape. Pasting tab-separated spreadsheet text into a table fills adjacent
  cells from the caret position, adding rows or columns when the pasted grid is
  larger than the current table.
  Pasting a Markdown table into an existing table follows the same structured
  cell-fill path while preserving escaped literal pipes and carrying the pasted
  separator alignment into the affected columns. Pasting tab-separated
  spreadsheet text outside an existing table creates a Markdown table block,
  using the first pasted row as the header and preserving Markdown-safe escaped
  pipes in cell text. Pasting a complete Markdown table outside an existing
  table inserts it as an isolated table block and keeps the pasted separator
  alignment row intact.
- Structured shortcut/contextual command history so Markdown transforms can be
  undone separately from raw text input.

Source preview remains available from the top chrome for inspection, but the
formatted surface is the primary user flow.

The editor shell centers a white writing page in a quiet workspace, keeping the
rich-text editor as the direct pointer target while the visual surface provides
the paper, border, and shadow. The source preview remains opt-in and opens as a
full-height side inspector so the default screen stays focused on formatted
writing.

Full file-system content import/export is implemented for the macOS and Windows
native service bridges through the shared host text-file service. Web supports
Open by reading the selected browser `File.text()` into the same text-file read
flow. Browsers with the File System Access API keep handles from
`showOpenFilePicker` or `showSaveFilePicker`, so `Save As` writes the selected
file and later `Save` can write the current document path again; browsers
without a writable handle still report Web text-file writes unavailable. Linux
remains an explicit service gap. Clipboard transfer remains the fallback
content path when a host cannot provide file content.

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
configure those flags temporarily while running Skia smoke checks. Use
`scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke`
when you need the renderer pixel smoke plus first-frame Showcase and Markdown
Editor Skia evidence on macOS.

Windows native uses the shared MSVC helper. It accepts any Windows entrypoint
package, including the Markdown Editor package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/markdown_editor/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

For matching-host Markdown Skia first-frame evidence, set
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` in the same MSVC
environment before the `windows_skia` run. The log proves only the Windows host
that produced it.

Linux native Skia uses the Linux Skia provider package and should be run on a
matching Wayland host with real Skia link flags before claiming runtime pixels:

```sh
moon build examples/markdown_editor/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

Set `MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` before the
Linux `moon run` command when collecting matching-host first-frame evidence.

## Validation

Focused checks:

```sh
moon test examples/markdown_editor/app --target native
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/markdown_editor/macos_skia --target native
moon check examples/markdown_editor/windows_skia --target native
moon check examples/markdown_editor/linux_skia --target native
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

For app-only tests that do not need real Skia linking, set
`MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` to keep the repo-local Skia binding on its
fallback-safe path and avoid downloading the real Skia release artifact.

When editor work changes public view wrappers, also run:

```sh
moon test moui/views --target native
moon info
```

When platform entrypoints change, include the affected backend tests and current
platform example build.
