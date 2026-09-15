# Plan: Relocate window scene resolution family to backend/common/lifecycle

- **Status**: done
- **Goal**: Move the `WindowSceneResolver` / `WindowSceneResolution` /
  `WindowOpenResolution` / `WindowSceneInstance` / `WindowResolvedOpen`
  family out of `moui/runtime` into `moui/backend/common/lifecycle` — the
  P10 owner of neutral window-open lifecycle that already holds the
  translation workflow and scene-resolver plumbing — so the runtime public
  surface no longer exports types only backend-side consumers use.
- **Non-goals**: driver-slot seam redesign (ADR 0027 lineage stays), moving
  the family to root `moui/backend` (blocked: `WindowSceneInstance.runtime`
  is an `AppRuntime`, which would violate P5), runtime subpackage split,
  API compatibility wrappers (0.2 unpublished; atomic migration per ADR 0027
  precedent).

## Background

- All five types hang on `WindowSceneInstance.runtime : @runtime.AppRuntime`;
  runtime itself never consumes them — producers and consumers are entirely
  backend-side (desktop backends construct instances, lifecycle slots resolve
  scenes and read `.instance.runtime`).
- `backend/common/lifecycle` already imports `runtime` (the sanctioned
  driver-slot seam) and `backend` (`@backend_host`), owns the
  `resolve_open_request` translation and `WindowRuntimeSlot::from_resolved_open`.

## Delivery sequence

1. Merge the five type definitions into
   `moui/backend/common/lifecycle/window_scene_resolution.mbt` (`AppRuntime`
   qualified as `@runtime.AppRuntime`); delete
   `moui/runtime/window_scene_resolution.mbt`.
2. Re-qualify consumers: desktop backends and backend/common root tests
   `@runtime.X` → `@window_lifecycle.X`; lifecycle-internal usages
   unqualified; `examples/multi_window` `@runtime.X` → `@backend_common.X`.
3. Regenerate interfaces (`moon info`), update
   `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt` (drop
   the deleted runtime-file entry) and the lifecycle mbti budget in
   `tools/moui/validate_api_surface/backend_common_budgets.mbt` (lifecycle
   absorbs the family; the runtime facade shrinks).
4. Update `docs/platform-host-contract.md`, platform notes, and roadmap
   references to the family; run the website doc sync.
5. Focused tests plus the static gate set.

## Acceptance

- [x] `moui/runtime` no longer declares the scene family; runtime compiles
  and tests pass (native, plus wasm-gc check).
- [x] `moon test` passes for `moui/backend`, `moui/backend/common/lifecycle`,
  and `moui/backend/{macos,windows,linux,web}`.
- [x] `examples/multi_window` builds; scene-type references go through the
  lifecycle alias.
- [x] Static gates pass: backend-common-boundary, api-surface,
  maintenance-baseline, host-import-baseline, root-facade-deps,
  generated-interfaces, fmt.
- [x] Docs referencing the family are updated and website sync is clean;
  guidance and doc-reference validators pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-16 | Destination is `backend/common/lifecycle`, not root `backend`: the family carries `AppRuntime` (`WindowSceneInstance.runtime`), and root backend must not import runtime (P5). Lifecycle is the P10 neutral-lifecycle owner and already holds the only translation code. |

## Progress

| Date | Note |
|------|------|
| 2026-09-16 | Feasibility verified: consumer inventory (12 files), alias survey, budget entries located. |
| 2026-09-16 | Family merged into `backend/common/lifecycle/window_scene_resolution.mbt`; runtime file removed; 19 consumer files re-qualified; budgets ratcheted (runtime facade mbti 864→745, backend pub(all) 104→108, runtime pub(all) 35→31, lifecycle mbti 255→320); docs + website synced; tests: runtime 127, backend 25, lifecycle 21, macos 37, windows 26, linux 25, web(wasm-gc) 39 — all green. |
| 2026-09-16 | Environmental caveats (pre-existing, unrelated): global `moon fmt --check` trips on the window dev-mode submodule members and `check-generated-interfaces` drifts on `moui/backend/common/input` + `moui_richtext` mbti under the local toolchain; scoped fmt and all migration-package interface checks pass. |
