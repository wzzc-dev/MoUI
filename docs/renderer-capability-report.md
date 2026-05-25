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
| Clip | ready | ready | Rectangular transformed scissor behavior is aligned; rounded clips are handled through native shader SDF masks and Web offscreen layer-mask scopes. |
| Transform | partial | partial | Affine transforms are folded into visual, image, and text vertices. Scoped native layer/filter child plans now inherit transform and clip, and Web scoped layers clone the current transform/clip state; richer render-pass transform state and pixel evidence remain follow-up work. |
| Opacity | ready | ready | None |
| Layer compositing | ready | ready | Native and Web render layer scopes into offscreen GPU textures and composite them back through the advanced GPU pass with opacity and masks. |
| Blend mode | ready | ready | Source-over, multiply, screen, darken, and lighten map to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math. |
| Filter effect | ready | ready | `PushFilter` / `PopFilter` render scoped content to offscreen textures; the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters. |
| Path/vector | gap | gap | `DrawPath` has a platform-neutral `PathSpec` model and `moon_zeno` tessellation tests, but native and Web adapters still skip the command before visible renderer execution. |
| Shader effect | ready | ready | `DrawShaderEffect` executes through the advanced GPU shader path for built-in `solid`, `checker`, `linear-gradient-debug`, and `vignette`, with unknown effects using their fallback brush. |
| Text shaping | partial | partial | `FontSpec` now uses structured family stacks. Runtime text is injectable through `TextSystem`: `core` keeps only a deterministic fallback system, native WGPU exposes a provider protocol, `render/wgpu/cosmic_text` owns the Cosmic provider, macOS composes CoreText with Cosmic fallback by default, Windows composes its DirectWrite scaffold with Cosmic fallback, Linux has a fontconfig/HarfBuzz/FreeType scaffold provider, and Web uses the same Canvas CSS `system-ui` stack for measurement and WebGPU text drawing. macOS/Windows startup can select `MoonCosmic` or `PlatformDefault`; the Windows/Linux scaffolds currently return no platform glyph data and rely on the composed Cosmic fallback until real engines land. Full bidi, line breaking, and typography conformance remain follow-up work. |
| Emoji text | gap | partial | Native color emoji support is not implemented; Web coverage depends on browser font rasterization. Diagnostic text conformance now covers deterministic emoji measurement/caret invariants for single-codepoint, variation-selector, and ZWJ samples, but it does not claim full grapheme shaping or native color glyph support. |
| Async image | partial | partial | Renderer-neutral lifecycle records model loading, ready, failed, disposed, and eviction. Native and Web renderers expose image resource snapshots; Web refreshes ready/failed records from the browser cache after host submission. App-level async repaint/notification policy remains follow-up work. |

## Current Native Notes

Native wgpu now renders rects, rounded geometry, gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover fit modes, and fallback
handling.
Clip support uses transformed rectangular scissor rectangles and rounded clips
with shader SDF masks. Transform support is applied to planned visual, image,
and text vertices. Scoped layer/filter child plans inherit transform and clip
state while outer opacity is applied once at composite time. Opacity is folded
into visual and text vertex alpha.
Layer compositing and filter scopes render into offscreen textures before the
parent pass samples them through the advanced composite shader. That pass
applies opacity, rectangular or rounded masks, built-in filter payloads, and
shader-effect payloads. Source-over, multiply, screen, darken, and lighten use
GPU blend-state mappings; overlay uses a separate backdrop-sampling pass so the
shader can evaluate the per-channel overlay formula against the current target.
Vector paths currently stop at the shared `moon_zeno` tessellation contract:
fills and strokes can be lowered into triangle vertices, including flattened
quadratic and cubic segments, but the native draw plan still drops
`DrawPath` before visible GPU execution. The renderer-neutral SVG import path
uses `mizchi/svg` as its parser frontend and lowers supported scene graph
shapes into the same draw-command model while reporting unsupported SMIL
animation and `foreignObject` usage. `render/capabilities.mbt` also exposes a
command fallback planner that reports unbalanced pops, open advanced scopes,
and planned `DrawPath` fallbacks for native and WebGPU adapters. Native color
emoji remains an explicit gap. Text shaping is
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
Cosmic provider package. Diagnostic text conformance covers deterministic emoji
measurement and caret invariants for single-codepoint, variation-selector, and
ZWJ samples, but full bidi, line breaking, typography conformance, native color
emoji, and full grapheme shaping are still follow-up work.
The cross-package text boundary is documented in [Text system](text-system.md).
Native image support is synchronous from the app model's point of view.
`WgpuRenderer::image_resources()` exposes renderer-local image resource
snapshots. Planned image commands are marked loading until the native cache can
resolve them; successful synchronous decode/cache upload marks records ready
with dimensions, and failed decodes mark records failed with a diagnostic.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, text, and loaded
images through WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph
atlas before the glyphs are composited by WebGPU. Images are cached as WebGPU
textures, support contain/cover fit, and use a deterministic fallback color
while the browser is still loading the source or if loading fails.
`WebGpuWasmRenderer::image_resources()` exposes renderer-local image resource
snapshots. Submitted sources start as loading, and after host submission the
adapter refreshes records from the browser cache that is updated by
`Image.onload` / `Image.onerror`, so subsequent renders can report ready
dimensions or failed diagnostics without changing the app model.

Clip support maps transformed rectangular clip stacks to per-item scissor
rectangles. Rounded clip scopes are submitted as offscreen layer scopes with a
rounded mask, reusing the browser runtime's layer-mask composite path.
Transform support is folded into generated visual, image, and text vertices,
with clip scissors derived from transformed bounding boxes. Scoped layer/filter
commands clone the current transform and clip state before rendering into their
offscreen scope.
The Web runtime forwards layer, filter, and shader-effect commands through the
wasm-gc host ABI. The browser runtime uses draw scopes, offscreen WebGPU
textures, and an advanced composite shader for layer opacity, masks, filters,
and built-in shader effects. Blend-mode coverage matches native: source-over,
multiply, screen, darken, and lighten use WebGPU blend states, while overlay
uses a backdrop-sampling WebGPU pass for exact semantics.
Arbitrary paths share the same MoonBit tessellation contract as native, but the
wasm-gc adapter still drops `DrawPath` instead of forwarding a host-call mesh.
Skipped advanced commands are retained in the renderer's last fallback plan for
diagnostics when scopes are unbalanced, left open, or known modeled commands
are not visibly executed yet. Emoji and complex text shaping rely on browser
font behavior; diagnostic conformance covers measurement and caret invariants
for representative emoji samples but does not make browser rasterization or
full grapheme shaping deterministic.

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page

For text-related renderer changes, also update `docs/text-system.md`.
