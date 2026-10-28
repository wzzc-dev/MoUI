# 0044: A GPU route with no external graphics library is authorized (Apple-first, experimental)

- **Date**: 2026-10-27
- **Status**: Accepted — **L0 executed on 2026-10-27 and its kill gate fired on the
  performance branch.** The performance motive is gone (the shipped Skia-Metal
  route already holds the renderer-attributable slice at 0.10–0.76 ms p50 while the
  frame costs are framework-side) and the license motive is struck (L0.3). What
  survives is narrower than what was claimed: **size versus the Skia mainline**
  (a compliant Metal route should land well under 20.35 MB, and under this
  boundary it is the *only* GPU-capable option — `sun` has no GPU and `wgpu` is
  excluded) and **autonomy**, which is the owner's call. The sub-MB ambition is
  dead: the floor is MoUI's own ≈4.0 MB framework body, not a backend choice.
  Nothing further is authorized on performance or license grounds; entering L1
  requires re-pricing the two surviving motives on their own. See the plan's
  "L0.4 measured" section and its Decision-log row. **Later the same day the owner
  directed the two structural steps anyway** ("把文本 provider 从 wgpu 模块搬出，
  然后实现 moui_metal_renderer"): L0.5 relocated the five text providers into
  `wzzc-dev/moui_text_providers`, and L1 landed `wzzc-dev/moui_metal_renderer`
  with its measured evidence recorded in ADR 0045. The kill gate's verdict on the
  performance and license motives is unchanged by that: the route now exists
  because the owner wants the size-versus-Skia and autonomy motives priced by
  real code, not because a gate asked for it. **Corrected 2026-10-28 by the route's
  own release build**: the "≈4.0 MB framework floor, a GPU route lands between 4.06
  and 11.05 MB" figure below is a derivation from `wgpu` − `sun`, and the built
  route is 4,101,856 B — 158,832 B *below* `sun`, with 171,436 B less `__text`. The
  sub-MB ambition stays dead and the size-versus-Skia motive is stronger than this
  ADR credited; the measurement and its limits are in ADR 0045, §"Amended 2026-10-28
  (L4 size)".
- **Deciders**: wzzc-dev (owner, set the dependency boundary), agent-assisted
  (verification and staging)
- **Related**: supersedes the *conclusion* of ADR 0043 and keeps its
  measurements; amends ADR 0005 (Metal only through Skia); invariants R1 (`docs/invariants.md:36`)
  and R7 (`:37`); ADR 0023 (the model for declaring a new route experimental),
  ADR 0027 (provider surface caps); plan
  [`docs/plans/active/no-third-party-gpu-route.md`](../plans/active/no-third-party-gpu-route.md)

## Context

ADR 0043 rejected an Apple-Metal-direct renderer after four checks. The owner
then fixed a boundary that none of those four checks included: **no extra
third-party graphics library**, with OS-provided frameworks explicitly allowed
(`Metal`, `QuartzCore`, `CoreText`, `CoreGraphics`, `AppKit`) — the gpui shape.

That boundary changes the option set, because the two existing GPU routes are
both inside the excluded set:

| Route | GPU | External graphics library it links |
|---|---|---|
| `moui_skia_renderer` (mainline) | yes | Skia |
| `moui_wgpu_renderer` (diagnostic) | yes | `wgpu-native` via `Milky2018/wgpu_mbt` (`moui_wgpu_renderer/moon.pkg:6-7`) |
| `moui_sun_renderer` (experimental) | no — CPU raster | none |

So kill reason 2 of ADR 0043 ("GPU without Skia already exists") is void: as of
this ADR, {has GPU} ∩ {links no external graphics library} is empty. Kill reason
1 survives only in reduced form (see the plan's size band), kill reason 3 survives
as a fact but no longer as a rejection, and kill reason 4 — the performance
premise cannot be measured with current tooling — stands completely and becomes
this route's first stage rather than a footnote.

The owner named three motives: target-platform coverage, size plus long-term
autonomous evolution, and license / IP chain. This ADR records what each is worth
today: autonomy is a strategy decision the owner may make without measurement;
size is a modest, already-bounded win; **platform coverage is not served by an
Apple-only route**, and **licensing has no in-repo conclusion yet** —
`THIRD_PARTY.md:15-30` records only that MoUI does not vendor Skia or
`wgpu-native` and that supplied builds "remain governed by … upstream license
terms", naming no SPDX and no obligations.

## Decision

Authorize the route as a staged plan, not as an implementation sprint:

1. `docs/plans/active/no-third-party-gpu-route.md` becomes the single owner of
   scope and gates (moved from `docs/plans/debt/metal-direct-backend.md`).
2. **L0 ships before any drawing code**: a renderer-parametric benchmark harness,
   extraction of the neutral native text model out of the wgpu-importing package,
   and a license fact sheet. Each has a stated kill gate; L0.1's is "if `sun`
   meets the existing `frameMs` budgets on a real app, the performance case is
   dead and the route continues only on size + autonomy, explicitly re-priced".
3. Compliance is verified from the artifact, not from intent: `otool -L` / `nm` /
   `strings` on a release build must show no Skia and no wgpu symbols or link
   entries, with the hand-written `extern "C" fn` count inside the estimated
   10–40 budget.
4. Product class is `experimental` with its own ADR when it lands, following ADR
   0023's precedent. No `auto` selection.
5. Nothing here changes R1. Skia remains mainline and native WGPU remains
   diagnostic; an R1 reclassification still requires an RFC, and this route does
   not preempt it.

## Options Considered

### Option A: authorized route, staged, gated at L0 (chosen)

- Pros: serves the only capability no current route can serve (GPU without an
  external graphics library); reuses three things that already exist and were
  verified today — the host's `CAMetalLayer` and its
  `moui_macos_surface_layer_from_view` export
  (`moui/backend/macos/macos_present.mm:308,334-342`), the repo-owned tessellator
  in `moui/render/common`, and the system-frameworks-only CoreText provider
  (`moui_text_providers/coretext/moon.pkg`, 4 externs at `coretext_text.mbt:439-465`);
  keeps the kill gate in front of the expensive part.
- Cons: MoUI takes ownership of GPU path antialiasing, gradients, filters, clip
  and damage correctness, glyph-atlas residency, and device-lost recovery — the
  exact surface Skia currently absorbs; a fourth text-fidelity copy to keep honest;
  the full renderer registration cost (release-modules, profiles, capability
  report + zh-Hans mirror, provider gates) is permanent.

### Option B: reject again, keep the 0043 record

- Pros: zero new cost; `sun` remains the answer for size, Skia for GPU.
- Cons: cannot serve the owner's stated boundary at all — every GPU answer would
  link an excluded library, which converts a technical decision into a standing
  conflict with the project's own dependency policy.

### Option C: promote `moui_wgpu_renderer` instead

- Pros: cheapest path to "not Skia" (one RFC, 14 hand-written externs already,
  CoreText already wired on macOS at 11.05 MB).
- Cons: does not satisfy this boundary — it is the route that links
  `wgpu-native`. Recorded here so the rejection is explicit rather than silent.

### Option D: build the harness only, decide later

- Pros: removes guessing from all four routes' frame numbers for a small cost.
- Cons: leaves the authorized capability unbuilt. Adopted *inside* Option A as L0
  rather than as the whole answer.

## Consequences

- ADR 0043's conclusion is superseded; its measurement table, the falsified
  "no renderer-neutral text gate" premise, and the naming trap remain valid and
  are carried into the plan.
- ADR 0005 must be amended before any Metal-not-through-Skia frame is shipped,
  not merely before release: today it permits Metal only as
  "Metal drawable-backed Skia" (`docs/decisions/0005-mobile-host-and-gpu.md:72,100`).
- "Target-platform coverage" is recorded as **not** delivered by this route.
  Metal is Apple-only; D3D12 would be OS-shipped on Windows; Linux and the RISC-V
  embedded targets have no OS-owned GPU API, so a compliant Vulkan backend means
  hand-writing swapchain, synchronization and explicit memory binding — i.e.
  owning the abstraction wgpu-hal provides. That is a separate ADR and a
  materially different commitment; this plan's only obligation toward it is that
  the neutral halves stay platform-neutral (L0.2).
- "License / IP chain" is recorded as an **unverified** motive until L0.3 lands.
  If Skia and `wgpu-native` turn out to be permissive and non-blocking, the
  motive is removed from the record rather than kept as folklore.
  **L0.3 landed 2026-10-27 and this bullet's condition is met, so the motive is
  struck.** Everything locally confirmable is permissive (Apache-2.0/MIT MoonBit
  graph; BSD/MIT/Zlib/libpng/FTL texts in the Skia package). The real gap is
  notice completeness: the macOS link line names eight archives and the delivered
  artifact carries text for one of them (HarfBuzz), with no Skia root `LICENSE` and
  no ICU terms — and since the locked provider is this project's own
  `wzzc-dev/skia` artifact, those notices are ours to add. See
  `THIRD_PARTY.md`, Skia and "License Motive Conclusion" sections.
- Every existing MoUI frame number is measured through a **no-op presenter**
  (`SkiaPresentTarget`'s `present` closure discards the frame,
  `benchmarks/performance_budget/native/main.mbt:262-264`, still the site the
  concrete pump uses on the `raster` route) on the **forced CPU
  raster** route, while the Apple product default is
  `MetalGpuSurfaceRoute` (`moui_skia_renderer/native_gpu_policy.mbt:105-114`).
  Presentation cost is unmeasured, and the shipped route has never been
  benchmarked — so L0 gained a control step (L0.4) whose failure also kills this
  route: if the GPU route Skia already provides consumes the renderer-attributable
  slice, a hand-written backend would only re-acquire the same savings while
  adding an owned rasterizer.
  **L0.4 landed 2026-10-27 and the gate fired on this branch.** Measured through
  the committed budget runner, 3 interleaved rounds × 40 frames, the shipped
  route's renderer-attributable `presentMs` is 0.100–0.762 ms p50 once the
  drawable rotation a real `CAMetalLayer` forces is priced in, while the
  scenarios that dominate the frame (excel 12.5 ms, deep 4.8 ms) are 92–95%
  framework. Two measurement traps the run exposed: the CPU-raster baseline
  overstated scroll present by ~3.5×, and `metal-gpu`'s number is a
  GPU→CPU `read_pixels` cost, not an engine comparison. No committed timing budget
  separates any of the four routes (0 of 140 sample/budget ratios exceed 1.0;
  tightest 0.80), so the budgets are ceilings rather than evidence.
- Size versus the *floor* is not an output of this route, measured rather than
  argued: a one-line MoonBit native release binary is 266,600 B, and `macos_sun` —
  which links no graphics library — is 4,260,688 B, so ~4.0 MB of the artifact is
  MoUI's own framework body. A no-third-party renderer adds a rasterizer to that
  body and cannot take any route sub-MB; that ambition is dead. Size versus the
  **Skia mainline** survives and is the route's strongest remaining argument:
  the measured band puts a GPU route between `sun`'s 4.06 MB and the wgpu route's
  11.05 MB (derived engine cost ≈4.80 MB of `__text`), i.e. well under Skia's
  20.35 MB — and under the owner's boundary this is the only GPU-capable compliant
  option, since `sun` has no GPU and `wgpu` links an excluded library. Whether it
  beats 11.05 MB is unmeasured, not assumed. (Measured 2026-10-28, and both
  sentences in this bullet that speak of a floor and a band are void: the route is
  4,101,856 B — below `sun` — see ADR 0045 §"Amended 2026-10-28 (L4 size)".) (Self-
  correction, same day: an earlier L0 writeup over-generalised the floor finding
  into "size cannot come from this route at all". It cannot come from it *below the
  floor*; it does come from it *relative to Skia*.) No gate enforces any of these
  numbers — `checks/performance-budgets.json` `packageBytes` limits (70–105 MB) are
  placeholders.
- `docs/platform-notes-macos.md:97` already uses "the direct Metal GPU provider"
  for the shipped Skia-on-Metal surface; the distinguishing property of this
  route is "no Skia, no wgpu", and docs must say that.

## Agent Notes

- **Session context**: continuation of the size/GPU-backend thread. The
  `-Wl,-dead_strip -Wl,-x` linker flags had just landed (Studio release
  30.51 → 24.56 MB), which is what made the three-route comparison fair.
- **Key prompt or instruction**: "想增加一个不想使用额外的第三方库的gpu路径",
  then the boundary choice "系统框架可用，只排除外部图形库".
- **Self-correction recorded**: ADR 0043's rejection reason 2 assumed the
  non-Skia GPU need was already served. It is served, but only by a route inside
  the newly excluded set, so the reason does not hold. Separately, the agent
  claimed "the repo records no Skia/wgpu license conclusion"; `THIRD_PARTY.md`
  does exist and does cover both engines, but only as a non-vendoring/provenance
  policy — it names no license, so the claim was overstated and the correction is
  magnitude: a notice file exists, a conclusion does not.
- **Validation**: no renderer code written. Every plumbing claim in the Context
  section was read from source on 2026-10-27 (`macos_present.mm`,
  `moui_wgpu_renderer/moon.pkg`, `moui_wgpu_renderer/coretext/moon.pkg`,
  `native_text_model.mbt:100` as it then stood, `text_protocol/moon.pkg`),
  including the negative
  finding that the CoreText provider's 17 `@wgpu_renderer` references are all
  data types declared inside the wgpu-importing package — which is why L0.2
  exists as an extraction step rather than a reuse step. The five provider
  packages were relocated into `moui_text_providers/` later the same day (plan
  stage L0.5), so the `moui_wgpu_renderer/<provider>` paths above are the
  pre-move layout.
  That finding is now
  historical: L0.2 moved those types, so `native_text_model.mbt:100` now falls
  inside the renderer's remaining atlas/vertex state (`:99` is
  `text_vertex_stride`) rather than the `NativeTextEngine` declaration.
- **L0 execution (later the same day)**: L0.1, L0.2, L0.3 and L0.4 delivered. L0.1
  first became route-parametric and then, in the same session, provider-parametric:
  the perf harness now pumps frames through a `RendererProvider` when
  `MOUI_PERFORMANCE_PROVIDER=skia-neutral|sun`, keeps the concrete Skia path as the
  only budget-gated runner, and emits a distinct runner identity per provider. That
  closed the gate's formally-untested first branch with a negative answer — the
  boundary-compliant CPU provider lands at 15–233× the shipped renderer's `frameMs`
  p50 and breaks 4 of 5 committed ceilings, so "adopt the existing CPU renderer and
  frames get cheaper" is measured out rather than assumed. No
  renderer code, no package registration, no ADR 0005 amendment. Two self-
  corrections during the run: an initial note claimed the macOS product "links 28
  archives" — the verified figure is 29 shipped / 8 on the darwin link line,
  `-lfreetype` is Linux-only (`moui_skia/build.js:777`), and the release binary is
  stripped so `nm` counts are inconclusive; and the L0.4 draft treated
  all-zero `buildMs`/`layoutMs` as a broken probe, when they are only timed on the
  dirty path — the missing instruments were `drawMs`/`totalMs`.

## References

- `docs/plans/active/no-third-party-gpu-route.md`
- `docs/decisions/0043-metal-direct-renderer-not-adopted.md` (superseded conclusion)
- `docs/decisions/0005-mobile-host-and-gpu.md:72,100`
- `docs/decisions/0023-sun-experimental-renderer.md` (product-class precedent)
- `THIRD_PARTY.md:15-30`
- `moui/backend/macos/macos_present.mm:308,334-342`
- `moui_wgpu_renderer/moon.pkg:6-7`, `moui_text_providers/coretext/moon.pkg`
- `moui/render/native_text/text_model.mbt:5` (`NativeTextEngine`, since L0.2; was
  `moui_wgpu_renderer/native_text_model.mbt:100`)
