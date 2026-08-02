# ADR 0001-0002: Editor and Rich Text (merged)

> 原编号保留为小节锚点: 0001-markdown-session-virtual-scrolling,0002-moui-richtext-optimization

---

## 0001: Markdown Session Virtual Scrolling

- **Date**: 2026-06-28
- **Status**: Accepted
- **Deciders**: Agent-assisted
- **Related**: `docs/markdown-editor.md`, `docs/text-system.md`

### Context

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

### Decision

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

### Options Considered

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

### Rationale

The session-owned virtual viewport is the only option that removes the known
hot paths: whole-document Markdown formatting during paint, whole-document
height walks during scroll, layout invalidation on ordinary wheel input, and
full-document grapheme scans during host focus polling.

The trade-off is a larger `moui_richtext` API and a stricter separation between
compatibility helpers and the app's main Markdown editing path.

### Consequences

- Markdown Editor should route view, scroll, selection, find/replace, outline,
  and source mode through `MarkdownDocumentSession`.
- App code must not call `session.snapshot()`, `snapshot.rich_text`, or
  `rich_text_document_height()` from root/render/paint/scroll paths.
- Generic `scroll_view` remains valid for normal children, but the Markdown
  editor surface owns its own virtual scrolling.
- Native smoothness and IME behavior still need matching-host smoke evidence;
  package tests only prove the structural performance contract.

### Agent Notes

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

### References

- `moui_richtext/editor_session.mbt`
- `moui_richtext/rich_text_editor.mbt`
- `examples/markdown_editor/app/view_editor_surface.mbt`
- `examples/markdown_editor/app/editor_app_cache_runtime_wbtest.mbt`

---

## 0002: MouiRichtext Optimization — Primitives, API Surface, Geometry, Tests

- **Date**: 2026-06-29
- **Status**: Accepted
- **Deciders**: Agent-assisted (Trae AI)
- **Related**: `docs/moui-app-package-boundary.md`, `docs/text-system.md`, `docs/markdown-editor.md`

### Context

The `moui_richtext` addon grew organically and accumulated three structural problems:

1. **Duplicate editing primitives**: Generic text operations (`replace_text_range`,
   `selected_text`, `is_*_shortcut`, `composition_*`, `active_text_selection`,
   `clamp_int` helpers) are independently reimplemented in `moui_richtext/`,
   `moui/views/text_area_control.mbt`, and `moui/core/text_editing.mbt`. This
   creates drift risk for caret, selection, and undo/redo behavior across the
   plain-text and rich-text code paths.

2. **Oversized public API**: `moui_richtext` exposes 606 public symbols across
   32 files. The Markdown Editor app actually imports only 13 of those. Internal
   helpers in `editor_selection.mbt` (45 pub), `input_paste.mbt` (41 pub),
   `commands_blocks.mbt` (41 pub), and `editor_source_mapping.mbt` (55 pub) are
   all public, preventing internal refactoring without compatibility constraints.

3. **Rich text geometry bypasses `TextSystem`**: Caret rect, selection rects, and
   hit-testing in richtext use font-metric-based estimation rather than
   `TextSystem::layout_paragraph` → `TextParagraphLayoutResult`,
   which `text_area`/`text_field` already use. This creates a second geometry
   source that can drift across renderers and degrades on fallback TextSystem.

Additionally, `docs/moui-app-package-boundary.md` had stale text claiming
richtext is owned by `moui/views`, but the code and reality say it's a
`moui_richtext` addon.

### Decision

Execute a 5-workflow plan to bring the richtext subsystem to a maintainable,
contract-stable state:

### Workflow 1: Primitives → `moui/core`

Move generic editing primitives from `moui_richtext` and `moui/views/text_area_control.mbt`
into `moui/core/text_editing.mbt`:
- `replace_text_range`, `selected_text`, `delete_text_range`, `surround_text_range`
- `is_select_all_shortcut`, `is_undo_shortcut`, `is_redo_shortcut`
- `composition_start_index`, `composition_cursor_offset`

Duplicate helpers in `moui_richtext` and `moui/views` are replaced with `@core.*` calls.

### Workflow 2: API Surface Reduction

