///|
pub(all) suberror SkiaRendererError {
  SkiaUnavailable
  SurfaceUnavailable
  CanvasUnavailable
  ReadPixelsUnavailable
  GpuContextUnavailable(String)
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaRendererError::message(self : SkiaRendererError) -> String {
  match self {
    SkiaUnavailable => "moui_skia/native is unavailable"
    SurfaceUnavailable => "failed to create Skia surface"
    CanvasUnavailable => "failed to acquire Skia canvas"
    ReadPixelsUnavailable => "failed to read Skia surface pixels"
    GpuContextUnavailable(description) =>
      "failed to create Skia GPU context: \{description}"
    PresentFailed(description) => "Skia presenter failed: \{description}"
  }
}

///|
pub(all) struct SkiaPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : Bytes
} derive(Eq, Debug)

///|
pub(all) struct SkiaPresentTarget {
  description : String
  present : (SkiaPixelFrame) -> Bool
}

///|
pub(all) enum SkiaSurfaceRoute {
  RasterSurfaceRoute
  MetalGpuSurfaceRoute
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaSurfaceRoute::is_gpu(self : SkiaSurfaceRoute) -> Bool {
  self is MetalGpuSurfaceRoute
}

///|
pub fn SkiaSurfaceRoute::label(self : SkiaSurfaceRoute) -> String {
  match self {
    RasterSurfaceRoute => "raster"
    MetalGpuSurfaceRoute => "metal-gpu"
  }
}

///|
pub(all) struct SkiaUnsupportedCommandDiagnostic {
  command : String
  reason : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SkiaTextVisualOrderProof {
  logical_text : String
  visual_text : String
  logical_cluster_count : Int
  visual_cluster_count : Int
  segment_count : Int
  glyph_count : Int
  width : Double
  visual_order_differs : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SkiaTextSelectionGeometryProof {
  text : String
  selection_range : @core.TextRange
  selection_rect_count : Int
  selected_line_count : Int
  line_count : Int
  hit_test_offset : Int
  hit_test_line_index : Int
  hit_test_inside : Bool
  visual_order_differs : Bool
  visual_segment_count : Int
  bidi_visual_order_evidence : Bool
} derive(Eq, Debug, ToJson)

///|
priv struct SkiaParagraphClusterBox {
  has_rect : Bool
  rtl : Bool
}

///|
pub(all) struct SkiaEmojiFontFallbackProof {
  text : String
  text_system_id : String
  font_family : String
  font_source : String
  fallback_language_tags : Array[String]
  fallback_script_tag : String
  fallback_language_tag_count : Int
  fallback_request_language_count : Int
  shaper : String
  glyph_format : String
  glyph_key : String
  glyph_count : Int
  cluster_count : Int
  glyph_width : Int
  glyph_height : Int
  resolved_missing_glyph_count : Int
  fallback_character : Int
  emoji_hint : Bool
  emoji_fallback_attempted : Bool
  fallback_request_ready : Bool
  missing_glyph_recovery_ready : Bool
  deterministic_color_emoji_ready : Bool
} derive(Eq, Debug, ToJson)

///|
priv struct SkiaRasterSurfacePreflight {
  physical_width : Int
  physical_height : Int
  target_ready : Bool
  frame_ready : Bool
  finalization_ready : Bool
  submission_ready : Bool
  resource_count : Int
  cacheable_resource_count : Int
  uncacheable_resource_count : Int
  gpu_backed_resource_count : Int
  surface_resource_count : Int
  byte_size : Int64
}

///|
fn SkiaRasterSurfacePreflight::summary(
  self : SkiaRasterSurfacePreflight,
) -> String {
  let dimensions_ready = self.physical_width > 0 && self.physical_height > 0
  let ready = dimensions_ready &&
    self.target_ready &&
    self.frame_ready &&
    self.finalization_ready &&
    self.submission_ready &&
    self.resource_count ==
    self.cacheable_resource_count + self.uncacheable_resource_count &&
    self.surface_resource_count > 0 &&
    self.gpu_backed_resource_count == 0 &&
    self.byte_size > 0L
  if ready {
    "SurfaceTargetDescriptor finalization preflight ready"
  } else {
    "SurfaceTargetDescriptor finalization preflight pending"
  }
}

///|
fn skia_gpu_context_status_label(
  status : @skia_native.SkiaGpuContextSupportStatus,
) -> String {
  match status {
    @skia_native.SkiaGpuContextAvailable => "available"
    @skia_native.SkiaGpuContextSkiaUnavailable => "skia-unavailable"
    @skia_native.SkiaGpuContextAnonymous => "anonymous"
    @skia_native.SkiaGpuContextMockUnsupported => "mock-unsupported"
    @skia_native.SkiaGpuContextBackendUnsupported => "backend-unsupported"
    @skia_native.SkiaGpuContextMetalOptInDisabled => "metal-opt-in-disabled"
    @skia_native.SkiaGpuContextMetalHeadersUnavailable =>
      "metal-headers-unavailable"
    @skia_native.SkiaGpuContextMetalRuntimeUnavailable =>
      "metal-runtime-unavailable"
  }
}

///|
pub fn skia_gpu_metal_preflight_summary() -> String {
  let context = @moui_skia.GpuContextDescriptor::metal(
    b"moui-render-skia-metal-preflight",
  )
  let target = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(1, 1),
    gpu_context_key=Some(context.resource_key()),
  )
  let plan = target.resource_plan()
  let target_plan_ready = target.has_gpu_context() &&
    plan.count_kind(@moui_skia.GpuSurfaceResource) == 1 &&
    plan.count_kind(@moui_skia.GpuContextResource) == 1 &&
    plan.gpu_backed_count == 2
  let status = @skia_native.Surface::gpu_context_support_status(context)
  let target_label = if target_plan_ready {
    "target-plan-ready"
  } else {
    "target-plan-pending"
  }
  let surface_label = if status.is_available() {
    "explicit-offscreen-surface-api-ready"
  } else {
    "explicit-offscreen-surface-api-pending"
  }
  "Metal GPU opt-in preflight: context=\{skia_gpu_context_status_label(status)}; \{target_label}; \{surface_label}; window-present=pending"
}

///|
priv struct SkiaTextDescriptorPreflight {
  family_count : Int
  fallback_character : Int
  fallback_ready : Bool
  fallback_resource_count : Int
  measurement_ready : Bool
  measurement_resource_count : Int
  shaping_ready : Bool
  shaping_resource_count : Int
  shaped_run_ready : Bool
  shaped_run_resource_count : Int
  glyph_run_ready : Bool
  glyph_run_resource_count : Int
}

///|
fn SkiaTextDescriptorPreflight::summary(
  self : SkiaTextDescriptorPreflight,
) -> String {
  if self.ready() {
    "text fallback/shaping descriptor preflight ready"
  } else {
    "text fallback/shaping descriptor preflight pending"
  }
}

///|
fn SkiaTextDescriptorPreflight::ready(
  self : SkiaTextDescriptorPreflight,
) -> Bool {
  self.family_count > 0 &&
  self.fallback_character >= 0 &&
  self.fallback_ready &&
  self.fallback_resource_count > 0 &&
  self.measurement_ready &&
  self.measurement_resource_count >= self.fallback_resource_count &&
  self.shaping_ready &&
  self.shaping_resource_count >= self.fallback_resource_count &&
  self.shaped_run_ready &&
  self.shaped_run_resource_count >= self.shaping_resource_count &&
  self.glyph_run_ready &&
  self.glyph_run_resource_count >= self.shaped_run_resource_count
}

///|
priv struct SkiaTextMaturityPreflight {
  descriptor_ready : Bool
  fallback_request_ready : Bool
  shaped_cluster_caret_ready : Bool
  fallback_cluster_caret_ready : Bool
  emoji_hint_ready : Bool
  empty_typeface_emoji_retry_disabled : Bool
  missing_glyph_recovery_ready : Bool
  bidi_reordering_ready : Bool
  paragraph_line_breaking_ready : Bool
  mixed_run_font_fallback_ready : Bool
  deterministic_color_emoji_ready : Bool
  unicode_17_grapheme_boundary_ready : Bool
  ready_count : Int
  gap_count : Int
}

///|
fn SkiaTextMaturityPreflight::summary(
  self : SkiaTextMaturityPreflight,
) -> String {
  let baseline_ready = self.descriptor_ready &&
    self.fallback_request_ready &&
    self.shaped_cluster_caret_ready &&
    self.fallback_cluster_caret_ready &&
    self.emoji_hint_ready &&
    self.empty_typeface_emoji_retry_disabled &&
    self.missing_glyph_recovery_ready
  let remaining_gaps_pending = !self.bidi_reordering_ready &&
    !self.paragraph_line_breaking_ready &&
    !self.deterministic_color_emoji_ready
  let baseline_label = if baseline_ready {
    "baseline ready"
  } else {
    "baseline pending"
  }
  let gap_label = if remaining_gaps_pending {
    "remaining tracked gaps pending"
  } else {
    "tracked gaps changed"
  }
  let grapheme_label = if self.unicode_17_grapheme_boundary_ready {
    "Unicode 17 grapheme boundary contract ready"
  } else {
    "Unicode 17 grapheme boundary contract pending"
  }
  let mixed_run_label = if self.mixed_run_font_fallback_ready {
    "mixed-run fallback ready; missing-glyph recovery ready; " +
    grapheme_label +
    "; bidi, paragraph line breaking, and color emoji pending"
  } else {
    "mixed-run fallback pending; missing-glyph recovery pending; " +
    grapheme_label +
    "; bidi, paragraph line breaking, and color emoji pending"
  }
  "text maturity audit partial: ready=" +
  self.ready_count.to_string() +
  " gaps=" +
  self.gap_count.to_string() +
  " " +
  baseline_label +
  ", " +
  gap_label +
  " (" +
  mixed_run_label +
  ")"
}

///|
pub(all) enum SkiaFontResolution {
  SystemFontMgr
  EmptyTypeface
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SkiaRasterRenderer {
  mut metrics : @render.RendererSurfaceMetrics
  target : SkiaPresentTarget
  font_resolution : SkiaFontResolution
  surface_route : SkiaSurfaceRoute
  gpu_context : @skia_native.GpuContext?
  mut surface : @skia_native.Surface
  image_cache : Map[String, @skia_native.Image]
  failed_images : Map[String, String]
  image_lifecycle : @render.ImageResourceLifecycle
  async_image_loading : Bool
  mut on_image_resource_change : ((@render.ImageResourceSnapshot) -> Unit)?
  mut present_count : Int
  mut unsupported_command_count : Int
  unsupported_command_diagnostics : Array[SkiaUnsupportedCommandDiagnostic]
  mut last_frame : SkiaPixelFrame?
  priv layer_cache : Array[SkiaCachedLayerImageEntry]
  priv layer_cache_admissions : Array[SkiaCachedLayerAdmissionRecord]
  priv mut layer_cache_tick : Int
}

///|
priv struct SkiaCachedLayerImageEntry {
  identity_key : String
  key : String
  runtime_key : String
  image : @skia_native.Image
  frame : @core.Rect
  physical_size : @moui_skia.ISize
  scale_factor : Double
  surface_route : SkiaSurfaceRoute
  content_revision : Int
  byte_size : Int64
  update_streak : Int
  mut hit_count : Int
  skip_reason : String
  last_admitted_frame : Int
  mut last_used : Int
}

///|
priv struct SkiaCachedLayerAdmissionRecord {
  identity_key : String
  mut update_streak : Int
  mut hit_count : Int
  mut skip_reason : String
  mut last_admitted_frame : Int
  mut last_revision : Int
}

///|
priv struct SkiaCachedLayerFrameStats {
  mut cache_hit_count : Int
  mut cache_miss_count : Int
  mut cache_update_count : Int
  mut cache_evict_count : Int
  missing_layer_keys : Array[String]
}

///|
priv struct SkiaTextMetrics {
  baseline : Double
  height : Double
}

///|
priv struct SkiaGlyphRun {
  glyphs : Array[@skia_native.GlyphId]
  positions : Array[@moui_skia.Point]
  clusters : Array[Int]
  width : Double
}

///|
priv struct SkiaTextPlacement {
  origin : @moui_skia.Point
  clip : @core.Rect
}

///|
priv struct SkiaTextRunSegment {
  text : String
  font : @skia_native.Font
  glyph_run : SkiaGlyphRun
  x_offset : Double
}

///|
priv struct SkiaResolvedTextLayout {
  segments : Array[SkiaTextRunSegment]
  width : Double
  metrics : SkiaTextMetrics
}

///|
priv enum SkiaCanvasScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
  Layer
  Filter
} derive(Eq)

///|
pub fn skia_available() -> Bool {
  @skia_native.skia_available()
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  let available = skia_available()
  let surface_preflight = raster_surface_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
  )
  let text_preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=12.0, weight=400),
    "MoUI",
  )
  let text_maturity = skia_text_maturity_preflight()
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    status=if available {
      @render.RendererCapabilityStatus::Ready
    } else {
      @render.RendererCapabilityStatus::Unavailable
    },
    can_render=available,
    can_resize=available,
    owns_surface=true,
    description="Native Skia raster renderer using moui_skia/native CPU surfaces, " +
      surface_preflight.summary() +
      ", " +
      skia_gpu_metal_preflight_summary() +
      ", " +
      text_preflight.summary() +
      ", " +
      text_maturity.summary() +
      ", flush-and-submit finalization, and platform pixel presenters.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  skia_raster_native_descriptor()
}

///|
pub fn skia_raster_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
    description="Native Skia raster renderer that presents copied RGBA premultiplied pixel frames to the host.",
  )
}

///|
pub fn skia_text_visual_order_proof(
  text : String,
  font? : @core.FontSpec = @core.FontSpec::new(size=20.0, weight=500),
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaTextVisualOrderProof? {
  if text == "" {
    return None
  }
  let logical_clusters = skia_grapheme_cluster_texts(text)
  let visual_clusters = skia_bidi_visual_cluster_texts(logical_clusters)
  match skia_resolved_text_layout_for_resolution(font, text, font_resolution) {
    Some(layout) => {
      let mut glyph_count = 0
      for segment in layout.segments {
        glyph_count += segment.glyph_run.glyphs.length()
      }
      Some({
        logical_text: skia_join_clusters(logical_clusters),
        visual_text: skia_join_clusters(visual_clusters),
        logical_cluster_count: logical_clusters.length(),
        visual_cluster_count: visual_clusters.length(),
        segment_count: layout.segments.length(),
        glyph_count,
        width: layout.width,
        visual_order_differs: !skia_string_arrays_equal(
          logical_clusters, visual_clusters,
        ),
      })
    }
    None => None
  }
}

///|
pub fn skia_text_selection_geometry_proof(
  text : String,
  selection? : @core.TextRange? = None,
  font? : @core.FontSpec = @core.FontSpec::new(size=20.0, weight=500),
  max_width? : Double = 96.0,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaTextSelectionGeometryProof? {
  if text == "" {
    return None
  }
  let system = skia_text_system(resolution=font_resolution)
  let layout = system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width~),
  )
  if layout.lines.is_empty() {
    return None
  }
  let selection_range = match selection {
    Some(range) => range
    None => skia_default_selection_geometry_range(layout)
  }
  let normalized = @core.TextGraphemeBoundaries::new(text~).normalize_range(
    selection_range,
  )
  let selection_rects = layout.selection_rects(normalized)
  let hit_line = if layout.lines.length() > 1 {
    layout.lines[1]
  } else {
    layout.lines[0]
  }
  let hit = layout.hit_test(
    @core.Point::new(
      x=(hit_line.origin.x + hit_line.size.width * 0.5).min(max_width),
      y=hit_line.origin.y + hit_line.size.height * 0.5,
    ),
  )
  let visual = skia_text_visual_order_proof(text, font~, font_resolution~)
  let (visual_order_differs, visual_segment_count, bidi_visual_order_evidence) = match
    visual {
    Some(proof) =>
      (
        proof.visual_order_differs,
        proof.segment_count,
        proof.visual_order_differs &&
        proof.logical_cluster_count == proof.visual_cluster_count &&
        proof.segment_count >= 3 &&
        proof.glyph_count >= 1,
      )
    None => (false, 0, false)
  }
  Some({
    text,
    selection_range: normalized,
    selection_rect_count: selection_rects.length(),
    selected_line_count: skia_selected_line_count(layout, normalized),
    line_count: layout.line_count(),
    hit_test_offset: hit.offset,
    hit_test_line_index: hit.line_index,
    hit_test_inside: hit.is_inside,
    visual_order_differs,
    visual_segment_count,
    bidi_visual_order_evidence,
  })
}

