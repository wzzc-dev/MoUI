# Plan: Architecture priority execution — incremental core, component boundary, and extension discipline

- **Status**: done
- **Baseline**: HEAD `1cd3f90db` (2026-11-05), 0.3.x release line
- **Inputs**: three 2026-11-05 architecture reviews: an
  implementation-first optimization scan, a mature-framework comparison, and a
  component/state architecture review. All three are treated as evidence, not as
  separate competing roadmaps.
- **Goal**: Land the common conclusions as a staged, evidence-gated program:
  make update/render caching correct and measurable; remove the remaining
  whole-tree and whole-surface work from the normal path; decide and, where
  justified, add a TEA-compatible component-scoped lifecycle/state contract;
  and make extension, route, release, and status-document handling explicit.
- **Non-goals**: no hidden mutable `ComponentContext`/`State`/`Binding`/
  `DerivedState` or arbitrary Model setters; no package-level split of
  `moui/core`/`moui/runtime` before the existing structure trigger; no
  `ViewNode` trait decomposition or `RendererSession` trait rewrite; no new
  renderer route or dynamic plugin ABI; no promise of in-process state-preserving
  hot reload in this plan; no platform readiness promotion without matching-device
  evidence.

## Background

The three reviews converge on the same execution problem. MoUI's package
boundaries, provider negotiation, backend ownership, validators, and evidence
pipeline are already strong. The remaining high-leverage work is not another
package reorganization. It is making the normal update path incremental,
measurable, and explicit about its fallbacks.

The existing plans already own several adjacent scopes and must not be
reopened:

| Existing plan | Relationship |
|---|---|
| [architecture-review-followups](architecture-review-followups.md) | B0-B4 already landed the dirty-id index, one-pass damage index, and deep-tree baseline. Its A/C/D workstreams remain owned there. This plan starts from that result. |
| [cohesion-governance-convergence](cohesion-governance-convergence.md) | Owns package cohesion and the core-split/structure triggers. This plan must respect those triggers rather than start a new split. |
| [pointer-input-parity](pointer-input-parity.md) | Owns declared-but-inert input fixes, scroll semantics, multi-pointer, selection, and RTL mirroring. Gesture-arbitration and scroll-transform work must extend its tests. |
| [harmonyos-scroll-frame-pacing](harmonyos-scroll-frame-pacing.md) | Provides the matching-device evidence for scroll cache misses and full-surface present cost. Its deferred scroll-rebuild work feeds this plan. |
| [full-surface-redraw-per-frame](../debt/full-surface-redraw-per-frame.md) | This plan absorbs the debt into W2; do not maintain a second full-surface roadmap. |
| [view-node-trait-refactor](view-node-trait-refactor.md) | Provides the low-level custom-control protocol. W3 builds a control SDK above it and does not reopen the trait design. |

## Consolidated findings at baseline

| Finding | Evidence at baseline | Confidence | Owner |
|---|---|---|---|
| Render caching is effectively disabled outside the default static environment | `matches_default_cache_key` requires neutral environment/style, fallback text system, scale/text scale 1, `en-US`, LTR, standard contrast, no reduced motion, medium content size, and `now_ms == 0.0` (`moui/runtime/render_environment.mbt:86-103`). Host `FrameTick` writes a non-zero time and the paint path forwards it (`moui/runtime/runtime_events.mbt:112`, `moui/runtime/runtime_render_pipeline.mbt:296`). The budget catalog records `cacheHitRate` 0 in four scenarios and 0.0417 in Showcase (`checks/performance-budgets.json`). | Confirmed | W1.1 |
| Every program message requests a root rebuild, before reconciliation can localize layout/paint | `AppRuntime` calls `request_root_rebuild()` after every program update (`moui/runtime/runtime.mbt:119`); `rebuild_if_possible` re-runs the root builder (`moui/runtime/runtime_state.mbt:472-487`). | Confirmed | W1.2 |
| `View::map` recreates an adapter and recursively maps its children, so each nested scope amplifies construction cost | `ViewAdapter::map` maps `semantics_action_handlers` and every child adapter (`moui/core/view_node.mbt:258-300`). The deep-tree benchmark already separates one and two map layers (`benchmarks/full_cycle/native/main.mbt:85-95`). | Confirmed | W1.3 |
| The normal message path forces full-surface damage, so precise damage cannot reach the renderer | `request_root_rebuild` sets `full_damage_reason` (`moui/runtime/runtime_state.mbt:503-516`); `compute_damage_region` returns `DamageRegion::full` immediately for that reason and also when the dirty list is empty (`moui/runtime/runtime_render_pipeline.mbt:351-365`). | Confirmed | W2.1 |
| The baseline Skia raster route always resolved to full-surface presentation | At baseline, `SkiaRasterRenderer::resolve_effective_damage` returned `FullSurface` unconditionally. W2.2/W2.4 now provide an opt-in `SubRect` CPU-raster path and content-local scroll frames, but every production host still negotiates `FullSurfaceOnly`. HarmonyOS evidence records 2090×1324 full-surface work during scroll (`docs/plans/active/harmonyos-scroll-frame-pacing.md`). | Confirmed at baseline; host capability still full | W2.2-W2.3 |
| Scroll bakes the offset into absolute child frames, so descendant caches miss on every scroll tick | `ScrollContainer::layout` calls `scroll_child_frame` with the runtime offset (`moui/views/controls/scroll_view_layout.mbt:242-258`, `:876-897`). HarmonyOS captures show 648-1906 misses versus about 24 hits. | Confirmed | W2.4 |
| Component-scoped persistent state and lifecycle are deliberately absent | `Feature::scope` is a pure lens composition and `docs/tea-program-model.md:175-186` records that it introduces no lifecycle, binding, context, or mutable holder. `docs/zh-Hans/architecture.md:293-306` states there is no second component lifecycle state machine. This is a product/API decision, not an accidental omission. | Confirmed absence; impact hypothesis | W0.5, W3 |
| Extension and release surfaces are broad relative to the current product boundary | There are 14 canonical routes, 5 marked ready, and 6 experimental in `checks/platform-matrix.json`; `checks/release-modules.json` lists 25 public modules. `DrawCommand` remains a closed union and `RendererSession` remains a closure record (`docs/plans/debt/renderer-session-closure-style.md`). | Confirmed counts; ecosystem impact hypothesis | W3.4, W4.1-W4.2 |
| Performance and status governance are not yet enforcing the claimed architecture | Benchmark failures are currently non-blocking on shared runners (`docs/testing.md:412`), several budgets are conservative placeholders, and status pages still disagree on component and HarmonyOS state (`moui/README.mbt.md:17-18`, `docs/roadmap-2026.md:63-66`, `docs/platform-readiness-declaration.md:33`, `docs/feature-status-dashboard.md:104`). | Confirmed | W0.1-W0.4, W4.3 |

### What remains a hypothesis

- Whether the missing component-local state is the main adoption blocker, or
  only a first-party ergonomics issue. The answer depends on whether third-party
  stateful controls are a product goal.
- Whether leaf-only updates on 1k/10k-node trees remain dominated by build
  allocation after the cache and map fixes. Existing deep-tree scenarios use
  environment invalidation and cannot separate root rebuild from genuine dirty
  work.
- Whether partial presentation produces a material win on each platform after
  compositor policy is included. The 2026-11-05 HarmonyOS device evaluation
  found no eligible partial frame and no full-surface present-budget miss, so
  every host stays on the full-surface fallback until both prerequisites are
  measured.
- Whether independent release cadence for 25 modules reduces friction or merely
  adds compatibility-matrix maintenance. External consumer data is required.

## Sequencing principles

1. Correctness and measurement before public API. A cache or damage change must
   be proven with mismatch/stale-pixel tests before a component API is designed.
2. Cache-key correctness precedes memoization. A memo on top of a cache that
   never hits would hide the real cost without fixing the invalidation model.
3. Damage precision precedes partial presentation. The renderer must not receive
   an under-covered damage region just because a platform can accept one.
4. Content-coordinate scroll work comes after the cache-key vocabulary is
   explicit. Otherwise the new coordinate model would immediately be invalidated
   by the old environment key.
5. Component-local state is a decision-gated product contract, not an assumed
   implementation detail. The default bias is Feature-first; a runtime-owned
   state store requires an RFC with snapshot, restore, and multi-instance
   semantics.
6. Portfolio and status work runs in parallel because it is inexpensive and
   prevents the architecture from drifting while the hot path is being rebuilt.

## Delivery order

