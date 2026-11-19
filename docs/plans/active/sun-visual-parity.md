# Plan: Sun visual parity with Skia

- **Status**: active
- **Goal**: Drive the Sun CPU renderer's perceived visual output on Linux to
  Skia parity — 60-cell control-state matrix average pixel error ≤3%, worst
  cell ≤10% under the perceptual metric below, Showcase first screen without
  bitmap-looking text, clipped glyphs, or jaggies — and keep it there with a
  reproducible comparison gate that blocks regressions.
- **Non-goals**:
  - Pixel-exact parity. Anti-aliasing/hinting/rounding differences are
    expected and accepted; only perceived similarity is targeted.
  - Changing Sun's product positioning. Sun stays an experimental renderer:
    not selected by `auto`, not registered in default composition roots, and
    no performance promises (ADR 0023, which this plan only annotates with a
    visual goal).
  - macOS/Windows visual-parity gates. Linux is verified first; other hosts
    follow only after the Linux loop is stable.

## Acceptance

- [x] 60-cell matrix (`6 controls × 5 states × 2 schemes`) generated from the
      same baseline with `--renderer sun` and `--renderer skia` reports
      average ≤3% and worst ≤10%.
- [x] Showcase first screen screenshot passes human inspection: no bitmap
      glyphs, no clipped text, no jaggies.
- [x] `scripts/visual-parity-gate.mjs` reproduces the baseline numbers and
      fails on threshold breaches (exit 1 without `--report-only`; self-test
      covers metric and invalidity paths); the `visual` check profile registers
      it as a blocking Linux step.
- [x] Sun remains experimental (`auto` unchanged, no default composition root
      registration); ADR 0023 carries the bounded parity addendum.

## Measurement contract

Perceptual metric per cell: for every pixel take the maximum absolute
difference over the R/G/B channels, average that over all pixels of the cell,
then normalize by 255 into a percentage.

```sh
node scripts/visual-control-matrix.mjs --renderer sun --out artifacts/vm-sun
node scripts/visual-control-matrix.mjs --renderer skia --out artifacts/vm-skia
node scripts/visual-parity-gate.mjs --sun artifacts/vm-sun --skia artifacts/vm-skia
```

