# Renderer Capability Report

This page tracks draw command coverage for the native wgpu renderer and the
wasm-gc WebGPU host bridge. The same status data is codified in
`render/capabilities.mbt` and checked by `render/capabilities_test.mbt`.
Showcase consumes the same report and prioritizes follow-up rows in its visible
capability card, but renderer support claims still come from this report plus
renderer/provider tests.

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
| Transform | partial | partial | Affine transforms are folded into visual, image, text, shader-effect advanced vertices, and masked native layer composite vertices. Scoped native layer/filter child plans inherit transform and clip; native filter scopes preserve transformed child vertices and transformed clip scissors. Web scoped layer/filter commands clone the current transform/clip state, and Web adapter tests preserve transform scope around layers, filters, and shader effects. Broader render-pass transform pixel evidence remains follow-up work. |
| Opacity | ready | ready | None |
| Layer compositing | ready | ready | Native and Web render layer scopes into offscreen GPU textures and composite them back through the advanced GPU pass with opacity and masks. |
| Blend mode | ready | ready | Source-over, multiply, screen, darken, and lighten map to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math. |
| Filter effect | ready | ready | `PushFilter` / `PopFilter` render scoped content to offscreen textures; the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters. |
| Path/vector | ready | ready | `DrawPath` lowers `PathSpec` fills and strokes through the shared `moon_zeno` tessellator. Native wgpu renders the triangle mesh through the visual GPU pipeline, and the wasm-gc Web adapter forwards the same mesh payload to the browser WebGPU visual pipeline. |
| Shader effect | ready | ready | `DrawShaderEffect` executes through the advanced GPU shader path for built-in `solid`, `checker`, `linear-gradient-debug`, and `vignette`, with unknown effects using their fallback brush. |
| Text shaping | partial | partial | `FontSpec` now uses structured family stacks. Runtime text is injectable through `TextSystem`: `core` keeps only a deterministic fallback system, native WGPU exposes a provider protocol with validation for metrics and non-empty run-layout caret coverage, `render/wgpu/cosmic_text` owns the Cosmic provider, macOS composes CoreText with Cosmic fallback by default, Windows composes its DirectWrite scaffold with Cosmic fallback, Linux composes its fontconfig/HarfBuzz/FreeType scaffold with Cosmic fallback, and Web uses the same Canvas CSS `system-ui` stack for measurement and WebGPU text drawing. Cosmic measurement and native run layout paths safe-map provider-fragile emoji samples before shaping while preserving monotonic caret coverage. macOS/Windows/Linux startup can select `MoonCosmic` or `PlatformDefault`; the Windows/Linux scaffolds currently return no platform glyph data and rely on the composed Cosmic fallback until real engines land. Full bidi, line breaking, and typography conformance remain follow-up work. |
| Emoji text | partial | partial | Native WGPU can preserve RGBA color glyph payloads through the provider protocol, atlas upload path, and text vertex shader marker; Cosmic loads platform emoji fallback font candidates when available, keeps color swash pixels, and safe-maps provider-fragile single-codepoint, variation-selector, and ZWJ emoji samples before native layout so caret coverage remains stable; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS. Web coverage depends on browser font rasterization. Full native emoji font fallback across all providers, ZWJ/color emoji conformance, browser rasterization determinism, and full grapheme shaping remain follow-up work. |
| Async image | partial | partial | Renderer-neutral lifecycle records model loading, ready, failed, disposed, and eviction. Native and Web renderers expose image resource snapshots; the Web backend `WebRenderer` facade also exposes those snapshots to app/host integration code. Web refreshes ready/failed records from the browser cache after host submission, and the canonical Web boot path schedules a redraw when browser image load/error events report a resource change. Broader native/general repaint policy and release evidence remain follow-up work. |

## Current Native Notes

