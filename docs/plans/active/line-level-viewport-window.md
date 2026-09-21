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

The caret rectangle, hit testing (`rich_text_document_source_offset_at_point`)
and selection rendering consume `window.document`. Once 3a clips the wrapped
text, they must apply the same line window and vertical offset, or a click lands
on the wrong line.

- Extend `MarkdownDocumentRichTextWindow` with `clipped_lines` (visual lines of
  the first rendered block that sit above the viewport) and `clipped_height`
  (their accumulated height). `top_padding` already exists as the mechanism for
  the same idea at block granularity.
- Thread the pair through the caret/hit-test coordinate conversion.

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
