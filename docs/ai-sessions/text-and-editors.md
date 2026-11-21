# Text system, rich text and editors (2026-06 → 2026-10)

Durable summary of the Markdown/rich-text/editor sessions. Canonical architecture lives in `docs/text-system.md`, `docs/markdown-editor.md` and ADR 0001; this page keeps the performance contracts and the traps.

## 2026-06-28 — Markdown session virtual scrolling

Outcome: structural package-level performance contracts landed; native interactive smoothness still needs matching-host smoke evidence.

- Canonical-Markdown-source editing moved from `String -> RichTextDocument` formatter callbacks to a long-lived `MarkdownDocumentSession` (block ids/revisions, dirty ranges, block height index, `rich_text_window`, `estimated_content_height`, `source_offset_y`).
- The Markdown editor owns virtual scrolling; the generic `scroll_view` is no longer the primary large-document surface. Wheel input must not invalidate layout.
- `controlled_markdown_session_editor` handles wheel, reads live `ScrollState`, renders only the visible window, and keeps ordinary text-input polling cheap because native/Web hosts call `focused_text_input()` for IME/context menu. ADR 0001.

## 2026-06-28 — scroll cache and caret latency

Outcome: package-level cache/caret hot-path regressions fixed; final native interaction smoothness still needs matching-host manual smoke evidence.

- Runtime cached-layer admission became frame-scoped: previous/current visible sets plus warmup admission; warm only after 3 consecutive visible frames; transient layers stay direct-draw. `cached_layer_count` follows the current frame, not accumulated scroll history. Skia keeps same-size cached pixels reusable on origin-only moves; admission records bounded (512) as a safety guard, not as the main mechanism.
- Rich text visible overscan reduced to `min(320, viewport_height * 0.5)`.
- Caret latency root cause: MoonBit `Option::unwrap_or` evaluates its fallback eagerly, so caret code measured huge plain-text prefixes even when the windowed caret rect was available. Replaced with lazy `match`/helper paths; bottom-click hit-testing avoids per-preceding-block measurement while keeping x-based placement in bottom whitespace.

## 2026-06-29 — editor layout and hit-testing

- File tree: `tree_view` is intentionally scroll-unaware; callers wrap it in a `scroll_view` with bounded height (`height - 260`, Recent keeps ~80 px).
- Table click caret: linear interpolation `(x - cell_x) / column_width` ignored cell padding, alignment and real text width (worst for right-aligned cells). Fixed by measuring `rich_text_width`, applying `cell.align`, and per-grapheme midpoint hit-testing inside text bounds. Header weight 700 / body 400 must stay in sync with the renderer.
- Typora-style flush layout: `padding_layout` clamps child width to `min(available, child_size)`, which blocks `expanded()`; use `expanded()` directly and center the editor with `spacer(weight=1.0)` on both sides. A `row` with one child and no spacer does not fill, even under `Stretch`. Test helper `editor_content_x` models `left_width + max(0, (available - editor_width) / 2)`.

## 2026-06-29 — richtext blackbox tests

Outcome: 82 new blackbox tests across five files, no API change, all through `pkg.generated.mbti`. `MarkdownEditReason` derives `Eq, ToJson, Debug` but not `Show`, so `inspect()` does not compile on it.

## 2026-07-07 — native Code Editor example

Outcome: `examples/code_editor` added (native, no WebView/Monaco): tokenizer-backed highlighting, bracket matching, auto-indent, multi-cursor, find/replace, shortcuts, providers, diagnostics, hover, go-to-definition, diff preview, custom language registration; later reshaped into a VS Code-style shell.

- Editable surface is `moui_richtext.controlled_rich_text_editor`; language-service contracts stay app-owned, not promoted to `moui/core`/`moui/views`. LCS line diff in-app, no dependency. `moui_richtext` gained `visible_scroll_state`.

## 2026-09-02 — Markdown editor hot-path overhaul (P1/P2/P3) + undo merge

Outcome: success on the acceptance-relevant fixes; 96 pub lines after P3 (target ~30 blocked structurally); host check exposed two pre-existing renderer text bugs.

- Incremental parse: re-parse only the affected block cluster with offset rebase; fence/HTML/table/footnote/bracket/global-context guards fall back to full parse.
- Persisted measured-height prefix-sum index keyed by font/width/source, epoch invalidated; content height O(1); visible window by binary search.
- One memoized soft-wrap layout per block per width shared by paint/height/caret/hit-test/copy/selection; copy strips injected soft breaks.
- Undo merge window: contiguous same-kind single-char edits within 500 ms merge into one undo entry; newline/paste/selection-replace/undo/redo reset. Undo tests must drive with the *pre-edit* caret.
- Benchmarks (79 KB fixture, instrumented): end-of-doc keystroke 123,680 → 11,845 µs, wheel scroll 22,815 → ≈284 µs, steady session rebuild ≈19 ms (dominated by the app's `markdown_editor_substring` O(source) copy debt).
- Host bugs fixed: SkParagraph `fStartIndex`/`fEndIndex` are UTF-16 code units (were mapped through UTF-8 byte offsets → CJK wrap corruption); shaped-run glyph ids must be painted with a typeface whose cmap covers the text (CJK painted blank on GPU).
- P3: 52 declarations privatized; dead code deleted (`TextViewerNode`, `controlled_rich_text_document_editor`, source-range methods…); 4046 public-depends-on-private forced 40 restorations, so the ~30-line target needs a domain-model relocation into the app package.

## 2026-10-03 — Blocks canvas (MoUI Studio) defects

Outcome: three reported defects fixed, `moui_studio/app` 273/273.

- Context menu anchors at a zero-size pointer point; `…End` aligns the menu's right edge to the pointer and pops left. Candidate order is now `BelowStart, AboveStart, BelowEnd, AboveEnd`.
- Block width hugs content (estimate ÷ `LABEL_WIDTH_SAFETY` + 12, floor 64); the "▶ " spotlight text prefix was removed (retained as a stroke) because it forces ellipsis at content width.
- Slot holes are positioned by a leading cursor; `TextRun` defaults to `align=TextCenter`, so any left-cursor accessory drawn with default alignment is displaced — the black-hole artifact. Display/lead/hit text now come from one producer (`block_row_texts`).
- MoonBit traps: string interpolation `\{…}` cannot span lines; this core has no `String::substring`/`drop_suffix`; headless runtime (`new_program_with_dimensions` + `draw_commands()`) gives real-text-geometry acceptance cheaper than fake metrics. Second round: "Run" fills the run page without executing the selected subprogramme (events execute it); full-screen pages use `side_width` for `main_col`/bottom bar. Run-page armed state i18n key `app.run.armed`.
