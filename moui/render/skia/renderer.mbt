///|
pub(all) suberror SkiaRendererError {
  SkiaUnavailable
  SurfaceUnavailable
  CanvasUnavailable
  ReadPixelsUnavailable
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaRendererError::message(self : SkiaRendererError) -> String {
  match self {
    SkiaUnavailable => "skia_mbt/native is unavailable"
    SurfaceUnavailable => "failed to create Skia raster surface"
    CanvasUnavailable => "failed to acquire Skia canvas"
    ReadPixelsUnavailable => "failed to read Skia surface pixels"
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
  bidi_reordering_ready : Bool
  paragraph_line_breaking_ready : Bool
  mixed_run_font_fallback_ready : Bool
  deterministic_color_emoji_ready : Bool
  full_grapheme_parity_ready : Bool
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
    self.empty_typeface_emoji_retry_disabled
  let tracked_gaps_pending = !self.bidi_reordering_ready &&
    !self.paragraph_line_breaking_ready &&
    !self.deterministic_color_emoji_ready &&
    !self.full_grapheme_parity_ready
  let baseline_label = if baseline_ready {
    "baseline ready"
  } else {
    "baseline pending"
  }
  let gap_label = if tracked_gaps_pending {
    "tracked gaps pending"
  } else {
    "tracked gaps changed"
  }
  let mixed_run_label = if self.mixed_run_font_fallback_ready {
    "mixed-run fallback ready; bidi, paragraph line breaking, color emoji, and full grapheme parity pending"
  } else {
    "bidi, paragraph line breaking, mixed-run fallback, color emoji, and full grapheme parity pending"
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
  mut surface : @skia_native.Surface
  image_cache : Map[String, @skia_native.Image]
  failed_images : Map[String, String]
  image_lifecycle : @render.ImageResourceLifecycle
  mut present_count : Int
  mut unsupported_command_count : Int
  mut last_frame : SkiaPixelFrame?
}

///|
priv struct SkiaTextMetrics {
  baseline : Double
  height : Double
}

///|
priv struct SkiaGlyphRun {
  glyphs : Array[@skia_native.GlyphId]
  positions : Array[@skia_mbt.Point]
  clusters : Array[Int]
  width : Double
}

///|
priv struct SkiaTextPlacement {
  origin : @skia_mbt.Point
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
    description="Native Skia raster renderer using skia_mbt/native CPU surfaces, " +
      surface_preflight.summary() +
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
) -> SkiaRasterRenderer raise SkiaRendererError {
  if !skia_available() {
    raise SkiaRendererError::SkiaUnavailable
  }
  let surface = create_surface(metrics)
  {
    metrics,
    target,
    font_resolution,
    surface,
    image_cache: {},
    failed_images: {},
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    present_count: 0,
    unsupported_command_count: 0,
    last_frame: None,
  }
}

///|
fn create_surface(
  metrics : @render.RendererSurfaceMetrics,
) -> @skia_native.Surface raise SkiaRendererError {
  let target = skia_raster_surface_target(metrics)
  match @skia_native.Surface::for_target(target) {
    Some(surface) => surface
    None => raise SkiaRendererError::SurfaceUnavailable
  }
}

///|
fn skia_raster_surface_target(
  metrics : @render.RendererSurfaceMetrics,
) -> @skia_mbt.SurfaceTargetDescriptor {
  @skia_mbt.SurfaceTargetDescriptor::raster_n32_premul(
    @skia_mbt.ISize::new(
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
  let command_list = @skia_mbt.RenderCommandList::for_target(target).clear(
    @skia_mbt.Color::transparent(),
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
    surface_resource_count: resource_plan.count_kind(@skia_mbt.SurfaceResource),
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
  let run = @skia_mbt.TextRunDescriptor::new(
    range=@skia_mbt.TextRange::new(0, text_bytes.length()),
    fallback~,
  )
  let measurement = @skia_mbt.TextMeasurementDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
    shape=true,
  )
  let shaping = @skia_mbt.TextShapingDescriptor::new(
    run~,
    font_key~,
    width=Float::from_double(font.size * 32.0),
  )
  let glyph_count = skia_preflight_glyph_count(text)
  let shaped_run = shaping.shaped_run_descriptor(
    glyph_count~,
    cluster_count=glyph_count,
    advance=@skia_mbt.Point::new(Float::from_double(font.size), 0.0),
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
  let mixed_run_font_fallback_ready = skia_mixed_text_segments("A你\u{1F642}B").length() ==
    4 &&
    skia_grapheme_cluster_texts("\u{1F469}\u{200D}\u{1F4BB}").length() == 1
  let ready_count = skia_ready_count([
    descriptor.ready(),
    !fallback_request.is_empty() && fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    mixed_run_font_fallback_ready,
  ])
  let gap_count = skia_gap_count([
    false, false, mixed_run_font_fallback_ready, false, false,
  ])
  SkiaTextMaturityPreflight::{
    descriptor_ready: descriptor.ready(),
    fallback_request_ready: !fallback_request.is_empty() &&
    fallback_request.has_character(),
    shaped_cluster_caret_ready,
    fallback_cluster_caret_ready,
    emoji_hint_ready,
    empty_typeface_emoji_retry_disabled,
    bidi_reordering_ready: false,
    paragraph_line_breaking_ready: false,
    mixed_run_font_fallback_ready,
    deterministic_color_emoji_ready: false,
    full_grapheme_parity_ready: false,
    ready_count,
    gap_count,
  }
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
      @skia_mbt.Point::new(0.0, 0.0),
      @skia_mbt.Point::new(14.0, 0.0),
      @skia_mbt.Point::new(28.0, 0.0),
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
fn skia_preflight_glyph_positions(count : Int) -> Array[@skia_mbt.Point] {
  let positions : Array[@skia_mbt.Point] = []
  for index in 0..<count {
    positions.push(@skia_mbt.Point::new(Float::from_int(index), 0.0))
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
  self.surface = create_surface(metrics)
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
        @skia_mbt.Size::new(
          Float::from_double(self.metrics.scale_factor),
          Float::from_double(self.metrics.scale_factor),
        ),
      )
      self.unsupported_command_count = 0
      let canvas_scopes : Array[SkiaCanvasScopeKind] = []
      for command in commands {
        self.render_command(canvas, command, canvas_scopes)
      }
      if !canvas_scopes.is_empty() {
        self.unsupported_command_count += canvas_scopes.length()
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
        self.unsupported_command_count = self.unsupported_command_count + 1
      }
    None => self.unsupported_command_count = self.unsupported_command_count + 1
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
          self.unsupported_command_count = self.unsupported_command_count + 1
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
      self.unsupported_command_count = self.unsupported_command_count + 1
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
        self.unsupported_command_count = self.unsupported_command_count + 1
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
                @skia_mbt.Paint::new(anti_alias=true),
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
          self.unsupported_command_count = self.unsupported_command_count + 1
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
        @skia_mbt.Rect::from_xywh(
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
        sampling=@skia_mbt.SamplingOptions::linear(),
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
            ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
            return None
          }
        None => ()
      }
      match skia_image_source_bytes(source) {
        Some(bytes) => {
          ignore(self.image_lifecycle.mark_loading(source))
          match @skia_native.Image::from_encoded_bytes(bytes) {
            Some(image) => {
              self.failed_images.remove(source)
              self.image_cache[source] = image
              ignore(
                self.image_lifecycle.mark_ready(
                  source,
                  width=image.width(),
                  height=image.height(),
                ),
              )
              Some(image)
            }
            None => {
              self.failed_images[source] = "Skia image decode failed"
              ignore(
                self.image_lifecycle.mark_failed(
                  source,
                  diagnostic="Skia image decode failed",
                ),
              )
              None
            }
          }
        }
        None => {
          self.failed_images[source] = "Skia image source bytes are unavailable"
          ignore(
            self.image_lifecycle.mark_failed(
              source,
              diagnostic="Skia image source bytes are unavailable",
            ),
          )
          None
        }
      }
    }
  }
}

///|
fn skia_image_failed_cache_can_retry(source : String) -> Bool {
  !source.has_prefix("data:") && @fs.path_exists(source)
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
          origin=@skia_mbt.Point::new(
            Float::from_double(
              placement.origin.x.to_double() + segment.x_offset,
            ),
            placement.origin.y,
          ),
        )
      }
      canvas.restore_to_count(saved)
    }
    None => self.unsupported_command_count = self.unsupported_command_count + 1
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
    origin: @skia_mbt.Point::new(Float::from_double(x), Float::from_double(y)),
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
        skia_fallback_draw_payload(font_spec, text, resolution)
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
  let clusters = skia_grapheme_cluster_texts(text)
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
fn skia_grapheme_cluster_texts(text : String) -> Array[String] {
  let chars = text.to_array()
  let clusters : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    let end = skia_grapheme_cluster_end(chars, index)
    let safe_end = if end <= index { index + 1 } else { end }
    clusters.push(String::from_array(chars[index:safe_end]))
    index = safe_end
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
  (codepoint >= 0x3400 && codepoint <= 0x4DBF) ||
  (codepoint >= 0x4E00 && codepoint <= 0x9FFF) ||
  (codepoint >= 0xF900 && codepoint <= 0xFAFF) ||
  (codepoint >= 0x20000 && codepoint <= 0x2FA1F) ||
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
    None => self.unsupported_command_count = self.unsupported_command_count + 1
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
                @skia_mbt.Paint::new(anti_alias=true),
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
      self.unsupported_command_count = self.unsupported_command_count + 1
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
      self.unsupported_command_count = self.unsupported_command_count + 1
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
            @skia_mbt.Paint::new(anti_alias=true),
          )
        None => {
          canvas.draw_rect(skia_rect(frame), skia_paint(brush.fallback_color()))
          self.unsupported_command_count = self.unsupported_command_count + 1
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
        @skia_mbt.Paint::new(anti_alias=true),
      )
    None => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.unsupported_command_count = self.unsupported_command_count + 1
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
pub fn SkiaRasterRenderer::dispose(self : SkiaRasterRenderer) -> Unit {
  for source, _ in self.image_cache {
    ignore(self.image_lifecycle.dispose(source))
  }
  self.image_cache.clear()
  self.failed_images.clear()
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
  @core.TextSystem::new(id="skia-raster-empty-typeface-text-system", measure=input => {
    let fallback = @core.TextSystem::fallback().measure_text(input)
    match
      skia_resolved_text_layout_for_resolution(
        input.font,
        input.text,
        SkiaFontResolution::EmptyTypeface,
      ) {
      Some(layout) => skia_resolved_text_layout_result(input, fallback, layout~)
      None => fallback
    }
  })
}

///|
fn skia_system_font_mgr_text_system() -> @core.TextSystem {
  @core.TextSystem::new(id="skia-raster-text-system", measure=input => {
    let fallback = @core.TextSystem::fallback().measure_text(input)
    match
      skia_resolved_text_layout_for_resolution(
        input.font,
        input.text,
        SkiaFontResolution::SystemFontMgr,
      ) {
      Some(layout) => skia_resolved_text_layout_result(input, fallback, layout~)
      None => fallback
    }
  })
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
        Some(carets) => return carets
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
  let mut index = 0
  while index < chars.length() {
    let cluster_end = skia_grapheme_cluster_end(chars, index)
    if cluster_end > index + 1 {
      skia_stabilize_caret_cluster(adjusted, index, cluster_end)
      index = cluster_end
    } else {
      index = index + 1
    }
  }
  adjusted
}

///|
fn skia_grapheme_cluster_end(chars : Array[Char], start : Int) -> Int {
  if start < 0 || start >= chars.length() {
    return start
  }
  if skia_codepoint_is_regional_indicator(chars[start].to_int()) {
    return skia_regional_indicator_cluster_end(chars, start)
  }
  if skia_codepoint_is_grapheme_prepend(chars[start].to_int()) {
    return skia_prepend_cluster_end(chars, start)
  }
  if skia_codepoint_is_hangul_cluster_codepoint(chars[start].to_int()) {
    return skia_hangul_cluster_end(chars, start)
  }
  if skia_codepoint_can_start_emoji_tag_sequence(chars[start].to_int()) {
    let tag_end = skia_emoji_tag_sequence_end(chars, start)
    if tag_end > start + 1 {
      return tag_end
    }
  }
  let mut end = skia_grapheme_extend_end(chars, start + 1)
  let mut advanced = true
  while advanced {
    advanced = false
    if end < chars.length() &&
      chars[end].to_int() == 0x200D &&
      end + 1 < chars.length() {
      end = skia_grapheme_extend_end(chars, end + 2)
      advanced = true
    } else if end < chars.length() &&
      end > start &&
      skia_codepoint_is_virama(chars[end - 1].to_int()) {
      end = skia_grapheme_extend_end(chars, end + 1)
      advanced = true
    }
  }
  end
}

///|
fn skia_regional_indicator_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() &&
        skia_codepoint_is_regional_indicator(chars[end].to_int()) &&
        end - start < 2 {
    end = end + 1
  }
  end
}

///|
fn skia_emoji_tag_sequence_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start + 1
  let mut saw_tag = false
  while end < chars.length() && skia_codepoint_is_emoji_tag(chars[end].to_int()) {
    saw_tag = true
    end = end + 1
    if chars[end - 1].to_int() == 0xE007F {
      return end
    }
  }
  if saw_tag {
    end
  } else {
    start
  }
}

