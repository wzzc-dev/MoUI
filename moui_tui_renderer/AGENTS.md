# moui_tui_renderer — Projection Contract

This renderer turns a `@core.SemanticsFramePayload` into a cell grid and an ANSI
delta stream. Everything below is one rule set: each rule has an id, an
implementation site, and at least one named test. A change to a rule must cite
the rule id in the commit message; rules are added or retired only by updating
this table. The S5/S7 incident history is the evidence that a rule changed ad
hoc re-breaks a sibling rule — five of the fixes below were real-terminal
defect reports, and none of them regressed after their rule got both an id and
a named test.

References are file + symbol/test name, not line numbers, so the table survives
edits. The whole-frame goldens live inline in the tests they pin
(`projection_test.mbt` "a container box and its items project into a
recognisable grid", `renderer_test.mbt` "interactive roles paint their glyph
markers"): change a golden only with the rule id and a dated reason appended
here.

## Geometry and clipping

| id | rule | impl | test |
|---|---|---|---|
| R1 | A cell belongs to a frame iff the cell **centre** lies inside the frame — the host clicks cell centres, so the drawn box is the hit box (S5 addendum 1). | `quantize_span`, `quantize` (project.mbt) | projection_test "quantization keeps exactly the cells a centre click can hit" + phase sweep + counter 54x11 case |
| R2 | A hairline frame that owns no centre still gets one cell **for strokes** (sub-cell fallback `floor(edge/cell)`). | `quantize_axis` (project.mbt) | clip_wbtest "a band needs a cell centre, a stroke does not" |
| R3 | The band pass uses `quantize_box`, which has **no** sub-cell fallback: a rect with no centre owns no band — a reversed cell with no glyph is a colour blob, not a selection. | `quantize_box` (project.mbt) | clip_wbtest same test, `None` cases |
| R4 | Two inherited rects: `chrome` (what a Region may ring) and `content` (ring inside). `child_clip` narrows only at `ScrollView`; a ring with no inside falls back to the whole ring so cramped panes still show rows (S7 addendum). | `Clip`, `inside_ring`, `child_clip` (project.mbt) | projection_test "scroll view clips its own rows" / "clips narrow at scroll views" / "a ring with no inside keeps its full rect"; clip_wbtest "inside_ring insets by one cell"; PTY "S7 a short pane keeps its ring free of rows and bands" |

## Paint order and ownership

| id | rule | impl | test |
|---|---|---|---|
| P1 | Paint in BFS order from the root; nodes outside the viewport are **dropped and counted** (`offscreen-nodes`), never clamped onto the boundary row. | `paint_order`, `visible_box`, `offscreen_node_count` (project.mbt, renderer.mbt) | projection_test :141-style BFS case + offscreen case; tui_spike "off-viewport nodes are clipped, not folded onto the boundary row"; renderer_test offscreen diagnostic case |
| P2 | Per-cell ownership: priority chrome/Item 1 < Label 2 < Content/Placeholder 3; higher wins, equal priority first-come-first-served. | `role_priority` (roles.mbt), `can_claim` (canvas.mbt) | projection_test "leaf beats border" + "same priority first wins" |
| P3 | Stealing a cell clears the wide glyph's continuation partner. | `drop_partner` (canvas.mbt) | projection_test "stealing a wide glyph clears its partner" |
| P4 | `Item` roles paint no glyphs (an item's text belongs to its children); `Placeholder` paints `[image]`/`[web-view]` + named degrade; an unlabeled Content leaf paints `?` at lowest priority + `unlabeled-leaf`. | `paint_content`, `paint_node` (project.mbt) | projection_test "wrappers paint nothing so their rows keep their letters"; renderer_test placeholder + `?` leaf cases |
| P5 | Word wrapping fills only the word's own cells; the trailing gap writes a space **only when claimable**, never over a sibling glyph; CJK breaks hard per character. | `write_boxed`, `put_word` (canvas.mbt) | canvas_wbtest "a word gap never paints over a sibling glyph" (the `Entry 0`→` ntry 0` regression, pinned at unit level 2026-10-16); projection_test CJK wrap case |
| P6 | A Region box smaller than its stroke (fewer than 3 rows or 3 cols) degrades to a single `~` marker cell — a Region is never silently dropped. | `draw_box` (canvas.mbt) | canvas_wbtest "a too-small box degrades to a marker cell, a real box gets corners" (pinned 2026-10-16) |

## Overlay bands

| id | rule | impl | test |
|---|---|---|---|
| B1 | Two band passes: **focused first, selected last**. The selected row owns its whole box even when an inner button holds focus (S7 follow-up 2). | band loops in `project_payload` (project.mbt) | band_wbtest "the selected band wins every cell it shares with the focused band" (unit-level pass order, pinned 2026-10-16); PTY "S7 a clicked row keeps the selection band on itself" |
| B2 | Bands rewrite attrs without claiming cells (the band *is* the row highlight), but line decoration (underline) applies only to cells claimed this frame — a line over an unclaimed cell is a quantization artefact, not a control (S5 addendum 2). | `style_range` (canvas.mbt) | canvas_wbtest "a focus band underlines only claimed cells" |
| B3 | A vacated band is swept: cells touched by the band last frame, untouched this frame, and claimed by neither frame reset to default attrs (S7 follow-up 1). Glyph cells stay with the owners/sweep; wide right-halves stay with their left half. | `bands`/`prev_bands` masks + `sweep_stale_bands` (canvas.mbt) | canvas_wbtest "a band that moves away resets the attrs of cells nobody claimed"; renderer_test "a band that moves away rewrites the cells it vacated"; PTY "S7 a moved selection sweeps the band off the vacated row" |

## Output framing

| id | rule | impl | test |
|---|---|---|---|
| F1 | Damage is decided by comparing the final grid against the grid last **sent**, not by write-time dirtying; unchanged frames emit zero bytes. | `row_changed`, `present_update`, `final_damage` (canvas.mbt) | renderer_test "unchanged frame emits zero bytes" + repaint-count cases |
| F2 | `begin_frame` swaps owner/width masks but keeps the retained grid; `sweep_stale` erases only cells this frame did not claim. Without this F1 has nothing to diff. | `begin_frame`, `sweep_stale` (canvas.mbt) | renderer_test "dropping a node repaints only the row it left behind" |
| F3 | A size change clears the projection grid (`clear_all`, scrollback dropped) and forces one `ESC[2J` rebuild. `TermScreen::resize` keeps VT-isomorphic scrollback — that is correct for the emulator and wrong for a full-frame projector, so the clear is renderer-local (S5). | `Canvas::resize`, `final_damage` rebuild branch (canvas.mbt) | renderer_test "a shrink repaints the new grid, not the old one" (red against the pre-clear version); PTY resize case |
| F4 | Roles map to styles through **exhaustive matches on the `SemanticsRole` enum** (`role_tag`, `role_kind`, `base_attrs`): a new core role fails compilation here rather than degrading silently in any of the three layers. Focus and selection must be visually distinct. | `role_tag`, `role_kind`, `base_attrs`/`attrs_for` (roles.mbt) | projection_test "focus and selection are visually distinct from plain text"; compile-coverage: `moon check moui_tui_renderer` fails on an unmapped new variant |
| F5 | Pixel-only commands and platform views become **named** degrade records; the log must not degenerate into noise (a solid brush and a plain draw-text are not reported). | `note_dropped_commands` (degrade.mbt) | renderer_test degrade-sources case |

## Deliberate absences (do not "fix" without reopening the decision)

- No golden for the 100x30 split demo: its properties are pinned by ~30
  content assertions in `moui_tests/tui_spike/renderer_projection_test.mbt` plus
  the PTY gate; a 3000-char whole-frame snapshot would duplicate that signal at
  a fraction of the churn tolerance and dies when H5 folds the demo into
  `tui_layers`. Small deterministic fixtures are where full-frame goldens pay.
- No clip/scroll metadata on `SemanticsNode`, no re-simulated `PushClip` stack:
  the ancestor chain is the clip source, and clipping is quantization policy
  owned here, not a core or runtime concern (Option B constraint).
- `TuiRenderer::recover` always succeeds: there is no GPU resource to lose and
  no CPU fallback to take; the cell projection *is* the final output.

## History

- 2026-10-14/15: rules R1–F5 emerged from S0–S7 and the four real-terminal
  addenda (label row = hit row; decoration over claimed cells only; ring vs
  content rows; vacated-band sweep; band pass order).
- 2026-10-16 (tui-hardening H2): table first written; `attrs_for`/`base_attrs`
  moved onto the enum (F4); P5 word-gap, P6 tiny-box, B1 pass order and the
  role-glyph signatures (P4/F4) gained named unit tests; box+items and
  role-glyph frames pinned as inline goldens.