///|
pub fn skia_emoji_font_fallback_proof(
  text? : String = "\u{1F469}\u{200D}\u{1F4BB}",
  font? : @core.FontSpec = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
    size=32.0,
    weight=400,
  ),
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> SkiaEmojiFontFallbackProof? {
  if text == "" {
    return None
  }
  let emoji_hint = skia_text_contains_emoji_hint(text)
  let fallback_request = skia_font_fallback_request(font, text)
  let fallback_language_tags = skia_font_fallback_language_tags(text)
  let fallback_script_tag = skia_fallback_script_tag(fallback_language_tags)
  let fallback_request_language_count = fallback_request.language_count()
  match skia_resolved_text_layout_for_resolution(font, text, font_resolution) {
    Some(layout) => {
      let glyph_count = skia_resolved_text_layout_glyph_count(layout)
      if glyph_count <= 0 || layout.width <= 0.0 || layout.metrics.height <= 0.0 {
        return None
      }
      let text_system = skia_text_system(resolution=font_resolution)
      let shaper = if @skia_native.skia_shaper_available() {
        "skshaper"
      } else {
        "fallback-glyph-run"
      }
      let fallback_character = skia_representative_fallback_codepoint(text)
      let font_source = skia_emoji_font_source_label(font_resolution)
      let glyph_format = skia_emoji_glyph_format_label()
      let resolved_missing_glyph_count = skia_resolved_text_layout_missing_glyph_count(
        layout,
      )
      Some({
        text,
        text_system_id: text_system.id(),
        font_family: "emoji",
        font_source,
        fallback_language_tags,
        fallback_script_tag,
        fallback_language_tag_count: fallback_language_tags.length(),
        fallback_request_language_count,
        shaper,
        glyph_format,
        glyph_key: skia_emoji_glyph_key(
          font_source,
          text_system.id(),
          shaper,
          fallback_script_tag,
          fallback_language_tags,
          fallback_request_language_count,
          fallback_character,
          glyph_format,
        ),
        glyph_count,
        cluster_count: skia_grapheme_cluster_texts(text).length(),
        glyph_width: skia_positive_pixel_extent(layout.width),
        glyph_height: skia_positive_pixel_extent(layout.metrics.height),
        resolved_missing_glyph_count,
        fallback_character,
        emoji_hint,
        emoji_fallback_attempted: font_resolution ==
        SkiaFontResolution::SystemFontMgr &&
        emoji_hint,
        fallback_request_ready: !fallback_request.is_empty() &&
        fallback_request.has_character() &&
        fallback_request_language_count == fallback_language_tags.length(),
        missing_glyph_recovery_ready: skia_sample_missing_glyph_recovery_ready(),
        deterministic_color_emoji_ready: false,
      })
    }
    None => None
  }
}

///|
fn skia_emoji_font_source_label(resolution : SkiaFontResolution) -> String {
  match resolution {
    SkiaFontResolution::SystemFontMgr => "skia-system-fontmgr"
    SkiaFontResolution::EmptyTypeface => "skia-empty-typeface"
  }
}

///|
fn skia_emoji_glyph_format_label() -> String {
  "rgba"
}

///|
fn skia_fallback_script_tag(tags : Array[String]) -> String {
  if tags.is_empty() {
    ""
  } else {
    tags[0]
  }
}

///|
fn skia_emoji_glyph_key(
  font_source : String,
  text_system_id : String,
  shaper : String,
  fallback_script_tag : String,
  fallback_language_tags : Array[String],
  fallback_request_language_count : Int,
  fallback_character : Int,
  glyph_format : String,
) -> String {
  let script_key = if fallback_script_tag == "" {
    "script=und"
  } else {
    "script=\{fallback_script_tag}"
  }
  let language_key = if fallback_language_tags.is_empty() {
    "lang-tags=none"
  } else {
    "lang-tags=\{fallback_language_tags.join("+")}"
  }
  "\{font_source}|\{text_system_id}|\{shaper}|\{script_key}|langs=\{fallback_request_language_count}|\{language_key}|emoji-u+\{fallback_character}|\{glyph_format}"
}

///|
fn skia_resolved_text_layout_glyph_count(
  layout : SkiaResolvedTextLayout,
) -> Int {
  let mut glyph_count = 0
  for segment in layout.segments {
    glyph_count += segment.glyph_run.glyphs.length()
  }
  glyph_count
}

///|
fn skia_resolved_text_layout_missing_glyph_count(
  layout : SkiaResolvedTextLayout,
) -> Int {
  let mut missing_glyph_count = 0
  for segment in layout.segments {
    missing_glyph_count += skia_glyph_run_missing_glyph_count(segment.glyph_run)
  }
  missing_glyph_count
}

///|
fn skia_positive_pixel_extent(value : Double) -> Int {
  value.ceil().to_int().max(1)
}

///|
fn skia_default_selection_geometry_range(
  layout : @core.TextParagraphLayoutResult,
) -> @core.TextRange {
  if layout.lines.length() > 1 {
    @core.TextRange::new(
      start=layout.lines[0].text_range.start,
      end=layout.lines[1].text_range.end,
    )
  } else {
    @core.TextRange::new(start=0, end=layout.text.to_array().length())
  }
}

///|
fn skia_selected_line_count(
  layout : @core.TextParagraphLayoutResult,
  range : @core.TextRange,
) -> Int {
  let range = range.normalized()
  if range.is_collapsed() {
    return 1
  }
  let mut count = 0
  for line in layout.lines {
    if range.start < line.text_range.end && range.end > line.text_range.start {
      count += 1
    }
  }
  count
}

///|
pub fn SkiaPresentTarget::new(
  description~ : String,
  present~ : (SkiaPixelFrame) -> Bool,
) -> SkiaPresentTarget {
  { description, present }
}

///|
pub fn create_with_present_target(
  metrics : @render.RendererSurfaceMetrics,
  target : SkiaPresentTarget,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
  on_image_resource_change? : ((@render.ImageResourceSnapshot) -> Unit)? = None,
) -> SkiaRasterRenderer raise SkiaRendererError {
  create_with_present_target_and_route(
    metrics,
    target,
    surface_route=RasterSurfaceRoute,
    font_resolution~,
    async_image_loading~,
    on_image_resource_change~,
  )
}

///|
pub fn create_with_present_target_and_route(
  metrics : @render.RendererSurfaceMetrics,
  target : SkiaPresentTarget,
  surface_route? : SkiaSurfaceRoute = RasterSurfaceRoute,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
  on_image_resource_change? : ((@render.ImageResourceSnapshot) -> Unit)? = None,
) -> SkiaRasterRenderer raise SkiaRendererError {
  if !skia_available() {
    raise SkiaRendererError::SkiaUnavailable
  }
  let gpu_context = create_gpu_context(surface_route)
  let surface = create_surface(metrics, surface_route, gpu_context)
  {
    metrics,
    target,
    font_resolution,
    surface_route,
    gpu_context,
    surface,
    image_cache: {},
    failed_images: {},
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    async_image_loading,
    on_image_resource_change,
    present_count: 0,
    unsupported_command_count: 0,
    unsupported_command_diagnostics: [],
    last_frame: None,
    layer_cache: [],
    layer_cache_admissions: [],
    layer_cache_tick: 0,
  }
}

///|
fn create_gpu_context(
  surface_route : SkiaSurfaceRoute,
) -> @skia_native.GpuContext? raise SkiaRendererError {
  match surface_route {
    RasterSurfaceRoute => None
    MetalGpuSurfaceRoute => {
      let descriptor = @moui_skia.GpuContextDescriptor::metal(
        b"moui-render-skia-metal-gpu",
      )
      match @skia_native.GpuContext::metal(descriptor) {
        Some(context) => Some(context)
        None => {
          let status = @skia_native.Surface::gpu_context_support_status(
            descriptor,
          )
          raise SkiaRendererError::GpuContextUnavailable(
            skia_gpu_context_status_label(status),
          )
        }
      }
    }
  }
}

///|
fn create_surface(
  metrics : @render.RendererSurfaceMetrics,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @skia_native.Surface raise SkiaRendererError {
  let target = skia_surface_target(metrics, surface_route, gpu_context)
  match surface_route {
    RasterSurfaceRoute =>
      match @skia_native.Surface::for_target(target) {
        Some(surface) => surface
        None => raise SkiaRendererError::SurfaceUnavailable
      }
    MetalGpuSurfaceRoute =>
      match gpu_context {
        None =>
          raise SkiaRendererError::GpuContextUnavailable(
            "missing-metal-gpu-context",
          )
        Some(gpu_context) =>
          match
            @skia_native.Surface::for_target_with_gpu_context(
              target, gpu_context,
            ) {
            Some(surface) => surface
            None => raise SkiaRendererError::SurfaceUnavailable
          }
      }
  }
}

///|
fn skia_surface_target(
  metrics : @render.RendererSurfaceMetrics,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @moui_skia.SurfaceTargetDescriptor {
  let size = @moui_skia.ISize::new(
    skia_dim_to_int(metrics.physical_size.width),
    skia_dim_to_int(metrics.physical_size.height),
  )
  skia_surface_target_for_physical_size(size, surface_route, gpu_context)
}

///|
fn skia_surface_target_for_physical_size(
  size : @moui_skia.ISize,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @moui_skia.SurfaceTargetDescriptor {
  match surface_route {
    RasterSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(size)
    MetalGpuSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
        size,
        gpu_context_key=match gpu_context {
          Some(gpu_context) => Some(gpu_context.resource_key())
          None => None
        },
      )
  }
}

///|
fn skia_raster_surface_target(
  metrics : @render.RendererSurfaceMetrics,
) -> @moui_skia.SurfaceTargetDescriptor {
  @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(
      skia_dim_to_int(metrics.physical_size.width),
      skia_dim_to_int(metrics.physical_size.height),
    ),
  )
}

///|
fn raster_surface_preflight(
  metrics : @render.RendererSurfaceMetrics,
) -> SkiaRasterSurfacePreflight {
  let target = skia_raster_surface_target(metrics)
  let command_list = @moui_skia.RenderCommandList::for_target(target).clear(
    @moui_skia.Color::transparent(),
  )
  let frame = command_list.frame_descriptor(target)
  let finalization = frame.finalization_descriptor()
  let submission = frame.submission_descriptor()
  let resource_plan = finalization.resource_plan
  SkiaRasterSurfacePreflight::{
    physical_width: target.dimensions().width,
    physical_height: target.dimensions().height,
    target_ready: !target.resource_key().is_empty(),
    frame_ready: frame.is_ready(),
    finalization_ready: finalization.is_ready(),
    submission_ready: submission.is_ready(),
    resource_count: resource_plan.length(),
    cacheable_resource_count: resource_plan.cacheable_count,
    uncacheable_resource_count: resource_plan.uncacheable_count,
    gpu_backed_resource_count: resource_plan.gpu_backed_count,
    surface_resource_count: resource_plan.count_kind(@moui_skia.SurfaceResource),
    byte_size: resource_plan.byte_size,
  }
}

///|
fn skia_text_descriptor_preflight(
  font : @core.FontSpec,
  text : String,
) -> SkiaTextDescriptorPreflight {
  let families = skia_preflight_family_candidates(font)
  let fallback = skia_font_fallback_request(font, text)
  let font_key = fallback
    .font_descriptor(size=Float::from_double(font.size))
    .resource_key()
  let text_bytes = @utf8.encode(text[:], bom=false)
  let run = @moui_skia.TextRunDescriptor::new(
    range=@moui_skia.TextRange::new(0, text_bytes.length()),
    fallback~,
  )
  let measurement = @moui_skia.TextMeasurementDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
    shape=true,
  )
  let shaping = @moui_skia.TextShapingDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
  )
  let glyph_count = skia_preflight_glyph_count(text)
  let shaped_run = shaping.shaped_run_descriptor(
    glyph_count~,
    cluster_count=glyph_count,
    advance=@moui_skia.Point::new(Float::from_double(font.size), 0.0),
  )
  let glyph_run = shaped_run.glyph_run_descriptor(
    glyph_ids=skia_preflight_glyph_ids(glyph_count),
    positions=skia_preflight_glyph_positions(glyph_count),
    clusters=skia_preflight_glyph_clusters(glyph_count),
  )
  let fallback_plan = fallback.resource_plan(size=Float::from_double(font.size))
  let measurement_plan = measurement.resource_plan(text_bytes)
  let shaping_plan = shaping.resource_plan(text_bytes)
  let shaped_run_plan = shaped_run.resource_plan(text_bytes)
  let glyph_run_plan = glyph_run.resource_plan(text_bytes)
  SkiaTextDescriptorPreflight::{
    family_count: families.length(),
    fallback_character: fallback.character,
    fallback_ready: !fallback.is_empty(),
    fallback_resource_count: fallback_plan.length(),
    measurement_ready: measurement.is_shaped(),
    measurement_resource_count: measurement_plan.length(),
    shaping_ready: !shaping.resource_key(text_bytes).is_empty(),
    shaping_resource_count: shaping_plan.length(),
    shaped_run_ready: shaped_run.is_valid(),
    shaped_run_resource_count: shaped_run_plan.length(),
    glyph_run_ready: glyph_run.is_valid(),
    glyph_run_resource_count: glyph_run_plan.length(),
  }
}

///|
fn skia_text_maturity_preflight() -> SkiaTextMaturityPreflight {
  let descriptor = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=18.0, weight=500, style=@core.FontStyle::Italic),
    "A\u{1F469}\u{200D}\u{1F373}",
  )
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=500,
  )
  let fallback_request = skia_font_fallback_request(
    font, "A\u{1F469}\u{200D}\u{1F373}",
  )
  let shaped_cluster_caret_ready = skia_sample_shaped_cluster_caret_ready()
  let fallback_cluster_caret_ready = skia_sample_fallback_cluster_caret_ready()
  let emoji_hint_ready = skia_text_contains_emoji_hint(
      "\u{1F469}\u{200D}\u{1F373}",
    ) &&
    skia_representative_fallback_codepoint("A\u{1F469}\u{200D}\u{1F373}") ==
    0x1F469
  let empty_typeface_emoji_retry_disabled = skia_emoji_fallback_draw_font(
      font,
      "\u{1F469}\u{200D}\u{1F373}",
      SkiaFontResolution::EmptyTypeface,
    )
    is None
  let missing_glyph_recovery_ready = skia_sample_missing_glyph_recovery_ready()
  let mixed_run_font_fallback_ready = skia_mixed_text_segments("A你\u{1F642}B").length() ==
    4 &&
    skia_grapheme_cluster_texts("\u{1F469}\u{200D}\u{1F4BB}").length() == 1
  let unicode_17_grapheme_boundary_ready = skia_unicode_17_grapheme_boundary_contract_ready()
  let bidi_reordering_ready = false
  let paragraph_line_breaking_ready = false
  let deterministic_color_emoji_ready = false
  let ready_count = skia_ready_count([
    descriptor.ready(),
    !fallback_request.is_empty() && fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    missing_glyph_recovery_ready,
    mixed_run_font_fallback_ready,
    unicode_17_grapheme_boundary_ready,
  ])
  let gap_count = skia_gap_count([
    bidi_reordering_ready, paragraph_line_breaking_ready, deterministic_color_emoji_ready,
  ])
  SkiaTextMaturityPreflight::{
    descriptor_ready: descriptor.ready(),
    fallback_request_ready: !fallback_request.is_empty() &&
    fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    missing_glyph_recovery_ready,
    bidi_reordering_ready,
    paragraph_line_breaking_ready,
    mixed_run_font_fallback_ready,
    deterministic_color_emoji_ready,
    unicode_17_grapheme_boundary_ready,
    ready_count,
    gap_count,
  }
}

///|
fn skia_unicode_17_grapheme_boundary_contract_ready() -> Bool {
  skia_grapheme_cluster_boundaries_match("\r\n", [0, 2]) &&
  skia_grapheme_cluster_boundaries_match("\u{094D}\u{0915}", [0, 1, 2]) &&
  skia_grapheme_cluster_boundaries_match("a\u{094D}\u{0924}", [0, 2, 3]) &&
  skia_grapheme_cluster_boundaries_match("\u{1B32}\u{1B44}\u{1B2F}", [0, 3]) &&
  skia_grapheme_cluster_boundaries_match(
    "\u{179F}\u{17D2}\u{178F}\u{17D2}\u{179A}\u{17B8}",
    [0, 6],
  ) &&
  skia_grapheme_cluster_boundaries_match("\u{1FC00}\u{200D}\u{1FC01}", [0, 3])
}

///|
fn skia_grapheme_cluster_boundaries_match(
  text : String,
  expected : Array[Int],
) -> Bool {
  let actual = [0]
  let mut cursor = 0
  for cluster in skia_grapheme_cluster_texts(text) {
    cursor += cluster.to_array().length()
    actual.push(cursor)
  }
  if actual.length() != expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    if actual[index] != expected[index] {
      return false
    }
  }
  true
}

///|
fn skia_ready_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if value {
      count += 1
    }
  }
  count
}

///|
fn skia_gap_count(values : Array[Bool]) -> Int {
  let mut count = 0
  for value in values {
    if !value {
      count += 1
    }
  }
  count
}

///|
fn skia_sample_shaped_cluster_caret_ready() -> Bool {
  let run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(14.0, 0.0),
      @moui_skia.Point::new(28.0, 0.0),
    ],
    clusters: [0, 1, 12],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F469}\u{200D}\u{1F373}B", run) {
    Some(carets) =>
      skia_carets_are_monotonic(carets) &&
      carets.length() == 6 &&
      carets[1] == carets[2] &&
      carets[2] == carets[3] &&
      carets[5] == 34.0
    None => false
  }
}