///|
fn skia_prepend_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut base = start + 1
  while base < chars.length() &&
        skia_codepoint_is_grapheme_prepend(chars[base].to_int()) {
    base = base + 1
  }
  if base >= chars.length() {
    return base
  }
  skia_grapheme_cluster_end(chars, base)
}

///|
fn skia_hangul_cluster_end(chars : Array[Char], start : Int) -> Int {
  let codepoint = chars[start].to_int()
  if skia_codepoint_is_hangul_l(codepoint) {
    return skia_hangul_l_cluster_end(chars, start)
  }
  if skia_codepoint_is_hangul_v(codepoint) ||
    skia_codepoint_is_hangul_lv(codepoint) {
    return skia_hangul_v_cluster_end(chars, start + 1)
  }
  if skia_codepoint_is_hangul_t(codepoint) ||
    skia_codepoint_is_hangul_lvt(codepoint) {
    return skia_hangul_t_cluster_end(chars, start + 1)
  }
  start
}

///|
fn skia_hangul_l_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start + 1
  while end < chars.length() && skia_codepoint_is_hangul_l(chars[end].to_int()) {
    end = end + 1
  }
  if end < chars.length() {
    let codepoint = chars[end].to_int()
    if skia_codepoint_is_hangul_v(codepoint) ||
      skia_codepoint_is_hangul_lv(codepoint) {
      end = skia_hangul_v_cluster_end(chars, end + 1)
    } else if skia_codepoint_is_hangul_lvt(codepoint) {
      end = skia_hangul_t_cluster_end(chars, end + 1)
    }
  }
  skia_grapheme_extend_end(chars, end)
}