| Order | Slice | Exit evidence |
|---|---|---|
| 1 | Close W1.1 and land W0.1-W0.3 measurement | Themed/scaled cache-key coverage, production-like benchmark, leaf-only 1k/10k scenario, scroll cache counters, and one stable blocking update budget |
| 2 | Land W1.2a/W1.4 and record W1.2b/W1.3 blockers | Explicit memo, build/cache diagnostics, and an explicit builder-key/map decision; no false structural claim |
| 3 | Land W0.5 and W2.1-W2.3 | Explicit invalidation classes, no-op message to `Empty`, surface damage capability defaulting to full, and a passing pixel-coverage self-check |
| 4 | Land W2.4 | Content-coordinate scroll with place/render cache hits across ticks; pointer, focus, caret, overlay, semantics, RTL, and scroll-target parity remain green |
| 5 | Land W3.1 and close W3.2 via W0.6; then land W3.3 | Scoped lifecycle isolation passes; Feature-first component-state boundary recorded; pointer-arbitration tests pass |
| 6 | Run W0.7 and W4.1-W4.3 in parallel; land W3.4 after the component decision | Route/module ownership, release-coupling decision, generated status blocks, and the custom-control SDK are current |
| 7 | Land W4.4 over the existing inspector snapshots | A bounded trace exposes execution-model deltas without adding runtime ownership or payload capture |

## Program state

The original W0-W4 program is complete. W2.3b was evaluated on a matching
HarmonyOS device and closed as evidence-backed non-adoption. N1-N3 are closed
decisions, not open work:

- N1/W1.2b is closed by ADR 0057. The explicit builder/content-key primitive
  and app-adoption boundary are recorded; no first-party app has both a
  measured repeated-builder cost and a maintainable complete key.
- N2/W1.3 is closed with a negative implementation decision. The recursive
  typed adapter remains until the language can express the hidden source
  message safely (ADR 0058).
- N3 is complete. The keyed multi-instance pilot confirms ADR 0053 without
  adding a runtime component store.
- W0.3 is satisfied by a blocking, machine-independent structural gate; timing
  remains report-only pending the dedicated runner that will enforce it.
- W2.3b is closed without enabling EGL partial presentation. The matching
  device produced only full-surface frames, present cost was already low, and
  the frame budget was not missed. This is a measured non-adoption, not a
  waiver; the concrete reopen conditions are recorded below.
- N5 is complete. The Showcase shell no longer writes transient scroll offsets
  into the model; wheel and drag scrolling leave the program update count and
  activation rebuild count unchanged. Full-surface damage remains because the
  scroll path is still layout-dirty, but the activation cause is gone.
- N4 remains parked and must not become a second roadmap.

## Next development plan

This stage is a bounded completion program. N3 has validated the already-accepted
Feature-first component boundary and W0.3/W2.3b have closed their evidence
gates. N5 targets the remaining normal-path root rebuild during scroll before
any further presentation work.

| Order | Slice | Start condition | Work | Exit evidence |
|---|---|---|---|---|
| 1 | N3 component pilot | Done | Extend `examples/custom_control` into a keyed multi-instance feature with parent-owned state, `Feature::scope` identities, an app-owned snapshot DTO, and focused isolation tests. Record the ergonomics cost and any missing framework capability. | Two keyed counters prove edit isolation, lifecycle isolation, reorder/removal behavior, and snapshot round-trip with no hidden mutable state. The pilot confirms ADR 0053 and records the explicit lens/snapshot/id-cursor friction as acceptable for the current product scope. |
| 2 | N0/W0.3 structural gate | Done | Pin the benchmark identity and retain repeated artifacts. Promote a machine-independent build/cache counter budget before promoting wall-clock timing. | One structural update budget blocks in the applicable profile; runner identity, repetitions, variance, and ratchet policy are recorded. Timing remains report-only until a dedicated enforcing runner meets the variance rule. |
| 3 | N0/W2.3b device evidence | Closed 2026-11-05 | Build the current Showcase HAP, capture a matching-device scroll, inspect damage reasons and cache counters, and compare present/pacing with the requirement for any partial-present work. | The matching-device decision is recorded with artifacts and reopen criteria. EGL stays `FullSurfaceOnly`; no device pixel-equality claim is made because partial presentation was never eligible. |
| 4 | N5 transient scroll and damage localization | Done 2026-11-05 | Remove app-owned transient scroll offsets/callbacks from the Showcase shell, rely on element-owned `ScrollRuntimeState` plus explicit route-reset requests, and measure the resulting rebuild/damage behavior before touching the presenter. | Pointer scrolling no longer dispatches a model message or activation rebuild. Two identical structural runs reduce Showcase layout misses from 693 to 279 and render misses from 522 to 108 over 60 frames. Wheel damage is now `layout changed`; drags fall back to `damage accumulated across paint passes`, so rect damage and EGL partial presentation remain unimplemented. |
| 5 | N4 follow-up charters | After N5 records its result | Scope trace UI/replay, state-preserving reload, native accessibility, and new renderer routes as separate plans when product evidence warrants them. | Each has an owner, evidence requirement, and explicit non-goals; none expands `moui/core` or `moui/runtime` implicitly. |

### Execution rules

- N3 makes no public framework API change by default. A runtime or core change
  is allowed only if the pilot exposes a concrete defect, and then must be the
  smallest test-led fix.
- Feature-first remains the accepted boundary. If the pilot shows excessive
  plumbing, record the evidence and open a separate component-store RFC; do not
  silently add a runtime store, hidden `ComponentContext`, or saveable element
  slot.
- Performance gates use structural counters first. A shared-runner timing
  sample cannot become blocking without the W0.3 runner and variance evidence.
- W2.3b is closed by matching-device non-adoption. Unsupported hosts keep
  `FullSurfaceOnly`; do not add EGL partial-swap code until both runtime rect
  damage and a measured full-surface frame-budget miss exist, and the device
  advertises the required EGL damage/preserved-buffer extensions.
- N5 changes app ownership before runtime classification. A runtime damage
  change is allowed only after the transient-scroll path is measured; it must
  be the smallest test-led change and must retain the ADR 0050 fail-closed
  rules.
- N4 work starts only from a separate charter; it is not part of this plan's
  completion path.

### Milestones

| Milestone | Deliverable | Decision |
|---|---|---|
| M1 — prove the component model | Done: N3 pilot and tests, plus W0.3 runner instrumentation | Feature-first remains sufficient for reusable multi-instance features. |
| M2 — earn the gates | Done: N3 ergonomics record, blocking structural budget, and matching-device W2.3b evaluation | Timing, partial presentation, and device pixel claims are limited to what the evidence supports. |
| M3 — localize scroll | Done: N5 removes activation rebuilds and records two identical structural runs | The normal Showcase scroll path no longer causes root activation work; layout/full-surface work remains explicitly classified. |
| M4 — close or split | Close this plan after the final `pr` gate; keep hardware-specific partial presentation under the HarmonyOS/ADR 0050 reopen gates | Do not leave an architecture plan open on speculative optimization. |

### N1 — Explicit scoped construction contract

The contract must answer:

- What identity names a reusable subtree: a stable caller key, a model-derived
  key, or an explicit parent-owned slot?
- What is invalidated: only the selected subtree's construction, or also its
  mapped children and semantics handlers?
- How do keyed collections, conditional branches, environment/theme changes,
  text-system changes, and captured event payloads invalidate the entry?
- How does the root TEA projection remain the single view-building boundary?
- Why can an under-declared key produce a visible behavioral failure that
  conformance tests catch, without relying on implicit read tracking?

The default design biases remain: one application state loop, no runtime
component store, no hidden `ComponentContext`, and no automatic equality of
arbitrary closures. ADR 0057 accepts `ViewBuilderCache` for multi-entry keyed
slots; `ViewMemo` remains the single-entry primitive.

Acceptance for N1:

- [x] An accepted RFC exists before any public or runtime integration change.
      ADR 0057 defines the stable builder key, complete content key, manual
      removal/clear lifetime, and the no-runtime-state boundary.
- [x] A 1k/10k leaf-update benchmark shows unrelated sibling builders are not
      called. The structural assertion fails if the changed leaf plus container
      are not the only builders invoked.
- [x] The construction-clone boundary is decided rather than conflated with
      builder skipping. Recursive `View::map` adapter copies remain; N2/ADR 0058
      records why the safe transform-chain implementation is unavailable.
- [x] Ordinary app adoption is evidence-gated. No app with both a measured
      repeated-builder cost and a maintainable complete key was found, so the
      primitive stays in advanced core and the program-factory ownership
      pattern is documented in ADR 0057.
- [x] Keyed reorder, conditional replacement, map/semantics lifting, theme
      invalidation, and captured event-payload replacement have core regression
      coverage. Effect/subscription scope isolation remains covered by the
      existing runtime W3.1 suites and is unchanged by this construction-only
      cache.
- [x] The implementation adds no second mutation path, hidden state, global
      registry, or saveable component registry.

### N2 — Type-safe map transform design

The spike must compare at least three implementations: a typed transform chain,
a generated/reified adapter, and retaining the recursive adapter as the
fallback. The bounded outcome is intentionally allowed to be negative.

Acceptance for N2:

- [x] The typed transform chain, generated/reified adapter, and retained
      recursive adapter were compared.
