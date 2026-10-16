# 2026-10-16 — TUI hardening session (H1–H5)

- Workspace: MoUI, branch `tui/hardening` (18 commits over five stages).
- Plan: [tui-hardening](../plans/done/tui-hardening.md) (done), continuing
  [tui-output-path](../plans/done/tui-output-path.md).

## Durable facts (promoted to `memories/repo/`)

- The TUI gate is content-anchored: `await_frame(needle)` / `await_reply()` +
  a 60 ms confirmation flush replaced the 250 ms quiet-window criterion; CI
  runs it nightly in `moui-runtime-gates.yml` (macos-14, two binaries).
- `moui_tui_renderer/AGENTS.md` is the projection contract (R1–F5). Changing
  a projection rule means citing its id and, for golden frames, a dated reason
  in that file.
- Colors reach cells only through `TuiPalette` (renderer) / `theme` (host
  entry). `SemanticsNode` carries no color; that boundary was an owner call.
- `examples/tui_layers` (16 layers, s-free tail names) is the sole two-pane
  terminal acceptance app after `tui_split` was retired with all its PTY
  proofs ported.

## Judgments and scope changes

- H2: rejected pinning the 100x30 split demo as a whole-frame golden (it
  duplicates 30 content assertions at a fraction of the churn tolerance, and
  H5 removed the app anyway); small deterministic fixtures are where full
  frame goldens pay.
- H4: the planned Ctrl-T live theme toggle became a `--theme dark` launch flag;
  mid-session reload is debt. The evidence chain (Theme→palette→quantize→ANSI→
  decoded cells) is complete either way.
- H5: bare-letter commands (a `tui_split` proof) were folded into the
  per-keystroke filter evidence; a field-bearing two-pane app cannot claim
  bare letters (decoder emits Keyboard+TextInput per printable byte) —
  documented, not silently dropped.

## Infra findings (pre-existing, not caused here)

- `moui_studio/services/compile_native` flakes under parallel profile load
  (assertion flake once, SIGSEGV once; 4/4 green in isolation).
- `node scripts/test-moui-prebuild.mjs` (daily step 196) fails identically on
  `main` — skia binding prebuild link ownership — unrelated to TUI.
- HEAD `20bf3089c` (studio scaffold_plan refactor) has never been pushed; CI
  has not validated that surface.

## Verification

- `sh scripts/check.sh --profile pr` fully green (194 steps).
- `sh scripts/check.sh --profile daily` green through step 195; the failing
  step pre-exists on main.
- PTY gate: 3×15/15 after the deterministic waits, 3×8/8 after tui_split
  retirement (two binaries).
- Six static validators green on the branch tree (maintenance-baseline only
  red while a parallel session's submodule checkout sat ahead; green on the
  committed pointer).