///|
fn skia_sample_fallback_cluster_caret_ready() -> Bool {
  let devanagari = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{0937}B",
    [0.0, 10.0, 14.0, 20.0, 30.0, 38.0],
  )
  let zwj_emoji = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F469}\u{200D}\u{1F373}B",
    [0.0, 14.0, 20.0, 22.0, 28.0, 34.0],
  )
  let tag_flag = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0.0, 9.0, 11.0, 13.0, 15.0, 25.0, 33.0],
  )
  let paired_flags = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F1FA}\u{1F1F8}\u{1F1EF}\u{1F1F5}B",
    [0.0, 9.0, 13.0, 21.0, 27.0, 35.0, 43.0],
  )
  let prepend_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{0600}\u{0628}\u{0651}B",
    [0.0, 8.0, 11.0, 14.0, 23.0, 31.0],
  )
  let thai_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E01}\u{0E34}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  let sinhala_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCF}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  let myanmar_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{1039}\u{1001}B",
    [0.0, 10.0, 14.0, 18.0, 25.0, 32.0],
  )
  let hangul_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{1100}\u{1161}\u{11A8}B",
    [0.0, 9.0, 13.0, 18.0, 26.0, 34.0],
  )
  skia_carets_are_monotonic(devanagari) &&
  devanagari.length() == 6 &&
  devanagari[1] == devanagari[2] &&
  devanagari[2] == devanagari[3] &&
  devanagari[5] == 38.0 &&
  skia_carets_are_monotonic(zwj_emoji) &&
  zwj_emoji.length() == 6 &&
  zwj_emoji[1] == zwj_emoji[2] &&
  zwj_emoji[2] == zwj_emoji[3] &&
  zwj_emoji[5] == 34.0 &&
  skia_carets_are_monotonic(tag_flag) &&
  tag_flag.length() == 7 &&
  tag_flag[1] == tag_flag[2] &&
  tag_flag[2] == tag_flag[3] &&
  tag_flag[3] == tag_flag[4] &&
  tag_flag[6] == 33.0 &&
  skia_carets_are_monotonic(paired_flags) &&
  paired_flags.length() == 7 &&
  paired_flags[1] == paired_flags[2] &&
  paired_flags[3] == paired_flags[4] &&
  paired_flags[6] == 43.0 &&
  skia_carets_are_monotonic(prepend_mark) &&
  prepend_mark.length() == 6 &&
  prepend_mark[1] == prepend_mark[2] &&
  prepend_mark[2] == prepend_mark[3] &&
  prepend_mark[5] == 31.0 &&
  skia_carets_are_monotonic(thai_mark) &&
  thai_mark.length() == 5 &&
  thai_mark[1] == thai_mark[2] &&
  thai_mark[4] == 29.0 &&
  skia_carets_are_monotonic(sinhala_mark) &&
  sinhala_mark.length() == 5 &&
  sinhala_mark[1] == sinhala_mark[2] &&
  sinhala_mark[4] == 31.0 &&
  skia_carets_are_monotonic(myanmar_conjunct) &&
  myanmar_conjunct.length() == 6 &&
  myanmar_conjunct[1] == myanmar_conjunct[2] &&
  myanmar_conjunct[2] == myanmar_conjunct[3] &&
  myanmar_conjunct[5] == 32.0 &&
  skia_carets_are_monotonic(hangul_jamo) &&
  hangul_jamo.length() == 6 &&
  hangul_jamo[1] == hangul_jamo[2] &&
  hangul_jamo[2] == hangul_jamo[3] &&
  hangul_jamo[5] == 34.0
}

///|
fn skia_sample_missing_glyph_recovery_ready() -> Bool {
  let blank_primary = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let partial_primary = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let improved = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(19),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let complete = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(18),
      @skia_native.GlyphId::new(19),
      @skia_native.GlyphId::new(20),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  skia_glyph_run_missing_glyph_count(partial_primary) == 2 &&
  !skia_glyph_run_can_draw_text(partial_primary) &&
  skia_glyph_run_improves_missing_glyphs(partial_primary, improved) &&
  skia_glyph_run_improves_missing_glyphs(blank_primary, improved) &&
  skia_glyph_run_can_draw_text(complete) &&
  !skia_glyph_run_improves_missing_glyphs(improved, partial_primary)
}

///|
fn skia_carets_are_monotonic(carets : Array[Double]) -> Bool {
  let mut previous = 0.0
  for index, caret in carets {
    if index == 0 {
      previous = caret
    } else if caret < previous {
      return false
    } else {
      previous = caret
    }
  }
  true
}

///|
fn skia_preflight_family_candidates(font : @core.FontSpec) -> Array[String] {
  let candidates : Array[String] = []
  for family in font.families.families {
    for candidate in skia_font_family_candidates(family) {
      if !candidates.contains(candidate) {
        candidates.push(candidate)
      }
    }
  }
  if candidates.is_empty() {
    skia_font_family_candidates(@core.FontFamily::SystemUi)
  } else {
    candidates
  }
}

///|
fn skia_representative_fallback_codepoint(text : String) -> Int {
  let mut first = 0
  let mut first_non_ascii = 0
  for ch in text {
    let codepoint = ch.to_int()
    if first == 0 {
      first = codepoint
    }
    if first_non_ascii == 0 && codepoint >= 0x80 {
      first_non_ascii = codepoint
    }
    if skia_codepoint_is_emoji_hint(codepoint) {
      return codepoint
    }
  }
  if first_non_ascii > 0 {
    first_non_ascii
  } else {
    first
  }
}

///|
fn skia_preflight_glyph_count(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count = count + 1
  }
  Int::max(1, count)
}

///|
fn skia_preflight_glyph_ids(count : Int) -> Array[Int] {
  let ids : Array[Int] = []
  for index in 0..<count {
    ids.push(index + 1)
  }
  ids
}

///|
fn skia_preflight_glyph_positions(count : Int) -> Array[@moui_skia.Point] {
  let positions : Array[@moui_skia.Point] = []
  for index in 0..<count {
    positions.push(@moui_skia.Point::new(Float::from_int(index), 0.0))
  }
  positions
}

///|
fn skia_preflight_glyph_clusters(count : Int) -> Array[Int] {
  let clusters : Array[Int] = []
  for index in 0..<count {
    clusters.push(index)
  }
  clusters
}

