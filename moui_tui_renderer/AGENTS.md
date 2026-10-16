# moui_tui_renderer — Projection Contract

This renderer turns a `@core.SemanticsFramePayload` into a cell grid and an ANSI
delta stream. Everything below is one rule set: each rule has an id, an
implementation site, and at least one named test. A change to a rule must
reference the rule id in the commit message, and rules may only be added or
retired by updating this table — the S5/S7 incident history shows that rules
changed ad hoc re-break sibling rules.

## R — Geometry and clipping

| id | rule | impl | test |
|---|---|---|---|
| R1 | A cell belongs to a frame iff the cell **centre** lies inside the frame (the pointer clicks cell centres, so drawn box = hit box). | `quantize_span` project.mbt:32 | projection_test.mbt "quantization keeps exactly the cells a centre click can hit" (:28), the phase sweep and the 54x11 button cases (:73, :112) |
| R2 | A hairline frame that owns no centre still gets one cell **for strokes** (sub-cell fallback `floor(edge/cell)`). | `quantize_axis` project.mbt:50 | clip_wbtest.mbt "a band needs a cell centre, a stroke does not" (:17) |
| R3 | The band pass uses `quantize_box` which has **no** sub-cell fallback: a rect with no centre owns no band (a reversed cell with no glyph is a colour blob, not a selection). | `quantize_box` project.mbt:94 | clip_wbtest.mbt :17 |
| R4 | Two inherited rects: `chrome` (what a Region may ring) and `content` (ring inside); `child_clip` narrows only at `ScrollView`; a ring with no inside falls back to the whole ring so cramped panes keep showing rows. | `Clip`/`inside_ring`/`child_clip` project.mbt:145–172 | projection_test.mbt "scroll view clips its own rows" (:435), "clips narrow at scroll views" (:458), "a ring with no inside keeps its full rect" (:485), clip_wbtest.mbt :42; PTY "S7 a short pane keeps its ring free of rows and bands" |

## R — Painting order and ownership

| id | rule | impl | test |
|---|---|---|---|
| P1 | Paint in BFS order from the root; off-viewport strays are appended last and clipped away, never folded onto the boundary. | `paint_order` project.mbt:274; `visible_box` :258 | projection_test.mbt :141, "off-viewport nodes are clipped" (renderer tests + tui_spike) |
| P2 | Per-cell ownership: priority 1 chrome/Item, 2 Label, 3 Content/Placeholder; higher wins, equal priority first-come-first-served. | `role_priority` roles.mbt:32; `can_claim` canvas.mbt:171 | projection_test.mbt :218, :244 |
| P3 | Stealing a wide glyph clears its continuation partner. | `drop_partner` canvas.mbt:191 | projection_test.mbt "stealing a wide glyph clears its partner" (:271) |
| P4 | `Item` roles paint no glyphs (an item's text belongs to its children); `Placeholder` paints `[image]`/`[web-view]` and a named degrade record; an unnamed leaf gets `?` + `unlabeled-leaf`. | paint path project.mbt:344–380, 408 | projection_test.mbt "wrappers paint nothing..." (:557), renderer_test.mbt :325, :365 |
| P5 | Word wrapping fills only the word's own cells; a gap never paints over a sibling's cell. CJK breaks hard per character. | `write_boxed`/`put_word` canvas.mbt:268–329 | projection_test.mbt "CJK text wraps inside its own quantized box" (:301); word-gap unit case added in tui-hardening H2 |
| P6 | A box smaller than its stroke degrades to `~` lines, never to a wrong glyph. | `draw_box` canvas.mbt:334 | tiny-box unit case added in tui-hardening H2 |

## R — Overlay bands

| id | rule | impl | test |
|---|---|---|---|
| B1 | Two band passes, focused first, selected last; the selected row owns its whole box even when an inner button holds focus. | project.mbt:456–497 | canvas_wbtest/projection band cases; PTY "S7 a clicked row keeps the selection band on itself" |
| B2 | Bands copy attrs over unclaimed cells (the band *is* the row highlight) but line decoration (underline) only over cells claimed this frame. | `style_range` canvas.mbt:376 | canvas_wbtest.mbt "focus band underlines only claimed cells" (:16) |
| B3 | A vacated band is swept: cells band-touched last frame, not this frame, and claimed by neither frame reset to default attrs. | `sweep_stale_bands` canvas.mbt:479 | canvas_wbtest.mbt :48; renderer_test.mbt :180; PTY "S7 a moved selection sweeps the band off the vacated row" |

## R — Output framing

| id | rule | impl | test |
|---|---|---|---|
| F1 | Damage is decided by the final grid vs what was last sent, not by write-time dirtying; unchanged frames emit zero bytes. | `row_changed` canvas.mbt:420; `present_update` | renderer_test.mbt "unchanged frame emits zero bytes" (:60), :106; projection_test.mbt :375 |
| F2 | `begin_frame` keeps the retained grid (swap owner/width masks only); `sweep_stale` erases cells not claimed this frame. | canvas.mbt begin_frame/:132 | renderer_test.mbt "dropping a node repaints only the row it left behind" (:80) |
| F3 | A size change clears the projection grid (`clear_all`) and forces one `ESC[2J` rebuild; the buffer's VT-isomorphic resize (scrollback) must never leak into the projection. | `Canvas::resize` canvas.mbt:95; `final_damage` :444 | renderer_test.mbt "a shrink repaints the new grid, not the old one" (:124, :152); PTY resize case |
| F4 | Focus and selection must be visually distinct (`attrs_for`); roles map to styles via an exhaustive match on `SemanticsRole` — a new core role fails compilation here, never degrades silently. | roles.mbt `attrs_for`/`role_kind` | projection_test.mbt :375–381; tui-hardening H2 compile coverage |
| F5 | Pixel-only commands and platform views become **named** degrade records; the log must not degenerate into noise (solid brushes and plain draw-text are not reported). | `degrade.mbt::note_dropped_commands` :106–133 | renderer_test.mbt degrade sources case |

## Change protocol

- Golden frames in `golden_wbtest.mbt` pin whole `rows()` arrays for the box+items
  fixture and the split demo. Updating a golden frame requires the rule id that
  changed and a dated reason in this file's history section.
- Any fix that moves logic out of this module into `moui/core` or
  `moui/runtime` violates the decision-B constraint: quantization, clipping and
  overlap repair live here, in the consuming renderer.
- `moui_tests/tui_pty_smoke` is the only place terminal-visible behaviour is
  asserted; a rule that changes what a screen shows needs a PTY case too,
  verified red against the pre-fix code before it is committed.

### History

- 2026-10-14…15: rules R1–F5 emerged from S0–S7 and the four real-terminal
  addenda (label row = click row; decoration over claimed cells only; ring vs
  content; vacated band sweep; band pass order).
- 2026-10-16: table first written (tui-hardening H2); P5 word-gap, P6 tiny-box,
  B1 pass order and F4 role-glyph coverage gained named unit tests.
