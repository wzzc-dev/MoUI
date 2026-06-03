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
| Text | ready | ready | ready | Skia `Font` measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interior stabilization for both caret paths, and best-available glyph-run rendering clip to `TextRun.frame` while resolving `FontSpec` family, weight, style, and a representative emoji/non-ASCII coverage character through Skia `FontMgr` `FontFallbackRequest`/`Font`; real native renderer smoke covers glyph-run pixels and bounded `TextRun.frame` clipping; broader shaping is tracked separately. |
| Image | ready | ready | ready | Skia validates PNG/JPEG/BMP data URI decode, local PNG/JPEG/BMP decode, contain/cover/stretch placement geometry, `draw_image_rect` output, ready/failed lifecycle records, failed-image placeholders, immutable-source failed-cache reuse, and local-file failure retry once the file appears; the real native renderer smoke covers ready data URI/local PNG drawing and failed-image placeholders. |
| Clip | ready | ready | ready | Skia rectangular, rounded, and path clip scopes have representative real native smoke coverage. |
| Transform | partial | ready | partial | WGPU/Web fold affine transforms into planned vertices and scope state. Skia maps MoUI affine fields into Skia matrix members and has translated, scaled-and-clipped, layer-masked opacity, and filter-scoped pixel proof. |
| Opacity | ready | ready | ready | Skia save-layer opacity has blended pixel smoke coverage. |
| Layer compositing | ready | ready | ready | Skia validates `save_layer` opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter composition through renderer-local pixel tests plus the real native renderer smoke. |
| Blend mode | ready | ready | ready | Skia maps all MoUI blend modes to Skia paint blend modes and validates multiply through renderer-local pixels, with multiply/screen/overlay/darken/lighten output pixels also covered by the real native renderer smoke. |
| Filter effect | ready | ready | ready | Skia validates saturation and identity-normalized color matrix filters through renderer-local tests, with blur, saturation, brightness, contrast, and color matrix filters also covered by the real native renderer smoke. |
| Path/vector | ready | ready | ready | Skia replays `PathSpec` into native paths with renderer-local solid/gradient pixel tests and real native smoke coverage for solid/gradient fill and stroke output, plus quadratic and cubic curve verbs. |
| Shader effect | ready | ready | ready | Skia procedural solid, checker, linear-gradient-debug, and vignette effects have renderer-local pixel tests plus real native renderer pixel smoke coverage; unknown names still use fallback paths. |
| Text shaping | partial | partial | partial | Skia maps `FontSpec` family, weight, and style, builds `FontFallbackRequest` values with representative emoji/non-ASCII coverage characters before regular family matching, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interiors in both caret paths, retries emoji-family fonts for emoji-hint text on the system `FontMgr` path, can draw optional SkShaper shaped glyph runs after linking, and audits `skia_mbt` fallback/measurement/shaping descriptor resource plans through fallback-safe tests; SkParagraph-style line breaking, bidi, mixed-run fallback, and typography conformance remain follow-up work. |
| Emoji text | partial | partial | partial | Skia detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, emoji tag-sequence, Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark samples, and Hangul Jamo cluster samples, prefers emoji coverage characters in system `FontMgr` `FontFallbackRequest` matching, stabilizes representative cluster interior carets, and retries platform emoji font candidates before default-font fallback on the system `FontMgr` path; deterministic color emoji, grapheme shaping, and cross-platform font fallback conformance remain follow-up work. |
| Async image | partial | partial | partial | Renderer-neutral lifecycle records are shared. Native WGPU and Skia providers now expose renderer image-resource snapshots through `HostWindowRenderer`; Skia caches immutable failed sources with diagnostics before placeholder drawing, retries previously failed local-file sources once the file appears, and records disposed cached image resources during renderer disposal; Web renderer/backend diagnostics were refreshed on 2026-05-31; late native/general async repaint policy remains follow-up work. |

## Renderer Descriptors

Renderer identity is declared through `RendererDescriptor`, not by adding fixed fields
to app code or the internal view tree. Current descriptors are:

- `NativeWgpu`: family `Wgpu`, presentation `HostGpuSurface`, target `Native`.
- `WebGpuWasm`: family `WebGpu`, presentation `WebCanvas`, targets `WasmGc`
  and `Web`.
