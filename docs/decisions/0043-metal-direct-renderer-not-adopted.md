# 0043: Metal-direct renderer is not adopted

- **Date**: 2026-10-26
- **Status**: Superseded by
  [ADR 0044](0044-no-third-party-graphics-library-gpu-route.md) (2026-10-27). The
  owner fixed a dependency boundary this ADR's option set did not contain — no
  external graphics library, OS frameworks allowed — which voids Decision
  rationale 2 below: `moui_wgpu_renderer` *is* a non-Skia GPU route, but it links
  `wgpu-native`, so it does not serve the boundary. The measured baseline, the
  falsified "no renderer-neutral text gate" premise, the naming trap, and the
  permanent cost list all stay valid and were carried into the active plan.
- **Deciders**: Agent-assisted (decision gate), wzzc-dev (owner)
- **Related**: ADR 0005 (mobile host and GPU), ADR 0007 / 0022 (renderer and
  Skia), ADR 0023 (Sun CPU raster experimental), ADR 0027 (provider surface
  caps); invariants R1 and R7; plan
  [`docs/plans/active/no-third-party-gpu-route.md`](../plans/active/no-third-party-gpu-route.md)

## Context

The question came from an external comparison (gpui, nanoui): both draw Metal /
Vulkan directly instead of embedding Skia, so MoUI was asked to add an
Apple-only direct-Metal renderer over the `CAMetalLayer` the host already hands
providers (`moui/backend/macos/macos_present.mm:308-366`).

Two constraints make this a governance question, not just an implementation
question:

- ADR 0005 permits Metal only *through Skia* — "Direct presentation means Metal
  drawable-backed Skia on iOS/macOS" (`docs/decisions/0005-mobile-host-and-gpu.md:72`),
  with the macOS route recorded as the Skia `MetalGpuSurfaceRoute` (:100). A
  renderer that talks to Metal itself needs an explicit reclassification, the
  same way ADR 0023 had to state Sun's product class separately.
- Invariant R1 (`docs/invariants.md:36`) fixes the route order: Native Skia is
  mainline, native WGPU is diagnostic; reclassification is RFC-required.

A decision gate was set before any renderer code: the route is only worth
building if it buys a capability no existing route provides. Size alone or
preference for in-house code alone was pre-declared insufficient.

## Decision

Do not add a Metal-direct renderer. Record the route as rejected debt with
explicit, ordered re-open conditions
(`docs/plans/debt/metal-direct-backend.md`, now
[`docs/plans/active/no-third-party-gpu-route.md`](../plans/active/no-third-party-gpu-route.md)).
No `moui_metal_renderer` package,
no capability column, no showcase entrypoint.

## Options Considered

### Option A: Metal-direct renderer (no Skia, no wgpu-native)

- Pros: full control over the draw pipeline; would drop both external graphics
  dependencies on Apple; theoretical size win over `wgpu`.
- Cons: measured landing zone is between `sun` (4.06 MB) and `wgpu` (11.05 MB),
  so it buys no size floor that `sun` does not already give; requires a
  hand-written path rasterizer, glyph atlas, and layer/damage model; a fourth
  text-fidelity copy to keep honest; needs both an ADR 0005 amendment and an
  R1 reclassification; and the performance premise cannot currently be measured
  at all.

### Option B: Promote the existing native WGPU route from diagnostic

- Pros: "GPU without Skia" already exists and already links `Metal.framework`
  for the same app at 11.05 MB with 14 hand-written externs (the API surface is
  outsourced to `Milky2018/wgpu_mbt`); it already runs CoreText shaping on
  macOS (`examples/showcase/macos_wgpu/main.mbt:11-12`), i.e. the gpui
  architecture is already present. Cost is one RFC, not one renderer.
- Cons: still carries wgpu-native (~4.80 MB of `__text` at this app); its
  capability column is `partial` for transform/gradient and it is classified
  diagnostic for reasons that need re-checking on evidence before promotion.

### Option C: Ship `sun` CPU raster where size dominates

- Pros: 4.06 MB, 0 externs, `supported` on clip/transform/filter/shader in the
  capability report, 1,128 sun/macos tests plus a real first-present smoke.
- Cons: ADR 0023 + invariant R7 make it experimental with a capability freeze
  and no `auto` selection; `TextShaping` and `EmojiText` are `Partial`; frame
  cost under real load is unmeasured.