Native wgpu now renders rects, rounded geometry, gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover fit modes, and fallback
handling.
Clip support uses transformed rectangular scissor rectangles and rounded clips
with shader SDF masks. Transform support is applied to planned visual, image,
text, shader-effect advanced vertices, and masked layer composite vertices.
Scoped layer/filter child plans inherit transform and clip state while outer
opacity is applied once at composite time; filter scopes preserve transformed
child vertices and transformed clip scissors before compositing. Opacity is folded into visual and
text vertex alpha.
Layer compositing and filter scopes render into offscreen textures before the
parent pass samples them through the advanced composite shader. That pass
applies opacity, rectangular or rounded masks, built-in filter payloads, and
shader-effect payloads. Source-over, multiply, screen, darken, and lighten use
GPU blend-state mappings; overlay uses a separate backdrop-sampling pass so the
shader can evaluate the per-channel overlay formula against the current target.
Vector paths use the shared `moon_zeno` tessellation contract: fills and
strokes lower into triangle vertices, including flattened quadratic and cubic
segments. The native draw plan now submits those vertices through the visual
GPU pipeline as path-colored triangles, so `DrawPath` is no longer a
fallback-only command. The renderer-neutral SVG import path uses `mizchi/svg`
as its parser frontend and lowers supported scene graph shapes into the same
draw-command model while reporting unsupported SMIL animation and
`foreignObject` usage. `render/capabilities.mbt` also exposes a command
fallback planner that reports unbalanced pops and open advanced scopes while
keeping visible `DrawPath` commands out of the fallback list. Native color glyph
payloads can now flow through the provider protocol, glyph atlas, and text
vertex shader marker as RGBA data; Cosmic loads platform emoji fallback font
candidates when available, preserves color swash pixels, and safe-maps
provider-fragile emoji samples before native layout so caret diagnostics remain
stable; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS. Text shaping is
partial: `core/` keeps only a deterministic fallback `TextSystem`,
`render/wgpu` owns provider validation and atlas upload, including rejection of
non-empty run-layout caret arrays that do not cover the input text,
`render/wgpu/cosmic_text` owns the native Cosmic
provider, macOS composes a CoreText-backed platform text engine with Cosmic
fallback for measurement and glyph rasterization, and native platform providers
share `render/wgpu/text_protocol` for UTF-32 input encoding, versioned
`FontSpec` payloads carrying size, weight, style, and the structured family
stack, private versioned measurement payload parsing, a generic run-layout
envelope for shaped glyph placements with platform-private raster payloads, a
shared alpha-mask/RGBA raster glyph parser, and a versioned registration payload
encoder/decoder for embedded font bytes. CoreText then
attempts installed named families from the structured family stack, maps generic
families such as `ui-monospace`, `serif`, and `emoji` to suitable macOS fonts,
falls back to system fonts for unavailable families, attempts process-local
registration of app-provided font bytes under the requested family alias, uses
CoreText glyph runs for glyph ids and positions before atlas upload, and its
glyph payloads carry PostScript font identity so fallback-font glyph runs can be
rasterized with the same font that shaped them. Windows composes a DirectWrite
scaffold provider with Cosmic fallback, and Linux composes its
fontconfig/HarfBuzz/FreeType scaffold provider with Cosmic fallback. Web injects
a Canvas-backed text system that uses the same CSS `system-ui` family stack as
text drawing. The Windows and Linux native stubs intentionally return no
platform layout/raster data today, so hosts rely on the composed Cosmic fallback
until real engines are implemented.
Fallback composition is explicit at the backend/provider boundary; the
`render/wgpu` package validates provider responses but does not depend on the
Cosmic provider package. Diagnostic text conformance covers deterministic emoji
measurement and caret invariants for single-codepoint, variation-selector, and
ZWJ samples; Cosmic run-layout tests also assert glyph output plus monotonic
caret coverage through the provider-safe mapped layout path, and focused Cosmic
tests cover platform emoji fallback font loading and emoji codepoint resolution
when such a font is available. Full bidi, line breaking, typography
conformance, native emoji font fallback across all providers, color emoji
conformance, and full grapheme shaping are still follow-up work.
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
snapshots, and `backend/web.WebRenderer::image_resources()` forwards the same
records to app/host integration code. Submitted sources start as loading, and
after host submission the adapter refreshes records from the browser cache that
is updated by `Image.onload` / `Image.onerror`, so subsequent renders can report
ready dimensions or failed diagnostics. The browser runtime also exposes an
`onImageResourceChange` callback for WebGPU imports, and `bootMouiWasmGcApp`
wires that callback to `window_web.schedule_animation_frame` so image load/error
completion reaches the normal Web redraw path even if user notification code
throws.

Clip support maps transformed rectangular clip stacks to per-item scissor
rectangles. Rounded clip scopes are submitted as offscreen layer scopes with a
rounded mask, reusing the browser runtime's layer-mask composite path.
Transform support is folded into generated visual, image, text, and shader-effect
advanced vertices, with clip scissors derived from transformed bounding boxes.
Scoped layer/filter commands clone the current transform and clip state before
rendering into their offscreen scope, and Web adapter tests preserve transform
scope around layer, filter, and shader-effect host calls.
The Web runtime forwards layer, filter, and shader-effect commands through the
wasm-gc host ABI. The browser runtime uses draw scopes, offscreen WebGPU
textures, and an advanced composite shader for layer opacity, masks, filters,
and built-in shader effects. Blend-mode coverage matches native: source-over,
multiply, screen, darken, and lighten use WebGPU blend states, while overlay
uses a backdrop-sampling WebGPU pass for exact semantics.
Arbitrary paths share the same MoonBit tessellation contract as native. The
wasm-gc adapter serializes the tessellated `DrawPath` mesh into a compact host
payload, and the browser runtime submits those vertices through the WebGPU
visual pipeline with the active transform, opacity, and clip state. Skipped
advanced commands are retained in the renderer's last fallback plan for
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
