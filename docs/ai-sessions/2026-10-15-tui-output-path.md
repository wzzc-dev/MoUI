# 2026-10-15: TUI output path (S0–S7)

- **Agent**: Qoder agent (MoonBit / MoUI framework work)
- **Goal**: Build a desktop-grade TUI output path so existing `@moui.View[Msg]`
  apps run in a real terminal — split panes, focus traversal, list selection,
  file-tree collapse, mouse, instant relayout — without pixel rendering.
  Stages S0→S6, each with reproducible evidence.
- **Outcome**: Success (S0–S7 landed, all static gates green). Terminal path is
  `experimental` / `ready=false`: interaction fidelity is proven, pixel fidelity
  is not claimed.

## Summary

Five new/changed surfaces: `moui_tui` (publishable cell buffer with damage and
CJK double-width), `moui_tui_renderer` (semantics-only ANSI renderer provider,
no native/GPU link), `moui_terminal_host` (raw mode, SGR mouse, input decode,
cell→logical geometry, explicit `tui-ansi` composition), `examples/tui_split`
(two-pane list + file tree acceptance app), and `moui_tests/tui_pty_smoke`
(real PTY gate for the six interactions). S6 wired the path into the repo's
existing machine-checked consistency surface: the capability validator now checks
a fifth `Terminal cell ANSI` column against the renderer's own self-report.
S7 put all eight acceptance requirements into one app (`examples/tui_layers`) and
extended the PTY gate to drive it, which found and fixed a crash on the terminal
route's text field.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_tui/` | `TermScreen`/`Cell`/`CellAttrs`/`runs()`/`resize()` promoted from `examples/terminal/app`; damage/revision deltas; CJK wide cells | Apps and the renderer need one VT-isomorphic buffer, not two dialects |
| `moui_tui_renderer/` | `RendererProvider`/`RendererSession` over `frame.semantics`; role→cell projection with ownership/avoidance z-order; degrade placeholders + diagnostics for non-projectable controls; `capabilities.mbt` self-report | Keeps quantization policy inside the renderer (invariants P5/P6/P10/P11) |
| `moui_tui_renderer/canvas.mbt` | `present_update` diffs candidate rows against the grid last sent; `resize` clears and rebuilds `sent` | Write-time dirtying repainted unchanged rows; terminal-semantics `resize` leaked scrollback into the projection |
| `moui_terminal_host/` | termios raw mode, SIGWINCH, SGR(1006) mouse set/restore, byte→event decode, explicit `tui-ansi` provider | Three input channels, none swallowed by the backend |
| `moui/core` `DrawFrame` | carries the semantics payload | A cell renderer driven through a pixel protocol would have to invent a fake frame |
| `examples/tui_split/` | left list + right file tree using existing `View` composition only | Proves split layout, per-pane scroll/clip, dynamic tree with stable identity — no new `@core` view variant |
| `examples/tui_layers/` | one app carrying all eight requirements: two panes + a live filter field, `only-visible` box, per-pane wheel, program-claimed `Ctrl` chords, `rows=`/`hide=`/`sel=` needles | The split demo's static list cannot prove a keystroke reaching the model per character, nor a scroll that belongs to the hovered pane |
| `moui/views/text/`, `moui_tui_renderer/cell.mbt` | cell text system reports per-character insertion columns; six caret-index sites go through `caret_offset` (empty array → box origin) | Clicking a text field in a real terminal panicked and killed the app |
| `moui_tests/tui_pty_smoke/`, `scripts/tui-pty-smoke.sh`, `smoke/gates.json` | 9 PTY tests over three binaries for Tab/Shift-Tab, arrow selection, tree expand/collapse, instant keypress, mouse click+wheel, resize relayout, per-keystroke filter field | The goal's acceptance criterion is a real terminal, not a mock |
| `tools_product/moui/validate_renderer_capability_consistency/`, `tools_product/moon.mod` | Fourth self-report column (`provider_id: "tui-ansi"`), `ReportRow.tui`, row gate `>= 6` cells | A doc column nothing checks rots; 68 cells now verified |
| `docs/renderer-capability-report.md` (+ zh-Hans), `architecture-map.md`, `view-catalog.md`, `testing.md`, `release-readiness.md`, `platform-readiness-declaration.md` | Terminal column, descriptor bullet, ownership rows, coverage + evidence boundary, PTY gate policy, `ready=false` variant section | The path has to survive other people's gates |
| `memories/repo/tui-output-path.md` | Durable traps (matrix contract, validator dep pairing, damage diff rule, resize semantics, routing needs no runtime change, PTY timing) | Facts a future agent cannot re-derive quickly |

