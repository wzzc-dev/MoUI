# Plan: no-third-party GPU renderer (`moui_metal_renderer`, Apple-first)

- **Status**: **active, L1 delivered on 2026-10-27 (L1a–L1c: the evidence
  frame exists and is pixel-proved)**. Authorized by the owner as the second
  decision of the day. L0 executed and its kill gate fired on the performance
  branch, so the frame-cost prize is *not* the reason this proceeds; the owner
  re-priced the surviving case — size versus Skia plus long-term autonomous
  evolution — and directed: relocate the text providers out of the wgpu module
  (L0.5), then implement `moui_metal_renderer` (L1). Both are done (2026-10-27):
  the five providers are `wzzc-dev/moui_text_providers`, and
  `wzzc-dev/moui_metal_renderer` draws the L1 acceptance frame — clear colour,
  filled rects, solid path fills and one real CoreText glyph run — with zero
  Skia and zero wgpu in the link. L2 (`DrawCommand` honesty across all 26
  variants), L3 (text fidelity, where the shared-atlas question is decided) and
  L4 (capability truth, GPU recovery) are the remaining stages. L0.2 is done (2026-10-27);
  L0.1 is done for the two headless providers (2026-10-27), which also closes the
  gate's second, untested branch: `sun` does **not** meet the `frameMs` budgets.
  Both stayed live as framework work independent of this route's fate, which is why
  this file stays in `active/`. See ADR
  [0044](../../decisions/0044-no-third-party-graphics-library-gpu-route.md), which
  supersedes ADR 0043's conclusion and keeps its measurements.
- **Standing limit on L1**: the performance motive stays dead. If a Metal frame
  ever beats Skia's, that is a new measurement requiring its own decision, not a
  reason to re-open this one; and every L1 number must come from a real window —
  the headless harness cannot bind a GPU provider
  (`moui_wgpu_renderer/binding_factory.mbt:25-27` is the precedent for why).
- **Fixed boundary (owner, 2026-10-27)**: OS-provided frameworks are allowed —
  `Metal`, `QuartzCore`, `CoreText`, `CoreGraphics`, `AppKit`. External graphics
  libraries are not — Skia and `wgpu-native` / `Milky2018/wgpu_mbt`. This is the
  gpui shape, not a from-scratch stack.
- **Named owner motives** (all three were recorded as selected): target-platform
  coverage, size plus long-term autonomous evolution, license / IP chain. Each
  gets its own verification step below; two of the three are currently
  unevidenced in-repo, and this plan does not let them become load-bearing by
  assertion.
- **L0 verdict (2026-10-27), motive by motive**: platform coverage — **not served**
  (Apple-only; see "The open fork"). License / IP — **struck**, everything locally
  confirmable is permissive and the gap is notice completeness (L0.3, now in
  `THIRD_PARTY.md`). Performance — **no prize left**: the shipped Skia-Metal route
  already holds `presentMs` at 0.10–0.76 ms p50 while the frame-dominating
  scenarios are 92–95% framework (L0.4), and the boundary-compliant CPU provider
  that exists measures 15–233× *worse* than the shipped renderer, not better
  (L0.1). Size — **split, and the split was pessimistic in this route's favour**:
  L0 predicted "nothing below the ≈4.0 MB framework floor, but a real
  20.35 MB → 4.06–11.05 MB band versus Skia"; measured at L4 the Metal artifact is
  3.91 MB, below the floor and below `macos_sun` (see **Measured baseline**).
  Autonomy — **live, and
  the owner's call**, not measurement's. L0's kill gate fired on the performance
  branch, so this plan does not enter L1; the surviving case is size-versus-Skia +
  autonomy, and it must be re-priced on its own rather than carried by the two
  motives that died.
- **Non-goals (this plan)**: no change to invariant R1 (Skia stays mainline, WGPU
  stays diagnostic); no `auto`-mode selection of the new route; no promotion of
  `moui_wgpu_renderer`; no cross-platform GPU abstraction layer (see the fork).

## Measured baseline

