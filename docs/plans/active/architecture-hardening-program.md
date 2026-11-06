# Plan: Architecture hardening program — host seam, API surface, extension points, text ownership, capability/diagnostics

- **Status**: active
- **Goal**: Resolve the 2026-11-06 architecture-review findings as a staged, evidence-gated program: one-way host orchestration, smaller `core`/`runtime` packages, an open service extension point, single-owner text caching, executable renderer capability policy, a unified diagnostic envelope, one async task semantics, and the product/governance follow-ups.
- **Non-goals**: no TEA/`View`/`ViewNode` rewrite; no renderer or platform reclassification; no new mobile readiness claims; no 1.0 stability promise; no independent module cadence; no UI feature work beyond migration fixtures.
- **Release vehicle**: `0.4.0` minor (declared breaking program under the pre-1 policy, no SemVer exception; `0.4.x` release-line ADR required). All slices land atomically in `0.4.0`; there is no `0.3.3` phase and no compatibility layer.

## Context

The 2026-11-06 architecture review found five structural gaps behind the `A-`
rating:

1. **Host seam inversion.** `moui/runtime/moon.pkg` imports `moui/backend` and
   `moui/render`; `moui/backend/common` imports `moui/runtime` in 13 files
   (`AppRuntime` 17 uses, `HostRuntimeDriver` 14 uses). The reverse edge is
   pinned by `checks/backend-common-ownership.json` and anticipated by
   structure trigger 19 in `docs/golden-principles.md`.
2. **Oversized contract packages.** `moui/core` is 134.6k lines / 668 files /
   ~1,114 `pub fn` / 146 importing package manifests; `moui/runtime` has ~597
   public symbols / 116 importing package manifests. The current trigger 18
   (`pkg.generated.mbti` > ~3.5k lines) does not measure fan-in or change
   coupling; `core` is at 2,720 lines today.
3. **Closed service extension.** `AppServices` is a fixed seven-field struct and
   `AppEnvironment` is a fixed four-field struct, while renderers use an open
   `RendererProvider` registry. Third-party services cannot participate in
   runtime task lifetime, cancellation, capability reporting, or test fakes
   without editing `moui/services`.
4. **Text cache ownership.** `moui/core/text_layout.mbt` owns the `TextSystem`
   protocol and routes paragraph layout through a process-global LRU in
   `moui/core/text_paragraph_cache.mbt` (`Map` + `Ref`, 16 MB budget, 4,096
   entries). Font registration bumps one global generation; every renderer's
   paragraph cache is invalidated. `moui/render/native_text/text_cache.mbt`
   already owns a per-renderer measure/layout/glyph cache, so the two layers
   overlap.
5. **Capability and diagnostics are descriptive, not executable.**
   `RendererProvider.capabilities()` and `RendererCommandFallback` exist, but
   `resolve_renderer` discards every `Rejected(String)` reason
   (`moui/render/common/provider_selection.mbt`), and `AppBuilder::run` aborts
   with a generic message (`moui/runtime/app_builder.mbt`). Diagnostics are
   split across runtime, renderer, image, IME, AT-SPI, and DevTools structs with
   no shared envelope or stable code catalog.

The remaining findings are product/governance-level: single-window
`AppRuntime` with host-level `WindowRequests`, a 25-module published portfolio
with a synchronized release line, and a hand-maintained architecture map that
does not verify its documented dependency edges.

## Relationship to existing plans

This is an umbrella program, not a replacement for the active plans that
already own parts of the surface:

- `architecture-review-followups` owns the renderer gate matrix, dirty-path
  work, overlay closure, and close-order evidence; W5 and W6 consume its
  outputs rather than reopening them.
- `cohesion-governance-convergence` owns file-level cohesion, helper dedup, and
  the first version of structure trigger 18; W2 upgrades that trigger and keeps
  its file-level splits as prerequisites.
- `backend-renderer-lifecycle-convergence` owns the backend-common owner split
  and the `RendererProvider`/`RendererSession` contracts; W1 changes only the
  remaining `backend/common -> runtime` edge and does not reopen those
  decisions.

## Release Vehicle

`0.4.0` is a declared breaking architecture program on the normal `0.x` minor
path. The pre-1 policy permits breaking changes when the release ships upgrade
notes and migration examples. No SemVer exception is recorded for this program.