///|
pub fn SkiaRasterRenderer::resize(
  self : SkiaRasterRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise SkiaRendererError {
  self.metrics = metrics
  self.surface = create_surface(metrics, self.surface_route, self.gpu_context)
  self.clear_layer_cache()
}

///|
pub fn SkiaRasterRenderer::surface_route(
  self : SkiaRasterRenderer,
) -> SkiaSurfaceRoute {
  self.surface_route
}

///|
pub fn SkiaRasterRenderer::surface_is_gpu(self : SkiaRasterRenderer) -> Bool {
  self.surface.descriptor().is_gpu()
}

///|
pub fn SkiaRasterRenderer::surface_diagnostic_summary(
  self : SkiaRasterRenderer,
) -> String {
  let context = match self.gpu_context {
    Some(gpu_context) =>
      skia_gpu_context_status_label(gpu_context.support_status())
    None => "none"
  }
  let gpu_surface = if self.surface_is_gpu() { "true" } else { "false" }
  "surface_route=\{self.surface_route.label()}; surface_gpu=\{gpu_surface}; gpu_context=\{context}; dimensions=\{self.surface.width()}x\{self.surface.height()}"
}

///|
fn SkiaRasterRenderer::record_unsupported_command(
  self : SkiaRasterRenderer,
  command : String,
  reason : String,
) -> Unit {
  self.unsupported_command_count = self.unsupported_command_count + 1
  self.unsupported_command_diagnostics.push({ command, reason })
}

///|
fn skia_scope_name(scope : SkiaCanvasScopeKind) -> String {
  match scope {
    Clip => "clip"
    RoundedClip => "rounded-clip"
    Transform => "transform"
    Opacity => "opacity"
    Layer => "layer"
    Filter => "filter"
  }
}

///|
fn skia_scope_push_command(scope : SkiaCanvasScopeKind) -> String {
  match scope {
    Clip => "PushClip"
    RoundedClip => "PushRoundedClip"
    Transform => "PushTransform"
    Opacity => "PushOpacity"
    Layer => "PushLayer"
    Filter => "PushFilter"
  }
}

///|
fn skia_scope_pop_command(scope : SkiaCanvasScopeKind) -> String {
  match scope {
    Clip => "PopClip"
    RoundedClip => "PopRoundedClip"
    Transform => "PopTransform"
    Opacity => "PopOpacity"
    Layer => "PopLayer"
    Filter => "PopFilter"
  }
}

///|
pub fn SkiaRasterRenderer::render(
  self : SkiaRasterRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise SkiaRendererError {
  match self.surface.canvas() {
    Some(canvas) => {
      canvas.clear(skia_color(@render.first_clear_color(commands)))
      let saved = canvas.save()
      canvas.scale(
        @moui_skia.Size::new(
          Float::from_double(self.metrics.scale_factor),
          Float::from_double(self.metrics.scale_factor),
        ),
      )
      self.unsupported_command_count = 0
      self.unsupported_command_diagnostics.clear()
      let canvas_scopes : Array[SkiaCanvasScopeKind] = []
      for command in commands {
        self.render_command(canvas, command, canvas_scopes)
      }
      if !canvas_scopes.is_empty() {
        for scope in canvas_scopes {
          self.record_unsupported_command(
            skia_scope_push_command(scope),
            "command stream ended with an open \{skia_scope_name(scope)} scope",
          )
        }
      }
      canvas.restore_to_count(saved)
      if !self.surface.flush_and_submit() {
        raise SkiaRendererError::SurfaceUnavailable
      }
      let frame = self.read_frame()
      self.last_frame = Some(frame)
      if (self.target.present)(frame) {
        self.present_count = self.present_count + 1
      } else {
        raise SkiaRendererError::PresentFailed(self.target.description)
      }
    }
    None => raise SkiaRendererError::CanvasUnavailable
  }
}

///|
pub fn SkiaRasterRenderer::render_frame(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  self.render_frame_inner(frame) catch {
    err => {
      self.record_unsupported_command("RenderFrame", err.message())
      @render.RenderFrameResult::new(presented=false)
    }
  }
}

///|
fn SkiaRasterRenderer::render_frame_inner(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult raise SkiaRendererError {
  match self.surface.canvas() {
    Some(canvas) => {
      canvas.clear(skia_color(frame.clear_color))
      let saved = canvas.save()
      canvas.scale(
        @moui_skia.Size::new(
          Float::from_double(self.metrics.scale_factor),
          Float::from_double(self.metrics.scale_factor),
        ),
      )
      self.unsupported_command_count = 0
      self.unsupported_command_diagnostics.clear()
      let stats = SkiaCachedLayerFrameStats::new()
      let canvas_scopes : Array[SkiaCanvasScopeKind] = []
      let complete = self.render_cached_command_range(
        canvas,
        frame.commands,
        start_index=0,
        end_index=frame.commands.length(),
        canvas_scopes,
        stats,
      )
      if !canvas_scopes.is_empty() {
        for scope in canvas_scopes {
          self.record_unsupported_command(
            skia_scope_push_command(scope),
            "command stream ended with an open \{skia_scope_name(scope)} scope",
          )
        }
      }
      canvas.restore_to_count(saved)
      if !complete {
        return stats.to_render_frame_result(presented=false)
      }
      if !self.surface.flush_and_submit() {
        raise SkiaRendererError::SurfaceUnavailable
      }
      let skia_frame = self.read_frame()
      self.last_frame = Some(skia_frame)
      if (self.target.present)(skia_frame) {
        self.present_count = self.present_count + 1
        stats.to_render_frame_result(presented=true)
      } else {
        raise SkiaRendererError::PresentFailed(self.target.description)
      }
    }
    None => raise SkiaRendererError::CanvasUnavailable
  }
}

///|
fn SkiaCachedLayerFrameStats::new() -> SkiaCachedLayerFrameStats {
  {
    cache_hit_count: 0,
    cache_miss_count: 0,
    cache_update_count: 0,
    cache_evict_count: 0,
    missing_layer_keys: [],
  }
}

///|
fn SkiaCachedLayerFrameStats::record_missing(
  self : SkiaCachedLayerFrameStats,
  key : String,
) -> Unit {
  self.cache_miss_count = self.cache_miss_count + 1
  if !self.missing_layer_keys.any(existing => existing == key) {
    self.missing_layer_keys.push(key)
  }
}

///|
fn SkiaCachedLayerFrameStats::to_render_frame_result(
  self : SkiaCachedLayerFrameStats,
  presented~ : Bool,
) -> @render.RenderFrameResult {
  @render.RenderFrameResult::new(
    presented~,
    cache_hit_count=self.cache_hit_count,
    cache_miss_count=self.cache_miss_count,
    cache_update_count=self.cache_update_count,
    cache_evict_count=self.cache_evict_count,
    missing_layer_keys=self.missing_layer_keys.copy(),
  )
}

///|
fn SkiaRasterRenderer::render_cached_command_range(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  commands : Array[@core.DrawCommand],
  start_index~ : Int,
  end_index~ : Int,
  canvas_scopes : Array[SkiaCanvasScopeKind],
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  let mut index = start_index
  while index < end_index {
    match commands[index] {
      @core.DrawCommand::BeginCachedLayer(spec) =>
        match find_cached_layer_end(commands, index + 1, spec.key) {
          Some(layer_end) => {
            if !self.update_cached_layer(
                canvas,
                spec,
                commands,
                start_index=index + 1,
                end_index=layer_end,
                stats,
              ) {
              return false
            }
            index = layer_end + 1
          }
          None => {
            self.record_unsupported_command(
              "BeginCachedLayer",
              "cached layer command stream ended without matching EndCachedLayer for \{spec.key}",
            )
            return false
          }
        }
      @core.DrawCommand::EndCachedLayer(_) => return true
      @core.DrawCommand::DrawCachedLayer(spec) => {
        if !self.draw_cached_layer(canvas, spec, stats) {
          return false
        }
        index = index + 1
      }
      command => {
        self.render_command(canvas, command, canvas_scopes)
        index = index + 1
      }
    }
  }
  true
}

///|
fn find_cached_layer_end(
  commands : Array[@core.DrawCommand],
  start_index : Int,
  key : String,
) -> Int? {
  let mut depth = 0
  for index in start_index..<commands.length() {
    match commands[index] {
      @core.DrawCommand::BeginCachedLayer(_) => depth = depth + 1
      @core.DrawCommand::EndCachedLayer(end_key) =>
        if depth == 0 {
          if end_key == key {
            return Some(index)
          } else {
            return None
          }
        } else {
          depth = depth - 1
        }
      _ => ()
    }
  }
  None
}

///|
fn SkiaRasterRenderer::update_cached_layer(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.CachedLayerSpec,
  commands : Array[@core.DrawCommand],
  start_index~ : Int,
  end_index~ : Int,
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  if spec.frame.is_empty() {
    return true
  }
  let physical_size = skia_cached_layer_physical_size(
    spec.frame,
    self.metrics.scale_factor,
  )
  let byte_size = skia_cached_layer_byte_size(physical_size)
  let budget = self.layer_cache_budget_bytes()
  if budget > 0L && byte_size > budget {
    self.record_unsupported_command(
      "BeginCachedLayer",
      "cached layer \{spec.key} exceeds Skia layer cache budget; rendered directly",
    )
    return self.render_uncached_layer_to_canvas(
      canvas,
      spec,
      commands,
      start_index~,
      end_index~,
      stats,
    )
  }
  match self.create_layer_surface(physical_size) {
    Some(layer_surface) =>
      match layer_surface.canvas() {
        Some(layer_canvas) => {
          layer_canvas.clear(@moui_skia.Color::transparent())
          let saved = layer_canvas.save()
          layer_canvas.scale(
            @moui_skia.Size::new(
              Float::from_double(self.metrics.scale_factor),
              Float::from_double(self.metrics.scale_factor),
            ),
          )
          layer_canvas.translate(
            @moui_skia.Point::new(
              Float::from_double(0.0 - spec.frame.origin.x),
              Float::from_double(0.0 - spec.frame.origin.y),
            ),
          )
          let layer_scopes : Array[SkiaCanvasScopeKind] = []
          let complete = self.render_cached_command_range(
            layer_canvas,
            commands,
            start_index~,
            end_index~,
            layer_scopes,
            stats,
          )
          if !layer_scopes.is_empty() {
            for scope in layer_scopes {
              self.record_unsupported_command(
                skia_scope_push_command(scope),
                "cached layer command stream ended with an open \{skia_scope_name(scope)} scope",
              )
            }
          }
          layer_canvas.restore_to_count(saved)
          if !complete {
            return false
          }
          if !layer_surface.flush_and_submit() {
            self.record_unsupported_command(
              "BeginCachedLayer",
              "cached layer surface flush failed for \{spec.key}; rendered directly",
            )
            return self.render_uncached_layer_to_canvas(
              canvas,
              spec,
              commands,
              start_index~,
              end_index~,
              stats,
            )
          }
          match layer_surface.image_snapshot() {
            Some(image) => {
              let identity_key = self.skia_layer_cache_identity_key(
                spec,
                physical_size,
              )
              let admission = self.layer_cache_admission_record(identity_key)
              admission.record_update(spec.content_revision)
              let entry = SkiaCachedLayerImageEntry::{
                identity_key,
                key: self.skia_layer_cache_key(spec, physical_size),
                runtime_key: spec.key,
                image,
                frame: spec.frame,
                physical_size,
                scale_factor: self.metrics.scale_factor,
                surface_route: self.surface_route,
                content_revision: spec.content_revision,
                byte_size,
                update_streak: admission.update_streak,
                hit_count: admission.hit_count,
                skip_reason: admission.skip_reason,
                last_admitted_frame: admission.last_admitted_frame,
                last_used: 0,
              }
              match self.cached_layer_admission_skip_reason(
                admission,
                byte_size,
                budget,
              ) {
                Some(reason) => {
                  admission.skip_reason = reason
                  self.remove_cached_layers_by_identity(entry.identity_key)
                }
                None => {
                  if self.store_cached_layer(entry, admission) {
                    admission.skip_reason = ""
                    stats.cache_update_count = stats.cache_update_count + 1
                    stats.cache_evict_count += self
                      .evict_cached_layers_if_needed()
                  }
                }
              }
              self.draw_cached_layer_image(
                canvas,
                image,
                spec.frame,
                physical_size,
              )
              true
            }
            None => {
              self.record_unsupported_command(
                "BeginCachedLayer",
                "cached layer snapshot failed for \{spec.key}; rendered directly",
              )
              self.render_uncached_layer_to_canvas(
                canvas,
                spec,
                commands,
                start_index~,
                end_index~,
                stats,
              )
            }
          }
        }
        None => {
          self.record_unsupported_command(
            "BeginCachedLayer",
            "cached layer canvas unavailable for \{spec.key}; rendered directly",
          )
          self.render_uncached_layer_to_canvas(
            canvas,
            spec,
            commands,
            start_index~,
            end_index~,
            stats,
          )
        }
      }
    None => {
      self.record_unsupported_command(
        "BeginCachedLayer",
        "cached layer surface unavailable for \{spec.key}; rendered directly",
      )
      self.render_uncached_layer_to_canvas(
        canvas,
        spec,
        commands,
        start_index~,
        end_index~,
        stats,
      )
    }
  }
}

///|
fn SkiaRasterRenderer::render_uncached_layer_to_canvas(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.CachedLayerSpec,
  commands : Array[@core.DrawCommand],
  start_index~ : Int,
  end_index~ : Int,
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  let saved = canvas.save_count()
  self.push_layer(
    canvas,
    @core.LayerSpec::new(
      mask=@core.LayerMask::RectMask(spec.frame),
      offscreen=true,
    ),
  )
  let layer_scopes : Array[SkiaCanvasScopeKind] = []
  let complete = self.render_cached_command_range(
    canvas,
    commands,
    start_index~,
    end_index~,
    layer_scopes,
    stats,
  )
  if !layer_scopes.is_empty() {
    for scope in layer_scopes {
      self.record_unsupported_command(
        skia_scope_push_command(scope),
        "uncached fallback layer command stream ended with an open \{skia_scope_name(scope)} scope",
      )
    }
  }
  canvas.restore_to_count(saved)
  complete
}

///|
fn SkiaRasterRenderer::draw_cached_layer(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.CachedLayerSpec,
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  if spec.frame.is_empty() {
    return true
  }
  let physical_size = skia_cached_layer_physical_size(
    spec.frame,
    self.metrics.scale_factor,
  )
  let key = self.skia_layer_cache_key(spec, physical_size)
  match self.lookup_cached_layer(key) {
    Some(entry) => {
      if entry.runtime_key != spec.key ||
        entry.frame != spec.frame ||
        entry.scale_factor != self.metrics.scale_factor ||
        entry.surface_route != self.surface_route ||
        entry.content_revision != spec.content_revision {
        stats.record_missing(spec.key)
        return false
      }
      entry.last_used = self.next_layer_cache_tick()
      entry.hit_count = entry.hit_count + 1
      let identity_key = self.skia_layer_cache_identity_key(
        spec,
        physical_size,
      )
      let admission = self.layer_cache_admission_record(identity_key)
      admission.hit_count = admission.hit_count + 1
      stats.cache_hit_count = stats.cache_hit_count + 1
      self.draw_cached_layer_image(
        canvas,
        entry.image,
        spec.frame,
        entry.physical_size,
      )
      true
    }
    None => {
      stats.record_missing(spec.key)
      false
    }
  }
}

///|
fn SkiaRasterRenderer::draw_cached_layer_image(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  image : @skia_native.Image,
  frame : @core.Rect,
  physical_size : @moui_skia.ISize,
) -> Unit {
  let _ = self
  canvas.draw_image_rect(
    image,
    @moui_skia.Rect::from_xywh(
      0.0,
      0.0,
      Float::from_int(physical_size.width),
      Float::from_int(physical_size.height),
    ),
    skia_rect(frame),
    @moui_skia.Paint::new(anti_alias=true),
  )
}

///|
fn SkiaRasterRenderer::create_layer_surface(
  self : SkiaRasterRenderer,
  physical_size : @moui_skia.ISize,
) -> @skia_native.Surface? {
  let target = skia_surface_target_for_physical_size(
    physical_size,
    self.surface_route,
    self.gpu_context,
  )
  match self.surface_route {
    RasterSurfaceRoute => @skia_native.Surface::for_target(target)
    MetalGpuSurfaceRoute =>
      match self.gpu_context {
        Some(gpu_context) =>
          @skia_native.Surface::for_target_with_gpu_context(target, gpu_context)
        None => None
      }
  }
}

///|
fn SkiaRasterRenderer::skia_layer_cache_key(
  self : SkiaRasterRenderer,
  spec : @core.CachedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> String {
  "\{spec.key}|route=\{self.surface_route.label()}|scale=\{self.metrics.scale_factor}|pw=\{physical_size.width}|ph=\{physical_size.height}|rev=\{spec.content_revision}"
}

///|
fn SkiaRasterRenderer::skia_layer_cache_identity_key(
  self : SkiaRasterRenderer,
  spec : @core.CachedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> String {
  "\{spec.key}|route=\{self.surface_route.label()}|scale=\{self.metrics.scale_factor}|pw=\{physical_size.width}|ph=\{physical_size.height}"
}

///|
fn SkiaRasterRenderer::layer_cache_admission_record(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> SkiaCachedLayerAdmissionRecord {
  for record in self.layer_cache_admissions {
    if record.identity_key == identity_key {
      return record
    }
  }
  let record = SkiaCachedLayerAdmissionRecord::{
    identity_key,
    update_streak: 0,
    hit_count: 0,
    skip_reason: "",
    last_admitted_frame: 0,
    last_revision: -1,
  }
  self.layer_cache_admissions.push(record)
  record
}

///|
fn SkiaCachedLayerAdmissionRecord::record_update(
  self : SkiaCachedLayerAdmissionRecord,
  revision : Int,
) -> Unit {
  if self.last_revision != revision {
    self.update_streak = self.update_streak + 1
    self.last_revision = revision
  }
}

///|
fn SkiaRasterRenderer::cached_layer_admission_skip_reason(
  self : SkiaRasterRenderer,
  admission : SkiaCachedLayerAdmissionRecord,
  byte_size : Int64,
  budget : Int64,
) -> String? {
  let _ = self
  if budget > 0L && byte_size * 10L > budget * 4L {
    Some("large-layer")
  } else if admission.update_streak > 2 && admission.hit_count == 0 {
    Some("churn-without-hit")
  } else {
    None
  }
}

///|
fn SkiaRasterRenderer::lookup_cached_layer(
  self : SkiaRasterRenderer,
  key : String,
) -> SkiaCachedLayerImageEntry? {
  for entry in self.layer_cache {
    if entry.key == key {
      return Some(entry)
    }
  }
  None
}

///|
fn SkiaRasterRenderer::store_cached_layer(
  self : SkiaRasterRenderer,
  entry : SkiaCachedLayerImageEntry,
  admission : SkiaCachedLayerAdmissionRecord,
) -> Bool {
  if entry.byte_size > self.layer_cache_budget_bytes() {
    return false
  }
  self.remove_stale_cached_layers_for_entry(entry)
  let admitted_frame = self.next_layer_cache_tick()
  admission.last_admitted_frame = admitted_frame
  for index in 0..<self.layer_cache.length() {
    if self.layer_cache[index].key == entry.key {
      self.layer_cache[index] = {
        ..entry,
        hit_count: admission.hit_count,
        skip_reason: admission.skip_reason,
        last_admitted_frame: admitted_frame,
        last_used: admitted_frame,
      }
      return true
    }
  }
  self.layer_cache.push({
    ..entry,
    hit_count: admission.hit_count,
    skip_reason: admission.skip_reason,
    last_admitted_frame: admitted_frame,
    last_used: admitted_frame,
  })
  true
}

///|
fn SkiaRasterRenderer::remove_stale_cached_layers_for_entry(
  self : SkiaRasterRenderer,
  entry : SkiaCachedLayerImageEntry,
) -> Unit {
  let mut index = 0
  while index < self.layer_cache.length() {
    let current = self.layer_cache[index]
    if current.identity_key == entry.identity_key && current.key != entry.key {
      ignore(self.layer_cache.remove(index))
    } else {
      index = index + 1
    }
  }
}

///|
fn SkiaRasterRenderer::remove_cached_layers_by_identity(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> Unit {
  let mut index = 0
  while index < self.layer_cache.length() {
    if self.layer_cache[index].identity_key == identity_key {
      ignore(self.layer_cache.remove(index))
    } else {
      index = index + 1
    }
  }
}

///|
fn SkiaRasterRenderer::evict_cached_layers_if_needed(
  self : SkiaRasterRenderer,
) -> Int {
  let budget = self.layer_cache_budget_bytes()
  let mut bytes = self.layer_cache_byte_size()
  let mut evicted = 0
  while budget > 0L && bytes > budget && self.layer_cache.length() > 0 {
    let index = self.cached_layer_eviction_index(budget)
    let entry = self.layer_cache[index]
    bytes -= entry.byte_size
    ignore(self.layer_cache.remove(index))
    evicted = evicted + 1
  }
  evicted
}

///|
fn SkiaRasterRenderer::cached_layer_eviction_index(
  self : SkiaRasterRenderer,
  budget : Int64,
) -> Int {
  let mut candidate = -1
  let mut candidate_bytes = 0L
  let mut candidate_last_used = 0
  for index in 0..<self.layer_cache.length() {
    let entry = self.layer_cache[index]
    let large_cold = entry.hit_count == 0 &&
      entry.byte_size * 10L >= budget * 2L
    let churny_cold = entry.hit_count == 0 &&
      entry.update_streak > 1 &&
      entry.skip_reason == ""
    let entry_last_used = if entry.last_admitted_frame > 0 {
      entry.last_admitted_frame
    } else {
      entry.last_used
    }
    if large_cold || churny_cold {
      if candidate < 0 ||
        entry.byte_size > candidate_bytes ||
        (entry.byte_size == candidate_bytes &&
        entry_last_used < candidate_last_used) {
        candidate = index
        candidate_bytes = entry.byte_size
        candidate_last_used = entry_last_used
      }
    }
  }
  if candidate >= 0 {
    candidate
  } else {
    self.oldest_cached_layer_index()
  }
}

///|
fn SkiaRasterRenderer::oldest_cached_layer_index(
  self : SkiaRasterRenderer,
) -> Int {
  let mut oldest_index = 0
  let mut oldest_tick = self.layer_cache[0].last_used
  for index in 1..<self.layer_cache.length() {
    if self.layer_cache[index].last_used < oldest_tick {
      oldest_index = index
      oldest_tick = self.layer_cache[index].last_used
    }
  }
  oldest_index
}

///|
fn SkiaRasterRenderer::layer_cache_byte_size(
  self : SkiaRasterRenderer,
) -> Int64 {
  let mut bytes = 0L
  for entry in self.layer_cache {
    bytes += entry.byte_size
  }
  bytes
}

///|
fn SkiaRasterRenderer::layer_cache_budget_bytes(
  self : SkiaRasterRenderer,
) -> Int64 {
  let surface = skia_dim_to_int(self.metrics.physical_size.width).to_int64() *
    skia_dim_to_int(self.metrics.physical_size.height).to_int64() *
    4L *
    3L
  let cap = 64L * 1024L * 1024L
  if surface < cap {
    surface
  } else {
    cap
  }
}

///|
fn SkiaRasterRenderer::next_layer_cache_tick(self : SkiaRasterRenderer) -> Int {
  self.layer_cache_tick = self.layer_cache_tick + 1
  self.layer_cache_tick
}

///|
fn SkiaRasterRenderer::clear_layer_cache(self : SkiaRasterRenderer) -> Unit {
  self.layer_cache.clear()
  self.layer_cache_admissions.clear()
  self.layer_cache_tick = 0
}

///|
fn skia_cached_layer_physical_size(
  frame : @core.Rect,
  scale_factor : Double,
) -> @moui_skia.ISize {
  @moui_skia.ISize::new(
    skia_dim_to_int(frame.size.width * scale_factor),
    skia_dim_to_int(frame.size.height * scale_factor),
  )
}

///|
fn skia_cached_layer_byte_size(size : @moui_skia.ISize) -> Int64 {
  size.width.to_int64() * size.height.to_int64() * 4L
}

///|
fn SkiaRasterRenderer::render_command(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  command : @core.DrawCommand,
  canvas_scopes : Array[SkiaCanvasScopeKind],
) -> Unit {
  match command {
    @core.DrawCommand::Clear(color) => canvas.clear(skia_color(color))
    @core.DrawCommand::FillRect(rect, color) =>
      canvas.draw_rect(skia_rect(rect), skia_paint(color))
    @core.DrawCommand::StrokeRect(rect, color, width) =>
      canvas.draw_rect(skia_rect(rect), skia_stroke_paint(color, width))
    @core.DrawCommand::FillRoundedRect(rounded, color) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_paint(color),
      )
    @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_stroke_paint(color, width),
      )
    @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
      self.draw_brush_rounded_rect(canvas, rounded, brush, stroke_width=None)
    @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.draw_brush_rounded_rect(
        canvas,
        rounded,
        brush,
        stroke_width=Some(width),
      )
    @core.DrawCommand::DrawShadow(shadow) => self.draw_shadow(canvas, shadow)
    @core.DrawCommand::DrawText(run) => self.draw_text(canvas, run)
    @core.DrawCommand::DrawImage(run) => self.draw_image(canvas, run)
    @core.DrawCommand::PushClip(rect) => {
      ignore(canvas.save())
      canvas_scopes.push(SkiaCanvasScopeKind::Clip)
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @core.DrawCommand::PopClip =>
      self.pop_canvas_scope(canvas, canvas_scopes, SkiaCanvasScopeKind::Clip)
    @core.DrawCommand::PushRoundedClip(rounded) => {
      ignore(canvas.save())
      canvas_scopes.push(SkiaCanvasScopeKind::RoundedClip)
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
    @core.DrawCommand::PopRoundedClip =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        SkiaCanvasScopeKind::RoundedClip,
      )
    @core.DrawCommand::PushTransform(transform) => {
      ignore(canvas.save())
      canvas_scopes.push(SkiaCanvasScopeKind::Transform)
      canvas.concat(skia_matrix(transform))
    }
    @core.DrawCommand::PopTransform =>
      self.pop_canvas_scope(
        canvas,
        canvas_scopes,
        SkiaCanvasScopeKind::Transform,
      )
    @core.DrawCommand::PushOpacity(opacity) => {
      ignore(canvas.save_layer(paint=skia_opacity_paint(opacity)))
      canvas_scopes.push(SkiaCanvasScopeKind::Opacity)
    }
    @core.DrawCommand::PopOpacity =>
      self.pop_canvas_scope(canvas, canvas_scopes, SkiaCanvasScopeKind::Opacity)
    @core.DrawCommand::PushLayer(layer) => {
      self.push_layer(canvas, layer)
      canvas_scopes.push(SkiaCanvasScopeKind::Layer)
    }
    @core.DrawCommand::PopLayer =>
      self.pop_canvas_scope(canvas, canvas_scopes, SkiaCanvasScopeKind::Layer)
    @core.DrawCommand::BeginCachedLayer(spec) => {
      self.push_layer(
        canvas,
        @core.LayerSpec::new(
          mask=@core.LayerMask::RectMask(spec.frame),
          offscreen=true,
        ),
      )
      canvas_scopes.push(SkiaCanvasScopeKind::Layer)
    }
    @core.DrawCommand::EndCachedLayer(_) =>
      self.pop_canvas_scope(canvas, canvas_scopes, SkiaCanvasScopeKind::Layer)
    @core.DrawCommand::DrawCachedLayer(spec) =>
      self.record_unsupported_command(
        "DrawCachedLayer",
        "renderer-local cached layer was requested without a host-expanded cache entry: \{spec.key}",
      )
    @core.DrawCommand::PushFilter(filter) => {
      self.push_filter(canvas, filter)
      canvas_scopes.push(SkiaCanvasScopeKind::Filter)
    }
    @core.DrawCommand::PopFilter =>
      self.pop_canvas_scope(canvas, canvas_scopes, SkiaCanvasScopeKind::Filter)
    @core.DrawCommand::DrawPath(path) => self.draw_path(canvas, path)
    @core.DrawCommand::DrawShaderEffect(spec) =>
      self.draw_shader_effect(canvas, spec)
  }
}

///|
fn SkiaRasterRenderer::pop_canvas_scope(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  canvas_scopes : Array[SkiaCanvasScopeKind],
  expected : SkiaCanvasScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        canvas.restore()
      } else {
        canvas_scopes.push(actual)
        self.record_unsupported_command(
          skia_scope_pop_command(expected),
          "pop did not match active \{skia_scope_name(actual)} scope",
        )
      }
    None =>
      self.record_unsupported_command(
        skia_scope_pop_command(expected),
        "pop has no matching push scope",
      )
  }
}

///|
fn SkiaRasterRenderer::push_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  filter : @core.FilterEffect,
) -> Unit {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      match
        @skia_native.ImageFilter::blur(
          Float::from_double(radius.max(0.0)),
          Float::from_double(radius.max(0.0)),
        ) {
        Some(image_filter) =>
          ignore(canvas.save_layer(image_filter=Some(image_filter)))
        None => {
          ignore(canvas.save_layer())
          self.record_unsupported_command(
            "PushFilter", "Skia blur image filter unavailable; used unfiltered layer",
          )
        }
      }
    @core.FilterEffect::Saturate(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::saturation(Float::from_double(amount)),
      )
    @core.FilterEffect::Brightness(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::brightness(Float::from_double(amount)),
      )
    @core.FilterEffect::Contrast(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::contrast(Float::from_double(amount)),
      )
    @core.FilterEffect::ColorMatrix(values) =>
      self.push_color_filter(canvas, skia_color_filter_matrix(values))
  }
}

///|
fn SkiaRasterRenderer::push_color_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  color_filter : @skia_native.ColorFilter?,
) -> Unit {
  match color_filter {
    Some(color_filter) =>
      ignore(canvas.save_layer(color_filter=Some(color_filter)))
    None => {
      ignore(canvas.save_layer())
      self.record_unsupported_command(
        "PushFilter", "Skia color filter unavailable; used unfiltered layer",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shadow(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  shadow : @core.ShadowSpec,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  let expanded = skia_shadow_rect(shadow, grow=spread)
  let radius = (shadow.rect.radius + spread).max(0.0)
  if blur > 0.0 {
    match @skia_native.MaskFilter::blur(Float::from_double(blur)) {
      Some(mask_filter) => {
        let saved = canvas.save_layer(
          bounds=Some(
            skia_rect(skia_shadow_rect(shadow, grow=spread + blur * 3.0)),
          ),
          mask_filter=Some(mask_filter),
        )
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        canvas.restore_to_count(saved)
      }
      None => {
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        self.record_unsupported_command(
          "DrawShadow", "Skia mask filter unavailable; drew unblurred shadow",
        )
      }
    }
    return ()
  }
  canvas.draw_round_rect(
    skia_rect(expanded),
    Float::from_double(radius),
    Float::from_double(radius),
    skia_paint(shadow.color),
  )
}

///|
fn skia_shadow_rect(shadow : @core.ShadowSpec, grow~ : Double) -> @core.Rect {
  let rect = shadow.rect.rect
  @core.Rect::new(
    x=rect.origin.x + shadow.offset.x - grow,
    y=rect.origin.y + shadow.offset.y - grow,
    width=rect.size.width + grow * 2.0,
    height=rect.size.height + grow * 2.0,
  )
}

///|
fn SkiaRasterRenderer::draw_brush_rounded_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  stroke_width~ : Double?,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_stroke_paint(color, width),
          )
        None =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(color),
          )
      }
    _ =>
      match skia_brush_shader(brush) {
        Some(shader) =>
          match stroke_width {
            Some(width) =>
              canvas.draw_round_rect_shader(
                skia_rect(rounded.rect),
                Float::from_double(rounded.radius),
                Float::from_double(rounded.radius),
                shader,
                skia_stroke_paint(brush.fallback_color(), width),
              )
            None => {
              ignore(canvas.save())
              canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
              canvas.draw_rect_shader(
                skia_rect(rounded.rect),
                shader,
                @moui_skia.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
          }
        None => {
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(brush.fallback_color()),
          )
          self.record_unsupported_command(
            "FillRoundedRectBrush", "Skia brush shader unavailable; used fallback color",
          )
        }
      }
  }
}

///|
fn SkiaRasterRenderer::draw_image(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.ImageRun,
) -> Unit {
  match self.skia_image_for_source(run.source) {
    Some(image) => {
      let placement = skia_image_placement(
        run.frame,
        @core.Size::new(
          width=image.width().to_double(),
          height=image.height().to_double(),
        ),
        run.fit,
      )
      canvas.draw_image_rect(
        image,
        @moui_skia.Rect::from_xywh(
          Float::from_double(placement.u0 * image.width().to_double()),
          Float::from_double(placement.v0 * image.height().to_double()),
          Float::from_double(
            (placement.u1 - placement.u0) * image.width().to_double(),
          ),
          Float::from_double(
            (placement.v1 - placement.v0) * image.height().to_double(),
          ),
        ),
        skia_rect(placement.frame),
        skia_opacity_paint(run.opacity),
        sampling=@moui_skia.SamplingOptions::linear(),
      )
    }
    None => self.draw_image_placeholder(canvas, run)
  }
}

///|
fn SkiaRasterRenderer::draw_image_placeholder(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.ImageRun,
) -> Unit {
  self.draw_brush_rect(canvas, run.frame, skia_image_placeholder_brush(run))
}

///|
fn SkiaRasterRenderer::skia_image_for_source(
  self : SkiaRasterRenderer,
  source : String,
) -> @skia_native.Image? {
  match self.image_cache.get(source) {
    Some(image) => Some(image)
    None => {
      match self.failed_images.get(source) {
        Some(diagnostic) =>
          if skia_image_failed_cache_can_retry(source) {
            self.failed_images.remove(source)
          } else {
            self.mark_image_failed(source, diagnostic~)
            return None
          }
        None => ()
      }
      if self.async_image_loading {
        match self.image_lifecycle.lookup(source) {
          Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) =>
            return None
          Some({ status: @render.ImageResourceStatus::ImageReady, .. }) =>
            return self.decode_and_cache_image_source(
              source,
              mark_loading=false,
            )
          Some(
            { status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. }
          ) => {
            self.failed_images[source] = diagnostic
            return None
          }
          _ => {
            self.mark_image_loading(source)
            return None
          }
        }
      }
      self.decode_and_cache_image_source(source, mark_loading=true)
    }
  }
}