## Key Decisions

- **Terminal is an output path, not a platform route** — `checks/platform-matrix.json`
  is a "canonical 14 routes" contract asserted by `tools/moui/validate_platform_matrix`,
  and each route carries pixel-oriented fields. Recorded in
  `docs/platform-readiness-declaration.md` as a variant instead (precedent:
  `linux-skia-riscv64`). Rejected: a 15th route, which would require relaxing a
  governance contract (RFC territory).
- **Machine-checked capability column over prose** — Rejected: describing the
  terminal in paragraphs only; an `Image: supported` row would then be a
  documentation lie about a placeholder that nothing catches.
- **Keyboard routing needed no `moui/runtime` change** — surveyed before writing
  code: pass 3 (`Program::with_commands` + `ActionCommand`/`KeyboardShortcut`)
  already lets an app claim editing keys ahead of the focused control, and
  bindings are re-derived from the model each update. Rejected: adding a routing
  policy API to the runtime.
- **`recover` always reports success** — there is no GPU resource to lose and no
  CPU fallback to take; a fake `FallbackToCpu` would be a lie the session
  contract rewards.
- **PTY gate stays manual for now** — timing-based frame completeness plus a
  POSIX PTY; recorded as debt in `docs/testing.md`. Rejected: wiring
  `.github/workflows/*` inside a documentation stage (shared infrastructure needs
  explicit approval).

## Discoveries

- Frame content, not write history, decides damage: the projector writes a cell
  several times per frame (border → content steal → frame-end sweep).
- `TermScreen::resize` is deliberately VT-isomorphic (content preserved, dropped
  rows into scrollback); a projection that reads `line_at(y)` as "visible row"
  must clear on resize rather than reshape the buffer.
- Adding a renderer dep to a validator's `moon.pkg` fails to solve unless the
  module is also imported in `tools_product/moon.mod`.
- `checks/release-modules.json` has no readiness booleans — `ready=false` lives
  in the readiness docs, not the module catalog.
- PTY smoke assertions need `=`-bearing needles (`list=`, not `list`): the pane
  header `focus: list` sits above the status row and produced a plausible wrong
  number.
- The resize gate failed on a genuine projector defect visible in the raw stream
  (`│ E│tEntry 1` — two layouts superposed), which is now caught by a fast
  renderer test rather than only by the PTY.
- A fixed grid size is not a grid-phase test. Every suite ran at 100x30, where the
  expanding quantizer and the host's centre-based click happen to agree; the
  pointer/hit-test defect below only appears when a frame's top edge lands in the
  lower half of a cell (`frame_top mod 16 >= 8`), which 54x11 exposes. A geometry
  sweep over several sizes belongs next to any grid-quantization claim.

## Follow-up session (same day) — the label row was not the click row

The owner reported it from a real terminal: at 54x11, `[-] [Reset] [+]` drew one
row above the area that responded, so a click had to land *below* the label.

- Cause: `quantize` used the expanding rule (origin `floor`, extent `ceil - 1`)
  while `moui_terminal_host/input_channel.mbt` maps a click to the cell **centre**.
  Proven twice before touching code — a headless frame/box/clickable-row table over
  heights 11..30, then a real-PTY per-row click sweep (label row 6, fired rows 7..8).