Same app (`examples/showcase`), same flags (`--release --target native`, all
linked with `-Wl,-dead_strip -Wl,-x`, which is why those two flags appear
temporarily in the entrypoint's `moon.pkg` and are reverted afterwards),
measured with `size -m`:

| Route | Artifact | `__text` | `__const` (TEXT) | GPU | External graphics lib | Hand-written `extern "C" fn` |
|---|---|---|---|---|---|---|
| `macos_skia` (mainline) | 20.35 MB (21,340,336 B) | 9.09 MB (9,092,412) | 11.39 MB (11,390,176) | yes, via Skia | Skia | 292 (`moui_skia/native`) |
| `macos_wgpu` (diagnostic) | 11.05 MB (11,591,088 B) | 8.50 MB (8,498,112) | 1.33 MB (1,328,452) | yes, `otool -L` shows `Metal.framework` | `wgpu-native` + `Milky2018/wgpu_mbt` | 14 |
| `macos_sun` (experimental) | 4.06 MB (4,260,688 B) | 3.70 MB (3,699,004) | 0.34 MB (338,848) | no, CPU raster | none | 0 |
| `macos_metal` (this plan) | 3.91 MB (4,101,856 B) | 3.36 MB (3,527,568) | 0.32 MB (339,584) | yes, direct — `otool -L` shows `Metal.framework` | none | 8 (`moui_metal_renderer/metal_device.mbt`) |

The skia/wgpu/sun rows are the 2026-10-26 numbers; the `sun` row was re-measured
on 2026-10-28 alongside the Metal build and came out byte-identical, so the two
are a same-toolchain pair rather than a comparison across two days.

**Refuted by its own measurement.** The derivation recorded here on 2026-10-27
was: *"the GPU engine's own code is about 4.80 MB of `__text` (`wgpu` − `sun`).
A hand-written Metal renderer's realistic landing zone is between `sun` and
`wgpu`. The size motive therefore survives only as 'GPU **and** well under Skia's
20.35 MB' — it does not beat the `sun` floor."* The premise was that reaching a
GPU costs an engine of roughly `wgpu` − `sun`, and that number is wgpu's engine
size, not the price of a GPU. Measured, the Metal route lands **below** the
`sun` floor — 158,832 B smaller in total artifact, and its `__text` is 171,436 B
smaller than Sun's whole CPU rasterizer, while `__const` is 736 B larger. So the
band "any new GPU route lands between 4.06 and 11.05 MB" is void, and the size
motive is stronger than it was credited: GPU, a fifth of Skia's artifact, and the
repo's smallest route.

What the measurement does *not* say: it is not a packaging-gate number.
`moui package macos` builds debug artifacts, and
`checks/performance-budgets.json`'s `packageBytes` limits are 70/80/100 MB
placeholders that no route approaches, so no gate requires or forbids any number
in this table.

Release-artifact boundary proof for the Metal row, on the same build
(`_build/native/release/build/examples/showcase/macos_metal/macos_metal.exe`):
`otool -L` lists only Apple system frameworks plus `libSystem`/`libz`/`libobjc`
(Metal, CoreText, CoreGraphics, ImageIO, ColorSync, QuartzCore, CoreVideo,
AppKit, Foundation, UniformTypeIdentifiers, ApplicationServices, CoreFoundation),
and `nm -a` finds 0 matches for `skia|Skia|wgpu|hal::|vulkan|Vulkan` with
`strings -a` finding none either — the excluded-set claim holds at the shipped
binary, not only in `moon.pkg`.

## What ADR 0043 killed, and what the new constraint changes

| 0043 kill reason | Still true under the fixed boundary? |
|---|---|
| 1. "Smaller binary" — `sun` already owns the floor | **False, and it was false as a prediction.** It was written before the route existed; measured 2026-10-28 the Metal artifact is 158,832 B *below* the `sun` figure quoted here. The floor was CPU-raster-shaped, not GPU-shaped. |
| 2. "GPU without Skia already exists" (`moui_wgpu_renderer`) | **Void.** That route links `wgpu-native`, so it is inside the excluded set. {GPU} ∩ {no external graphics lib} is empty today. |
| 3. "Metal + CoreText glyph atlas is already wired" | **Void as a rejection, still true as a fact.** The wiring exists. Its neutral text types used to live in the package that imports `Milky2018/wgpu_mbt`; the extraction (L0.2, done 2026-10-27) moved them to `moui/render/native_text`, so the provider data model is now reusable as-is. |
| 4. "Performance premise is unmeasurable in both directions" | **Fully stands, and becomes L0.** |

("We want to write it ourselves" remains excluded as a justification. The
surviving non-measurable motive is long-term autonomous evolution, which is a
strategy choice the owner is entitled to make — the plan's job is to price it,
not to litigate it.)

## Verified plumbing (read from source, 2026-10-27)

- **The host already owns the Metal layer, renderer-neutrally.**
  `moui/backend/macos/macos_present.mm:334-342` creates/adopts a `CAMetalLayer`
  (`name = "moui_host_surface_layer"`) and `:308` exports
  `moui_macos_surface_layer_from_view(raw_view, width, height, scale)` returning
  the raw handle. A Metal-direct renderer needs no host changes to present.
- **The Metal calls actually needed for presentation are a handful.** The shipped
  Skia GPU path reaches Metal with `MTLCreateSystemDefaultDevice()`
  (`moui_skia/native/skia_stub_surface_image_data.cpp:65,99`) plus
  `objc_msgSend` `nextDrawable` / texture access (:1824-1836) — the ObjC
  trampoline pattern is small and precedented (the CPU presenter is 10
  `MOONBIT_FFI_EXPORT` in `macos_present.mm`).
- **Text shaping is already external-library-free.**
  `moui_text_providers/coretext/moon.pkg` links only
  `AppKit QuartzCore CoreText CoreGraphics Foundation CoreFoundation -lobjc -lz`,
  and `coretext_text.mbt:439-465` is 4 externs
  (`measure_utf32`, `layout_glyphs_utf32`, `raster_glyph`,
  `register_font_data`).
- **…and its types now are too (L0.2, 2026-10-27).** The provider data model
  (`NativeTextEngine`, `NativePlatformTextProvider`, `NativeGlyphKey`,
  `NativeTextLayout`, `NativeGlyphPlacement`, `NativeRasterGlyph`) plus layout
  validation and the measure/layout caches live in
  `moui/render/native_text/`, whose `moon.pkg` imports only
  `wzzc-dev/moui/core`. All five native text packages — `coretext`,
  `cosmic_text`, `directwrite`, `fontconfig`, `text_protocol` — import that
  package and no longer import the wgpu renderer root, so
  `moui_wgpu_renderer` keeps only what is genuinely wgpu-owned: the glyph atlas
  upload, the text vertex builder, and the WGSL side. Two residuals this did
  **not** erase, and the plan recorded them rather than glossing them: the five
  packages still physically lived *inside* the `moui_wgpu_renderer` module
  (`moui_wgpu_renderer/coretext/`, `moui_wgpu_renderer/text_protocol/`), so
  reusing them still meant depending on that module even though nothing in them
  now depended on the renderer; and `coretext` / `directwrite` / `fontconfig`
  still imported the sibling `wzzc-dev/moui_wgpu_renderer/text_protocol`. Moving
  them is a module-layout decision of its own, not part of L0.2 — that decision
  is L0.5 below, and both residuals are closed there.
- **Geometry is already repo-owned.** The path tessellator lives in
  `moui/render/common` (`advanced_execution.mbt`, exercised by
  `path_fill_tessellation_wbtest.mbt`) and is shared by the WGPU and Web routes,
  so the non-trivial algorithmic half is not something this route must invent.

Estimated hand-written FFI bill under the fixed boundary: **≈10–40 externs**
(device, queue, drawable, render-pass descriptor, pipeline state, glyph-texture
upload), not the 292 of `moui_skia/native`.

## The open fork, stated plainly

"Target-platform coverage" is **not** served by an Apple-only Metal renderer.
Metal exists on Apple; D3D12 ships with Windows (so it satisfies
"OS-provided framework"); Linux and the RISC-V/embedded targets have no
OS-owned GPU API — `libvulkan.so` is driver-supplied, and hand-writing a Vulkan
renderer (swapchain, sync objects, explicit memory binding, render passes) is a
materially larger bill than Metal and is where "own the abstraction instead of
depending on wgpu-hal" actually concentrates cost. This plan proceeds
Apple-first and requires only that the platform-neutral halves stay neutral
(L0.2). A second GPU API is a separate ADR, not a phase of this one.

## What the repo's own frame numbers can and cannot say

`artifacts/performance/result.json` (generated 2026-09-06, `runner:
native-skia-raster`, medians over non-zero samples):

| Scenario | `frameMs` | `presentMs` | `paintMs` | `layoutMs` | `buildMs` |
|---|---|---|---|---|---|
| showcase-runtime-scroll | 3.107 | 2.947 | 1.086 | 0.239 (9/60 samples) | 0 |
| excel-grid-navigation | 19.597 | 1.651 | 17.339 | 0 | 0 |
| virtual-list-100k | 0.722 | 0.376 | 0.255 | 0.078 | 0 |
| multi-window-4 | 0.826 | 0.362 | 0.358 | 0.108 | 0.001 |
| deep-tree-env-toggle | 7.661 | 0.826 | 2.896 | 1.266 | 2.244 |
| markdown-editor-text-input | 0.336 | 0.333 | 0 | 0 | 0 |

Three limits on reading these as "MoUI's frame cost", and they decide what L0
must fix first:

- **The presenter is a no-op.** `benchmarks/performance_budget/native/main.mbt:262`
  constructs `SkiaPresentTarget` whose `present` closure ignores the frame and
  returns `true` (the same shape as the neutral pump's presenter at :348), and the
  app runs headless. So the column named `presentMs`
  measured nothing resembling putting pixels on a screen, and the product's real
  GPU present path was entirely unbenchmarked. L0.4 added the host-surface modes
  that take a real GPU target; `raster` and `metal-gpu` still use this closure.
- **Every number is the forced CPU raster route.** `SkiaRaster` is requested
  explicitly (`surface_route_for` at
  `moui_skia_renderer/native_gpu_policy.mbt:105-108`), while the Apple product
  default is `MacOS | IOS => MetalGpuSurfaceRoute` (:114). The repo therefore has
  **zero measurements of the route it actually ships.**
- **Framework cost is invisible, not small.** `buildMs` is all-zero in four of
  six scenarios and `layoutMs` all-zero in two, so the retained-tree/build slice
  — the part no renderer can touch — is unmeasured exactly where it matters. The
  columns also do not nest (scroll's `present`+`paint` median exceeds `frameMs`
  because they are medians over different sample subsets), so treat the split as
  indicative only.

Consequence for this route: the cheapest experiment that tests the performance
motive is not a new backend, it is **the same app measured through the GPU route
Skia already provides**. Until that number exists, "a Metal-direct renderer would
make frames cheaper" has no baseline to be compared against.

## L0.4 measured (2026-10-27): the shipped route, priced

`MOUI_PERFORMANCE_SURFACE_ROUTE` now selects one of four present paths in
`benchmarks/performance_budget/native/main.mbt`, each with its own runner label,
so a GPU number can no longer be written under the raster identity:

| Mode | Runner label | What `presentMs` contains |
|---|---|---|
| `raster` | `native-skia-raster` | CPU raster surface + `read_frame` pixel copy (the gated runner) |
| `metal-gpu` | `native-skia-metal-gpu-cpu-frame` | Skia-on-Metal **plus** the GPU→CPU `read_pixels` copy |
| `metal-gpu-host` | `native-skia-metal-gpu-host-surface` | Skia-on-Metal, no CPU copy, one stable stand-in drawable |
| `metal-gpu-host-rotating` | `...-host-surface-rotating` | as above, plus a fresh GPU surface every frame (drawable rotation) |

`perf_renderer` `perf_fail`s on two identity conditions (`surface_is_gpu()` and
`target_kind()`) instead of mislabelling, so the four rows cannot silently
degrade into one another; the harness only reaches a Metal GPU surface if a real
Metal context handed one back. `drawMs` and `totalMs` are now emitted and gated
(`tools/moui/validate_performance_budgets/model.mbt`), which is what makes the
framework slice separable from the raster slice at all.

Three interleaved rounds × 40 frames, one machine, p50 ms pooled over rounds
(`artifacts/performance/l04/`, git-ignored):

| Scenario | raster `present` | metal-gpu `present` | rotating-host `present` | rotating-host `frame` | framework share of `frame` |
|---|---|---|---|---|---|
| showcase-runtime-scroll | 2.697 | 1.867 | 0.762 | 0.796 | 4% |
| excel-grid-navigation | 1.060 | 1.511 | 0.636 | 12.506 | 95% |
| virtual-list-100k | 0.170 | 0.388 | 0.100 | 0.345 | 71% |
| multi-window-4 | 0.230 | 1.113 | 0.221 | 0.643 | 66% |
| deep-tree-env-toggle | 0.527 | 1.060 | 0.409 | 4.789 | 92% |

Four things this settles:

- **The renderer-attributable slice is ≤0.76 ms at p50 on the route closest to
  what Apple ships**, and the two scenarios that actually cost frames are
  92–95% framework (`paintMs`/`buildMs`/`layoutMs`/`drawMs`). A hand-written
  backend that was perfectly free would take excel 12.51→11.87 ms and deep-tree
  4.79→4.38 ms. Nothing in the performance motive lives there.
- **The committed raster numbers overstate the product.** `presentMs` for scroll
  is 2.697 on the gated raster runner vs 0.762 on the rotating host route — the
  repo's headline `presentMs` was ~3.5× the shipped path, so "present is the
  dominant stage" was an artifact of benchmarking the fallback.
- **`metal-gpu` is a trap, not a comparison.** Presenting a GPU surface through a
  CPU pixel frame is 1.7–5.9× the raster `presentMs`; that ratio is the price of
  `read_pixels`, not of the GPU engine. Any "GPU is slower than raster" claim
  made through a CPU-frame presenter is measuring the copy.
- **The budget gate cannot decide this route.** Across 4 routes × 5 scenarios ×
  7 timing metrics (140 measured/budget ratios), the tightest is 0.80 and none
  exceeds 1.0; `presentMs` on the host routes sits at 0.007–0.051 of budget. The
  committed `frameMs`/`presentMs` ceilings are crash detectors, so the gate had
  to be answered by attribution, not by pass/fail.

Residual gap, stated rather than glossed: the harness is headless, so
`present_gpu` never touches `CAMetalLayer`, `nextDrawable` or a vsync-blocked
`present:`. The rotating mode buys per-frame surface acquisition — the largest
component that can be synthesized without a window — but the display handoff and
vsync stay unmeasured. They are also backend-independent: no choice of rasterizer
changes them. Reproducing them needs the live-window path
(`scripts/macos-skia-renderer-smoke.sh`), which is a different instrument.

## L0.1 measured (2026-10-27): the neutral pump, and the first time a non-Skia route produced a frame number

`MOUI_PERFORMANCE_PROVIDER` selects who owns the frame pump, and each choice
emits its own runner identity:

| Provider | Runner label | Frame path | Budget-validated? |
|---|---|---|---|
| `skia` (default) | `native-skia-raster` (+ the three `metal-gpu` labels) | concrete `SkiaRasterRenderer` | yes — unchanged, so the committed ceilings still describe the runner they were measured on |
| `skia-neutral` | `native-skia-raster-via-provider` | `@skia_renderer.raster()` bound as a `RendererProvider`, driven through `RendererSession::render_frame` | no — control run |
| `sun` | `native-sun-raster` | `@render_sun.raster()` through the same neutral contract | no — control run |

A single 60-frame + 12-warmup run per provider, sequential on one machine, p50
over the non-zero samples (`artifacts/performance/result*.json`, git-ignored).

**The neutral pump is the same instrument as the concrete one.** That is the
claim the harness had to earn before any non-Skia number could be trusted,
because a session wrapper that quietly did extra per-frame work would flatter or
penalize every future route measured through it:

| Scenario | `skia` `frameMs` | `skia-neutral` `frameMs` | Δ |
|---|---|---|---|
| showcase-runtime-scroll | 2.480 | 2.541 | +2.5% |
| excel-grid-navigation | 11.602 | 11.301 | −2.6% |
| virtual-list-100k | 0.363 | 0.357 | −1.7% |
| multi-window-4 | 0.563 | 0.552 | −2.0% |
| deep-tree-env-toggle | 4.539 | 4.723 | +4.1% |

Same engine, same scenario, and `cacheHitRate` identical to four decimals in all
five scenarios (0.0417 / 0 / 0 / 0 / 0.0224) — which is the app-side proof that the
two paths fed the renderer the same frames. The two paths are **not** bit-identical
by construction: the provider factory sets `async_image_loading=true`
(`moui_skia_renderer/binding_factory.mbt:28`) while the harness's direct constructor
takes the `false` default (`moui_skia_renderer/renderer.mbt:211`), so a non-zero Δ is
expected and this A/B only bounds what that flag costs.

**That bound is weaker than the table above suggests, and the weakness is measured,
not assumed.** The gated `skia` run was repeated later in the session, after a
formatting-only `moon fmt` pass — same runner, same code, same binary layout — and
every scenario moved:

| Scenario | `skia` run 1 | `skia` run 2 | self-drift |
|---|---|---|---|
| showcase-runtime-scroll | 2.480 | 2.669 | +7.6% |
| excel-grid-navigation | 11.602 | 11.816 | +1.8% |
| virtual-list-100k | 0.363 | 0.403 | +11.0% |
| multi-window-4 | 0.563 | 0.616 | +9.4% |
| deep-tree-env-toggle | 4.539 | 4.670 | +2.9% |

So the whole ±4% A/B sits **inside** the same runner's own repeat spread. That cuts
both ways: it strengthens "the neutral pump is the same instrument" (the A/B is
indistinguishable from noise), and it forbids reading ±4% as the price of
`async_image_loading` — at this resolution that flag is not separable. It does
**not** move the gated runner: `skia` stays on the concrete path so no committed
baseline is re-priced as a side effect.

Protocol caveat: these runs were sequential, not interleaved. L0.4 used three
interleaved rounds precisely to keep thermal drift out of its comparisons; this A/B
did not, and the drift is one-directional (later runs are slower on the small
scenarios; `sun` shows +20% `buildMs` / +17% `layoutMs` on identical framework code
paths). Read anything under ~10% here as drift, not as signal — which is exactly why
the route-relevant finding below is sun's 15–233× and none of the small deltas.

**Sun's numbers, which is what the kill gate's first branch asked for.** `frameMs`
p50, with the committed `frameMs` p50 ceiling for the same scenario:

| Scenario | `skia` | `sun` | sun/skia | `sun` / budget p50 |
|---|---|---|---|---|
| showcase-runtime-scroll | 2.480 | 561.477 | 226× | **22.5** |
| excel-grid-navigation | 11.602 | 2191.800 | 189× | **60.9** |
| virtual-list-100k | 0.363 | 84.514 | 233× | **3.5** |
| multi-window-4 | 0.563 | 8.669 | 15.4× | 0.12 |
| deep-tree-env-toggle | 4.539 | 655.446 | 144× | **20.5** |

Four of five scenarios blow the committed ceiling, and the fifth passes only
because that ceiling (72 ms) is ~30× looser than what the shipped route actually
measures — the same "budgets are crash detectors, not evidence" finding from L0.4.
`sun`'s `presentMs` is 96–99.7% of its `frameMs`, so the gap is the rasterizer. Its
framework stages are also slower in absolute terms (deep-tree `buildMs`
1.620→1.951, +20%), but that is ≤1.5% of a 655 ms frame and it drifts the same
one-directional way the runner's own repeat drifts (see the self-drift table above), so it is not renderer work.
`peakRss` goes the other way as a cross-check: sun uses 270–315 MB
against Skia's 82–105 MB while holding *fewer* live allocation blocks (957 vs
~10.4k), i.e. a small number of large CPU buffers rather than Skia's object graph.
`startupMs` moves the same way — 16.6 / 27.1 / 1.35 / 0.42 / 8.1 s for sun against
0.114 / 0.657 / 0.008 / 0.008 / 0.054 s for Skia — but it is **not** independent
evidence: the timer spans app construction, pump construction and the same 12
warmup frames (`benchmarks/performance_budget/native/main.mbt:725-737`), so it is a
re-statement of the frame ratio plus a renderer-neutral constant, not a second
measurement of it.

So the first branch is **evaluated and does not fire**: on this repo's five real
app scenarios, the available boundary-compliant CPU provider is 15–233× the
shipped renderer's frame cost, not faster.

Three limits that keep this from being read as more than it is:

- **This prices sun, not "a non-Skia renderer".** Sun is today's MoonBit software
  rasterizer, with its own atlas and caching maturity. A purpose-written Metal
  backend would not inherit sun's raster loop. What the measurement does kill is
  the specific shortcut of "adopt the existing CPU provider and frames get
  cheaper", which is what the gate's first branch was offering as the cheap win.
- **The neutral contract cannot certify completeness.** `RendererSession` exposes
  `present_count`, `image_diagnostics`, and GPU-recovery counters
  (`moui/render/renderer_session.mbt:212-251`) but no unsupported-command counter,
  so the pump can prove every frame *reached* the presenter, not that every
  `DrawCommand` was drawn. Both renderers keep that counter privately
  (`moui_skia_renderer/renderer.mbt:678`, `moui_sun_renderer/renderer.mbt:222`) and
  the concrete Skia pump asserts on it; the neutral pump cannot. The direction of
  the error is known though: a silently-skipped command *removes* work, so an
  incomplete sun would be understating its own cost, which makes the 15–233× a
  floor rather than a flattering number.
- **`packageBytes` in these artifacts is 23,262,232 for all three runners**,
  including sun — because the benchmark package links `moui_skia_renderer` and the
  concrete pump, so the *same* binary carries both renderers. Do not read the sun
  artifact as a sun-only app size; the 4.06 MB `macos_sun` figure comes from a
  sun-only app build, and this runner cannot produce one.
- **`wgpu` has no number and cannot get one on this harness.** Its bind closure
  returns `Rejected("wgpu requires a native surface capability")` without a
  `HostSurface.native_surface()` (`moui_wgpu_renderer/binding_factory.mbt:25-27`),
  which a headless surface never has. A wgpu frame number needs a real window.

## The language floor, measured (this is what settles the size motive)

`moon run --release --target native` on a one-line hello-world probe
(`println`) links a **266,600 B** Mach-O (`__text` 151,508, `__const` 20,769)
with only `/usr/lib/libSystem.B.dylib`. So MoonBit's native floor is already
inside nanoui's 0.4–0.7 MB band, and `macos_sun` at 4,260,688 B — which links **no
graphics library of any kind** — means roughly **4.0 MB of that is MoUI's own
always-linked framework plus used stdlib modules**.

**Corrected by the L4 measurement (2026-10-28).** This section previously
reasoned that "a no-third-party GPU renderer adds a rasterizer to that body; it
cannot subtract from it", so size below the floor was ruled out and the prize was
framed as "a GPU route lands in the 4.06–11.05 MB band against Skia's 20.35 MB".
Both halves are now measured false: `macos_metal` is 4,101,856 B — *below* the
`macos_sun` figure quoted above, by 158,832 B — and the reason is visible in the
sections. Metal's `__text` is 171,436 B **smaller** than Sun's, because the code
a GPU route adds is command encoding, while the code it stops needing is a
software rasterizer; `__const` moved by +736 B. So the floor is not
"CPU-raster-shaped": the always-linked MoUI body dominates either rasterizer, and
swapping one for the other can go either way. What still stands here is the
comparison that motivated the route — a GPU, at a fifth of Skia's artifact — and
the last sentence: per-scenario `packageBytes` budget baselines (70–105 MB) are
placeholders that no measurement has yet replaced, so even that prize is
currently unenforced. Under the boundary, `macos_metal` is also now the only
GPU-capable compliant option (`sun` has no GPU, `wgpu` links an excluded library).

## Stages, each with its own kill gate

**L0 — instrument and de-risk (no drawing code).**
- L0.1 Renderer-parametric benchmark harness: accept a `RendererProvider`
  (`moui/render/provider_contract.mbt:23`, 4 fields) instead of a concrete Skia
  renderer, run the five existing scenarios, emit under the current runner
  identity rules
  (`benchmarks/performance_budget/native/main.mbt` and
  `benchmarks/app_cached_layer/native/main.mbt:143-151` were both typed to
  `@skia_renderer.SkiaRasterRenderer`, so no non-Skia route had ever produced a
  frame number). This is the prerequisite for every route decision, including
  this one's own stop condition.
  **Done for the headless providers (2026-10-27)**, and the `sun` branch of the
  kill gate is now evaluated (see "L0.1 measured" below). The perf harness drives
  a `PerfFramePump` (`main.mbt:167`) chosen by `MOUI_PERFORMANCE_PROVIDER`:
  `skia` keeps the concrete renderer (so the four committed runner labels and the
  gated budgets are untouched), `skia-neutral` binds `@skia_renderer.raster()`
  through the neutral contract, and `sun` binds `@render_sun.raster()`.
  Two residuals, both verified rather than assumed:
  **`wgpu` has no number and cannot get one here** — its bind closure returns
  `Rejected("wgpu requires a native surface capability")` unless the
  `HostSurface` carries `native_surface()` (`moui_wgpu_renderer/binding_factory.mbt:25-27`),
  which a headless surface never does, so a wgpu frame number needs a real window
  and is a different instrument. And `benchmarks/app_cached_layer/native/main.mbt`
  stays concrete on purpose: its numbers do not feed a route decision, so
  duplicating the pump there is a permanent cost with no evidence gain.
- L0.2 Extract the neutral native text model out of the wgpu-importing package,
  so `coretext` and `text_protocol` stop importing `wzzc-dev/moui_wgpu_renderer`.
  **Done (2026-10-27)** as `moui/render/native_text` (imports `wzzc-dev/moui/core`
  only). `moui_wgpu_renderer` re-exports the moved names with `pub using`, so its
  published surface is identical in *name* and neither `examples/showcase/*_wgpu`
  nor the `momark` submodule needed an edit; its mbti surface shrank from
  154 lines / 77 public declarations / 3 `pub(all)` groups to 116 / 55 / 2, and
  the new package is registered at 94 / 46 / 1. Two intentional behavior changes
  came with the move: the dispatch API is cache-centric (`cache.measure` /
  `cache.layout_run` / `cache.raster_glyph`) instead of passing a cache into an
  engine call, and fallback-derived layouts are now memoized under the same key as
  primary results — provider output is deterministic per key, so the cached value
  is the same either way.
  Residual in the bullet above: the provider packages themselves stay inside the
  `moui_wgpu_renderer` module.
- L0.3 License / IP fact sheet. `THIRD_PARTY.md` records that MoUI does **not**
  vendor Skia or `wgpu-native` and that supplied artifacts "remain governed by
  Skia's upstream license terms" (:15-30) — it names no license, no obligations,
  no compatibility conclusion. Before "license / IP chain" is cited as a reason
  for anything, fill in the SPDX for each engine this repo actually links on
  each platform. If the conclusion is "permissive and non-blocking", the license
  motive is dropped from the record rather than left implicit.
  **Done (2026-10-27)**, in `THIRD_PARTY.md`. The macOS link line is eight
  archives (`moui_skia/build.js` darwin static + paragraph), the delivered
  artifact carries license text for one of them (HarfBuzz), and the seven texts
  it does carry are BSD-family / MIT-family / Zlib / libpng / FTL — so the
  exposure is notice completeness, not IP blocking. Per this bullet's own rule
  the license motive is **struck from the record**, not left implicit. Two
  collateral findings: `-lfreetype` is Linux-only, so its FTL-vs-GPLv2 choice is
  not a macOS obligation; and the smoke script's default provider
  (`jetbrains`/`m148-8967a2e80c`) is not the locked product provider
  (`wzzc-dev/skia`/`dev-6d73578a36`), although both packages were verified to
  ship identical archive-name and license-text sets, so the notice conclusion
  does not depend on which one a given run used.
- L0.4 Control measurement before invention: run the same scenarios through the
  GPU route the product already ships (`from_env(NativeGpuPlatform::MacOS)`,
  `MetalGpuSurfaceRoute`) with a real presenter instead of the no-op closure, and
  fix the all-zero `buildMs` / `layoutMs` probes so the framework slice is
  separable from the raster slice. This is the only step that can tell whether the
  remaining gap to an immediate-mode competitor is renderer cost or retained-tree
  cost.
  **Done (2026-10-27)**, results in "L0.4 measured" above: the shipped route's
  renderer-attributable slice is ≤0.76 ms p50 and the >4 ms scenarios are 92–95%
  framework. `buildMs`/`layoutMs` were already honest (they are only timed when
  dirty); the missing instrument was `drawMs`/`totalMs`, now emitted and gated.
- **Kill gate**: if L0.1 + L0.4 show `sun` meeting the `frameMs` budgets on a real
  app, **or** show that the already-shipped Skia-Metal route consumes the
  renderer-attributable slice (so a hand-written backend would only re-acquire the
  same savings at the cost of owning a rasterizer), the route stops at L0 and
  continues only on size + autonomy, explicitly re-priced.
  **Fired on the second branch (2026-10-27).** L0.4 shows the shipped Metal route
  already holds the present cost at 0.10–0.76 ms p50 while the scenarios that
  dominate the frame are framework-bound, so a hand-written backend has no
  performance prize left to acquire — only the permanent cost of owning a
  rasterizer. Note that the gate's phrasing ("show that the route *meets the
  budgets*") could not have fired either way: no route on any scenario reaches
  even 0.80 of any committed timing budget, so the budgets are ceilings, not
  evidence. The attribution split decided it. First branch (a `sun` / non-Skia
  provider meeting `frameMs` on a real app) is **evaluated and does not fire
  (2026-10-27, with L0.1)**: `native-sun-raster` comes in at 15–233× the shipped
  renderer's `frameMs` p50 and breaks 4 of 5 committed ceilings by 3.5–61×, so
  adopting the existing CPU provider is not the cheap win this branch was
  offering. See "L0.1 measured" for what that does and does not price. Per this
  gate, the route does not proceed to L1 on performance grounds, and continuing
  requires the size + autonomy motive to be re-priced.
  Re-priced against the measurements, that means: **size below the floor was
  predicted to be out** (the 266,600 B language floor and `macos_sun`'s 4.06 MB
  were read as putting the remaining framework body outside any backend choice),
  and **that prediction did not survive L4** — the built route is 3.91 MB, under
  both the floor's stated source and Skia's 20.35 MB by a factor of five (see
  **Measured baseline**). **Size versus Skia and autonomy are the live motives**;
  neither of them is served by any route that satisfied the boundary before this
  one existed, which is exactly the gap ADR 0044 opened this route for.

**L0.5 — move the text providers out of the wgpu module (the P14 prerequisite,
owner-directed 2026-10-27).** L0.2 made the five provider packages depend on nothing
renderer-shaped, but at decision time they still lived *inside* the
`moui_wgpu_renderer` module, and P14
(`docs/invariants.md:30`, enforced by
`tools/moui/validate_release_module_closures/main.mbt:169-172`) forbids a module with
`role: "renderer"` from depending on another renderer module — so
`moui_metal_renderer` cannot import `wzzc-dev/moui_wgpu_renderer/coretext` however
clean that package's own imports are. Decision: a new module
**`wzzc-dev/moui_text_providers`** (directory `moui_text_providers`) holding the five
packages, registered `publication: "public"`, `role: "binding"`,
`releaseStage: "base-bindings"`, `version = "0.2.2"` — the topology `moui_skia` and
`moui_sun` already use for native bindings that live outside a `moui_*_renderer`. An
alternative that gives the new module `role: "renderer"` is not merely worse: it makes
`moui_wgpu_renderer` itself the P14 violator.

- **Wording tension recorded rather than quietly resolved.** P6's clause "native
  bindings live in `moui_*_renderer` modules" (`docs/invariants.md:20`) has no
  detector and is already contradicted in practice by `moui_skia` (292 hand-written
  externs) and `moui_sun`. This plan reads P6 as scoping *renderer-specific* bindings;
  that reading belongs in an ADR note, and the invariant table is not edited
  unilaterally here.
- **Registration blast radius, checked against the gates before moving.** `moon.work`
  member; `checks/release-modules.json` row;
  `tools/moui/validate_maintenance_baseline/scan_scope.mbt` `monitored_roots`; the
  `text_protocol` PackageBudget re-key at
  `tools/moui/validate_api_surface/main.mbt:606-607`; a new
  `moui_text_providers/build.js` that owns the DirectWrite/Fontconfig `link_configs`
  and `MOUI_LINUX_FONTCONFIG_STUB_CC_FLAGS`, with the `--moonbit-unstable-prebuild`
  option travelling with it; `scripts/test-moui-prebuild.mjs:196-207`, whose
  assertions are about *ownership* ("WGPU prebuild must own the DirectWrite link
  config") and must be re-labelled rather than merely re-pathed; consumer `moon.pkg`
  imports in `examples/showcase/*_wgpu` and
  `moui_tests/{wgpu_renderer_smoke,text_conformance}` plus their `moon.mod` pins; and
  prose in `docs/architecture.md` / `docs/architecture-map.md`. No moved file exceeds
  1800 lines, so no `checks/source-file-policy.json` budget is needed, and no
  `checks/compatibility-policy.json` tier row is needed (`moui_skia` / `moui_sun`
  carry none).
- **Deliberate non-choice: no compatibility shims.** `examples/momark` and
  `moui_studio` are git submodules that resolve `wzzc-dev/moui_wgpu_renderer@0.2.2`
  from the registry, so they keep building against the published artifact that still
  contains the providers; re-export stubs at the old paths would be in-tree clutter
  paying for a dependency that does not exist locally. Their import update is a
  follow-up at the next pin bump, recorded in Follow-Up instead of pre-empted here.
- **Kill gate.** Done means: `moon check` green workspace-wide,
  `moui_tests/text_conformance/native` still exercises the providers through the new
  paths (it is the only profile-gated consumer; `wgpu_renderer_smoke/*` is in no
  profile and the four provider packages stay outside `pr` as native-only host-stub
  tests — the move must not *reduce* that), every static validator green, and
  `--profile pr` green. P14's escape hatch is an RFC, and the correct answer here is
  to move the packages, not to file the RFC.
- **Delivered 2026-10-27.** `git mv` of the five packages into
  `moui_text_providers/`, plus `moui_wgpu_renderer/build.js` →
  `moui_text_providers/build.js` (byte-identical apart from the two `link_configs`
  package tokens), with the `--moonbit-unstable-prebuild` option and the
  `Milky2018/moon_cosmic` / `moon_swash` pins travelling with it. Measured:
  `moon test` per package 23 `cosmic_text` / 20 `coretext` / 14 `text_protocol` /
  6 `fontconfig` / 8 `directwrite`, `moui_wgpu_renderer` 61,
  `moui/render/native_text` 8, `moui_tests/text_conformance/native` 10 — all
  passing; `moon build examples/showcase/macos_wgpu --target native` links
  (111 tasks). The `text_protocol` PackageBudget needed only the path +
  `package_token` re-key: `pkg.generated.mbti` is still 58/23 against its 60/23
  ceiling, so no budget was raised by this move. Final gate state after every
  registration below: `sh scripts/check.sh --profile pr` green (199 steps,
  "MoUI pr checks passed."), the six pre-push static validators green, and
  `scripts/test-moui-prebuild.mjs` green for the text-provider assertions.
- **Gate-surface registrations the pre-move survey missed.** Each of these is a
  list that names modules explicitly, so dropping `moui_text_providers` from it
  shrinks coverage without any failure: `checks/source-file-policy.json` `roots`
  (without it the moved files leave the file-size gate altogether —
  `cosmic_text.mbt` at 1,148 lines is the largest); `monitored_roots("full")` in
  `tools/moui/validate_maintenance_baseline/scan_scope.mbt`;
  `tools/moui/validate_runtime_state_render_ownership/validation.mbt` global scan
  roots; `tools/moui/validate_renderer_provider_manifests/main.mbt` per-platform
  backend forbidden list (it previously caught provider imports only as a
  `wzzc-dev/moui_wgpu_renderer` substring);
  `checks/backend-common-ownership.json` `sourceRoots`;
  `scripts/external-consumer-ci.mjs` `base` / `skia` / `web` forbidden closures
  (the transitive cover the move removed); and a
  `docs/architecture-map.md` ownership row naming the module, because it is now
  what any renderer reaches for text. The prebuild test also gained an assertion
  the plan did not call for: `existsSync("moui_wgpu_renderer/build.js")` must be
  false, so a renderer module re-acquiring text `link_configs` fails the gate
  whose whole purpose is to keep them out of renderers.
- **Three registrations deliberately not added, with the check that ruled them
  out.** `checks/backend-common-ownership.json` `rendererModules` stays without
  it — the providers are not a renderer, and listing them there would make the
  boundary validator demand renderer treatment of them. The same file's
  `packageRules` `forbiddenImports` for `moui/render` and `moui/render/common`
  gains nothing either: `has_default_import`
  (`tools/moui/validate_backend_common_boundary/validation.mbt:192-194`) builds
  the probe as a fully quoted token, so `"wzzc-dev/moui_wgpu_renderer"` never
  matched `"wzzc-dev/moui_text_providers/coretext"`-style subpackage imports
  before the move, and `moui_text_providers/` has no root `moon.pkg` for a bare
  module token to match — the entry would be dead config. The live detector for
  "a provider leaks into the published base module" is
  `validate-release-module-closures`, which hard-fails `validate_base_closure` on
  the `Milky2018/moon_cosmic` / `moon_swash` pins. `checks/compatibility-policy.json`
  `apiTiers` gains no row: the key has no reader anywhere in the repo (only its
  own definition and the 2026-10-25 session note match `apiTiers`), and the
  sibling binding modules `moui_skia` / `moui_sun` carry no tier row either.
- **A pre-existing red surfaced by running the gate, not caused by this move.**
  `scripts/test-moui-prebuild.mjs`'s assertion "Skia binding prebuild must leave
  link ownership to moon.pkg" has been failing since `af9bafa6c` (2026-08-12),
  which restored a `wzzc-dev/moui_skia/native` `link_configs` entry that the
  earlier `3df372319` had forbidden. It is a `daily`/`full` step, not a `pr` step
  (77 steps, 0 prebuild hits), which is why `pr` never caught it. Evidence it is
  independent of L0.5: with HEAD's own `moui_skia/build.js` the hook emits
  `link_configs.length == 1` under exactly the env the test passes, and excising
  only that block makes the re-labelled script print
  `split module prebuild tests: ok`. Which side should win is an owner call — the
  emission is deliberate and commented ("`link_configs` is the carrier that
  reaches is-main links") — so this plan records it instead of unilaterally
  changing an unrelated gate's expectation.

**L1 — proof of a compliant frame.** One clear color, one filled path, one
CoreText glyph run, presented through the existing host `CAMetalLayer` handle.
Acceptance is not "it looks right": `otool -L` / `nm` / `strings` on the release
artifact must show no Skia and no wgpu symbols or link entries, and the extern
count must land inside the 10–40 budget. A route that only reaches a frame by
re-linking an excluded library has failed the constraint that opened it.

**Delivered 2026-10-27 (L1a–L1c).** `wzzc-dev/moui_metal_renderer` exists and
draws that frame. Measured against the acceptance text above:

- **Symbol-gate caveat, learned the expensive way.** The `nm` pattern must not
  contain `Gr[A-Z][a-z]`: it matches Apple's own `CGRectIsNull`,
  `CTFontGetBoundingRectsForGlyphs` and friends, and reported 2,612 "Skia"
  symbols on a clean artifact. The precise set is `skia`, `wgpu`,
  `GrDirectContext|SkSurface|SkCanvas|GrBackend` — all 0 — plus
  `strings -a` for `libskia|skparagraph|skshaper|wgpu_core|ganesh`, also 0.
- **Zero Skia, zero wgpu**: `otool -L`, `nm -a` and `strings -a` on
  `examples/showcase/macos_metal` each report 0 matches, and the artifact's only
  frameworks are `Metal` and `QuartzCore` from `/System/Library/Frameworks`.
- **Externs: 7, not 10–40** (`context_create`, `context_prepare`,
  `texture_write`, `image_upload`, `draw_frame`, `draw_proof`,
  `context_release`; **8 since L2b**, where `image_upload` split into
  `image_decode` + `image_write_rgba`). The estimate's
  floor was wrong in the optimistic direction: presentation needs the layer
  handle the backend already hands over, and geometry came from
  `moui/render/common` (`lower_draw_commands`, `tessellate_path`), so there was
  never a C surface to grow.
- **Public API 34 lines / 9 declarations** (`metal`, its descriptor and
  capability self-report, the offscreen pixel proof, the real-provider text
  smoke, and four `pub using` lines). The renderer, geometry, glyph atlas and
  frame types are package-private.
- **Evidence**: 16 module tests including offscreen pixel assertions for the
  clear colour, a filled rect, a solid tessellated path and a scissored clip;
  `moui_tests/metal_renderer_smoke/macos` renders one real CoreText glyph run and
  asserts read-back ink ratio 0.245 with a noop-engine control at exactly 0 ink;
  a real window shows the showcase text correctly oriented. Both gates are
  `platform`-profile steps with `host: "darwin"`.
- **What it refuses**: rounded-rect fills, strokes, shadows, images, gradients,
  layer/filter scopes and retained layers are counted as dropped work (97 dropped
  ops in the showcase's first frame), never approximated into pixels; `recover`
  returns `RecoveryFailed` because there is no recovery path before L4; the atlas
  has no eviction and counts a glyph it cannot fit (the first clause of this list
  to be overtaken — see L2/L2c and L3a below); the engine's fallback layout
  is never consulted; colour glyphs are composited as straight alpha with no
  colour-font evidence. The capability self-report says all of this per feature
  and `validate-renderer-capability-consistency` now checks it as a fifth column
  (85 cells).
- **The size motive is still unpriced.** The 8.9 MB figure is a *debug* build and
  the 20.35 MB Skia figure is a release artifact, so they are not comparable;
  `packageBytes` baselines in this repo are placeholder values. No release-size
  claim is made here.
- **Two things the plan's premises got wrong.** (1) The protocol identity cannot
  be called `Metal`: `moui/render`'s published surface is guarded against naming
  platform surfaces (`rootRenderForbiddenTokens` lists `Metal`, `HWND`, `Vulkan`,
  `EGL`, `D3D`, and `validate-api-surface.mjs` rejects the token in
  `moui/render/pkg.generated.mbti`). The guard fired on the first attempt and the
  guard won — the cases are `NativeDirectGpu` / `DirectGpu`, the module keeps the
  literal name, and prose keeps saying "no Skia, no wgpu" because
  `docs/platform-notes-macos.md` already calls the shipped Skia-on-Metal path
  "the direct Metal GPU provider". (2) A package's `cc-link-flags` never reach an
  is-main link (measured by injecting an invalid flag into
  `moui_text_providers/coretext` and watching `macos_wgpu` build anyway), so the
  frameworks travel in `moui_metal_renderer/build.js` `link_configs` — and the
  same gap was latent in CoreText itself, where the symbols resolved only because
  a platform backend also links the `ApplicationServices` umbrella. That is now
  fixed in `moui_text_providers/build.js` and pinned by
  `scripts/test-moui-prebuild.mjs`.
- **One test-quality lesson worth keeping.** The first glyph test used a fully
  covered mask, and it passed while real CoreText text painted solid white bars:
  a full mask cannot distinguish "coverage scaled into the premultiplied colour"
  from "coverage landed only in alpha". The mask is now half covered, which fails
  the wrong shader for the right reason.

**L2 — `DrawCommand` honesty.** All 26 variants
(`moui/core/paint.mbt:418`) are either implemented or raise
unsupported-command diagnostics. Silent mis-draw is a rejection of this route,
not a TODO.

**L2 progress (2026-10-27; the `metal_frame_report` surface below is
2026-10-28).** 19 of the 26 variants are handled — the 11 paint
ops this stage draws (rects, rounded rects, strokes, brush fills, shadows, paths,
text, images) plus the 8 clip/transform/opacity scope ops — and the remaining 7
are counted: `PushLayer`, `PopLayer`, `BeginRetainedLayer`, `EndRetainedLayer`,
`PushFilter`, `PopFilter`, `DrawShaderEffect`. Implemented with pixel proofs in
`moui_metal_renderer/metal_l2_wbtest.mbt`: `FillRect`, `StrokeRect`,
`FillRoundedRect`, `StrokeRoundedRect`, `FillRoundedRectBrush`,
`StrokeRoundedRectBrush`, `DrawShadow` and `DrawPath` (fill and stroke, solid and
gradient), on top of L1's `Clear`, `DrawText` and the clip/transform/opacity
scopes. The shape pipeline is
two Metal pipelines over one 76-byte vertex (clip position, shape-local point,
atlas uv, gradient endpoints, two brush colours, brush kind) with an 8-float
per-item box parameter, and the SDF / stroke-subtraction / shadow-spread /
gradient-interpolation math is the same formulation
`moui_wgpu_renderer/native_visual_shader.mbt` already pins with pixel tests, so
the two diagnostic renderers agree on what each mode means.

Three things this progress note has to keep honest:

- Colours ride **per vertex**, not per item, because the shared
  `tessellate_path` mesh mixes a fill sub-mesh and a stroke sub-mesh in one
  vertex array with different brushes; a per-item colour would repaint the
  stroke with the fill. That is also why gradient paths stopped being dropped.
- The shadow falloff is a smoothstep band of width ≈ `blur` just inside the
  grown box, not a Gaussian convolution; the first version of the test sampled
  the saturated plateau and failed for the wrong reason, so the sample points
  and the band are now both named in the test.
- "Raise unsupported-command diagnostics" cannot mean an event: `RendererEvent`
  carries only `PresentCompleted` / `ImageLoadRequested` and both host backends
  ignore anything else, so a new variant would be a channel with no reader. The
  route instead exposes `metal_frame_report` — CPU-only, so it answers on any
  host — and the macOS smoke prints it (`items=1 vertices=54 refused=0` for the
  nine-glyph run). Each push and pop counts separately, which the report test
  pins at 3 dropped ops for image + filter scope.

**L2b — images, both lifecycles (2026-10-28).** `DrawImage` now draws on the
host's asynchronous image path, which is the only path a real app uses: the
provider sets `async_image_loading=true`, so a source is requested, resolved off
frame, and painted once its completion lands. The session wires the four
image-side contract slots — `image_source`, `image_decoder`, `image_records`,
`apply_image_load_completion` — over the shared
`@render_common.ImageResourceLifecycle`, so the host's dedup / retry / snapshot
semantics are the same ones Skia and WGPU get. Decoding is Apple's ImageIO
(`CGImageSource`) into `kCGImageAlphaPremultipliedLast |
kCGBitmapByteOrder32Big`, keeping the route's "no external graphics library"
property: the module still links only `Metal`, `QuartzCore`, `CoreGraphics`,
`ImageIO` and the Foundation pair. Two facts cost real debugging time and belong
in the record:

- A completion carries **decoded RGBA**, not encoded bytes. The first version
  routed completions back through the decode stub, so the install probe returned
  `0` and every async image silently failed. The stub split is now
  `image_write_rgba` (upload only) versus `image_decode` + `image_write_rgba`
  (the proof path, which does start from encoded bytes).
- `ImageResourceLoadCompletion::has_decoded_rgba_payload()` requires
  `decoded_row_bytes >= width * 4` and `pixels.length() >= row_bytes * height`.
  Passing `width * height * 4` as `row_bytes` fails that predicate, and the
  failure looks like a texture problem, not a contract problem.

`Image` therefore moved `Partial → Supported` in the capability self-report, and
the pixel proof pins both halves of the fixture PNG (`red` left, `blue` right)
appearing only on the *second* frame — frame 1 asserts `items=0` with
`image_ops_pending=1`, so the async request cannot be satisfied by a synchronous
decode sneaking into the frame. The FFI surface is **8** externs (the L1 note's
`image_upload` was replaced by `image_decode` + `image_write_rgba`); 31 module
tests pass.

**Gate note.** `pr` and the two darwin `platform` Metal steps are green; `daily`
is **not**, on one pre-existing failure that this route does not own:
`check.sh` injects `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` into every step, so
`moui_skia_renderer`'s real-Skia variable-font assertion runs against fallback
stubs and fails at HEAD too (A/B proven; `-Wl,-dead_strip` exonerated). Two other
`daily` reds of the same "generated file vs generator" class were fixed on the way
through. Details and the owner decision still open:
`docs/ai-sessions/2026-10-27-direct-host-gpu-renderer-l1.md`.

**L2c — scopes, and the first mis-draw this route ever found (2026-10-28).**
`PushLayer`/`PopLayer`, `PushFilter`/`PopFilter`, `BeginRetainedLayer`/
`EndRetainedLayer` and `DrawShaderEffect` all draw now, which takes the command
stream to its full 26 variants.

- **The pass architecture is one flat item stream plus owner tags.** Each item
  carries a 9th int32 `owner` (`-1` main pass, `-2` discarded, `>=0` a layer
  slot). Slots are claimed *eagerly in post-order*, so a parent always owns a
  higher slot than its children and the host can render `slot = count-1 … 0`
  then the main pass — one encoder at a time, which is Metal's rule, without
  recursion in the host. A layer record is 11 words (device frame, child item
  range, blend code, then the four floats of the surface→target NDC transform)
  bound per draw as `constant float4& [[buffer(1)]]`; the transform, the
  scissors and the composite uv all derive from the *same* device rect, which is
  why content texels and destination texels coincide. Pipelines are keyed
  `role-format[-blend]` and built lazily; the earlier single-format assumption
  was a latent bug and is gone.
- **Exactness is counted, never implied.** Five of six blend modes reach
  fixed-function state (`MTLBlendOperationMin`/`Max` for darken/lighten); Overlay
  needs a conditional and lands in `blend_modes_unsupported`. Those five are
  exact only over an opaque destination and this stage has no backdrop read, so
  every non-source-over composite is counted in `blend_modes_approximated`. Blur
  is a 3×3 weighted tap (`filter_approximations`). The backdrop-blit design that
  would make all six exact was evaluated and rejected for this stage: a per-pass
  backdrop texture, encoder splitting and `framebufferOnly = NO`.
- **Retained layers repainted; shader effects use their own fallback.** There was
  no cross-frame cache keyed by `key`/`content_revision`, so `BeginRetainedLayer`
  rebuilt into a fresh pass each frame and `retained_layers_rebuilt` said so.
  (Superseded later the same day: a boundary is now kept across frames on the
  target the host already pools for its slot — `moui_metal_renderer/metal_retained.mbt`,
  and the `LayerCompositing` row in Progress.)
  `DrawShaderEffect` paints the spec's declared `fallback` brush into its `frame`
  and `shader_effects_fallback_painted` marks the frames where the real effect
  would have looked different. (Superseded the same day by L4: the four
  `builtin_shader_names()` names are now drawn per fragment and only an
  app-defined name falls back — see the `ShaderEffect` row in Progress.)
- **A gradient on a rect that does not start at the origin was mis-painted since
  L1b.** A box fragment measures its SDF from the rect origin, while a path mesh
  carries absolute positions, so pushing the brush endpoints in surface
  coordinates shifted every offset box gradient by the rect origin — measured on
  the GPU: an axis declared 2→10 interpolated 4→12. Nothing noticed for two
  stages because each earlier gradient test anchored at `(0,0)`, where the two
  spaces agree. The fix shifts box endpoints into box space and deliberately
  *not* a radial `end.x`, which is a length; the pin is
  `a radial gradient on an offset rect keeps its centre and its radius`. The
  general lesson is for this route's test style, not just this bug: a proof that
  only holds at the origin proves the arithmetic, not the coordinate space.
- **The walk is now exhaustive, so `dropped_ops` left the public report.** With
  all 26 variants matched the catch-all was unreachable — the compiler said so —
  and a counter that can never move is decoration. A new `PlanOp` variant is a
  compile error here, exactly the guarantee
  `moui_wgpu_renderer/native_visual_plan.mbt` already relies on. The API-surface
  budget for this module went 48→53 lines, all of it fields of
  `MetalFrameReport`.
- Capability rows moved `gap → partial` for `LayerCompositing`, `BlendMode`,
  `FilterEffect`, `ShaderEffect` and `AsyncImage` (the last one had been claiming
  `gap` while the `Image` note described its wired lifecycle), each naming the
  half that is missing; the matrix in `docs/renderer-capability-report.md` and its
  Chinese mirror match the code (85 cells). 43 module tests pass, extern count is
  still **8**.
- **The size gate caught this route's own growth, and splitting was the answer.**
  `pr`'s `validate_source_file_policy` step flagged two files past the 1200-line
  new-file hard limit: `metal_geometry.mbt` (1674) and `metal_renderer.mm`
  (1291). Both are new this week, so a ratchet would have been the gate's named
  failure mode — permanent headroom bought for code that had just outgrown itself.
  The geometry file split along the seams that were already visible: the op walk
  stays in `metal_geometry.mbt` (789 lines), the frame's byte layout and MSL code
  values moved to `metal_geometry_wire.mbt` (622), the clip/filter/layer scope and
  pass-slot machinery to `metal_geometry_scopes.mbt` (275). The bridge split
  smaller and along a different kind of seam: the 182-line embedded Metal Shading
  Language string moved to `metal_shaders.h`, because shader source compiled at
  runtime by `newLibraryWithSource` is data the host reads, not host logic — and
  it is the only thing a fragment change edits. `metal_renderer.mm` is now 1096
  lines, in the repo's 1000+ *review* queue with 40 other files rather than a
  failure. No public API, no extern, and no test assertion changed; 43 tests and
  the darwin smoke pass before and after.

**L3a — glyph atlas residency (2026-10-28).** The first L3 leg, and the one that
was a correctness cliff rather than a fidelity gap: the 512×512 coverage atlas
had no way to empty. A frame whose text needed more room than the atlas still had
dropped the glyph, counted it in `text_dropped_glyphs`, and — because placements
are never reclaimed — kept dropping every new glyph for the rest of the session.
For a scrolling document that is "text disappears and never comes back", not a
degradation a counter describes.

- The recovery is the sibling route's policy, copied rather than invented:
  `moui_wgpu_renderer/native_visual_plan.mbt:342` clears its atlas and rebuilds
  the plan when a glyph reports full, and `native_text_rendering.mbt:147` turns
  the report into that retry signal. Metal does the same in
  `build_metal_geometry`: the walk sets `atlas_overflowed` on `Full` (which is
  now a distinct branch from `Missing`, the two having different remedies), the
  frame is cleared and built a second time, and the retry is bounded at one — a
  single frame whose own glyph set cannot fit an *empty* atlas would fail the
  same way twice, and the surviving `text_dropped_glyphs` is the honest signal
  there.
- Non-vacuity was proven by A/B, not asserted: with the retry disabled the new
  test fails at `assert_eq(second.item_count, 1)` with `0 != 1`, i.e. the glyph
  really was being dropped. The test fills the atlas with four 200×200 rasters
  (exactly two shelves of two), then asks for a fifth glyph in its own frame and
  asserts it paints, that `resets == 1`, and that the atlas afterwards holds
  **one** placement — the current frame's working set, not four glyphs the next
  frame will never draw.
- `atlas.resets` stayed package-private. A successful retry draws the right
  pixels, so there is nothing for a host to be told; what a host should see is
  the drop count, which already exists. The thrash case (a working set larger
  than the atlas, re-uploading 1 MB per frame) is a *cost* signal, and the route
  has no perf gate that could act on it yet — L4 is where the report grows, and
  it needs a named failure mode there rather than a field for its own sake.

**L3b — colour glyphs, measured before claimed (2026-10-28).** The `EmojiText` row
asserted that a colour raster's own pixels survive the atlas branch that skips
tinting. Nothing pinned that, and the first real emoji run through the route
refuted it: 698 inked pixels, none of them anything but the run colour.

- Two renderer-local pixel tests now pin the branch, and they are a pair on
  purpose: one identical 6×8 glyph box drawn once as `ColorRgba` green under a
  pure-red run (`a colour glyph paints its own pixels, not the run colour`) and
  once as `AlphaMask` under the same red run (`the same footprint as a coverage
  mask takes the run colour`). The raster format is the only difference between
  them, so a walk that ignored format could not satisfy both.
- The half that was refuted lived in the shared provider, not this module.
  `moui_text_providers/coretext/macos_coretext_text.m` chose the colour payload by
  comparing the PostScript name with `"AppleColorEmoji"`, while the system cascade
  resolves an emoji on macOS 26.3 to **`.AppleColorEmojiUI`** — so every glyph came
  back as a 37×42 DeviceGray coverage mask. A throwaway CoreText probe settled the
  rest: that face carries `kCTFontColorGlyphsTrait` and draws 472 of 539 chromatic
  pixels into an RGBA bitmap context, so colour was reachable through the path the
  provider already used and only the key was wrong. The fix is the documented
  check — `CTFontGetSymbolicTraits(font) & kCTFontColorGlyphsTrait` — which also
  keeps ordinary text a coverage mask (`coretext_text_wbtest.mbt`: `coretext keeps
  ordinary text as a coverage mask`), and no longer depends on one font's name.
- After it, `moui_tests/metal_renderer_smoke/macos` reports 🙂 at 698 inked / 686
  green-channel / 698 red-channel-from-green-run and the ZWJ sequence 👩‍💻 at
  1011 / 993 / 1011, with a noop engine lighting none of it. Each sample is drawn
  under two run colours and each claim names a channel the other colour zeroes, so
  neither half can be met by a solid bar or by a tint that leaked.
- The change pays outside this route too, and it pays as an upgrade:
  `moui_wgpu_renderer` shares the provider, already branches on `ColorRgba`
  (`native_text_glyph_atlas.mbt:118`, `native_text_rendering.mbt:199`), and its
  `EmojiText` row claims `supported` — which the old name keying cannot have been
  delivering on macOS. This leg did not re-evidence that row; its 61 tests and
  `moui_tests/text_conformance/native`'s 10 pass unchanged, and the wgpu claim is
  L4 work with a number attached to it now.
- Editing the matrices turned up a second truth gap: the Chinese mirror listed Sun
  as `supported` for the emoji row where `moui_sun_renderer/capabilities.mbt:24`
  reports `Partial`. The mirror is not machine-checked, so the divergence sat there
  silently; corrected on the same line as the Metal cell.
- With `EmojiText` no longer `Gap`, the compiler reported the catch-alls in
  `metal_feature_status` / `metal_feature_note` unreachable, so both walks now name
  all 17 features and a new `RendererFeature` variant is a compile error in this
  module rather than a row that silently reports `gap`. The trade is recorded
  honestly: the note-vs-status tripwire's `Gap` half has no row to fire on today,
  and the guarantee that replaces it is the compile error plus the 85-cell
  validator, which runs on every host while this module compiles only on darwin.

**L3c — atlas capacity, measured through the real provider (2026-10-28).** The
previous leg's scoping note listed four packing divergences and called the
empty-glyph and padding rules "correctness differences". Measured, that is wrong,
and the error matters because it pointed the work at the wrong file: none of those
four can produce a wrong pixel, while a difference the list *omitted* — the atlas
side, 512 here against the sibling's 1024 — silently loses text on the platform
this route targets.

- Inert, with the reason: the padding rule cannot bleed because the glyph sampler
  is `MTLSamplerMinMagFilterNearest` (`metal_renderer.mm:317`), so no fragment
  ever reads a neighbour texel; writing vs skipping transparent texels cannot ghost
  because both routes' `clear()` reallocates a zeroed buffer; a zero-size raster
  costs Metal one shelf pixel per *distinct* empty cache key (512 of them to spend a
  row); and return-value-vs-counter is reporting, not drawing.
- Failure-bearing, and it was a real one: filling the 512 atlas with distinct
  hanzi through the CoreText provider — the same frame the plan's own L3a test
  describes — gives a capacity of **~200 distinct glyphs at 14pt and device scale
  2.0**, ~651 at 14pt/1.0, ~333 at 24pt/1.0, ~92 at 24pt/2.0. A 1200×800 Retina
  page of Chinese prose wants on the order of a thousand distinct ideographs, so
  the densest pages dropped their own overflow **every frame**: L3a's retry fixed
  the cross-frame wall, not the within-frame ceiling, and the surviving drops are
  not a degradation a counter describes either.
- The atlas side is now 1024, which is the sibling's budget rather than an
  invention, and the measured capacity follows it: **~818 at 14pt/2.0** and ~347 at
  24pt/2.0, ~1389 at 24pt/1.0, and no drops for 1600 distinct 14pt ideographs
  **at device scale 1.0** — the sentence as first written left the scale out and
  therefore read as if 1600 ideographs fit one page at Retina too, which is exactly
  the case paging closed the same day. Both scales are now re-measured by the smoke
  on every run: `scale=1 items=1 dropped=0`, `scale=2 items=2 dropped=0`.
  What it costs, stated: 4 MB of CPU pixel buffer and a 4 MB RGBA8 texture resident
  for the life of the renderer (was 1 MB each), the whole texture re-uploaded on
  every frame that introduces a glyph, and one 4 MB zero-fill on each overflow
  retry — `clear_metal_glyph_atlas` now fills the existing array in place instead of
  reallocating it, so the retry costs no allocation, and the field lost its `mut`
  because the compiler said so. Amended by the paged atlas below: the 4 MB pair is
  page 0 and the steady state, not the ceiling, and a re-upload now covers only the
  page a glyph landed on.
- Drift between the two sides is now loud instead of silent: the size lives once in
  MoonBit and once in the bridge, and `moui_metal_texture_write` compares the buffer
  length against `side*side*4` for equality where it previously used it as a floor,
  so a caller that is larger than the texture is refused rather than uploading a
  prefix and sampling garbage for the rest. Proven by A/B, not asserted: setting the
  MoonBit side back to 512 against a 1024 bridge fails three GPU pixel tests plus
  the new capacity test, and that test's own failure message reads "a 512x512 atlas
  only fit 289 distinct 28x28 glyph boxes" — the floor (`metal_text_wbtest.mbt`:
  "the atlas holds a retina page's distinct glyph boxes") sits under the measured
  818 and well above the old 289, so shrinking the budget fails in the module
  instead of showing up as missing text.
- Not done here, and named so it is not mistaken for finished: an eviction record
  keyed by use (the working set above capacity thrashes the same way it clears, so
  it prevents no drop and is not owed), and dirty-rect uploads (a cost signal with no
  perf gate to act on it — L4). The remaining ceiling **was** done here, later the
  same day: the page set replaced it, and with it the `Text` row's disclosed
  "a frame whose own glyph set does not fit an empty 1024x1024 atlas still drops and
  counts". One more pair is now written in two languages, which the bullet above
  already covers for the side: `METAL_ATLAS_MAX_PAGES` and
  `kMouiMetalMaxAtlasPages`, where the host refuses a page index past its own cap
  instead of growing the array on a value the CPU side never intended to send.

**L3 — text fidelity.** Glyph atlas residency plus the paragraph layer. The
provider-parametric measure matrix already exists and already drives non-Skia
providers (`moui_tests/text_conformance/native/text_conformance_test.mbt:104-123`,
:362-407, 16 samples); only the paragraph / hit-test layer (:247-286) and the
Skia maturity-signal strings (:55-76) are Skia-bound. A fourth "usable but worse"
text copy is a reason to stop, not to ship.

- **Shared-atlas scoping, measured 2026-10-28 (before deciding).** The copies are
  two, not three: `moui_wgpu_renderer/native_text_glyph_atlas.mbt` (135 lines)
  and `moui_metal_renderer/metal_text.mbt`'s atlas (160 lines). Sun is a CPU
  raster and owns no atlas at all, so nothing is being duplicated a third time.
  The two agree on shelf packing and disagree on four behaviours, each of which a
  shared seam would have to parameterise: padding is two-sided in WGPU (the glyph
  is inset by `padding`, so the shelf advance is `width + 2*padding`) and
  trailing in Metal; a zero-size raster consumes no shelf at all in WGPU
  (`place_glyph` returns `(0,0)` before the cursor moves) while Metal advances it
  by the padding, so a run of space glyphs slowly eats its own atlas; WGPU skips
  writing fully transparent texels, Metal writes them; WGPU reports full/missing
  as a return value, Metal as counters.
  That is the honest case against extracting the atlas now: four switches at the
  seam, and the L3 fidelity work (eviction records, colour-font evidence, fallback
  chain) is exactly what would keep moving them. The order that follows from this
  is to converge the *behaviours* first — the empty-glyph and padding rules are
  correctness differences between two renderers that both claim `Partial` for the
  same feature — and only then, if a third GPU route ever appears, deduplicate
  what has become identical.
  **Corrected by L3c, in both halves.** Those four behaviours turned out not to be
  correctness differences (nearest sampling, zeroed clears, one pixel per distinct
  empty key), and the difference that *was* correctness-bearing — a 512 side against
  1024 — was not in the list at all. So converging the list would have bought a
  shared seam for four inert switches while the text kept disappearing, and with
  the capacity now matched the two copies differ only in reporting and density:
  extraction has nothing left to protect and stays deferred until a third GPU route
  makes it worth a module. The lesson for the next scoping note: enumerate the
  differences by what they can *draw wrong*, and measure the budget constants
  first.

**L4 — capability truth.** The 17 `RendererFeature` states
(`moui/render/capabilities_feature_model.mbt:2`) from real probes or pixel tests;
`gpu_recovery` / `recover` must not use the default that always returns success
(a known vacuous gate in this repo); product class declared `experimental` with
its own ADR, the way ADR 0023 did for `sun`.

**L4 gpu_recovery, measured 2026-10-28: the vacuous default was real, and the
promotion harness was compounding it.** `RendererSession::new`'s `recover~`
default returned `RecoverySucceeded` — a session with no recovery path reporting
a rebuild it never did. (Every concrete renderer already passed `recover~`
explicitly — Skia/WGPU/Sun `FallbackToCpu`, TUI/Web success, Metal a named
refusal — so the default was a trap for the *next* renderer rather than a live
lie today; it now refuses.) The larger half was the host: the macOS GPU
promotion harness's context-loss phase ended by writing
`context_loss_done = context_loss_injected` and
`recovered_within_vsyncs = wait_presents` **whether or not anything recovered**,
and `gpu_recovery_count()` is a constant 0 on every route (Skia wires only
`gpu_fallback_active`), so `diagnostics.recoveryCount` in a recorded artifact was
the number of losses *injected*. Neither number is fabricated now: a loss counts
as done only when the renderer's recovery counter advanced, and the summary line
carries `context_loss_injected=` alongside `recovery_count_before=/after=` so a
reader can see the instrumentation state. Skia's own claim is untouched because
it rides `automatic_fallback`, which the harness sets from
`gpu_fallback_active()` — the one signal that is wired.

**L4 paint-state probes, measured 2026-10-28: the first capability rows put
through the device, and the two mis-draws that found.**

`Transform` and `Opacity` were the two rows of the 17 that had never been drawn:
`PushTransform`/`PopTransform` and `PushOpacity`/`PopOpacity` appeared in zero
tests, so each reported `Partial` on the strength of a reading of
`metal_geometry.mbt`. Eleven device probes now pin them
(`moui_metal_renderer/metal_state_wbtest.mbt`, module tests 48 → 59, and 63 after
the row walk below), and
putting a transform through the route for the first time found two real mis-draws,
both fixed:

1. **A box was culled by its untransformed rect.** `append_metal_box` tested
   `state.clip.intersection(rect)` before emitting a vertex, so a rect whose
   transform carried it into a layer's masked frame was counted as
   `clipped_away_ops` and drawn as nothing — reproducible as
   `PushLayer(mask = RectMask(4,4,8,8))` + `PushTranslate(4,4)` + `FillRect(0,0,4,4)`
   on a 16x16 surface: empty, while the same stream outside the layer and the same
   rect with an identity transform both paint. The cull now reads
   `metal_transformed_bounds(rect, state.transform)` (also applied to the image
   op's identical test), and `a transform that moves a box into a masked layer's
   frame is not culled` pins it.
2. **A clip pushed under a transform clipped where it was written.**
   `metal_state_with_clip` intersected the raw rect, while
   `moui_wgpu_renderer/native_visual_state.mbt:48` pushes
   `transform_rect(rect, state.transform)` — so the two routes read the same
   command stream differently, and the reference route was the evidence, not a
   spec. Now transformed, with the same rule wgpu keeps for the exception: a
   `LayerSpec` mask is **not** transformed (`native_visual_state.mbt:185` does not
   either), because a mask names a frame on the surface rather than a shape in the
   caller's space.

Non-vacuity was checked by mutation, not by inspection: replacing
`transform_metal_point` with the identity fails all 8 transform and clip probes;
reverting either fix fails exactly its own probes (1 and 2). The first A/B attempt
silently matched nothing — `moon fmt` had re-indented the expression it patched —
and reported a passing "revert", which is the same trap as the `recover~` A/B
earlier in this plan.

Both statuses stay `Partial`, for the reasons their notes already named (per-vertex
CPU composition, no per-object matrix upload; bounding-rect rounded clips, counted
through `approximated_clip_count`). What changed is that the notes now cite bytes
read off a Metal device. The limit worth keeping: these are host tests — `metal_proof`
aborts without a device rather than skipping, so a host without Metal fails loudly
instead of green.

**L4 capability-row walk, measured 2026-10-28: the capability table itself put under
observation.**

The state probes answered "does this op draw?" for 2 of 17 rows. The rest of the
table has a cheaper, uglier hole: the other 15 rows have pixel tests, but nothing
joined a row's *label* to a number the device produced.
`scripts/validate-renderer-capability-consistency.mjs` compares
`docs/renderer-capability-report.md` against `metal_feature_status`, so the docs and
the code can agree exactly about a feature this route paints as nothing — and a
`Partial` label looks conservative enough that nobody goes looking.
`moui_metal_renderer/metal_feature_probe_wbtest.mbt` (4 tests; module 59 → 63) asks
the device once per row what that row's own minimum stream produced:

- `no capability row claims ink the device did not paint` walks all 17 statuses:
  `Supported`/`Partial`/`HostForwarded` must put at least one pixel above the
  clear's noise floor, `Gap`/`Unavailable` must put none. It also asserts
  `probed == 16`, because a walk that silently skipped rows would still satisfy its
  own loop.
- The one row a single frame cannot answer is exempted **by name**, not by silence:
  `AsyncImage` requests on frame one and paints after the completion, so its
  evidence is the two lifecycle proofs in `metal_image_wbtest.mbt`.
  `the exempted row is exempt because one frame really paints nothing` re-asserts
  the exemption's premise every run, so the exemption cannot become a place to hide.
- `a row that claims supported refuses nothing in its own probe` turns the
  `MetalFrameReport` counters into a claim check: a `Supported` row whose probe
  stream trips `refused_count()` reports a fidelity the route did not deliver.
  `metal_frame_report` has no decoder by design, so `image_ops_unresolved` stays
  outside that count rather than becoming evidence about the `Image` row.
- `the shaping row is forwarded, not drawn by this route` is the only row whose
  claim is about absence: the same command stream paints ink through the injected
  engine and nothing through the noop engine.

Two streams cost more than a line. `BlendMode`'s first probe used `Multiply` and
painted nothing — which is what multiply against an opaque black clear *should* do,
so the honest fork was between changing the stream and loosening the assertion; it
uses `Screen`, whose white-over-black is the composite's own ink. `Text`,
`TextShaping` and `EmojiText` need different rasters (coverage for the first two,
the green colour bitmap for the third) or their probes would be three copies of one
frame distinguishing nothing.

Teeth, measured rather than assumed. Flipping `Rect` to `Gap` fails the ink walk
("the rect row reports gap while its probe stream paints 64 pixels") *and* the notes
test ("a Gap row must say the feature is absent"); flipping `BlendMode` to
`Supported` fails the claim check ("the blend-mode row reports supported, but its
probe refuses 1 ops"). Both flips were applied to the formatted file with the patch
confirmed present before running — the discipline that caught the two earlier false
"passing" A/Bs in this plan — and the restore is byte-verified against a
pre-mutation checksum (`shasum -c`), after which 63/63.

The honest scope: the walk proves "the stream named after this row paints ink". It
does not machine-check that the stream contains that row's op; that stays a review
obligation on `metal_probe_commands`, backed by the per-feature pixel proofs
elsewhere in the package. `TextShaping` and `EmojiText` reuse the text run, so their
ink is text ink — which is exactly why the shaping row gets the engine-dependence
assertion instead of a bare "paints something".

**L4 text fidelity, measured 2026-10-28: the half of "the renderer draws text" that
the renderer does not do.**

Read closely, the route's text claim is narrower than it looks.
`moui_metal_renderer/binding_factory.mbt:62` installs
`@native_text.native_text_system_with_cache(self.cache)`, and
`moui/render/native_text/text_cache.mbt:227-231` builds that system with `measure`
and **no** `paragraph_layout` hook — so `moui/core/text_layout.mbt:155` gives every
`Text`, `TextArea` and `TextField` on this route core's per-line fallback, measured
by whatever provider the composition root injected. Line breaking, caret rects,
selection rects and hit-testing on the Metal route are therefore *not* renderer code
at all, and nothing had ever put that combination under assertion:
`moui_tests/text_conformance/native` had a paragraph test, but the only system it
ran through it was `skia_text_system()`, which does pass a native hook.

What landed instead, in the one suite that already owns text fidelity:

- `assert_diagnostic_native_paragraph_contract(system)` — the route-independent half
  of the existing Skia paragraph test, extracted rather than copied (wrapped to ≥2
  lines under a `max_width`, one caret rect per cluster, per-line height and
  baseline, a selection spanning two lines, a hit-test past the right edge landing
  on line 1).
- A cosmic-backed case in that package (10 → 11 tests). Cosmic is cross-platform, so
  the paragraph path this route depends on is now held on Linux and Windows CI too,
  not only on the darwin host that can link CoreText.
- A CoreText-backed case in `moui_text_providers/coretext` (22 → 23 tests) — the
  engine `examples/showcase/macos_metal` actually injects — asserting the same
  contract against CoreText's own widths plus `native_paragraph_ready == false`,
  which is the honest half: the line breaks came from fallback arithmetic over
  provider metrics, not from a shaper.

Teeth, and the part that shows the coverage was genuinely absent: making
`fallback_paragraph_should_wrap` never wrap fails **both** new tests while the Skia
paragraph test stays green. Restore byte-verified against a pre-mutation checksum.

Two findings came out of the same leg:

1. **The wiring claim had a test named for it and no test checking it.**
   `metal session reports the fallback text system until the text leg lands`
   asserted `present_count` and the `recover` reason — nothing about the text
   system. The title had outlived its content by three legs. It is renamed to what
   it pins, and `metal session gives the runtime the injected engine's text system`
   (module 63 → 64) now reads the metrics back off the session's own system;
   re-pointing `text_system=` at `@core.TextSystem::fallback()` fails exactly that
   test. The first fixture tried there measured 8.8 wide where the provider had
   said 6.0: `NativeTextLayout::is_valid_for_measure`
   (`moui/render/native_text/layout_validation.mbt:18`) requires a caret per
   cluster, rejects the caret-less test layout, and the shared model substitutes
   core's ~0.55em estimate for the widget while the painter still uses the
   provider's placements. Real providers ship caret tables (the CoreText suite
   pins those counts), so this is a fixture property rather than a route bug — but
   it is precisely the split the new test exists to catch, which is why its
   fixture carries numbers no estimate produces.
2. **No profile ran the provider this route's text depends on.**
   `checks/profiles.json` had steps for `moui_metal_renderer` and its smoke and none
   for `moui_text_providers`, so those 22 CoreText tests only ever executed when
   someone typed the command. A darwin-host `CoreText provider tests` step is now in
   the `platform` profile beside the Metal ones.

No capability cell moved (85 cells still match), and the honest limit: the contract
is asserted through the text system that the route installs, not through a Metal
frame — wrapped paragraph *pixels* on the device remain the run-placement tests in
`metal_text_wbtest.mbt`, and the wgpu route inherits the same shared contract
because it installs the same kind of system.

**L3 gap closed, measured 2026-10-28: a colour glyph inside a group.**

The `EmojiText` row's own note named its remaining half — "a colour glyph inside a
layer or filter group has not been put through" — and putting it through turned out to
be three fixtures the module already had (`metal_test_engine_for` on a colour raster,
`metal_layer`, `metal_filter`) rather than new mechanism. All three pass, so the route
carries a colour glyph's pixels into an offscreen group, composites them without
re-tinting, lets a brightness filter rewrite them as colour, and clips them with the
layer's rect mask (module 64 → 67):

- `a colour glyph keeps its pixels through a layer composite` — green stays green under
  a pure-red run, inside the group.
- `a filter group rewrites a colour glyph as colour, not as coverage` — half brightness
  halves the glyph's green; the assert that fails on the wrong branch is the red one,
  because a coverage glyph tinted by that same red run gives 128 there.
- `a masked layer clips its colour glyph as well as its pixels` — nothing had put *text*
  inside a masked group before (the mask tests all used fills), so this one pins both
  halves at once: inked at (1,1), black at (5,3) where the 4x4 mask ends.

Teeth, twice, each with the patch confirmed in the formatted file first and the restore
byte-verified with `shasum -c`: forcing `coverage_only` in `blit_metal_glyph`
(`metal_text.mbt:163`) fails 3 tests — the main-pass pair and both group cases — and the
filter case names the mechanism ("red channel 128 leaked the run colour"); dropping the
mask out of `metal_layer_clip` (`metal_geometry_scopes.mbt:24`) fails 5, including the
new text case at its (5,3) assert. The second mutation is shared with the fill-based mask
tests, which is the honest reading of what these three add: they extend the *context* the
colour branch is claimed in, they do not test a group-specific colour path, because the
atlas is one texture and the group composite never sees a run colour to leak.

No cell moved (85 cells, `EmojiText` still `Partial`), and the note now names what is
left: the real-provider smoke is one run at a time on the main pass at 32pt and scale
factor 1.0, a rounded-mask group and two nested colour-carrying groups have not been put
through, and whether a codepoint is colour at all remains the shared provider's
`kCTFontColorGlyphsTrait` decision.

## Cross-route capability finding, measured 2026-10-28: the diagnostic route's `Clip`
row claims what the Metal route discloses as missing

The row walk left one asymmetry the other direction. `docs/renderer-capability-report.md`
marks `Clip` `supported` for `Native wgpu diagnostic` and `partial` for `Native direct
GPU`, with the Metal note naming its missing half (a rounded clip uses its bounding rect,
counted in `approximated_clips`). The wgpu route does the same thing:
`moui_wgpu_renderer/native_visual_state.mbt:56-81` tracks a `clip_radius` (min of the
nested radii) that **no code reads** — `native_scissor_for_state` (`:162`) builds the
scissor from `state.clip`, a plain `Rect`, and the only per-vertex radius channel is
`mask_radius`, fed from `layer.mask` (`native_visual_advanced.mbt:10`), never from a
clip. So a rounded *layer mask* really rounds on that route and a rounded *clip* does
not, while its table cell says `supported` and its note says nothing about clips.

Not fixed here. Correcting another module's published self-report (and the report's
`Clip` row, which the capability validator compares against code) is a claim change on
the diagnostic route, not evidence this route needed, and the alternative — making
rounded clips exact — is one mechanism shared by both GPU routes, so the honest sequence
is to build it once and let both rows move. What this finding changes is the target: the
exact-rounded-clip work (stencil write on the clip shape + stencil-equal compare on
subsequent draws, which is what an SDF-in-fragment cannot do for nested clips because a
vertex carries only one clip slot) closes a row on two routes and retires a dead field on
the third. Recorded as an open item rather than scheduled, because the owner's plan does
not ask for it at any stage: L4's own definition (17 rows from real probes, a
non-vacuous `recover`, an `experimental` product-class ADR) is met.

## Permanent cost surfaces

Registering a new renderer is not just drawing code. Mandatory: `moon.work`
member; `checks/release-modules.json` row; `checks/profiles.json` test steps; a
`docs/renderer-capability-report.md` column plus its zh-Hans mirror; provider
capability tests; `examples/showcase/macos_metal` entrypoint; and the
provider-surface gates `scripts/validate-renderer-provider-manifests.mjs` +
`scripts/validate-renderer-provider-open-extension.mjs` (ADR 0027 caps session /
provider accretion). Plus, on the engine side: antialiased GPU path rasterization
quality, gradients, blur/shadow filters, clip and damage correctness, glyph
atlas eviction, and device-lost recovery — all of which Skia currently absorbs,
and all of which become MoUI-owned code with MoUI-owned bugs.

Damage is the one item on that list this route answers by *not* acting:
`render_frame` ignores `frame.damage` and repaints the whole surface, because the
present pass clears the drawable on load, so honouring a damage rect would erase the
rest of the frame instead of preserving it. Making partial repaint correct means a
retained backbuffer or `framebufferOnly = NO` plus a copy of the previous frame — the
same cost family the backdrop snapshot was declined for — and no measurement has yet
shown a frame rate this route loses to that cost. The note in `renderer.mbt` exists so
the omission reads as a decision rather than an oversight, and so the "fix" that drops
the damage check into the scissor without the backbuffer is not attempted.

## Naming trap

`docs/platform-notes-macos.md:97` already calls the *shipped* Skia-on-Metal
surface "the direct Metal GPU provider" (versus the CPU-raster + `NSImageView`
fallback). "Direct Metal" does not distinguish this route; **"no Skia, no
wgpu"** does. Keep that phrase in every writeup or the docs will describe two
different things with one name.

A second instance is already in the artifacts, and it is worse because it is
machine-readable: every text provider in `wzzc-dev/moui_text_providers` still
carries its pre-relocation id — `native-wgpu-coretext-system`
(`moui_text_providers/coretext/coretext_text.mbt:33`), `native-wgpu-cosmic-fallback`,
`native-wgpu-directwrite-planned`, `native-wgpu-fontconfig-freetype` — and that
string is what `TextSystem::id()` and `TextParagraphLayoutResult::metadata.text_system_id`
report at runtime. So a Metal-route artifact names its text system as a wgpu one,
which is exactly the confusion the paragraph above warns about, arriving through a
diagnostic field instead of prose. Left unfixed here on purpose: the ids are
published behavior of `moui_text_providers@0.2.2`, pinned by its own tests, and a
rename of a runtime-visible string across four modules is an owner call, not a
side effect of an evidence leg.

## Decision log

| Date | Decision |
|------|----------|
| 2026-10-26 | Rejected at the M0 gate (ADR 0043) with four checks and three ordered re-open conditions. |
| 2026-10-27 | Owner fixed the dependency boundary (OS frameworks yes, external graphics libraries no). Kill reason 2 voided, condition (2) removed as a gate; route reopened as this plan under ADR 0044. |
| 2026-10-27 | Apple-first chosen; cross-platform coverage explicitly excluded from this plan's scope rather than deferred inside it. |
| 2026-10-27 | L0 kill gate **fired on its second branch**: the shipped Skia-Metal route already holds the renderer-attributable present slice at 0.10–0.76 ms p50 while the frame-dominating scenarios are 92–95% framework, so there is no performance prize left for a hand-written backend. The license motive is struck (L0.3). The route does not enter L1. Surviving motives, re-priced: size **relative to Skia** (4.06–11.05 MB GPU band vs 20.35 MB, and no boundary-compliant route has GPU today) and autonomy; size **below the ≈4.0 MB framework floor** is off the table, which is where the earlier draft of this plan had over-claimed. |
| 2026-10-27 | L0.2 placed in `moui/render/native_text` — inside the published base module rather than a new top-level module — because AGENTS.md routes "render protocols/algorithms → `moui/render`", every consumer already depends on `wzzc-dev/moui`, and a new module would need `moon.work` + `checks/release-modules.json` registration for no gain. The wgpu renderer root re-exports the moved names (`pub using`) instead of asking its consumers to repoint, so the extraction is invisible to `examples/showcase/*_wgpu` and `moui_tests/wgpu_renderer_smoke`. |
| 2026-10-27 | Deliberate non-changes recorded so they are not mistaken for oversights: the five provider packages stay inside the `moui_wgpu_renderer` module (relocation is its own structural decision, and L0.2's criterion is import-level), and `NativeTextEngineSetting` — public, `pub(all)`, and referenced by **zero** local source files (only vendored `.mooncakes` copies of older published layouts) — was carried along in the wgpu root untouched rather than deleted or moved, because deleting public API is an owner call, not an extraction side-effect. |

| 2026-10-27 | L0.1 kept the **gated** runner on the concrete Skia path and added the provider path as a second, separately-labelled identity (`native-skia-raster-via-provider`) instead of converting the gated one. The two construction paths are not identical — the provider factory sets `async_image_loading=true` (`moui_skia_renderer/binding_factory.mbt:28`) while the harness constructor takes `false` (`moui_skia_renderer/renderer.mbt:211`) — so swapping them would have re-priced every committed `native-skia-raster` baseline as a side effect of an instrument change. The A/B row in "L0.1 measured" is what makes that caution auditable rather than assumed: same engine through both paths, ±4% on `frameMs` p50 — a band later shown to sit inside this runner's own repeat spread, so it certifies "no visible overhead", not a price. |
| 2026-10-27 | L0.1 scope cut, recorded so it is not mistaken for an oversight: `benchmarks/app_cached_layer/native/main.mbt` stays typed to `@skia_renderer.SkiaRasterRenderer`. Its numbers do not feed a route decision, and duplicating the pump into a second executable buys no evidence for the cost of a permanent second copy to maintain. Same reasoning for the `metal-gpu` present modes: they are arguments to Skia's own constructor, so the harness refuses (`perf_assert_provider_mode`) to run a non-`skia` provider under them rather than emit a mislabelled control number. |
| 2026-10-27 | L0.5 destination chosen as a **new published module with `role: "binding"`**, not a new renderer module and not a package inside `wzzc-dev/moui`. Landing the providers in `moui` hard-fails `validate_base_closure` (they carry `Milky2018/moon_cosmic` / `moon_swash`); giving the new module `role: "renderer"` would have made `moui_wgpu_renderer` the P14 violator it exists to prevent. `binding` is the topology `moui_skia` (292 externs) and `moui_sun` already use, and it is what makes the P6 clause "native bindings live in `moui_*_renderer` modules" read as scoping *renderer-specific* bindings rather than every native binding. No compatibility re-export shims at the old paths: `examples/momark` and `moui_studio` are submodules that resolve the already-published `wzzc-dev/moui_wgpu_renderer@0.2.2` from the registry, so a shim would pay for a local dependency that does not exist. |
| 2026-10-28 | The size motive is **recorded as measured, not derived**, and the derivation was wrong: the plan's own earlier text ("a no-third-party GPU renderer adds a rasterizer … it cannot subtract from it", "a GPU route lands in the 4.06–11.05 MB band") is kept where it stands and marked corrected in place, rather than deleted, because it is the record of how the route was almost talked out of existing on a number nobody had built. The measured pair is same-day, same-app, same-flags (`-Wl,-dead_strip -Wl,-x` added to the two entrypoints' `moon.pkg` only for the measurement and reverted immediately after, so the committed tree stays flag-free and the number is reproducible only by re-adding them). |
| 2026-10-28 | L4's recovery work done as **contract honesty, not engine code**: a Metal device-loss rebuild would have had no caller (`RendererSession::recover` is invoked only from tests; `MTLDevice isRemoved` is never polled), while the two vacuities that do exist were closable in a few lines — `recover~`'s always-success default, and a promotion harness that recorded injected losses as completed recoveries. Reopen condition for the engine in ADR 0045 §"Amended 2026-10-28 (L4)". |
| 2026-10-28 | "Complete" split into two halves on the text leg, and the fork was decided **toward the contract, not a second engine**: paragraph layout, caret/selection rects and hit-testing on this route are `moui/core`'s fallback arithmetic over the injected provider's metrics (`moui/render/native_text/text_cache.mbt:227-231` passes no `paragraph_layout` hook), which is already the route's published claim rather than a hidden degradation — `moui_metal_renderer/capabilities.mbt`'s `Text` note says the composition root wraps the platform provider with no second engine behind it, and `docs/renderer-capability-report.md`'s `Native direct GPU` column marks `Text` `partial`. Building a Metal-owned shaper would have been a third copy of a contract the repo already owns in two places, so the work taken instead was to put the *existing* combination under assertion (`moui_tests/text_conformance/native` plus a CoreText provider case), which is what L4's "renderer draws text" claim can be held to without growing the module. |

## Progress

| Date | Note |
|------|------|
| 2026-10-28 | **Decoded-image residency stopped being unbounded, and the claim that it was became a test.** The `AsyncImage` note said "one texture per distinct source is held until the context itself is released", which was true and was also the kind of sentence a route keeps by saying the policy belongs elsewhere. It does not: `apply_metal_image_completion` installs textures, so the installer can also release them. Every build now enforces a resident-bytes budget (`METAL_IMAGE_MAX_RESIDENT_BYTES` = 64 MB) over the installed set, releasing least-recently-used through a new `moui_metal_image_release` host call (extern count 8 → 9, still inside the plan's 10–40 estimate), dropping the source/key lookups so the next frame treats it as unresolved, and recording the count in `image_textures_released` (interface budget 56 → 57, one more field of the same report struct). The budget is a `MetalFrameContext` field, not a constant at the call site — that is what makes the test drive the automatic path instead of a helper it calls by hand; the first version of the test did exactly that and an A/B (deleting the enforcement) proved it: the manual call left the test green, the wired field makes it red. `metal_image_wbtest.mbt` (`an evicted image is requested again while the resident one keeps painting`) asserts the thing that matters about eviction: the released source is either re-resolved or requested on the next frame (`item_count + image_ops_pending == 1`), nothing disappears into a silent hole, and after the completion the fixture paints its red/blue halves again on the device. The test also corrected a premise mid-write: an image with a readable host source resolves **inside** the build, so the staged request→complete→request sequence the first draft assumed never happened, and the assertion became the invariant rather than the script. What stays open, named in the note: this is eviction under byte pressure, not reclamation on notification — `ImageResourceLifecycle::evict_disposed` still has no callers anywhere, and when a disposed source should be dropped is a decision above this module. One process own-goal: restoring from a stale `/tmp` backup clobbered the struct field I had just added and cost two extra compile rounds — back up the current state, not an earlier one, when a revert is a possibility. 91/91 module tests. **And the `pr` claim attached to this row was wrong when first written**: the background run reported exit 0 because the pipeline ended in `tail`, so the shell status was `tail`'s, and the profile had actually died in `generate-repo-docs --check` — first because the interface numbers were never regenerated after the new report field, then because the budget-raising comment pushed `tools/moui/validate_api_surface/main.mbt` past its own registered line budget. Both fixed (docs regenerated; the rationale comment shortened), and `pr` now passes with its status read directly (`pr-exit=0`, "MoUI pr checks passed"). The lesson is the same one this route keeps paying for: never report a gate you have not read the result of, and never trust an exit code from a pipeline. |
| 2026-10-28 | **The windowed gate now reads the presented surface, and ink on it is what the old gate would have missed.** `scripts/macos-metal-presentation-smoke.sh` previously proved two things — the direct route was the one selected, and the host presented a frame. Neither would have noticed a presented **blank** surface: the marker prints whether or not anything was drawn. The host now copies the drawable it is about to present into a staging texture and counts the pixels differing from the frame's clear colour, printing `MOUI-METAL-PRESENT width=.. height=.. ink=..`; measured on a real window, 1,817,023 of 2,992,000 pixels (60.6%) carry the UI on a 2200×1360 Retina drawable. The gate parses that line and rejects ink outside a 0.5%–99.5% band, so both an untouched surface and a surface that differs from its clear colour everywhere (a broken clear) fail. `framebufferOnly` is flipped to `NO` **only while the smoke variable is set**, because the copy costs bandwidth on every frame; without the flag the layer is built exactly as before. Falsified by construction: forcing the reported count to 0 leaves the identity line and the first-frame marker both intact — the old gate would have gone green — while the new one exits 1 with "presented surface has ink=0 of 2992000 pixels"; restoring the count is byte-exact by `diff`, and the gate passes again. The addition pushed `metal_renderer.mm` past the 1200-line new-source hard limit, which `pr` caught, so the readback became its own translation unit (`metal_present_smoke.mm`, 95 lines, registered in `native-stub`) rather than a registered ratchet — the host file is back to 1148 and the gate measures the same figure. What this is not: pixel fidelity in a window. It asserts coverage — that the route drew something with the right shape of extent onto the real surface — while per-pixel claims stay with the offscreen proofs, where they belong because those can assert exact channels. 90/90 module tests, both smokes green, six validators green. |
| 2026-10-28 | **Two disclosure fixes, one of them a claim I had written this morning and gotten wrong.** (1) **Damage:** `MetalRenderer::render_frame` never reads `frame.damage` — it repaints the whole surface — and nothing said so. The reason is structural rather than lazy: the present pass sets `MTLLoadActionClear` on the drawable (`moui_metal_pass`), so restricting a draw to a damage rect would *erase* everything outside it, and correct partial repaint needs a retained backbuffer or `framebufferOnly = NO` plus a previous-frame copy — the same cost family for which the `Overlay` backdrop was declined. The decision is now a comment at the call site and a paragraph in Permanent cost surfaces, which also warns off the tempting one-line "fix" that would ship a blank frame. (2) **A false limitation in my own note:** the `Shadow` row claimed "a path- or texture-filled source still casts its bounding box". `ShadowSpec::new` takes `rect~ : RoundedRect` with colour/offset/blur/spread, so the command model cannot express a path-shaped shadow and no app can hit the described mis-draw — the sentence invented a gap. Corrected in `capabilities.mbt` and both report matrices, with the real residual named instead: the corner falloff follows the distance field rather than an exact 2-D convolution. The rule this generalises: an over-pessimistic row costs what an optimistic one costs, because each makes the table unusable — one hides a gap, the other invents work — and both are caught by the same habit of going back to the type or the device for the claim. No behaviour changed: 90/90, six validators green. |
| 2026-10-28 | **The row walk now asks each row for its own consequence, not just for ink.** The L4 walk (`metal_feature_probe_wbtest.mbt`) proved a row's status was compatible with what its probe stream painted, and its own header admitted the weak half: *"nothing here checks that a stream contains the op its row is named for"*. `metal_probe_row_observed(feature, report, pixels)` closes it as a **total match over all 17 features** — no catch-all, so a new `RendererFeature` variant is now a compile error in the walk as well as in the two capability walks. Each arm is a measured consequence the other rows cannot produce, and every threshold was taken from a printed pass over all 17 streams before it was written down, not guessed: the clip halves coverage to ~16 pixels where a rect gives 64; the transform leaves `(0,0)` black and inks `(6,6)`; a blur puts light **outside** the shape it wrapped (ink 80 > the 64 the fill could cover) and reports 2 passes with 1 counted approximation; the rounded box leaves `(0,0)` clear at 60/64 inked; the gradient changes channel along its axis; opacity lands at 128; the shadow inks pixels beyond its rect and thins outward; the image samples red-left/blue-right from the fixture; `Text` and `TextShaping` stay under 48 pixels so neither can be a solid bar; `EmojiText` lights green under a pure-red run; `ShaderEffect` and `BlendMode` report their own counters (fallback painted, blend approximated). The measurement earned its keep twice: my first `Image` predicate asserted red+blue in the same pixel because I misread the printed tuple's channel order, and it failed the walk before any ship — the printed numbers, not my reading of the fixture, are what settled it. A/B: replacing the Clip row's stream with a bare fill (op dropped, ink still 64) fails exactly the consequence assert; restore `shasum -c`-verified, 90/90. Honest remainder, now written in the header: choosing a row's *stream* is still review work, but a stream that does not exercise its row has to fail the predicate written for it, so the mistake surfaces at a gate instead of in a reader's attention. `AsyncImage` stays exempt by name and its exemption premise is re-asserted each run, as before. |
| 2026-10-28 | **The route had never been run in a window by anything committed; now it has, and the gate refuses to credit the wrong renderer.** `moui_metal_renderer` had offscreen pixel proofs, a real-provider text smoke, module tests and validators — and no committed step that opened a `CAMetalLayer` and presented. Running it by hand worked first try: `MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/macos_metal` printed `macOS renderer presented first frame; exiting by request` and exited 0, so the whole framework loop (build, layout, text, images, host present) holds on the direct route. That is evidence, not a gate, so it became one: `scripts/macos-metal-presentation-smoke.sh`, registered as a darwin `platform` step next to the other two Metal steps. The gate needs two lines, not one: the host's marker names the *platform* — Skia and wgpu present through the same backend and print the same sentence — so the entrypoint now also prints an identity line built from the module's own `metal_renderer_descriptor` and capability rows (`renderer=direct-gpu family=direct-gpu provider=metal-direct`). A/B on the gate rather than on the app: pointing its identity grep at `renderer=skia-raster` exits 1 with "no renderer identity line; the presenting route is unnamed", and restoring it passes, which is the proof the second grep is load-bearing and the first alone would have been decoration. Two now-false sentences written earlier today were refreshed rather than left standing: the `LayerCompositing` note's "no committed script launches it" and the plan's equivalent claim, both marked as retired history with the script named. `AGENTS.md` gained the script in its manual-smoke list — a one-line factual edit to project instructions, flagged here so it is visible rather than silently absorbed. Module tests 90/90, `profiles.json` parses, validators green; the `platform` profile now runs the presentation step on darwin. What this does *not* claim: it is a first-frame present, not a pixel assertion in a window (no readback of the drawable), and readiness stays `experimental` — one frame, one host, no interaction evidence. The plan's L3-shaped gap that it closes is "has it ever run", which was genuinely unanswered. |
| 2026-10-28 | **The proof pass learned to render at a device scale, which retired the last blanket disclaimer on the text rows.** `metal_proof` had `physical_size = logical_size, scale_factor = 1.0` hard-coded, so every real-provider pixel claim in this module was a 1× claim while the machines it ships on are Retina. `metal_proof_pixels` now takes `scale_factor~ : Double = 1.0` (logical `width`/`height`, device `width * scale` texels), which is the same metrics split the renderer has always used — NDC normalises by the logical size, scissors and pass transforms by the device size — so nothing but the proof pass changed. New suite evidence: `a proof frame at device scale two renders four times the texels` pins the buffer at 16×16 for a logical 8×8, reads a 4-logical-pixel box inked at device `(6,6)`, empty at `(9,9)`, and asserts the *same* stream at scale 1.0 is black at `(6,6)` — so the pair cannot both pass if the parameter is inert. Mutating the device dimensions back to the logical ones fails exactly that test (89/90) and nothing else, and the restore is checksum-verified. New smoke evidence through the real provider: colour survives the Retina raster — 🙂 6084 inked / 6018 green, the ZWJ sequence 8146 / 8049, noop control 0 for both — joining the size grid (24/32/48pt) and the layer-composite case added earlier today. Both rows then lost an untrue disclaimer rather than gained a claim: `EmojiText` no longer says Retina colour is unproven; it now says what is actually left, that the matrix is sampled and not covered (sizes and the group are read at scale 1.0, Retina at one run per sample), and that the trait decision is the provider's. `Text` keeps its measured-grid scope sentence. Neither moved off `Partial`. Interface: one defaulted labelled parameter on an existing public function — `pkg.generated.mbti` line count unchanged, `validate-api-surface` green at the 56-line budget. 90/90 tests, smoke green, `pr` to follow. |
| 2026-10-28 | **The text and emoji rows' evidence scopes stopped being guesses: the real-provider smoke now runs a grid, and the grid is proven able to fail.** Two `Remaining:` clauses claimed the same thing — "one run at a time on the main pass at 32pt and scale factor 1.0" — so the smoke grew into a grid rather than a sentence. `metal_emoji_smoke` walks 24, 32 and 48pt per sample (measured: the ZWJ sequence inks 576 / 1011 / 2290 with 571 / 993 / 2240 lighting green, and the pure-green run lights red in turn) **and** draws each through a layer composite (2098 inked, 2048 green, `layers` 1), with the noop control at zero in every case; `metal_text_capacity_smoke` became cells — (14pt, scale 1.0, 1600 glyphs) → 1 text item, (14pt, 2.0, 1600) → 2, (24pt, 2.0, 900) → 3, all with `text_dropped_glyphs` 0 — which is the per-page ceiling confirmed at a second size instead of restated at one. Non-vacuity, because a smoke that cannot fail is decoration: pinning `METAL_ATLAS_MAX_PAGES` to 1 makes the grid print `items=1 least=2 dropped=782` and abort with "a frame denser than one atlas page did not grow past it" — the same 782 the paging leg measured by hand, now a regression tripwire. What the rows now concede instead of the old blanket sentence, in both notes and both report matrices: read-back *colour* evidence stops at device scale 1.0 (`metal_proof` renders one logical pixel per texel, so Retina is covered by counters and by the module's fake-raster probes, not by real-provider pixels), and the capacity grid is two sizes and two scales, not every font and script. Neither row moves off `Partial` — the widened evidence removed a disclaimer, not a gap. 89/89, six validators, smoke green with and without the mutation, restore verified by grep; `pr` follows. Three MoonBit syntax lessons from writing it: a labelled optional parameter is named without `~` inside the body (`width=side`, not `width=side~`), `moon fmt` rewrites `size~=size` to the shorthand `size~` at call sites so hand-written patches must be re-read before being matched again, and a patch script must compute its replacement before opening the file — the third time this session that ordering mattered. |
| 2026-10-28 | **A blur radius that did not widen the blur: measured, then fixed at the same cost.** The separable kernel kept thirteen samples per axis one device pixel apart under a cap of `min(ceil(2*sigma), 12)`, so its *reach* was 12 pixels whatever the radius asked for, and growing sigma only flattened the weights. On device, a straight edge with `Blur(16.0)` read **255 sixteen pixels inside the edge (a Gaussian is at 214), 122 at the edge, and exactly 0 one sigma out** where the true value is 40/255 — a "radius 16" that blurred no wider than radius 6. The fix is one divisor: `stride = max(sigma / 6, 1)`, taps at `index * stride` pixels with weights `exp(-(index*stride)^2 / 2sigma^2)`, `support = min(ceil(2*sigma/stride), 12)` — same 13 samples, same cost, and the samples now span ~2 sigma at every radius. Measured after: 212 / 119 / 32 / 10 / 0 at -sigma, the edge, +sigma, +1.5 sigma and +2 sigma against the ideal 214 / 128 / 40 / 17 / 6. The residual is the discretisation the tap budget buys: the far tail reads ~20% low (+1 sigma 32 versus 40), which is now what the `FilterEffect` note names instead of the old truncation claim, along with 8-bit intermediate quantisation, no backdrop, and a blur that cannot spill past the group's own frame because that frame is the pass target. Test-first: `a large blur radius widens the falloff instead of flattening it` was written against the broken kernel and failed on the inside reading (255) before any shader changed, so the red is the record, not an afterthought; 89/89 green after, including the sigma-8 profile test, which the wider stride does not disturb. Also checked rather than assumed: the shadow half this task carried (a one-sided field over-brightening a shape thinner than its blur) is real but bounded — a 12-pixel mark at sigma 8 peaks at ~81% where the exact two-sided integral is ~54% — and it is left as a disclosed number in the row, because a two-sided rounded-rect integral would cost a further axis of tails per fragment, and this repo has no verified emitter for it — the claim that no view casts a shadow thinner than its blur is *not* checked, so it is not offered as a reason; the disclosed number is. |
| 2026-10-28 | **The `AsyncImage` host-evidence half was re-attributed — after my first two versions of it were wrong.** The row claimed a completion crossing a *presented* host's event channel was unmeasured "here", blaming this route's host wiring. Checking the seam produced three corrections in a row, each caught before it settled: (1) `window_image_task_starter_install` — the symbol I first grepped as `_set` — **does** have a production caller: `examples/momark/macos_skia/main.mbt:24` installs `@image_remote.remote_image_starter` and runs the worker as a sibling of the pump, so "no app installs a starter" was false; it is the only one that does (`macos_wgpu`, `linux_wgpu` and every in-repo app take the synchronous `immediate` default at `moui/backend/common/window_host_workflows.mbt:11`). (2) That starter defers `https:` sources only, and the app this route actually drives feeds `data:` URIs (`examples/showcase/app/diagnostics/formatting.mbt:129`) — so the queued follow-up "wire the deferred starter into `macos_metal` and observe the async completion" would have produced **no** async completion at all: local and inline sources complete synchronously under both starters. The task was closed as its own refutation rather than executed. (3) My replacement sentence said the module was "unpublished"; it is registered `publication: public` at `checks/release-modules.json:68` — what it is not is *released*, and `examples/momark` is a submodule pinned to released versions with no `macos_metal` variant, which is the actual blocker. The row now reads to that standard, with the ordering semantics credited where they are proven (`moui/backend/common/image/window_image_tasks_test.mbt:134,:176`, injected `spawn`/`post`), and the remaining half attributed to a release line plus a product choice rather than to renderer code. Two transferable rules, both from my own misses: a universal negative needs the right symbol (grep the definition first, then its callers), and "registered" is not "released" — check which one a claim needs. 88/88, six validators green, module code unchanged by the correction. |
| 2026-10-28 | **Two `Partial` rows had no missing half named, and the gate that claims to require one could not see it.** The tripwire in `metal_renderer_wbtest.mbt` enforced "a `Partial` row must explain the half that is missing" as `note.length() >= 60` — a check that cannot tell an explanation from a description. `Transform` (814 chars) and `Opacity` (715) passed on prose that named nothing missing, while the other nine rows buried their reasons mid-paragraph where nothing pointed at them. The convention is now machine-checkable: **every `Partial` note ends with a `Remaining:` sentence listing its gaps**, the gate collects every offending row and fails with their labels instead of one per run, and all eleven Partial rows carry it. The two halves that had never been written are now, from code rather than guesswork: `Transform` — because the stack reaches vertices only, anything measured as a *length* in the shape's own space (corner radius, stroke width, a shadow's blur band) is exact under uniform scale and rotation but cannot be right on both axes under a non-uniform scale or skew, which is also why `PushRoundedClip` declines its exact path there, and a rotated clip rect contributes only its axis-aligned bounds to the scissor; `Opacity` — because it is folded into each vertex colour rather than taken once per draw, a mesh that covers an area twice (a self-intersecting or multi-subpath fill) double-blends inside the overlap where Skia's save-layer dims once, and a group's opacity lands on the composite, inheriting `BlendMode`'s exact-only-over-opaque-destination half. A tempting third claim was checked and discarded: colour glyphs do *not* ignore opacity — the colour branch multiplies white by `state.opacity` (`metal_geometry.mbt:704`), so it would have been a false gap. A/B: stripping one marker fails the gate (87/88), restore is checksum-identical. 88/88, six validators green. One self-inflicted incident is on the record because it is a trap worth naming: a patch script written as `open(p, "w").write(s.replace(a, b, "1"))` truncated `capabilities.mbt` to zero bytes — Python opens (and truncates) before evaluating the argument, and the bad `str.replace` call then raised *after* the damage. The module is untracked, so recovery came from `_build/wasm-gc/release/format/.../capabilities.mbt`, the copy `moon fmt` had written a minute earlier. The rules it teaches: build the new text first, assert on it, and only then open the file for writing; and keep `_build` around until a change is verified, because it is the only copy of an untracked file that a bad write leaves behind. |
| 2026-10-28 | **`Shadow` was a slab, and it is now a bell — measured before and after, at no extra passes.** The row said "a soft-edge approximation, not a Gaussian convolution"; measuring the pixels said the sentence was too kind. With the box grown by `2*blur + spread` and the ramp spanning the last sigma, a 12-pixel mark at `blur_radius = 8` read back as **255 from eight pixels outside its left edge to seven past its right edge, then a 76-level drop in one pixel at the box rim** — a solid slab with a soft rim, not a shadow, and the reason no test had caught it is that the existing one only asked whether *some* ramp existed somewhere. The formulation is now the one a Gaussian actually leaves at a hard edge: coverage = `0.5 * erfc(d / (sigma*sqrt2))` over the rounded-box distance field, `d` measured from the shape inflated by `spread` (not from the box drawn around it — that distinction is one of the two mutations below), sigma = `blur_radius`, matching the mainline because `moui_skia_renderer` passes `radius` straight to `ImageFilter::blur`. `erfc` does not exist in this MSL build, so the normal tail is computed from Abramowitz & Stegun 7.1.26 (~1.5e-7, far under an 8-bit output); the quad grows `3*sigma + spread` so the tail reaches 0.13% inside the box rather than at its edge. No new pass, no new texture, no wire change: one extra `exp` and a few multiplies per shadow fragment, over a quad ~1.4x wider than before. The new device test asserts a **profile** — half-covered at the shape edge, ~16% at +1 sigma, under 10% at +2, monotone to +3, and no single-pixel step carrying most of the remaining ink — and the old test was rewritten to the same standard rather than kept as a witness. Two A/B runs, each aimed at one decision: restoring the old grown-box ramp fails **both** shadow tests; keeping the Gaussian but measuring `d` from the grown box fails only the new one, which is the clearest possible evidence that the previous assertion was too weak to notice a shadow anchored to the wrong geometry. Restores `shasum -c`-verified, 88/88 (module 87 → 88), six validators, 85 capability cells. Remaining halves named in the row, not smoothed over: the field is one-sided, so a shape thinner than its blur reads brighter at its centre than Skia's two-sided convolution (that same 12px mark peaks near 81% where the exact answer is ~50%), corners are the SDF's, and a path- or texture-filled source still casts its bounding box (a claim later corrected: `ShadowSpec` carries a `RoundedRect`, so no such shadow exists to cast — the residual is the corner falloff, see the row's note) — a true content blur would need the shadow drawn through the filter-pass machinery, which is a pass and a target per shadow. And one cross-route consequence, recorded rather than fixed here: Metal and `moui_wgpu_renderer` no longer agree on what a shadow looks like, and the wgpu note still claims the shared formulation, which is now the stale half of the pair — same shape of finding as its `clip_radius` row. |
| 2026-10-28 | **The route's blur was an echo, now it is a bell — and the fix came with two defect findings, one of them pre-existing.** The row had said "a 3x3 tap is not the Gaussian"; measuring said more. With taps at 0 and +-radius, a two-pixel mark blurred at radius 8 read back as 128, 128 at the mark, **six empty pixels**, then 64, 64 at +8 — the group replicated at +-radius, not softened, and no counter said so (`metal_proof`, not derived from the shader). The fix is separable, and the route already owned every part of it: the horizontal stage is one composite-role item, its target is an ordinary pass record — claimed **before** the group so the host's descending walk renders it after — two new filter-kind numbers stand in for the blur payload, and nothing about the vertex, the item row, the record layout or the host changes. A blurred group now reports `layers = 2` (the intermediate is a pass and is counted as one) while still counting a single `filter_approximations`; sigma is the radius, the same reading `moui_skia_renderer` gives `ImageFilter::blur(radius, radius)`, with taps at every device pixel to `min(2*sigma, 12)` and weights divided by their own sum. The new device test asserts a **profile**, not a value: light past the mark on both axes, non-increasing falloff in each, and no +8 sample out-shining the ones nearer the mark — the last clause is exactly what the old kernel failed. Then the second pass came back saturated, and localising it found a bug that predated this leg: the composite fragment's `else if (kind > 4.5)` was open **above**, so kinds 6 and 7 fell through into the colour-matrix branch, and `metal_identity_color_matrix` carried the numbers `moui_wgpu_renderer` ships — an identity for a `mat4x5f` indexed by column, not for this shader's row reads — so that "identity" mapped every channel onto red and forced alpha to red's value. Reachable today through `ColorMatrix` with fewer than 20 values, where the copy leaves the rest of the array as shipped. Both fixed (branch bounded at 5.5, identity row-major with each row's translation last), each pinned by its own test, and each shown to be load-bearing separately: the wrong identity fails one test on its green-channel pixel assert and leaves the bell green; re-running the horizontal axis instead of the vertical fails the bell's "no light below the mark" assert; disabling the blur branch fails the bell and the older softening test. Restores `shasum -c`-verified, 85 -> 87 module tests, six validators and 85 capability cells unmoved, `FilterEffect` still `Partial` for reasons that are now only about quality and backdrop (support truncated near 2 sigma, 8-bit intermediate quantises twice, no backdrop, un-premultiplied colour maths versus WGPU). Two process facts earned badly, kept because they transfer: an embedded-MSL `.h` can be rebuilt verbatim from the compiled `.o` (slice from `#include <metal_stdlib>` to the next NUL — a `strings` dump silently drops runs shorter than four characters, i.e. every `  }` line), which is how the file was recovered after a substring anchor matched the *wrong* `kind > 0.5 && kind < 1.5` and deleted a third of the shader; and in that literal form every MSL line needs its own `\n`, since a comment line without one concatenates with the next and can swallow a statement. |
| 2026-10-28 | **`EmojiText`'s last two named group halves closed — with the caveat written into the row rather than glossed over.** Two device probes (`metal_text_wbtest.mbt`, module 83 → 85): a colour glyph through a `LayerSpec` carrying `RoundedMask`, and one through two nested groups. The first is also the route's **first** device probe of that mask kind at all — `LayerMask::RoundedMask` had only ever been reached from inside `PushRoundedClip` (`metal_geometry.mbt:331`), never from a `PushLayer` a test wrote. Each probe is a pair, not a single claim: the rounded case asserts green at the deepest inside of the arc `(3,3)` and `(2,2)` **and** black at the inked corner `(0,0)` the radius must clear, so a composite that ignored the mask fails the corner while the colour asserts stay green; the nested case asserts the same three pixels **and** `report.layers == 2`, so it cannot pass on one composite. Status stays `Partial`. The honesty clause: all five group cases (plain, filter, rect mask, rounded mask, nested) share one mechanism — the colour branch is chosen at the vertex and the composite neither reads nor can re-tint it — so these widen the contexts in which the claim holds instead of proving a new path, and the note says that in those words. A/B twice, each with a different target: forcing the coverage branch (`placement.coverage_only || !placement.coverage_only`) fails 6 tests including both new ones at their pixel asserts, which is exactly the shared-mutation signature the note discloses; dropping only the rounded mask's kind (`RoundedMask → metal_mask_none`) fails 3, and the new test dies on its own message ("the corner the radius should clear is inked") — that second run is what shows the new probe is not the old probe in a costume. Restores `shasum -c`-verified, 85/85, six validators and the 85 capability cells unmoved; the row's note and both report `EmojiText` rows now carry the widened scope plus the remaining half (real-provider evidence beyond one run on the main pass at 32pt and scale 1.0, and the provider's trait decision). |
| 2026-10-28 | **`LayerCompositing`'s open half closed: `BeginRetainedLayer` boundaries are now kept across frames, on the pass pool the host already had.** `moui_metal_pass_target` holds one offscreen target per slot between frames and rebuilds it only when the size differs, so a boundary that claims the same slot at the same device rect in the frame *after* the one that painted it composites that texture instead of rebuilding its group: the hit pushes a pass record with `child_count = 0`, consumes the child stream without drawing it (`skip_metal_retained_scope`), and the host's pass loop gained exactly one branch — a childless record gets no encoder, because opening one clears the cached pixels. That branch is a no-op for every pre-existing stream, since an empty group releases its slot rather than shipping a record, and no wire format, vertex or shader changed. Three guards, one per failure mode: `content_revision` must match; `slot` + `device_x/y/width/height` must all match; the entry must come from the immediately preceding frame, because a pass target is not private to a boundary and anything that claimed the slot in a gap overwrote it. `retained_layers_cached` / `_rebuilt` / `_updated` / `_evicted` record which case ran — the four records the row's note said did not exist. The first version was wrong in a way only a four-frame device run could show: a hit did not re-stamp its entry, so a stable page aged out on its **second** hit and the cache saved one frame in two; re-stamping is sound because the hitting frame also claims the slot. Seven new tests (`metal_retained_wbtest.mbt`, module 76 → 83) — five device-free over the bookkeeping so they run on any host, two on the device — and the decisive pixel claim is deliberately stale: frame three keeps key and revision but asks for a green child, and the test asserts the pixel is still red, because a hit that painted what the current stream asked for would be indistinguishable from re-rendering it; its mirror (a revision bump arriving as green) and a grown-rect repaint are asserted in the same runs. A/B three times, patch landed before each read: deleting the host branch fails 1 test at its **pixel** assert (`metal_retained_wbtest.mbt:351`, red where the cleared target gives black) with every counter green; a hit that ignores the guards fails 4; a cache that never hits fails 5. Restores `shasum -c`-verified, 83/83. Cost: no GPU memory of its own (the pinned targets are the ones a rebuild would have allocated anyway), and the public surface grew by three fields of the one existing report struct — the module's interface budget moved 53 → 56 with its rationale in `tools/moui/validate_api_surface/main.mbt`, no new declaration or type. A stale test title went with it (`a retained layer rebuilds into its own pass every frame` → `a retained boundary with no frame before it rebuilds into its own pass`). Row stays `Partial`: this is the pool reused as a cache, not a picture or pixel cache, so an entry is valid for one frame at one slot and rect; fidelity is delegated whole to `content_revision`; entries are aged, never capped or prioritised, so no residency decision exists. Docs amended in place: the `LayerCompositing` note, both report rows, ADR 0045's retained-layer paragraph, and the plan's own L2c bullet, which had said the opposite. |
| 2026-10-28 | **The `Text` row's own disclosed gap closed: the glyph atlas is now a lazily-grown page set, not one fixed texture.** The gap was the sentence the note had been carrying since L3c — *"a frame whose own glyph set does not fit an empty 1024x1024 atlas still drops and counts"* — and clear-and-rebuild cannot recover it, because repacking into another empty page of the same size reproduces the same shortfall: such a frame lost its overflow **every** frame, and the only signal was a `text_dropped_glyphs` number. Shelf packing is monotone (a glyph is appended to the current shelf or the next), so within one run the page index never decreases and the run splits into contiguous vertex ranges, one text item per page, with the page named in the word the wire already had — `item[7]`, `texture_key`, which the image role reads as an image record and the composite role as a pass slot. That is the whole mechanism: the 76-byte vertex, the 9-int32 item and the MSL are untouched, and u/v stay page-normalized because every page is the same size. `METAL_ATLAS_MAX_PAGES = 4` bounds the worst case (16 MB staging + 16 MB texture); page 0 is allocated at construction and per-page `dirty` keeps a normal frame uploading one page, so a text-light route pays exactly what it paid before. Past the cap the clear-and-rebuild recovery is retained rather than replaced, and host page textures deliberately survive a clear until the context is released — freeing them there would rebuild a 4 MB texture on every frame of a document that keeps crossing the cap. Measured through the real CoreText provider on a 1,600-distinct-ideograph frame at 14pt and device scale 2.0: `items=2 dropped=0` now, against `items=1 dropped=782` with the cap pinned to one page — which independently confirms the ~818-per-page figure this plan had derived from a single run (1600 − 782 = 818). Two new tests and three retargeted ones (`metal_text_wbtest.mbt`, module 74 → 76): the new device probe asserts four pixels (both pages inked, the gap between them clean) rather than counters, and the retina-budget, clear-and-replace and cap tests now assert the page set as well as the boxes. A/B three times, each chosen to fail at a **pixel** assert rather than a counter, because a counter-only failure would not show that the page binding paints anything: binding page 0 always (`moui_metal_atlas_page(context, item[7])` → `context, 0`) fails only `metal_text_wbtest.mbt:529`; `METAL_ATLAS_MAX_PAGES = 1` fails 3 tests including `:530`; making the run-split condition unsatisfiable fails `:527`. All three restored and re-verified green. The alternative that looked cheaper per megabyte — splitting coverage by alpha depth, ~4x capacity — was rejected because selecting a page per glyph needs a new vertex attribute, i.e. the wire change this route buys by reusing a word that was already there. `Text` stays `Partial` with three named reasons (capped pages rather than per-glyph eviction; the measured ceiling; straight-alpha colour glyphs and a single engine behind the composition root); updated in `moui_metal_renderer/capabilities.mbt`, both capability report Text rows, `docs/text-system.md` (+ its zh mirror, a new direct-GPU section) and ADR 0045's decision 3, whose "4 MB … for the life of the renderer" is now the per-page figure. |
| 2026-10-28 | **`ShaderEffect` went from "every name falls back" to "the four builtins are drawn"** for the names `builtin_shader_names()` declares (`moui/render/common/advanced_execution.mbt:87`): `checker`, `solid`, `linear-gradient-debug` and `vignette` are now evaluated in the visual fragment, and only a name outside that list paints the spec's `fallback` brush and increments `shader_effects_fallback_painted`. No size change: the two slots of the 144-byte item record that were written as literal `0.0` (`edge.z`, `edge.w`) carry the kind and the amount, so the wire format, `metal_renderer.mm` and the record's 36 floats all stay as they were. Formulation was chosen per effect rather than copied wholesale — checker cells (`min(w,h)/amount`, square, measured from the frame origin) and vignette radii (`max(w,h)/2 * max(amount, 0.8)`, fading to black at the fallback colour's own alpha) follow `moui_skia_renderer` and `moui_sun_renderer`, **not** `moui_wgpu_renderer`, which normalizes each axis and so paints rectangular cells on a non-square frame and clamps the checker scale to a minimum of 8; `solid` instead follows wgpu's flat-`color0` reading while Skia answers that name with the whole fallback brush, so the two differ and the note says so. `uniforms[0]` is the only uniform read, defaulted per effect the way the mainline routes default it (8.0 cells, 0.8 radius). Four device probes (`metal_l2c_wbtest.mbt`, module 70 -> 74), each pinned against the fallback frame it replaced, and two existing pins retargeted to `name="glow"` because the behaviour they described changed. A/B twice, at two different layers: forcing `effect_kind` to `metal_effect_none` fails 4/74 and all four stop at their counter assert, so that run alone proved nothing about pixels; breaking only the CPU->MSL handoff (writing `0.0` into `edge.z`) then fails the same 4 at their **pixel** asserts with the counters still green, which is what shows the MSL branch produces the pixels and the shape blob is the carrier. Restored (mutation-marker grep 0), 74/74, six validators and 85 capability cells unmoved, real-device smoke unchanged at the same counts it reported before the change (2587 glyph pixels, 698/1011 emoji). Unlike the `Clip` row, this one is not a prospective cost: `examples/showcase/app/diagnostics/advanced_rendering_section.mbt:207-224` emits `checker` and `vignette` on every frame **of that section**, so wherever the app shows it the two builtins were being flattened. Scope stated precisely (same walk as the `LayerCompositing` finding below): no committed script launches `examples/showcase/macos_metal` at all, and its entrypoint passes no route, so its *first* frame is `Components/welcome` (`examples/showcase/app/workspace.mbt:84-86`) — the effects, like the repaint boundaries, arrive on navigation into a diagnostics section, not on the landing frame. |
| 2026-10-28 | **Outstanding verification closed, and the strong version of the claim was refuted before it shipped**: the `LayerCompositing` row's open half is **emitted for real** by this repo's own apps — `moui/runtime/paint_engine.mbt:134` turns `plan.repaint_boundary` into `with_repaint_boundary_cache()` (`render_tree.mbt:197`), which always produces a non-empty key (`:230-232`), and `render_tree.mbt:98` then pushes `BeginRetainedLayer(spec)` — with the app-side emitters at `examples/showcase/app/diagnostics/components.mbt:24,32,80` (every diagnostics section's scroll body **and** header). What did **not** survive the check is the sentence I had just drafted for the note, "already being paid on every frame of the evidence app": `examples/showcase/macos_metal/main.mbt` passes no route and no `initial_section_code`, `ShowcaseRoute::default()` is `Components/welcome` (`workspace.mbt:84-86`), the only `repaint_boundary()` calls in the showcase live in the diagnostics panels, and `grep -rn macos_metal scripts/ checks/` returned **nothing** at the time (since retired: `scripts/macos-metal-presentation-smoke.sh` now launches it as a `platform` step). So the honest scope is "live on the first navigation into a diagnostics section, not on the landing frame", and the note, both report rows and the `ShaderEffect` progress row above were corrected to say exactly that. Two things the walk turned up that are worth more than the correction: the committed cached-layer benchmark already drives that section (`benchmarks/app_cached_layer/native/main.mbt:376`), so a retained-layer cache leg has an existing instrument rather than needing a new one, and `key`/`content_revision` are already on the spec, so the cache needs no wire change to become possible. No status moved; `Text` and `LayerCompositing` stay `Partial`. |
| 2026-10-28 | **`Clip` stopped being an approximation for the shape most of the UI uses.** A `PushRoundedClip` whose arc the composite can still describe now opens the same offscreen pass a `LayerMask::RoundedMask` uses, so its corners are rounded by the existing SDF instead of being squared off by the bounding-rect scissor — no wire-format and no MSL change, because the composite already had the mask path and the scope machinery already had passes. Exactness has two preconditions, checked in `metal_exact_rounded_clip` (`metal_geometry_scopes.mbt`): the open transform must be axis-aligned with a uniform scale (a rotation or non-uniform scale makes the corners ellipses), and neither the parent clip nor the surface may shrink the rect (the composite rounds *the box it is handed*, so a shrunk frame would round the wrong corners). Where either fails the scope keeps the rect scissor and keeps incrementing `approximated_clips`. Three probes (`metal_state_wbtest.mbt`: "a rounded clip rounds the corner instead of squaring it off", "a rounded clip under a scale rounds at the scaled radius", "a rounded clip that cannot stay a rounded box is still counted"); two earlier pins changed because the behaviour they described changed (`metal_state_wbtest.mbt:197` moved from `approximated_clips = 1` to `0` and gained the corner-pixel claim; `metal_report_wbtest.mbt`'s empty rounded-clip group now reports nothing refused). A/B on the production change, not on the tests: forcing the bbox fallback makes 4 of 70 fail and the scale probe's own message becomes the evidence ("corner 255 is inside an unscaled radius-3 arc" where the exact path reads 13); restoring it returns 70/70. Cost recorded in the row's note rather than hidden, and measured first: one exact clip is one pass and one card-sized target, `report.layers` counts it, while nothing in this repo calls `push_rounded_clip` or builds a `RoundedClip` yet (its only emitter is `moui/views/controls/layout_helpers.mbt:77`), so no shipped frame pays that cost today, and the stencil mechanism that would be exact for *every* shape at no extra pass remains shared work with `moui_wgpu_renderer` (whose `Clip` row claims `supported` while `clip_radius` has no reader — see the cross-route finding below). |
| 2026-10-28 | **A second `AsyncImage` gap was found, then declined on evidence, and the note that claimed it was corrected.** The asymmetry is real: `SkiaRasterRenderer::dispose` marks every cached source `ImageDisposed` before clearing its cache (`moui_skia_renderer/renderer_image.mbt:630-634`) while `MetalRenderer::dispose` releases the context and leaves its records as they were. Mirroring it was rejected because no reader exists: `RendererSession::image_diagnostics` has no production caller (only `moui_tests/renderer_contract/renderer_contract_test.mbt:182`, `moui/backend/host_rendering_test.mbt:132`), and both host dispose paths are terminal — `window_frame_state.mbt:166-172` refuses further frames once disposed, `window_host_workflows.mbt:16` drops the session it just disposed. Same discriminator the L4 `recover` decision used (a path with zero callers prevents no real failure mode), applied this time to a change that would have *added* parity rather than capability. The earlier note edit had asserted "a shared-lifecycle policy the Skia route also does not exercise", which the Skia reading disproved; `capabilities.mbt`'s `AsyncImage` note now carries the verified asymmetry and the verified absence of a reader. Mid-session reclamation (`evict_disposed`, zero callers on both routes) stays the real open half. |
| 2026-10-28 | **L3's named `EmojiText` half closed, and one cross-route claim found on the way**: three device probes put a colour glyph inside a group (`metal_text_wbtest.mbt`, module 64 → 67) — plain layer composite, brightness filter, rect-masked layer — and all three pass, so the note's missing half is now the real-provider smoke's single size/scale, a rounded-mask or doubly-nested colour group, and the provider's colour trait. A/B twice (blit forced to coverage fails 3 including both new group cases, with the filter case naming "red channel 128 leaked the run colour"; mask dropped fails 5 including the new text case), restores `shasum -c`-verified, 85 capability cells unmoved. Same walk found the *opposite* asymmetry: wgpu claims `Clip` `supported` while its `clip_radius` (`moui_wgpu_renderer/native_visual_state.mbt:56-81`) has no reader and its scissor comes from the plain-`Rect` clip state — the same bounding-rect approximation this plan discloses as Metal's missing half. Left as a recorded open item (a claim change on another route, and the fix is one shared mechanism), not scheduled: L4's own gate — 17 rows from real probes, non-vacuous `recover`, `experimental` product class with its own ADR — is met. |
| 2026-10-28 | The **text half of "complete"** went from named to asserted: the route's paragraph/caret/selection/hit-test path is core's fallback over the injected provider, and no suite had ever run that combination (`moui_tests/text_conformance/native`'s only paragraph test drove `skia_text_system()`, which passes a native hook). Extracted `assert_diagnostic_native_paragraph_contract`, added a cosmic-backed case there (10 → 11) and a CoreText-backed one in `moui_text_providers/coretext` (22 → 23) — cosmic is cross-platform, so the contract this route leans on now holds on Linux and Windows CI, not just the darwin host. Renamed the stale `metal session reports the fallback text system until the text leg lands` to what it actually pins and replaced the missing wiring probe with `metal session gives the runtime the injected engine's text system` (module 63 → 64), whose fixture carries a caret table on purpose: the first attempt measured 8.8 where the provider said 6.0, because `is_valid_for_measure` rejects a caret-less layout and core's ~0.55em estimate then serves the widget while the painter uses the provider's placements. Both new paragraph cases fail when `fallback_paragraph_should_wrap` is made to never wrap, with the Skia case staying green; the wiring test fails alone when `text_system=` is re-pointed at the core fallback. Restores byte-verified. Registered `CoreText provider tests` (darwin) in the `platform` profile — nothing before it executed those 22 tests. Detail in "L4 text fidelity" above; no capability cell moved. |
| 2026-10-28 | The **capability table itself** went to the device: `metal_feature_probe_wbtest.mbt` (module tests 59 -> 63) probes each row's own minimum stream once and rejects a row whose label and pixels disagree — `Supported`/`Partial`/`HostForwarded` must ink, `Gap`/`Unavailable` must not, `probed == 16` is asserted so the walk cannot quietly shrink, and the single one-frame-exempt row (`AsyncImage`, two-frame lifecycle) is exempted by name with its premise re-asserted each run. A `Supported` row must also refuse nothing in its own probe (`refused_count()`). `BlendMode`'s probe moved from `Multiply` (correctly nothing over an opaque black clear) to `Screen`; the three text rows needed distinct rasters to distinguish anything. A/B-proven: `Rect -> Gap` fails the ink walk (64 pixels) and the notes test, `BlendMode -> Supported` fails the claim check (1 refusal), restore byte-verified by `shasum -c` then 63/63. Known scope limit as written then (the walk checked ink per row, not that each stream contains that row's op) was closed later the same day: `metal_probe_row_observed` now demands a measured consequence per row — see the Progress row above. |
| 2026-10-28 | L4's **real capability probes** started at the two rows that had none: `Transform` and `Opacity` reported `Partial` from a code reading while `PushTransform`/`PushOpacity` appeared in zero tests. Eleven device probes (`metal_state_wbtest.mbt`, module tests 48 -> 59) found and fixed two mis-draws on the first pass: `append_metal_box` culled against the clip with the **untransformed** rect, so a box a transform carried into a layer's masked frame drew nothing, and `metal_state_with_clip` clipped in the caller's space instead of the transform's, which `moui_wgpu_renderer/native_visual_state.mbt:48` does not — layer masks stay untransformed on both routes (`:185`). Both culls now read `metal_transformed_bounds`; the image op's identical test too. A/B-pinned three times (identity `transform_metal_point` fails 8 probes; each revert fails its own 1 and 2), with one false "passing revert" caught because `moon fmt` had re-indented the patched expression. Statuses unchanged; the notes now cite device-read pixels. `moon test moui_metal_renderer --target native` 59/59, capability validator 85 cells. |
| 2026-10-28 | **Decision:** a clip rect is transformed on push and a layer mask is not, on both native GPU routes. Reason stated while fixing the Metal divergence: a clip is a shape drawn in the caller's coordinate space, a mask names a rectangle on the surface, and the two must survive a transform differently or the same command stream paints two ways depending on the route. |
| 2026-10-28 | L4's vacuous-recovery item closed at the contract, not with an engine: `RendererSession::new`'s `recover~` default no longer returns `RecoverySucceeded` (A/B-pinned by a new `moui/render` test), and the macOS GPU promotion harness stopped writing `context_loss_done = context_loss_injected` when nothing recovered — `gpu_recovery_count()` is a constant 0 on every route, so `diagnostics.recoveryCount` in promotion artifacts had been counting injected losses as completed rebuilds. The lifecycle line gained `context_loss_injected=` and `recovery_count_after=`, and `gpu-performance-metrics.mjs` exposes `contextLossInjected`. A Metal device-loss rebuild was **not** built: `recover` has no production caller (all four call sites are tests) and `MTLDevice isRemoved` is unpolled — the reopen condition is in ADR 0045. `moon test moui/render --target native` 21/21, `moon test moui/backend/macos --target native` 49/49. |
| 2026-10-28 | L4 size motive **measured and recorded**, and it refuted the plan's own derivation: `macos_metal` release artifact 4,101,856 B (`__text` 3,527,568 / `__const` 339,584) against `macos_sun` re-measured the same day at 4,260,688 B under the same app and the same `-Wl,-dead_strip -Wl,-x`, i.e. the GPU route is 158,832 B *below* the figure this plan called the floor, with 171,436 B less `__text` than Sun's whole CPU rasterizer. Corrected in **Measured baseline** and in "The language floor, measured"; ADR 0044 amended in place with a pointer to the measurement, and ADR 0043's kill-reason wording left as the decision record it is (its numbers stand, its extrapolation does not); the substance is in ADR 0045 §"Amended 2026-10-28 (L4 size)". Boundary proof taken from the shipped binary rather than the package config: `otool -L` lists Apple frameworks only, `nm -a` returns 0 matches for skia/wgpu/`hal::`/vulkan and `strings -a` finds none. Honest limits: the two link flags are not committed (added for the measurement, reverted after), and `moui package macos` builds debug artifacts, so this is a release-binary number, not a packaging-gate one. |
| 2026-10-27 | L0.5 landed: `coretext`, `cosmic_text`, `directwrite`, `fontconfig` and `text_protocol` moved by `git mv` into the new published module `wzzc-dev/moui_text_providers` (`role: "binding"`, `releaseStage: "base-bindings"`, `0.2.2`), with `moui_wgpu_renderer/build.js` and the `--moonbit-unstable-prebuild` hook and the Cosmic/Swash pins travelling with them; `examples/showcase/*_wgpu` and `moui_tests/{wgpu_renderer_smoke,text_conformance}` were repointed (paths plus `@wgpu_*` → `@text_*` aliases) and the six static validators, `moon fmt --check`, the per-package tests and `check.sh --profile pr` are green. Verification detail, the two registrations the pre-move survey missed, and the pre-existing `daily` prebuild red this run surfaced are in the L0.5 block above. |
| 2026-10-27 | L0 opened (state since superseded by the rows below): no renderer code, no package registration, no ADR 0005 amendment yet. Plumbing facts re-verified from source (host `CAMetalLayer` export, `coretext` link flags, `native_text_model.mbt` ownership) — the extraction, not the writing, is the first real cost. |
| 2026-10-27 | Read the repo's own frame artifact and the MoonBit size floor: `presentMs` is measured against a no-op presenter on the forced raster route, the shipped `MetalGpuSurfaceRoute` has never been benchmarked, and a hello-world MoonBit native binary is 266,600 B. Added L0.4 (control measurement + fix the all-zero `buildMs`/`layoutMs`) and made it a kill gate. |
| 2026-10-27 | L0.4 measured: four present paths (`raster`, `metal-gpu`, `metal-gpu-host`, the new `metal-gpu-host-rotating`) × 3 interleaved rounds × 40 frames, 5 scenarios, through the committed budget runner. `drawMs`/`totalMs` emitted and gated (7 timing metrics now), `presentMs` given a real presenter, and the blit path's engagement asserted in-package because a failed `Surface::copy_from` silently degrades to a full redraw. Results in "L0.4 measured" above; the committed budgets cannot discriminate between any of these routes (0 of 140 ratios exceed 1.0). |
| 2026-10-27 | L0.3 fact sheet written into `THIRD_PARTY.md`: darwin link line (8 archives) vs delivered license texts (7 paths, HarfBuzz the only overlap), ICU/Skia root terms marked NOT CONFIRMED LOCALLY, `wgpu-native` v27.0.4.0-vs-v29.0.1.1 Windows pin split, Skia provider-vs-smoke-script pin split, and the license motive struck. No renderer code written; nothing registered. |
| 2026-10-27 | L0.2 landed: the native text model, layout validation, and the measure/layout caches moved from `moui_wgpu_renderer` to the new `moui/render/native_text` package (source: `text_model.mbt` 258 lines, `text_cache.mbt` 234, `layout_validation.mbt` 73, plus `text_model_wbtest.mbt` 258 carrying the 8 moved tests); `native_text_provider_engine.mbt` and `native_text_layout_validation.mbt` were deleted from the renderer, whose `native_text_model.mbt` fell 355→111 lines to atlas/vertex state only. All five native text packages plus `moui_tests/text_conformance/native` were repointed and no longer import the renderer root. |
| 2026-10-27 | L0.2 verification, all `--target native`, per package: `moui/render/native_text` 8/8, `moui_wgpu_renderer` 61/61, `text_protocol` 14/14, `coretext` 20/20, `cosmic_text` 23/23, `directwrite` 8/8, `fontconfig` 6/6, `moui_tests/text_conformance/native` 10/10 — 150 tests, 0 failures. All six pre-push static validators green, and `check.sh --profile pr` green at 198 steps / 1992 tests. `validate-maintenance-baseline` caught two stale line-budget entries pointing at the deleted renderer files; `native_text_glyph_atlas.mbt` (+3) / `native_text_rendering.mbt` (+13) / `native_text_model.mbt` (−244) were rebudgetted to 140 / 320 / 120 — the model's ceiling was tightened rather than left at 500, or the extraction would have been free to regrow. `moon fmt` was needed after the edits (the pr profile's format step diffs against `_build`, so an unformatted `moon.pkg` fails the profile). |
| 2026-10-27 | Coverage finding from the same run, stated because it is easy to misread: pr staying at **exactly** 198 steps / 1992 tests before and after a move of 8 tests is *not* evidence the move is covered — no check profile executed `moui_wgpu_renderer`'s tests at all, before or after (`grep` of `checks/profiles.json`: the module appears in no profile, and `moui_tests/text_conformance/native` runs only in `full`). `moon test moui/render` also does not reach the new sub-package, so the extracted model would have had zero automated coverage. Added a `native text model tests` step (`moon test moui/render/native_text --target native`) next to `render facade tests` in `pr` for that; the four provider packages and `text_protocol` stay outside pr because they are native-only with host stubs, and putting them in pr would make the pre-push gate host-dependent. |
| 2026-10-27 | L0.1 landed on the perf harness: `PerfFramePump` (`benchmarks/performance_budget/native/main.mbt:167`) replaces the raw `SkiaRasterRenderer` the scenario loop held, `perf_pump` dispatches on `MOUI_PERFORMANCE_PROVIDER` over three pumps (`perf_concrete_skia_pump` :300, `perf_neutral_pump` :320, chosen at :382), and `perf_runner_label` adds `native-skia-raster-via-provider` / `native-sun-raster` while leaving the four committed Skia labels byte-identical. `scripts/run-performance-budgets.mjs` gained `--provider` and a `gated = provider === "skia" && surfaceRoute === "raster"` condition, so control runs write `result-<provider>-<route>.json` and skip budget validation; the default (no flags, what CI `benchmark-scaffold` runs) is still the gated path, the gated artifact name, and the gated validator. |
| 2026-10-27 | L0.1 verification: the gated run still validates green (`artifacts/performance/result.json: ok (performance budgets)`, 60+12 frames), the `skia-neutral` A/B reproduces it within ±4% on `frameMs` p50 across all five scenarios with identical `cacheHitRate` — a band the next row shows is inside this runner's own repeat spread, so it certifies "no visible overhead" rather than a measured equivalence, and `native-sun-raster` produced the first non-Skia frame numbers in this repo's history (561 / 2192 / 84.5 / 8.7 / 655 ms `frameMs` p50) while passing every identity assert the neutral pump makes — provider id, `descriptor.presentation == CpuPixelFrame`, and `present_count == warmup + frames` per pump. The sun branch of the L0 kill gate is therefore closed, not merely untested. `moon check benchmarks/performance_budget/native --target native` clean; profile/format/validator consequences recorded in the next row. |
| 2026-10-27 | L0.1 format consequence, plus a third self-correction. `moon fmt --check` (a `pr` step) failed on the harness after the edits; `moon fmt benchmarks/performance_budget` regenerated the package's `_build/wasm-gc/release/format/` copy but **did not write the source back**, so only a project-wide `moon fmt` applied it. Re-formatting re-wrapped `perf_runner_label` and `perf_neutral_pump`, which shifted every `main.mbt` line citation in this plan, ADR 0043, ADR 0044 and `memories/repo/renderer-route-economics.md` by +1–2; each was re-checked against the file instead of trusted, and `docs/decisions/0043` also gained a pointer that its Option D instrument now exists. Then the gated `native-skia-raster` path was re-run — same code, formatting-only change — and **all five scenarios moved by +1.8% to +11.0%**, so the ±4% A/B in "L0.1 measured" sits inside this runner's own repeat spread. That claim was restated there (the A/B certifies "no visible overhead", not a measured equivalence) and the drift threshold raised from ~5% to ~10%. The sun verdict is untouched by the correction: 15–233× is 4–50× the noise band, and the gated run still validates `ok (performance budgets)`. |

## Acceptance

- [x] L0.1 harness runs the five scenarios through a `RendererProvider` and emits
      `sun` / `skia` / `wgpu` frame numbers under one runner-identity rule.
      **Met for `sun` and `skia`, not for `wgpu` (2026-10-27)** — and the criterion's
      `wgpu` clause was not achievable as written: wgpu's bind closure rejects any
      surface without a native handle (`moui_wgpu_renderer/binding_factory.mbt:25-27`),
      so its number requires a real window, which is a different instrument from
      this headless runner. Both measured halves are in "L0.1 measured" above, with
      the `skia-neutral` A/B establishing that the neutral pump is the same
      instrument as the concrete one (±4%, inside the runner's own repeat spread) before any
      non-Skia number is read. Two residuals stay on the record rather than inside
      the check mark: `benchmarks/app_cached_layer/native/main.mbt` is still
      concrete on purpose, and no neutral `RendererSession` accessor exposes
      unsupported commands, so a neutral session can certify *presentation*, not
      *completeness*.
- [x] L0.2 `coretext` and `text_protocol` no longer import
      `wzzc-dev/moui_wgpu_renderer`. **Met (2026-10-27)**, and met for all five
      native text packages (`coretext`, `cosmic_text`, `directwrite`,
      `fontconfig`, `text_protocol`): none of their `moon.pkg` files lists the
      wgpu renderer root any more, and `moui_tests/text_conformance/native` no
      longer imports it either. The criterion is *type*-level, which is what the
      bullet asked for; it does not by itself relocate the packages, so the
      module-level reuse-blocker described below this list is narrowed but not
      closed.
- [x] L0.3 `THIRD_PARTY.md` names each engine's license, or the license motive is
      struck from the record. **Motive struck** — everything locally confirmable
      is permissive; the gap is missing notice texts (Skia root, ICU), recorded as
      NOT CONFIRMED LOCALLY rather than guessed.
- [x] L0.4 the same scenarios measured through the already-shipped Skia-Metal
      route, with a real presenter and non-zero `buildMs` / `layoutMs`, so the
      renderer-attributable slice is separated from the retained-tree slice.
      Done; the criterion's premise was wrong in one respect — `buildMs` /
      `layoutMs` were already honest (they are only timed when the matching dirty
      flag is set), and the genuinely missing instruments were `drawMs` /
      `totalMs`, now emitted and gated.
- [x] L0.5 the five text providers live outside every `moui_*_renderer` module, so
      a new renderer can inject one without importing another renderer.
      **Met (2026-10-27)** as `wzzc-dev/moui_text_providers`, and the gate that
      decides it (`validate-release-module-closures`, P14) is green with the row
      registered `role: "binding"`. What this does *not* buy: a Metal frame. It
      removes the structural blocker, nothing more — L1 is still the one that has
      to produce the zero-Skia/zero-wgpu artifact.
- [x] L1 release artifact shows no Skia/wgpu symbols (`otool -L`, `nm`, `strings`)
      and ≤40 hand-written externs.
      **Met (2026-10-27)** on the debug artifact at 0/0/0 matches and 6 externs;
      the *release* artifact has not been sized, so the size motive this route
      exists to price is still unmeasured. See the L1a–L1c delivery block.
- [ ] L2–L4 `DrawCommand` honesty, one text-fidelity copy, real capability probes.
      **Two of three met outright; the third is met for the path this route runs and
      not repo-wide (2026-10-28).** Honesty: all 26 `PlanOp` variants draw or count,
      and the table is now checked against the device instead of against the docs
      ("L4 capability-row walk"). Real capability probes: 16 of 17 rows put through
      a Metal pass, the 17th exempted by name with its premise re-asserted each run.
      One text-fidelity copy: the engine-backed paragraph contract this route's text
      widgets actually run through is pinned inside the shared
      `moui_tests/text_conformance/native` suite plus the CoreText package's own
      tests ("L4 text fidelity" above), so this route adds no copy of its own — but
      Skia, Sun and the emoji smoke each still keep a text suite, so the criterion
      read as "one copy in the repository" is not met, and read as "this route
      duplicates nothing" it is.

L1 and L2–L4 are **not** blocked on evidence — the L0 kill gate fired, so they are
out of scope until the size + autonomy motive is re-priced. L0.1 (provider-
parametric harness) is delivered and outlives this route regardless of its fate: it
is the harness every future route decision needs, and it is now the only way a
candidate renderer can be measured on this repo's own apps. L0.2 is done and was the
prerequisite for any
of them to draw text at all; what it narrowed rather than closed was the module
location. Before the extraction, reusing native text meant depending on a module
whose root package links `Milky2018/wgpu_mbt`. After it, the data model, the
validation and the caches lived in `moui/render/native_text` (which imports only
`wzzc-dev/moui/core`), while the five provider packages themselves still lived
*inside* `moui_wgpu_renderer/` (`moui_wgpu_renderer/coretext/moon.pkg`,
`moui_wgpu_renderer/text_protocol/moon.pkg`) and three of them still imported the
sibling `wzzc-dev/moui_wgpu_renderer/text_protocol`. So a compliant route could
build a text engine without the wgpu renderer's *types*, but consuming the
`coretext` provider still meant depending on the diagnostic wgpu *module*.
`wzzc-dev/moui` itself does not import that module (only a doc mention at
`moui/render/renderer.mbt:18`), so this was a reuse-blocker, not a
release-closure violation. Relocating the provider packages was its own structural
decision — it touches `moon.work`, `checks/release-modules.json`, and every
consumer's import path — and it is not part of L0.2's criterion. **That decision
is L0.5 above, and it closed the module-level blocker on the same day.**
