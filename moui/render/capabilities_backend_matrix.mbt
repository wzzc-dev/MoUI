///|
/// [DEPRECATED] Central capability matrix that lists all renderer backends.
///
/// **Migration**: Each `RendererProvider` declares its own capabilities via the
/// `capabilities` field (ADR 0019). Consumers iterate registered providers
/// instead of this static list. The old function is preserved for incremental
/// migration and will be removed after all consumers migrate.
///
pub fn renderer_capability_backends() -> Array[RendererBackendKind] {
  [
    RendererBackendKind::SkiaRasterNative,
    RendererBackendKind::SkiaGpuNative,
    RendererBackendKind::WebGpuWasm,
    RendererBackendKind::NativeWgpu,
    RendererBackendKind::SunRasterNative,
    RendererBackendKind::Canvas2DWasm,
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
  canvas2d_status : RendererFeatureStatus,
  canvas2d_note : String,
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
      RendererBackendKind::SkiaGpuNative,
      skia_status,
      "Skia GPU reuses the native Skia command and resource semantics; " +
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
    renderer_backend_feature(
      feature,
      RendererBackendKind::Canvas2DWasm,
      canvas2d_status,
      canvas2d_note,
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
    TextShaping => RendererFeatureStatus::Supported
    EmojiText => RendererFeatureStatus::Supported
    AsyncImage => RendererFeatureStatus::Supported
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
      "Sun raster uses moui_sun/text FontFace and CoverageMask when fonts are registered, clips glyph drawing to the TextRun frame, and falls back to debug placeholder glyphs otherwise."
    Image =>
      "Sun raster decodes PNG/BMP data URI and local-file image sources through moui_sun Pixmap codecs, decodes JPEG data URI and local-file image sources through mizchi/image RGBA normalization, caches them as moui_sun Pixmaps, and validates contain/cover/stretch/scale-down/fit-width/fit-height placement plus source-crop geometry before drawing through draw_quality_pixmap or draw_quality_pixmap_rect."
    Clip =>
      "Sun raster applies transformed rectangular clips through moui_sun Canvas clip state; rounded clips render child commands into an offscreen canvas that inherits parent transform/clip state and composite back with per-pixel inverse-transform SDF rounded-rect masking; renderer-local tests cover 2x rectangular and rounded clip pixels."
    Transform =>
      "Sun raster maps MoUI affine transform scopes to moui_sun Canvas transform state."
    Opacity =>
      "Sun raster applies scoped opacity by multiplying Paint opacity for supported primitive commands."
    LayerCompositing =>
      "Sun raster composites PushLayer/PopLayer scopes by rendering child commands into an offscreen canvas that inherits parent transform/clip state and drawing the result with LayerSpec opacity, inverse-transform rectangular masks, inverse-transform rounded masks, and blend mode; renderer-local tests cover transform-scoped layers plus 2x layer and mask pixels. BeginCachedLayer/EndCachedLayer/DrawCachedLayer scopes cache layer pixmaps with content-revision, scale-factor, and physical-size validation, apply surrounding opacity when drawing cached pixels, allow same-size frame moves to reuse cache entries, clear cached layers on resize and dispose, use FIFO eviction, expose a cached-layer diagnostic summary with live entry keys, cumulative hit/miss/update/evict counters, and admission records that skip churn-without-hit identities while keeping hot layers admitted, and have renderer-local pixel coverage for cache hit, miss, refresh, resize, and dispose lifecycle."
    BlendMode =>
      "Sun raster maps all MoUI blend modes to moui_sun Paint blend modes and applies them when compositing PushLayer/PopLayer layer scopes; renderer-local pixel test covers Multiply."
    FilterEffect =>
      "Sun raster applies PushFilter/PopFilter scopes using offscreen canvases that inherit parent transform/clip state plus moui_sun PaintFilter pixmap-level color transforms for saturate, brightness, contrast, and color matrix effects; blur uses three-pass separable box blur (Gaussian approximation) on the layer pixmap before compositing; renderer-local tests cover transformed filter scopes."
    PathVector =>
      "Sun raster maps MoUI PathSpec verbs to moui_sun Path fill and stroke drawing."
    ShaderEffect =>
      "Sun raster implements checker shader-effect builtin with canvas-level tile rendering; vignette builtin uses concentric fill_circle calls for circular falloff; unknown builtins fall back to the spec fallback brush with an unsupported-command diagnostic."
    TextShaping =>
      "Sun raster text uses moui_sun/text FontFace, LayoutConfig, rasterize_text_face, and ShapingBuffer-backed layout metadata for font-metric baseline/height, direction/script-aware shaping inputs, paragraph metadata, and requested-family-first fallback chain resolution across registered faces; renderer-local tests cover mixed Latin-plus-emoji measurement, paragraph metadata, and frame-clipped text rendering."
    EmojiText =>
      "moui_sun/text FontFallbackPlan selects registered fallback faces for emoji spans after requested family faces, so mixed Latin-plus-emoji Sun text can measure and draw without missing fallback diagnostics when coverage is registered; Sun raster renders the selected glyph coverage through FontFace and CoverageMask."
    AsyncImage =>
      "Sun raster decodes PNG/JPEG/BMP data URI plus local-file image sources through moui_sun Pixmap codecs and a mizchi/image JPEG-to-RGBA adapter, records renderer-local loading/ready/failed/disposed image lifecycle snapshots, clears cached image pixmaps on dispose while preserving disposed records, exposes sun_image_load_completion and sun_image_load_completion_from_bytes for provider-owned decode completions, forwards revisioned image-resource snapshots plus callback/apply ports through native Sun providers, keeps cached repeat draws revision-stable, retries async local-file failures once the file appears, routes macOS/Linux/Windows Sun local-file loads through HostNativeAsyncImageSource with off-main file I/O, and package tests cover deferred native-source completion through the host repaint tracker into the second presented frame."
  }
}