- Fix stays in the renderer (`moui_tui_renderer/project.mbt`): keep only the cells
  whose centre lies inside the frame, so the drawn box *is* the hit box; frames
  narrower than half a cell (separators) fall back to the origin's cell rather than
  vanishing. `moui/runtime` hit-testing was not touched, so no owner gate opened.
- Rejected, with the reason in the plan: moving the host's click point to the cell's
  top-left (relocates the contested edge instead of removing it), two quantization
  rules in one grid (splits rows that layout expects to share), and letting the
  border win the contested cell (writes `╰ab/arrow-lr pane`).
- Accepted cost: a cell border costs a whole row, so where a Region's border row is
  also a content row the frame stays open on that side. The split-demo assertion
  `lines[rows-1].contains("╰")` was therefore replaced, not weakened: closure is
  guarded by controlled fixtures plus "some row shows a closed bottom edge", and the
  last row must start with the key-help line intact.
- New guards, each verified red against the old rule (rebuild with `floor`/`ceil`
  restored): 3 renderer tests (quantization contract; the swept general form; "a
  button label is drawn on a row the click can hit" at the counter's real 54x11
  frame) and 1 PTY case (counter
  at 54x11 — clicking the drawn `[-]` cell decrements `Count`, the row above does
  not). `scripts/tui-pty-smoke.sh` now builds `examples/counter/terminal` too and
  exports `MOUI_TUI_COUNTER_BIN`; the split demo cannot show this defect because its
  labels live inside item nodes.

## Follow-up session 2 (same day) — the focus band painted rules on empty cells

The same owner session, one click later: two yellow horizontal rules appeared
under the counter's button row.

- Cause: `Canvas::style_range` copies the focused node's attributes across its
  whole quantized box and ignores ownership on purpose (a list row must highlight
  cells its children wrote). `attrs_for` gives focus an `underline`, and the
  button's box is 3 rows x 13 cols while the label is 1 row x 3 cols, so the two
  blank rows below it were written as *space + underline* — a rule with nothing
  under it. Proven by a throwaway PTY style probe that printed the parsed
  attributes of every cell around the click; the probe is deleted, the two
  assertions it produced are not.
- Fix stays in the renderer: line decoration is dropped where `owners[y][x] == 0`,
  while background/reverse still spans the box. Rejected: skipping unclaimed cells
  in the overlay at all (the `Item` role writes no glyphs, so a selected row would
  lose its bar), shrinking the band to the painted run (the projector keeps no
  per-node drawn extent), and deleting `underline` from the focus style (symptom
  removal).
- New guards: `moui_tui_renderer/canvas_wbtest.mbt` (first white-box file in the
  package — `Canvas` is `priv`, so this is the only way to assert the overlay
  without promoting internals into the public API) and two more assertions inside
  the existing counter PTY case. Both verified red with the guard removed.
- Harness fact worth keeping: the PTY focus assertions must read the screen
  **before** the second click. That click lands outside the hit box and takes the
  focus band off the entire screen (measured: no underlined cell in any row), so
  after it there is nothing left to assert — and the failure would look like a
  renderer regression rather than a lost focus.

## Follow-up session 3 (same day) — eight requirements in one app, and a click that killed it

- Request: `examples/tui_split` proves five of the eight acceptance items, so build
  one demo (`examples/tui_layers`) where a person sees all eight: two panes, Tab
  traversal, bordered list, foldable tree, cursor selection + arrows, mouse wheel and
  click, a keypress that acts without submit, and resize relayout. App code stayed
  inside the app boundary (`examples/tui_layers/app` + a thin `terminal` entrypoint),
  so no framework change was needed to build the demo itself.
