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

The historical in-repo Markdown Editor example was removed when MoMark
graduated into its own repository. The live app, its app-level editing model,
and platform commands now ship in this workspace through the `examples/momark`
submodule; see the MoMark repository for its standalone documentation.
