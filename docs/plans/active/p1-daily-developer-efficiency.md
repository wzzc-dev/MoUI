# Plan: P1 Daily Developer Efficiency

- **Status**: active
- **Goal**: Make everyday MoUI development faster and more diagnosable through a
  project-local dev loop, a usable Inspector, measurable performance budgets,
  and data-view primitives that scale beyond fixed-height demos.
- **Non-goals**: V1 does not claim in-process state-preserving hot reload,
  device-specific log streaming for every platform, or production readiness for
  experimental renderers. Those require matching host evidence and follow-up
  design work.

## Acceptance

- [x] `moui dev` can run a one-shot build and a watch/restart loop for generated
  projects; Web projects expose refresh and a readable compile-error page.
- [x] `moui_devtools` exposes structured Inspector sections and an overlay that
  can render them without reducing the existing snapshot APIs.
- [ ] Performance tooling records build/layout/paint/present samples and checks
  percentile budgets from a checked-in baseline format.
- [ ] Data views provide variable-height virtualization with stable anchors and
  grid-oriented selection/editing/semantics primitives while preserving current
  fixed-height APIs.
- [ ] Each slice is validated and committed before the next slice begins.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-22 | Use a Node runner for long-lived watch/restart behavior; keep MoonBit CLI parsing and project generation thin. |
| 2026-08-22 | Treat state serialization as an optional file-based hook, not in-process hot reload. |
| 2026-08-22 | Preserve existing public APIs and add opt-in Inspector/performance/data-view APIs. |

## Progress

| Date | Note |
|------|------|
| 2026-08-23 | `moui dev` CLI contract, generated project entrypoint, Node watch/restart runner, Web refresh/error overlay, and optional state-file hook implemented. |
| 2026-08-23 | Structured Inspector reports now expose View/Layout/Render/Semantics nodes, constraints, paint bounds, cache counters, event hit paths, effect/subscription lifecycle, JSON output, and a multi-line overlay. |
