# ADR 0023: Sun CPU Raster is an Experimental Renderer

- **Date**: 2026-08-02
- **Status**: Accepted
- **Deciders**: Agent-assisted (deepseek-v4-flash); positioning decided by repo owner
- **Related**: ADR 0007 (renderer and Skia, sections on provider open-extension); ADR 0019 (renderer provider plugin); invariants R1/R2; `moui/render/sun/provider.mbt`; `moui_sun/` package

## Context

MoUI carries a second native rendering stack in addition to the mainline
Native Skia renderer:

- `moui_sun/` (81K lines) — a pure-MoonBit CPU raster stack: graphics canvas,
  TTF parser/shaper/layout/rasterizer, render pipeline, and a softbuffer
  native surface layer.
- `moui/render/sun/` (3.5K lines) — the `sun-raster` `RendererProvider` that
  adapts `moui_sun` into the ADR 0019 provider plugin system. It only accepts
  `CpuRaster` surfaces and presents `CpuPixelFrame`s.

Facts established during the 2026-08-02 architecture review:

- **No product app uses sun.** `macos_backend.mbt`, `linux_backend.mbt`, and
  `windows_backend.mbt` reference `sun` zero times. The product `auto`
  renderer selection stays on `SkiaGpuNative` / `SkiaRasterNative` (R2).
- Sun is reachable only through dedicated smoke entrypoints
  (`examples/showcase/{macos,linux,windows}_sun`) and platform provider tests
  (`backend/{macos,linux,windows}/sun`).
- The three platform sun providers are near-mirror adapter shells, gated by
  the platform file-similarity validator.
- Sun's capability surface already diverges from Skia (e.g., blur uses a
  three-pass box blur; missing glyphs draw debug placeholder coverage).
- Git history shows 75 commits touching sun paths; the stack is maintained,
  tested (renderer-local pixel tests, resource replay tests), and governed by
  line budgets in `validate-maintenance-baseline`.

Forces:

- Native Skia is the declared mainline (R1); native WGPU is diagnostic.
  Sun currently has **no** product-class commitment and is not on any default
  composition root.
- Maintaining a second full renderer stack costs real engineering (every new
  `DrawCommand` capability would otherwise need a third implementation).
- A pure-MoonBit raster/text stack has option value: no-Skia distribution
  paths, WASM CPU rendering, or a reusable standalone text package
  (`moui_sun/text`).
- MoUI governance ("budgets only shrink or stay", "experimental = no product
  commitment") needs an explicit position so the option value does not become
  an unbounded maintenance tax.

## Decision

Position `moui_sun` + `moui/render/sun` as **an experimental renderer**, on
the same product class as native WGPU but with an even lower commitment:

1. **No product commitment.** Sun is not part of the product `auto` renderer
   selection, is not registered in default composition roots, and makes no
   usability/performance claim. Its providers keep reporting
   `renderer=experimental-ready` and `runtime=matching-host pending`.
2. **Capability freeze by default.** New `DrawCommand` capabilities and new
   renderer features are **not required** to be implemented in sun. Sun only
   needs to keep compiling and passing its existing renderer-local tests and
   platform provider tests. Adding a new sun capability requires a reason and
   an ADR note (it is the exception, not the default).
3. **Document the positioning in the repo.** The capability report already
   lists Sun CPU raster in the product order; add an explicit experimental
   note so future readers and agents do not infer mainline status.
4. **Revisit at a decision point.** If a committed product role materializes
   (no-Skia distribution, WASM CPU raster, standalone text package), record it
   in an RFC/ADR. If no role materializes, the freeze becomes the steady
   state and any future removal reuses the ADR 0023 rationale.

## Options Considered

### Option A: Elevate sun to mainline/second-class product renderer

- Pros: fully realized MoonBit-native rendering; no Skia FFI dependency.
- Cons: contradicts R1 (mainline = Native Skia); doubles the capability
  implementation tax; no product evidence or default-path usage today.

### Option B: Freeze as experimental (chosen)

- Pros: preserves the option value (pure-MoonBit stack, reusable text
  package) at near-zero ongoing capability cost; keeps the stack compiling
  and tested; honest about readiness; matches "budgets only shrink" culture.
- Cons: the stack still occupies ~86K lines and periodic platform
  maintenance; must resist pressure to "keep parity" with Skia.

### Option C: Eliminate sun now

- Pros: removes ~86K lines and the near-mirror provider shells immediately.
- Cons: discards the only pure-MoonBit rendering/text asset before any
  product role is evaluated; deletion touches validators, budgets, docs, and
  `moon.work`; irreversible (git history remains, but effort is lost).

## Rationale

The chosen option keeps the hedge (Option C's salvage value) without paying
Option A's tax. Sun is maintained, tested, and already integrated through the
ADR 0019 provider plugin — the marginal cost of keeping it experimental is
small, while deleting it permanently removes the only Skia-free raster path.
A documented freeze prevents silent capability drift while leaving the door
open to either promotion (with RFC) or eventual removal (reusing this ADR).

## Consequences

- **Easier**: honest readiness reporting; no implicit obligation to mirror
  every Skia capability in sun; contributors know the boundary without
  archaeology.
- **Harder**: the ~86K-line footprint remains; platform adapter shells must
  keep passing the file-similarity gate; a future promotion requires an RFC
  and product evidence.
- **Follow-up**: add the experimental note to
  `docs/renderer-capability-report.md`; register invariant R7; keep `moon.work`
  listing `./moui_sun` while it is exercised by tests.

## Agent Notes

- **Session context**: architecture review of MoUI (completeness,
  maintainability, extensibility, long-term maintenance, engineering
  quality), followed by a deep dive into `moui_sun` / `render/sun` and a
  decision on its positioning.
- **Agent model**: deepseek-v4-flash (Buffy/Freebuff).
- **Key prompt or instruction**: "sun 定位为实验性渲染" — the repo owner
  decided sun's product class is experimental renderer.
- **Validation**: package/line-budget evidence gathered via code search and
  terminal inspection (provider registrations, capability report, git
  history); ADR follows `docs/decisions/TEMPLATE.md`; static validation trio
  run after the docs update.

## References

- `moui_sun/moon.mod` ("Experimental MoonBit-native CPU raster stack")
- `moui/render/sun/provider.mbt` (`create_sun_provider`, id `sun-raster`)
- `moui/backend/{macos,linux,windows}/sun/*_sun_provider.mbt`
- `examples/showcase/{macos,linux,windows}_sun/main.mbt`
- `docs/decisions/0007-renderer-and-skia.md`
- `docs/decisions/0011-platform-class-and-convergence.md`
