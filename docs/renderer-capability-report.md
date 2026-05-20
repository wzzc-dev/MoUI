# Renderer Capability Report

This page tracks draw command coverage for the native wgpu renderer and the
wasm-gc WebGPU host bridge. The same status data is codified in
`render/capabilities.mbt` and checked by `render/capabilities_test.mbt`.

Status meanings:

- `ready`: implemented directly by the renderer.
- `partial`: visible support exists, but follow-up work remains.
- `gap`: no visible implementation yet.
- `host-forwarded`: MoonBit forwards the command to the browser WebGPU host
  without local runtime coverage.

| Feature | Native wgpu | Web wasm-gc | Follow-up |
| --- | --- | --- | --- |
| Rect | ready | ready | None |
| Rounded rect | ready | ready | None |
| Gradient | ready | ready | None |
| Shadow | ready | ready | None |
| Text | ready | ready | None |
| Image | partial | ready | Native still needs source decode and texture sampling; Web now loads sources into a WebGPU texture cache with contain/cover fit and deterministic fallback while loading or on failure. |
| Clip | partial | partial | Rectangular transformed scissor behavior is aligned; rounded clips and richer mask stacks remain follow-up work. |
| Transform | partial | partial | Affine transforms are folded into visual, image, and text vertices; layer-level transform state remains follow-up work. |
| Opacity | ready | ready | None |

## Current Native Notes

Native wgpu currently renders rects, rounded geometry, gradients, soft shadows,
and glyph-atlas text directly. Image commands are now represented as distinct
native image draw items that preserve source, opacity, fit, clip, and transform
metadata; the actual source decode, upload, and texture sampling path is still
pending and uses a deterministic visual fallback. Clip support uses transformed
rectangular scissor rectangles. Transform support is applied to planned visual,
image fallback, and text vertices. Opacity is folded into visual and text vertex
alpha.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, text, and loaded
images through WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph
atlas before the glyphs are composited by WebGPU. Images are cached as WebGPU
textures, support contain/cover fit, and use a deterministic fallback color
while the browser is still loading the source or if loading fails.

Clip support maps transformed rectangular clip stacks to per-item scissor
rectangles. Transform support is folded into generated visual, image, and text
vertices, with clip scissors derived from transformed bounding boxes.

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page
