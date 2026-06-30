# Richtext / Rich Text Editor Patterns

## Table Click Mapping

- `rich_text_block_table_source_offset_at_point` must NOT use linear interpolation
  (`relative = (x - cell_x) / column_width`) for x→offset mapping — it ignores
  `cell_padding`, text alignment, and actual text width.
- Correct approach:
  - Compute `cell_x`, `column_width`, `cell_padding`, `inner_x`, `inner_width`
  - Measure `text_width = rich_text_width(cell.text, font, text_system)`
  - Apply `cell.align` (TextStart/TextCenter/TextEnd) to find `text_x`
  - Click before text → `range.start`, after text → `range.end`, between chars →
    per-grapheme midpoint hit (reuse `rich_text_run_visual_offset_at_x` pattern)
- Use `@core.TextGraphemeBoundaries::nearest_boundary` to avoid caret in surrogate
  pairs.

## Text Editing Primitives

- `moui/core/text_editing.mbt` should be the single source for: `replace_text_range`,
  `selected_text`, `delete_text_range`, `surround_text_range`,
  `is_select_all_shortcut`, `is_undo_shortcut`, `is_redo_shortcut`,
  `composition_start_index`, `composition_cursor_offset`.
- `moui_richtext` and `moui/views/text_area_control.mbt` should delegate to
  `@core.*` rather than maintaining duplicate implementations.
- MoonBit `Option::unwrap_or` evaluates the fallback eagerly — in caret/cursor
  code this can trigger expensive fallback measurement even when the primary path
  succeeds. Use `match` or lazy helpers.

## Blackbox Testing

- Pure function black-box tests for richtext: document model, source mapping,
  commands, input transforms, session transactions.
- Test at the facade level only (public symbols from `pkg.generated.mbti`).
- Don't depend on `examples/markdown_editor/app` tests for addon coverage.
- `MarkdownEditReason` does not implement `Show` — use `assert_true(txn.reason == CommandEdit)` instead of `inspect`.
- Indentation uses two-space prefix (`"  "`), not tab.