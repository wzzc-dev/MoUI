# Renderer Capability Report

This page describes draw-command coverage for concrete renderer providers. The
live report is built from the provider array registered by a composition root;
its index is `RendererProvider.id`, never `RendererBackendKind`. The latter is
kept solely as diagnostic classification metadata. The historical grouped table
below remains a readable product summary, not a central selection matrix.
Showcase receives the composition root's provider list and renderer support
claims still require this report plus provider tests. The current product order
is native Skia, WebGPU with Canvas2D fallback, native WGPU diagnostics, then
Sun CPU raster.

**Sun CPU raster is an experimental renderer (ADR 0023).** It is not part of
the product `auto` selection, is not registered in default composition roots,
and makes no usability/performance claim. New draw-command capabilities are
not required to be implemented in sun; it only needs to keep compiling and
passing its renderer-local and neutral host-binding tests.

Platform readiness is tracked separately from renderer capability. A macOS
Skia smoke log can support a macOS-only runtime note, but it does not upgrade
Windows/Linux platform status and does not promote global Skia typography or
native paragraph/bidi readiness without matching-host smoke logs.

**Terminal cell ANSI (`tui-ansi`) is an experimental output path.** It draws no
pixels: it projects `DrawFrame.semantics` onto an equal-width cell grid and
writes ANSI deltas to a host-supplied byte sink. Its column is checked in code
by `@render_tui.tui_feature_capabilities()`, and the `gap` cells are honest
gaps rather than fallbacks — a cell grid has no gradient, shadow, transform or
vector path, so those records are dropped with a degrade diagnostic instead of
being quietly approximated. The path is not part of the product `auto`
selection, is registered only by composition roots that name it explicitly, and
makes no pixel-fidelity claim. What it does claim is interaction fidelity:
focus traversal, bordered-list selection, tree folding, immediate keypress,
mouse click/wheel and resize reflow are proven inside a real PTY by the
`tui.pty-interaction-smoke` gate (`smoke/gates.json`).

Status meanings:

- `supported`: implemented directly by the renderer.
- `partial`: visible support exists, but follow-up work remains.
- `gap`: no visible implementation yet.
- `host-forwarded`: MoonBit forwards the command to the browser WebGPU host
  without local runtime coverage.
- `unavailable`: the backend has a contract or planned mapping, but cannot be
  claimed supported in the current fallback-safe build.