///|
fn SkiaRasterRenderer::decode_and_cache_image_source(
  self : SkiaRasterRenderer,
  source : String,
  mark_loading~ : Bool,
) -> @skia_native.Image? {
  match skia_image_source_bytes(source) {
    Some(bytes) => {
      if mark_loading {
        self.mark_image_loading(source)
      }
      match @skia_native.Image::from_encoded_bytes(bytes) {
        Some(image) => {
          self.failed_images.remove(source)
          self.image_cache[source] = image
          self.mark_image_ready(
            source,
            width=image.width(),
            height=image.height(),
          )
          Some(image)
        }
        None => {
          self.failed_images[source] = "Skia image decode failed"
          self.mark_image_failed(source, diagnostic="Skia image decode failed")
          None
        }
      }
    }
    None => {
      self.failed_images[source] = "Skia image source bytes are unavailable"
      self.mark_image_failed(
        source,
        diagnostic="Skia image source bytes are unavailable",
      )
      None
    }
  }
}

///|
fn SkiaRasterRenderer::mark_image_loading(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_loading(source))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::mark_image_ready(
  self : SkiaRasterRenderer,
  source : String,
  width~ : Int,
  height~ : Int,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_ready(source, width~, height~))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::mark_image_failed(
  self : SkiaRasterRenderer,
  source : String,
  diagnostic~ : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::dispose_image_resource(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.dispose(source))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::notify_image_resource_change_if_needed(
  self : SkiaRasterRenderer,
  previous_revision : Int,
) -> Unit {
  if self.image_lifecycle.revision() > previous_revision {
    match self.on_image_resource_change {
      Some(notify) => notify(self.image_lifecycle.snapshot_with_revision())
      None => ()
    }
  }
}

///|
fn skia_image_failed_cache_can_retry(source : String) -> Bool {
  !source.has_prefix("data:") && @fs.path_exists(source)
}

///|
pub fn skia_image_load_completion(
  source : String,
) -> @render.ImageResourceLoadCompletion {
  match skia_image_source_bytes(source) {
    Some(bytes) =>
      match @skia_native.Image::from_encoded_bytes(bytes) {
        Some(image) =>
          @render.ImageResourceLoadCompletion::ready(
            source,
            width=image.width(),
            height=image.height(),
          )
        None =>
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="Skia image decode failed",
          )
      }
    None =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="Skia image source bytes are unavailable",
      )
  }
}