The program has no compatibility layer: moved public symbols are removed from
their old package in the same release, and every in-tree call site plus the
external consumer fixture moves atomically. `0.4.0` still needs:

- a release-line ADR that moves the synchronized line from `0.3.x` to `0.4.x`
  (ADR 0055 currently pins `0.3.x`);
- every public module manifest and `checks/portfolio-governance.json` moved to
  `0.4.x` together;
- upgrade notes and migration examples for each removed or moved symbol;
- the external consumer gate across base, Skia, and Web profiles.

## Slice-to-release map

| Slice | `0.4.0` |
|---|---|
| W0 policy/ledger | release-line ADR + metadata |
| W1 host seam split | yes |
| W2 `core`/`runtime` split + trigger | yes, conditional on the multi-signal trigger |
| W3 service registry | yes |
| W4 text cache ownership | yes |
| W5 renderer capability plan | yes |
| W6 diagnostic envelope | yes |
| W7 async task semantics | code + scheduler convention |
| W8 product/governance | AppShell + graph tooling + portfolio proposal |

## W0 — Release-line governance

**Slices**

- W0.1 Record that `0.4.0` is the single release vehicle and that no SemVer
  exception or compatibility layer is used.
- W0.2 Keep `currentReleaseLine` at `0.3.x` until the release window, then move
  it to `0.4.x` with the rest of the synchronized line.
- W0.3 Before `0.4.0`, write the `0.4.x` release-line ADR that supersedes or
  amends ADR 0055.
- W0.4 At release time, move `checks/portfolio-governance.json` and every public
  module manifest to `0.4.x`; keep exact workspace pins synchronized.

**Acceptance**

- [ ] Policy page and JSON agree that `0.4.0` is a normal `0.x` minor breaking
      release with no exception ledger.
- [ ] `node scripts/validate-ecosystem-metadata.mjs` passes.
- [ ] The `0.4.x` ADR is accepted before any module advances.
- [ ] `node scripts/validate-portfolio-governance.mjs` passes at the `0.4.0`
      release window.

## W1 — Host seam split (`moui/apphost`)

**Slices**

- W1.1 Introduce `moui/apphost` and move `HostRuntimeDriver`,
  `AppBuilder`/`run_app`, redraw/present pump, frame clock, and close-request
  adaptation into it.
- W1.2 Make `moui/runtime` depend only on `moui/core` by moving host event and
  render orchestration out of the package.
- W1.3 Replace `backend/common`'s direct `AppRuntime`/`HostRuntimeDriver` imports
  with the `apphost` facade (re-export or explicit forwarding); flip
  `checks/backend-common-ownership.json` from an allowlist of runtime importers
  to a forbidden rule.
- W1.4 No compatibility layer: remove the moved symbols from `moui/runtime` in
  the same change, migrate every in-tree call site, and update the external
  consumer fixture at the release window.

**Acceptance**

- [ ] `moui/runtime/moon.pkg` no longer imports `moui/backend` or `moui/render`
      for orchestration.
- [ ] `backend/common` has zero production imports of `moui/runtime`; the
      ownership validator enforces it.
- [ ] The dependency graph is one-way: `host → runtime + backend + render`.
- [ ] `moon test moui/runtime`, `moui/backend/common`, and
      `moui_tests/tester` pass; host-sim, macOS Skia, and Web presentation
      smokes pass.
- [ ] Public API diff is reviewed with `moon info`; migration note documents the
      new canonical import path.

## W2 — `core`/`runtime` package split and multi-signal trigger

**Slices**

- W2.1 Replace trigger 18 in `docs/golden-principles.md` with a multi-signal
  condition (mbti lines, public symbol count, importing package count, change
  coupling, compile critical path).
- W2.2 Split leaf domains out of `moui/core` first (`geometry`, `draw`, `text`,
  `semantics`, `theme`, `view`), keeping `wzzc-dev/moui/core` as a `pub using`
  facade.
- W2.3 Split `moui/runtime` internals (`tree`, `layout`, `input`, `semantics`,
  `diagnostics`) behind the existing `AppRuntime` facade.
- W2.4 Record before/after compile time and importer counts; do not split a
  domain whose types would have to become public only to cross the new package
  boundary.

W2.2 and W2.3 execute only when the upgraded trigger fires. If it does not, the
deliverable is W2.1 plus the measurement note; do not pre-pay the split. This
keeps the program compatible with structure trigger 18's "review before growth"
rule.