- `SkiaRasterNative`: family `Skia`, presentation `CpuPixelFrame`, target
  `Native`.

`RendererDescriptor` describes static renderer capability identity. Native host
runtime assembly is handled by platform renderer providers instead:
`backend/<platform>/wgpu` selects the `NativeWgpu` renderer family and
`backend/<platform>/skia` selects the `SkiaRasterNative` renderer family. The
`RendererSelection` helper remains useful for reports and tests that match
families or backend ids, but it is not a native host-core option or provider
contract. Web keeps using the WebGPU wasm backend; future Skia Web or Skia GPU
variants can add new `RendererBackendKind` values without changing the
capability record shape.

## Current Native Notes

Native wgpu now renders rects, rounded geometry, gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover/stretch fit modes, and
fallback handling.
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
fallback planner that reports unbalanced pops and open clip, rounded-clip,
transform, opacity, layer, and filter scopes while keeping visible `DrawPath`
commands out of the fallback list. Native color glyph
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
snapshots, and native WGPU providers forward those records through
`HostWindowRenderer::image_resources()` for host-visible diagnostics. Planned
image commands are marked loading until the native cache can resolve them;
successful synchronous decode/cache upload marks records ready with dimensions,
and failed decodes mark records failed with a diagnostic. Skia renderer-local
tests also pin `ImageFit::Contain` letterboxing, `ImageFit::Cover` UV crop
geometry, and `ImageFit::Stretch` full-frame sampling before `draw_image_rect`
submits the source/destination rects.

## Current Skia Raster Notes

`render/skia` is a native-only renderer package over the editable
`wzzc-dev/skia_mbt` checkout. It exposes `SkiaRasterRenderer`,
`SkiaPixelFrame`, `SkiaPresentTarget`, `SkiaFontResolution`, `renderer_descriptor()`,
backend info, fallback-safe availability checks, a basic Skia-backed text
system, image resource snapshots that native Skia providers forward through
`HostWindowRenderer`, cached-image disposal diagnostics, and diagnostics for
unsupported commands. Unmatched, mismatched, and frame-end unclosed canvas
scopes are treated as unsupported diagnostics and ignored or restored at the
frame boundary instead of restoring past the frame-root canvas scope. In
fallback builds `skia_available()`
returns `false`, renderer creation raises `SkiaUnavailable`, and platform Skia
entrypoints preflight availability before handing control to host app assembly,
so explicit Skia selection exits with a diagnostic instead of opening a blank
window. Windows and Linux host options now expose the same renderer-neutral
first-frame auto-exit hook used by the Skia entrypoints for matching-host
runtime smoke runs; those logs prove presentation only for the host that
produced them.

When real Skia is linked, the renderer creates a CPU `raster_n32_premul` surface
using physical pixels through `skia_mbt`'s `SurfaceTargetDescriptor` and
`Surface::for_target` value-layer surface contract, scales the canvas by the
host scale factor so MoUI commands remain in logical coordinates, draws the
command stream, finalizes the surface through `Surface::flush_and_submit`,
reads pixels back into `SkiaPixelFrame`, and calls the platform presenter. The
fallback-safe `raster_surface_preflight` diagnostic summarizes the same
`skia_mbt` surface/frame/finalization resource plans so MoUI can audit the
Skia raster target contract even when real native Skia is not linked. The
fallback-safe `skia_text_descriptor_preflight` similarly consumes the
`FontFallbackRequest`, `TextMeasurementDescriptor`, `TextShapingDescriptor`,
`ShapedTextRunDescriptor`, and `ShapedGlyphRunDescriptor` resource plans as
cache-key evidence for the current Skia text path. The companion
`text maturity audit partial` backend-info summary keeps audited Skia text
baseline checks separate from tracked gaps for bidi, paragraph line breaking,
mixed-run fallback, deterministic color emoji, and full grapheme parity; neither
diagnostic replaces the existing MoUI draw-command replay or proves full shaping
parity. macOS presents
the frame through a `CGImage` on a `CALayer`, Windows through a top-down BGRA
DIB and `StretchDIBits`, and Linux through the local `window/linux`
`Window::present_rgba_pixels` `wl_shm` presenter.

