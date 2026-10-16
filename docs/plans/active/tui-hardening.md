# Plan: TUI hardening — close the output path, contract-ify the projection, make the evidence automatic

- **Status**: active (opened 2026-10-16, continuing [tui-output-path](tui-output-path.md),
  which stays open until its PTY gate lands in nightly CI and then moves to `done/`).
- Goal: turn the shipped S0–S7 TUI path into a governed, self-checking surface:
  the `pr` profile green, the projection rules converged into one verifiable
  contract, the PTY interaction gate deterministic and wired into CI nightly, a
  theme→ANSI palette that carries the app's `@core.Theme` into cells without a
  `moui/core` change, and one canonical TUI acceptance example.
- Non-goals: no new `@core` view variants or `SemanticsNode` color fields; no
  15th route in `checks/platform-matrix.json`; no keyboard-routing change in
  `moui/runtime` (beyond the approved `focus-dbg` removal); no dynamic
  theme-reload mid-session (recorded as debt); Windows ConPTY out of scope.
- Owner decisions feeding in (2026-10-16): Option A of the two open items in
  `tui-output-path.md` — (1) delete the `[focus-dbg]` `println` in
  `moui/runtime/runtime_events.mbt:431` (the approval that plan asked for is
  granted here), (2) settle the `validate_api_surface` source budget
  1669 → 1680 with a dated reason instead of splitting the file. The PTY CI
  decision is: determinize the settle protocol first, then join the existing
  nightly `moui-runtime-gates.yml`.

## Stages

- H1 close-out: settle the budget ratchet, remove the `focus-dbg` println,
  commit the uncommitted S0–S7 working tree in module-boundary commits
  (carrier → `moui_tui` → `moui_tui_renderer` → `moui_terminal_host` →
  apps/tests/gates → docs-and-surfaces). Exit: `sh scripts/check.sh --profile
  pr` green; `sh scripts/tui-pty-smoke.sh` 13/13.
- H2 projection contract (no behaviour change): `attrs_for` switches on the
  `SemanticsRole` enum exhaustively like `role_tag`/`role_kind` already do, so
  the compile-time coverage promise extends to styling; `moui_tui_renderer/AGENTS.md`
  numbers every projection rule (R1…) with its implementation site and test
  name; `golden_wbtest.mbt` pins whole-frame row arrays for the box+items
  fixture and the split demo at 100x30; named tests added for the four rules
  currently covered only in prose or in the PTY suite (word-gap fill, tiny-box
  `~`, band pass order, role glyphs).
- H3 evidence automation: replace the quiet-window completion criterion in
  `moui_tests/tui_pty_smoke` with needle/deadline waits plus a short
  confirmation window (byte-fact counters unchanged); migrate all 13 cases;
  add a `tui-pty-interaction-smoke` job to `moui-runtime-gates.yml`
  (macos-14 nightly); flip `smoke/gates.json` mode `manual` → `run`, `docs/testing.md`
  wording; then `tui-output-path.md` closes into `done/`.
- H4 theme→ANSI: `TuiPalette` in `moui_tui_renderer` (default palette =
  today's constants, zero drift; `from_theme(@core.Theme)` quantizes palette
  colors to xterm-256); optional `palette?~` on `TuiRenderer::new`/`ansi()`
  and optional `theme?` on the host `run_program`/`run_view`; `tui_layers`
  Ctrl-T theme toggle proved in the PTY suite; capability-report notes updated;
  `moui_tui_renderer`/`moui_terminal_host` bump to 0.2.0 with pins synced.
- H5 consolidation: `TerminalState` constructed per `run()` instead of a
  process-level `let` (same public API); grow `tui_layers` datasets until the
  wheel scrolls several rows, port the split-demo-only PTY needles, then
  remove `examples/tui_split` and its surfaces (moon.work, smoke script,
  catalog, docs); add the "non-windowed output path" category line to
  `docs/architecture-map.md` and `docs/INDEX.md`.

## Acceptance

- [x] H1 `pr` profile green; S0–S7 work committed on this branch in module
      commits; focus-dbg gone; ratchet exact.
- [ ] H2 `moon test moui_tui_renderer moui_tui moui_tests/tui_spike --target native`
      green with golden frames unchanged from H1 behaviour; every rule in
      `moui_tui_renderer/AGENTS.md` names a test; six static validators green.
- [ ] H3 `sh scripts/tui-pty-smoke.sh` green 3 consecutive local runs;
      workflow_dispatch of `moui-runtime-gates.yml` runs the new job green;
      `node scripts/smoke-check.mjs --check` green; `tui-output-path.md` in `done/`.
- [ ] H4 default-palette golden frames byte-identical to H2; themed PTY case
      green; `moon info`/api-surface regenerated.
- [ ] H5 PTY suite green with two binaries and no lost assertion strength
      (each ported case names its origin); `sh scripts/check.sh --profile
      daily` green; this plan moved to `done/`.

## Decision log

| Date | Decision |
|---|---|
| 2026-10-16 | owner approved: scope = all stages; delete `focus-dbg`; no `SemanticsNode` color field — theme enters via renderer palette param; PTY gate: determinize settle, then join nightly. |
| 2026-10-16 | budget remedy = settle ratchet 1669→1680 with dated reason (splitting the validator deferred; the file is the API-surface contract-audit carrier). |

## Progress

| Date | Note |
|---|---|
| 2026-10-16 | plan opened on `tui/hardening`; H1 in progress. |
| 2026-10-16 | **H1 landed**: 9 commits (carrier `6a1495307` → fmt `c31cffdad`), focus-dbg removed (owner approval recorded in tui-output-path header), validate_api_surface ratchet settled 1669→1680 with dated reason, six static validators green, `sh scripts/check.sh --profile pr` green end-to-end (194 steps), PTY gate 13/13 before and after the fmt commit. |
| 2026-10-16 | pre-existing infra note (not this plan's defect): `moui_studio/services/compile_native` failed twice in earlier profile runs under load (assertion flake, then SIGSEGV) while passing 4/4 in isolation; HEAD `20bf3089c` (studio scaffold_plan refactor) has never been pushed, so CI has not validated that surface. Unrelated to TUI paths; left for the owner. |