- The gate promised in the plan is one white-box PTY case over items 6–8. Written
  against the real grid, it found a crash: **clicking the filter field killed the
  app.** `moui_tui_renderer/cell.mbt` returned `caret_positions: []` (a box-only
  measure has no per-character points), and `moui/views/text` indexed it after
  `clamp_int(_, 0, length - 1)` — that clamp *manufactures* a legal index 0 for an
  empty array, so the subscript panicked inside the focused-field overlay. Fixed by
  making the cell text system report one column per character (wide glyph = 2,
  clamped to `max_width`, empty text still has the origin) **and** by routing the
  six index sites through `caret_offset`, which falls back to the box origin. Three
  new tests; no `moui/core` / `moui/runtime` change, so no owner gate tripped.
- A misreading worth keeping: the run before the fix looked like "the terminal never
  routes keys to the field". It was the crash — a dead process stops updating its
  frame, so the last `filter=-` sits there forever and every later assertion reads
  as a routing bug. Check liveness before checking routing.
- Measured on the real grid (all now asserted): click the `[` of `[x] Labels` →
  `sel=Labels`, Space → `hide=3` and the row's own marker reads back `[ ]`; click
  the placeholder `n` → `s`/`t`/`r`/`o` give `rows=` 8→6→2→1 with no CR/LF sent;
  wheel over a list row while the field holds focus gives `row=1 file=0` (hover
  routing, and one cell is the whole range at this height); resize 72x14 → 43x11 →
  100x30 keeps both pane titles and both panes' rows, with `rebuilds` 1→2→3→4 and
  `painted_count()==30` on the way back.
- Two facts that only exist because a real terminal disagrees with the headless
  driver: a printable byte arrives as `Keyboard` **and** `TextInput`, so the
  released Space *inserts a space* (`rows=1`→`0`) instead of being a no-op as in
  `app_test.mbt` — the release rule is provable only in the PTY gate; and
  `Ctrl` chords are the only structural keys, because any plain-letter claim would
  both fire a command and eat the character the filter is waiting for.
- Also measured: `row_height` is a floor, not the pitch (36px content, pitch
  `row_height + 4`); folding re-centres a content-sized viewport, so a second
  gesture must re-read the frame or it lands in the gap the first one made; at 43
  columns `Canvas::write_boxed` truncates the status line's tail, so narrow-grid
  needles must come from the head of the line.

## Follow-up session 4 (same day) — rows and selection bands landed on the pane border

- Request: from a real 190x12 terminal, "the list sometimes scrolls outside its box,
  and clicking shows a blue selection block" — analyse the cause and fix it.
- Cause, measured rather than assumed: one rect for two different jobs. A terminal
  line is a whole 8x16 cell while the layout's border is a few pixels, so
  a `ScrollView`'s ring row *was* its first content row; the sub-cell fallback in
  `quantize_axis` (kept for hairline separators) then promoted a 4px tail row onto the
  bottom border, and the focus/selection band reused the same rect, so it reversed the
  top border row, the bottom border row and both border columns. Reverting the rule
  reproduces the screenshot exactly: top border reads `[▾] ─[src] ────╮`, bottom
  border reads `╰row 8 ────────╯` in the headless 100x30 spike.
- Fix, entirely inside `moui_tui_renderer` (no `moui/core` / `moui/runtime` change, so
  the owner gate was never triggered): `Clip` carries `chrome` (where a `Region` may
  draw its ring — identical to the old single rect, so a `List`/`Tree` ring stays
  coincident with its `ScrollView` instead of insetting twice) and `content` (the
  inside of that ring, used for every glyph and for the band), plus `quantize_box`,
  a band-only quantizer with **no** sub-cell fallback: a reversed cell containing no
  glyph is a colour blob, not a selection. A ring with no inside falls back to the
  whole ring so a cramped pane still shows rows.
- Accepted cost: every bordered pane loses one content row. The spike's
  `0..<=8` needle became `0..<=7` — that extra row was the one painted *into* the
  border stroke, so "visible" had never meant "correct".
- Two rejected alternatives are recorded in the plan: letting chrome win the contested
  cell (the outer `Group` ring occupies row 0 and row 11 of a 12-row window — the title
  bar and the key legend would be erased), and insetting every region (nested rings a
  cell apart, and both panes empty at 43x11).
