# 0002: MouiRichtext Optimization — Primitives, API Surface, Geometry, Tests

- **Date**: 2026-06-29
- **Status**: Accepted
- **Deciders**: Agent-assisted (Trae AI)
- **Related**: `docs/moui-app-package-boundary.md`, `docs/text-system.md`, `docs/markdown-editor.md`

## Context

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

## Decision

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

## Options Considered

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

## Rationale

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

## Consequences

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

## Agent Notes

- **Session context**: The `.trae/documents/moui-text-richtext-optimization-plan.md`
  document was migrated as an ADR into the project's documentation system.
- **Agent model**: Trae AI
- **Key prompt or instruction**: "把 .trae 下面的文档统一维护起来"
- **Validation**: Workflow 4 (blackbox tests) was completed and verified — see
  `docs/ai-sessions/2026-06-29-moui-richtext-blackbox-tests.md`.

## References

- `moui_richtext/` — current 606-public-symbol surface
- `moui/core/text_editing.mbt` — target for migrated primitives
- `moui/views/text_area_control.mbt` — duplicate cleanup target
- `docs/moui-app-package-boundary.md` — stale ownership text
- `.trae/documents/moui-text-richtext-optimization-plan.md` — source planning doc