Reduce `moui_richtext` public API from ~606 to ~30 symbols:
- Keep public: `RichTextDocument`, `RichTextBlock`, `RichTextRun`, `RichTextDecoration`,
  `RichTextInputTransform`, `RichTextSourceRange`, `MarkdownDocumentSession`,
  `MarkdownEditTransaction`, `MarkdownEditReason`, `MarkdownEditorSelection`,
  `MarkdownEditorCommand`, `MarkdownEditorHistoryEntry`, 4 facade functions,
  and 5 app-used geometry/query functions.
- Change to private: all internal helpers in `editor_selection.mbt`,
  `editor_source_mapping.mbt`, `input_*.mbt`, `commands_*.mbt`, and
  `markdown_model*.mbt`.

### Workflow 3: Geometry Reuse

Replace richtext's custom geometry estimation with `TextSystem::layout_paragraph`:
- Each `RichTextBlock` calls `text_system.layout_paragraph(TextLayoutInput::new(...))`
- Caret rect → `paragraph_result.caret_rect_at(offset)`
- Selection → `paragraph_result.selection_rects(range)`
- Hit test → `paragraph_result.hit_test(point)`
- Table cells use `layout_paragraph` for cell text; table-level geometry stays custom.
- Retain estimation fallback when `paragraph_layout_available = false`.

### Workflow 4: Blackbox Tests

Add contract-level blackbox tests (82+ new test cases):
- `rich_text_document_test.mbt` — document model invariants
- `editor_source_mapping_test.mbt` — offset round-trip consistency
- `editor_commands_test.mbt` — command wrap/unwrap symmetry
- `editor_input_transforms_test.mbt` — input transform chain
- `editor_session_test.mbt` (extended) — transaction immutability

### Workflow 5: Documentation Fix

Fix `docs/moui-app-package-boundary.md` to correctly state richtext is a
`moui_richtext` addon, not owned by `moui/views`. Sync `AGENTS.md` and
related docs.

### Options Considered

### Option A: Full Rewrite

- Pros: Clean slate, no legacy API to maintain.
- Cons: Massive breaking change, blocks all other work for weeks,
  risk of regressions in Markdown Editor app.

### Option B: Gradual Optimization (Chosen)

- Pros: Each workflow independently verifiable, no long blocking period,
  progressive improvement, 80% of value with 20% of effort.
- Cons: Intermediate states have mixed old/new API; some dead code stays
  until all consumers migrate.

### Option C: Only Add Tests, No Refactoring

- Pros: Lowest risk.
- Cons: Does not fix the duplicate-primitive drift risk or the geometry
  source split; keeps 606 public symbols as permanent maintenance burden.

### Rationale

The gradual optimization minimizes risk while addressing all three structural
problems. The 5-workflow sequence is designed so each step is independently
verifiable:

- Workflow 1 & 2 can partially parallelize (different files).
- Workflow 3 depends on Workflow 2 (geometry functions are part of the stable
  public facade).
- Workflow 4 depends on Workflow 2 (blackbox tests test the stable facade).
- Workflow 5 is independent but best done last to avoid rework.

Breaking changes are acceptable without a deprecation period — the only consumer
(`examples/markdown_editor/app`) already imports only the 13 symbols that will
remain public.

### Consequences

- `moui/core/text_editing.mbt` becomes the single source of truth for generic
  editing primitives.
- `moui_richtext` public API shrinks from ~606 to ~30 symbols — future refactoring
  of internals does not trigger compatibility constraints.
- Richtext caret/selection/hit-test geometry aligns with `text_area`/`text_field`,
  eliminating cross-renderer drift.
- Addon has proper contract-level tests, not just app-level indirect coverage.
- Documentation accurately reflects the addon ownership boundary.
- Formatter mode (`rich_text_editor` + `RichTextFormatter`) is not removed in
  this plan; deprecation deferred to a future ADR.

### Agent Notes

- **Session context**: The `.trae/documents/moui-text-richtext-optimization-plan.md`
  document was migrated as an ADR into the project's documentation system.
- **Agent model**: Trae AI
- **Key prompt or instruction**: "把 .trae 下面的文档统一维护起来"
- **Validation**: Workflow 4 (blackbox tests) was completed and verified — see
  `docs/ai-sessions/2026-06-29-moui-richtext-blackbox-tests.md`.

### References

- `moui_richtext/` — current 606-public-symbol surface
- `moui/core/text_editing.mbt` — target for migrated primitives
- `moui/views/text_area_control.mbt` — duplicate cleanup target
- `docs/moui-app-package-boundary.md` — stale ownership text
- `.trae/documents/moui-text-richtext-optimization-plan.md` — source planning doc

