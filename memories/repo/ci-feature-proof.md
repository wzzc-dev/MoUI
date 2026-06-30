# CI Feature Proof System

## Proof Layers

- **L1**: Package tests pass = API correct (all PRs, no real hardware needed).
- **L2**: Matching-host platform smoke = runtime behavior proven (only on
  `moui_skia/**` path changes).
- **L3**: All platforms L2 pass = full cross-platform proof.

## Trigger Rules

| Workflow | Trigger | Scope |
|----------|---------|-------|
| `ci.yml` | Always on push/PR | L1: macOS/Linux/Windows + Web wasm-gc |
| `moui-skia-real-skia-pr-smoke.yml` | PR + `paths: moui_skia/**` | L2: real Skia pixels on 3 platforms |
| `feature-proof-summary.yml` | `workflow_run` on ci.yml | Summary report generation |

- Non-Skia PRs: L1 only (~5 min).
- Skia PRs: L1 + L2 parallel (~30 min).
- When `moui_skia` is not changed, L2 features are marked `skipped` (not `gap`).