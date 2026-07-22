///|
pub fn renderer_feature_capability_report() -> Array[RendererFeatureCapability] {
  [
    renderer_feature_capability_entry(
      RendererFeature::Rect,
      RendererFeatureStatus::Supported,
      "Native wgpu renders rect fills and strokes as visual pipeline quads.",
      RendererFeatureStatus::Supported,
      "Skia raster renders clear, rect fill, and rect stroke commands in the real native renderer pixel smoke through moui_skia/native.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host renders rect fills and strokes as visual pipeline quads.",
      RendererFeatureStatus::Supported,
      "Canvas 2D renders rect fills and strokes through fillRect and strokeRect on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::RoundedRect,
      RendererFeatureStatus::Supported,
      "Native wgpu renders rounded fills and strokes with shader SDF geometry.",
      RendererFeatureStatus::Supported,
      "Skia raster renders rounded rect fills, strokes, and solid rounded brushes in the real native renderer pixel smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host renders rounded fills and strokes with shader SDF geometry.",
      RendererFeatureStatus::Partial,
      "Canvas 2D renders rounded rect fills and strokes through path-based rounded rect drawing; status stays partial until real Mini Program pixel smoke is recorded.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Gradient,
      RendererFeatureStatus::Partial,
      "Native wgpu evaluates linear and radial rounded/path brushes in the visual shader using a radial brush payload; status stays partial until renderer smoke captures center/mid/edge pixel artifacts across native platforms.",
      RendererFeatureStatus::Supported,
      "Skia raster renders linear-gradient and radial-gradient fills and strokes for rounded rects and paths; linear gradients have real native renderer pixel smoke coverage and radial brushes have renderer-local guarded pixel coverage.",
      RendererFeatureStatus::Partial,
      "The browser WebGPU host evaluates solid, linear-gradient, and true radial rounded/path brush payloads in the visual shader; status stays partial until a Web renderer smoke records radial center/mid/edge pixels.",
      RendererFeatureStatus::Supported,
      "Canvas 2D renders linear and radial gradients through createLinearGradient and createRadialGradient on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Shadow,
      RendererFeatureStatus::Supported,
      "Native wgpu renders soft rounded shadows as visual shader primitives.",
      RendererFeatureStatus::Supported,
      "Skia raster renders soft rounded shadows through moui_skia MaskFilter blur and real native renderer pixel smoke coverage.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host renders soft rounded shadows as visual shader primitives.",
      RendererFeatureStatus::Supported,
      "Canvas 2D renders shadows through shadowBlur, shadowColor, shadowOffsetX, and shadowOffsetY on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Text,
      RendererFeatureStatus::Supported,
      "Native wgpu uses shaped glyphs and a glyph-atlas text pipeline.",
      RendererFeatureStatus::Supported,
      "Skia raster text measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interior stabilization for both caret paths, grapheme-safe mixed-run fallback segments, and best-available glyph-run rendering clip to the TextRun frame while resolving FontSpec family, weight, style, and representative coverage characters through Skia FontMgr FontFallbackRequest/Font; real native renderer smoke covers glyph-run pixels and bounded TextRun frame clipping; broader shaping remains tracked separately.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host uses a canvas-rasterized DPR-aware glyph atlas and WebGPU text pipeline.",
      RendererFeatureStatus::Supported,
      "Canvas 2D renders text through fillText on the CanvasRenderingContext2D, with text measurement via measureText.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Image,
      RendererFeatureStatus::Supported,
      "Native wgpu decodes local file paths and base64 data URIs through mizchi/image for PNG, JPEG, and BMP, then caches GPU textures with contain/cover/stretch/scale-down/fit-width/fit-height sampling.",
      RendererFeatureStatus::Supported,
      "Skia raster decodes PNG/JPEG/BMP data URIs and local PNG/JPEG/BMP files through moui_skia encoded image APIs, validates contain/cover/stretch/scale-down/fit-width/fit-height placement geometry and draw_image_rect output, records ready/failed image lifecycle states, and renders failed-image placeholders in the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host loads image sources into a texture cache, samples contain/cover/stretch/scale-down/fit-width/fit-height image fits through a WebGPU image pipeline, and falls back to a deterministic source color while loading or on failure.",
      RendererFeatureStatus::Partial,
      "Canvas 2D renders images through drawImage; image loading is delegated to the host via wx.getImageInfo or Canvas Image; status stays partial until async image loading is validated in the Mini Program environment.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Clip,
      RendererFeatureStatus::Supported,
      "Native wgpu maps nested rectangular and rounded clips, using physical scissor rectangles with shader SDF masks for rounded corners.",
      RendererFeatureStatus::Supported,
      "Skia raster applies canvas clip_rect, clip_rrect, and clip_path scopes, with rectangular, rounded, and path-clipped gradient output covered by the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host applies transformed rectangular scissors; the wasm-gc adapter submits rounded clip scopes as offscreen layer masks in the advanced composite shader.",
      RendererFeatureStatus::Supported,
      "Canvas 2D applies clips through save/restore and clip on the CanvasRenderingContext2D; rounded clips use path-based clip regions.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Transform,
      RendererFeatureStatus::Partial,
      "Native wgpu folds affine transforms into planned visual, image, text, shader-effect advanced vertices, and masked layer composite vertices; scissor uses transformed bounding boxes; scoped layer/filter child plans inherit transform and clip while outer opacity is applied at composite time. Filter scopes preserve transformed child vertices and transformed clip scissors. Broader render-pass transform pixel observation remains follow-up work.",
      RendererFeatureStatus::Supported,
      "Skia raster maps MoUI affine fields into Skia matrix members and validates translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform output in the real native renderer smoke.",
      RendererFeatureStatus::Partial,
      "The browser WebGPU host folds affine transforms into visual, image, text, and shader-effect advanced vertices, and scoped layer/filter commands clone the current transform and clip state. Web adapter tests preserve transform scope around layers, filters, and shader effects; broader render-pass transform pixel observation remains follow-up work.",
      RendererFeatureStatus::Supported,
      "Canvas 2D applies affine transforms through setTransform, translate, rotate, and scale on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Opacity,
      RendererFeatureStatus::Supported,
      "Native wgpu folds opacity into visual and text vertex alpha.",
      RendererFeatureStatus::Supported,
      "Skia raster applies save_layer opacity, with blended pixel output covered by the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host folds opacity into visual and text vertex alpha.",
      RendererFeatureStatus::Supported,
      "Canvas 2D applies opacity through globalAlpha on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::LayerCompositing,
      RendererFeatureStatus::Supported,
      "PushLayer/PopLayer render child commands into offscreen textures and composite them back through the advanced GPU pass with opacity, masks, filters, and blend selection.",
      RendererFeatureStatus::Supported,
      "Skia raster composites save_layer scopes with renderer-local pixel tests and real native renderer smoke coverage for opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter combinations.",
      RendererFeatureStatus::Supported,
      "The wasm-gc host ABI forwards PushLayer/PopLayer and the browser runtime renders layer scopes into offscreen WebGPU textures before compositing.",
      RendererFeatureStatus::Partial,
      "Canvas 2D composites layers through offscreen canvases; status stays partial until renderer-local pixel tests cover layer compositing with masks and blend modes.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::BlendMode,
      RendererFeatureStatus::Supported,
      "Layer composite pipelines map source-over, multiply, screen, darken, and lighten to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math.",
      RendererFeatureStatus::Supported,
      "Skia raster maps all MoUI blend modes to Skia paint blend modes with renderer-local multiply pixel coverage plus real native renderer smoke coverage for multiply, screen, overlay, darken, and lighten output pixels.",
      RendererFeatureStatus::Supported,
      "The browser runtime maps source-over, multiply, screen, darken, and lighten to WebGPU blend states; overlay uses a backdrop-sampling WebGPU pass for exact semantics.",
      RendererFeatureStatus::Supported,
      "Canvas 2D maps blend modes through globalCompositeOperation on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::FilterEffect,
      RendererFeatureStatus::Supported,
      "PushFilter/PopFilter render scoped content into offscreen textures, then the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
      RendererFeatureStatus::Supported,
      "Skia raster applies image-filter and color-filter save_layer scopes with renderer-local saturation/color-matrix coverage plus real native renderer smoke coverage for blur, saturation, brightness, contrast, and identity-normalized color matrix filters.",
      RendererFeatureStatus::Supported,
      "The wasm-gc host forwards filter scopes and the browser advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
      RendererFeatureStatus::Partial,
      "Canvas 2D applies blur through the filter property; other filter effects use offscreen canvas pixel manipulation; status stays partial until real Mini Program pixel smoke validates filter fidelity.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::PathVector,
      RendererFeatureStatus::Supported,
      "Native wgpu tessellates DrawPath through moon_zeno and renders the resulting fill/stroke triangle mesh through the visual GPU pipeline.",
      RendererFeatureStatus::Supported,
      "Skia raster replays MoUI PathSpec into native Skia paths with renderer-local pixel tests and real native smoke coverage for solid and linear-gradient fills and strokes, plus quadratic and cubic curve verbs.",
      RendererFeatureStatus::Supported,
      "The wasm-gc adapter tessellates DrawPath through the same moon_zeno contract and forwards a mesh payload to the browser WebGPU visual pipeline.",
      RendererFeatureStatus::Supported,
      "Canvas 2D renders path vectors through beginPath, moveTo, lineTo, arc, bezierCurveTo, with fill and stroke on the CanvasRenderingContext2D.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::ShaderEffect,
      RendererFeatureStatus::Supported,
      "DrawShaderEffect executes through the advanced GPU shader path for built-in solid, checker, linear-gradient-debug, vignette, and fallback-brush effects.",
      RendererFeatureStatus::Supported,
      "Skia raster executes solid, checker, linear-gradient-debug, and vignette effects with renderer-local pixel tests and real native renderer pixel smoke coverage; unknown shader names still use fallback paths.",
      RendererFeatureStatus::Supported,
      "DrawShaderEffect is forwarded through the wasm-gc host ABI and executes in the browser advanced WebGPU shader path with the same built-ins and fallback brush.",
      RendererFeatureStatus::Gap,
      "Canvas 2D has no native shader pipeline; built-in shader effects are simulated through Canvas 2D drawing primitives where possible, with fallback to the spec fallback brush for unsupported effects.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::TextShaping,
      RendererFeatureStatus::Supported,
      "Native wgpu uses a private platform text provider boundary: render/wgpu owns validation and atlas upload, including non-empty run-layout caret coverage checks, render/wgpu/cosmic_text owns the Cosmic provider, macOS composes CoreText/CoreGraphics with Cosmic fallback, Windows composes DirectWrite provider records with Cosmic fallback, and Linux composes fontconfig/FreeType provider records with Cosmic fallback. Native provider paths safe-map provider-fragile samples before shaping while preserving monotonic caret coverage.",
      RendererFeatureStatus::Supported,
      "Skia raster text provider maps FontSpec family, weight, and style to Skia FontMgr/Font, builds FontFallbackRequest values with representative emoji/non-ASCII coverage characters before regular family matching, splits mixed-script text into grapheme-safe fallback segments for per-run FontMgr resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or Skia-measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interiors in both caret paths, retries emoji-family fonts for emoji-hint text on the system FontMgr path, uses optional SkShaper shaped glyph-run drawing once linked, and marks SkParagraph-style line breaking plus bidi reordering ready in the text maturity preflight.",
      RendererFeatureStatus::Supported,
      "Web text uses browser-shaped canvas rasterization to build DPR-aware glyph atlases, while conformance tests cover deterministic measurement and caret invariants through the shared text-system contract.",
      RendererFeatureStatus::Supported,
      "Canvas 2D text shaping uses the browser's built-in text shaping via measureText and fillText, which provides platform-native shaping.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::EmojiText,
      RendererFeatureStatus::Supported,
      "Native wgpu atlas upload, text vertices, and provider protocol preserve RGBA color glyph payloads; Cosmic loads platform emoji fallback font candidates when available, keeps color swash pixels, and safe-maps provider-fragile single-codepoint, variation-selector, and ZWJ emoji grapheme samples before native layout so caret coverage remains stable; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS; Linux fontconfig/FreeType can rasterize explicit emoji-family Noto Color Emoji glyphs as RGBA when available.",
      RendererFeatureStatus::Supported,
      "Skia raster detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, emoji tag-sequence, Indic/Arabic/Thai/Lao/Sinhala/Khmer/Myanmar mark, and Hangul Jamo grapheme cluster samples, prefers emoji coverage characters and inferred language tags in system FontMgr FontFallbackRequest matching, stabilizes representative cluster interior carets, retries platform emoji font candidates before default-font fallback, and reports deterministic color emoji readiness through Typeface::has_color_glyphs and glyph format metadata.",
      RendererFeatureStatus::Supported,
      "Browser canvas glyph rasterization surfaces emoji through platform fonts while diagnostic text conformance covers deterministic measurement, caret invariants, and shared grapheme cluster handling.",
      RendererFeatureStatus::Supported,
      "Canvas 2D emoji rendering uses the browser's built-in emoji font support via fillText, which renders color emoji natively.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::AsyncImage,
      RendererFeatureStatus::Supported,
      "Renderer-neutral image lifecycle state models loading, ready, failed, disposed, eviction, monotonic revision/change signals, and ImageResourceLoadCompletion ready/failed apply helpers; native WgpuRenderer exposes renderer-local image resource records plus revisioned snapshots, native WGPU providers forward revisioned snapshots through HostWindowRenderer, HostWindowRenderer exposes apply_image_resource_load_completion as the renderer-neutral completion apply port, native_image_load_completion decodes PNG/JPEG/BMP data URI and local-file sources into ready/failed completion payloads, macOS/Windows/Linux WGPU providers install provider-owned HostAsyncImageLoader hooks for that completion path, HostAsyncImageLoader scans loading records and gates late/cancelled completion callbacks before HostImageResourceCompletionSource routes native async loader completion snapshots through HostImageResourceRepaintTracker, and macOS/Windows/Linux hosts track presented revisions, call optional provider-owned async image loaders after present baseline, and route per-window repaint requests when newer image revisions are observed.",
      RendererFeatureStatus::Supported,
      "Skia raster image lifecycle uses the same renderer-neutral records, ImageResourceLoadCompletion apply helper, and revisioned snapshot contract, exposes renderer-local image-resource change callbacks when lifecycle revisions advance, native Skia providers create renderers with off-main-thread async image loading where data URI sources complete through the renderer decode path and local-file sources read and decode to RGBA pixels on background native workers via platform C++ stubs (GCD on macOS, pthread on Linux, CreateThread on Windows) before decoded completion delivery, forward snapshots and callback setters through HostWindowRenderer, HostWindowRenderer exposes apply_image_resource_load_completion as the renderer-neutral completion apply port, HostAsyncImageLoader scans loading records and gates late/cancelled completion callbacks before HostImageResourceCompletionSource routes native async loader completion snapshots through HostImageResourceRepaintTracker, macOS/Windows/Linux hosts install baseline-guarded callbacks, call optional provider-owned async image loaders after present baseline, and request redraw for post-present image revisions, immutable failed sources are cached with diagnostics before placeholder drawing, local-file failures retry once the file appears, hosts discard closed-window image changes, real Skia observation covers PNG/JPEG/BMP data URI decode, PNG/JPEG/BMP local-file decode, failed-image placeholder, failed-cache snapshot, local-file retry, image-resource callback snapshots, HostWindowRenderer callback bridge coverage, async image second-frame smoke, and dispose-record diagnostics, and decoded completions carry background_io, background_decode, decoded dimensions, row bytes, and RGBA pixels.",
      RendererFeatureStatus::Supported,
      "Renderer-neutral image lifecycle state matches the browser async loading cache contract; WebGpuWasmRenderer and the backend WebRenderer facade expose app-visible image resource records plus revisioned snapshots, refresh loading, ready, or failed records from the browser cache after host submission, and the canonical Web boot path schedules a redraw when Image.onload or Image.onerror reports a resource change.",
      RendererFeatureStatus::Gap,
      "Canvas 2D async image loading uses the host-provided image loading infrastructure (wx.getImageInfo / Canvas Image); renderer-local async image lifecycle is not yet implemented.",
    ),
  ]
}

///|
pub fn renderer_feature_capability(
  feature : RendererFeature,
) -> RendererFeatureCapability? {
  for entry in renderer_feature_capability_report() {
    if entry.feature == feature {
      return Some(entry)
    }
  }
  None
}

///|
pub fn renderer_feature_follow_ups() -> Array[RendererFeatureCapability] {
  let follow_ups : Array[RendererFeatureCapability] = []
  for entry in renderer_feature_capability_report() {
    if entry.needs_follow_up() {
      follow_ups.push(entry)
    }
  }
  follow_ups
}

///|
pub fn renderer_backend_capabilities(
  backend : RendererBackendKind,
) -> Array[RendererBackendFeatureCapability] {
  let capabilities : Array[RendererBackendFeatureCapability] = []
  for entry in renderer_feature_capability_report() {
    match entry.backend_capability(backend) {
      Some(capability) => capabilities.push(capability)
      None => ()
    }
  }
  capabilities
}