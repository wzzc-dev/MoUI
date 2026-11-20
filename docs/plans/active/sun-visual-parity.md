# Plan: Sun visual parity with Skia

- **Status**: active
- **Goal**: Drive the Sun CPU renderer's perceived visual output on Linux to
  Skia parity — 60-cell control-state matrix average pixel error ≤3%, worst
  cell ≤10% under the perceptual metric below, Showcase first screen without
  bitmap-looking text, clipped glyphs, or jaggies — and keep it there with a
  reproducible comparison gate that blocks regressions. Linux is complete;
  **Phase 2 extends the same bar to Windows**, starting from a measured
  baseline and closing the host gaps (system font discovery first).
- **Non-goals**:
  - Pixel-exact parity. Anti-aliasing/hinting/rounding differences are
    expected and accepted; only perceived similarity is targeted.
  - Changing Sun's product positioning. Sun stays an experimental renderer:
    not selected by `auto`, not registered in default composition roots, and
    no performance promises (ADR 0023, which this plan only annotates with a
    visual goal).
  - A macOS visual-parity gate. Linux and now Windows are the measured hosts;
    macOS stays deferred until it has its own evidence route.

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

## Phase 2: Windows parity

Windows is the second measured host. Sun runs through the lab route
`examples/showcase/windows_sun`, while the 60-cell matrix and the gate are
host-agnostic, so the same comparison runs on Windows against a Skia reference
built on the same machine.

### Baseline (2026-11-20, Windows, `sun` branch)

```sh
node scripts/visual-control-matrix.mjs --renderer sun --out artifacts/vm-sun-win
node scripts/visual-control-matrix.mjs --renderer skia --out artifacts/vm-skia-win
node scripts/visual-parity-gate.mjs --sun artifacts/vm-sun-win --skia artifacts/vm-skia-win
```

The Skia reference was built from the locked release provider
(`dev-6d73578a36`, `windows-Release-x64-static`). It printed
`SkLoadICU: datafile ... icudtl.dat is missing`, so its Latin labels were shaped
through DirectWrite without ICU data; stage 9 stages `icudtl.dat` next to the
matrix executable before claiming non-Latin coverage.

| Step | Avg | Worst | Diagnostic changed-pixel share |
|---|---|---|---|
| before Windows font discovery | 7.41% | 17.67% (`checkbox/dark/focused`) | 20.00% |
| after Windows font discovery | 1.57% | 5.04% (`toggle/light/focused`) | 11.73% |
| after font discovery, through `windows-platform-evidence.sh` with `icudtl.dat` staged | 1.52% | 4.00% (`checkbox/dark/pressed`) | 11.60% |
| after the Windows symbol face (payload v3) | 1.04% | 2.30% (`checkbox/dark/pressed`) | 11.01% |

Before the fix every label painted placeholder glyphs (a blocky `PRIMARY`);
`moui_sun_renderer` had no Windows face query, so
`sun_default_platform_font_faces` only offered the bundled macOS paths, which
do not exist on Windows. After the face query `toggle` was the worst group
(≈5.0%) and `checkbox` the next (≈3.2%). The symbol face is what closes most of
the remaining checkbox gap: the checked box paints `DrawText("✓")`, U+2713 is
not in the text families, and Sun without a symbol face drew the .notdef box
while DirectWrite fell back to Segoe UI Symbol. With the face registered,
`checkbox` drops to 1.95–2.30% and `toggle` to 0.9–1.3%; text cells stay below
1.7% and slider ≤0.06%.

### Acceptance

- [x] Windows baseline recorded before any change: avg/worst, top offenders,
      and the placeholder-glyph cause.
- [x] Windows system font discovery resolves Segoe UI, Consolas and Times New
      Roman from `%WINDIR%\Fonts` through the existing weight buckets;
      the button cell now draws real Segoe UI outlines instead of placeholders.
- [x] Windows matrix average ≤3% and worst ≤10%: 1.57% / 5.04% after face
      discovery, 1.04% / 2.30% after the symbol face (both gate PASS).
- [x] Windows symbol coverage: the payload carries a `symbol` role and the
      native stub registers `Segoe UI Symbol`, so a check mark or arrow the text
      families do not cover draws its outline instead of the .notdef box; the
      face is reachable through its own family only, so body text still resolves
      to Segoe UI.
