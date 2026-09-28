# MoMao UI layout traps (views.mbt)

- **Verify layout via MCP, not pixels**: momao's macos entry serves MCP NDJSON
  on its own stdin (`serve_with_diagnostics`, protocol 2024-11-05): 2 semantic
  tools + 4 diagnostics (runtime counters, paint summary with ALL drawn texts,
  raw pointer/keyboard event injection `{"kind":"Pointer","position":{x,y},
  "phase":"Down|Up"}`, command intents). `read_semantics` frames are numeric
  ground truth; `perform_action` drives the app (target node_id as decimal
  STRING, action `{"kind":"activate"}`, precondition `{"kind":"latest"}`).
  This closed the loop on: empty-canvas hint (paint texts), dirty marker,
  draft restore, canvas zoom hit-testing.
- Known leak (FIXED): text_field values are exposed verbatim in the semantics
  tree. The provider key now uses `password_field` (masked display + reveal
  toggle) and update ignores edits while masked (star-text would corrupt the
  real value).
- Design-canvas auto-fit: the canvas measure fills its constraints
  (`width = min(max_w, max_h/0.75)`), scale = frame.width/640 computed in the
  draw/tap/drag closures — the canvas column is `.flexible()` in the main row,
  so the canvas grows with the window and hit-testing stays consistent without
  model state. Drawing plan ops are pure design coords; transforms happen at
  draw time.
- Draft auto-save: `program()`'s update wrapper recomputes
  `@codec.encode_program(program)` per message; dirty = encoding !=
  `saved_encoding` (set on save/open), draft written to settings key
  `momao.draft` only when the encoding changed since `draft_encoding` (RunTick
  at 30fps doesn't rewrite). Restored drafts boot dirty (● next to the title).

- `@views.text` defaults to `width=160` and the width is a **minimum** (grows with
  measured text). Inside a fixed-width panel it silently inflates the scroll
  content wider than the viewport; sibling buttons stretch to the inflated width
  and get clipped square by the scroll clip. Always pass explicit `width=` for
  texts inside narrow fixed panels (momao left panel headers use 140).
- Scroll indicator geometry (framework): the thumb draws at the **viewport's
  right edge minus 7pt** (`scroll_indicator_thumb`), so "scrollbar at the panel's
  far right" means the scroll viewport itself must reach the panel edge — e.g.
  card `padding=0` + full-bleed `scroll_view(width=card_width)` (momao right
  panel: thumb lands ~4pt from the card border).
- A scroll container's child **frame is the viewport width** (tight on
  re-layout): a bare `column` directly inside `scroll_view` stretches every
  child to the full viewport. To get centered content + a scrollbar lane, wrap
  the column in `@views.container(width=<content>, background=transparent,
  padding=<vertical breathing>)` — ContainerBox centers the child inside the
  stretched frame, and the leftover right strip becomes the indicator lane
  (momao right panel: viewport 300 / content 250 → fields centered at 25pt
  margins, ~18pt clear of the thumb). Cap every child's `width=` to the content
  budget, or one wide text inflates the whole column again.
- Main-row horizontal centering: flex rows pack children at x=0; the top_bar is
  centered (ContainerBox centers its narrow child), so the two rhythms clashed
  and the left card sat flush with the window edge. Fix: `@views.spacer()`
  (weight=1) at both row ends centers the row content and degrades gracefully
  on narrow windows.
- `@views.divider(axis=Vertical)` measures as **full available height** (mirror
  of the horizontal divider's full-width behavior). Inside a flex row it drives
  the row's cross size up to the window height; combine with `ContainerBox`
  centering this pushed the design canvas ~157pt down and pushed the footer
  notice off-window. Fix: bound the row `.frame(height=560.0)` (same as the
  panel cards) and `align=Start` so the 640x480 canvas top-aligns with panels.
- `shortcut_button` chip text is mono 16px: `Ctrl+Z` ≈ 58px, `Ctrl+Shift+Z` ≈
  116px. Chip width must be ≥ label + 12 padding (momao uses 84 / 140); smaller
  values clip the shortcut text on both sides.
- Button variant discipline after the "red wall" feedback: one solid Primary per
  panel (运行 / 生成提案 / 闸门确认); list entries, mode toggles, delete/duplicate
  use Tonal / Outline.
