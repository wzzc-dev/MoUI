# Line-Level Viewport Window For Oversized Blocks

- Status: active
- Goal: make the markdown session editor's visible window line-granular inside
  a single block, so opening or scrolling a document whose text collapses into
  one huge soft-wrapped paragraph stays proportional to the viewport instead of
  the document.
- Compatibility: internal to `moui_richtext`; no public API change is intended.
  The paint, caret, hit-test and selection paths must keep consuming one
  soft-wrapped document (ADR 0001), so the line window is additive state, not a
  second document.

## Problem

`markdown_document_window_range` selects a range of **blocks**. A document with
almost no blank lines collapses into very few blocks — a 156,820-line novel is
5 blocks, one of which holds 5.9M characters and ~313k inline runs. That block
is taller than any viewport, so it is never culled and every per-line stage runs
over the whole document.

Measured with `moui_richtext`'s fallback text system, single-block documents:

| lines | session | window | wrap | heights | widths | total |
| ----- | ------- | ------ | ---- | ------- | ------ | ----- |
| 10,000 | 58 ms | 230 ms | 394 ms | 7 ms | 146 ms | ~0.84 s |
| 20,000 | 71 ms | 467 ms | 688 ms | 14 ms | 174 ms | ~1.4 s |

Scaling is linear in document size, and the real app (Skia text system) adds
shaping cost on top: `人间如狱.md` opens its first frame in ~15.9 s.

There is no single dominant stage — the whole per-line pipeline is document
sized. `window` and `wrap` are per content revision (the wrap is content-cached);
`heights`, `widths` and the draw loop run **per paint**, so scrolling a large
document re-walks every visual line every frame.

## Stages

### 3a — paint side

Bound the per-line work to the visible band without changing what is drawn at
each y position.

- `append_rich_text_block_runs` already skips off-band visual lines while still
  advancing `line`, `line_offset` and `x`, so painted positions already agree
  with the full-document layout. **Done.**
- `rich_text_block_line_heights` / `rich_text_block_line_widths` are still
  whole-block and run per paint. Give them a line range, or cache the two arrays
  per (block, width, font) revision so a scroll does not rebuild them.
- `rich_text_document_soft_wrap` still wraps the whole block on the first paint.
  This is the largest single cost (688 ms at 20k lines) and the main target:
  wrap only the source lines in the band, using the block's estimated line
  height to map the scroll offset to a source line index.

### 3b — interaction side

**This must land before 3a is enabled.** 3a was tried on its own and reverted
twice; the second attempt produced a visible defect: scroll away from the caret,
then click, and the caret is painted at the very start of the block.

The cause is that `window.document` is the single geometry source for both
paint and interaction (ADR 0001). Clipping it removes the caret's line whenever
the caret sits outside the visible band, so
`rich_text_document_caret_rect_at_source` finds nothing and falls through to
`markdown_session_estimated_caret_rect`, which places the caret from block-level
geometry — i.e. at the block's start.

The vertical offset itself is already solved: folding the clipped height into
`top_padding` makes `content_rect` place the window correctly, so hit testing
and paint agree. What is missing is *locating a caret the window does not
contain*.

Two candidate designs:

- **A — window is the union of the band and the caret's line.** Extend the slice
  to cover the caret's line as well as the visible band. The existing lookup
  then works unchanged. Simple and exact, but when the caret is parked far from
  the scroll position the window spans everything between them, which is the
  scroll-with-a-parked-caret case that 3a exists to speed up.
- **B — caret geometry from the block's own line index.** Keep the window  band-only and compute an out-of-band caret's y from the block's top plus
  `line_index * line_step`. Exactness needs the caret's line index within the
  block, which no index provides today: `height_index` carries per-block height
  units, not a prefix newline count. Adding one is the real work.

**B is the one that preserves 3a's win.** Its cost is a per-block prefix
newline index, which `markdown_document_source_digest_and_line_counts` already
walks — extending that scan to publish a prefix array is the natural place.

Acceptance test for either design: with the window clipped, park the caret
outside the band, query the caret rect, and assert it equals the rect the
unclipped window produces. That test does not exist yet, which is why 3a looked
safe when it was not.