- Practice worth keeping: both new assertions were **mutation-checked**. Dropping the
  content track fails on "both panes drew a ring"; dropping only the horizontal inset
  fails on "the band never covers the ring". A regression test nobody has seen fail is
  a guess.

## Follow-up session 5 (same day) — the vacated selection band kept a permanent color block

- Request: from a screenshot of the layers demo, "点过的区域有这个青色的原因是什么" —
  areas that were once selected keep a cyan block with no text in it, and it never
  goes away.
- Cause, measured with a throwaway PTY probe that printed the reverse/bold/underline
  fingerprint of every row across three selections (probe deleted, its assertions
  kept): the highlight band is an attr-only overlay that deliberately does **not**
  claim cells, and `sweep_stale` only resets cells that were *owned* last frame
  (`prev_owners == 0` is skipped forever). A 40px row is 2.5 terminal lines, so the
  band paints the title line plus a tail of empty cells; when the selection moves on,
  the title cells are repainted plain by their owning text nodes but the tail cells
  — owned by nobody — keep `reverse` forever. That is the textless cyan block. The
  same probe added two facts: the startup selection shows the fullest residue because
  nothing ever covers it again; and a *clicked* row loses its band immediately
  because its ghost button's focus band (no reverse) rewrites the same box in paint
  order — keyboard-selected rows keep the bar, clicked rows do not.
- Fix, inside `moui_tui_renderer/canvas.mbt` only: a `bands`/`prev_bands` mask pair
  marked in `style_range`, and a frame-end `sweep_stale_bands` that resets attrs to
  default on cells band-touched last frame, not band-touched this frame, and claimed
  by neither frame. Only unowned cells: glyph cells stay the painters' and
  `sweep_stale`'s job, and wide-char right halves stay tied to their left half.
- Rejected: resetting attrs inside the band pass by pretending the overlay owns its
  cells (that ownership is exactly what keeps the overlay from erasing sibling
  glyphs — the S2 rule), leaving the tail to the presentation diff (stale cells never
  differ again — that is the bug), and re-layering the focus band over the selection
  band (a visual-language decision; the clicked-row lose-the-bar behavior predates
  this fix and is now recorded, not silently changed).