### Option D: Build the missing measurement instrument first

- Pros: a renderer-parametric benchmark harness (accepting `RendererProvider`,
  `moui/render/provider_contract.mbt:23`) is the prerequisite for Options A, B
  and C alike, and costs a small fraction of any of them. Today both harnesses
  are typed to `@skia_renderer.SkiaRasterRenderer`
  (`benchmarks/performance_budget/native/main.mbt:255-260`,
  `benchmarks/app_cached_layer/native/main.mbt:143-151`) and
  `checks/performance-budgets.json:4` declares a single runner identity, so no
  non-Skia route has ever produced a frame number.
  **This instrument was built on 2026-10-27 as L0.1 of ADR 0044's route plan**:
  the perf harness is now provider-parametric and `native-sun-raster` produced the
  first non-Skia frame numbers, which answered this option's open question
  negatively (15–233× the shipped renderer's `frameMs` p50). The citations above
  are the post-L0.1 layout of the same file.
- Cons: delivers no user-visible capability by itself.

## Rationale

Every proposed justification for Option A was checked against the current tree
and each one is either already served or unverifiable: size (Option C already
owns the floor), "GPU without Skia" (Option B already owns it, and its barrier
is classification), "Metal + CoreText glyph atlas" (already wired on macOS),
performance (unmeasurable with today's tooling, in either direction). A route
whose only differentiators are "smaller than wgpu" and "we would write it
ourselves" fails the gate that was set for it.

## Consequences

- The route order stays Skia mainline / WGPU diagnostic / Sun experimental; no
  ADR 0005 amendment and no R1 reclassification is opened now. (0044 keeps the R1
  part and does require an ADR 0005 amendment before shipping a non-Skia Metal
  frame.)
- The re-open condition is evidence, not enthusiasm: (1) a renderer-parametric
  benchmark harness exists and `sun` misses the existing `frameMs` budgets on a
  real app; (2) an RFC to promote native WGPU has been considered and rejected
  on evidence; (3) a product needs GPU plus under-11 MB on Apple. All three.
  _(0044 removed the force of (2): promoting native WGPU cannot satisfy "no
  external graphics library", because that is the route that links
  `wgpu-native`.)_
- The immediate reusable lever is the benchmark harness, tracked as the cheap
  prerequisite in the plan, not as part of this ADR.
- `docs/platform-notes-macos.md:97` already names the shipped Skia-on-Metal
  surface "the direct Metal GPU provider"; "direct Metal" is not a
  distinguishing phrase for this candidate and must not be used as one.

## Agent Notes

- **Session context**: size-reduction thread. `-Wl,-dead_strip -Wl,-x` had just
  landed (Studio release 30.51 → 24.56 MB, −19.5%), which is why the three-route
  comparison could be measured on equal linking terms.
- **Agent model**: Qoder agent session, 2026-10-26.
- **Key prompt or instruction**: "参考 gpui nanoui 给 moui 增加一个直接使用
  metal 的后端 是否可行 可行的话 制定一个目标 给目标模式完成者目标" — with an
  explicit gate instruction that the route must die if size or self-interest is
  its only argument.
- **Validation**: `size -m` re-measured on all three `examples/showcase` release
  artifacts (bytes match the recorded baselines exactly); provider seam, FFI
  counts, benchmark-harness typing, and the CoreText wiring each read from
  source. One goal premise was falsified and corrected in the plan: a
  provider-parametric text conformance matrix *does* exist at the measure level
  (`moui_tests/text_conformance/native/text_conformance_test.mbt:104-123`,
  already driven by non-Skia providers at :362-407); only the paragraph /
  hit-test layer and the Skia maturity strings are Skia-bound. No renderer code
  was written, so no new test surface entered the pr profile.

## References

- `docs/plans/active/no-third-party-gpu-route.md` (measurements, kill list, staged
  gates — carried forward after the 0044 reopen)
- `docs/invariants.md:36` (R1), `:37` (R7)
- `docs/decisions/0005-mobile-host-and-gpu.md:72,100`
- `docs/decisions/0023-sun-experimental-renderer.md`
- `docs/renderer-capability-report.md:47-65`
- `moui/backend/macos/macos_present.mm:308-366`
