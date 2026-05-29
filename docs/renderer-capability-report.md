# Renderer Capability Report

This page tracks draw command coverage by renderer backend. The same status
data is codified in `render/capabilities.mbt` and checked by
`render/capabilities_test.mbt`. Showcase consumes the same backend list, so new
renderer columns come from structured data instead of hard-coded native/web
fields. Renderer support claims still come from this report plus
renderer/provider tests.

Status meanings:

- `ready`: implemented directly by the renderer.
- `partial`: visible support exists, but follow-up work remains.
- `gap`: no visible implementation yet.
- `host-forwarded`: MoonBit forwards the command to the browser WebGPU host
  without local runtime coverage.
- `unavailable`: the backend has a contract or planned mapping, but cannot be
  claimed ready in the current fallback-safe build.

| Feature | Native wgpu | Skia raster native | Web wasm-gc | Follow-up |
| --- | --- | --- | --- | --- |
| Rect | ready | ready | ready | Skia rect fill/stroke has real native renderer pixel smoke coverage. |
| Rounded rect | ready | ready | ready | Skia rounded fill/stroke and solid rounded brushes have real native renderer pixel smoke coverage. |
| Gradient | ready | ready | ready | Skia linear-gradient fills and strokes for rounded rects and paths have real native renderer pixel smoke coverage. |
| Shadow | ready | ready | ready | Skia soft rounded shadows use `MaskFilter` blur and have real native renderer pixel smoke coverage. |
| Text | ready | ready | ready | Skia basic `Font` measurement and `draw_text_utf8` rendering resolve `FontSpec` family, weight, and style through Skia `FontMgr`/`Font`, with real native renderer smoke evidence; shaping is tracked separately. |
| Image | ready | ready | ready | Skia validates PNG data URI and local PNG decode, `draw_image_rect` output, ready/failed lifecycle records, and failed-image placeholders in the real native renderer smoke. |
| Clip | ready | ready | ready | Skia rectangular, rounded, and path clip scopes have representative real native smoke coverage. |
| Transform | partial | ready | partial | WGPU/Web fold affine transforms into planned vertices and scope state. Skia maps MoUI affine fields into Skia matrix members and has translated, scaled-and-clipped, layer-masked opacity, and filter-scoped pixel proof. |
| Opacity | ready | ready | ready | Skia save-layer opacity has blended pixel smoke coverage. |
| Layer compositing | ready | ready | ready | Skia validates `save_layer` opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter composition in the real native renderer smoke. |
| Blend mode | ready | ready | ready | Skia maps all MoUI blend modes to Skia paint blend modes and validates multiply, screen, overlay, darken, and lighten output pixels in the real native renderer smoke. |
| Filter effect | ready | ready | ready | Skia validates blur image filters plus saturation, brightness, contrast, and color matrix color filters in the real native renderer smoke. |
| Path/vector | ready | ready | ready | Skia replays `PathSpec` into native paths with solid/gradient fill and stroke smoke coverage, plus quadratic and cubic curve verbs. |
| Shader effect | ready | ready | ready | Skia procedural solid, checker, linear-gradient-debug, and vignette effects have real native renderer pixel smoke coverage; unknown names still use fallback paths. |
| Text shaping | partial | partial | partial | Skia maps `FontSpec` family, weight, and style for basic `Font` measurement/drawing after linking, but SkShaper/SkParagraph-style shaping, bidi, line breaking, and typography conformance remain follow-up work. |
| Emoji text | partial | partial | partial | Skia emoji behavior depends on platform font fallback and future shaping coverage; native WGPU/Web also retain grapheme/color-emoji gaps. |
| Async image | partial | partial | partial | Renderer-neutral lifecycle records are shared. Skia image lifecycle has data URI, local-file, and failed-image placeholder evidence; late async repaint remains follow-up work. |

## Renderer Specs

Renderer identity is declared through `RendererSpec`, not by adding fixed fields
to app code or `ViewSpec`. Current specs are:

- `NativeWgpu`: family `Wgpu`, presentation `HostGpuSurface`, target `Native`.
- `WebGpuWasm`: family `WebGpu`, presentation `WebCanvas`, targets `WasmGc`
  and `Web`.
- `SkiaRasterNative`: family `Skia`, presentation `CpuPixelFrame`, target
  `Native`.

Native platform backends resolve `RendererSelection::Default` to `NativeWgpu`.
`Backend(SkiaRasterNative)` and `Family(Skia)` opt into Skia raster. Web keeps
using the WebGPU wasm backend; future Skia Web or Skia GPU variants can add new
`RendererBackendKind` values without changing the capability record shape.

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

## Current Skia Raster Notes

`render/skia` is a native-only renderer package over the editable
`wzzc-dev/skia_mbt` checkout. It exposes `SkiaRasterRenderer`,
`SkiaPixelFrame`, `SkiaPresentTarget`, `renderer_spec()`, backend info,
fallback-safe availability checks, a basic Skia-backed text system, image
resource snapshots, and diagnostics for unsupported commands. In fallback builds
`skia_available()` returns `false`, renderer creation raises `SkiaUnavailable`,
and platform backends reject explicit Skia selection before opening a blank
window.

When real Skia is linked, the renderer creates a CPU `raster_n32_premul` surface
using physical pixels, scales the canvas by the host scale factor so MoUI
commands remain in logical coordinates, draws the command stream, reads pixels
back into `SkiaPixelFrame`, and calls the platform presenter. macOS presents the
frame through a `CGImage` on a `CALayer`, Windows through a top-down BGRA DIB and
`StretchDIBits`, and Linux through the local `window/linux` `wl_shm` presenter.

The current real Skia smoke uses JetBrains Skia link flags to render and read
back a representative frame through `SkiaRasterRenderer`. It validates clear,
rect fill/stroke, rounded fill/stroke, linear-gradient fills and strokes, soft rounded
shadows, rectangular and rounded clips, affine translation and scaled scoped
clip, transformed layer opacity masks, transformed filter scopes, opacity, layer
opacity with rectangular and rounded masks, nested layer/filter composition,
multiply/screen/overlay/darken/lighten blending,
blur/saturation/brightness/contrast/color-matrix filters, solid and gradient
paths including quadratic and cubic curve verbs, the checker shader effect,
vignette shader effect, PNG data URI and local PNG image drawing, failed-image
placeholders, and basic text
pixels while requiring `unsupported_command_count == 0`. Remaining Skia
renderer gaps are now narrower: complex text shaping. Basic text
measurement/drawing uses Skia `FontMgr`/`Font` with `FontSpec` family, weight,
and style selection, while complex shaping, bidi, line
breaking, and deterministic emoji behavior remain partial and separate from the
WGPU Moon Cosmic provider stack.

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
