# 2026-06-29: Fix Markdown Editor Table Click Caret Position

- **Agent**: Trae AI
- **Goal**: Fix imprecise caret placement when clicking table cells in the Markdown Editor. The root cause was linear interpolation of source offset by column width, ignoring cell padding, alignment, and actual rendered text width.
- **Outcome**: Success (click mapping uses measured text geometry; tests tightened)

## Summary

The table click‑to‑offset mapping function `rich_text_block_table_source_offset_at_point` used `relative = (x - cell_x) / column_width` to interpolate within `range.start .. range.end`. This ignored `cell_padding`, `TextAlign`, and actual rendered text width, causing off‑by‑1–3 character errors, especially for center‑/right‑aligned cells. The fix replaced linear interpolation with exact text measurement: compute `cell_x`, `column_width`, `inner_x`/`inner_width` with `cell_padding`, measure `text_width` via `rich_text_width`, apply `cell.align`, then use per‑grapheme midpoint hit‑testing inside text bounds, returning `range.start`/`range.end` for clicks in padding whitespace.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_richtext/rich_text_editor.mbt` | Rewrote `rich_text_block_table_source_offset_at_point` | Replaced linear interpolation with text‑measurement‑based offset mapping |
| `moui_richtext/rich_text_editor.mbt` | Added `base_font` and `text_system` parameters to the function | Needed for actual text width measurement |
| `moui_richtext/rich_text_editor.mbt` | Updated call site in `rich_text_document_source_offset_at_point` | Pass through `base_font` and `text_system` |
| `examples/markdown_editor/app/editor_snapshot_wbtest.mbt` | Tightened table click test assertions | Narrow caret range from `38..41` to specific grapheme boundary |

## Key Decisions

- Reuse existing helpers (`rich_text_block_font`, `rich_text_width`,
  `TextGraphemeBoundaries::nearest_boundary`) rather than introducing new
  measurement code.
- Keep `rich_text_run_visual_offset_at_x`'s per‑grapheme midpoint hit‑testing
  pattern for character‑level precision.
- Header cells use `weight=700`, body cells `weight=400` — must stay synchronized
  with `append_rich_text_block_table`.
- Linear interpolation retained as fallback when `column_width <= 0.0` or
  `text_width <= 0.0` (empty cells).
- No changes to the rendering path — fix is entirely in the hit‑test mapping.

## Discoveries

- The existing test `"markdown editor click maps table preview cells to markdown
  source"` used a generous `caret >= 38 && caret <= 41` assertion, hiding the
  off‑by‑1 deviation for a 3‑character "yes" cell.
- Multiple reusable helpers already existed: `rich_text_block_font`,
  `rich_text_width`, `TextGraphemeBoundaries` — the table hit‑test simply wasn't
  using them.
- Right‑aligned cells (`| ---: |`) are the worst case for linear interpolation:
  the cell center falls in text‑right whitespace, not over text.

## Validation

```sh
moon check
moon test -p moui_richtext
moon test -p markdown_editor
node scripts/validate-api-surface.mjs
node scripts/validate-maintenance-baseline.mjs
wait
```

## Follow-Up

- [ ] All cell alignment modes (left, center, right) and empty cells are covered by tests.