///|
fn skia_hangul_v_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() && skia_codepoint_is_hangul_v(chars[end].to_int()) {
    end = end + 1
  }
  skia_hangul_t_cluster_end(chars, end)
}

///|
fn skia_hangul_t_cluster_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() && skia_codepoint_is_hangul_t(chars[end].to_int()) {
    end = end + 1
  }
  skia_grapheme_extend_end(chars, end)
}

///|
fn skia_grapheme_extend_end(chars : Array[Char], start : Int) -> Int {
  let mut end = start
  while end < chars.length() &&
        skia_codepoint_is_grapheme_extend(chars[end].to_int()) {
    end = end + 1
  }
  end
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
fn skia_glyph_run_can_draw_text(run : SkiaGlyphRun) -> Bool {
  skia_glyph_run_has_visible_glyphs(run) &&
  run.glyphs.all(glyph => glyph.to_int() != 0)
}

///|
fn skia_fallback_draw_payload(
  font : @core.FontSpec,
  text : String,
  resolution : SkiaFontResolution,
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
    Some(fallback_font) => skia_visible_fallback_payload(fallback_font, text)
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
fn skia_visible_fallback_payload(
  font : @skia_native.Font,
  text : String,
) -> (@skia_native.Font, SkiaGlyphRun)? {
  let fallback_run = skia_glyph_run(font, text)
  if skia_glyph_run_has_visible_glyphs(fallback_run) {
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
fn skia_codepoint_is_variation_selector(codepoint : Int) -> Bool {
  (codepoint >= 0xFE00 && codepoint <= 0xFE0F) ||
  (codepoint >= 0xE0100 && codepoint <= 0xE01EF)
}

///|
fn skia_codepoint_is_grapheme_extend(codepoint : Int) -> Bool {
  skia_codepoint_is_variation_selector(codepoint) ||
  skia_codepoint_is_combining_mark(codepoint) ||
  skia_codepoint_is_spacing_mark(codepoint) ||
  skia_codepoint_is_emoji_modifier(codepoint) ||
  skia_codepoint_is_emoji_tag(codepoint)
}

///|
fn skia_codepoint_is_grapheme_prepend(codepoint : Int) -> Bool {
  (codepoint >= 0x0600 && codepoint <= 0x0605) ||
  codepoint == 0x06DD ||
  codepoint == 0x070F ||
  codepoint == 0x0890 ||
  codepoint == 0x0891 ||
  codepoint == 0x08E2 ||
  codepoint == 0x110BD ||
  codepoint == 0x110CD
}

///|
fn skia_codepoint_is_combining_mark(codepoint : Int) -> Bool {
  (codepoint >= 0x0300 && codepoint <= 0x036F) ||
  (codepoint >= 0x0591 && codepoint <= 0x05BD) ||
  codepoint == 0x05BF ||
  (codepoint >= 0x05C1 && codepoint <= 0x05C2) ||
  (codepoint >= 0x05C4 && codepoint <= 0x05C5) ||
  codepoint == 0x05C7 ||
  (codepoint >= 0x0610 && codepoint <= 0x061A) ||
  (codepoint >= 0x064B && codepoint <= 0x065F) ||
  codepoint == 0x0670 ||
  (codepoint >= 0x06D6 && codepoint <= 0x06DC) ||
  (codepoint >= 0x06DF && codepoint <= 0x06E4) ||
  (codepoint >= 0x06E7 && codepoint <= 0x06E8) ||
  (codepoint >= 0x06EA && codepoint <= 0x06ED) ||
  codepoint == 0x0711 ||
  (codepoint >= 0x0730 && codepoint <= 0x074A) ||
  (codepoint >= 0x07A6 && codepoint <= 0x07B0) ||
  (codepoint >= 0x07EB && codepoint <= 0x07F3) ||
  (codepoint >= 0x0816 && codepoint <= 0x0819) ||
  (codepoint >= 0x081B && codepoint <= 0x0823) ||
  (codepoint >= 0x0825 && codepoint <= 0x0827) ||
  (codepoint >= 0x0829 && codepoint <= 0x082D) ||
  (codepoint >= 0x0859 && codepoint <= 0x085B) ||
  (codepoint >= 0x08D3 && codepoint <= 0x08FF) ||
  (codepoint >= 0x1AB0 && codepoint <= 0x1AFF) ||
  (codepoint >= 0x1DC0 && codepoint <= 0x1DFF) ||
  (codepoint >= 0x20D0 && codepoint <= 0x20FF) ||
  (codepoint >= 0x102B && codepoint <= 0x103E) ||
  (codepoint >= 0x1056 && codepoint <= 0x1059) ||
  (codepoint >= 0x105E && codepoint <= 0x1060) ||
  (codepoint >= 0x1062 && codepoint <= 0x1064) ||
  (codepoint >= 0x1067 && codepoint <= 0x106D) ||
  (codepoint >= 0x1071 && codepoint <= 0x1074) ||
  (codepoint >= 0x1082 && codepoint <= 0x108D) ||
  codepoint == 0x108F ||
  (codepoint >= 0x109A && codepoint <= 0x109D) ||
  (codepoint >= 0x3099 && codepoint <= 0x309A) ||
  (codepoint >= 0xFE20 && codepoint <= 0xFE2F)
}

///|
fn skia_codepoint_is_spacing_mark(codepoint : Int) -> Bool {
  (codepoint >= 0x0900 && codepoint <= 0x0903) ||
  (codepoint >= 0x093A && codepoint <= 0x093C) ||
  (codepoint >= 0x093E && codepoint <= 0x094F) ||
  (codepoint >= 0x0951 && codepoint <= 0x0957) ||
  (codepoint >= 0x0962 && codepoint <= 0x0963) ||
  (codepoint >= 0x0981 && codepoint <= 0x0983) ||
  codepoint == 0x09BC ||
  (codepoint >= 0x09BE && codepoint <= 0x09C4) ||
  (codepoint >= 0x09C7 && codepoint <= 0x09C8) ||
  (codepoint >= 0x09CB && codepoint <= 0x09CD) ||
  codepoint == 0x09D7 ||
  (codepoint >= 0x09E2 && codepoint <= 0x09E3) ||
  (codepoint >= 0x0A01 && codepoint <= 0x0A03) ||
  codepoint == 0x0A3C ||
  (codepoint >= 0x0A3E && codepoint <= 0x0A42) ||
  (codepoint >= 0x0A47 && codepoint <= 0x0A48) ||
  (codepoint >= 0x0A4B && codepoint <= 0x0A4D) ||
  codepoint == 0x0A51 ||
  (codepoint >= 0x0A70 && codepoint <= 0x0A71) ||
  codepoint == 0x0A75 ||
  (codepoint >= 0x0B01 && codepoint <= 0x0B03) ||
  codepoint == 0x0B3C ||
  (codepoint >= 0x0B3E && codepoint <= 0x0B44) ||
  (codepoint >= 0x0B47 && codepoint <= 0x0B48) ||
  (codepoint >= 0x0B4B && codepoint <= 0x0B4D) ||
  (codepoint >= 0x0B55 && codepoint <= 0x0B57) ||
  (codepoint >= 0x0B62 && codepoint <= 0x0B63) ||
  (codepoint >= 0x0C00 && codepoint <= 0x0C04) ||
  (codepoint >= 0x0C3E && codepoint <= 0x0C44) ||
  (codepoint >= 0x0C46 && codepoint <= 0x0C48) ||
  (codepoint >= 0x0C4A && codepoint <= 0x0C4D) ||
  (codepoint >= 0x0C55 && codepoint <= 0x0C56) ||
  (codepoint >= 0x0C62 && codepoint <= 0x0C63) ||
  (codepoint >= 0x0D00 && codepoint <= 0x0D03) ||
  (codepoint >= 0x0D3B && codepoint <= 0x0D44) ||
  (codepoint >= 0x0D46 && codepoint <= 0x0D48) ||
  codepoint == 0x0DCA ||
  (codepoint >= 0x0D4A && codepoint <= 0x0D4D) ||
  (codepoint >= 0x0DCF && codepoint <= 0x0DD4) ||
  codepoint == 0x0DD6 ||
  (codepoint >= 0x0DD8 && codepoint <= 0x0DDF) ||
  codepoint == 0x0D57 ||
  (codepoint >= 0x0D62 && codepoint <= 0x0D63) ||
  codepoint == 0x0E31 ||
  (codepoint >= 0x0E34 && codepoint <= 0x0E3A) ||
  (codepoint >= 0x0E47 && codepoint <= 0x0E4E) ||
  codepoint == 0x0EB1 ||
  (codepoint >= 0x0EB4 && codepoint <= 0x0EBC) ||
  (codepoint >= 0x0EC8 && codepoint <= 0x0ECD) ||
  (codepoint >= 0x17B4 && codepoint <= 0x17D3) ||
  codepoint == 0x17DD
}

///|
fn skia_codepoint_is_virama(codepoint : Int) -> Bool {
  codepoint == 0x094D ||
  codepoint == 0x09CD ||
  codepoint == 0x0A4D ||
  codepoint == 0x0ACD ||
  codepoint == 0x0B4D ||
  codepoint == 0x0BCD ||
  codepoint == 0x0C4D ||
  codepoint == 0x0CCD ||
  codepoint == 0x0D4D ||
  codepoint == 0x0DCA ||
  codepoint == 0x1039 ||
  codepoint == 0x17D2
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
fn skia_codepoint_is_emoji_modifier(codepoint : Int) -> Bool {
  codepoint >= 0x1F3FB && codepoint <= 0x1F3FF
}

///|
fn skia_codepoint_is_emoji_tag(codepoint : Int) -> Bool {
  (codepoint >= 0xE0020 && codepoint <= 0xE007E) || codepoint == 0xE007F
}

///|
fn skia_codepoint_can_start_emoji_tag_sequence(codepoint : Int) -> Bool {
  codepoint == 0x1F3F4
}

///|
fn skia_codepoint_is_regional_indicator(codepoint : Int) -> Bool {
  codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF
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
) -> @skia_mbt.FontFallbackRequest {
  @skia_mbt.FontFallbackRequest::new(
    families=skia_font_fallback_chain(font),
    character=skia_representative_fallback_codepoint(text),
    style=skia_font_style_request(font),
  )
}

///|
fn skia_font_fallback_chain(
  font : @core.FontSpec,
) -> @skia_mbt.FontFallbackChain {
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
  @skia_mbt.FontFallbackChain::new(primary_family~, fallback_families~)
}

///|
fn skia_font_style_request(font : @core.FontSpec) -> @skia_mbt.FontStyleRequest {
  @skia_mbt.FontStyleRequest::new(
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
fn skia_color(color : @core.Color) -> @skia_mbt.Color {
  @skia_mbt.Color::from_argb(
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
fn skia_paint(color : @core.Color) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(color=skia_color(color), anti_alias=true)
}

///|
fn skia_opacity_paint(opacity : Double) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(
    color=@skia_mbt.Color::white().with_alpha(color_component_byte(opacity)),
    anti_alias=true,
  )
}

///|
fn skia_stroke_paint(color : @core.Color, width : Double) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(color=skia_color(color), anti_alias=true)
  .set_stroke(true)
  .set_stroke_width(Float::from_double(width.max(0.0)))
}

///|
fn skia_blend_mode(mode : @core.BlendMode) -> @skia_mbt.BlendMode {
  match mode {
    @core.BlendMode::SourceOver => @skia_mbt.BlendMode::SrcOver
    @core.BlendMode::Multiply => @skia_mbt.BlendMode::Multiply
    @core.BlendMode::Screen => @skia_mbt.BlendMode::Screen
    @core.BlendMode::Overlay => @skia_mbt.BlendMode::Overlay
    @core.BlendMode::Darken => @skia_mbt.BlendMode::Darken
    @core.BlendMode::Lighten => @skia_mbt.BlendMode::Lighten
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
fn skia_rect(rect : @core.Rect) -> @skia_mbt.Rect {
  @skia_mbt.Rect::from_xywh(
    Float::from_double(rect.origin.x),
    Float::from_double(rect.origin.y),
    Float::from_double(rect.size.width),
    Float::from_double(rect.size.height),
  )
}

///|
fn skia_point(point : @core.Point) -> @skia_mbt.Point {
  @skia_mbt.Point::new(Float::from_double(point.x), Float::from_double(point.y))
}

///|
fn skia_rrect(rounded : @core.RoundedRect) -> @skia_mbt.RRect {
  @skia_mbt.RRect::from_rect_xy(
    skia_rect(rounded.rect),
    Float::from_double(rounded.radius),
    Float::from_double(rounded.radius),
  )
}

///|
fn skia_matrix(transform : @core.Transform2D) -> @skia_mbt.Matrix {
  @skia_mbt.Matrix::from_affine([
    Float::from_double(transform.a),
    Float::from_double(transform.c),
    Float::from_double(transform.tx),
    Float::from_double(transform.b),
    Float::from_double(transform.d),
    Float::from_double(transform.ty),
  ]).unwrap_or(@skia_mbt.Matrix::identity())
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
