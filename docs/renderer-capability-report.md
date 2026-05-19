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
| Image | partial | partial | Replace placeholder visuals with source decode, texture upload, sampling, fit, and cache management. |
| Clip | partial | partial | Move beyond rectangular scissor support toward rounded clips and richer mask stacks. |
| Transform | partial | partial | Preserve full affine behavior through renderer state instead of only folding transforms into planned vertices and scissor bounds. |
| Opacity | ready | ready | None |

## Current Native Notes

Native wgpu currently renders rects, rounded geometry, gradients, soft shadows,
and glyph-atlas text directly. Image commands are represented by placeholder
visual items, which keeps command ordering and opacity behavior testable while
the real texture path is still pending. Clip support uses rectangular scissor
rectangles. Transform support is applied to planned vertices; clip scissors use
transformed bounding boxes. Opacity is folded into visual and text vertex alpha.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, and text through
WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph atlas before the
glyphs are composited by WebGPU.

Image commands currently render the same placeholder visual used by native
wgpu. Clip support maps rectangular clip stacks to per-item scissor rectangles.
Transform support is folded into generated visual and text vertices, with clip
scissors derived from transformed bounding boxes.

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page