**Acceptance**

- [ ] Trigger 18 fires on at least two independent signals, with measurement
      commands recorded.
- [ ] Existing app imports (`wzzc-dev/moui/core`, `wzzc-dev/moui/runtime`) keep
      working through facades.
- [ ] `node scripts/validate-api-surface.mjs` passes; `moon info` diff is
      reviewed and justified.
- [ ] `moon test` for both packages and the workspace examples passes.
- [ ] A short measurement note records compile-time and fan-in deltas.

## W3 — Open service extension point

**Slices**

- W3.1 Add `ServiceId[T]` / `ServiceProvider` / `ServiceRegistry` types with
  typed handles and versioned interfaces.
- W3.2 Recast the seven built-in service groups (`files`, `clipboard`, `urls`,
  `settings`, `appearance`, `menus`, `platform`) as default providers;
  `AppServices` becomes a facade with the existing typed getters.
- W3.3 Register service providers in `HostCapabilitySummary` so apps can
  preflight availability.
- W3.4 Add one external test service in `moui_tests` or
  `checks/external-consumer` that is registered without editing
  `moui/services`.

**Acceptance**

- [ ] A third-party service works end-to-end without a core/services edit.
- [ ] Existing `AppServices` getters and constructors remain source-compatible.
- [ ] Unavailable services return a typed `Unavailable` result, not an abort.
- [ ] Service task cancellation and diagnostics follow the W7 convention.
- [ ] External consumer base profile passes.

## W4 — Text cache ownership

**Slices**

- W4.1 Move paragraph caching, LRU policy, and the byte budget out of
  `moui/core` into `moui/render/native_text` or a renderer-session-owned
  `TextLayoutService`.
- W4.2 Make font-registration invalidation session-scoped; remove the global
  `text_paragraph_cache_font_generation`.
- W4.3 Define the text stage contract:
  document/edit model (`core` / `richtext`) → paragraph layout
  (`render/native_text`) → shaping/font provider (`moui_text_providers`) →
  glyph raster (renderer).
- W4.4 Add locale/bidi/RTL to the layout input contract instead of leaving it
  to provider inference.
- W4.5 Land the slice in `0.4.0` with the renderer/factory rewiring and
  memoization counters; do not ship a `TextSystem` signature change without the
  owner-local cache in the same release.

**Acceptance**

- [ ] No module-level mutable cache remains in `moui/core`.
- [ ] Two windows/renderers with different font registration do not invalidate
      each other's paragraph cache.
- [ ] Cache-budget tests do not mutate process globals.
- [ ] `moon test moui/core`, `moui/render/native_text`,
      `moui_skia_renderer`, and `moui_richtext` pass.
- [ ] `docs/text-system.md` records the stage ownership and invalidation rules.

## W5 — Executable renderer capability plan

**Slices**

- W5.1 Change `resolve_renderer` to return a `RendererResolution` carrying the
  bound session, ordered `RendererRejection` reasons, and a capability plan.
- W5.2 Add `AppBuilder::require_features` / `allow_partial` policy; emit a
  structured startup report before any abort.
- W5.3 Generate the capability report from provider descriptors and keep
  `docs/renderer-capability-report.md` synchronized by validator.
- W5.4 Add conformance tests for: all providers reject, a required feature is
  `Gap`, a `Partial` feature is allowed, and a fallback provider wins.

**Acceptance**

- [ ] No `Rejected(String)` is silently discarded.
- [ ] A missing required feature fails at startup with provider-by-provider
      reasons.
- [ ] `allow_partial` surfaces a warning and a stable diagnostic code.
- [ ] Capability report and provider descriptors cannot drift.
- [ ] macOS Skia and Web Canvas2D fallback smokes pass.

## W6 — Unified diagnostic envelope

**Slices**

- W6.1 Define `DiagnosticEvent` (code, severity, domain, generation/frame,
  message, remediation) and a stable code catalog.
- W6.2 Add one bounded sink used by runtime, render, backend, text, and
  DevTools.
- W6.3 Migrate the existing ad-hoc diagnostic structs for covered cases;
  keep domain-specific detail as payload, not a second envelope.
- W6.4 Let DevTools and the Agent/MCP surface read the same events.

**Acceptance**

- [ ] A stable diagnostic code exists for renderer gap/fallback, image failure,
      IME failure, service unavailable, and lifecycle close errors.
