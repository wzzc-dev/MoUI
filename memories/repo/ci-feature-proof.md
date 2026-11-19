# CI Feature Proof System

## Proof Layers

- **L1**: Package tests pass = API correct (every push/PR, no real hardware needed).
  In `ci.yml` the L1 signal comes from `pr-static` (ubuntu-24.04: policy
  validators, API-surface guards, MoonBit tool tests, format) and `pr-profile`
  (macOS: one `_build` reused by `pr-native` plus the workspace sweep).
- **L2**: Matching-host platform smoke = runtime behavior proven (only on
  `moui_skia/**` path changes).
- **L3**: All platforms L2 pass = full cross-platform proof.

## Trigger Rules

| Workflow | Trigger | Scope |
|----------|---------|-------|
| `ci.yml` | push/PR on `main` and `dev` | L1 static + native halves, Linux contracts, Windows MSVC, agent smoke |
| `moui-skia-real-skia-pr-smoke.yml` | PR + `paths: moui_skia/**` | L2 real Skia pixels on 3 platforms |
| `feature-proof-summary.yml` | `workflow_run` on ci.yml | Summary report generation |

- Docs-only changes (`docs/`, `memories/`, `website/web_wasm/docs/`, `*.md`) skip
  the compile jobs; `pr-static` still runs because it validates documentation.
- `macos-packaging` and `benchmark-scaffold` are push/dispatch-only landing
  checks. Their L1 rows are by-design skips on a PR, and compile jobs are
  by-design skips on a docs-only change; `generate_feature_proof_report` gets
  `--event` / `--docs-only` from the summary workflow so a real failure still
  fails verification.
- Job ids the report maps: `pr-static`, `pr-profile`, `linux-platform`,
  `macos-packaging`, `benchmark-scaffold`, `windows-native`, plus the three
  `*-real-skia` jobs.
- Non-Skia PRs: L1 only. Skia PRs: L1 + L2 parallel. When `moui_skia` is not
  changed, L2 features are marked `skipped` (not `gap`).

## Summary-job cost traps

`feature-proof-summary.yml` only renders a report from job conclusions plus the
MoonBit verify tool, so it checks out with `submodules: "false"` and installs no
wayland/Skia system packages; the 356 MB window submodule and apt step it used
to carry were pure overhead. `docs_only` is derived from
`pr-profile == skipped && pr-static == success`, and an empty commit range (a
dispatch run on an already-landed commit) is forced to `docs_only=false` so the
run still compiles the tree it was asked to prove.

## ubuntu `pr-static` needs the Wayland prebuild set

Every MoonBit-backed validator shim runs `moon` in the workspace, and resolving
`wzzc-dev/window` executes its Linux prebuild, which shells out to
`wayland-scanner` for `xdg-shell`, `xdg-decoration`, and `cursor-shape`. Without
`wayland-protocols` + `libwayland-dev`/`libwayland-bin` the job dies with
`xdg-shell protocol XML not found`, before any guard output. Install the lean
set (`bash scripts/set_linux_deps.sh --wayland`) in that job; the full set is
only for the Linux platform-contracts job that actually links and runs.