///|
fn skia_image_source_bytes(source : String) -> Bytes? {
  if source.has_prefix("data:") {
    skia_image_data_uri_bytes(source)
  } else if @fs.path_exists(source) {
    Some(@fs.read_file_to_bytes(source)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
fn skia_image_data_uri_bytes(source : String) -> Bytes? {
  let parts = source.split(",").to_array()
  if parts.length() < 2 {
    return None
  }
  let meta = parts[0]
  if !meta.has_prefix("data:") || !meta.contains(";base64") {
    return None
  }
  Some(@base64.decode(parts[1], ignore_whitespace=true)) catch {
    _ => None
  }
}

///|
fn skia_image_placeholder_brush(run : @core.ImageRun) -> @core.Brush {
  @core.Brush::linear_gradient(
    start=run.frame.origin,
    end=@core.Point::new(
      x=run.frame.origin.x + run.frame.size.width,
      y=run.frame.origin.y + run.frame.size.height,
    ),
    start_color=@core.Color::rgba(r=0.72, g=0.78, b=0.86, a=run.opacity),
    end_color=@core.Color::rgba(r=0.42, g=0.50, b=0.62, a=run.opacity),
  )
}

///|
priv struct SkiaImagePlacement {
  frame : @core.Rect
  u0 : Double
  v0 : Double
  u1 : Double
  v1 : Double
}

///|
fn skia_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> SkiaImagePlacement {
  if image_size.width <= 0.0 ||
    image_size.height <= 0.0 ||
    frame.size.width <= 0.0 ||
    frame.size.height <= 0.0 {
    return { frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
  }
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame.size.width / frame.size.height
  match fit {
    @core.ImageFit::Stretch => { frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
    @core.ImageFit::ScaleDown =>
      if image_size.width <= frame.size.width &&
        image_size.height <= frame.size.height {
        {
          frame: @core.Rect::new(
            x=frame.origin.x + (frame.size.width - image_size.width) / 2.0,
            y=frame.origin.y + (frame.size.height - image_size.height) / 2.0,
            width=image_size.width,
            height=image_size.height,
          ),
          u0: 0.0,
          v0: 0.0,
          u1: 1.0,
          v1: 1.0,
        }
      } else {
        skia_contain_image_placement(frame, image_ratio, frame_ratio)
      }
    @core.ImageFit::FitWidth =>
      skia_fit_width_image_placement(frame, image_ratio)
    @core.ImageFit::FitHeight =>
      skia_fit_height_image_placement(frame, image_ratio)
    @core.ImageFit::Contain =>
      skia_contain_image_placement(frame, image_ratio, frame_ratio)
    @core.ImageFit::Cover =>
      if image_ratio > frame_ratio {
        let visible = frame_ratio / image_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
      } else {
        let visible = image_ratio / frame_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
      }
  }
}

///|
fn skia_fit_width_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> SkiaImagePlacement {
  let scaled_height = frame.size.width / image_ratio
  if scaled_height <= frame.size.height {
    {
      frame: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - scaled_height) / 2.0,
        width=frame.size.width,
        height=scaled_height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let visible = frame.size.height / scaled_height
    let inset = (1.0 - visible) / 2.0
    { frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
  }
}

///|
fn skia_fit_height_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> SkiaImagePlacement {
  let scaled_width = frame.size.height * image_ratio
  if scaled_width <= frame.size.width {
    {
      frame: @core.Rect::new(
        x=frame.origin.x + (frame.size.width - scaled_width) / 2.0,
        y=frame.origin.y,
        width=scaled_width,
        height=frame.size.height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let visible = frame.size.width / scaled_width
    let inset = (1.0 - visible) / 2.0
    { frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
  }
}

///|
fn skia_contain_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
  frame_ratio : Double,
) -> SkiaImagePlacement {
  if image_ratio > frame_ratio {
    let scaled_height = frame.size.width / image_ratio
    let offset_y = (frame.size.height - scaled_height) / 2.0
    {
      frame: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + offset_y,
        width=frame.size.width,
        height=scaled_height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let scaled_width = frame.size.height * image_ratio
    let offset_x = (frame.size.width - scaled_width) / 2.0
    {
      frame: @core.Rect::new(
        x=frame.origin.x + offset_x,
        y=frame.origin.y,
        width=scaled_width,
        height=frame.size.height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  }
}

///|
fn SkiaRasterRenderer::push_layer(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  layer : @core.LayerSpec,
) -> Unit {
  let paint = skia_opacity_paint(layer.opacity).set_blend_mode(
    skia_blend_mode(layer.blend_mode),
  )
  match layer.mask {
    @core.LayerMask::NoMask => ignore(canvas.save_layer(paint~))
    @core.LayerMask::RectMask(rect) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rect)), paint~))
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @core.LayerMask::RoundedMask(rounded) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rounded.rect)), paint~))
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
  }
  if layer.offscreen {
    ignore(layer.offscreen)
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_text(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.TextRun,
) -> Unit {
  if !skia_text_frame_can_draw(run.frame) {
    return ()
  }
  match
    skia_resolved_text_layout_for_resolution(
      run.font,
      run.text,
      self.font_resolution,
    ) {
    Some(layout) => {
      let placement = if layout.segments.length() == 1 {
        skia_text_placement(run, layout.segments[0].glyph_run, layout.metrics)
      } else {
        skia_text_placement_for_width(run, layout.width, layout.metrics)
      }
      let saved = canvas.save()
      canvas.clip_rect(skia_rect(placement.clip), anti_alias=true)
      for segment in layout.segments {
        canvas.draw_glyphs(
          segment.glyph_run.glyphs,
          segment.glyph_run.positions,
          segment.font,
          skia_paint(run.color),
          origin=@moui_skia.Point::new(
            Float::from_double(
              placement.origin.x.to_double() + segment.x_offset,
            ),
            placement.origin.y,
          ),
        )
      }
      canvas.restore_to_count(saved)
    }
    None =>
      self.record_unsupported_command(
        "DrawText", "Skia text layout unavailable; skipped text run",
      )
  }
}

///|
fn skia_text_frame_can_draw(frame : @core.Rect) -> Bool {
  frame.size.width > 0.0 && frame.size.height > 0.0
}

///|
fn skia_text_placement(
  run : @core.TextRun,
  glyph_run : SkiaGlyphRun,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  skia_text_placement_for_width(run, glyph_run.width, metrics)
}

///|
fn skia_text_placement_for_width(
  run : @core.TextRun,
  text_width : Double,
  metrics : SkiaTextMetrics,
) -> SkiaTextPlacement {
  let x = match run.align {
    @core.TextAlign::TextStart => run.frame.origin.x
    @core.TextAlign::TextCenter =>
      run.frame.origin.x + (run.frame.size.width - text_width) / 2.0
    @core.TextAlign::TextEnd =>
      run.frame.origin.x + run.frame.size.width - text_width
  }
  let y = skia_text_baseline_y(run.frame, metrics)
  {
    origin: @moui_skia.Point::new(Float::from_double(x), Float::from_double(y)),
    clip: run.frame,
  }
}

///|
fn skia_text_baseline_y(
  frame : @core.Rect,
  metrics : SkiaTextMetrics,
) -> Double {
  let offset_y = if frame.size.height > metrics.height {
    (frame.size.height - metrics.height) / 2.0
  } else {
    0.0
  }
  frame.origin.y + offset_y + metrics.baseline
}

///|
fn skia_draw_text_payload_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  match skia_font_with_resolution_for_text(font_spec, text, resolution) {
    Some(font) => {
      let glyph_run = skia_glyph_run_for_resolution(font, text, resolution)
      if skia_glyph_run_can_draw_text(glyph_run) {
        Some((font, glyph_run))
      } else {
        skia_fallback_draw_payload(font_spec, text, resolution, glyph_run)
      }
    }
    None => None
  }
}

///|
fn skia_resolved_text_layout_for_resolution(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  if text == "" {
    match skia_draw_text_payload_for_resolution(font_spec, text, resolution) {
      Some((font, glyph_run)) =>
        Some({
          segments: [{ text, font, glyph_run, x_offset: 0.0 }],
          width: glyph_run.width,
          metrics: skia_text_metrics(
            font,
            fallback_baseline=font_spec.size,
            fallback_height=font_spec.size * 1.25,
          ),
        })
      None => None
    }
  } else {
    skia_resolved_text_segments(font_spec, text, resolution)
  }
}

///|
fn skia_resolved_text_segments(
  font_spec : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaResolvedTextLayout? {
  let text_segments = skia_mixed_text_segments(text)
  if text_segments.is_empty() {
    return None
  }
  let segments : Array[SkiaTextRunSegment] = []
  let mut x_offset = 0.0
  let mut baseline = 0.0
  let mut height = 0.0
  for segment_text in text_segments {
    match
      skia_draw_text_payload_for_resolution(font_spec, segment_text, resolution) {
      Some((font, glyph_run)) => {
        let metrics = skia_text_metrics(
          font,
          fallback_baseline=font_spec.size,
          fallback_height=font_spec.size * 1.25,
        )
        baseline = baseline.max(metrics.baseline)
        height = height.max(metrics.height)
        segments.push({ text: segment_text, font, glyph_run, x_offset })
        x_offset = x_offset + glyph_run.width
      }
      None => return None
    }
  }
  if segments.is_empty() {
    None
  } else {
    Some({
      segments,
      width: x_offset,
      metrics: { baseline, height: height.max(baseline) },
    })
  }
}

///|
fn skia_mixed_text_segments(text : String) -> Array[String] {
  let clusters = skia_bidi_visual_cluster_texts(
    skia_grapheme_cluster_texts(text),
  )
  skia_mixed_text_segments_from_clusters(clusters)
}

///|
fn skia_mixed_text_segments_from_clusters(
  clusters : Array[String],
) -> Array[String] {
  let segments : Array[String] = []
  let current : Array[Char] = []
  let mut current_class = -1
  for cluster in clusters {
    let cluster_class = skia_text_segment_class(cluster)
    if !current.is_empty() && cluster_class != current_class {
      segments.push(String::from_array(current))
      current.clear()
    }
    for ch in cluster {
      current.push(ch)
    }
    current_class = cluster_class
  }
  if !current.is_empty() {
    segments.push(String::from_array(current))
  }
  segments
}

///|
fn skia_bidi_visual_cluster_texts(clusters : Array[String]) -> Array[String] {
  let visual : Array[String] = []
  let mut index = 0
  while index < clusters.length() {
    let rtl = skia_cluster_is_rtl(clusters[index])
    let start = index
    index = index + 1
    while index < clusters.length() &&
          skia_cluster_is_rtl(clusters[index]) == rtl {
      index = index + 1
    }
    if rtl {
      let mut cursor = index
      while cursor > start {
        cursor = cursor - 1
        visual.push(clusters[cursor])
      }
    } else {
      for cursor in start..<index {
        visual.push(clusters[cursor])
      }
    }
  }
  visual
}

///|
fn skia_cluster_is_rtl(cluster : String) -> Bool {
  skia_text_segment_class(cluster) == 4
}

///|
fn skia_join_clusters(clusters : Array[String]) -> String {
  let chars : Array[Char] = []
  for cluster in clusters {
    for ch in cluster {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}

///|
fn skia_string_arrays_equal(
  left : Array[String],
  right : Array[String],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn skia_grapheme_cluster_texts(text : String) -> Array[String] {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let clusters : Array[String] = []
  if boundaries.length() < 2 {
    return clusters
  }
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start {
      clusters.push(String::from_array(chars[start:end]))
    }
  }
  clusters
}

///|
fn skia_text_segment_class(text : String) -> Int {
  let representative = skia_representative_fallback_codepoint(text)
  if skia_codepoint_is_emoji_hint(representative) {
    1
  } else if skia_codepoint_is_cjk(representative) {
    2
  } else if skia_codepoint_is_hangul_cluster_codepoint(representative) {
    3
  } else if skia_codepoint_is_rtl_script(representative) {
    4
  } else if representative < 0x0300 {
    0
  } else {
    5
  }
}

///|
fn skia_codepoint_is_cjk(codepoint : Int) -> Bool {
  skia_codepoint_is_cjk_ideograph(codepoint) || skia_codepoint_is_kana(codepoint)
}

///|
fn skia_codepoint_is_cjk_ideograph(codepoint : Int) -> Bool {
  (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
  (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) ||
  (codepoint >= 0x20000 && codepoint <= 0x2FA1F)
}

///|
fn skia_codepoint_is_kana(codepoint : Int) -> Bool {
  (codepoint >= 0x3040 && codepoint <= 0x30FF)
}

///|
fn skia_codepoint_is_rtl_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0590 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB1D && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}

///|
fn SkiaRasterRenderer::draw_path(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.PathSpec,
) -> Unit {
  match skia_path(spec) {
    Some(path) => {
      match spec.fill {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_paint(color))
        Some(brush) =>
          self.draw_path_brush(canvas, path, brush, stroke_width=None)
        None => ()
      }
      match spec.stroke {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_stroke_paint(color, spec.stroke_width))
        Some(brush) =>
          self.draw_path_brush(
            canvas,
            path,
            brush,
            stroke_width=Some(spec.stroke_width),
          )
        None => ()
      }
    }
    None =>
      self.record_unsupported_command(
        "DrawPath", "Skia path conversion unavailable; skipped path",
      )
  }
}

///|
fn SkiaRasterRenderer::draw_path_brush(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  path : @skia_native.Path,
  brush : @core.Brush,
  stroke_width~ : Double?,
) -> Unit {
  match skia_brush_shader(brush) {
    Some(shader) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_path_shader(
            path,
            shader,
            skia_stroke_paint(brush.fallback_color(), width),
          )
        None =>
          match path.bounds() {
            Some(bounds) => {
              ignore(canvas.save())
              canvas.clip_path(path, anti_alias=true)
              canvas.draw_rect_shader(
                bounds,
                shader,
                @moui_skia.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
            None => ()
          }
      }
    None => {
      let paint = match stroke_width {
        Some(width) => skia_stroke_paint(brush.fallback_color(), width)
        None => skia_paint(brush.fallback_color())
      }
      canvas.draw_path(path, paint)
      self.record_unsupported_command(
        "DrawPath", "Skia brush shader unavailable; used fallback color",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shader_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  match spec.name {
    "solid" => self.draw_brush_rect(canvas, spec.frame, spec.fallback)
    "checker" => self.draw_checker_effect(canvas, spec)
    "linear-gradient-debug" => self.draw_linear_gradient_debug(canvas, spec)
    "vignette" => self.draw_vignette_effect(canvas, spec)
    _ => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.record_unsupported_command(
        "DrawShaderEffect",
        "unknown shader effect '\{spec.name}' used fallback brush",
      )
    }
  }
}

///|
fn SkiaRasterRenderer::draw_brush_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  frame : @core.Rect,
  brush : @core.Brush,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      canvas.draw_rect(skia_rect(frame), skia_paint(color))
    _ =>
      match skia_brush_shader(brush) {
        Some(shader) =>
          canvas.draw_rect_shader(
            skia_rect(frame),
            shader,
            @moui_skia.Paint::new(anti_alias=true),
          )
        None => {
          canvas.draw_rect(skia_rect(frame), skia_paint(brush.fallback_color()))
          self.record_unsupported_command(
            "FillRectBrush", "Skia brush shader unavailable; used fallback color",
          )
        }
      }
  }
}

///|
fn skia_brush_shader(brush : @core.Brush) -> @skia_native.Shader? {
  match brush {
    @core.Brush::Solid(_) => None
    @core.Brush::LinearGradient(gradient) =>
      @skia_native.Shader::linear_gradient(
        skia_point(gradient.start),
        skia_point(gradient.end),
        skia_color(gradient.start_color),
        skia_color(gradient.end_color),
      )
    @core.Brush::RadialGradient(gradient) =>
      @skia_native.Shader::radial_gradient(
        skia_point(gradient.center),
        Float::from_double(gradient.radius),
        skia_color(gradient.center_color),
        skia_color(gradient.edge_color),
      )
  }
}

///|
fn SkiaRasterRenderer::draw_checker_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let amount = match spec.uniforms.get(0) {
    Some(value) => value.max(1.0)
    None => 8.0
  }
  let (color_a, color_b) = skia_shader_effect_colors(spec.fallback)
  let cell = (spec.frame.size.width.min(spec.frame.size.height) / amount).max(
    1.0,
  )
  let columns = (spec.frame.size.width / cell).ceil().to_int().max(1)
  let rows = (spec.frame.size.height / cell).ceil().to_int().max(1)
  for row in 0..<rows {
    for column in 0..<columns {
      let color = if (row + column) % 2 == 0 { color_a } else { color_b }
      let x = spec.frame.origin.x + column.to_double() * cell
      let y = spec.frame.origin.y + row.to_double() * cell
      canvas.draw_rect(
        skia_rect(
          @core.Rect::new(
            x~,
            y~,
            width=cell.min(spec.frame.origin.x + spec.frame.size.width - x),
            height=cell.min(spec.frame.origin.y + spec.frame.size.height - y),
          ),
        ),
        skia_paint(color),
      )
    }
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_linear_gradient_debug(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (start_color, end_color) = skia_shader_effect_colors(spec.fallback)
  let gradient = @core.LinearGradientSpec::new(
    start=spec.frame.origin,
    end=@core.Point::new(
      x=spec.frame.origin.x + spec.frame.size.width,
      y=spec.frame.origin.y,
    ),
    start_color~,
    end_color~,
  )
  self.draw_brush_rect(
    canvas,
    spec.frame,
    @core.Brush::LinearGradient(gradient),
  )
}

///|
fn SkiaRasterRenderer::draw_vignette_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (color, _) = skia_shader_effect_colors(spec.fallback)
  let center = @core.Point::new(
    x=spec.frame.origin.x + spec.frame.size.width / 2.0,
    y=spec.frame.origin.y + spec.frame.size.height / 2.0,
  )
  let radius = spec.frame.size.width.max(spec.frame.size.height) /
    2.0 *
    skia_vignette_radius_scale(spec)
  let outer_color = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=color.a)
  match
    @skia_native.Shader::radial_gradient(
      skia_point(center),
      Float::from_double(radius),
      skia_color(color),
      skia_color(outer_color),
    ) {
    Some(shader) =>
      canvas.draw_rect_shader(
        skia_rect(spec.frame),
        shader,
        @moui_skia.Paint::new(anti_alias=true),
      )
    None => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.record_unsupported_command(
        "DrawShaderEffect", "Skia radial shader unavailable for vignette; used fallback brush",
      )
    }
  }
}

///|
fn skia_vignette_radius_scale(spec : @core.ShaderEffectSpec) -> Double {
  match spec.uniforms.get(0) {
    Some(amount) => amount.max(0.8)
    None => 0.8
  }
}

///|
fn SkiaRasterRenderer::read_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame raise SkiaRendererError {
  match self.surface.read_pixels() {
    Some(pixmap) =>
      {
        width: pixmap.width(),
        height: pixmap.height(),
        row_bytes: pixmap.row_bytes(),
        scale_factor: self.metrics.scale_factor,
        pixels: pixmap.pixels,
      }
    None => raise SkiaRendererError::ReadPixelsUnavailable
  }
}

///|
pub fn SkiaRasterRenderer::text_system(
  self : SkiaRasterRenderer,
) -> @core.TextSystem {
  skia_text_system(resolution=self.font_resolution)
}

///|
pub fn SkiaRasterRenderer::image_resources(
  self : SkiaRasterRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.image_lifecycle.snapshot()
}

///|
pub fn SkiaRasterRenderer::image_resource_snapshot(
  self : SkiaRasterRenderer,
) -> @render.ImageResourceSnapshot {
  self.image_lifecycle.snapshot_with_revision()
}

///|
pub fn SkiaRasterRenderer::apply_image_resource_load_completion(
  self : SkiaRasterRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  let previous_revision = self.image_lifecycle.revision()
  let snapshot = self.image_lifecycle.apply_load_completion(completion)
  if snapshot.revision > previous_revision {
    match completion.status {
      @render.ImageResourceLoadCompletionStatus::ImageLoadReady =>
        self.failed_images.remove(completion.source)
      @render.ImageResourceLoadCompletionStatus::ImageLoadFailed =>
        self.failed_images[completion.source] = completion.diagnostic
    }
    self.notify_image_resource_change_if_needed(previous_revision)
  }
  snapshot
}

///|
pub fn SkiaRasterRenderer::dispose(self : SkiaRasterRenderer) -> Unit {
  for source, _ in self.image_cache {
    self.dispose_image_resource(source)
  }
  self.image_cache.clear()
  self.failed_images.clear()
  self.clear_layer_cache()
}

///|
pub fn SkiaRasterRenderer::set_image_resource_change_callback(
  self : SkiaRasterRenderer,
  callback : ((@render.ImageResourceSnapshot) -> Unit)?,
) -> Unit {
  self.on_image_resource_change = callback
}

///|
pub fn SkiaRasterRenderer::backend_kind(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  @render.RendererBackendKind::SkiaRasterNative
}

///|
pub fn SkiaRasterRenderer::backend_info(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn SkiaRasterRenderer::present_count(self : SkiaRasterRenderer) -> Int {
  self.present_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_count(
  self : SkiaRasterRenderer,
) -> Int {
  self.unsupported_command_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_diagnostics(
  self : SkiaRasterRenderer,
) -> Array[SkiaUnsupportedCommandDiagnostic] {
  self.unsupported_command_diagnostics.copy()
}

///|
pub fn SkiaRasterRenderer::last_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame? {
  self.last_frame
}

///|
pub fn skia_text_system(
  resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @core.TextSystem {
  match resolution {
    SkiaFontResolution::EmptyTypeface =>
      if skia_available() {
        skia_empty_typeface_text_system()
      } else {
        @core.TextSystem::fallback()
      }
    SkiaFontResolution::SystemFontMgr => skia_system_font_mgr_text_system()
  }
}

///|
fn skia_empty_typeface_text_system() -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-empty-typeface-text-system",
    measure=input => {
      skia_measure_text_for_resolution(input, SkiaFontResolution::EmptyTypeface)
    },
    paragraph_layout=Some(input => {
      skia_fallback_paragraph_layout_result(
        input,
        SkiaFontResolution::EmptyTypeface,
        "skia-raster-empty-typeface-text-system",
      )
    }),
  )
}

///|
fn skia_system_font_mgr_text_system() -> @core.TextSystem {
  @core.TextSystem::new(
    id="skia-raster-text-system",
    measure=input => {
      skia_measure_text_for_resolution(input, SkiaFontResolution::SystemFontMgr)
    },
    paragraph_layout=Some(input => {
      match skia_native_paragraph_layout_result(input) {
        Some(layout) => layout
        None =>
          skia_fallback_paragraph_layout_result(
            input,
            SkiaFontResolution::SystemFontMgr,
            "skia-raster-text-system",
          )
      }
    }),
  )
}

///|
fn skia_measure_text_for_resolution(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
) -> @core.TextLayoutResult {
  let fallback = @core.TextSystem::fallback().measure_text(input)
  match
    skia_resolved_text_layout_for_resolution(input.font, input.text, resolution) {
    Some(layout) => skia_resolved_text_layout_result(input, fallback, layout~)
    None => fallback
  }
}

///|
fn skia_fallback_paragraph_layout_result(
  input : @core.TextLayoutInput,
  resolution : SkiaFontResolution,
  id : String,
) -> @core.TextParagraphLayoutResult {
  @core.TextSystem::new(id~, measure=measure_input => {
    skia_measure_text_for_resolution(measure_input, resolution)
  }).layout_paragraph(input)
}

///|
fn skia_native_paragraph_layout_result(
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult? {
  if input.text == "" || !@skia_native.skia_paragraph_available() {
    return None
  }
  let max_width = input.max_width.unwrap_or(1000000000.0)
  let family_name = skia_primary_paragraph_family(input.font)
  let text_bytes = @utf8.encode(input.text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      text_bytes,
      family_name~,
      size=Float::from_double(input.font.size),
      weight=input.font.weight,
      width=5,
      slant=skia_font_slant(input.font.style),
      max_width=Float::from_double(max_width),
      left_to_right=true,
    ) {
    None => None
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(input.text)
      let lines = skia_paragraph_line_metrics(input.text, paragraph, offsets)
      if lines.is_empty() {
        return None
      }
      let caret_rects = skia_paragraph_caret_rects(
        input.text,
        paragraph,
        lines,
        offsets,
      )
      if caret_rects.length() != input.text.to_array().length() + 1 {
        return None
      }
      let all_text_boxes = paragraph.text_boxes_utf8(0, text_bytes.length())
      if all_text_boxes.is_empty() {
        return None
      }
      let probe = skia_paragraph_bidi_probe_ready(input.font)
      let visual_order = skia_paragraph_visual_order_metadata(
        input.text,
        paragraph,
        offsets,
        bidi_ready=probe,
      )
      let hit = paragraph.hit_test_utf8(
        0.0,
        Float::from_double(lines[0].baseline),
      )
      let hit_available = hit.offset >= 0 && hit.offset <= text_bytes.length()
      let selection_rects_available = all_text_boxes.length() > 0
      let line_metrics_available = !lines.is_empty()
      let native_ready = line_metrics_available &&
        selection_rects_available &&
        hit_available &&
        !caret_rects.is_empty()
      Some({
        text: input.text,
        size: @core.Size::new(
          width=paragraph.width().to_double().min(max_width),
          height=paragraph.height().to_double(),
        ),
        baseline: lines[0].baseline,
        lines,
        caret_rects,
        visual_order,
        metadata: {
          text_system_id: "skia-raster-text-system",
          paragraph_layout_available: true,
          line_metrics_available,
          selection_rects_available,
          hit_test_available: hit_available,
          native_paragraph_ready: native_ready,
          bidi_visual_order_ready: native_ready && probe,
        },
      })
    }
  }
}

///|
fn skia_primary_paragraph_family(font : @core.FontSpec) -> Bytes {
  let candidates = skia_preflight_family_candidates(font)
  if candidates.is_empty() {
    b""
  } else {
    @utf8.encode(candidates[0][:], bom=false)
  }
}

///|
fn skia_paragraph_line_metrics(
  text : String,
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
) -> Array[@core.TextParagraphLineMetrics] {
  let chars = text.to_array()
  let lines : Array[@core.TextParagraphLineMetrics] = []
  for metric in paragraph.line_metrics() {
    match
      (
        skia_char_index_for_utf8_offset(offsets, metric.start),
        skia_char_index_for_utf8_offset(offsets, metric.end),
      ) {
      (Some(start), Some(end)) => {
        let start = start.clamp(min=0, max=chars.length())
        let end = end.clamp(min=start, max=chars.length())
        let ascent = metric.ascent.to_double().abs()
        let descent = metric.descent.to_double().abs()
        let metric_height = metric.height
          .to_double()
          .max(ascent + descent)
          .max(1.0)
        let top = metric.baseline.to_double() - ascent
        lines.push({
          line_index: lines.length(),
          text_range: @core.TextRange::new(start~, end~),
          origin: @core.Point::new(x=metric.left.to_double(), y=top.max(0.0)),
          size: @core.Size::new(
            width=metric.width.to_double().max(0.0),
            height=metric_height,
          ),
          baseline: metric.baseline.to_double(),
        })
      }
      _ => ()
    }
  }
  lines
}

///|
fn skia_paragraph_caret_rects(
  text : String,
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
) -> Array[@core.Rect] {
  let chars = text.to_array()
  let carets : Array[@core.Rect] = []
  for index in 0..<(chars.length() + 1) {
    carets.push(skia_paragraph_caret_rect_at(paragraph, lines, offsets, index))
  }
  carets
}

///|
fn skia_paragraph_caret_rect_at(
  paragraph : @skia_native.Paragraph,
  lines : Array[@core.TextParagraphLineMetrics],
  offsets : Array[Int],
  index : Int,
) -> @core.Rect {
  let line = skia_paragraph_line_for_char_index(lines, index)
  let start_byte = offsets[index.clamp(min=0, max=offsets.length() - 1)]
  let end_byte = if index + 1 < offsets.length() {
    offsets[index + 1]
  } else {
    start_byte
  }
  let boxes = if end_byte > start_byte {
    paragraph.text_boxes_utf8(start_byte, end_byte)
  } else if start_byte > 0 {
    paragraph.text_boxes_utf8(offsets[(index - 1).max(0)], start_byte)
  } else {
    []
  }
  let x = if boxes.is_empty() {
    line.origin.x
  } else if end_byte > start_byte {
    boxes[0].left.to_double()
  } else {
    boxes[boxes.length() - 1].right.to_double()
  }
  @core.Rect::new(
    x~,
    y=line.origin.y,
    width=1.0,
    height=line.size.height.max(1.0),
  )
}

///|
fn skia_paragraph_line_for_char_index(
  lines : Array[@core.TextParagraphLineMetrics],
  index : Int,
) -> @core.TextParagraphLineMetrics {
  if lines.is_empty() {
    return {
      line_index: 0,
      text_range: @core.TextRange::collapsed(0),
      origin: @core.Point::new(x=0.0, y=0.0),
      size: @core.Size::new(width=0.0, height=1.0),
      baseline: 0.0,
    }
  }
  for line in lines {
    if index >= line.text_range.start && index <= line.text_range.end {
      return line
    }
  }
  lines[lines.length() - 1]
}

///|
fn skia_paragraph_visual_order_metadata(
  text : String,
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
  bidi_ready~ : Bool,
) -> @core.TextParagraphVisualOrderMetadata {
  let logical_clusters = skia_grapheme_cluster_texts(text)
  let boxes = skia_paragraph_cluster_boxes(logical_clusters, paragraph, offsets)
  let paragraph_bidi_evidence = skia_paragraph_has_bidi_evidence(boxes)
  let visual_clusters = if paragraph_bidi_evidence {
    skia_bidi_visual_cluster_texts(logical_clusters)
  } else {
    logical_clusters
  }
  let visual_order_differs = !skia_string_arrays_equal(
    logical_clusters, visual_clusters,
  )
  {
    logical_text: skia_join_clusters(logical_clusters),
    visual_text: skia_join_clusters(visual_clusters),
    logical_cluster_count: logical_clusters.length(),
    visual_cluster_count: visual_clusters.length(),
    segment_count: boxes.length().max(1),
    glyph_count: logical_clusters.length(),
    visual_order_differs,
    bidi_visual_order_ready: bidi_ready &&
      paragraph_bidi_evidence &&
      visual_order_differs,
  }
}

///|
fn skia_paragraph_cluster_boxes(
  clusters : Array[String],
  paragraph : @skia_native.Paragraph,
  offsets : Array[Int],
) -> Array[SkiaParagraphClusterBox] {
  let boxes : Array[SkiaParagraphClusterBox] = []
  let mut char_index = 0
  for cluster in clusters {
    let cluster_length = cluster.to_array().length()
    let end_index = (char_index + cluster_length).min(offsets.length() - 1)
    if end_index > char_index {
      let text_boxes = paragraph.text_boxes_utf8(
        offsets[char_index],
        offsets[end_index],
      )
      let has_rect = !text_boxes.is_empty()
      let native_rtl = if has_rect {
        let directions = paragraph.text_box_directions_utf8(
          offsets[char_index],
          offsets[end_index],
        )
        if directions.is_empty() {
          false
        } else {
          directions[0] == 0
        }
      } else {
        false
      }
      boxes.push({
        has_rect,
        rtl: native_rtl || skia_cluster_is_rtl(cluster),
      })
    }
    char_index = end_index
  }
  boxes
}

///|
fn skia_paragraph_has_bidi_evidence(
  boxes : Array[SkiaParagraphClusterBox],
) -> Bool {
  let mut rect_count = 0
  let mut rtl_count = 0
  for box in boxes {
    if box.has_rect {
      rect_count = rect_count + 1
    }
    if box.rtl {
      rtl_count = rtl_count + 1
    }
  }
  rect_count > 0 && rtl_count > 0
}

///|
fn skia_paragraph_bidi_probe_ready(font : @core.FontSpec) -> Bool {
  if !@skia_native.skia_paragraph_available() {
    return false
  }
  let text = "ABC \u{05D0}\u{05D1}\u{05D2} 123"
  let bytes = @utf8.encode(text[:], bom=false)
  match
    @skia_native.Paragraph::layout_utf8(
      bytes,
      family_name=skia_primary_paragraph_family(font),
      size=Float::from_double(font.size),
      weight=font.weight,
      width=5,
      slant=skia_font_slant(font.style),
      max_width=400.0,
      left_to_right=true,
    ) {
    Some(paragraph) => {
      let offsets = skia_utf8_char_offsets(text)
      let logical = skia_grapheme_cluster_texts(text)
      let visual = skia_paragraph_visual_order_metadata(
        text,
        paragraph,
        offsets,
        bidi_ready=true,
      )
      visual.visual_order_differs &&
      visual.bidi_visual_order_ready &&
      visual.logical_cluster_count == logical.length() &&
      visual.visual_cluster_count == logical.length()
    }
    None => false
  }
}

///|
fn skia_resolved_text_layout_result(
  input : @core.TextLayoutInput,
  fallback : @core.TextLayoutResult,
  layout~ : SkiaResolvedTextLayout,
) -> @core.TextLayoutResult {
  if layout.segments.is_empty() {
    return fallback
  }
  if layout.segments.length() == 1 && layout.segments[0].text == input.text {
    return skia_text_layout_result(
      layout.segments[0].font,
      input,
      fallback,
      glyph_run=layout.segments[0].glyph_run,
    )
  }
  let carets = skia_resolved_text_caret_positions(input.text, layout)
  let measured = skia_layout_width_from_carets(carets)
  match input.max_width {
    Some(max_width) => {
      let clamped : Array[Double] = []
      for caret in carets {
        clamped.push(caret.min(max_width))
      }
      {
        size: @core.Size::new(
          width=measured.min(max_width),
          height=layout.metrics.height,
        ),
        baseline: layout.metrics.baseline,
        caret_positions: clamped,
      }
    }
    None =>
      {
        size: @core.Size::new(width=measured, height=layout.metrics.height),
        baseline: layout.metrics.baseline,
        caret_positions: carets,
      }
  }
}

///|
fn skia_text_layout_result(
  font : @skia_native.Font,
  input : @core.TextLayoutInput,
  fallback : @core.TextLayoutResult,
  glyph_run~ : SkiaGlyphRun,
) -> @core.TextLayoutResult {
  if !skia_font_can_measure_text(font, input.text) {
    return fallback
  }
  let carets = skia_caret_positions(font, input.text, glyph_run~)
  let measured = skia_layout_width_from_carets(carets)
  let metrics = skia_text_metrics(
    font,
    fallback_baseline=fallback.baseline,
    fallback_height=fallback.size.height,
  )
  match input.max_width {
    Some(max_width) => {
      let clamped : Array[Double] = []
      for caret in carets {
        clamped.push(caret.min(max_width))
      }
      {
        size: @core.Size::new(
          width=measured.min(max_width),
          height=metrics.height,
        ),
        baseline: metrics.baseline,
        caret_positions: clamped,
      }
    }
    None =>
      {
        size: @core.Size::new(width=measured, height=metrics.height),
        baseline: metrics.baseline,
        caret_positions: carets,
      }
  }
}

///|
fn skia_resolved_text_caret_positions(
  text : String,
  layout : SkiaResolvedTextLayout,
) -> Array[Double] {
  let carets : Array[Double] = [0.0]
  for segment in layout.segments {
    let segment_carets = skia_caret_positions(
      segment.font,
      segment.text,
      glyph_run=segment.glyph_run,
    )
    if segment_carets.length() > 1 {
      for index in 1..<segment_carets.length() {
        carets.push(segment.x_offset + segment_carets[index])
      }
    }
  }
  if carets.length() != text.to_array().length() + 1 {
    return carets
  }
  skia_stabilize_grapheme_cluster_carets(text, carets)
}

///|
fn skia_font_can_measure_text(font : @skia_native.Font, text : String) -> Bool {
  text == "" || skia_measure_text_width(font, text) > 0.0
}

///|
fn skia_text_metrics(
  font : @skia_native.Font,
  fallback_baseline~ : Double,
  fallback_height~ : Double,
) -> SkiaTextMetrics {
  let metrics = font.metrics()
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let leading = metrics.leading.to_double()
  let measured_baseline = (0.0 - ascent).max(0.0)
  let measured_height = (descent - ascent + leading)
    .max(descent - ascent)
    .max(0.0)
  let baseline = if measured_baseline > 0.0 {
    measured_baseline
  } else {
    fallback_baseline
  }
  let height = if measured_height > 0.0 {
    measured_height
  } else {
    fallback_height
  }
  { baseline, height: height.max(baseline) }
}

///|
fn skia_caret_positions(
  font : @skia_native.Font,
  text : String,
  glyph_run? : SkiaGlyphRun,
) -> Array[Double] {
  match glyph_run {
    Some(run) =>
      match skia_shaped_caret_positions(text, run) {
        Some(carets) =>
          if skia_shaped_caret_positions_are_usable(text, carets) {
            return carets
          }
        None => ()
      }
    None => ()
  }
  let chars = text.to_array()
  let carets : Array[Double] = [0.0]
  for index in 1..<(chars.length() + 1) {
    let prefix = String::from_array(chars[:index])
    carets.push(skia_measure_text_width(font, prefix))
  }
  skia_stabilize_grapheme_cluster_carets(text, carets)
}

///|
fn skia_shaped_caret_positions_are_usable(
  text : String,
  carets : Array[Double],
) -> Bool {
  let chars = text.to_array()
  if carets.length() != chars.length() + 1 {
    return false
  }
  let clusters = skia_grapheme_cluster_texts(text)
  if clusters.length() != chars.length() || chars.length() <= 2 {
    return true
  }
  for index in 1..<(carets.length() - 1) {
    if carets[index] > carets[index - 1] {
      return true
    }
  }
  false
}

///|
fn skia_layout_width_from_carets(carets : Array[Double]) -> Double {
  if carets.is_empty() {
    0.0
  } else {
    carets[carets.length() - 1]
  }
}

///|
fn skia_shaped_caret_positions(
  text : String,
  run : SkiaGlyphRun,
) -> Array[Double]? {
  if run.clusters.is_empty() ||
    run.positions.length() != run.clusters.length() ||
    run.width <= 0.0 {
    return None
  }
  let offsets = skia_utf8_char_offsets(text)
  if offsets.length() <= 1 {
    return Some([0.0])
  }
  let carets : Array[Double] = Array::new(capacity=offsets.length())
  for _ in offsets {
    carets.push(-1.0)
  }
  carets[0] = 0.0
  carets[carets.length() - 1] = run.width
  for index, cluster in run.clusters {
    match skia_char_index_for_utf8_offset(offsets, cluster) {
      Some(caret_index) => {
        let x = run.positions[index].x.to_double()
        if x >= 0.0 && x <= run.width {
          let current = carets[caret_index]
          if current < 0.0 || x < current {
            carets[caret_index] = x
          }
        }
      }
      None => ()
    }
  }
  let mut previous = 0.0
  for index in 0..<carets.length() {
    if carets[index] < 0.0 || carets[index] < previous {
      carets[index] = previous
    } else {
      previous = carets[index]
    }
  }
  carets[carets.length() - 1] = run.width.max(carets[carets.length() - 1])
  Some(skia_stabilize_grapheme_cluster_carets(text, carets))
}

///|
fn skia_stabilize_grapheme_cluster_carets(
  text : String,
  carets : Array[Double],
) -> Array[Double] {
  let chars = text.to_array()
  if carets.length() != chars.length() + 1 {
    return carets
  }
  let adjusted = carets.copy()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start + 1 {
      skia_stabilize_caret_cluster(adjusted, start, end)
    }
  }
  adjusted
}

///|
fn skia_stabilize_caret_cluster(
  carets : Array[Double],
  start : Int,
  end : Int,
) -> Unit {
  if start < 0 || end <= start + 1 || end >= carets.length() {
    return ()
  }
  let cluster_start = carets[start]
  for caret_index in (start + 1)..<end {
    carets[caret_index] = cluster_start
  }
  if carets[end] < cluster_start {
    carets[end] = cluster_start
  }
}

///|
fn skia_utf8_char_offsets(text : String) -> Array[Int] {
  let offsets : Array[Int] = [0]
  let mut offset = 0
  for ch in text {
    offset += @utf8.encode(ch.to_string()[:], bom=false).length()
    offsets.push(offset)
  }
  offsets
}

///|
fn skia_char_index_for_utf8_offset(offsets : Array[Int], offset : Int) -> Int? {
  if offset < 0 {
    return None
  }
  for index, current in offsets {
    if current == offset {
      return Some(index)
    }
    if current > offset {
      return Some(index)
    }
  }
  None
}

///|
fn skia_measure_text_width(font : @skia_native.Font, text : String) -> Double {
  font.measure_text_utf8(@utf8.encode(text[:], bom=false)).to_double()
}

///|
fn skia_glyph_run(font : @skia_native.Font, text : String) -> SkiaGlyphRun {
  skia_glyph_run_with_shaper(font, text, use_shaper=true)
}

///|
fn skia_glyph_run_for_resolution(
  font : @skia_native.Font,
  text : String,
  resolution : SkiaFontResolution,
) -> SkiaGlyphRun {
  match resolution {
    SkiaFontResolution::SystemFontMgr => skia_glyph_run(font, text)
    SkiaFontResolution::EmptyTypeface =>
      skia_glyph_run_with_shaper(font, text, use_shaper=false)
  }
}

///|
fn skia_glyph_run_with_shaper(
  font : @skia_native.Font,
  text : String,
  use_shaper~ : Bool,
) -> SkiaGlyphRun {
  let bytes = @utf8.encode(text[:], bom=false)
  if use_shaper && @skia_native.skia_shaper_available() {
    match font.shape_text_utf8(bytes) {
      Some(run) => {
        let glyphs = run.glyphs()
        let positions = run.positions()
        if !glyphs.is_empty() && glyphs.length() == positions.length() {
          let clusters = run.clusters()
          if clusters.length() == glyphs.length() {
            return {
              glyphs,
              positions,
              clusters,
              width: run.advance().x.to_double(),
            }
          }
        }
      }
      None => ()
    }
  }
  let glyphs = font.text_to_glyphs_utf8(bytes)
  {
    glyphs,
    positions: font.glyph_positions(glyphs),
    clusters: [],
    width: font.measure_text_utf8(bytes).to_double(),
  }
}

///|
fn skia_glyph_run_has_visible_glyphs(run : SkiaGlyphRun) -> Bool {
  if run.glyphs.is_empty() || run.width <= 0.0 {
    return false
  }
  run.glyphs.any(glyph => glyph.to_int() != 0)
}

///|
fn skia_glyph_run_missing_glyph_count(run : SkiaGlyphRun) -> Int {
  let mut count = 0
  for glyph in run.glyphs {
    if glyph.to_int() == 0 {
      count = count + 1
    }
  }
  count
}

///|
fn skia_glyph_run_can_draw_text(run : SkiaGlyphRun) -> Bool {
  skia_glyph_run_has_visible_glyphs(run) &&
  skia_glyph_run_missing_glyph_count(run) == 0
}

///|
fn skia_glyph_run_improves_missing_glyphs(
  primary_run : SkiaGlyphRun,
  fallback_run : SkiaGlyphRun,
) -> Bool {
  if !skia_glyph_run_has_visible_glyphs(fallback_run) {
    return false
  }
  if !skia_glyph_run_has_visible_glyphs(primary_run) {
    return true
  }
  skia_glyph_run_missing_glyph_count(fallback_run) <
  skia_glyph_run_missing_glyph_count(primary_run)
}

///|
fn skia_fallback_draw_payload(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
  primary_run : SkiaGlyphRun,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  match skia_emoji_fallback_draw_font(font, text, resolution) {
    Some(emoji_font) =>
      match skia_complete_fallback_payload(emoji_font, text) {
        Some(payload) => return Some(payload)
        None => ()
      }
    None => ()
  }
  match skia_default_fallback_draw_font(font) {
    Some(fallback_font) =>
      skia_recovering_fallback_payload(fallback_font, text, primary_run)
    None => None
  }
}

///|
fn skia_complete_fallback_payload(
  font : @skia_native.Font,
  text : String,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run(font, text)
  if skia_glyph_run_can_draw_text(fallback_run) {
    Some((font, fallback_run))
  } else {
    None
  }
}

///|
fn skia_recovering_fallback_payload(
  font : @skia_native.Font,
  text : String,
  primary_run : SkiaGlyphRun,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run(font, text)
  if skia_glyph_run_can_draw_text(fallback_run) ||
    skia_glyph_run_improves_missing_glyphs(primary_run, fallback_run) {
    Some((font, fallback_run))
  } else {
    None
  }
}

///|
fn skia_emoji_fallback_draw_font(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> @skia_native.Font? {
  match resolution {
    SkiaFontResolution::SystemFontMgr =>
      if skia_text_contains_emoji_hint(text) {
        skia_system_emoji_font(font)
      } else {
        None
      }
    SkiaFontResolution::EmptyTypeface => None
  }
}

///|
fn skia_system_emoji_font(font : @core.FontSpec) -> @skia_native.Font? {
  match @skia_native.FontMgr::default() {
    Some(font_mgr) => {
      let emoji_font = @core.FontSpec::new(
        families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
        size=font.size,
        weight=font.weight,
        style=font.style,
      )
      match skia_typeface_from_font_mgr(font_mgr, emoji_font) {
        Some(typeface) =>
          @skia_native.Font::from_typeface(
            typeface,
            size=Float::from_double(font.size),
          )
        None => None
      }
    }
    None => None
  }
}

///|
fn skia_default_fallback_draw_font(font : @core.FontSpec) -> @skia_native.Font? {
  @skia_native.Font::default(size=Float::from_double(font.size))
}

///|
fn skia_text_contains_emoji_hint(text : String) -> Bool {
  for ch in text {
    if skia_codepoint_is_emoji_hint(ch.to_int()) {
      return true
    }
  }
  false
}

///|
fn skia_codepoint_is_emoji_hint(codepoint : Int) -> Bool {
  codepoint == 0x200D ||
  codepoint == 0xFE0F ||
  (codepoint >= 0x2600 && codepoint <= 0x27BF) ||
  (codepoint >= 0x1F000 && codepoint <= 0x1FAFF)
}

///|
fn skia_codepoint_is_hangul_cluster_codepoint(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_l(codepoint) ||
  skia_codepoint_is_hangul_v(codepoint) ||
  skia_codepoint_is_hangul_t(codepoint) ||
  skia_codepoint_is_hangul_lv(codepoint) ||
  skia_codepoint_is_hangul_lvt(codepoint)
}

///|
fn skia_codepoint_is_hangul_l(codepoint : Int) -> Bool {
  (codepoint >= 0x1100 && codepoint <= 0x115F) ||
  (codepoint >= 0xA960 && codepoint <= 0xA97C)
}

///|
fn skia_codepoint_is_hangul_v(codepoint : Int) -> Bool {
  (codepoint >= 0x1160 && codepoint <= 0x11A7) ||
  (codepoint >= 0xD7B0 && codepoint <= 0xD7C6)
}

///|
fn skia_codepoint_is_hangul_t(codepoint : Int) -> Bool {
  (codepoint >= 0x11A8 && codepoint <= 0x11FF) ||
  (codepoint >= 0xD7CB && codepoint <= 0xD7FB)
}

///|
fn skia_codepoint_is_hangul_lv(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 == 0
}

///|
fn skia_codepoint_is_hangul_lvt(codepoint : Int) -> Bool {
  skia_codepoint_is_hangul_syllable(codepoint) && (codepoint - 0xAC00) % 28 != 0
}

///|
fn skia_codepoint_is_hangul_syllable(codepoint : Int) -> Bool {
  codepoint >= 0xAC00 && codepoint <= 0xD7A3
}

///|
fn skia_codepoint_is_hangul_compatibility_jamo(codepoint : Int) -> Bool {
  codepoint >= 0x3130 && codepoint <= 0x318F
}

///|
fn skia_codepoint_is_hebrew_script(codepoint : Int) -> Bool {
  codepoint >= 0x0590 && codepoint <= 0x05FF
}

///|
fn skia_codepoint_is_arabic_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0600 && codepoint <= 0x08FF) ||
  (codepoint >= 0xFB50 && codepoint <= 0xFDFF) ||
  (codepoint >= 0xFE70 && codepoint <= 0xFEFF)
}

///|
fn skia_codepoint_is_devanagari_script(codepoint : Int) -> Bool {
  codepoint >= 0x0900 && codepoint <= 0x097F
}

///|
fn skia_codepoint_is_thai_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E00 && codepoint <= 0x0E7F
}

///|
fn skia_codepoint_is_lao_script(codepoint : Int) -> Bool {
  codepoint >= 0x0E80 && codepoint <= 0x0EFF
}

///|
fn skia_codepoint_is_sinhala_script(codepoint : Int) -> Bool {
  codepoint >= 0x0D80 && codepoint <= 0x0DFF
}

///|
fn skia_codepoint_is_khmer_script(codepoint : Int) -> Bool {
  codepoint >= 0x1780 && codepoint <= 0x17FF
}

///|
fn skia_codepoint_is_myanmar_script(codepoint : Int) -> Bool {
  codepoint >= 0x1000 && codepoint <= 0x109F
}

///|
fn skia_codepoint_is_latin_script(codepoint : Int) -> Bool {
  (codepoint >= 0x0041 && codepoint <= 0x005A) ||
  (codepoint >= 0x0061 && codepoint <= 0x007A) ||
  (codepoint >= 0x00C0 && codepoint <= 0x024F) ||
  (codepoint >= 0x1E00 && codepoint <= 0x1EFF)
}

///|
fn skia_font_with_resolution_for_text(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
) -> @skia_native.Font? {
  match resolution {
    SkiaFontResolution::EmptyTypeface =>
      @skia_native.Font::empty(size=Float::from_double(font.size))
    SkiaFontResolution::SystemFontMgr =>
      match skia_typeface_for_text(font, text) {
        Some(typeface) =>
          @skia_native.Font::from_typeface(
            typeface,
            size=Float::from_double(font.size),
          )
        None => @skia_native.Font::default(size=Float::from_double(font.size))
      }
  }
}

///|
fn skia_typeface_for_text(
  font : @core.FontSpec,
  text : String,
) -> @skia_native.Typeface? {
  match @skia_native.FontMgr::default() {
    Some(font_mgr) => skia_typeface_from_font_mgr_for_text(font_mgr, font, text)
    None => None
  }
}

///|
fn skia_typeface_from_font_mgr_for_text(
  font_mgr : @skia_native.FontMgr,
  font : @core.FontSpec,
  text : String,
) -> @skia_native.Typeface? {
  let request = skia_font_fallback_request(font, text)
  if !request.is_empty() {
    match font_mgr.match_fallback_request(request) {
      Some(typeface) => return Some(typeface)
      None => ()
    }
  }
  skia_typeface_from_font_mgr(font_mgr, font)
}

///|
fn skia_typeface_from_font_mgr(
  font_mgr : @skia_native.FontMgr,
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  for family in font.families.families {
    for family_name in skia_font_family_candidates(family) {
      match
        font_mgr.match_family_style(
          @utf8.encode(family_name[:], bom=false),
          weight=font.weight,
          width=5,
          slant=skia_font_slant(font.style),
        ) {
        Some(typeface) => return Some(typeface)
        None => ()
      }
    }
  }
  None
}

///|
fn skia_font_fallback_request(
  font : @core.FontSpec,
  text : String,
) -> @moui_skia.FontFallbackRequest {
  @moui_skia.FontFallbackRequest::new(
    families=skia_font_fallback_chain(font),
    bcp47=skia_font_fallback_language_bytes(text),
    character=skia_representative_fallback_codepoint(text),
    style=skia_font_style_request(font),
  )
}

///|
fn skia_font_fallback_language_bytes(text : String) -> Array[Bytes] {
  let tags = skia_font_fallback_language_tags(text)
  let bytes : Array[Bytes] = []
  for tag in tags {
    bytes.push(@utf8.encode(tag[:], bom=false))
  }
  bytes
}

///|
fn skia_font_fallback_language_tags(text : String) -> Array[String] {
  let tags : Array[String] = []
  let representative = skia_representative_fallback_codepoint(text)
  match skia_script_language_tag_for_codepoint(representative) {
    Some(tag) => skia_push_language_tag(tags, tag)
    None => ()
  }
  if representative > 0 {
    skia_push_language_tag(tags, "en")
  }
  tags
}

///|
fn skia_push_language_tag(tags : Array[String], tag : String) -> Unit {
  if tag != "" && !tags.contains(tag) {
    tags.push(tag)
  }
}

///|
fn skia_script_language_tag_for_codepoint(codepoint : Int) -> String? {
  if codepoint <= 0 {
    None
  } else if skia_codepoint_is_emoji_hint(codepoint) {
    Some("und-Zsye")
  } else if skia_codepoint_is_kana(codepoint) {
    Some("ja")
  } else if skia_codepoint_is_cjk_ideograph(codepoint) {
    Some("zh-Hans")
  } else if skia_codepoint_is_hangul_cluster_codepoint(codepoint) ||
    skia_codepoint_is_hangul_compatibility_jamo(codepoint) {
    Some("ko")
  } else if skia_codepoint_is_hebrew_script(codepoint) {
    Some("he")
  } else if skia_codepoint_is_arabic_script(codepoint) {
    Some("ar")
  } else if skia_codepoint_is_devanagari_script(codepoint) {
    Some("hi")
  } else if skia_codepoint_is_thai_script(codepoint) {
    Some("th")
  } else if skia_codepoint_is_lao_script(codepoint) {
    Some("lo")
  } else if skia_codepoint_is_sinhala_script(codepoint) {
    Some("si")
  } else if skia_codepoint_is_khmer_script(codepoint) {
    Some("km")
  } else if skia_codepoint_is_myanmar_script(codepoint) {
    Some("my")
  } else if skia_codepoint_is_latin_script(codepoint) {
    Some("en")
  } else {
    None
  }
}

///|
fn skia_font_fallback_chain(
  font : @core.FontSpec,
) -> @moui_skia.FontFallbackChain {
  let families = skia_preflight_family_candidates(font)
  let primary_family = if families.is_empty() {
    b"system-ui"
  } else {
    @utf8.encode(families[0][:], bom=false)
  }
  let fallback_families : Array[Bytes] = []
  if families.length() > 1 {
    for index in 1..<families.length() {
      fallback_families.push(@utf8.encode(families[index][:], bom=false))
    }
  }
  @moui_skia.FontFallbackChain::new(primary_family~, fallback_families~)
}

///|
fn skia_font_style_request(
  font : @core.FontSpec,
) -> @moui_skia.FontStyleRequest {
  @moui_skia.FontStyleRequest::new(
    weight=font.weight,
    width=5,
    slant=skia_font_slant(font.style),
  )
}

///|
fn skia_font_family_candidates(family : @core.FontFamily) -> Array[String] {
  match family {
    Name(name) => [name]
    SystemUi | UiSansSerif | SansSerif => skia_system_sans_families()
    UiSerif | Serif => skia_serif_families()
    UiMonospace | Monospace => skia_monospace_families()
    Emoji => skia_emoji_families()
    Math => skia_serif_families()
    FangSong => skia_fangsong_families()
  }
}

///|
fn skia_system_sans_families() -> Array[String] {
  [
    "Helvetica Neue", "Segoe UI", "Arial", "DejaVu Sans", "Noto Sans", "Liberation Sans",
  ]
}

///|
fn skia_serif_families() -> Array[String] {
  [
    "Times New Roman", "Georgia", "DejaVu Serif", "Noto Serif", "Liberation Serif",
  ]
}

///|
fn skia_monospace_families() -> Array[String] {
  [
    "Menlo", "Consolas", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono", "Liberation Mono",
  ]
}

///|
fn skia_emoji_families() -> Array[String] {
  ["Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"]
}

///|
fn skia_fangsong_families() -> Array[String] {
  ["STFangsong", "FangSong", "FangSong SC", "SimSun"]
}

///|
fn skia_font_slant(style : @core.FontStyle) -> Int {
  match style {
    Normal => 0
    Italic => 1
  }
}

///|
fn skia_dim_to_int(value : Double) -> Int {
  value.ceil().max(1.0).to_int()
}

///|
fn skia_color(color : @core.Color) -> @moui_skia.Color {
  @moui_skia.Color::from_argb(
    color_component_byte(color.a),
    color_component_byte(color.r),
    color_component_byte(color.g),
    color_component_byte(color.b),
  )
}

///|
fn color_component_byte(value : Double) -> Byte {
  (value.max(0.0).min(1.0) * 255.0).round().to_int().to_byte()
}

///|
fn skia_paint(color : @core.Color) -> @moui_skia.Paint {
  @moui_skia.Paint::new(color=skia_color(color), anti_alias=true)
}

///|
fn skia_opacity_paint(opacity : Double) -> @moui_skia.Paint {
  @moui_skia.Paint::new(
    color=@moui_skia.Color::white().with_alpha(color_component_byte(opacity)),
    anti_alias=true,
  )
}

///|
fn skia_stroke_paint(color : @core.Color, width : Double) -> @moui_skia.Paint {
  @moui_skia.Paint::new(color=skia_color(color), anti_alias=true)
  .set_stroke(true)
  .set_stroke_width(Float::from_double(width.max(0.0)))
}

///|
fn skia_blend_mode(mode : @core.BlendMode) -> @moui_skia.BlendMode {
  match mode {
    @core.BlendMode::SourceOver => @moui_skia.BlendMode::SrcOver
    @core.BlendMode::Multiply => @moui_skia.BlendMode::Multiply
    @core.BlendMode::Screen => @moui_skia.BlendMode::Screen
    @core.BlendMode::Overlay => @moui_skia.BlendMode::Overlay
    @core.BlendMode::Darken => @moui_skia.BlendMode::Darken
    @core.BlendMode::Lighten => @moui_skia.BlendMode::Lighten
  }
}

///|
fn skia_shader_effect_colors(
  fallback : @core.Brush,
) -> (@core.Color, @core.Color) {
  match fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
    @core.Brush::RadialGradient(gradient) =>
      (gradient.center_color, gradient.edge_color)
  }
}

///|
fn skia_color_filter_matrix(
  values : Array[Double],
) -> @skia_native.ColorFilter? {
  @skia_native.ColorFilter::matrix(skia_color_filter_matrix_values(values))
}

///|
fn skia_color_filter_matrix_values(values : Array[Double]) -> Array[Float] {
  let matrix = skia_identity_color_matrix_values()
  let count = values.length().min(20)
  for index in 0..<count {
    matrix[index] = Float::from_double(values[index])
  }
  matrix
}

///|
fn skia_identity_color_matrix_values() -> Array[Float] {
  let matrix : Array[Float] = []
  for index in 0..<20 {
    matrix.push(
      if index == 0 || index == 6 || index == 12 || index == 18 {
        1.0
      } else {
        0.0
      },
    )
  }
  matrix
}

///|
fn skia_rect(rect : @core.Rect) -> @moui_skia.Rect {
  @moui_skia.Rect::from_xywh(
    Float::from_double(rect.origin.x),
    Float::from_double(rect.origin.y),
    Float::from_double(rect.size.width),
    Float::from_double(rect.size.height),
  )
}

///|
fn skia_point(point : @core.Point) -> @moui_skia.Point {
  @moui_skia.Point::new(
    Float::from_double(point.x),
    Float::from_double(point.y),
  )
}

///|
fn skia_rrect(rounded : @core.RoundedRect) -> @moui_skia.RRect {
  @moui_skia.RRect::from_rect_xy(
    skia_rect(rounded.rect),
    Float::from_double(rounded.radius),
    Float::from_double(rounded.radius),
  )
}

///|
fn skia_matrix(transform : @core.Transform2D) -> @moui_skia.Matrix {
  @moui_skia.Matrix::from_affine([
    Float::from_double(transform.a),
    Float::from_double(transform.c),
    Float::from_double(transform.tx),
    Float::from_double(transform.b),
    Float::from_double(transform.d),
    Float::from_double(transform.ty),
  ]).unwrap_or(@moui_skia.Matrix::identity())
}

///|
fn skia_path(spec : @core.PathSpec) -> @skia_native.Path? {
  match @skia_native.Path::new() {
    Some(path) => {
      for verb in spec.verbs {
        match verb {
          @core.PathVerb::MoveTo(point) => path.move_to(skia_point(point))
          @core.PathVerb::LineTo(point) => path.line_to(skia_point(point))
          @core.PathVerb::QuadTo(control, end) =>
            path.quad_to(skia_point(control), skia_point(end))
          @core.PathVerb::CubicTo(c1, c2, end) =>
            path.cubic_to(skia_point(c1), skia_point(c2), skia_point(end))
          @core.PathVerb::Close => path.close()
        }
      }
      Some(path)
    }
    None => None
  }
}