The gate additionally reports, as a diagnostic only (never a threshold), the
share of pixels with any non-zero channel difference ("any channel off-by-one
counts as different"). Artifacts stay local under `artifacts/` and are not
committed.

## Baseline (2026-11-19, Linux, `sun` at `cb7287a` + gates fix `d32b7a9`)

`d32b7a9` (upstream dev, parented exactly on `cb7287a`) is cherry-picked to
clear the p5-merge standing findings that made `validate-api-surface` and
`validate-maintenance-baseline` red; it touches only governance data, docs and
the p5 example split, and the matrix numbers below are re-measured unchanged
after it. The later dev restructuring (`cef7842`, `137e6d3`) is not pulled in
yet — it changes the build/CI layout and would force a fresh Skia-prebuild and
baseline setup.

| Cell group | Avg | Worst |
|---|---|---|
| 60 cells | 7.93% | 19.72% (`checkbox/dark/focused`) |

Top offenders at baseline: `checkbox/dark/focused` 19.72%,
`checkbox/dark/default` 19.69%, `checkbox/light/focused` 19.01%,
`checkbox/light/default` 18.98%, `checkbox/dark/hover` 18.66%. Best cells are
slider rest states at ~0.01–0.03%. Diagnostic changed-pixel share: 20.89%.

## Stages

1. **Branch + baseline + gate** — push `sun`, add
   `scripts/visual-parity-gate.mjs` with self-test, re-record both matrices,
   register the gate in the `visual` profile as report-only.
2. **Font discovery + vector text** — resolve real font files on Linux and
   render glyphs as vector outlines instead of the current fallback.
3. **Shape anti-aliasing** — coverage-based AA for rounded rects, borders and
   icons.
4. **Shadow/gradient/filter feel** — blur quality, gradient dithering, layer
   composition.
5. **Showcase + blocking gate** — tune the Showcase first screen, switch the
   profile entry from report-only to blocking.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-19 | Metric fixed to per-pixel max-channel absolute difference normalized by 255, averaged per cell; average/worst thresholds 3%/10%. Pixel-identical output is explicitly out of scope. |
| 2026-11-19 | Gate enters the `visual` profile as `--report-only` in stage 1 so it cannot block while the parity work is in flight; stage 5 flips it to blocking. Caveat for stage 5: the `visual` profile disables the Skia prebuild, so a host without Skia prints `skipped` and exits 0 by the same convention as the control-preview/gallery-screenshot steps; a blocking gate therefore needs a Skia-capable job (fetch the release prebuild there) or must stay non-blocking on Skia-less hosts. |
| 2026-11-19 | Upstream `d32b7a9` cherry-picked (`-x`) onto `sun` to clear the p5-merge standing findings instead of moving the branch to the restructured dev tip (`cef7842`, `137e6d3`), which would invalidate the recorded baseline and the local Skia prebuild setup. |
| 2026-11-19 | `--generate` renders Skia first and fails fast with `skipped` on hosts without it, so a Skia-less run does not spend a full Sun matrix first. |
| 2026-11-19 | Stage 3: rounded rects and their strokes rasterise through analytic row coverage (`sun_shape_coverage_steps` = 16 vertical samples per row, exact horizontal spans) instead of the generic 4x4 point grid, which only offers 17 alpha levels. The fast path applies only to axis-aligned uniform-scale transforms; rotated/skewed canvases and dashed strokes keep the generic path. |
| 2026-11-19 | The miter join test in the generic stroker is bounded by the miter length `half_width / sin(half the interior angle)`. Unbounded, its two offset-edge slabs also accept points far along a nearly straight join, so every flattened curve joint painted a strip that made stroked curves about 0.5 px fatter than the same shape filled. |
| 2026-11-19 | The two rounded-rect helper/parity tests compare through `assert_pixmaps_match_within_sampling`: solid pixels must be identical (that is the geometry assertion), partially covered edge pixels get a 24/255 budget because the helper and the generic path probe the same outline with different sampling grids (measured worst case 16/255). |
| 2026-11-20 | Stage 4: `PositionedGlyph.x` is documented as "pen + left side bearing" (the caret test pins it), while glyph outlines already carry `xMin`. The rasteriser, SVG outline and atlas paths were adding the side bearing a second time, which shifted every glyph by one logical pixel at scale 2 (ink started at device 60 vs Skia's 58). All three now position from the pen origin; `PositionedGlyph::get_origin_x()` is the new read-only accessor (the atlas path lives in another package, so the field needs a public getter). |
| 2026-11-20 | Stage 4: `PaintShader` geometry is canvas (user) space, not device space. Coverage and image paths sample shaders through `Canvas::sample_paint_color`, which maps the device sample point back through `transform.inverse()` before sampling. Gradients therefore keep their logical length at any DPR and follow any affine transform (radial/conic become ellipses automatically). |
| 2026-11-20 | Stage 4: blur and shadow geometry are DPR-aware. Sun rasterises layers and shadow pixmaps in device pixels, so filter/backdrop blur radii scale by `scale_factor` (Skia image-filter sigma is local-space), while the shadow mask-filter sigma is device-space and stays unscaled. Shadow size/spread scale, and the blit position comes from the canvas transform; before this a DPR=2 surface painted the shadow at half size and half offset. |
| 2026-11-20 | Stage 5: the `visual` profile parity step is blocking (no `--report-only`) and keeps `--generate`; it uses the default `artifacts/vm-sun` / `artifacts/vm-skia` directories and the 3%/10% thresholds. A blocking gate must not pass by skipping: when `--generate` cannot find Skia it now exits 1 unless `--report-only` is set, so a host without a Skia reference is visibly red instead of silently green. |
| 2026-11-20 | Stage 5: the gate is Linux-first. `checks/profiles.json` marks the parity step with `"host": "linux"`, and `ci.yml` gains `dev` in `pull_request.branches` plus a `ubuntu-24.04` `visual-profile` job. check.mjs keeps its default `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1`, because the committed control-preview and gallery-screenshot checks are macOS-glyph artifacts and are stale on a Skia-capable Linux host (the profile is expected to print `skipped` for them). The blocking parity step itself opts into `MOUI_SKIA_DISABLE_PREBUILD_SKIA=0` for its two matrix children, so CI fetches the locked release Skia (cached between runs) and really compares; the macOS runner never judges the Linux visual gate. |
| 2026-11-20 | Stage 5: Showcase screenshots are captured from a real X11 run of `examples/showcase/linux_sun`, not from a throwaway offscreen package. `scripts/capture-showcase-sun.sh` runs the app under `xvfb-run`, waits for the `MoUI Showcase` window and saves the window rectangle with `scrot`; `MOUI_SHOWCASE_SECTION_1` / `MOUI_SHOWCASE_SECTION_2` (the existing `@showcase.env_flag` hook) select Advanced Rendering and Accessibility Probe. |
| 2026-11-20 | Stage 5: the golden pixel baselines `solid_and_rounded_rects` and `linear_gradient` are updated to the current Sun hashes (`961543285849148029` and `3090617638251390686`). Both moves are intentional stage-3/4 changes — analytic rounded-rect row coverage and canvas-space gradient sampling — and were visually covered by the stage-3 corner crops and the stage-4 gradient zoom; `clip_transform_opacity` and `path_fill` stayed unchanged. Without the update the `visual` profile's golden step is red, which would make the new blocking CI job red for a stale baseline rather than a parity regression. |
| 2026-11-20 | Stage 5: the two known gaps are documented in the PR as limitations rather than fixed here. `draw_text` overflow wrapping in Sun versus clipping in Skia is a layout-policy difference with many public `moui_sun/text` tests, and it does not enter the matrix or the first-screen acceptance; the Renderer Smoke image placeholder only affects the offscreen screenshot path, while the stage-5 screenshots come from the real run where image loading is active. |
| 2026-11-20 | Stage 4: the Skia build used here paints `DrawShadow` with no blurred falloff (a synthetic DPR=2 probe steps `255 -> 153` across a single pixel at the shadow edge; either the prebuild lacks `MOUI_SKIA_HAS_MASK_FILTER` or `saveLayer` does not apply the mask filter). Sun keeps the three-pass box blur (support `3 * radius`, no banding), so shadow parity is judged by position, size and softness, not by pixel equality with that reference artefact. |

## Progress

| Date | Note |
|------|------|
| 2026-11-19 | Stage 1: `sun` pushed to origin; gate script + self-test (15 checks) added; cherry-picked `d32b7a9` (six static validators PASS, `moon check` exit 0, check-profile catalog PASS); baseline re-measured unchanged (7.93%/19.72%, changed-pixel share 20.89%); `visual` profile step registered report-only and the full profile run exits 0 with the gate skipping cleanly on this Skia-disabled host (golden 4/4, gallery 3/3). |
| 2026-11-19 | Stage 2: font discovery, platform faces resolved by CSS weight, and the offscreen screenshot toolchain hands the renderer text system to the runtime so layout and paint agree. 60-cell matrix avg 3.19%, worst 8.37% (`checkbox/dark/focused`); text-only cells 0.45-4.08%; Showcase first screen Sun-vs-Skia avg 1.445%, no bitmap glyphs, no clipped text. |
| 2026-11-19 | Stage 3: analytic row coverage for rounded-rect fill/stroke, miter-join bound in the generic stroker, and single-line text centred on the face ascent/descent box. 60-cell matrix on a frozen tree avg 2.09% (limit 4.0%), worst 6.33% `checkbox/light/focused` (limit 13%); the 30 checkbox/radio/toggle cells are 0.79-6.33%, all under the 8% per-cell line; 60 cells + 22 transitions, no missing styles; corner, ring, focus-ring and rail crops show only 1-2 level edge differences, no jaggies. Glyph masks still use the 4x4 grid; the adaptive glyph-mask sampler measured neutral in an A/B (50 cells changed pixels, gate unchanged) and is not part of this stage. The residual on checkbox labels is dominated by a one-logical-pixel horizontal phase offset of the text origin (ink starts at 60 device px against Skia's 58), not by edge coverage; left-shifting Sun text by that pixel takes checkbox from 6.65% to 3.42%. That is carried into stage 4. |
| 2026-11-20 | Stage 4: text placement now uses the pen origin (no double side bearing), shaders sample in canvas space, and blur/shadow geometry scales with DPR. 60-cell matrix on the frozen tree avg 1.23% (limit 3.5%), worst 2.63% `text_field/light/default` (limit 10.5%); 60 cells + 22 transitions, no missing styles, changed-pixel share 11.66%. Showcase at 2160×1440: Welcome first screen 1.036%, Advanced Rendering 0.973% (1.332% before the gradient fix), Accessibility Probe 0.84%; radial-gradient card region 0.093%, filter card region 0.481% → 0.259% after DPR blur; a DPR=2 shadow probe shows a smooth 3-pass falloff with no banding. First-screen render 33.9 s vs the 41.5 s stage-3 baseline (debug native, 1080×720, DPR 2) = 0.82×, inside the 1.2× line. `moon check` clean; `moui_sun_renderer` 124/124. Known gaps outside this stage: the Showcase image source still paints Sun's placeholder in the offscreen screenshot path, and overflowing `draw_text` wraps in Sun's layout where Skia clips at the frame edge. |
| 2026-11-20 | Stage 5: the `visual` parity entry is blocking and Linux-only. The gate no longer skips on a missing Skia reference (exit 1 without `--report-only`), and the blocking step forces the locked release prebuild for its two matrix children while the rest of the profile keeps the prebuild-disabled default (so the host-pinned control-preview and gallery-screenshot checks print `skipped` on Linux instead of going stale). `ci.yml` now triggers pull requests to `dev` and runs the whole `visual` profile in a `ubuntu-24.04` job after `set_linux_deps.sh`; the parity check is a red check on dev PRs. Tightening the gate to `--max-avg 1` exited 1; restoring 3/10 exited 0. Final standard-directory gate: 60 cells, `avg 1.23%` (limit 3.00%), worst `2.63% text_field/light/default` (limit 10.00%), 22 transitions, no missing/blank, exit 0; diagnostic changed-pixel share 11.66%. `node scripts/check.mjs --profile visual` exits 0 (parity PASS, golden 4/4, gallery app 3/3; previews/gallery skipped by the documented host rule). Real X11 Showcase screenshots at 1100×680 via `scripts/capture-showcase-sun.sh`: Welcome `artifacts/showcase-real/sun-0.png`, Advanced Rendering `sun-1.png`, Accessibility Probe `sun-2.png`; visual inspection shows no bitmap glyphs or jaggies and no clipped text on the first screen. Local checks: `moon check` clean, `moon fmt --check` clean, `moui_sun_renderer` 124/124, `examples/showcase/app` 17/17; static validators green except `validate-renderer-capability-consistency`, which cannot compile the Metal `.mm` stubs on this Linux host (`cc1objplus` missing). Known gaps documented in the PR: Sun `draw_text` overflow wraps where Skia clips (Renderer Smoke card), and the Renderer Smoke PNG data URI still paints a Sun placeholder. |