| Feature | Skia raster native | Web wasm-gc | Native wgpu diagnostic | Sun CPU raster | Terminal cell ANSI | Native direct GPU | Follow-up |
| --- | --- | --- | --- | --- | --- | --- |
| Rect | supported | supported | supported | supported | supported | supported | Skia rect fill/stroke has real native renderer pixel smoke coverage. |
| Rounded rect | supported | supported | supported | supported | partial | supported | Skia rounded fill/stroke and solid rounded brushes have real native renderer pixel smoke coverage. |
| Gradient | supported | partial | partial | supported | gap | supported | Skia now renders linear and radial gradient brushes for rounded rects and paths; browser WebGPU and native WGPU diagnostics both preserve radial rounded/path brush payloads and shade radial interpolation in the visual shader. Web stays partial until Web renderer smoke records real radial center/mid/edge pixels; native WGPU keeps the same requirement only for its diagnostic smoke. |
| Shadow | supported | supported | supported | supported | gap | partial | Skia soft rounded shadows use `MaskFilter` blur and have real native renderer pixel smoke coverage. Metal direct now evaluates the same profile in the fragment: coverage is `0.5 * erfc(d / (sigma * sqrt 2))` over the shape's rounded-box distance field with sigma = `blur_radius` — Skia's reading, since it hands `radius` to `ImageFilter::blur` — with the quad grown 3 sigma for tail room. Before that it filled the grown box solid to 2 sigma and ramped the last one, which a 12-pixel mark at blur 8 showed as a 255 slab reaching eight pixels outside the shape and a 76-level step at the box rim; the device test now pins the curve (half at the edge, ~16% one sigma out, monotone to three sigma, no single-pixel step). It stays partial because the field is one-sided — a shape thinner than its blur reads brighter at its centre than Skia's two-sided sum — corners follow the SDF rather than an exact 2-D convolution. The shadow's source is a `RoundedRect` by contract — `ShadowSpec` carries a rect, colour, offset, blur and spread — so there is no path- or texture-shaped shadow in the command model to approximate. That also means the two diagnostic routes disagree here: `moui_wgpu_renderer` keeps the old ramp, and its note still describes the shared formulation. |
| Text | supported | supported | supported | supported | supported | partial | Skia `Font` measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/Hangul-Jamo/keycap/emoji-modifier/VS/ZWJ/regional-indicator-pair/emoji-tag/prepend-mark cluster interior stabilization for both caret paths, grapheme-safe mixed-run fallback segments, and best-available glyph-run rendering clip to `TextRun.frame` while resolving `FontSpec` family, weight, style, representative coverage characters, and inferred fallback language tags through Skia `FontMgr` `FontFallbackRequest`/`Font`; real native renderer smoke covers glyph-run pixels and bounded `TextRun.frame` clipping; broader shaping is tracked separately. Metal direct packs provider coverage into shelf-packed 1024x1024 RGBA8 pages that grow lazily: the item word that already named a texture now names the page to bind, so a glyph run whose glyphs no longer fit one page becomes one draw per page, and neither the 76-byte vertex nor the text shader mentions pages. Capacity is a capped four pages with clear-and-rebuild past the cap rather than per-glyph eviction — a text-light route still costs one 4 MB buffer and one 4 MB texture, because page 0 is the only one allocated at construction. The ceiling is measured through the real provider rather than asserted: ~818 distinct 14pt ideographs per page at device scale 2.0, and the smoke's 1,600-distinct-ideograph frame builds as two text items with zero dropped glyphs where the same frame pinned at one page reported 782 drops. |
| Image | supported | supported | supported | supported | gap | supported | Skia validates PNG/JPEG/BMP data URI decode, local PNG/JPEG/BMP decode, contain/cover/stretch/scale-down/fit-width/fit-height placement geometry, `draw_image_rect` output, ready/failed lifecycle records, failed-image placeholders, immutable-source failed-cache reuse, and local-file failure retry once the file appears; Sun renderer-local tests now cover JPEG data URI and local-file decode through the `mizchi/image` adapter plus the same contain/cover/stretch/scale-down/fit-width/fit-height placement and source-crop geometry; the real native renderer smoke covers ready data URI/local PNG drawing and failed-image placeholders. `ImageRun.src_rect` names one cell of a sprite or tile atlas in *source pixel* coordinates: it is clamped by the shared `@render_common.image_src_window`, mapped onto `ImageRun.frame` as-is with `fit` ignored, and a window with no overlap with the decoded image skips the draw instead of falling back to the whole image. Skia, Sun and native WGPU implement it, each pinned by a placement wbtest ("skia image placement maps an atlas source window over the fit geometry", "sun image placement maps an atlas source window to a pixel rect", "native image placement maps an atlas source window to uv fractions"); Web wasm-gc ignores it because the `host_draw_image` ABI carries only `fit`, which is the follow-up there. |
| Clip | supported | supported | supported | supported | supported | partial | Skia rectangular, rounded, and path clip scopes have representative real native smoke coverage. Sun CPU raster applies transformed rectangular clip bounds through `moui_sun` clip state and validates 2x rectangular/rounded clip pixels with inverse-transform rounded masking. |
| Transform | supported | partial | partial | supported | gap | partial | WGPU/Web fold affine transforms into planned vertices and scope state. Skia maps MoUI affine fields into Skia matrix members and has translated, scaled-and-clipped, layer-masked opacity, and filter-scoped pixel smoke coverage. Sun CPU raster now keeps transform/clip state across layer, rounded-clip, and filter offscreen scopes. |
| Opacity | supported | supported | supported | supported | partial | partial | Skia save-layer opacity has blended pixel smoke coverage. |
| Layer compositing | supported | supported | supported | supported | partial | partial | Every frame carries complete `BeginRetainedLayer(spec)` payloads through `EndRetainedLayer(key)`. Skia and Sun keep renderer-local picture/pixel caches and decide hit, update, and eviction; runtime and host backends keep no residency mirror or command-cache fallback. Metal direct renders each group into its own offscreen target and composites it back, and a `BeginRetainedLayer` boundary is kept across frames: the host pools one pass target per slot, so a boundary that claims the same slot at the same device rect in the frame after the one that painted it composites that texture instead of rebuilding the group, with `retained_layers_cached` / `retained_layers_rebuilt` / `retained_layers_updated` / `retained_layers_evicted` recording which happened. It stays partial because that reuse is the pass pool rather than a picture or pixel cache: an entry is valid only for the frame immediately after, at the same slot and rect; content fidelity is delegated to `content_revision`; and entries are aged, never capped or prioritised. The boundary emitters are the showcase's diagnostics panels (`examples/showcase/app/diagnostics/components.mbt:24,32,80`) — `macos_metal`'s own first frame lands on `Components/welcome` (`examples/showcase/app/workspace.mbt:84-86`), which has none. |
| Blend mode | supported | supported | supported | supported | gap | partial | Skia maps all MoUI blend modes to Skia paint blend modes and validates multiply through renderer-local pixels, with multiply/screen/overlay/darken/lighten output pixels also covered by the real native renderer smoke. Metal direct reaches five of the six through fixed-function state (overlay is counted as unsupported) and is exact only over an opaque destination, which its report counts separately. |
| Filter effect | supported | supported | supported | supported | gap | partial | Skia validates saturation and identity-normalized color matrix filters through renderer-local tests, with blur, saturation, brightness, contrast, and color matrix filters also covered by the real native renderer smoke. Sun CPU raster validates transformed filter scopes after offscreen canvases inherit parent transform/clip state. Metal direct applies the group-scoped filter while compositing its own target, and its blur is separable with sigma equal to the requested radius — the same reading `moui_skia_renderer` uses: a horizontal pass into a second offscreen target, then a vertical read at the composite, thirteen taps an axis spaced `max(sigma/6, 1)` pixels so a bigger radius really is a wider blur (a sigma-16 edge measures 212/119/32/10 against the ideal 214/128/40/17; before the spacing it read 255/122/0/0, because the taps could not reach past 12 pixels whatever the radius asked for). The route's device test asserts a profile rather than a value: light has to reach past a two-pixel mark on both axes, the falloff has to be non-increasing away from it in each direction, and a sample eight pixels out must not out-shine the ones nearer the mark. That last claim is what the earlier kernel could not pass — measured before this leg, the spaced tap echoed the group at +-radius instead of blurring it (128 at the mark, six empty pixels, then 64 again at +8). The row stays partial because the support truncates near 2 sigma, the intermediate is an 8-bit texture so a wide blur quantises twice, there is no backdrop to filter, and the colour filters run on un-premultiplied colour where WGPU does not. |
| Path/vector | supported | supported | supported | supported | gap | supported | Skia replays `PathSpec` into native paths with renderer-local solid/gradient pixel tests and real native smoke coverage for solid/gradient fill and stroke output, plus quadratic and cubic curve verbs. WGPU/Web share the MoonBit tessellator, preserve path brush payloads, and submit radial path vertices through the visual shader instead of flattening radial brushes to a single sampled color. |
| Shader effect | supported | supported | supported | supported | gap | partial | Skia procedural solid, checker, linear-gradient-debug, and vignette effects have renderer-local pixel tests plus real native renderer pixel smoke coverage; unknown names still use fallback paths. Sun CPU raster now records the same unsupported-command diagnostic shape when an unknown shader name falls back to the spec fallback brush. Metal direct draws the four built-in names per fragment (checker cells and vignette radii follow Skia and Sun, the two colours come from the spec's own `fallback` brush); it has no shader registry, so an app-defined name still paints that fallback brush and is counted in `shader_effects_fallback_painted`. |
| Text shaping | supported | supported | supported | partial | partial | host-forwarded | Skia maps `FontSpec` family, weight, and style, builds `FontFallbackRequest` values with representative emoji/non-ASCII coverage characters plus inferred BCP47 script language tags before regular family matching, splits mixed-script text into grapheme-safe fallback segments for per-run `FontMgr` resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, stabilizes cluster interiors through the shared UAX-style `TextGraphemeBoundaries` scanner, exposes `TextSystem::layout_paragraph()` line metrics, paragraph caret rectangles, selection rectangles, and hit-test geometry, routes paragraph layout through native SkParagraph when available, retries emoji-family fonts for emoji-hint text on the system `FontMgr` path, and can draw optional SkShaper shaped glyph runs after linking. Sun raster exposes a renderer-backed `TextSystem` over `moui_sun/text` with requested-family-first fallback chain resolution across registered faces; renderer-local tests cover mixed Latin-plus-emoji measurement, no missing fallback diagnostic on covered draws, TextRun frame clipping, and paragraph metadata. The shared scanner uses generated Unicode 17.0 property predicates, `moui/core` runs curated and full vendored Unicode 17.0 default grapheme fixtures, and `moui_skia_renderer` runs the same fixture through `skia_grapheme_cluster_texts`. The real Skia smoke obtains bidi Arabic and mixed-direction visual-order markers plus paragraph wrapping, selection rectangles, hit testing, grapheme editing, and IME candidate/composition markers on macOS/Linux/Windows via `--run-text-emoji-smoke`. |
| Emoji text | supported | supported | supported | partial | partial | partial | Skia detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, emoji tag-sequence, Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark samples, and Hangul Jamo grapheme cluster samples, prefers emoji coverage characters and inferred language tags in system `FontMgr` `FontFallbackRequest` matching, stabilizes representative cluster interior carets, retries platform emoji font candidates before default-font fallback, and reports deterministic color emoji readiness through `Typeface::has_color_glyphs` and glyph format metadata. Sun raster uses `moui_sun/text FontFallbackPlan` over the requested-family-first fallback chain so registered emoji coverage can be selected after a Latin primary face; renderer-local tests cover mixed Latin-plus-emoji measurement and covered draw diagnostics. The text/emoji smoke records high-saturation glyph/raster observation plus font/glyph metadata with a non-empty source/script/fallback-request-character-aware glyph key that matches the recorded source, text-system, shaper, script, fallback language tag payload, language-count, fallback request character, and format metadata, and obtains keycap, regional-indicator, and skin-tone-modifier fallback diagnostic markers on macOS/Linux/Windows via `--run-text-emoji-smoke`. Metal direct keeps a colour glyph's own pixels through every group case it has — plain composite, brightness filter, rect mask, rounded mask and two nested groups (`metal_text_wbtest.mbt`) — and those five probes share one mechanism (the colour branch is taken at the vertex, so a composite cannot re-tint it), which is recorded as widened scope rather than a new path; the smoke now walks that evidence at 24, 32 and 48pt per sample and through a layer composite as well (1011 and 2290 inked at 32 and 48pt, 993 and 2240 of them green, 2098 inked inside a group, noop control 0 everywhere); the row stays partial because that evidence samples the matrix rather than covering it (Retina read-back colour is one run per sample on the main pass; the sizes and the group composite are read at scale 1.0) and because whether a codepoint arrives as colour at all is the shared provider's `kCTFontColorGlyphsTrait` decision. |
| Async image | supported | supported | supported | supported | gap | partial | Renderer sessions emit tokenized `RendererImageLoadRequest` events. Backend image owners schedule/cancel byte I/O only, return the same token in `ImageResourceLoadCompletion`, and request redraw only when the session applies the completion. Skia, Sun, WGPU, and Web own decode/resource/cache state; stale and disposed tokens are inert. Metal direct drives the shared lifecycle record and installs the completion's RGBA8 as the texture the next frame samples, pinned by two-frame renderer-local tests with an injected source. A completion arriving mid-frame through a real window's event loop has never been observed on this route: exactly one entrypoint in the repository installs a starter — `examples/momark/macos_skia/main.mbt:24`, on the Skia route — and the starter defers `https:` sources only, so a local file or `data:` URI completes inline everywhere else, where backends take the synchronous `immediate` default. Closing the Metal half needs a release line to publish this module (registered `publication: public` at `checks/release-modules.json:68`, still untracked here) so that network-image submodule app can bind it, plus a Metal variant of that app: a release-line and product decision, not renderer code. The ordering itself is covered at the backend with injected spawn/post hooks. |

## Renderer Descriptors

Renderer identity is declared through `RendererDescriptor`, not by adding fixed fields
to app code or view/runtime trees. Current descriptors are:

- `NativeWgpu`: family `Wgpu`, presentation `HostGpuSurface`, target `Native`.
- `WebGpuWasm`: family `WebGpu`, presentation `WebCanvas`, targets `WasmGc`
  and `Web`.
- `SkiaRasterNative`: family `Skia`, presentation `CpuPixelFrame`, target
  `Native`.
- `SkiaGpuNative`: family `Skia`, presentation `HostGpuSurface`, target
  `Native`.
- `SunRasterNative`: family `Sun`, presentation `CpuPixelFrame`, target
  `Native`.
- `TerminalAnsiNative`: family `Terminal`, presentation `ExternalSurface`,
  target `Native`, provider id `tui-ansi`.

For feature proof coverage (which CI job proves each feature), see
[feature-proof-matrix.md](feature-proof-matrix.md) and
[feature-status-dashboard.md](feature-status-dashboard.md).

`RendererDescriptor` describes static diagnostic identity. Runtime assembly is
handled by application-owned renderer providers: `@render_skia.from_env(platform=...)`
registers GPU then raster for `auto`, `@render_wgpu.native(...)` is an explicit
diagnostic composition, and `@webgpu_adapter.from_env()` registers WebGPU
followed by Canvas2D. `RendererSelection` remains useful for
diagnostics and tests, but it is not a host-core assembly or capability-report
index.

The Skia binding has explicit Metal, D3D12, Vulkan, and EGL/GLES window-surface
source paths, while `moui_skia_renderer` reports route preflight diagnostics. The macOS real
Skia helper can add `--run-gpu-smoke`, which requires the renderer smoke log to
include `MoUI Skia GPU Metal renderer smoke passed route=metal-gpu
surface_gpu=true present_count=1 pixel-markers`; that marker proves explicit
GPU route creation, GPU-backed offscreen surface rendering, readback, and the
existing pixel-present callback. In the same helper, `--run-gpu-smoke` also
sets `MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu` for Showcase first-frame runs,
and its log must include `surface_route=metal-gpu;
surface_gpu=true` provider diagnostics before the normal first-frame marker.
The renderer-only GPU smoke remains offscreen/readback evidence only. The
macOS first-frame smoke additionally proves `SkPicture` handoff to a native
worker that owns the Ganesh/Metal context, acquires a `CAMetalDrawable`, replays,
flushes, presents, and emits `Presented` without calling `read_pixels`.
The same worker owns D3D12 swapchains/fences, Vulkan acquire/render-finished
synchronization, and EGL contexts/surfaces in the other native providers.
Android and HarmonyOS cross-build those paths; iOS simulator selects the Metal
GPU route. Product `auto` defaults to `SkiaGpuNative` on every native Skia
platform when the host GPU surface is available. Windows/Linux and physical
mobile seven-gate quality manifests may still be incomplete.

## Current Native WGPU Diagnostic Notes

Native wgpu remains available as a diagnostic renderer. It now renders rects,
rounded geometry, linear gradients, soft shadows,
glyph-atlas text, and images directly. Image commands use a complete pipeline:
PNG/JPEG/BMP decoding through `mizchi/image`, local file and base64 data URI
sources, texture caching, GPU sampling, contain/cover/stretch/scale-down/fit-width/fit-height fit
modes, and fallback handling.
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
supported through the renderer text-system contract: `core/` keeps a deterministic fallback `TextSystem` with
representative variation-selector, combining-mark, emoji modifier, keycap, ZWJ,
regional-indicator, tag-sequence, prepend-mark, script-mark, and Hangul Jamo
cluster interior caret stabilization and basic left/right caret movement over
the same representative boundaries,
`moui_wgpu_renderer` owns provider validation and atlas upload, including rejection of
non-empty run-layout caret arrays that do not cover the input text,
`moui_text_providers/cosmic_text` owns the native Cosmic
provider, macOS composes a CoreText-backed platform text engine with Cosmic
fallback for measurement and glyph rasterization, and native platform providers
share `moui_text_providers/text_protocol` for UTF-32 input encoding, versioned
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
fontconfig/FreeType provider with Cosmic fallback. The Linux provider can emit
native FreeType RGBA glyphs for explicit emoji-family runs when Noto Color Emoji
is available, but general measurement, shaping, and non-emoji raster data still
fall back to Cosmic until the full fontconfig/HarfBuzz path is implemented. Web
injects a Canvas-backed text system that uses the same CSS `system-ui` family
stack as text drawing.
Fallback composition is explicit at the backend/provider boundary; the
`moui_wgpu_renderer` package validates provider responses but does not depend on the
Cosmic provider package. Diagnostic text conformance covers deterministic emoji
measurement and caret invariants for single-codepoint, variation-selector, and
ZWJ samples, plus core fallback cluster-safe caret geometry and movement for
representative combining-mark, emoji modifier, keycap, regional-indicator,
tag-sequence, prepend-mark, script-mark, and Hangul Jamo samples; Cosmic run-layout tests also
assert glyph output plus monotonic caret coverage through the provider-safe
mapped layout path, and focused Cosmic
tests cover platform emoji fallback font loading and emoji codepoint resolution
when such a font is available. Bidi reordering, paragraph line breaking,
deterministic color emoji, native emoji fallback, and provider shaping evidence
are represented by the text/emoji proof matrix rather than renderer capability
blockers.
The cross-package text boundary is documented in [Text system](text-system.md).
Native image support is asynchronous at the session boundary. A renderer emits
an opaque image request token; backend image tasks read raw bytes and return a
completion with the same token. `apply_image_load_completion` returns `true`
only when the session accepted the current request, so stale, duplicate, and
disposed completions cannot roll back status or cause a duplicate redraw.
`HostImageSource` never decodes or caches images. The selected
`RendererProvider` contributes a renderer-owned `RendererImageDecoder`;
Skia, Sun, and WGPU perform their own format detection, decode, cache update,
and ready/failed completion creation. Native host cores drain session events,
schedule cancellable byte I/O, and return the same request token; they do not
baseline a presented revision or own a neutral loader. Package tests cover
token completion/repaint sequencing, while matching-host runtime smoke remains
separate. Sun
renderer-local tests also cover JPEG data URI/local-file decode,
`ImageFit::Contain` letterboxing, `ImageFit::Cover` source crops,
`ImageFit::Stretch` full-frame sampling, `ImageFit::ScaleDown`
natural-size-or-contain placement, `ImageFit::FitWidth/FitHeight` axis-locked
placement/cropping, and async local-file failure retry after the file appears,
keeping the retry behavior aligned with Skia's local-file path. Skia renderer-local
tests also pin `ImageFit::Contain` letterboxing,
`ImageFit::Cover` UV crop geometry, `ImageFit::Stretch` full-frame sampling,
`ImageFit::ScaleDown` natural-size-or-contain placement, and
`ImageFit::FitWidth/FitHeight` axis-locked placement/cropping before
`draw_image_rect` submits the source/destination rects.
`ImageRun.src_rect` is the atlas path, kept outside those fit modes: a caller
that names a source cell has already decided what to sample, so `fit` is
ignored and the run maps that window onto `frame` directly. Skia, Sun and WGPU
clamp it through the one shared `@render_common.image_src_window`, so "the
window does not meet the decoded image" means "draw nothing" in all three
rather than each renderer choosing its own fallback.

## Current Skia Raster Notes

`moui_skia_renderer` is a native-only renderer package over the editable
`wzzc-dev/moui_skia` checkout. It exposes `SkiaRasterRenderer`,
`SkiaPixelFrame`, `SkiaPresentTarget`, `SkiaFontResolution`,
`SkiaUnsupportedCommandDiagnostic`, `renderer_descriptor()`, backend info,
fallback-safe availability checks, a basic Skia-backed text system,
renderer-local image resources, tokenized completion diagnostics, and structured
unsupported-command
diagnostics with command/reason payloads. The
`unsupported_command_count()` accessor remains the count summary, while
`unsupported_command_diagnostics()` returns the per-frame command/reason list.
Unmatched, mismatched, and frame-end unclosed canvas
scopes are treated as unsupported diagnostics and ignored or restored at the
frame boundary instead of restoring past the frame-root canvas scope. In
fallback builds `skia_available()`
returns `false`, renderer creation raises `SkiaUnavailable`, and platform Skia
entrypoints preflight availability before handing control to host app assembly,
so explicit Skia selection exits with a diagnostic instead of opening a blank
window. Windows and Linux host smoke options expose the same renderer-neutral
first-frame auto-exit hook used by tester/backend smoke runners; those logs
record presentation only for the host that produced them. Linux Skia is the native Linux Preview Ready route for renderer
and text observation; the Linux native WGPU/fontconfig provider remains diagnostic
and must not be cited as Skia-route readiness.

When real Skia is linked, the renderer creates a CPU `raster_n32_premul` surface
using physical pixels through `moui_skia`'s `SurfaceTargetDescriptor` and
`Surface::for_target` value-layer surface contract, scales the canvas by the
host scale factor so MoUI commands remain in logical coordinates, draws the
command stream, finalizes the surface through `Surface::flush_and_submit`,
reads pixels back into `SkiaPixelFrame`, and calls the platform presenter. The
fallback-safe `raster_surface_preflight` diagnostic summarizes the same
`moui_skia` surface/frame/finalization resource plans so MoUI can audit the
Skia raster target contract even when real native Skia is not linked. The
fallback-safe `skia_text_descriptor_preflight` similarly consumes the
`FontFallbackRequest`, `TextMeasurementDescriptor`, `TextShapingDescriptor`,
`ShapedTextRunDescriptor`, and `ShapedGlyphRunDescriptor` resource plans as
cache-key observation for the current Skia text path. Skia missing-glyph recovery
now accepts complete fallback runs immediately and accepts partial default-font
fallback only when it reduces missing glyph ids or recovers visible text from a
blank primary run. The companion
`text maturity audit ready` or `text maturity audit pending` backend-info
summary keeps audited Skia text baseline checks explicit in fallback-safe and
real Skia environments; bidi reordering, paragraph line breaking, and
deterministic color emoji are now part of the ready audit when the linked Skia
route exposes the required evidence. Neither
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
decode, local PNG/JPEG/BMP decode, contain/cover/stretch/scale-down/fit-width/fit-height image placement geometry,
local PNG image drawing, immutable
failed-image placeholders plus local-file retry recovery, basic text glyph-run pixels, bounded
`TextRun.frame` clipping, and optional SkShaper availability when the smoke is
run with `--enable-skshaper`, while requiring
`unsupported_command_count == 0`. Focused Skia renderer white-box tests also
cover radial-gradient rounded brush and path brush pixels, plus structured
unsupported-command diagnostics for unmatched pops, mismatched pops, unclosed
scopes, unknown shader fallback, and per-frame diagnostic reset. Provider-created
Skia sessions expose renderer-local image diagnostics through `RendererSession`;
hosts do not inspect or mirror renderer resource status. Applied token
completions route redraw to the matching window, while stale or disposed tokens
are inert. Renderer tests cover
JPEG/BMP data URI and local-file decode,
contain/cover/stretch/scale-down/fit-width/fit-height source/destination placement, immutable
failed-cache reuse, and local-file retry once a missing file appears.
Skia renderer text support is now release-ready for the current renderer
contract. Basic text measurement/drawing uses Skia `FontMgr`/`Font` with `FontSpec` family, weight,
style selection, `FontFallbackRequest` matching over representative
coverage characters and inferred BCP47 script language tags before regular
family matching, grapheme-safe mixed-run fallback segments for per-run
`FontMgr` resolution, Skia font
metrics for baseline/height, shaped-run cluster carets when SkShaper is linked
or Skia-measured prefix carets otherwise, shared UAX-style
`TextGraphemeBoundaries` cluster splitting and caret stabilization for both
caret paths, SystemFontMgr-only emoji font retry for
emoji-hint text, optional SkShaper shaped glyph runs for rendering when linked,
and fallback-safe descriptor preflight coverage for the Skia fallback,
measurement, shaping, shaped-run, and shaped-glyph resource plans. The renderer
also exposes a fallback-safe text maturity audit in backend info, counting the
audited baseline, missing-glyph recovery rule, mixed-run fallback, Unicode 17
grapheme boundary contract, bidi/paragraph readiness, and deterministic color
emoji readiness. `TextSystem::layout_paragraph()`
now gives Skia diagnostics wrapped line metrics, caret rectangles, selection
rectangles, and hit-test geometry. When the binding is built with
SkParagraph enabled, `skia_paragraph_available()` lets the Skia
text system use the native `Paragraph` wrapper for SkParagraph line metrics,
selection boxes, hit testing, and mixed-direction visual-order metadata. The
fallback path keeps native paragraph and bidi readiness flags false; the
SkParagraph path may set them only after valid line metrics, caret geometry,
selection rectangles, hit-test results, and visual-order metadata are present.
The renderer
clips aligned text glyphs to each
`TextRun.frame`; fallback-safe white-box tests cover the placement contract, and
the opt-in real Skia smoke verifies that long glyph runs do not leak outside
narrow text frames when native Skia is linked.
Native SkParagraph and bidi readiness are backed by matching-host real Skia
smoke logs that include `engine=skparagraph` markers for paragraph wrapping,
bidi layout, selection rectangles, and hit testing. Broader typography
benchmarks, future Unicode data refreshes, and cross-platform emoji fallback
comparisons are conformance maintenance items rather than renderer capability
blockers. The macOS Skia
provider now matches Windows and Linux by defaulting to
`SkiaFontResolution::SystemFontMgr`, so normal Showcase and
Mo Workbench Skia entrypoints use the system FontMgr path with platform font
lookup, emoji retry, and optional SkShaper when linked. macOS tester-owned
first-frame smoke entrypoints explicitly switch to
`SkiaFontResolution::EmptyTypeface`; that keeps CLI smoke runs on the safer
default-font retry path while preserving the normal app
default. The renderer smoke also uses the system FontMgr path so real Skia font
and optional SkShaper coverage remain tracked.

## Current Web Notes

The wasm-gc renderer bridge preserves the full draw command stream and forwards
payloads to the `webgpu` host import module. The browser runtime now renders
rects, rounded geometry, gradients, soft shadows, opacity, text, and loaded
images through WebGPU pipelines. Text uses a DPR-aware canvas-rasterized glyph
atlas before the glyphs are composited by WebGPU. Images are cached as WebGPU
textures, support contain/cover/stretch/scale-down/fit-width/fit-height fit,
render radial rounded fill/stroke and path brushes through the visual shader, and use a
deterministic fallback color while the browser is still loading the source or
if loading fails. Web radial support remains partial until a browser renderer
smoke records radial center/mid/edge pixels for both rounded and path payloads
in a Chrome/WebGPU session.
`WebGpuWasmRenderer` keeps image resources and decode state inside its
`RendererSession`. Browser image requests carry an opaque token; the Web host
returns a token-matched completion, and only an applied completion schedules
the next animation frame. The host does not expose a revision snapshot,
resource-status mirror, or renderer cache callback to application code.

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
errors into the page log so browser presentation observation fails on shader or
pipeline validation errors instead of silently relying on a nonblank screenshot.
Arbitrary paths share the same MoonBit tessellation contract as native. The
wasm-gc adapter serializes the tessellated `DrawPath` mesh into a compact host
payload once per distinct geometry, keeps the resulting host mesh behind a
handle keyed by path structure, and replays it with a single scalar call while
the browser runtime submits those vertices through the WebGPU visual pipeline
with the active transform, opacity, and clip state. Repainting unchanged
geometry therefore no longer re-crosses the wasm-gc boundary, which has no
shared linear memory and transfers one import call per code point. Skipped
advanced commands are retained in the renderer's last fallback plan for
diagnostics when scopes are unbalanced, left open, or known modeled commands
are not visibly executed yet. Emoji and complex text shaping rely on browser
font behavior; diagnostic conformance covers measurement and caret invariants
for representative emoji samples but does not make browser rasterization or
provider shaping deterministic.

## Canvas2D Fallback Parity Notes

The browser Canvas2D fallback (`canvas2d_runtime.js`) shares the same
MoonBit adapter and `webgpu` import ABI as the WebGPU host. The following
parity fixes keep its behavior aligned with the WebGPU host:

- **Transform**: `PushTransform` accumulates via `ctx.transform` (multiply)
  and conjugates the logical-space matrix with the logical→physical scale
  (S·T·S⁻¹), matching the WebGPU host's `multiplyTransform` for nested
  scopes.
- **Filter effects**: saturate uses CSS `saturate(amount)` (identity at
  amount=1, matching the WebGPU shader's `mix(luma, rgb, amount)`);
  color-matrix renders through a shared hidden inline SVG `feColorMatrix`
  with the Skia-compatible 5×4 row-major 20 values; filter payload kinds
  are offset by +1 at push time exactly like the WebGPU `normalizeFilter`.
- **Image placement**: `ScaleDown` (natural size centered when it fits,
  else contain), `FitWidth`, and `FitHeight` (axis-locked fill with crop or
  letterbox) now match the WebGPU host; previously they fell through to
  Contain.
- **Path mesh**: per-triangle vertex colors are approximated with a linear
  gradient along the triangle's longest edge with the third vertex's color
  at its projection, so gradient paths blend continuously instead of
  flat-filling with a single average color.
- **Text selection**: the selectable-text DOM overlay (transparent spans in
  a `.moui-text-selection-layer` div) is now provided by the fallback too,
  with a renderer-side logical transform/clip state stack feeding the same
  geometry and clip-path computation as the WebGPU host.
- **Shader effects**: `checker` renders the alternating-cell pattern and
  `uniforms[0]` drives the checker scale and vignette fade radius,
  matching the WebGPU host's `effectAmount`.

Remaining fallback approximations: shadow uses native `shadowBlur` with
`spread` folded into the radius, blur uses the browser's CSS `blur()`,
rounded clips are composited as layer masks, and path mesh gradients are
linear-edge approximations rather than per-vertex barycentric shading.

## Current Terminal Cell ANSI Notes

`moui_tui_renderer` is a native, pure-MoonBit renderer package: it links no C
library and opens no GPU device. Its input is `DrawFrame.semantics` only —
pixel draw commands are not approximated but reported through a degrade log, so
a node the terminal cannot draw becomes a named placeholder rather than an
absence. Quantization (a 8x16 logical cell box by default), per-cell ownership
and in-box wrapping live in this package, not in `moui/core` or
`moui/runtime`.

Layering is a claim rule rather than a painter's order: chrome borders claim
cells at priority 1, container titles at 2, leaf content at 3, and equal
priorities are first-come-first-served. Every paint is clipped to the node's own
quantized box, and nodes whose box is entirely off-screen are dropped and
counted (`offscreen_node_count()`). Output is ANSI row deltas: an unchanged
frame emits zero bytes, a removed node repaints only the row it vacated, and a
resize starts from a blank grid so no cell from the old width can be encoded
into the new frame.

`moui_tui` provides the cell buffer underneath it (damage/revision tracking and
CJK/emoji double-width cells with a filled right half), and the byte sink is
supplied by the composition root: the terminal backend wires it to stdout,
tests capture it. Cell-level text coverage is one or two cells per code point
with no shaper, which is why `Text shaping` and `Emoji text` are `partial`:
`moui_tui.unicode_width` decides advance, the host terminal font decides glyphs.

Colors enter through `TuiPalette`: the default palette is the fixed xterm
16-color mapping the terminal path shipped with (unchanged bytes; two inline
golden frames guard it), and `TuiPalette::from_theme` quantizes an app's
`@core.Theme` palette roles into the xterm-256 cube — `primary` for buttons
and focus, `secondary` for interactive controls, `on_surface` for text,
`error` for alerts. The terminal host takes an optional `theme` at launch
(`run_program`/`run_view`); `moui/core` carries no color on semantics nodes,
so pixel renderers and the semantics contract are untouched. Mid-session
theme reload is recorded as debt (tui-hardening H4).

## Update Rule

When improving image, clip, opacity, transform, or any other draw command
support, update:

1. `render/capabilities.mbt`
2. `render/capabilities_test.mbt`
3. this report page

The Skia, native WGPU, Sun and terminal columns are all machine-checked against
their code self-reports by
`node scripts/validate-renderer-capability-consistency.mjs`; the Web column is
checked by wasm-side package tests because a native validator cannot import
`moui_web_renderer`. Changing terminal projection coverage means
`moui_tui_renderer/capabilities.mbt` plus its cell in this table — a
`supported` cell there would claim pixels a cell grid cannot draw.

For text-related renderer changes, also update `docs/text-system.md`.

The direct-GPU route states its gaps in a form its own gate can check: every
`Partial` note in `moui_metal_renderer/capabilities.mbt` ends with a `Remaining:`
sentence listing what is missing, and `metal_renderer_wbtest.mbt` fails any Partial
row without one. That convention is this module's, not a repo-wide claim about the
other routes' note text.