- Guards, verified red against the pre-fix renderer first: black-box
  `renderer_test.mbt` "a band that moves away rewrites the cells it vacated" (a
  glyph-free `Item` band is the purest residue carrier; the vacated row must be
  re-sent once, then identical frames return to zero bytes), PTY
  "S7 a moved selection sweeps the band off the vacated row" (red on "the vacated
  tail line keeps no reversed cell" before the fix), and white-box
  `canvas_wbtest.mbt` "a band that moves away resets the attrs of cells nobody
  claimed".
- One harness note: the full `moui_tui_renderer` suite went green only after a full
  recompile — a stale incremental binary still containing the deleted debug
  `println` made the zero-byte assertion fail once, then 3 consecutive clean runs
  passed. When a just-edited canvas behaves like an older version, force the
  recompile before doubting the logic.

## Follow-up session 6 (same day) — the band flickered with focus, and the tree row kept only a front sliver

- Request: after the sweep fix, the user re-tested and reported two symptoms: 左栏
  点击后会在上一次点击的位置**闪一下**青色, 右栏点击后**被点选项前面**出现青色.
- Cause, measured with a press/release-separated PTY probe (sent
  `...M` and `...m` as separate writes, screen dumped after each): a click moves
  focus **before** it moves selection (focus lands on the embedded button at
  pointer-down, `SelectLayer`/`SelectNode` dispatch on release). The band overlay
  overwrites attrs wholesale and the single band pass ran in paint order, so a
  focused inner button could repaint the row band's box:
  - Left list: the ghost button spans exactly the row, so the clicked row never
    showed a band; meanwhile the previous row — focus gone, **selection not yet
    moved** — regained its reverse band for the press frame, then lost it on
    release. That is the one-frame cyan flash at the last-clicked row. A click on a
    dead zone (no view underneath) blurred focus entirely and popped the still
    selected row's band back.
  - Right tree: the row's label button box starts after the indent + toggle
    columns, so its focus band overwrote the middle of the row band and the front
    (marker/indent) columns kept the reverse — a permanent cyan sliver at the front
    of the clicked item.
- Fix, in `moui_tui_renderer/project.mbt` only: split the band pass into two —
  **focused bands first, selected bands second**. Selection now owns the full row
  box on the terminal regardless of what holds focus inside it: the clicked row
  lights up immediately and stably (no flash on click, no pop-in on blur), and the
  tree band covers the whole row from its front instead of leaving a sliver. A node
  that is both focused and selected composes both states in `attrs_for` already, so
  the second pass re-applies the same attrs there.
- Rejected: merging attrs in `style_range` (sticky reverse produces a yellow band —
  a visual-language change nobody asked for), and making the overlay own cells (that
  ownership is what keeps bands from erasing sibling glyphs — the S2 rule).
- Guards: new PTY case "S7 a clicked row keeps the selection band on itself"
  (verified red on "clicked flow: the band lands on the clicked row" before the
  reorder; asserts the band lands on the clicked row in both panes, covers the tree
  row from its front through the label glyphs, the vacated row and tail stay clean,
  and a dead-zone click does not blink the band). Assertion-scope fact worth
  keeping: one terminal row is shared by both panes, so cross-pane band counts must
  be scoped to column ranges (`reversed_in_cols`, list `[10,40]`, tree `[50,95]`) —
  an unscoped "no reversed cell in the row" assertion is red forever against the
  other pane's legitimate band.

## Validation

```sh
sh scripts/tui-pty-smoke.sh                     # 13 tests, 13 passed (real PTY, 3 binaries; 10 at S7, +1 stray-band, +1 residue sweep, +1 clicked-band)
moon test moui_tui moui_tui_renderer moui_terminal_host \
  moui_tests/tui_spike moui_tests/tui_pty_smoke moui/views/text \
  examples/tui_layers/app --target native       # 140 passed
moon test examples/tui_layers/app --target native   # 19/19
moon test moui/views/text --target native           # 28/28 (incl. the 2 new overlay cases)
moon test moui_tui_renderer --target native     # 33/33 (incl. the 2 clip white-box cases)
node scripts/generate-repo-docs.mjs --write     # repository facts + website docs
node scripts/validate-renderer-capability-consistency.mjs  # 68 cells match
node scripts/smoke-check.mjs --check            # ok (13 suites)
# plus the other five pre-push static validators, all ok
```
(Figures are after the four follow-up sessions; the earlier 43/43 + 6/6 snapshot was
taken before the quantization change.)

## Follow-Up

- [ ] Remove the debug `println("[focus-dbg] …")` at
      `moui/runtime/runtime_events.mbt:431` — needs owner approval (runtime change).
- [ ] Decide whether `tui.pty-interaction-smoke` gets a CI job (shared infra,
      needs approval).
- [ ] `docs/zh-Hans/architecture-map.md` has no terminal row (zh capability table
      also pre-dates this column; no validator compares zh to en).
- [ ] Text-shaping/emoji in the cell grid remains `partial`.

## Promote (required checklist)

- [x] Short durable facts → `memories/repo/tui-output-path.md`
- [x] Architectural choice → recorded in `docs/plans/active/tui-output-path.md`
      (S2/S6 decisions); no new ADR since no invariant was broken
- [x] Multi-session work remaining → `docs/plans/active/tui-output-path.md`
- [x] Stale guidance found → canonical docs updated in place
      (`renderer-capability-report.md`, `architecture-map.md`, `view-catalog.md`,
      `testing.md`, `platform-readiness-declaration.md`, `release-readiness.md`)