- [x] A safe implementation is ruled out for the current compiler: a trait
      object cannot expose a polymorphic remap method (E4038), associated
      source-message types are not supported, and the recursive adapter is the
      only implementation preserving typed event, text-command,
      semantics-action, and child mapping without unsafe erasure.
- [x] The native leaf benchmark records deterministic adapter-copy deltas at
      one and two map layers; wall-clock timing remains report-only because the
      shared-host variance is larger than the measured map-layer delta.
- [x] No lazy-only claim was made. ADR 0058 records the rejected designs, the
      compiler evidence, and the retained recursive adapter.

### N0 — Evidence gates

N0 work may run in parallel with N3. Missing runner or device access must block
the corresponding budget or platform claim, not the component-model design work.

Acceptance for N0:

- [x] W0.3 records the dedicated-runner requirement, repeated benchmark
      artifacts, and the variance rule used to promote a timing budget. No
      dedicated timing runner exists yet, so timing remains report-only.
- [x] W2.3b records a matching-device HarmonyOS/EGL evaluation and closes on
      evidence-backed non-adoption. No `SubRect` capability is enabled, so no
      device pixel-equality claim is made.
- [x] Structural review counters can gate on a shared runner earlier than
      wall-clock timing; unsupported hosts keep `FullSurfaceOnly`.

### N3 — Component ergonomics validation

ADR 0053 already decided that persistent component state remains Feature-first.
This slice tests that decision rather than silently reopening it.

The primary pilot is `examples/custom_control/app`: turn its single editable
counter into two or three keyed counter instances while keeping every committed
value in the parent TEA model. Settings remains the reference for the explicit
snapshot codec; it is not a second pilot.

Planned shape:

- A stable `CounterId` and a plain child counter model form a keyed collection
  owned by the parent Model. Add, remove, reorder, and edit stay typed `Msg`
  cases; no element-owned persistent state is introduced.
- Each instance is composed with
  `Feature::scope(scope_id="custom-control/<id>", ...)`. Instances may use the
  same local Effect/Subscription key; the scope id must keep their lifecycle
  entries independent.
- The app defines its own snapshot DTO and restore function. Snapshot identity,
  order, values, and edit counters round-trip explicitly; runtime slots remain
  interaction transients and are never serialized.
- Tests cover editing one instance without changing another, removing/reordering
  instances without losing the wrong values, sibling lifecycle isolation,
  snapshot round-trip, unique semantic ids, and the absence of hidden mutable
  component state.
- The pilot records an ergonomics checklist: lens/update plumbing, snapshot
  boilerplate, repeated builder work, root-model growth, diagnostic visibility,
  and any repeated manual step that a component store would remove.

Acceptance for N3:

- [x] One reusable multi-instance feature demonstrates parent-owned state,
      model-keyed instances, scope lifecycle, and app-owned snapshot restore.
      `examples/custom_control/app` owns two initial keyed counters with
      add/remove/reorder and an optional per-instance timer.
- [x] The pilot records API friction and any repeated work that a component
      store would remove; a runtime-owned store is reconsidered only with
      independent-product evidence, not just this pilot. The measured work is
      the explicit child lens/update, snapshot DTO, and stable-id cursor, all
      linear and visible in app code.
- [x] No hidden mutable lifecycle context, arbitrary setter, or saveable
      element slot is introduced.
- [x] The outcome is recorded in ADR 0053 or a superseding RFC: either the
      Feature-first boundary is confirmed with a concrete reusable example, or
      the evidence is strong enough to evaluate a separate typed store.
      ADR 0053 records the confirmed boundary plus scope isolation, snapshot
      round-trip, stale-dispatch, and wasm-gc evidence.

### N5 — Transient scroll and damage localization

Start condition: W2.3b is closed and W2.4's content-coordinate scroll path is
available. This slice fixes the remaining normal-path rebuild before considering
any presenter change.

Device evidence at start:

- A current-tree Showcase HAP was captured on a matching `HAD-W32`
  (HarmonyOS `7.0.0.107`, 2090×1324 surface, Maleoon 916, OpenGL ES 3.2).
- Two long drag runs produced 154 and 123 measured frames. Frame p50/p95 was
  4.99/7.80 ms and 5.20/8.00 ms; render was 8.91/11.06 ms and 8.63/11.26 ms;
  inter-frame p50/p95 was 16/20 ms and 20/26 ms.
- All 277 measured frames chose full-surface damage. The logged reasons were
  "dirty region covers most of the surface", "activation rebuild", and one
  "dirty bounds unavailable"; EGL present was only 1.2-2.4 ms.
- The app shell still feeds scroll back into the model:
  `SidebarScrolled` / `DetailScrolled` update `sidebar_scroll` /
  `detail_scroll`, while the scroll control reports `activated` whenever
  `on_scroll` is present. The result is a root activation rebuild per scroll
  step even though the element already owns transient offset state.

Work:

1. Remove controlled offsets and `on_scroll` callbacks from the Showcase shell
   (desktop and mobile list/detail) where cross-remount persistence is not a
   product requirement. Keep one deliberate controlled-scroll sample in the
   Components gallery and its tests so the public API keeps realistic coverage.
2. Let `ScrollRuntimeState` own the transient offset. Use an explicit
   `ScrollRequest` with a monotonic id for the one behavior that truly needs a
   model trigger: resetting detail scroll when opening a different story.
   Record and test whether returning from the mobile catalog should preserve or
   reset the detail position.
3. Add a regression that a pointer/wheel scroll in the transient Showcase shell
   changes view state without dispatching an app message or requesting an
   activation rebuild. Keep pointer capture, indicators, focus/caret reveal,
   semantics scrolling, RTL, and `scroll_target_into_view` coverage intact.
4. Re-run the Showcase scroll benchmark and record node builds, activation
   rebuilds, layout/render cache counters, damage reason/coverage, and
   frame/present timing against the W0.3 artifacts.
5. Only if frames still become full-surface, classify transform-only internal
   scroll as paint/layout damage at the smallest correct boundary. If placement
   move tracking is still insufficient, keep `FullSurface` and name the missing
   invariant rather than enabling a partial present.
6. If and only if runtime rect damage appears, exercise the existing CPU-raster
   pixel self-check. EGL partial presentation remains out of scope unless the
   separate W2.3b reopen gates also pass.

Acceptance:

- [x] Showcase pointer scroll does not dispatch a model message, rebuild the
      root, or produce an activation-rebuild damage cause. Wheel and drag
      regressions compare program dispatch/update counts, rebuild-pass counts,
      and the frame damage reason.
- [x] Route-change reset and mobile list/detail transitions have an explicit,
      tested behavior; no app-owned transient offset remains merely to mirror
      runtime element state. Opening a different story increments a monotonic
      request id; re-selecting it does not. The mobile list/detail branch switch
      unmounts the detail element, so returning through the catalog resets the
      detail position by design rather than retaining a second app-owned copy.
- [x] Controlled scroll remains covered by a product-justified example or
      conformance test; removing Showcase plumbing does not silently remove API
      coverage. The Components gallery keeps its controlled `page_scroll`
      sample, and `moui/views/controls` keeps controlled-offset tests.
- [x] The benchmark records the before/after structural delta and cache
      counters. Two 60-frame `native-skia-raster --structural-only` runs have
      identical counters: layout 243/693 -> 63/279 and render 117/522 -> 27/108
      (hits/misses). Per-frame misses fall from 11.55/8.70 to 4.65/1.80. The
      hit-rate denominator also shrinks because root rebuilds disappear, so the
      gate now pairs scenario floors with absolute per-frame miss ceilings.
      Local timing is report-only: frame p50 is 0.534-0.575 ms and present p50
      is 0.497-0.511 ms, with no timing ratchet.
- [x] The damage result is evidence-backed: either a sound rect classification
      is added with pixel coverage, or full-surface remains with a named missing
      invariant and no new presenter code. Wheel frames remain full for
      `layout changed`; drag frames fall back to
      `damage accumulated across paint passes`. The runtime still treats
      layout-phase scroll transforms as full-surface, and the presenter receives
      no rect damage. No pixel self-check or EGL partial path is enabled.
- [x] No new component-state store, hidden mutable context, package split, or
      renderer route is introduced.

Residual damage invariant: a layout-dirty scroll container changes its
`child_transform` without moving the content subtree's placed frames. Before a
rect frame is possible, damage computation must derive the moved content bounds
from that transform and prove that the scroll viewport clip covers every
exposed pixel. Until that invariant exists, `FullSurface` is the correct
fallback.

### N4 — Deliberately parked follow-ups

The full Inspector UI, payload-level message log, state-preserving hot reload,
native accessibility completion, platform readiness changes, and additional
renderer routes remain outside this queue. They require separate charters and
evidence; they must not be used as a reason to expand `moui/core` or
`moui/runtime`.

Recommended start order:

1. N3 is complete in `examples/custom_control`; the committed model remains
   plain data and the measured plumbing cost is recorded in ADR 0053 and the
   custom-control SDK.
2. W0.3's structural-counter gate is complete; do not promote a timing gate
   from a shared-runner sample.
3. W2.3b is closed as matching-device non-adoption. Do not add EGL partial
   presentation until runtime rect damage, a measured frame-budget miss, and
   device extension support all hold.
4. N5 is complete and the activation rebuild is closed. A future rect-damage
   slice needs the transform-aware viewport invariant above; it is not part of
   this plan. Any N4 charter starts only with independent product evidence.
5. Only an independent-product evidence set can justify opening a separate
   component-store RFC.
6. Close this plan after N5 records its benchmark and damage outcome and every
   applicable `pr`/path-triggered check passes.

## Workstreams

### W0 — Baseline, decisions, and portfolio inventory

Acceptance:

- [x] W0.1 Add a leaf-only benchmark at 1k and 10k nodes that advances a clock,
  changes one leaf, and reports p50/p95, build count, `View::map` clone/adapter
  count, render/layout cache hit rates, damage coverage, and present time.
- [x] W0.2 Add a scroll-cache measurement that reports place/render cache
  hit/miss counts and raster/present time on a representative large viewport;
  use the existing HarmonyOS capture as external evidence until a repeatable
  host simulation exists.
- [x] W0.3 Review `checks/performance-budgets.json` with the new scenarios,
  define provisional update/scroll budgets, and make at least one core update
  regression blocking in a stable profile. Document runner variance and the
  artifact/ratchet process.
- [x] W0.4 Write an ADR for the render cache key: time is not part of the key;
  environment identity, style, text-system identity, scale/locale/direction,
  and view-state revision are. Enter-fade/animation subtrees bypass the cache.
- [x] W0.5 Write an ADR/RFC for damage classification and surface capability:
  exact visual change, structural change, environment/theme/resize, and unknown;
  `FullSurfaceOnly | SubRect`; every unsupported platform defaults to full.
  Recorded in ADR 0050; W2.1 consumes the classification and W2.2 owns the
  capability plumbing.
- [x] W0.6 Write a decision record for component scope: persistent state
  ownership, lifecycle/effect ownership, save/restore, keyed identity, and
  multi-instance semantics. Compare Feature-first with a runtime-owned typed
  component store; do not reintroduce hidden mutable context.
  Recorded in ADR 0053: persistent state stays in the parent TEA model,
  `scope_id` names lifecycle resources only, keyed instances use model-owned
  keys, and save/restore uses an app-owned explicit snapshot DTO. No
  runtime-owned component store is approved.
- [x] W0.7 Inventory all 14 routes and 25 public modules by product/lab/
  diagnostic intent, owner, evidence, and review/graduation/retirement trigger.
  No new renderer route is added before this inventory closes.
  Recorded in `checks/portfolio-governance.json`; the inventory includes the
  `linux-skia-riscv64` architecture variant and excludes the internal
  `moui_tests` module. Coverage is enforced by the portfolio validator.

Gate: W1.1 may start after W0.4; W2.1-W2.3 after W0.5; W3.2 after W0.6.
W3.1 is independent because it adds identity to existing lifecycle keys without
choosing a persistent-state owner.
W0.1-W0.3 are prerequisites for claiming a performance win.

### W1 — Make the normal update path incremental

Acceptance:

- [x] W1.1 Replace the `matches_default_cache_key` gate with an explicit
  `RenderCacheKey`. After `FrameTick`, an unchanged repaint must hit the cache;
  theme, scale, locale, direction, text-system, focus, and view-state changes
  must invalidate exactly. Add a message repaint after `advance_time(16)` as a
  regression test.
- [x] W1.2a Add an advanced-core `ViewMemo[Msg]` with explicit content keys,
  construction-only caching, and an ADR defining caller-owned invalidation.
  Cover equal/changed keys, canonical key equality, mapped event/semantics
  preservation, and a 1k/10k builder A/B.
- [x] W1.2b Decide and implement scoped construction reuse at the correct
  boundary. A leaf update on a 1k/10k-node tree rebuilds only the affected leaf
  plus its container without a per-leaf memo, and unrelated sibling builders
  are not called. ADR 0057 accepts explicit `ViewBuilderCache` keys;
  `ViewMemo` remains the single-subtree primitive. Adoption review found no
  first-party app with both a measured repeated-builder cost and a maintainable
  complete content key, so the cache remains advanced core with a documented
  program-factory ownership pattern rather than a default app/views API. The
  recursive `View::map` copy boundary is closed separately by ADR 0058.
- [x] W1.3 Decide whether recursive adapter/subtree copying can be removed from
  `View::map` by carrying an internal message-transform chain. Public
  view/event semantics stay unchanged. ADR 0058 closes the spike with a
  negative outcome: generic trait methods exist, but trait objects reject
  polymorphic methods and the language has no associated source-message type.
  The current recursive adapter remains the only proven-correct
  implementation; the revisit trigger is tracked in
  `docs/plans/debt/message-transform-chain.md`. No lazy children were landed
  as a claimed fix because runtime traversal still materializes them.
- [x] W1.4 Expose caller-owned `ViewMemo` build/hit/miss counters and document
  the existing runtime inspector counters. Do not register memos globally: the
  inspector observes runtime-owned caches, while memo lifetime belongs to the
  caller. Record API-surface and maintenance-budget changes with the addition,
  and introduce no hidden state or implicit dependency tracking.

Gate: W1 is done only when the new leaf benchmark and the existing deep-tree
benchmark show the expected structural improvement, not merely a faster machine.

### W2 — Make damage and scrolling end-to-end incremental

Acceptance:

- [x] W2.1 Split invalidation reasons. A message with no visual change must
  produce `Empty`, not full surface; ordinary visual changes must preserve
  precise dirty ids; only environment/theme/resize and genuinely unknown work
  default to full. Add deletion, reorder, focus, overlay, scroll, and
  no-op-message tests.
  Projection rebuilds now classify clean, paint-only, structure/layout, and
  explicit full-surface causes separately. Runtime white-box coverage includes
  no-op, paint-only selection, layout-only, deletion, reorder, focus, overlay
  close, scroll, and environment invalidation.
- [x] W2.2 Add a surface damage capability, defaulting to `FullSurfaceOnly`.
  Skia raster consumes `SubRect` only when the capability is present; macOS,
  Web, Windows, and Linux keep their current byte-for-byte presentation unless
  separately proven.
  `SurfaceDamageCapability` now lives in the render protocol, and
  `RendererSession` exposes its negotiated value. Skia CPU raster accepts
  `SubRect` only through an explicit constructor argument; GPU drawables and
  every production composition root remain `FullSurfaceOnly`.
- [x] W2.3a Add a pixel-comparison self-check for damage coverage. Cover
  disjoint damage-union and HiDPI coordinates against a full-surface
  reference, scope-command fallback, empty-damage presentation skip, and
  full/default parity.
- [x] W2.3b Evaluate partial presentation on HarmonyOS/EGL with a
  matching-device capture. Record raster, present, frame-pacing, cache, and
  damage-reason evidence; enable `SubRect` only if the complete ADR 0050 gate
  passes.
  Evaluated 2026-11-05 on `HAD-W32` (HarmonyOS `7.0.0.107`, 2090×1324,
  Maleoon 916, OpenGL ES 3.2). Two long drags measured 277 frames total, all
  with full-surface damage; EGL present was 1.2-2.4 ms and inter-frame
  p50/p95 was 16/20 ms and 20/26 ms. The current Showcase scroll path supplied
  no rect damage and did not miss the full-surface frame budget, so EGL partial
  presentation was not enabled and no device pixel-equality claim was made.
  This is an evidence-backed non-adoption, not a waiver. Reopen only when the
  runtime produces scroll rect damage, a matching-device full-surface frame
  budget is measurably missed, and the device exposes the required preserved
  buffer and damage-swap EGL extensions. Local artifacts:
  `artifacts/harmonyos/w23b-baseline/`.
- [x] W2.4 Move scroll layout to content coordinates and apply the viewport
  transform at paint, hit-test, semantics, and accessibility boundaries.
  Place/render cache keys must be content-local. Verify scroll position,
  clipping, focus/caret reveal, overlay anchoring, RTL, and
  `scroll_target_into_view` parity. If transform-only still misses the target,
  add retained viewport tiles rather than re-baking absolute offsets into every
  child frame.
  Design: ADR 0051 adds `ViewLayoutResult.child_transform`; placed/render trees
  keep content-local frames and carry the transform to paint, pointer,
  semantics/accessibility, anchors, overlay placement, native platform views,
  and damage indexing. The scroll container's own layout/paint may rerun on a
  tick, but descendant place/render keys stay content-local.

