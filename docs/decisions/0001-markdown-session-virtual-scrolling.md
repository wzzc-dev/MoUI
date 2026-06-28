# 0001: Markdown Session Virtual Scrolling

- **Date**: 2026-06-28
- **Status**: Accepted
- **Deciders**: Agent-assisted
- **Related**: `docs/markdown-editor.md`, `docs/text-system.md`

## Context

Markdown Editor targets a Typora-like writing experience: canonical Markdown
source must round-trip, formatted editing should stay live, and large documents
must open and scroll without reparsing or rebuilding the whole visual document
on every frame.

The earlier formatter-driven path exposed `RichTextFormatter = (String) ->
RichTextDocument` as the core editor API. That made the app easy to wire, but
it encouraged root/view/paint paths to rebuild a complete `RichTextDocument`
from the source string. A later windowed rendering step reduced paint work, but
the primary editor was still wrapped in a generic `scroll_view` with a child
whose height represented the whole document. Wheel input therefore invalidated
layout and kept part of the scrolling path tied to whole-document state.

Text input added another constraint: native and Web hosts can query focused
text input state for IME and context-menu sync. That query path must return the
full canonical source, but it must not compute full-document grapheme
boundaries or rich-text layout just to answer the current caret rectangle.

## Decision

Markdown editing uses a long-lived `MarkdownDocumentSession` as the primary
document engine. The session owns canonical source, parsed block metadata,
stable block ids, cached outline/status fields, source length, and a block
height index.

The main editor API is session driven:

- transactions update the session rather than calling a formatter callback;
- `rich_text_window` builds rich text only for visible blocks plus overscan;
- `estimated_content_height` and `source_offset_y` read the cached height
  index;
- the Markdown session editor handles wheel input directly, updates the shared
  `ScrollState`, and marks paint dirty instead of layout dirty;
- focused text input state uses the visible block window for caret geometry
  and avoids whole-document grapheme scans in the ordinary polling path.

`MarkdownEditorSnapshot` and formatter-based rich text editors remain
compatibility/test/export helpers, but they are not the Markdown Editor app's
main render or scroll path.

## Options Considered

### Option A: Keep Formatter Editor And Optimize Internals

- Pros: Smallest API change; preserves existing editor wiring.
- Cons: The formatter signature keeps whole-source to whole-document rendering
  as the mental model. It cannot express stable block ids, dirty windows, or
  cached document metadata cleanly.

### Option B: Use Generic `scroll_view` With A Windowed Child

- Pros: Reuses existing scroll container behavior.
- Cons: The child still has whole-document height, and wheel events in the
  generic scroll container mark layout dirty. This makes scrolling pay layout
  costs even if rich text painting is windowed.

### Option C: Session-Owned Virtual Viewport

- Pros: Aligns with mature Markdown editors: source is canonical, blocks are
  the render/edit unit, scrolling changes only visible range, and caret/IME
  geometry comes from the same session mapping.
- Cons: Breaks the old public API as the primary path and requires more
  session metadata to stay correct.

## Rationale

The session-owned virtual viewport is the only option that removes the known
hot paths: whole-document Markdown formatting during paint, whole-document
height walks during scroll, layout invalidation on ordinary wheel input, and
full-document grapheme scans during host focus polling.

The trade-off is a larger `moui_richtext` API and a stricter separation between
compatibility helpers and the app's main Markdown editing path.

## Consequences

- Markdown Editor should route view, scroll, selection, find/replace, outline,
  and source mode through `MarkdownDocumentSession`.
- App code must not call `session.snapshot()`, `snapshot.rich_text`, or
  `rich_text_document_height()` from root/render/paint/scroll paths.
- Generic `scroll_view` remains valid for normal children, but the Markdown
  editor surface owns its own virtual scrolling.
- Native smoothness and IME behavior still need matching-host smoke evidence;
  package tests only prove the structural performance contract.

## Agent Notes

- **Session context**: Large Markdown files still opened slowly and scrolled
  poorly after an earlier session refactor.
- **Agent model**: Codex GPT-5.
- **Key prompt or instruction**: "目标是 Typora 级体验" and "现在打开大文件还是慢，滚动还是卡".
- **Validation**:

  ```sh
  moon test moui_richtext --target native
  moon test examples/markdown_editor/app --target native
  moon test moui/views --target native
  moon build examples/markdown_editor/web_wasm --target wasm-gc
  moon info
  node scripts/validate-api-surface.mjs
  git diff --check
  ```

## References

- `moui_richtext/editor_session.mbt`
- `moui_richtext/rich_text_editor.mbt`
- `examples/markdown_editor/app/view_editor_surface.mbt`
- `examples/markdown_editor/app/editor_app_cache_runtime_wbtest.mbt`