- [x] Windows parity step recorded by `scripts/windows-platform-evidence.sh`
      (60 cells, gate PASS — 1.04% / 2.30% with the symbol face, `icudtl.dat`
      staged next to the matrix executable) and the weekly
      `moui-windows-platform-evidence` workflow surfaces `visual_parity_status`
      in its job summary.
- [ ] Windows parity step flips from report-only to blocking after CI
      reproduces the local 3%/10% numbers (stage 9 remainder).

### Stages

6. **Windows baseline** — done 2026-11-20: 7.41% / 17.67% before the font fix,
   confirming the matrix tool and the Skia prebuild work on Windows.
7. **Windows font discovery** — done 2026-11-20: the native payload producer
   enumerates Segoe UI (100/300/400/600/700/800), Consolas (400/700) and Times
   New Roman (400/700), with Arial/Georgia/Courier New as per-role fallbacks.
   That stage kept the payload at version 2, so no decoder change was needed;
   stage 8 adds the symbol role and bumps it to version 3.
8. **Windows fallback coverage (started)** — done 2026-11-20: a `symbol` role
   carrying `Segoe UI Symbol` (`%WINDIR%\Fonts\seguisym.ttf`) puts the
   DirectWrite fallback face into Sun's fallback stack, so U+2713 and other
   symbols the text families lack draw outlines instead of the .notdef box.
   The payload moves to version 3 (`role 3 = symbol`), the decoder rejects
   version 2, and the symbol face registers under its own family only. Matrix
   after the change: avg 1.04% / worst 2.30%, now better than Linux
   (1.23% / 2.63%). Remaining stretch: checkbox ring/text phase and toggle
   geometry residuals, and `550`-style weight requests against DirectWrite's
   nearest-bucket rule.
9. **Windows gate + evidence** — recorded 2026-11-20: the script builds
   `moui_tests/visual_matrix` once, stages the release `icudtl.dat` beside it,
   runs both 60-cell matrices and the gate, and writes
   `visual_parity_status`/`visual_parity_enforcement` into the evidence summary.
   The step stays report-only (`--parity-blocking`, or
   `MOUI_WINDOWS_VISUAL_PARITY_BLOCKING=1`, opts into a red run) until the
   weekly Windows job reproduces the local numbers (1.04% / 2.30% after the
   symbol face); blocking follows only after that reproduction.

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
| 2026-11-20 | Phase 2: Windows is measured on the same host as its Skia reference, with the locked release provider (`dev-6d73578a36`). The missing `icudtl.dat` warning is recorded as a limitation of the reference for non-Latin shaping; the ASCII matrix labels still shape through DirectWrite, so the 60 cells remain comparable. |
| 2026-11-20 | Phase 2: the Windows face query lives in the existing native stub instead of a new `moon.pkg` link dependency. It builds paths from `GetWindowsDirectoryW` and returns the same version-2 payload, so no MoonBit decoder or package-config change was needed; the producer symbol is now `moui_sun_platform_font_payload` (was `moui_sun_linux_platform_font_payload`). |
| 2026-11-20 | Phase 2: Windows weight buckets map Segoe UI Light to both 100 and 300 (the family has no ExtraLight), Semibold to 600, Bold to 700 and Black to 800. The per-path face cache keeps the duplicated Light entry cheap, and the existing non-distinct-weight filter only compares against the regular (400) path, so Light is still registered once per weight key. |
| 2026-11-20 | Phase 2: with the thresholds met after font discovery, stage 8 stays a stretch target rather than a gate blocker. DirectWrite resolves a `550` request to the nearest heavier bucket (600 Semibold); Sun's fontconfig-derived bucket table currently resolves it to 400, so a Windows-specific CSS nearest-bucket rule is the first stage-8 candidate once the worst cells need further tightening. |
| 2026-11-20 | Same branch: the softbuffer Win32 presenter is restored to GDI `StretchDIBits` with RGBA→BGRA conversion and surface→client rect scaling for partial presents. `scripts/windows-platform-evidence.sh` runs `moon test moui_sun/softbuffer --target native` as step 0, because `moon build` on that library package tries to link an executable with no `main`. |
| 2026-11-20 | Stage 9: the parity step runs inside the evidence script in report-only form. It builds `moui_tests/visual_matrix` once, copies the release provider's `icudtl.dat` next to the executable (SkLoadICU only searches the module directory), runs the Sun and Skia matrices into `<log-dir>/visual-parity/`, and records `visual_parity_status` plus `visual_parity_enforcement` in the summary. `--parity-blocking` (or `MOUI_WINDOWS_VISUAL_PARITY_BLOCKING=1`) is the only way to make a threshold miss red, so the weekly job reports numbers instead of blocking until it reproduces the local numbers (1.52% / 4.00% then, 1.04% / 2.30% after stage 8's symbol face). Matrix paths go through `cygpath -w` because Git Bash paths such as `/c/...` would be read by node's `path.resolve` as `C:\c\...`. |
| 2026-11-20 | Stage 8: the Windows text stack had no symbol fallback face, so `DrawText("✓")` (U+2713 — the checkbox and toggle check glyph) painted the .notdef box while Skia's DirectWrite fallback reached Segoe UI Symbol. The native payload moves to version 3 and carries `role 3 = symbol`; the Windows candidate table registers `%WINDIR%\Fonts\seguisym.ttf` under its own family only, so the face joins `resolved_faces` as a fallback without ever resolving `system-ui`/`sans-serif`. The decoder rejects version 2 and caps `match_count` at 4 roles × 6 weights. Symbol faces come from the candidate table only, so the Linux fc-match loop still queries the three text roles. |