Gate: W2 requires the pixel self-check, a matching-device HarmonyOS evaluation,
and unchanged full-surface behavior on hosts without a proven partial-present
path. `SubRect` is enabled only when runtime damage, renderer/presenter
coverage, pixel equality, and host cost evidence all pass. A partial-damage
feature that only improves a synthetic benchmark is not accepted.

### W3 — Component scope, input arbitration, and the extension kit

Acceptance:

- [x] W3.1 Add explicit scope identity to Effect and Subscription lifecycle.
  `Feature::scope(scope_id, ...)` namespaces structured Effect and
  Subscription descriptor keys, so sibling or multi-instance features can
  reuse local keys without supersession or deduplication. Disappearance from
  the declarative subscription plan cancels that scope's subscriptions;
  completed/canceled Effect tasks continue to ignore stale dispatches, and
  runtime destruction cancels both. Feature scopes remain pure composition:
  they add no mount hook, hidden state, or second task owner, and one-shot
  tasks are not canceled merely because a subtree stops rendering.
- [x] W3.2 Execute the W0.6 component-state decision. If approved, implement the
  smallest contract that supports keyed multi-instance components and
  save/restore, with at least one first-party pilot. If declined, record the
  product constraint and close the workstream without inventing a second state
  model.
  Declined runtime-owned component state. ADR 0053 records parent-model
  ownership, model-keyed instances plus lifecycle-only `scope_id`, and
  app-owned snapshot codecs; Settings is the first-party save/restore pilot.
- [x] W3.3 Introduce a gesture recognizer arena for tap, long press, drag, and
  scroll competition across pointer ids. Preserve the pointer-parity fixes and
  add deterministic nested-scroll and tap-vs-long-press tests.
- [x] W3.4 Publish a custom-control SDK above `ViewNode`: a template,
  declaration/identity guidance, conformance tests for semantics/accessibility/
  RTL/focus/IME, golden layout/paint fixtures, and a migration example. Do not
  change the renderer ABI or add a dynamic plugin loader.
  `docs/custom-control-sdk.md` and `examples/custom_control` provide a
  message-independent editable counter with a model-owned committed value,
  caller-owned typed callbacks, declaration channels split by
  layout/paint/semantics/platform, pointer-seeded caret, composition begin/
  update/end, mirrored RTL action zones, and golden layout/paint fixtures.
  Runtime tests drive semantic actions and focus/IME through the public
  `ViewNode` boundary. The widget and app tests are in the `pr` profile.

Gate: W3.1 may ship independently. W3.2 is closed by ADR 0053 without a new
state API. W3.4 requires API-surface review and must not expand the core by
duplicating `Feature`/`Program` semantics.

### W4 — Portfolio, release, and status governance

Acceptance:

- [x] W4.1 Add owner, review date, and graduation/retirement condition to the
  route and module catalogs (or a generated companion catalog). Classify the 6
  experimental routes and the experimental renderer modules without deleting
  any route in this plan.
  Recorded as a generated companion catalog. The current split is five product
  routes, three diagnostic routes, and six lab routes plus the lab RISC-V64
  architecture variant; module intent is recorded for all 25 public modules.
- [x] W4.2 Define a compatibility matrix and a base-only patch path, or record
  the accepted synchronized-release constraint with evidence. A renderer or
  addon must not be forced to move because an unrelated base module changed.
  ADR 0055 records the accepted synchronized `0.3.x` line, no base-only patch
  path, deferred compatibility matrix, and no forced semantic bump for an
  unrelated base change.
- [x] W4.3 Generate the current status block for architecture, readiness, and
  feature-status pages from the platform/release catalogs. Add a validator that
  fails on the known semantic drift shapes, including removed component APIs
  and committed-versus-experimental conflicts.
  `validate_portfolio_governance` checks exact catalog coverage, intent-to-
  readiness consistency, evidence files, synchronized module versions,
  generated-block freshness, stale component API guidance, and HarmonyOS
  product-class claims.
- [x] W4.4 Ship a first devtools slice for the new execution model: message/
  effect timeline, frame-phase trace, memo/cache counters, and semantics-tree
  diff. Treat the full inspector/hot-reload effort as a follow-up plan.
  `moui_devtools.DevtoolsTrace` adds caller-owned sampled deltas over existing
  Inspector snapshots with bounded entry and semantics-diff retention. Showcase
  Diagnostics records a real probe interaction; ADR 0056 excludes payload
  capture, source rewriting, and hot reload from this slice.

Gate: W4.1-W4.3 are release-governance requirements. W4.4 is the bounded first
slice; a full Inspector UI, payload-level message log, or hot reload would need
a follow-up plan.

## Release gates

| Gate | Contents | Exit condition |
|---|---|---|
| A — hardening | W0, W1.1, W2.1, W4.3 | Cache and damage semantics are correct; status pages stop drifting; no public API break. |
| B — incremental core | W1.2a, W1.4, W2.2-W2.4, N5 | Explicit-memo leaf updates and scroll are measurably incremental; pixel coverage passes; W2.3b records a matching-device decision; unsupported hosts remain on full-surface. Automatic W1.2b and the W1.3 map rewrite remain separate design-gated optimizations. |
| C — component/extension | W3.1-W3.4 | Component-state decision is recorded and executed; scope lifecycle, gesture arbitration, and control SDK pass focused API and behavior gates. |
| Continuous | W4.1-W4.2 | Route/module ownership and release coupling are explicit; future additions carry their own review signal. |

## Expected impact

| Area | Expected result | Main trade-off |
|---|---|---|
| Render cache | Restore cache hits after the first frame and for common themed/high-DPI/RTL environments, reducing repaint work | More key data must be canonicalized; a wrong key causes stale pixels |
| View build | Avoid root rebuilds and nested map amplification; lower allocation and interaction latency on large trees | Explicit memo dependencies can be misdeclared; diagnostics and tests are required |
| Damage/present | Reduce raster, GPU encode, and energy cost on large/scroll-heavy surfaces | Coordinate-space and pixel-coverage complexity; default full fallback remains necessary |
| Component scope | Improve reusable components and multi-instance state without abandoning TEA | A second persistent-state layer adds snapshot/restore and compatibility complexity |
| Route/release/docs | Lower onboarding and upgrade risk; prevent experimental scope from silently becoming product scope | Slower route additions and more explicit review overhead |

## Risks and mitigations

- **Stale render cache after key changes:** add stale-pixel and decoded-value
  tests for theme, scale, locale, direction, text system, view-state revision,
  focus, and animation.
- **Memo misuse:** make dependencies explicit, expose hit/miss diagnostics, and
  prefer internal/Feature-owned memo before a public API.
- **Damage under-coverage:** retain the pixel self-check and full-surface
  fallback; never infer presentation capability from a renderer name.
- **Scroll transform regressions:** translate coordinates only at explicit
  boundaries; run pointer, focus, caret reveal, overlay, semantics, RTL, and
  scroll-target tests together.
- **Component scope creep:** no hidden mutable context, no dynamic plugin ABI,
  and no component-local state without the W0.6 decision and a first-party
  pilot.
- **Benchmark noise:** use repeated samples, artifact-backed comparisons,
  relative thresholds, and a stable profile; do not ratchet from a single
  shared-runner sample.
- **API growth:** require `moon info`, API-surface reports, and budget updates
  in the same change as every public addition.

## Validation matrix

| Slice | Focused validation | Broader gate |
|---|---|---|
| W0 | benchmark runs, budget review, ADR/RFC links | `node scripts/validate-guidance-consistency.mjs` |
| W1 | `moon test moui/core moui/runtime moui/views --target native`; leaf/deep benchmarks; `moon info` if API | `sh scripts/check.sh --profile pr` |
| W2 | runtime damage tests, Skia raster tests, scroll/hit/semantics tests, HarmonyOS capture | `sh scripts/check.sh --profile platform` where the route requires it |
| W3 | core/runtime/views + pointer tests, component conformance tests | API surface, maintenance baseline, relevant daily smoke |
| W4 | catalog validation, generated-doc check, doc-reference check | general guidance and release gates |

For every slice: run `moon fmt`, the smallest focused suite, and the applicable
static validators from `docs/testing.md`. Do not start a slice with the full
daily/platform profile when a focused loop is sufficient.

## Plan closure

The plan may move to `docs/plans/done/` when N5 records its transient-scroll
benchmark and damage outcome, W2.3b's non-adoption is reflected in the platform
documentation, and every applicable `pr`/path-triggered check passes. W1.2b's
explicit builder/content-key contract, structural evidence, and app-adoption
boundary are delivered by ADR 0057. W1.3's type-safety decision is closed by ADR
0058; the recursive adapter remains, with a language-triggered debt note for
reopening. W2.3b is closed by matching-device evidence, not waived, and does not
leave an indefinite hardware blocker. W3.4 and W4.4 are delivered by this plan.
A full Inspector UI, payload-level message log, state-preserving hot reload,
and further renderer routes remain separate follow-up plans.

## Not now