## Invariants to hold

- **ADR 0001**: paint, caret, hit-test, selection and the measured-height feed
  all read the same soft-wrapped document. The line window is shared state, not
  a paint-only shortcut.
- Painted y positions for the visible band are identical to the unclipped
  layout. This is the acceptance test: for one document, the draw commands in
  the visible band must match the full-layout run command for command.
- Scroll geometry keeps the block's full height; only the *materialised* lines
  shrink.
- Ordinary documents (many small blocks) must take the existing path unchanged;
  the line window only engages for blocks whose estimated height exceeds a
  multiple of the viewport.

## Risks

- **Highest-risk change in the editor.** It touches the window contract that
  paint, caret and hit testing share. Land 3a and 3b separately, each with the
  invariant test above.
- The scroll-offset → source-line mapping uses an estimated line height before
  the band is measured. If the estimate is wrong the band shifts; overscan must
  be generous enough to absorb it, and the measured heights for the band should
  feed back into the geometry the way `markdown_session_record_measured_block_heights`
  already does at block granularity.
- `rich_text_block_soft_wrap` is content-cached, so a banded wrap must not
  poison that cache with a partial block under the block's full-content key.

## Out of scope

- Large-file feature degradation switches (VS Code's large-file mode). There is
  no expensive optional feature to disable yet.
- Changing the block parser so that soft-wrapped paragraphs become many blocks.
  That would change the document model, undo granularity and the outline.

## Progress (2026-09-21)

Landed against the reported defects (`人间如狱.md`, 17 MB / 156k lines / 2 blank
lines → one 5.9M-char paragraph block):

- **3b interaction side — done.** `markdown_session_window_covers_caret` gates
  both the IME input state *and* the painted caret: an out-of-band caret falls
  to `markdown_session_estimated_caret_rect` (session height index + line
  index) instead of being pinned to the band's first rendered line. The
  "scroll, then click, and the caret sits at the very front" defect is covered
  by the runtime regression tests in momark
  (`editor_app_large_file_regression_wbtest.mbt`).
- **Document line-start index** (`markdown_document_line_index`, keyed by
  document identity): the visible-window slice locates a block's line range by
  binary search — a block that holds a whole novel is no longer materialized
  and scanned per window build. Window build on the 100k-line fixture:
  34 ms → 7 ms. Maintained in place by the structure-preserving apply; any
  other apply invalidates it (one line-scan rebuild).
- **Structure-preserving in-line apply** (`markdown_document_session_apply_in_line_edit`):
  an insert/delete/replace strictly inside one line of a single paragraph
  block, with the edited line re-validated against the shell paragraph rules,
  splices the text, shifts ranges and maintains the line index — no region
  re-parse (was O(block) per keystroke), no window decode. Novel-shaped typing
  on the 100k-line fixture: 753 ms → ~33 ms per keystroke (the remainder is the
  block-text splice, fingerprint hash and text-store rewrite, all bounded by
  the block).
- **Region re-parse switched to the shell parse** (`parse_inlines=false`),
  matching the open path's session shape; inline runs materialize on demand.
- **Text store segment cap** (256k chars): a document that is one block is one
  segment, which made every store edit and char probe O(document); edits now
  re-emit capped chunks and constructors cap oversized segments.
- Remaining known cost per keystroke on a 5.9M-char block: the block-text
  splice + fingerprint hash (~O(block) copies). A rope or incremental
  fingerprint would remove it, if the residual latency matters.
- **First-visual-line click snap — fixed.** A paragraph block's inline runs
  carry one run per source line plus a bare "\n" run between them; splitting
  that run yields two empty segments, and the second sits at the start of the
  next line before any content. The hit walk's empty-segment shortcut returned
  there and ignored the click x, pinning every click on a wrapped line's first
  visual line (and past-end clicks on the previous line) to the line start.
  `rich_text_block_visual_offset_at_point` now keeps walking to the line's
  content and only falls back to the remembered start for a genuinely empty
  line. Regression test:
  `rich_text_first_visual_line_hit_wbtest.mbt`.