The current real Skia smoke uses JetBrains Skia link flags to render and read
back a representative frame through `SkiaRasterRenderer`. It validates clear,
rect fill/stroke, rounded fill/stroke, linear-gradient fills and strokes, soft rounded
shadows, rectangular and rounded clips, affine translation and scaled scoped
clip, transformed layer opacity masks, transformed filter scopes, opacity, layer
opacity with rectangular and rounded masks, nested layer/filter composition,
multiply/screen/overlay/darken/lighten blending,
blur/saturation/brightness/contrast/color-matrix filters, color-matrix short/long
payload normalization, solid and gradient
paths including quadratic and cubic curve verbs, the solid, checker,
linear-gradient-debug, and vignette shader effects, PNG/JPEG/BMP data URI
decode, local PNG/JPEG/BMP decode, contain/cover/stretch image placement geometry,
local PNG image drawing, immutable
failed-image placeholders plus local-file retry recovery, basic text glyph-run pixels, bounded
`TextRun.frame` clipping, and optional SkShaper availability when the smoke is
run with `--enable-skshaper`, while requiring
`unsupported_command_count == 0`. Focused Skia renderer white-box tests also
cover unmatched and mismatched scope-pop diagnostics. Native Skia provider
packages expose the same
renderer image-resource snapshot records through `HostWindowRenderer`, so host
diagnostics can inspect loading, ready, failed, and disposed image resources
without importing `render/skia`; renderer tests cover JPEG/BMP data URI and
local-file decode, contain/cover/stretch source/destination placement, immutable
failed-cache reuse, and local-file retry once a missing file appears.
Remaining Skia renderer gaps are now narrower: complex text shaping. Basic text
measurement/drawing uses Skia `FontMgr`/`Font` with `FontSpec` family, weight,
style selection, `FontFallbackRequest` matching over a representative
emoji/non-ASCII coverage character before regular family matching, Skia font
metrics for baseline/height, shaped-run cluster carets when SkShaper is linked
or Skia-measured prefix carets otherwise, representative
combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interior
stabilization for both caret paths, SystemFontMgr-only emoji font retry for
emoji-hint text, optional SkShaper shaped glyph runs for rendering when linked,
and fallback-safe descriptor preflight coverage for the Skia fallback,
measurement, shaping, shaped-run, and shaped-glyph resource plans. The renderer
also exposes a fallback-safe text maturity audit in backend info, counting the
audited baseline separately from the same bidi, paragraph, mixed-run, color
emoji, and full-grapheme gaps. The renderer
clips aligned text glyphs to each
`TextRun.frame`; fallback-safe white-box tests cover the placement contract, and
the opt-in real-Skia smoke verifies that long glyph runs do not leak outside
narrow text frames when native Skia is linked.
SkParagraph-style line breaking, bidi, broader typography, deterministic color
emoji, grapheme shaping, and cross-platform emoji fallback conformance remain
partial and separate from the WGPU Moon Cosmic provider stack. The macOS Skia
provider now matches Windows and Linux by defaulting to
`SkiaFontResolution::SystemFontMgr`, so normal Showcase, Markdown Editor, and
Mo Workbench Skia entrypoints use the system FontMgr path with platform font
lookup, emoji retry, and optional SkShaper when linked. macOS first-frame smoke
entrypoints explicitly switch to `SkiaFontResolution::EmptyTypeface` only when
their exit-after-first-present environment flag is set; that keeps CLI smoke
runs on the safer default-font retry path while preserving the normal app
default. The renderer smoke also uses the system FontMgr path so real Skia font
and optional SkShaper coverage remain tracked.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, text, and loaded
images through WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph
atlas before the glyphs are composited by WebGPU. Images are cached as WebGPU
textures, support contain/cover/stretch fit, and use a deterministic fallback color
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
uses a backdrop-sampling WebGPU pass for exact semantics. The advanced shader
uses explicit-LOD texture sampling for blur and backdrop reads so Chrome's
WGSL validator accepts filter and overlay paths whose command kind varies per
fragment input, and the browser runtime forwards WebGPU uncaptured/device-lost
errors into the page log so browser presentation evidence fails on shader or
pipeline validation errors instead of silently relying on a nonblank screenshot.
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