- Splitting `moui/core` or `moui/runtime` into new public packages before the
  existing trigger fires.
- Decomposing `ViewNode` or replacing `RendererSession`'s closure record.
- Adding another renderer route, a generic dynamic plugin ABI, or an in-process
  hot-reload promise.
- Reintroducing hidden mutable component lifecycle or `ComponentContext` as a
  prerequisite for performance work.
- Automatic component builder skipping without explicit builder/content keys;
  `ViewMemo` and `ViewBuilderCache` are the supported construction
  optimizations. A non-copying `View::map` transform chain stays parked until
  the language provides the required safe representation (ADR 0058).
- EGL/OHOS partial-swap implementation before runtime rect damage and a
  measured full-surface frame-budget miss exist.
- Claiming mobile readiness from host-sim or desktop evidence.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-05 | Created from the three architecture reviews; existing dirty-path, package-cohesion, pointer, HarmonyOS, and ViewNode plans remain the owners of their existing scopes. |
| 2026-11-05 | Correctness and measurement precede component API work; cache and damage must be demonstrably correct before memoization and scoped state land. |
| 2026-11-05 | Component-local persistent state is a product/API decision, not an assumed refactor; Feature-first is the default bias. |
| 2026-11-05 | The full-surface debt is absorbed into W2; no second roadmap is created. |
| 2026-11-05 | No new route or renderer is added until the route/module inventory closes. |
| 2026-11-05 | Render caching keys on content-derived inputs, never the animation clock; time-dependent paint must report `animating` and bypass cache reads/writes (`docs/decisions/0048-render-cache-key-contract.md`). |
| 2026-11-05 | A clock-zero pressable transition latches the from-state as animating so the first host tick can advance it instead of caching a terminal sample. |
| 2026-11-05 | Peak-value-free render keys must also include a monotonic placement revision because paint reads child frames; environment passthrough classification is scoped to one view node plus parent environment identity and is invalidated when presentation declarations change. |
| 2026-11-05 | `ViewMemo` is advanced core with caller-owned content keys, not a root-facade app-loop type and not a component-state holder (`docs/decisions/0049-explicit-view-memo.md`). |
| 2026-11-05 | W1.3 remains blocked rather than partially landed: recursive `View::map` is the only implementation that preserves typed event, text-command, and semantics mapping without unsafe erasure. A lazy-child-only variant would move work into runtime traversal, not remove it. |
| 2026-11-05 | W0.3 timing gates are not promoted from the first host run. The canonical macOS benchmark remains report-only and its same-code p50 spread is larger than a defensible update ratchet; only a stable dedicated runner plus repeated artifacts can make a timing budget blocking. Structural build/cache counts may gate earlier because they are machine-independent. |
| 2026-11-05 | W3.1 uses a stable `scope_id` on `Feature::scope` to namespace Effect/Subscription keys instead of adding a component mount lifecycle. The existing runtime already owns completion, cancellation, stale-dispatch isolation, and diagnostics; the defect was global key identity across independent scopes. One-shot tasks remain program work and are not canceled by view disappearance (`docs/decisions/0052-feature-scope-lifecycle-identity.md`). |
| 2026-11-05 | W0.6/W3.2 choose Feature-first persistent component state. Parent models own keyed instances, `scope_id` names lifecycle keys only, and save/restore stays an app-owned snapshot codec. The runtime does not gain a component store, mount lifecycle, or saveable slot registry; automatic builder reuse remains deferred to a separate explicit-key RFC (`docs/decisions/0053-feature-first-component-state-boundary.md`). |
| 2026-11-05 | W1.4 keeps `ViewMemo` counts caller-owned. Runtime inspector counters continue to describe runtime build/layout/render caches; a global memo registry would add hidden lifetime and cleanup state for no diagnostic gain. |
| 2026-11-05 | W3.3 keeps gesture arbitration in a per-pointer transient runtime arena. Candidate recognizers are recorded on `Down`; the first completed recognizer owns later samples and other candidates are cancelled. No public event signal or component-state API is added (`docs/decisions/0054-pointer-gesture-arena.md`). |
| 2026-11-05 | W0.7/W4.1 records route and module intent in `checks/portfolio-governance.json`. All 14 canonical routes, the lab `linux-skia-riscv64` architecture variant, and all 25 public release modules carry owner, evidence, review, graduation, and retirement policy; `moui_tests` is internal, and this plan retires no route. |
| 2026-11-05 | W4.2 accepts a synchronized `0.3.x` release line with no base-only patch path. Compatibility-matrix maintenance is deferred until external consumer evidence exists, and an unrelated base change does not force renderer/addon semantic bumps (`docs/decisions/0055-synchronized-release-line.md`). |
| 2026-11-05 | W4.3 makes generated route/module status and semantic drift a `pr` gate. Exact catalog coverage, intent/readiness mapping, evidence paths, generated-block freshness, stale component API guidance, and HarmonyOS product-class claims are validated from the catalogs instead of maintained by prose. |
| 2026-11-05 | W4.4 keeps trace ownership outside the runtime. `DevtoolsTrace` samples existing Inspector snapshots, retains bounded deltas and one comparison watermark, and exposes text/JSON renderings. Message payloads, source rewriting, and state-preserving reload remain out of scope (`docs/decisions/0056-bounded-read-only-devtools-trace.md`). |
| 2026-11-05 | W3.4 keeps third-party controls message-independent. Committed values stay in the parent TEA model, typed callbacks and semantic-action handlers live in `View::from_node`, and focus/caret/selection/composition stay transient in runtime contexts. Declaration channels are split by layout, paint, semantics, and platform; text controls seed the caret from pointer geometry rather than assuming an initial offset, and RTL action zones come from one mirrored geometry source. The ownership validator now classifies reusable `examples/*/widgets` sources separately, permitting `TextControlStateContext` as a protocol input while retaining the hidden-state and component-context bans. The SDK adds no renderer ABI, dynamic plugin loader, hidden component state, or second lifecycle model (`docs/custom-control-sdk.md`). |
| 2026-11-05 | The next-stage queue is design/evidence first. N1 (W1.2b) and N2 (W1.3) must pass their RFC/type-safety gates before implementation; N0's runner and matching-device evidence gates may run in parallel but cannot be waived. N3 validates the already-accepted Feature-first component boundary and does not reopen ADR 0053 without independent-product evidence. |
| 2026-11-05 | N1's contract is accepted as ADR 0057. `ViewBuilderCache` extends `ViewMemo` with a stable builder key plus a complete content key, manual remove/clear lifetime, and caller-owned counters. It deliberately adds no automatic eviction, runtime store, hidden lifecycle, or closure-read tracking. The primitive skips sibling builders; recursive `View::map` copying remains a separate N2/W1.3 boundary. |
| 2026-11-05 | N2/W1.3 closes with a negative implementation decision. The compiler supports generic trait methods, but trait objects reject polymorphic methods (E4038) and traits cannot carry an associated source-message type. Without an existential typed view, every non-lazy alternative either recursively materializes mapped children or requires unsafe/type-erased dispatch. ADR 0058 retains the recursive adapter and records the reopen trigger. |
| 2026-11-05 | N1/W1.2b closes without a default app integration. First-party candidates either render too few repeated builders or lack a complete revision/content key; adding one now would trade measured builder savings for stale-view risk and a new public convenience API. ADR 0057 records the three adoption preconditions and the program-factory ownership pattern. Reconsider only with a profiled adopter. |
| 2026-11-05 | The next development plan is now bounded to N3, N0, and parked N4. N3 is the only implementation-ready architecture slice; W0.3 and W2.3b are evidence gates. (Superseded by the W2.3b closure and N5 entries below.) |
| 2026-11-05 | W0.3 uses structural counters as the blocking public CI signal. Builder-cache leaf workloads must build only the changed leaf plus container, and scroll cache floors are scenario-specific. Wall-clock timing stays report-only until two same-runner artifacts show at most 15% same-code p50 spread. (Superseded by the dedicated-runner timing entry below.) |
| 2026-11-05 | W0.3's renderer-free structural test lives in `moui/runtime`, not the benchmark package. This keeps the core update regression in the fast `pr` profile even when the real Skia benchmark host is unavailable; the measured benchmark remains the artifact-producing corroboration. |
| 2026-11-05 | W0.3 timing evidence is not promoted despite the latest local pair meeting the 15% p50-spread sample rule. The two artifacts came from a developer host, while the blocking job still runs on shared `macos-14`; the earlier 1.3-1.5x same-code drift remains the controlling evidence for that runner. The variance rule now requires the dedicated runner that will enforce the gate before any timing ratchet. |
| 2026-11-05 | W2.3b closes as evidence-backed non-adoption. On a matching `HAD-W32`, all 277 measured Showcase drag frames used full-surface damage, EGL present cost 1.2-2.4 ms, and pacing did not miss the full-surface budget. No device pixel-equality or partial-present claim is made, and EGL stays `FullSurfaceOnly`. |
| 2026-11-05 | N5 is the next implementation slice. The remaining scroll cost is app-owned transient scroll state forcing an activation rebuild, not EGL swap capability. Remove that app plumbing first, measure the structural delta, then decide whether transform-only internal scroll can truthfully produce rect damage. |
| 2026-11-05 | Timing ratchets require a dedicated runner that actually enforces the gate. Two shared-host or local artifacts are report-only even when their p50 spread is at most 15%; that sample rule does not substitute for runner identity. |
| 2026-11-05 | N5 keeps live scroll offsets element-owned. The Showcase model stores only a monotonic `ScrollRequest` for opening a different story. Re-selecting the current story does not reset, and a mobile list/detail branch switch resets by unmounting the element rather than by retaining a second app-owned offset. |
| 2026-11-05 | N5 leaves damage full-surface. Wheel scrolling reports `layout changed`; drag input can accumulate a full region across paint passes and reports `damage accumulated across paint passes`. A rect path still needs transform-aware moved-content bounds plus proof that the viewport clip covers every exposed pixel. |
| 2026-11-05 | The Showcase scroll structural gate now combines scenario hit-rate floors with maximum layout/render misses per frame. Removing root rebuilds cuts total cache work so sharply that hit rate alone falls despite fewer misses; the absolute ceiling prevents that denominator shift from hiding a regression. |

