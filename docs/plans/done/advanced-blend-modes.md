# Advanced blend modes: Add/Difference/Exclusion/HardLight/SoftLight/Dodge/Burn

- **Status**: done (2026-11-17)
- **Goal**: Grow `@core.BlendMode` from 6 separable modes to the full
  separable+separable-adjacent set creative canvases need, with true
  implementations on Skia and Sun, Canvas2D `globalCompositeOperation` on Web,
  and documented source-over degradation on WGPU/Metal until their pipelines
  grow the math.

## Current behavior

`BlendMode` has SourceOver/Multiply/Screen/Overlay/Darken/Lighten. p5's
`Add`, `Difference`, and `Exclusion` silently degrade to SourceOver in the
adapter's `_ =>` arm, and HardLight/SoftLight/Dodge/Burn do not exist on the
p5 side at all.

## Design

1. Core: add `Add`, `Difference`, `Exclusion`, `HardLight`, `SoftLight`,
   `ColorDodge`, `ColorBurn`.
2. Skia `skia_blend_mode`: `Plus`, `Difference`, `Exclusion`, `HardLight`,
   `SoftLight`, `ColorDodge`, `ColorBurn` (native Skia blend modes).
3. Sun `sun_blend_mode`: the `moui_sun` paint enum already implements every
   mode; map them.
4. Web: extend the shared host code (`blend_mode_host_code`) to 6..=12 and the
   Canvas2D JS `blendModeOp` to `lighter`/`difference`/`exclusion`/
   `hard-light`/`soft-light`/`color-dodge`/`color-burn`. The WebGPU JS
   `advancedBlend` switch defaults unknown codes to source-over factors — a
   documented degradation (its overlay path is shader-based; the new modes
   would need shader math).
5. WGPU `native_blend_mode_code`: new modes map to the source-over code.
   Metal `metal_blend_code`: new modes map to the existing `-1` unsupported
   sentinel (the same one `Overlay` already uses).
6. p5: add `HardLight`/`SoftLight`/`Dodge`/`Burn` to the p5 enum and replace
   the adapter's fallback arm with a full mapping (Dodge→ColorDodge,
   Burn→ColorBurn).

## Verification results

- `moon test moui_skia_renderer`: 153 passed — Difference of red over white
  renders cyan inside the layer and the untouched half stays white.
- `moon test moui_sun_renderer`: 113 passed — mapping unit test covers all
  seven new modes.
- `moon test examples/p5_sketch/p5/moui`: 15 passed — `Difference` and `Dodge`
  emit `PushLayer` with `Difference`/`ColorDodge` (no SourceOver fallback arm).
- TUI 43 / Web 33 / WGPU 61 / Metal 91 passed; static validators and
  regenerated budgets/report green.

## Follow-ups

- WebGPU/Metal shader implementations for the new modes.
- p5 `Subtract`/`Replace`/`Remove` map onto existing semantics only partially;
  revisit if a sketch needs them.
