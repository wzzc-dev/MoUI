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

- [ ] 60-cell matrix (`6 controls × 5 states × 2 schemes`) generated from the
      same baseline with `--renderer sun` and `--renderer skia` reports
      average ≤3% and worst ≤10%.
- [ ] Showcase first screen screenshot passes human inspection: no bitmap
      glyphs, no clipped text, no jaggies.
- [x] `scripts/visual-parity-gate.mjs` reproduces the baseline numbers and
      fails on threshold breaches (exit 1 without `--report-only`; self-test
      covers metric and invalidity paths); the `visual` check profile registers
      it report-only.
- [ ] Sun remains experimental (`auto` unchanged, no default composition root
      registration).

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

## Progress

| Date | Note |
|------|------|
| 2026-11-19 | Stage 1: `sun` pushed to origin; gate script + self-test (15 checks) added; cherry-picked `d32b7a9` (six static validators PASS, `moon check` exit 0, check-profile catalog PASS); baseline re-measured unchanged (7.93%/19.72%, changed-pixel share 20.89%); `visual` profile step registered report-only and the full profile run exits 0 with the gate skipping cleanly on this Skia-disabled host (golden 4/4, gallery 3/3). |