## Progress

| Date | Note |
|---|---|
| 2026-11-05 | Plan created from the three 2026-11-05 architecture reviews. Baseline evidence is those reviews plus the existing plan records at HEAD `1cd3f90db`. |
| 2026-11-05 | W0.4 complete: ADR 0048 records the explicit render-cache key and animation bypass contract. |
| 2026-11-05 | W1.1 first slice landed: replaced the default-static-environment gate with `RenderCacheKey`, removed the duplicate environment fields, added text-control revisioning, and added FrameTick, message/static-child, text-state, and button clock-zero regressions. Focused tests pass: `moui/runtime` 183/183, `moui/core` 142/142, `moui/views` 39/39, and `moui/views/button` 4/4. The six pre-push static validators also pass. Benchmark cache hit rate rose from 0.0417 to 0.0909 in Showcase and from 0 to 0.7234 in Excel-grid navigation, while scroll and virtual-list scenarios remain blocked by content-coordinate scrolling and are not claimed as fixed. W1.1 stays open until the remaining key dimensions and production-like themed/scaled benchmark are covered. |
| 2026-11-05 | W1.1 complete: added a placement revision to the key and fixed environment-scope identity reclassification. A scope can be a structural no-op for one parent environment and change the child environment for another, so classification now invalidates on a presentation-declaration change. New regressions cover theme/scale/locale/direction/contrast, text system, focus, view state, text-control state, animation bypass, FrameTick, static children, button clock-zero, painted-child-frame placement, and scope reclassification. Final focused suites: runtime 189/189, core 146/146, views 39/39, button 4/4. |
| 2026-11-05 | W0.1 evidence (native Skia raster, 30 measured frames, 6 warmup, two host runs): 1k update p50 range 7.33-7.71 ms non-memo versus 4.35-4.48 ms memo; 10k 110.20-111.73 ms versus 79.65-79.88 ms. p95 ranges were 7.54-8.73 / 4.72-5.11 ms at 1k and 114.49-122.63 / 81.35-87.55 ms at 10k. Both memo modes build 2 views/frame versus 1,001/10,001 without memo, while `assembledNodes` and computed map-adapter copies are unchanged (1k: 1,001/frame, 30,060 copies; 10k: 10,001/frame, 300,060 copies; the extra adapter is the first leaf's OnTap wrapper). Render hit rate is 0.9975/0.99975; every measured frame still reports full-surface damage, confirming W1.3 and W2 remain separate work. |
| 2026-11-05 | W1.2a complete: added `ViewMemo` as an advanced-core, single-entry construction cache with content-canonical keys. Tests cover equal/changed keys, key canonicalization, and mapped event/semantics behavior; ADR 0049 records that callers own the complete dependency set and that the memo is not application state. It is deliberately not re-exported from the root `moui` facade. The benchmark proves skipped sibling builders, but the root view assembly and recursive `View::map` remain; automatic scoped reuse is W1.2b. |
| 2026-11-05 | W0.2 complete: every budgeted scenario now emits separate layout/render hit/miss counters. The counters are tree-local, so remounts can discard old nodes' counts; measured deltas are clamped at zero and documented as a lower bound. Host 30-frame diagnostic: `showcase-runtime-scroll` layout 48/231 (0.172) and render 6/309 (0.019), paint p50/p95 0/0.172 ms, present 2.812/3.531 ms; `virtual-list-100k` layout 0/180 and render 0/176, paint 0.091/0.106 ms, present 0.131/0.218 ms. This independently confirms the scroll rebuild/cache-miss debt owned by W2.4. |
| 2026-11-05 | W0.5/W2.1 complete: ADR 0050 separates invalidation class, paint-damage bounds, and surface capability. Runtime projection rebuilds now distinguish no-op, paint-only, structure/layout, and explicit full-surface work; no-op rebuilds produce `Empty`, while environment/resize/activation/overlay causes stay full. Runtime white-box tests cover no-op, selection, focus, deletion, reorder, layout, overlay, scroll, and environment cases. |
| 2026-11-05 | W2.2/W2.3a complete: renderer sessions negotiate `FullSurfaceOnly` by default or an explicit `SubRect`; Skia CPU raster clips/clears to the damage union and skips `Empty` presentation only under `SubRect`. GPU drawables, scope-command frames, and all composition roots retain full-surface behavior. The pixel self-check runs at 2x scale with disjoint damage rectangles whose union leaves margins, and compares every candidate pixel with a full-surface reference. W2.3b matching-device HarmonyOS/EGL pacing evidence remains open. |
| 2026-11-05 | W2.4 complete: ADR 0051 adds `ViewLayoutResult.child_transform`; placed/render trees keep content-local frames and carry the transform to paint, hit testing, focus/caret reveal, semantics, anchors, overlay placement, native platform-view collection, and damage indexing. Scroll layout uses a static content frame plus the viewport transform, including mirrored RTL leading-edge semantics and paint-only rubber-band overshoot. Runtime white-box coverage proves descendant place/render cache hits across scroll ticks, screen-space paint/pointer/semantics/anchor/platform placement, viewport clipping, RTL presentation and hit testing, overlay escape, and repaint-boundary composition. Legacy `draw_commands()` remains a screen-space compatibility projection; `DrawFrame.commands` stays node-local with explicit transform scopes. Focused suites: core/runtime/views/controls/WebView/3D 439/439 and render/protocol/Skia 174/174. The full `sh scripts/check.sh --profile pr` run and all six pre-push static validators pass. W2.3b remains open pending matching-device HarmonyOS/EGL evidence. |
| 2026-11-05 | W3.1 complete: ADR 0052 adds stable `Feature::scope(scope_id, ...)` namespacing for structured Effect and Subscription descriptor keys, with `%`/`/` escaping and an empty root namespace for compatibility. Runtime regressions prove sibling subscriptions with the same local key both start, removal cancels only the removed scope, stale subscription dispatches are ignored, and sibling effect tasks with the same local key remain independently active until completion or runtime destroy. Core 149/149 and runtime 205/205 pass, and the full `sh scripts/check.sh --profile pr` run is green. First-party settings/workbench scopes now declare canonical ids. This does not decide or add component persistent state; W0.6/W3.2 remain open. |
| 2026-11-05 | W0.6/W3.2 complete: ADR 0053 records the Feature-first component-state boundary. Parent models own persistent and keyed instance state; model-derived `scope_id` isolates lifecycle keys only; save/restore uses an app-owned explicit snapshot (`SettingsSnapshot`/`restore_from_snapshot` in Settings). Runtime slots remain interaction transients and are not saveable. Stale roadmap and example references to the removed `ComponentContext`, binding, and `SaveableStateStore` APIs were corrected. W1.2b remains deferred pending a separate explicit builder-key contract. |
| 2026-11-05 | W1.4 complete: `ViewMemo::stats()` reports successful builds, hits, and misses from the memo's existing caller-owned state cell; copied handles share counters, and a failed build is not counted as completed. The leaf benchmark now reports memo build/hit/miss counts alongside runtime build and render-cache counters. API-surface budget and ADR 0049 were updated together; no global registry or inspector coupling was introduced. |
| 2026-11-05 | W3.3 complete: the runtime records gesture candidates per pointer id on `Down`, selects the first activated recognizer or authoritative scroll movement, cancels losing candidates, and routes the rest of that stream only to the winner. Both tap/long-press modifier orders now resolve to exactly one command, two concurrent pointer ids keep independent arenas, and existing drag, nested-scroll, multi-pointer, and long-press wake suites remain green. Runtime tests: 210/210. ADR 0054 records the transient-state boundary. |
| 2026-11-05 | W0.7/W4.1-W4.3 complete: `checks/portfolio-governance.json` covers all 14 canonical routes, the RISC-V64 architecture variant, and all 25 public release modules with owner, intent, review, evidence, graduation, and retirement policy. ADR 0055 records the synchronized `0.3.x` release line. The portfolio validator checks exact coverage, intent/readiness mapping, evidence paths, module-line versions, generated architecture/readiness/feature-status blocks, removed component API guidance, and HarmonyOS product-class drift. |
| 2026-11-05 | W0.7/W4.1-W4.3 validation closed: the portfolio validator passes 10/10 and reports 15 routes/variants plus 25 public modules with generated docs current. The full `sh scripts/check.sh --profile pr` run passes, including `moon fmt --check`, `moon check`, package tests, generated-interface checks, release closures, renderer contracts, and documentation guards. Four W2/W3 runtime files required formatter-only layout alignment; no behavior changed. W3.4 and W4.4 are the only ready slices; W0.3, W1.2b, W1.3, and W2.3b remain gated. |
| 2026-11-05 | W4.4 complete: `DevtoolsTrace` records counter deltas, frame-pass/profile timing, caller-owned memo counters, cache deltas, effect descriptors, and a bounded semantics-tree diff against one previous watermark. Showcase Diagnostics appends a real probe interaction to the existing Inspector card. Focused tests pass for `moui_devtools` (5/5), Showcase app (13/13), and Showcase integration (3/3); ADR 0056 records the no-runtime-trace, no-payload-capture boundary. W3.4 is now the only ready implementation slice; W0.3, W1.2b, W1.3, and W2.3b remain gated. |
| 2026-11-05 | W3.4 complete: `examples/custom_control/widgets` publishes the package-local `editable_counter` `ViewNode` and `examples/custom_control/app` keeps committed state in a strict TEA model. Tests pass for identity/declaration changes, golden layout and LTR/RTL paint geometry, runtime semantics/action round trips, and pointer focus followed by IME composition. `docs/custom-control-sdk.md` and its zh-Hans mirror document package shape, declaration/identity separation, text/focus ownership, RTL geometry, migration, and conformance; both example packages are in the `pr` profile. The ownership guard now has path-classification tests so a reusable widget package may name the text-control protocol context without weakening the persistent-state bans. The full `sh scripts/check.sh --profile pr` run passes. The plan now has no ready implementation slice. |
| 2026-11-05 | Next-stage queue added after consolidating the three reviews against the completed W0-W4 slices. The remaining work is split into N1 explicit builder-key RFC, N2 type-safe map-transform design, N0 performance/device evidence, N3 Feature-first component ergonomics validation, and N4 parked developer-experience/platform follow-ups. No code implementation is approved by this entry. |
| 2026-11-05 | N1 contract and primitive landed: ADR 0057, `ViewBuilderCache`, and 10 focused core tests cover equal/changed content, builder isolation, keyed reorder, conditional replacement, theme/scale invalidation, captured event and semantics payloads, mapped behavior, handle aliasing, `remove`/`clear`, stats, and a 64-item one-change collection. Core is 160/160. The native Skia raster leaf run proves builder skipping at both scales: 30 measured frames build 60 node views (changed leaf plus container) versus 30,030 direct at 1k and 300,030 at 10k; builder-cache counters are 30 builds, 29,970/299,970 hits, 30 misses, and 1k/10k entries. The benchmark now fails structurally if those counts drift. `assembledNodes` and root-map adapter/copy counts remain unchanged because recursive `View::map` still copies every child, so N1/W1.2b remains open for app-path adoption and clone removal rather than claiming full success from the primitive. |
| 2026-11-05 | N2/W1.3 evidence: the leaf benchmark now runs 1k and 10k trees at one and two map layers. Builder-cache construction stays at 60 node builds over 30 measured frames, while adapter copies scale from 30,060 to 60,120 at 1k and from 300,060 to 600,120 at 10k. Frame p50 deltas were within shared-host noise, so the decision uses deterministic structural counts, not timing. ADR 0058 and the message-transform-chain debt note record the compiler probes and reopen criteria. |
| 2026-11-05 | N1/W1.2b closed: adoption review found no responsible default app integration. ADR 0057 now records the data-table/Excel evidence, the three preconditions for use, and program-factory cache ownership. `ViewBuilderCache` stays advanced core with no `views` or root-facade re-export; `ViewMemo` remains the single-subtree primitive. This avoids an untested convenience API and lets the N2 negative decision own the residual map-copy debt. |
| 2026-11-05 | Next development plan refreshed: N3 is specified as a keyed `examples/custom_control` pilot with parent-owned state, `Feature::scope` lifecycle isolation, an app-owned snapshot DTO, and an explicit ergonomics checklist. W0.3 structural/counter work runs in parallel; W2.3b remains matching-device-only; N4 requires a separate charter. |
| 2026-11-05 | W0.3 complete: `checks/performance-budgets.json` is schema 2 with structural leaf-update and Showcase-scroll budgets; the validator enforces builder counts, one miss per frame, builder/render cache floors, node/layer identity, and scroll cache floors. `moui/runtime/leaf_update_structural_wbtest.mbt` blocks whole-tree builder regressions in `pr` without a renderer. The macOS benchmark job runs `--structural-only` as a blocking step and keeps timing review non-blocking. `scripts/run-performance-budgets.mjs` records frame/leaf configuration and accepts leaf frame controls. Two native-skia-raster artifacts were retained under `artifacts/performance/`; structural validation passed on both. |
| 2026-11-05 | W0.3 evidence: two `native-skia-raster` artifacts (30 measured frames, 6 warmups) had identical structural counters. At 1k the builder cache recorded 30 builds, 29,970 hits, 30 misses, and 1,000 entries; at 10k it recorded 30/299,970/30/10,000. Builder/render hit rates were 0.999/0.9975 at 1k and 0.999/0.99975 at 10k. Showcase scroll was layout 243/693 (0.2596) and render 117/522 (0.1831) in both runs. The largest timing p50 spread was 11.82% (leaf builder-cache 1k update 3.468 to 3.678 ms; 10k 49.322 to 51.264 ms), below the 15% sample threshold but not enough to promote timing while CI remains on shared `macos-14`. |
| 2026-11-05 | W2.3b matching-device evaluation: built the current-tree Showcase HAP with `moon run moui_cli/cmd/moui --target native -- build harmonyos ...` and installed it on `HAD-W32` (`10.213.18.33:34287`, HarmonyOS `7.0.0.107`, 2090×1324 surface, Maleoon 916, OpenGL ES 3.2). Two long drags measured 154 and 123 frames: frame p50/p95 4.99/7.80 and 5.20/8.00 ms, render 8.91/11.06 and 8.63/11.26 ms, inter-frame p50/p95 16/20 and 20/26 ms. EGL present was 1.2-2.4 ms. All 277 frames logged full-surface damage ("dirty region covers most of the surface", "activation rebuild", or one "dirty bounds unavailable"). Microbench artifacts and screenshots are local only at `artifacts/harmonyos/w23b-baseline/`; generated artifacts remain untracked. |
| 2026-11-05 | W2.3b closed and N5 queued. EGL partial presentation is not implemented because the runtime supplied no rect damage and the full-surface budget was not missed. The next slice removes Showcase's controlled `offset`/`on_scroll` shell plumbing, retains internal `ScrollRuntimeState`, uses an explicit route-reset request, and measures whether the normal scroll path stops rebuilding/activating the root. |
| 2026-11-05 | N5 complete: the four Showcase shell scroll views no longer take controlled offsets or `on_scroll`; the model keeps only `detail_scroll_request`. Wheel and drag regressions prove no program dispatch/update or activation rebuild, and route-reset plus mobile catalog round-trip behavior are explicit. Showcase app tests pass 17/17; controlled scroll remains covered by the Components gallery and `moui/views/controls` tests. |
| 2026-11-05 | N5 structural evidence: two 60-frame `native-skia-raster --structural-only` runs produced identical counters. Showcase layout changed from 243 hits/693 misses to 63/279 and render from 117/522 to 27/108. Misses per frame fell from 11.55/8.70 to 4.65/1.80. The new floors are 0.18 layout / 0.19 render with ceilings of 5 layout and 2 render misses per frame; both artifacts pass. Local report-only timing: frame p50 0.534-0.575 ms, present p50 0.497-0.511 ms. No timing ratchet and no device claim. |
| 2026-11-05 | N5 damage outcome: the activation-rebuild cause is removed, but the normal path still produces full-surface damage. Wheel scroll ends at `layout changed`; drag scroll can end at `damage accumulated across paint passes`. No rect damage appeared, so no CPU-raster pixel run or EGL partial-present work was activated. ADR 0050's three reopen conditions remain the owner of any presenter work. |