## Progress

| Date | Note |
|------|------|
| 2026-11-19 | Stage 1: `sun` pushed to origin; gate script + self-test (15 checks) added; cherry-picked `d32b7a9` (six static validators PASS, `moon check` exit 0, check-profile catalog PASS); baseline re-measured unchanged (7.93%/19.72%, changed-pixel share 20.89%); `visual` profile step registered report-only and the full profile run exits 0 with the gate skipping cleanly on this Skia-disabled host (golden 4/4, gallery 3/3). |
| 2026-11-19 | Stage 2: font discovery, platform faces resolved by CSS weight, and the offscreen screenshot toolchain hands the renderer text system to the runtime so layout and paint agree. 60-cell matrix avg 3.19%, worst 8.37% (`checkbox/dark/focused`); text-only cells 0.45-4.08%; Showcase first screen Sun-vs-Skia avg 1.445%, no bitmap glyphs, no clipped text. |
| 2026-11-19 | Stage 3: analytic row coverage for rounded-rect fill/stroke, miter-join bound in the generic stroker, and single-line text centred on the face ascent/descent box. 60-cell matrix on a frozen tree avg 2.09% (limit 4.0%), worst 6.33% `checkbox/light/focused` (limit 13%); the 30 checkbox/radio/toggle cells are 0.79-6.33%, all under the 8% per-cell line; 60 cells + 22 transitions, no missing styles; corner, ring, focus-ring and rail crops show only 1-2 level edge differences, no jaggies. Glyph masks still use the 4x4 grid; the adaptive glyph-mask sampler measured neutral in an A/B (50 cells changed pixels, gate unchanged) and is not part of this stage. The residual on checkbox labels is dominated by a one-logical-pixel horizontal phase offset of the text origin (ink starts at 60 device px against Skia's 58), not by edge coverage; left-shifting Sun text by that pixel takes checkbox from 6.65% to 3.42%. That is carried into stage 4. |
| 2026-11-20 | Stage 4: text placement now uses the pen origin (no double side bearing), shaders sample in canvas space, and blur/shadow geometry scales with DPR. 60-cell matrix on the frozen tree avg 1.23% (limit 3.5%), worst 2.63% `text_field/light/default` (limit 10.5%); 60 cells + 22 transitions, no missing styles, changed-pixel share 11.66%. Showcase at 2160×1440: Welcome first screen 1.036%, Advanced Rendering 0.973% (1.332% before the gradient fix), Accessibility Probe 0.84%; radial-gradient card region 0.093%, filter card region 0.481% → 0.259% after DPR blur; a DPR=2 shadow probe shows a smooth 3-pass falloff with no banding. First-screen render 33.9 s vs the 41.5 s stage-3 baseline (debug native, 1080×720, DPR 2) = 0.82×, inside the 1.2× line. `moon check` clean; `moui_sun_renderer` 124/124. Known gaps outside this stage: the Showcase image source still paints Sun's placeholder in the offscreen screenshot path, and overflowing `draw_text` wraps in Sun's layout where Skia clips at the frame edge. |
| 2026-11-20 | Stage 5: the `visual` parity entry is blocking and Linux-only. The gate no longer skips on a missing Skia reference (exit 1 without `--report-only`), and the blocking step forces the locked release prebuild for its two matrix children while the rest of the profile keeps the prebuild-disabled default (so the host-pinned control-preview and gallery-screenshot checks print `skipped` on Linux instead of going stale). `ci.yml` now triggers pull requests to `dev` and runs the whole `visual` profile in a `ubuntu-24.04` job after `set_linux_deps.sh`; the parity check is a red check on dev PRs. Tightening the gate to `--max-avg 1` exited 1; restoring 3/10 exited 0. Final standard-directory gate: 60 cells, `avg 1.23%` (limit 3.00%), worst `2.63% text_field/light/default` (limit 10.00%), 22 transitions, no missing/blank, exit 0; diagnostic changed-pixel share 11.66%. `node scripts/check.mjs --profile visual` exits 0 (parity PASS, golden 4/4, gallery app 3/3; previews/gallery skipped by the documented host rule). Real X11 Showcase screenshots at 1100×680 via `scripts/capture-showcase-sun.sh`: Welcome `artifacts/showcase-real/sun-0.png`, Advanced Rendering `sun-1.png`, Accessibility Probe `sun-2.png`; visual inspection shows no bitmap glyphs or jaggies and no clipped text on the first screen. Local checks: `moon check` clean, `moon fmt --check` clean, `moui_sun_renderer` 124/124, `examples/showcase/app` 17/17; static validators green except `validate-renderer-capability-consistency`, which cannot compile the Metal `.mm` stubs on this Linux host (`cc1objplus` missing). Known gaps documented in the PR: Sun `draw_text` overflow wraps where Skia clips (Renderer Smoke card), and the Renderer Smoke PNG data URI still paints a Sun placeholder. |
| 2026-11-20 | Phase 2 stages 6–7: Windows baseline before the fix was `avg 7.41%` / worst `17.67% checkbox/dark/focused` (changed-pixel share 20.00%) with every label in placeholder glyphs. After the Windows face query: `avg 1.57%` (limit 3.00%) / worst `5.04% toggle/light/focused` (limit 10.00%), gate PASS, changed-pixel share 11.73%; the button cell inspected at 2x now shows real Segoe UI outlines. `moon test moui_sun_renderer --target native` 124/124. The reference matrix came from the same host with the locked release provider; `icudtl.dat` staging is deferred to stage 9. |
| 2026-11-20 | Phase 2 stage 9: one full `scripts/windows-platform-evidence.sh` run on Windows (MSVC x64, release provider `dev-6d73578a36`) exits 0 and records `softbuffer_smoke_status=passed`, `visual_parity_status=passed` (report-only), `showcase_first_frame_status=passed`. Parity with `icudtl.dat` staged: 60 cells, `avg 1.52%` (limit 3.00%), worst `4.00% checkbox/dark/pressed` (limit 10.00%), 22 transitions, no missing/blank cells, changed-pixel share 11.60%. The worst group is now checkbox (3.6–4.0%), then toggle (2.6–3.0%); slider stays ≤0.06%. |
| 2026-11-20 | Phase 2 stage 8: Windows symbol fallback landed. 60-cell matrix avg 1.04% (limit 3.00%), worst 2.30% `checkbox/dark/pressed` (limit 10.00%), changed-pixel share 11.01% — better than Linux (1.23% / 2.63%). Checkbox group 3.6–4.0% → 1.95–2.30%, toggle 2.6–3.0% → 0.91–1.25%. `moon test moui_sun_renderer --target native` 126/126 (two new tests: the fallback stack covers U+2713, and the symbol role registers no generic family); `windows_sun` first-frame smoke still prints its marker. Local note: the five image/font fixture tests only pass with TEMP/TMP pointed inside the repo, because this machine denies %TEMP% writes to locally built executables. Closeout: the gate run without `--report-only` exits 0 on the same artifacts; `moon fmt --check` clean; 9/10 pre-push static validators PASS — `validate-renderer-capability-consistency` stays red on this Windows host because MSVC `cl` cannot produce the Metal `.mm` object (Linux CI covers it). |
