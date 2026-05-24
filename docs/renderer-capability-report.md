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
| Clip | ready | ready | Rectangular transformed scissor behavior is aligned; rounded clips are handled through native shader SDF masks and Web layer-mask shader coverage. |
| Transform | partial | partial | Affine transforms are folded into visual, image, and text vertices; layer-level transform state remains follow-up work. |
| Opacity | ready | ready | None |
| Layer compositing | ready | ready | Native and Web render layer scopes into offscreen GPU textures and composite them back through the advanced GPU pass with opacity and masks. |
| Blend mode | ready | ready | Source-over, multiply, screen, darken, and lighten map to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math. |
| Filter effect | ready | ready | `PushFilter` / `PopFilter` render scoped content to offscreen textures; the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters. |
| Path/vector | ready | ready | `DrawPath` models move/line/quad/cubic/close verbs and is lowered through `moon_zeno` into fill and stroke triangle vertices before renderer execution. |
| Shader effect | ready | ready | `DrawShaderEffect` executes through the advanced GPU shader path for built-in `solid`, `checker`, `linear-gradient-debug`, and `vignette`, with unknown effects using their fallback brush. |
| Text shaping | partial | partial | `FontSpec` now uses structured family stacks. Runtime text is injectable through `TextSystem`: `core` keeps only a deterministic fallback system, native WGPU exposes a provider protocol, `render/wgpu/cosmic_text` owns the Cosmic provider, macOS composes CoreText with Cosmic fallback by default, Windows composes its DirectWrite scaffold with Cosmic fallback, Linux has a fontconfig/HarfBuzz/FreeType scaffold provider, and Web uses the same Canvas CSS `system-ui` stack for measurement and WebGPU text drawing. macOS/Windows startup can select `MoonCosmic` or `PlatformDefault`; the Windows/Linux scaffolds currently return no platform glyph data and rely on the composed Cosmic fallback until real engines land. Full bidi, line breaking, and typography conformance remain follow-up work. |
| Emoji text | gap | partial | Native color emoji support is not implemented; Web coverage depends on browser font rasterization and lacks deterministic tests. |
| Async image | partial | partial | Renderer-neutral lifecycle records now model loading, ready, failed, disposed, and eviction; native/Web adapters still need to surface those diagnostics to app code. |

## Current Native Notes

Native wgpu now renders rects, rounded geometry, gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover fit modes, and fallback
handling.
Clip support uses transformed rectangular scissor rectangles and rounded clips
with shader SDF masks. Transform support is applied to planned visual, image,
and text vertices. Opacity is folded into visual and text vertex alpha.
Layer compositing and filter scopes render into offscreen textures before the
parent pass samples them through the advanced composite shader. That pass
applies opacity, rectangular or rounded masks, built-in filter payloads, and
shader-effect payloads. Source-over, multiply, screen, darken, and lighten use
GPU blend-state mappings; overlay uses a separate backdrop-sampling pass so the
shader can evaluate the per-channel overlay formula against the current target.
Vector paths additionally have a shared `moon_zeno` tessellation contract that
lowers fills and strokes into triangle vertices, including flattened quadratic
and cubic segments. The renderer-neutral SVG import path uses `mizchi/svg` as
its parser frontend and lowers supported scene graph shapes into the same
draw-command model while reporting unsupported SMIL animation and
`foreignObject` usage. `render/capabilities.mbt` also exposes a command
fallback planner that reports unbalanced pops and open advanced scopes for
native and WebGPU adapters. Native color emoji remains an explicit gap. Text shaping is
partial: `core/` keeps only a deterministic fallback `TextSystem`,
`render/wgpu` owns provider validation and atlas upload,
`render/wgpu/cosmic_text` owns the native Cosmic
provider, macOS composes a CoreText-backed platform text engine with Cosmic
fallback for measurement and glyph rasterization, and native platform providers
share `render/wgpu/text_protocol` for UTF-32 input encoding, versioned
`FontSpec` payloads carrying size, weight, style, and the structured family
stack, private versioned measurement payload parsing, a generic run-layout
envelope for shaped glyph placements with platform-private raster payloads, a
shared single-channel raster glyph parser, and a versioned registration payload
encoder/decoder for embedded font bytes. CoreText then
attempts installed named families from the structured family stack, maps generic
families such as `ui-monospace`, `serif`, and `emoji` to suitable macOS fonts,
falls back to system fonts for unavailable families, attempts process-local
registration of app-provided font bytes under the requested family alias, uses
CoreText glyph runs for glyph ids and positions before atlas upload, and its
glyph payloads carry PostScript font identity so fallback-font glyph runs can be
rasterized with the same font that shaped them. Windows composes a DirectWrite
scaffold provider with Cosmic fallback and Linux has a
fontconfig/HarfBuzz/FreeType scaffold provider. Web injects a Canvas-backed
text system that uses the same CSS `system-ui` family stack as text drawing. The
Windows and Linux native stubs intentionally return no platform layout/raster
data today, so hosts rely on the composed Cosmic fallback until real engines are
implemented.
Fallback composition is explicit at the backend/provider boundary; the
`render/wgpu` package validates provider responses but does not depend on the
Cosmic provider package. Full bidi, line breaking, and typography conformance
are still follow-up work.
Native image support is
synchronous from the app model's
point of view; the shared image lifecycle record can represent loading, ready,
failed, disposed, and evicted resources, but native adapter diagnostics are not
surfaced to app code yet.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, text, and loaded
images through WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph
atlas before the glyphs are composited by WebGPU. Images are cached as WebGPU
textures, support contain/cover fit, and use a deterministic fallback color
while the browser is still loading the source or if loading fails.
The shared image lifecycle contract now matches those loading, ready, failed,
and disposed states; the runtime still needs to publish browser cache
diagnostics back into app-visible renderer state.

Clip support maps transformed rectangular clip stacks to per-item scissor
rectangles. Transform support is folded into generated visual, image, and text
vertices, with clip scissors derived from transformed bounding boxes.
The Web runtime forwards layer, filter, and shader-effect commands through the
wasm-gc host ABI. The browser runtime uses draw scopes, offscreen WebGPU
textures, and an advanced composite shader for layer opacity, masks, filters,
and built-in shader effects. Blend-mode coverage matches native: source-over,
multiply, screen, darken, and lighten use WebGPU blend states, while overlay
uses a backdrop-sampling WebGPU pass for exact semantics.
Arbitrary paths share the same MoonBit tessellation contract as native, so host
upload can consume deterministic triangle meshes. Skipped advanced commands are
retained in the renderer's last fallback plan for diagnostics when scopes are
unbalanced or left open. Emoji and complex text shaping rely on browser font
behavior and need deterministic conformance tests.

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page