- [ ] Tests assert codes and severities, not just messages.
- [ ] The sink is bounded and cannot grow per frame without eviction.
- [ ] DevTools shows the same event stream used by tests.

## W7 — Async task semantics

**Slices**

- W7.1 Write the ownership/cancellation matrix for `Effect`, `Subscription`,
  `ServiceTask`, `TimerSource`, `RouteSource`, image requests, and the GPU
  worker control queue.
- W7.2 Introduce a shared `TaskScope` / `CancelToken` / generation convention
  without forcing one runtime type.
- W7.3 Define teardown order: window close → subscriptions → effects/tasks →
  in-flight images → renderer session dispose.
- W7.4 Add a deterministic virtual scheduler and order tests for native and
  embedded detach/recreate paths.

**Acceptance**

- [ ] The matrix is linked from `docs/tea-program-model.md` and the host
      contract page.
- [ ] Teardown-order tests cover native and embedded lifecycle.
- [ ] No callback can complete after its owning scope is cancelled.
- [ ] `effect_task_supersession`, image completion, and subscription cancel
      tests share the same generation rule.

## W8 — Product and governance follow-ups

**Slices**

- W8.1 Multi-window: write an `AppShell`/`WindowProgram` ADR or plan; prototype
  the smallest useful addon without changing single-window `AppRuntime`.
- W8.2 Release portfolio: propose collapsing or unpublishing lab/tiny modules;
  update `checks/release-modules.json`, `checks/portfolio-governance.json`, and
  release docs together.
- W8.3 Generate the package dependency graph from `moon.pkg` files; add a CI
  drift check against the edges documented in `docs/architecture-map.md`.

**Acceptance**

- [ ] AppShell has an accepted ADR or a rejected-with-rationale decision.
- [ ] Portfolio proposal lists every moved/retired module and its migration.
- [ ] The generated graph matches the documented architecture edges, or the
      validator reports the exact drift.
- [ ] No release module changes without closure and external-consumer gates.

## Execution order

1. **Release train (`0.4.0`):** W0.3-W0.4, W1, W2, W3, W4, W5, W6, W7, W8.1-W8.2.
   All slices land before the version bump; no intermediate release.
2. **Release window:** move `moui_studio/moon.mod`, `generated_dependency_versions`,
   `moui_cli` default dependency versions, and the generated CLI/Studio
   templates from the 0.3.2 runtime API to `moui/apphost` atomically with the
   0.4.0 manifests.
3. **Post-`0.4.0`:** measure the result and decide whether a `1.0` stability
   promise is justified.

W1 should land before W2 so `runtime` is split while it no longer owns host
orchestration. W4 should land before the `core` split so the global cache does
not move into a facade. W3, W5, W6, and W7 are independent after W1.

## Validation gates

Per slice:

```sh
moon check <package>
moon test <package> --target native
moon info <package>   # when public API changes
```

Program-level:

```sh
sh scripts/check.sh --profile pr
sh scripts/check.sh --profile daily
sh scripts/check.sh --profile platform
node scripts/validate-api-surface.mjs
node scripts/validate-release-module-closures.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-doc-references.mjs
node scripts/validate-ecosystem-metadata.mjs
node scripts/external-consumer-ci.mjs --source package --profile base
```

Path-triggered evidence: macOS Skia smoke, Web presentation, and the embedded
host-sim suite for any lifecycle change. Do not claim mobile readiness from host
simulation.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Moving public types across packages changes type identity or import paths | Keep `pub using` facades; no deprecated re-exports; review `moon info` diff |
| `backend/common` still needs runtime types after the host split | Use the `apphost` facade (re-export or explicit forwarding); if impossible, extend the ADR and the trigger-19 review, not the allowlist |
| `core` split exposes internals as `pub` | Split only leaf domains; keep cross-domain types in the facade; reject splits that widen the public surface |
| Service registry needs type erasure | Use a typed key plus a bounded boxed payload, following the existing `ViewStateValue` type-key precedent |
| Text cache move changes behavior | Keep `TextSystem` signatures stable and prove memoization with counter tests before removing the core cache |
| Release-line validator fails during the `0.4.0` window | Move `portfolio-governance.json` and all public manifests in one commit; run the portfolio validator before merging |
| Scope creep across nine workstreams | Each workstream has its own acceptance and can ship independently; do not batch unrelated slices into one PR |

