# TUI output path and pointer/input parity (2026-10)

Durable summary of the terminal output path and the input/pointer parity arc.
Canonical: `docs/renderer-capability-report.md` (Terminal column),
`docs/plans/active/pointer-input-parity.md`, `moui_tui_renderer/AGENTS.md`.

## 2026-10-15 — TUI output path (S0–S7)

Outcome: S0–S7 landed, all static gates green. Terminal path is `experimental` /
`ready=false`: interaction fidelity proven, pixel fidelity not claimed.

- Terminal is an *output path*, not a platform route: five surfaces —
  `moui_tui` (cell buffer with damage and CJK double-width), `moui_tui_renderer`
  (semantics-only ANSI provider, no native/GPU link), `moui_terminal_host` (raw
  mode, SGR(1006) mouse, byte→event decode, `tui-ansi` composition),
  `examples/tui_split` (acceptance app), `moui_tests/tui_pty_smoke` (real PTY gate).
- `DrawFrame` carries the semantics payload; a cell renderer that went through the
  pixel protocol would have to invent a fake frame.
- Projection policy lives in the renderer (`role`→cell, ownership/avoidance z-order,
  degrade placeholders + diagnostics for non-projectable controls); colors reach
  cells only through `TuiPalette`/theme, never `SemanticsNode`.
- PTY gate is content-anchored; `resize` clears and rebuilds the sent grid;
  write-time dirtying was mis-sending unchanged rows.
- Text fields on the terminal route panicked until caret indexing went through
  `caret_offset` (empty array → box origin).
- Selection bands: focused bands first, selected bands second — a click moves focus
  before selection, so the single paint-order band pass let an inner button's focus
  band overwrite the row band (left-list flash on the previous row, right-tree front
  sliver). Unscoped "no reversed cell in this row" assertions are impossible because
  two panes share a terminal row; scope to column ranges.
- Capability report gained a fourth self-report column (`provider_id: "tui-ansi"`);
  68 cells machine-checked.

## 2026-10-16 — TUI hardening (H1–H5)

- Gate criterion changed from a 250 ms quiet window to content anchors:
  `await_frame(needle)` / `await_reply()` + a 60 ms confirmation flush; nightly CI
  in `moui-runtime-gates.yml` on macos-14 with two binaries.
- `moui_tui_renderer/AGENTS.md` is the projection contract (R1–F5); changing a
  projection rule means citing its id and, for golden frames, a dated reason.
- `examples/tui_layers` (16 layers, s-free tail names) is the sole two-pane terminal
  acceptance app after `tui_split` retired with all its PTY proofs ported.
- Rejected pinning the 100×30 split demo as a whole-frame golden; the planned Ctrl-T
  live theme toggle became a `--theme dark` launch flag (mid-session reload is debt).
- Field-bearing two-pane apps cannot claim bare-letter commands: the decoder emits
  Keyboard+TextInput per printable byte.

## 2026-10-23 — pointer/input parity (S0–S6, S8, S9)

Outcome: §0–§6, §8, §9 landed; §7 (pinch/rotation) and the fling half of §3 remain.

- Scope lesson: the first plan was rejected for listing infrastructure gaps instead
  of user-visible behaviour. Six items were required verbatim: timed wake for held
  long-press, `PointerEvent` multi-touch contract, touch-era input minimum set,
  scroll inertia/rebound, RTL mirroring, stale-doc fixes.
- §3 split: rubber-band clamping, animated rebound and scrollbar geometry close in
  `moui/views`; exponential velocity decay needs the runtime frame pump under a
  paint latch → tracked as the remaining half behind owner approval.
- §4 kept the published Web ABI at 8 pointer parameters even though the workspace
  ABI grew to 10 (`id`, `pressure`); widening the `moui_cli` template broke the
  Studio export build ("requires 8 arguments, but is given 10").
- §5 hard line for triple-click (to the next `\n`) and a bounded word-boundary
  subset for double-click, not a UAX #29 claim.
- §9 moved the canonical mirror formula to core: `Rect::mirrored_x`,
  `Insets::mirrored`, `CustomPlacementContext::mirror_x` (+2 core methods,
  −1 views method); RTL overlay placement needed
  `OverlayPlacementContext.layout_direction` and a *required* `direction~` on
  `PresentationPlacement::resolve` (a silent LeftToRight default lands popups on the
  wrong side). Wheel stays physical; `scroll_leading_x_delta` isolates the
  leading-edge conversion.
- MoonBit syntax pitfalls: `-.x` does not parse (`0.0 - x`), tuple destructuring
  needs parentheses, bare cross-package enum constructors fail in unannotated array
  literals, `moon check <pkg>` can answer "no work to do" after real edits — verify
  with `moon test`/workspace check.
