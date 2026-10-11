# Markdown Editor

The Typora-style WYSIWYG Markdown editor (MoMark) lives in its own repository,
[wzzc-dev/MoMark](https://github.com/wzzc-dev/MoMark), and is vendored into this
workspace as the `examples/momark` Git submodule. It builds on the published
`wzzc-dev/moui` and `wzzc-dev/moui_richtext` packages, so the editing model,
session rendering, and platform entrypoints are documented in the MoMark
repository README and docs.

`examples/momark` is a `moon.work` member, so `moon check examples/momark` builds
the app against this checkout instead of the published packages. The submodule
pins its own upstream commit; bump it from the MoMark repository with
`git submodule update --remote examples/momark`.

This repository keeps the framework-side pieces MoMark consumes:

- `moui_richtext/facade.mbt`: public rich text editor wrappers (`markdown_editor`,
  `controlled_markdown_session_editor`).
- `moui_richtext/rich_text_document.mbt` plus `moui_richtext/rich_text_editor.mbt`:
  rich text document model, painting, geometry, selection, and editing logic.
- `moui/core/text_editing.mbt` plus `moui/core/text_layout.mbt`: platform-neutral
  text editing primitives, `TextSystem`, and paragraph layout contract shared by
  plain text controls and the rich text addon.

## Shared Markdown chrome (`moui_markdown`)

The engine is paired with a host-neutral chrome addon, `wzzc-dev/moui_markdown`.
It lifts the parts of MoMark's app layer that are not tied to that app's model
or message type, so any MoUI Markdown surface — including MoUI Studio's `.md`
panel — can reuse the same behavior:

- **Find/replace**: case-sensitive/whole-word/regex matching, caret-word query
  seeding, selection-aware previous/next/active index calculation, single-range
  and replace-all edits, and status labels.
- **Outline**: fold filtering, labels, indent geometry, active-heading
  tracking, and reading-time labels.
- **Format palette**: the quick-format catalog, its query filter, and the
  mapping from palette action ids to `MarkdownEditorCommand`s.
- **Document info**: character/heading/paragraph/list/task/quote/code/table/
  link/image/footnote tallies derived from source + blocks, a session, or a
  snapshot.
- **HTML export**: a standalone static HTML document plus block/inline
  rendering and escaping helpers.
- **Msg-generic chrome views**: outline panel, find/replace bar, format
  palette, and document-info panel. Every view takes theme, copy, and callback
  parameters, so it instantiates for MoMark, Studio, or a third-party host
  without depending on an app package.

The layering is deliberate: `moui_richtext` stays generic to rich text, while
`moui_markdown` owns the Markdown-specific chrome and pure helpers on top of
it. Both build for native and `wasm-gc`; consumers pin them together.

The historical in-repo Markdown Editor example was removed when MoMark
graduated into its own repository. The live app, its app-level editing model,
and platform commands now ship in this workspace through the `examples/momark`
submodule; see the MoMark repository for its standalone documentation.
