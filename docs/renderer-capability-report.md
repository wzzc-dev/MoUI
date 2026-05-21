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
| Image | ready | ready | Native decodes PNG/JPEG/BMP from local file paths and base64 data URIs through `mizchi/image`; Web loads browser-supported sources into a WebGPU texture cache. |
| Clip | ready | partial | Rectangular transformed scissor behavior is aligned; rounded clips supported in native with shader SDF masks. |
| Transform | partial | partial | Affine transforms are folded into visual, image, and text vertices; layer-level transform state remains follow-up work. |
| Opacity | ready | ready | None |
| Layer compositing | partial | partial | `PushLayer` / `PopLayer` now model opacity, blend mode, masks, and offscreen intent; native and WebGPU still need retained layer pass execution. |
| Blend mode | partial | partial | `BlendMode` is carried by `LayerSpec`; GPU pipeline blend-state mapping remains follow-up work. |
| Filter effect | partial | partial | `PushFilter` / `PopFilter` now model blur, color, and contrast-style effects; shader pass execution remains follow-up work. |
| Path/vector | partial | partial | `DrawPath` now models move/line/quad/cubic/close verbs with fill and stroke brushes; tessellation remains follow-up work. |
| Shader effect | partial | partial | `DrawShaderEffect` now models named effects, uniforms, frame, and fallback brush; shader registry and host ABI are still follow-up work. |
| Text shaping | partial | partial | Native has HarfBuzz shaping and fallback faces; full bidi, line breaking, and typography conformance remain follow-up work. |
| Emoji text | gap | partial | Native color emoji support is not implemented; Web coverage depends on browser font rasterization and lacks deterministic tests. |
| Async image | partial | partial | Images are cached after load/decode, but loading/error state and resource lifecycle APIs are not surfaced to app code yet. |

## Current Native Notes

Native wgpu now renders rects, rounded geometry, gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover fit modes, and fallback
handling.
Clip support uses transformed rectangular scissor rectangles and rounded clips
with shader SDF masks. Transform support is applied to planned visual, image,
and text vertices. Opacity is folded into visual and text vertex alpha.
Layer compositing, blend modes, filters, vector paths, and shader effects now
have renderer-neutral command intents. Native wgpu still needs the actual
offscreen passes, mask composition, path tessellation, filter shaders, and
shader registry. Native color emoji remains an explicit gap. Text shaping is partial: HarfBuzz and
fallback faces exist, but full bidi, line breaking, and typography conformance
are still follow-up work. Native image support is synchronous from the app
model's point of view; async loading and resource lifecycle state are not
surfaced yet.

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
The Web runtime has browser image loading and canvas-rasterized text, but
layer compositing, blend modes, filters, arbitrary paths, and user shader
effects are represented by the MoonBit command model but not yet forwarded in
the browser host ABI. Emoji and complex text shaping rely on browser font
behavior and need deterministic conformance tests.

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page
