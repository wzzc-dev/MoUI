# Plan: MoUI tier, TEA, entrypoint, and documentation debt convergence

- **Status**: active
- **RFC**: [0002](../../rfcs/0002-tiered-platform-tea-services.md)
- **Goal**: Establish one platform-tier source of truth, restore strict TEA app
  boundaries, reduce composition-root count and size, and close stale guidance
  and plan debt without weakening existing evidence claims.
- **Non-goals**: Promote Tier 3 readiness, fabricate matching-device evidence,
  or add renderer capabilities.

## Decisions

| Date | Decision |
|---|---|
| 2026-08-04 | Tier 1 = macOS Skia + Web; Tier 2 = Windows/Linux Skia; Tier 3 = desktop WGPU, mobile Skia, desktop Sun, and WeChat. |
| 2026-08-04 | Showcase covers all 14 routes; product examples may expose additional matrix routes, within the composition-root budget. |
| 2026-08-04 | Tier 3 evidence is non-blocking. |
| 2026-08-04 | App business state converges to strict TEA; local control state remains allowed. |
| 2026-08-04 | Breaking migration; no long-lived compatibility shell. |
| 2026-08-04 | Moon only exports executable-owned wasm definitions; fixed Web/WeChat `abi.mbt` shims replace the proposed `pub using`-only form and are closed by P1 validation. |

## Workstreams

1. Archive completed/superseded plans and mechanize plan-index consistency.
2. Add the 14-route platform matrix and derive validators/guidance from it.
3. Add `moui/services`, typed Program commands, and platform adapters.
4. Migrate Showcase and Markdown Editor service/command boundaries.
5. Remove duplicate/non-canonical roots and enforce entrypoint budgets.
6. Sync docs, skills, generated interfaces, and validation profiles.

## Acceptance

- [x] `checks/platform-matrix.json` contains exactly 14 canonical routes.
- [x] Showcase contains exactly those 14 routes and no duplicate provider-specific WGPU root.
- [x] UI composition roots stay within the repository budget.
- [x] Native entrypoint code is at most 50 lines; Web/WeChat at most 40.
- [x] `examples/*/app` production imports contain no runtime/backend/render.
- [x] App commands dispatch typed messages rather than mutating app state.
- [x] Active plan files, statuses, and `docs/plans/README.md` agree.
- [x] Root, Chinese, and website guidance use the same tier matrix.
- [x] Focused tests and `pr`, `daily`, and `platform` profiles pass on the current macOS host.

## Progress

| Date | Note |
|---|---|
| 2026-08-04 | Plan and RFC accepted; registry dependency baseline restored. |
| 2026-08-04 | Archived six completed/superseded plans and added active/done status plus README index consistency validation. |
| 2026-08-04 | Isolated static MoonBit tools in `tools/moon.work`; moved the product-coupled renderer capability validator to `tools_product`. |
| 2026-08-04 | Replaced the four-path window dependency allowlist with recursive discovery of every repository-owned `moon.mod`; seven consumers now resolve `wzzc-dev/window@0.5.4-0.1.6`. |
| 2026-08-04 | Added the 14-route matrix, generated Tier tables, matrix-driven entrypoint discovery, composition-root/two-file/50-or-40-line budgets, and fixed Web/WeChat ABI-shim validation. |
| 2026-08-04 | Added `moui/services`, typed Program commands, backend adapters/fakes, and strict TEA migrations; removed root `run_app`, app-facing host bridge APIs, and direct action mutation paths. |
| 2026-08-04 | Converged Showcase, Markdown Editor, Multi Window, and WebView Demo through module-root integration facades, removed duplicate WGPU Cosmic roots, and reduced retained entrypoint `main.mbt` files to their platform budgets. |
| 2026-08-04 | Current-host focused suites plus `pr`, `daily`, and `platform` pass; all 14 Showcase packages pass their declared-target static check/build. |

## Remaining Evidence And Release Work

- Windows and Linux Tier 2 L2 plus first-frame evidence still requires each
  matching host. The macOS `platform` run skips those checks by design.
- Mobile matching-device L3, WeChat matching-client L3, and Tier 3 diagnostic
  presentation remain scheduled/manual and non-blocking.
- The final `0.1.x` breaking release is an external release action and has not
  been cut by this implementation session.
