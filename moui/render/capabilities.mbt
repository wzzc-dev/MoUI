///|
pub(all) enum RendererFeature {
  Rect
  RoundedRect
  Gradient
  Shadow
  Text
  Image
  Clip
  Transform
  Opacity
  LayerCompositing
  BlendMode
  FilterEffect
  PathVector
  ShaderEffect
  TextShaping
  EmojiText
  AsyncImage
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererFeatureStatus {
  Supported
  Partial
  Gap
  HostForwarded
  Unavailable
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererBackendFeatureCapability {
  feature : RendererFeature
  backend : RendererBackendKind
  status : RendererFeatureStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererFeatureCapability {
  feature : RendererFeature
  backends : Array[RendererBackendFeatureCapability]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererCommandFallbackKind {
  PlannedFallback
  UnbalancedPop
  UnclosedScope
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererCommandFallback {
  index : Int
  feature : RendererFeature
  command : String
  kind : RendererCommandFallbackKind
  reason : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererCommandPlan {
  total_commands : Int
  fallback_count : Int
  final_layer_depth : Int
  final_filter_depth : Int
  fallbacks : Array[RendererCommandFallback]
} derive(Eq, Debug, ToJson)

///|
pub fn RendererFeature::label(self : RendererFeature) -> String {
  match self {
    Rect => "rect"
    RoundedRect => "rounded-rect"
    Gradient => "gradient"
    Shadow => "shadow"
    Text => "text"
    Image => "image"
    Clip => "clip"
    Transform => "transform"
    Opacity => "opacity"
    LayerCompositing => "layer-compositing"
    BlendMode => "blend-mode"
    FilterEffect => "filter-effect"
    PathVector => "path-vector"
    ShaderEffect => "shader-effect"
    TextShaping => "text-shaping"
    EmojiText => "emoji-text"
    AsyncImage => "async-image"
  }
}

///|
pub fn RendererFeatureStatus::label(self : RendererFeatureStatus) -> String {
  match self {
    Supported => "supported"
    Partial => "partial"
    Gap => "gap"
    HostForwarded => "host-forwarded"
    Unavailable => "unavailable"
  }
}

///|
pub fn RendererFeatureStatus::needs_follow_up(
  self : RendererFeatureStatus,
) -> Bool {
  match self {
    Partial | Gap | Unavailable => true
    Supported | HostForwarded => false
  }
}

///|
pub fn RendererBackendFeatureCapability::new(
  feature~ : RendererFeature,
  backend~ : RendererBackendKind,
  status~ : RendererFeatureStatus,
  note? : String = "",
) -> RendererBackendFeatureCapability {
  { feature, backend, status, note }
}

///|
pub fn RendererFeatureCapability::new(
  feature~ : RendererFeature,
  backends~ : Array[RendererBackendFeatureCapability],
) -> RendererFeatureCapability {
  { feature, backends }
}

///|
pub fn RendererFeatureCapability::backend_capability(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> RendererBackendFeatureCapability? {
  for capability in self.backends {
    if capability.backend == backend {
      return Some(capability)
    }
  }
  None
}

///|
pub fn RendererFeatureCapability::status_for_backend(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> RendererFeatureStatus {
  match self.backend_capability(backend) {
    Some(capability) => capability.status
    None => RendererFeatureStatus::Unavailable
  }
}

///|
pub fn RendererFeatureCapability::note_for_backend(
  self : RendererFeatureCapability,
  backend : RendererBackendKind,
) -> String {
  match self.backend_capability(backend) {
    Some(capability) => capability.note
    None => "renderer backend has no recorded capability for this feature"
  }
}

///|
pub fn RendererFeatureCapability::needs_follow_up(
  self : RendererFeatureCapability,
) -> Bool {
  self.backends.any(capability => capability.status.needs_follow_up())
}

///|
pub fn renderer_capability_backends() -> Array[RendererBackendKind] {
  [
    RendererBackendKind::SkiaRasterNative,
    RendererBackendKind::WebGpuWasm,
    RendererBackendKind::NativeWgpu,
    RendererBackendKind::SunRasterNative,
  ]
}

///|
fn renderer_backend_feature(
  feature : RendererFeature,
  backend : RendererBackendKind,
  status : RendererFeatureStatus,
  note : String,
) -> RendererBackendFeatureCapability {
  RendererBackendFeatureCapability::new(feature~, backend~, status~, note~)
}

///|
fn renderer_feature_capability_entry(
  feature : RendererFeature,
  native_wgpu_status : RendererFeatureStatus,
  native_wgpu_note : String,
  skia_status : RendererFeatureStatus,
  skia_note : String,
  web_status : RendererFeatureStatus,
  web_note : String,
) -> RendererFeatureCapability {
  RendererFeatureCapability::new(feature~, backends=[
    renderer_backend_feature(
      feature,
      RendererBackendKind::NativeWgpu,
      native_wgpu_status,
      native_wgpu_note,
    ),
    renderer_backend_feature(
      feature,
      RendererBackendKind::SkiaRasterNative,
      skia_status,
      skia_note,
    ),
    renderer_backend_feature(
      feature,
      RendererBackendKind::WebGpuWasm,
      web_status,
      web_note,
    ),
    renderer_backend_feature(
      feature,
      RendererBackendKind::SunRasterNative,
      sun_feature_status(feature),
      sun_feature_note(feature),
    ),
  ])
}

///|
fn sun_feature_status(feature : RendererFeature) -> RendererFeatureStatus {
  match feature {
    Rect | RoundedRect | Clip | Transform | Opacity | PathVector =>
      RendererFeatureStatus::Supported
    Gradient => RendererFeatureStatus::Supported
    BlendMode => RendererFeatureStatus::Supported
    Text | Image | Shadow | LayerCompositing | FilterEffect | ShaderEffect =>
      RendererFeatureStatus::Supported
    TextShaping => RendererFeatureStatus::Partial
    EmojiText => RendererFeatureStatus::Partial
    AsyncImage => RendererFeatureStatus::Partial
  }
}

///|
fn sun_feature_note(feature : RendererFeature) -> String {
  match feature {
    Rect =>
      "Sun raster renders clear, rect fill, and rect stroke commands through moui_sun/graphics Canvas."
    RoundedRect =>
      "Sun raster renders rounded rect fills and strokes through moui_sun/graphics rounded path helpers."
    Gradient =>
      "Sun raster maps MoUI linear and radial brushes to moui_sun PaintShader for rect and path drawing; runtime evidence exists through PaintShader linear and radial gradient mapping."
    Shadow =>
      "Sun raster renders shadows by filling the rounded-rect shadow shape using SDF on an offscreen pixmap, applying separable box blur, and compositing onto the main canvas, producing real soft-shadow falloff that respects corner radius, blur_radius, and spread."
    Text =>
      "Sun raster uses moui_sun/text FontFace and CoverageMask when fonts are registered, falling back to debug placeholder glyphs otherwise."
    Image =>
      "Sun raster decodes PNG and BMP data URI image sources through moui_sun Pixmap codecs, scaling them to the ImageRun frame with draw_scaled_pixmap."
    Clip =>
      "Sun raster applies rectangular clips through moui_sun Canvas clip state; rounded clips render child commands into an offscreen canvas and composite back with per-pixel SDF-based rounded-rect masking and anti-aliased edge coverage."
    Transform =>
      "Sun raster maps MoUI affine transform scopes to moui_sun Canvas transform state."
    Opacity =>
      "Sun raster applies scoped opacity by multiplying Paint opacity for supported primitive commands."
    LayerCompositing =>
      "Sun raster composites PushLayer/PopLayer scopes by rendering child commands into an offscreen canvas and drawing the result with scoped opacity; BeginCachedLayer/EndCachedLayer/DrawCachedLayer scopes cache layer pixmaps with content-revision and scale-factor validation, FIFO eviction, and renderer-local pixel coverage for cache hit, miss, and dispose lifecycle."
    BlendMode =>
      "Sun raster maps all MoUI blend modes to moui_sun Paint blend modes and applies them when compositing PushLayer/PopLayer layer scopes; renderer-local pixel test covers Multiply."
    FilterEffect =>
      "Sun raster applies PushFilter/PopFilter scopes using moui_sun PaintFilter pixmap-level color transforms for saturate, brightness, contrast, and color matrix effects; blur uses three-pass separable box blur (Gaussian approximation) on the layer pixmap before compositing; filter compositing applies PaintFilter at the pixmap level and draws the result with a single draw_pixmap call."
    PathVector =>
      "Sun raster maps MoUI PathSpec verbs to moui_sun Path fill and stroke drawing."
    ShaderEffect =>
      "Sun raster implements checker shader-effect builtin with canvas-level tile rendering; vignette builtin uses concentric fill_circle calls for circular falloff; unknown builtins fall back to the spec fallback brush."
    TextShaping =>
      "Sun raster text uses moui_sun/text FontFace, LayoutConfig, and rasterize_text_face for basic glyph layout with font-metric baseline/height; TextSystem provides font registration, requested-family-first fallback chain resolution across remaining registered faces, and face caching; renderer-local tests cover mixed Latin-plus-emoji measurement and paragraph metadata; ShapingBuffer is available for direction/script-aware shaping; full OpenType shaping, bidi, and line breaking remain follow-up work."
    EmojiText =>
      "moui_sun/text FontFallbackPlan selects registered fallback faces for emoji spans after requested family faces, so mixed Latin-plus-emoji Sun text can measure and draw without missing fallback diagnostics when coverage is registered; Sun raster renders text through FontFace and CoverageMask; RGBA color emoji glyph rendering and grapheme shaping remain follow-up work."
    AsyncImage =>
      "Sun raster decodes PNG and BMP data URI plus local-file image sources synchronously through moui_sun Pixmap codecs, records renderer-local ready/failed/disposed image lifecycle snapshots, forwards revisioned image-resource snapshots and callback/apply ports through native Sun providers, and keeps redraw-safe lifecycle revisions stable for cached repeat draws; post-present HostAsyncImageLoader scheduling remains follow-up work."
  }
}

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
    ),
    renderer_feature_capability_entry(
      RendererFeature::RoundedRect,
      RendererFeatureStatus::Supported,
      "Native wgpu renders rounded fills and strokes with shader SDF geometry.",
      RendererFeatureStatus::Supported,
      "Skia raster renders rounded rect fills, strokes, and solid rounded brushes in the real native renderer pixel smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host renders rounded fills and strokes with shader SDF geometry.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Gradient,
      RendererFeatureStatus::Partial,
      "Native wgpu evaluates linear and radial rounded/path brushes in the visual shader using a radial brush payload; status stays partial until renderer smoke captures center/mid/edge pixel artifacts across native platforms.",
      RendererFeatureStatus::Supported,
      "Skia raster renders linear-gradient and radial-gradient fills and strokes for rounded rects and paths; linear gradients have real native renderer pixel smoke coverage and radial brushes have renderer-local guarded pixel coverage.",
      RendererFeatureStatus::Partial,
      "The browser WebGPU host evaluates solid, linear-gradient, and true radial rounded/path brush payloads in the visual shader; status stays partial until a Web renderer smoke records radial center/mid/edge pixels.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Shadow,
      RendererFeatureStatus::Supported,
      "Native wgpu renders soft rounded shadows as visual shader primitives.",
      RendererFeatureStatus::Supported,
      "Skia raster renders soft rounded shadows through moui_skia MaskFilter blur and real native renderer pixel smoke coverage.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host renders soft rounded shadows as visual shader primitives.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Text,
      RendererFeatureStatus::Supported,
      "Native wgpu uses shaped glyphs and a glyph-atlas text pipeline.",
      RendererFeatureStatus::Supported,
      "Skia raster text measurement, font-metric baseline/height, shaped-run cluster carets when SkShaper is linked or measured prefix carets otherwise, representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interior stabilization for both caret paths, grapheme-safe mixed-run fallback segments, and best-available glyph-run rendering clip to the TextRun frame while resolving FontSpec family, weight, style, and representative coverage characters through Skia FontMgr FontFallbackRequest/Font; real native renderer smoke covers glyph-run pixels and bounded TextRun frame clipping; broader shaping remains tracked separately.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host uses a canvas-rasterized DPR-aware glyph atlas and WebGPU text pipeline.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Image,
      RendererFeatureStatus::Supported,
      "Native wgpu decodes local file paths and base64 data URIs through mizchi/image for PNG, JPEG, and BMP, then caches GPU textures with contain/cover/stretch/scale-down/fit-width/fit-height sampling.",
      RendererFeatureStatus::Supported,
      "Skia raster decodes PNG/JPEG/BMP data URIs and local PNG/JPEG/BMP files through moui_skia encoded image APIs, validates contain/cover/stretch/scale-down/fit-width/fit-height placement geometry and draw_image_rect output, records ready/failed image lifecycle states, and renders failed-image placeholders in the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host loads image sources into a texture cache, samples contain/cover/stretch/scale-down/fit-width/fit-height image fits through a WebGPU image pipeline, and falls back to a deterministic source color while loading or on failure.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Clip,
      RendererFeatureStatus::Supported,
      "Native wgpu maps nested rectangular and rounded clips, using physical scissor rectangles with shader SDF masks for rounded corners.",
      RendererFeatureStatus::Supported,
      "Skia raster applies canvas clip_rect, clip_rrect, and clip_path scopes, with rectangular, rounded, and path-clipped gradient output covered by the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host applies transformed rectangular scissors; the wasm-gc adapter submits rounded clip scopes as offscreen layer masks in the advanced composite shader.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Transform,
      RendererFeatureStatus::Partial,
      "Native wgpu folds affine transforms into planned visual, image, text, shader-effect advanced vertices, and masked layer composite vertices; scissor uses transformed bounding boxes; scoped layer/filter child plans inherit transform and clip while outer opacity is applied at composite time. Filter scopes preserve transformed child vertices and transformed clip scissors. Broader render-pass transform pixel observation remains follow-up work.",
      RendererFeatureStatus::Supported,
      "Skia raster maps MoUI affine fields into Skia matrix members and validates translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform output in the real native renderer smoke.",
      RendererFeatureStatus::Partial,
      "The browser WebGPU host folds affine transforms into visual, image, text, and shader-effect advanced vertices, and scoped layer/filter commands clone the current transform and clip state. Web adapter tests preserve transform scope around layers, filters, and shader effects; broader render-pass transform pixel observation remains follow-up work.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::Opacity,
      RendererFeatureStatus::Supported,
      "Native wgpu folds opacity into visual and text vertex alpha.",
      RendererFeatureStatus::Supported,
      "Skia raster applies save_layer opacity, with blended pixel output covered by the real native renderer smoke.",
      RendererFeatureStatus::Supported,
      "The browser WebGPU host folds opacity into visual and text vertex alpha.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::LayerCompositing,
      RendererFeatureStatus::Supported,
      "PushLayer/PopLayer render child commands into offscreen textures and composite them back through the advanced GPU pass with opacity, masks, filters, and blend selection.",
      RendererFeatureStatus::Supported,
      "Skia raster composites save_layer scopes with renderer-local pixel tests and real native renderer smoke coverage for opacity, rectangular masks, rounded masks, blend-mode layers, and nested layer/filter combinations.",
      RendererFeatureStatus::Supported,
      "The wasm-gc host ABI forwards PushLayer/PopLayer and the browser runtime renders layer scopes into offscreen WebGPU textures before compositing.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::BlendMode,
      RendererFeatureStatus::Supported,
      "Layer composite pipelines map source-over, multiply, screen, darken, and lighten to GPU blend states; overlay uses a backdrop-sampling GPU pass for exact channel math.",
      RendererFeatureStatus::Supported,
      "Skia raster maps all MoUI blend modes to Skia paint blend modes with renderer-local multiply pixel coverage plus real native renderer smoke coverage for multiply, screen, overlay, darken, and lighten output pixels.",
      RendererFeatureStatus::Supported,
      "The browser runtime maps source-over, multiply, screen, darken, and lighten to WebGPU blend states; overlay uses a backdrop-sampling WebGPU pass for exact semantics.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::FilterEffect,
      RendererFeatureStatus::Supported,
      "PushFilter/PopFilter render scoped content into offscreen textures, then the advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
      RendererFeatureStatus::Supported,
      "Skia raster applies image-filter and color-filter save_layer scopes with renderer-local saturation/color-matrix coverage plus real native renderer smoke coverage for blur, saturation, brightness, contrast, and identity-normalized color matrix filters.",
      RendererFeatureStatus::Supported,
      "The wasm-gc host forwards filter scopes and the browser advanced shader applies blur, saturation, brightness, contrast, and color matrix filters.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::PathVector,
      RendererFeatureStatus::Supported,
      "Native wgpu tessellates DrawPath through moon_zeno and renders the resulting fill/stroke triangle mesh through the visual GPU pipeline.",
      RendererFeatureStatus::Supported,
      "Skia raster replays MoUI PathSpec into native Skia paths with renderer-local pixel tests and real native smoke coverage for solid and linear-gradient fills and strokes, plus quadratic and cubic curve verbs.",
      RendererFeatureStatus::Supported,
      "The wasm-gc adapter tessellates DrawPath through the same moon_zeno contract and forwards a mesh payload to the browser WebGPU visual pipeline.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::ShaderEffect,
      RendererFeatureStatus::Supported,
      "DrawShaderEffect executes through the advanced GPU shader path for built-in solid, checker, linear-gradient-debug, vignette, and fallback-brush effects.",
      RendererFeatureStatus::Supported,
      "Skia raster executes solid, checker, linear-gradient-debug, and vignette effects with renderer-local pixel tests and real native renderer pixel smoke coverage; unknown shader names still use fallback paths.",
      RendererFeatureStatus::Supported,
      "DrawShaderEffect is forwarded through the wasm-gc host ABI and executes in the browser advanced WebGPU shader path with the same built-ins and fallback brush.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::TextShaping,
      RendererFeatureStatus::Partial,
      "Native wgpu uses a private platform text provider boundary: render/wgpu owns validation and atlas upload, including non-empty run-layout caret coverage checks, render/wgpu/cosmic_text owns the Cosmic provider, macOS composes CoreText/CoreGraphics with Cosmic fallback, Windows composes a DirectWrite scaffold with Cosmic fallback, and Linux composes a fontconfig/FreeType provider with Cosmic fallback. Linux can emit native FreeType RGBA glyphs for explicit emoji-family runs when Noto Color Emoji is available, but general shaping, measurement, and non-emoji raster data still fall back to Cosmic until the full fontconfig/HarfBuzz path lands. Cosmic measurement and native run layout paths safe-map provider-fragile emoji samples before shaping while preserving monotonic caret coverage. Full bidi, line breaking, and typography conformance remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Skia raster text provider maps FontSpec family, weight, and style to Skia FontMgr/Font, builds FontFallbackRequest values with representative emoji/non-ASCII coverage characters before regular family matching, splits mixed-script text into grapheme-safe fallback segments for per-run FontMgr resolution, returns Skia font-metric baseline/height plus shaped-run cluster carets when SkShaper is linked or Skia-measured prefix carets otherwise, stabilizes representative combining-mark/Indic-matra/Arabic-mark/Thai-mark/Lao-mark/Sinhala-mark/Khmer-vowel-coeng/Myanmar-mark/keycap/emoji-modifier/VS/ZWJ/regional-indicator cluster interiors in both caret paths, retries emoji-family fonts for emoji-hint text on the system FontMgr path, and uses optional SkShaper shaped glyph-run drawing once linked; SkParagraph-style line breaking and bidi reordering are now marked ready in the text maturity preflight, while color emoji determinism and typography conformance remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Web text uses canvas-rasterized glyph atlases, but full shaping, bidi, and line breaking conformance remain follow-up work.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::EmojiText,
      RendererFeatureStatus::Partial,
      "Native wgpu atlas upload, text vertices, and provider protocol can preserve RGBA color glyph payloads; Cosmic loads platform emoji fallback font candidates when available, keeps color swash pixels, and safe-maps provider-fragile single-codepoint, variation-selector, and ZWJ emoji samples before native layout so caret coverage remains stable; CoreText marks AppleColorEmoji raster payloads as RGBA on macOS; Linux fontconfig/FreeType can rasterize explicit emoji-family Noto Color Emoji glyphs as RGBA when available. Full emoji font fallback across native providers, ZWJ/color emoji conformance, and full grapheme shaping remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Skia raster detects representative single-codepoint, variation-selector, keycap, emoji-modifier, ZWJ, regional-indicator, Indic-matra, Arabic-mark, Thai-mark, Lao-mark, Sinhala-mark, Khmer, and Myanmar samples, prefers emoji coverage characters in system FontMgr FontFallbackRequest matching, stabilizes representative cluster interior carets, and on the system FontMgr path retries platform emoji font candidates before default-font fallback; deterministic color emoji, grapheme shaping, and cross-platform font fallback conformance remain follow-up work.",
      RendererFeatureStatus::Partial,
      "Browser canvas glyph rasterization can surface emoji where fonts support it. Diagnostic text conformance covers deterministic measurement and caret invariants, but not browser rasterization determinism or full grapheme shaping parity.",
    ),
    renderer_feature_capability_entry(
      RendererFeature::AsyncImage,
      RendererFeatureStatus::Partial,
      "Renderer-neutral image lifecycle state models loading, ready, failed, disposed, eviction, monotonic revision/change signals, and ImageResourceLoadCompletion ready/failed apply helpers; native WgpuRenderer exposes renderer-local image resource records plus revisioned snapshots, native WGPU providers forward revisioned snapshots through HostWindowRenderer, HostWindowRenderer exposes apply_image_resource_load_completion as the renderer-neutral completion apply port, native_image_load_completion decodes PNG/JPEG/BMP data URI and local-file sources into ready/failed completion payloads, macOS/Windows/Linux WGPU providers install provider-owned HostAsyncImageLoader hooks for that completion path, HostAsyncImageLoader scans loading records and gates late/cancelled completion callbacks before HostImageResourceCompletionSource routes native async loader completion snapshots through HostImageResourceRepaintTracker, and macOS/Windows/Linux hosts track presented revisions, call optional provider-owned async image loaders after present baseline, and route per-window repaint requests when newer image revisions are observed; off-main provider/platform async loader runtime observation remains follow-up work.",
      RendererFeatureStatus::Partial,
      "Skia raster image lifecycle uses the same renderer-neutral records, ImageResourceLoadCompletion apply helper, and revisioned snapshot contract, exposes renderer-local image-resource change callbacks when lifecycle revisions advance, native Skia providers create renderers with post-present async image loading, forward snapshots and callback setters through HostWindowRenderer, HostWindowRenderer exposes apply_image_resource_load_completion as the renderer-neutral completion apply port, HostAsyncImageLoader scans loading records and gates late/cancelled completion callbacks before HostImageResourceCompletionSource routes native async loader completion snapshots through HostImageResourceRepaintTracker, macOS/Windows/Linux hosts install baseline-guarded callbacks, call optional provider-owned async image loaders after present baseline, and request redraw for post-present image revisions, immutable failed sources are cached with diagnostics before placeholder drawing, local-file failures retry once the file appears, hosts discard closed-window image changes, and real Skia observation covers PNG/JPEG/BMP data URI decode, PNG/JPEG/BMP local-file decode, failed-image placeholder, failed-cache snapshot, local-file retry, image-resource callback snapshots, HostWindowRenderer callback bridge coverage, async image second-frame smoke, and dispose-record diagnostics; off-main provider/platform async loader runtime observation remains follow-up work.",
      RendererFeatureStatus::Partial,
      "Renderer-neutral image lifecycle state matches the browser async loading cache contract; WebGpuWasmRenderer and the backend WebRenderer facade expose app-visible image resource records plus revisioned snapshots, refresh loading, ready, or failed records from the browser cache after host submission, and the canonical Web boot path schedules a redraw when Image.onload or Image.onerror reports a resource change.",
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

///|
pub fn plan_renderer_command_fallbacks(
  commands : Array[@core.DrawCommand],
) -> RendererCommandPlan {
  let fallbacks : Array[RendererCommandFallback] = []
  let mut clip_depth = 0
  let mut rounded_clip_depth = 0
  let mut transform_depth = 0
  let mut opacity_depth = 0
  let mut layer_depth = 0
  let mut filter_depth = 0
  for index, command in commands {
    match command {
      @core.DrawCommand::PushClip(_) => clip_depth = clip_depth + 1
      @core.DrawCommand::PopClip =>
        if clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Clip,
              command="PopClip",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopClip has no matching PushClip",
            ),
          )
        } else {
          clip_depth = clip_depth - 1
        }
      @core.DrawCommand::PushRoundedClip(_) =>
        rounded_clip_depth = rounded_clip_depth + 1
      @core.DrawCommand::PopRoundedClip =>
        if rounded_clip_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Clip,
              command="PopRoundedClip",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopRoundedClip has no matching PushRoundedClip",
            ),
          )
        } else {
          rounded_clip_depth = rounded_clip_depth - 1
        }
      @core.DrawCommand::PushTransform(_) =>
        transform_depth = transform_depth + 1
      @core.DrawCommand::PopTransform =>
        if transform_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Transform,
              command="PopTransform",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopTransform has no matching PushTransform",
            ),
          )
        } else {
          transform_depth = transform_depth - 1
        }
      @core.DrawCommand::PushOpacity(_) => opacity_depth = opacity_depth + 1
      @core.DrawCommand::PopOpacity =>
        if opacity_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::Opacity,
              command="PopOpacity",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopOpacity has no matching PushOpacity",
            ),
          )
        } else {
          opacity_depth = opacity_depth - 1
        }
      @core.DrawCommand::PushLayer(_)
      | @core.DrawCommand::BeginCachedLayer(_) => layer_depth = layer_depth + 1
      @core.DrawCommand::PopLayer | @core.DrawCommand::EndCachedLayer(_) =>
        if layer_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::LayerCompositing,
              command="PopLayer",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopLayer has no matching PushLayer",
            ),
          )
        } else {
          layer_depth = layer_depth - 1
        }
      @core.DrawCommand::DrawCachedLayer(_) => ()
      @core.DrawCommand::PushFilter(_) => filter_depth = filter_depth + 1
      @core.DrawCommand::PopFilter =>
        if filter_depth <= 0 {
          fallbacks.push(
            renderer_command_fallback(
              index~,
              feature=RendererFeature::FilterEffect,
              command="PopFilter",
              kind=RendererCommandFallbackKind::UnbalancedPop,
              reason="PopFilter has no matching PushFilter",
            ),
          )
        } else {
          filter_depth = filter_depth - 1
        }
      @core.DrawCommand::DrawPath(_) => ()
      @core.DrawCommand::DrawShaderEffect(_) => ()
      _ => ()
    }
  }
  if clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Clip,
        command="PushClip",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open clip scope",
      ),
    )
  }
  if rounded_clip_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Clip,
        command="PushRoundedClip",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open rounded clip scope",
      ),
    )
  }
  if transform_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Transform,
        command="PushTransform",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open transform scope",
      ),
    )
  }
  if opacity_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::Opacity,
        command="PushOpacity",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open opacity scope",
      ),
    )
  }
  if layer_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::LayerCompositing,
        command="PushLayer",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open layer scope",
      ),
    )
  }
  if filter_depth > 0 {
    fallbacks.push(
      renderer_command_fallback(
        index=commands.length(),
        feature=RendererFeature::FilterEffect,
        command="PushFilter",
        kind=RendererCommandFallbackKind::UnclosedScope,
        reason="command stream ended with an open filter scope",
      ),
    )
  }
  {
    total_commands: commands.length(),
    fallback_count: fallbacks.length(),
    final_layer_depth: layer_depth,
    final_filter_depth: filter_depth,
    fallbacks,
  }
}

///|
fn renderer_command_fallback(
  index~ : Int,
  feature~ : RendererFeature,
  command~ : String,
  reason~ : String,
  kind? : RendererCommandFallbackKind = RendererCommandFallbackKind::PlannedFallback,
) -> RendererCommandFallback {
  { index, feature, command, kind, reason }
}