## Decision log

| Date | Decision |
|---|---|
| 2026-11-06 | Program created from the architecture-review findings. |
| 2026-11-06 | All architecture slices land atomically in `0.4.0`; the `0.3.3` phase is removed. |
| 2026-11-06 | `0.4.0` uses the pre-1 minor breaking path, not a SemVer exception; it requires a `0.4.x` release-line ADR, upgrade notes, migration examples, and the external consumer gate. |
| 2026-11-06 | No compatibility layer: moved symbols are deleted from their old package in the same release, and every in-tree call site moves atomically. |

## Progress

| Date | Note |
|---|---|
| 2026-11-06 | Plan created; compatibility policy ledger and machine-readable metadata updated. |
| 2026-11-06 | Reconciled to the approved 0.4.0-only, no-compatibility-layer execution decision; `moui/apphost` is the chosen package name. |
| 2026-11-06 | W1 code extraction landed: `moui/apphost` owns the host pump, `moui/runtime` production imports only `moui/core`, `backend/common` uses the apphost facade, and the workspace compiles. CLI/Studio generated bundles stay pinned to the published 0.3.2 API until the 0.4.0 version bump. |
| 2026-11-06 | W1 gates green: `pr` profile passes, `validate-backend-common-boundary`, `validate-host-import-baseline`, `validate-backend-renderer-boundary`, `validate-api-surface`, and `validate-maintenance-baseline` pass. `moui/runtime` mbti is 787 lines / 515 pub / 19 pub(all); `moui/apphost` is 189 / 94 / 5. |
| 2026-11-06 | W4 landed: `moui/core/text_paragraph_cache.mbt` deleted; `moui/render/common` owns `TextParagraphCache` with owner-local font generation and budget; Skia/Sun/native_text/Web/Canvas2D/TUI factories install it. Core/views/richtext/renderer tests pass, including a new text-area memoization regression. |
| 2026-11-06 | W3 landed: `ServiceExtension` + `AppServices::extensions`/`extension`/`extension_capability_labels`; `HostServiceCapabilities.extension_labels` feeds `enabled_labels`; service/backend extension tests pass. |
| 2026-11-06 | W5 core landed: `RendererCapabilityPlan`, `RendererRejection`, `RendererBindingResolution`, `resolve_renderer_with_plan`, `RendererCapabilityPolicy`; apphost logs ordered rejection reasons and rejects duplicate provider ids. Platform bindings now call the apphost resolution wrapper; per-platform policy evaluation remains. |
| 2026-11-06 | W6 foundation landed: `moui/core/diagnostics` envelope/sink, `RenderFrameResult.diagnostics`, diagnostics docs. Producer migration (TUI degrade, image/GPU/recovery, embedded wire) and DevTools/Showcase consumption remain. |
| 2026-11-06 | W7 contract landed: `docs/task-lifecycle.md`; `TaskScope`/`CancelToken` code adoption, virtual scheduler, and teardown-order tests remain. |
| 2026-11-06 | W5 release slice: `AppBuilder::capability_policy` now preflights required features across the provider list and aborts with named problems; `policy_problems` accepts a surface-free plan. Per-platform surface policy remains the next refinement but is no longer required for a valid startup failure. |
| 2026-11-06 | W6 release slice: Skia/Sun unsupported-command diagnostics and TUI degrade records now populate `RenderFrameResult.diagnostics`; `RenderFrameResult` carries the shared envelope. Image/GPU/recovery and embedded-wire migration remain 0.5.0. |
| 2026-11-06 | W7 release slice: `TaskScope`/`CancelToken` land in core; `ServiceTask` accepts an optional scope, drops completions after cancel, and preserves the scope through `map`. Image/GPU adoption and the virtual scheduler remain 0.5.0. |
| 2026-11-06 | W8 release slice: ADR 0064 defers first-class AppShell to 0.5.0; ADR 0065 supersedes 0055 with the synchronized 0.4.x line; `docs/compatibility-matrix.md` records intents and base pins; all public module manifests and workspace pins are 0.4.0; CLI/Studio generators pin 0.4.0 and emit `moui/apphost`. |
| 2026-11-06 | Pre-release validation: workspace check, `pr` profile, API surface, release closures, backend/common/host boundaries, docs, and website catalog are green before the version bump. |
