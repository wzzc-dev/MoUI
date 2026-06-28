# 2026-06-28: Markdown Session Virtual Scrolling

- **Agent**: Codex GPT-5
- **Goal**: Move Markdown Editor toward a Typora-like large-document editing
  path after large files still opened slowly and scrolling remained janky.
- **Outcome**: Success for structural package-level performance contracts;
  native interactive smoothness still needs matching-host smoke evidence.

## Summary

The session refactor was extended from "windowed rich text paint" into a true
Markdown-owned virtual viewport. The app no longer wraps the primary editor in
a generic `scroll_view`, and the rich text editor avoids whole-document work in
ordinary scroll and focused text-input polling paths.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_richtext/editor_session.mbt` | Added `MarkdownDocumentSession`, block ids/revisions, dirty ranges, cached metadata, source length, block height index, `rich_text_window`, `estimated_content_height`, and `source_offset_y`. | Keep canonical Markdown source while letting scrolling and caret mapping work by block window instead of whole document. |
| `moui_richtext/rich_text_editor.mbt` | Added `controlled_markdown_session_editor`; made Markdown session editor handle wheel input, read live `ScrollState`, render visible windows, and keep ordinary text-input state cheap. | Remove formatter-driven hot paths and prevent wheel events from invalidating layout. |
| `examples/markdown_editor/app/view_editor_surface.mbt` | Replaced `controlled_rich_text_editor(format=...)` plus outer `scroll_view` with `controlled_markdown_session_editor` sized to the viewport. | Avoid carrying a whole-document-height child through the runtime layout tree. |
| `examples/markdown_editor/app/view_chrome.mbt`, `view_inspectors.mbt`, `editor_navigation.mbt` | Routed root/status/outline/info/navigation through cached session fields and source-offset mapping. | Keep root/view updates from forcing snapshots or full rich-text documents. |
| `examples/markdown_editor/app/editor_app_cache_runtime_wbtest.mbt` | Added a regression that scroll does not reparse and marks paint dirty, not layout dirty. | Guard the performance contract that failed in practice. |
| `docs/markdown-editor.md`, `docs/text-system.md`, `docs/decisions/0001-markdown-session-virtual-scrolling.md` | Documented the session viewport and text-input hot-path rules. | Preserve the architecture choice for future agents and maintainers. |

## Key Decisions

- Use a long-lived Markdown document session as the editor engine rather than
  `String -> RichTextDocument` formatter callbacks.
- Let the Markdown editor own virtual scrolling; generic `scroll_view` remains
  for normal child views, not the primary large-document Markdown surface.
- Keep focused text-input polling cheap: full source is returned to hosts, but
  caret geometry comes from the visible block window and cached session data.
- See ADR: [0001: Markdown session virtual scrolling](../decisions/0001-markdown-session-virtual-scrolling.md).

## Discoveries

- Windowing paint alone is not enough if the editor is still inside a generic
  scroll container whose child height is the entire document.
- Including scroll offset in a generic scroll node's revision and returning
  layout dirty for wheel input makes every scroll frame pay layout costs.
- Native/Web hosts can call `focused_text_input()` for IME and context menu
  state, so text-input state construction must avoid full-document grapheme
  scans in the ordinary polling path.
- `moon fmt` on the whole `moui_richtext` package can introduce unrelated
  formatting churn in code-highlight files; prefer targeted formatting and
  review diff noise carefully.

## Validation

```sh
moon check moui_richtext examples/markdown_editor/app --target native
moon test moui_richtext --target native
moon test examples/markdown_editor/app --target native
moon test moui/views --target native
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon info
node scripts/validate-api-surface.mjs
git diff --check
```

Warnings observed were existing dependency/app warnings, not failures:
`bobzhang/mbtexcel` main-package dependency warnings and unused
Markdown Editor app fields/menu variants.

## Follow-Up

- [ ] Run a matching-host native Skia interaction smoke or profiling pass
      before claiming real scrolling smoothness.
- [ ] Continue shrinking old formatter-based API exposure when compatibility
      is no longer useful.
- [ ] Replace remaining explicit snapshot/export helpers only when their
      call sites become interactive hot paths.
