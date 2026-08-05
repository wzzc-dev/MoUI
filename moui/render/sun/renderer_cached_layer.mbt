///|
let sun_cached_layer_max_entries : Int = 32

///|
let sun_cached_layer_admission_max_records : Int = 512

///|
pub struct SunCachedLayerAdmissionDiagnostic {
  priv identity_key : String
  priv update_streak : Int
  priv hit_count : Int
  priv skip_reason : String
  priv churn_without_hit : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct SunCachedLayerDiagnostic {
  priv cached_layer_count : Int
  priv max_cached_layer_count : Int
  priv total_hit_count : Int
  priv total_miss_count : Int
  priv total_update_count : Int
  priv total_evict_count : Int
  priv admission_record_count : Int
  priv churn_without_hit_count : Int
  priv cached_layer_keys : Array[String]
  priv admission_records : Array[SunCachedLayerAdmissionDiagnostic]
  priv cache_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn SunCachedLayerAdmissionDiagnostic::identity_key(
  self : SunCachedLayerAdmissionDiagnostic,
) -> String {
  self.identity_key
}

///|
pub fn SunCachedLayerAdmissionDiagnostic::update_streak(
  self : SunCachedLayerAdmissionDiagnostic,
) -> Int {
  self.update_streak
}

///|
pub fn SunCachedLayerAdmissionDiagnostic::hit_count(
  self : SunCachedLayerAdmissionDiagnostic,
) -> Int {
  self.hit_count
}

///|
pub fn SunCachedLayerAdmissionDiagnostic::skip_reason(
  self : SunCachedLayerAdmissionDiagnostic,
) -> String {
  self.skip_reason
}

///|
pub fn SunCachedLayerAdmissionDiagnostic::churn_without_hit(
  self : SunCachedLayerAdmissionDiagnostic,
) -> Bool {
  self.churn_without_hit
}

///|
pub fn SunCachedLayerDiagnostic::cached_layer_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.cached_layer_count
}

///|
pub fn SunCachedLayerDiagnostic::max_cached_layer_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.max_cached_layer_count
}

///|
pub fn SunCachedLayerDiagnostic::total_hit_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.total_hit_count
}

///|
pub fn SunCachedLayerDiagnostic::total_miss_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.total_miss_count
}

///|
pub fn SunCachedLayerDiagnostic::total_update_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.total_update_count
}

///|
pub fn SunCachedLayerDiagnostic::total_evict_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.total_evict_count
}

///|
pub fn SunCachedLayerDiagnostic::admission_record_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.admission_record_count
}

///|
pub fn SunCachedLayerDiagnostic::churn_without_hit_count(
  self : SunCachedLayerDiagnostic,
) -> Int {
  self.churn_without_hit_count
}

///|
pub fn SunCachedLayerDiagnostic::cached_layer_keys(
  self : SunCachedLayerDiagnostic,
) -> Array[String] {
  self.cached_layer_keys
}

///|
pub fn SunCachedLayerDiagnostic::admission_records(
  self : SunCachedLayerDiagnostic,
) -> Array[SunCachedLayerAdmissionDiagnostic] {
  self.admission_records
}

///|
pub fn SunCachedLayerDiagnostic::cache_ready(
  self : SunCachedLayerDiagnostic,
) -> Bool {
  self.cache_ready
}

///|
pub struct SunCachedLayerAdmissionRecord {
  identity_key : String
  mut update_streak : Int
  mut hit_count : Int
  mut skip_reason : String
  mut last_revision : Int
}

///|
priv struct SunCachedLayerFrameStats {
  mut cache_hit_count : Int
  mut cache_miss_count : Int
  mut cache_update_count : Int
  mut cache_evict_count : Int
  missing_layer_keys : Array[String]
}

///|
fn SunCachedLayerFrameStats::new() -> SunCachedLayerFrameStats {
  {
    cache_hit_count: 0,
    cache_miss_count: 0,
    cache_update_count: 0,
    cache_evict_count: 0,
    missing_layer_keys: [],
  }
}

///|
fn SunCachedLayerAdmissionRecord::new(
  identity_key : String,
) -> SunCachedLayerAdmissionRecord {
  {
    identity_key,
    update_streak: 0,
    hit_count: 0,
    skip_reason: "",
    last_revision: -1,
  }
}

///|
fn SunCachedLayerAdmissionRecord::record_update(
  self : SunCachedLayerAdmissionRecord,
  revision : Int,
) -> Unit {
  if self.last_revision != revision {
    self.update_streak = self.update_streak + 1
    self.last_revision = revision
  }
}

///|
fn SunCachedLayerAdmissionRecord::record_hit(
  self : SunCachedLayerAdmissionRecord,
) -> Unit {
  self.hit_count = self.hit_count + 1
}

///|
fn SunCachedLayerAdmissionRecord::churn_without_hit(
  self : SunCachedLayerAdmissionRecord,
) -> Bool {
  self.update_streak > 2 && self.hit_count == 0
}

///|
fn SunCachedLayerAdmissionRecord::to_diagnostic(
  self : SunCachedLayerAdmissionRecord,
) -> SunCachedLayerAdmissionDiagnostic {
  {
    identity_key: self.identity_key,
    update_streak: self.update_streak,
    hit_count: self.hit_count,
    skip_reason: self.skip_reason,
    churn_without_hit: self.churn_without_hit(),
  }
}

///|
fn SunCachedLayerFrameStats::record_missing(
  self : SunCachedLayerFrameStats,
  key : String,
) -> Unit {
  self.cache_miss_count = self.cache_miss_count + 1
  if !self.missing_layer_keys.any(existing => existing == key) {
    self.missing_layer_keys.push(key)
  }
}

///|
fn SunCachedLayerFrameStats::to_render_frame_result(
  self : SunCachedLayerFrameStats,
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
pub fn SunCachedLayerDiagnostic::summary(
  self : SunCachedLayerDiagnostic,
) -> String {
  let label = if self.cache_ready {
    "Sun cached-layer audit ready"
  } else {
    "Sun cached-layer audit pending"
  }
  let base = "\{label}: entries=\{self.cached_layer_count}/\{self.max_cached_layer_count} hits=\{self.total_hit_count} misses=\{self.total_miss_count}"
  base +
  " updates=\{self.total_update_count} evicts=\{self.total_evict_count} churn_without_hit=\{self.churn_without_hit_count}"
}

///|
pub fn SunRasterRenderer::cached_layer_diagnostic(
  self : SunRasterRenderer,
) -> SunCachedLayerDiagnostic {
  let admission_records : Array[SunCachedLayerAdmissionDiagnostic] = []
  let mut churn_without_hit_count = 0
  for record in self.cached_layer_admissions {
    let diagnostic = record.to_diagnostic()
    if diagnostic.churn_without_hit {
      churn_without_hit_count = churn_without_hit_count + 1
    }
    admission_records.push(diagnostic)
  }
  {
    cached_layer_count: self.cached_layer_order.length(),
    max_cached_layer_count: sun_cached_layer_max_entries,
    total_hit_count: self.cached_layer_hit_count,
    total_miss_count: self.cached_layer_miss_count,
    total_update_count: self.cached_layer_update_count,
    total_evict_count: self.cached_layer_evict_count,
    admission_record_count: self.cached_layer_admissions.length(),
    churn_without_hit_count,
    cached_layer_keys: copy_sun_cached_layer_keys(self.cached_layer_order),
    admission_records,
    cache_ready: self.cached_layer_order.length() <=
    sun_cached_layer_max_entries,
  }
}

///|
fn SunRasterRenderer::cached_layer_admission_record(
  self : SunRasterRenderer,
  identity_key : String,
) -> SunCachedLayerAdmissionRecord {
  for record in self.cached_layer_admissions {
    if record.identity_key == identity_key {
      return record
    }
  }
  let record = SunCachedLayerAdmissionRecord::new(identity_key)
  self.cached_layer_admissions.push(record)
  self.prune_cached_layer_admission_records(identity_key)
  record
}

///|
fn SunRasterRenderer::prune_cached_layer_admission_records(
  self : SunRasterRenderer,
  protected_identity_key : String,
) -> Unit {
  while self.cached_layer_admissions.length() >
        sun_cached_layer_admission_max_records {
    let mut removed = false
    let mut index = 0
    while index < self.cached_layer_admissions.length() && !removed {
      if self.cached_layer_admissions[index].identity_key !=
        protected_identity_key {
        ignore(self.cached_layer_admissions.remove(index))
        removed = true
      } else {
        index = index + 1
      }
    }
    if !removed {
      return
    }
  }
}

///|
fn SunRasterRenderer::cached_layer_admission_skip_reason(
  self : SunRasterRenderer,
  admission : SunCachedLayerAdmissionRecord,
) -> String? {
  let _ = self
  if admission.update_streak > 2 && admission.hit_count == 0 {
    Some("churn-without-hit")
  } else {
    None
  }
}

///|
fn sun_find_cached_layer_end(
  commands : Array[@render_common.PlanOp],
  start : Int,
  key : String,
) -> Int? {
  let mut depth = 0
  for index in start..<commands.length() {
    match commands[index] {
      @render_common.PlanOp::BeginCachedLayer(_) => depth = depth + 1
      @render_common.PlanOp::EndCachedLayer(end_key) =>
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
fn SunRasterRenderer::render_cached_command_range(
  self : SunRasterRenderer,
  commands : Array[@render_common.PlanOp],
  start : Int,
  end : Int,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  opacity_stack : Array[Double],
  blend_mode_stack : Array[@sun_graphics.BlendMode],
  layer_spec_stack : Array[SunLayerScope],
  rounded_clip_transform_stack : Array[@sun_graphics.Transform],
  stats : SunCachedLayerFrameStats,
) -> Bool {
  let mut index = start
  while index < end {
    match commands[index] {
      @render_common.PlanOp::BeginCachedLayer(spec) =>
        match sun_find_cached_layer_end(commands, index + 1, spec.key) {
          Some(layer_end) => {
            if !self.render_or_draw_cached_layer(
                spec,
                commands,
                index + 1,
                layer_end,
                sun_current_opacity(opacity_stack),
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
      @render_common.PlanOp::EndCachedLayer(_) => {
        self.record_unsupported_command(
          "EndCachedLayer", "EndCachedLayer encountered without matching BeginCachedLayer",
        )
        return false
      }
      @render_common.PlanOp::DrawCachedLayer(spec) => {
        if !self.draw_cached_layer_from_cache(
            spec,
            sun_current_opacity(opacity_stack),
            stats,
          ) {
          return false
        }
        index = index + 1
      }
      command => {
        self.render_command(
          command, canvas_scopes, opacity_stack, blend_mode_stack, layer_spec_stack,
          rounded_clip_transform_stack,
        )
        index = index + 1
      }
    }
  }
  true
}

///|
fn SunRasterRenderer::render_or_draw_cached_layer(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
  commands : Array[@render_common.PlanOp],
  child_start : Int,
  child_end : Int,
  opacity : Double,
  stats : SunCachedLayerFrameStats,
) -> Bool {
  let cache_key = sun_cached_layer_cache_key(spec, self.metrics.scale_factor)
  if self.cached_layer_pixmaps.contains(cache_key) {
    let cached_rev = self.cached_layer_revisions.get(cache_key)
    let cached_scale = self.cached_layer_scales.get(cache_key)
    if cached_rev is Some(revision) &&
      revision == spec.content_revision &&
      cached_scale is Some(scale) &&
      scale == self.metrics.scale_factor {
      let pixmap = self.cached_layer_pixmaps[cache_key]
      self.draw_cached_layer_pixmap(pixmap, spec.frame, opacity)
      self.cached_layer_admission_record(cache_key).record_hit()
      self.cached_layer_hit_count = self.cached_layer_hit_count + 1
      stats.cache_hit_count = stats.cache_hit_count + 1
      return true
    }
  }
  self.update_cached_layer(
    spec, commands, child_start, child_end, opacity, stats,
  )
}

///|
fn SunRasterRenderer::update_cached_layer(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
  commands : Array[@render_common.PlanOp],
  child_start : Int,
  child_end : Int,
  opacity : Double,
  stats : SunCachedLayerFrameStats,
) -> Bool {
  guard !sun_cached_layer_is_empty(spec) else { return true }
  let physical_w = sun_cached_layer_dim(
    spec.frame.size.width,
    self.metrics.scale_factor,
  )
  let physical_h = sun_cached_layer_dim(
    spec.frame.size.height,
    self.metrics.scale_factor,
  )
  guard physical_w > 0 && physical_h > 0 else { return true }
  let layer_canvas = @sun_graphics.Canvas::new(physical_w, physical_h)
  layer_canvas.clear(@sun_graphics.Color::new(r=0, g=0, b=0, a=0))
  layer_canvas.scale(sx=self.metrics.scale_factor, sy=self.metrics.scale_factor)
  layer_canvas.translate(
    tx=0.0 - spec.frame.origin.x,
    ty=0.0 - spec.frame.origin.y,
  )
  let saved_canvas = self.canvas
  let saved_canvas_stack = self.canvas_stack
  let saved_filter_stack = self.filter_stack
  let saved_blur_radius_stack = self.blur_radius_stack
  let saved_rounded_clip_stack = self.rounded_clip_stack
  self.canvas = layer_canvas
  self.canvas_stack = []
  self.filter_stack = []
  self.blur_radius_stack = []
  self.rounded_clip_stack = []
  let child_scopes : Array[@render_common.PlanScopeKind] = []
  let child_opacity : Array[Double] = []
  let child_blend : Array[@sun_graphics.BlendMode] = []
  let child_layer_specs : Array[SunLayerScope] = []
  let child_rounded_clip_transforms : Array[@sun_graphics.Transform] = []
  let complete = self.render_cached_command_range(
    commands, child_start, child_end, child_scopes, child_opacity, child_blend, child_layer_specs,
    child_rounded_clip_transforms, stats,
  )
  if !child_scopes.is_empty() {
    for scope in child_scopes {
      self.record_unsupported_command(
        @render_common.plan_scope_push_command(scope),
        "cached layer command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
      )
    }
    while !self.canvas_stack.is_empty() {
      match self.canvas_stack.pop() {
        Some(parent) => self.canvas = parent
        None => ()
      }
    }
    self.filter_stack.clear()
    self.blur_radius_stack.clear()
    self.rounded_clip_stack.clear()
    child_rounded_clip_transforms.clear()
    while !child_blend.is_empty() {
      ignore(child_blend.pop())
    }
    while !child_layer_specs.is_empty() {
      ignore(child_layer_specs.pop())
    }
  }
  if !complete {
    self.canvas = saved_canvas
    self.canvas_stack = saved_canvas_stack
    self.filter_stack = saved_filter_stack
    self.blur_radius_stack = saved_blur_radius_stack
    self.rounded_clip_stack = saved_rounded_clip_stack
    return false
  }
  let pixmap = self.canvas.get_pixmap()
  let key = sun_cached_layer_cache_key(spec, self.metrics.scale_factor)
  let admission = self.cached_layer_admission_record(key)
  admission.record_update(spec.content_revision)
  match self.cached_layer_admission_skip_reason(admission) {
    Some(reason) => {
      admission.skip_reason = reason
      self.remove_cached_layer_entry(key)
      self.canvas = saved_canvas
      self.canvas_stack = saved_canvas_stack
      self.filter_stack = saved_filter_stack
      self.blur_radius_stack = saved_blur_radius_stack
      self.rounded_clip_stack = saved_rounded_clip_stack
      self.draw_cached_layer_pixmap(pixmap, spec.frame, opacity)
      return true
    }
    None => admission.skip_reason = ""
  }
  self.cached_layer_pixmaps[key] = pixmap
  self.cached_layer_revisions[key] = spec.content_revision
  self.cached_layer_scales[key] = self.metrics.scale_factor
  self.remove_cached_layer_order_entries(key)
  self.cached_layer_order.push(key)
  let evicted = self.evict_cached_layers_if_needed()
  stats.cache_evict_count = stats.cache_evict_count + evicted
  self.cached_layer_evict_count = self.cached_layer_evict_count + evicted
  stats.cache_update_count = stats.cache_update_count + 1
  self.cached_layer_update_count = self.cached_layer_update_count + 1
  self.canvas = saved_canvas
  self.canvas_stack = saved_canvas_stack
  self.filter_stack = saved_filter_stack
  self.blur_radius_stack = saved_blur_radius_stack
  self.rounded_clip_stack = saved_rounded_clip_stack
  self.draw_cached_layer_pixmap(pixmap, spec.frame, opacity)
  self.cached_layer_miss_count = self.cached_layer_miss_count + 1
  true
}

///|
fn SunRasterRenderer::draw_cached_layer_from_cache(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
  opacity : Double,
  stats : SunCachedLayerFrameStats,
) -> Bool {
  guard !sun_cached_layer_is_empty(spec) else { return true }
  let key = sun_cached_layer_cache_key(spec, self.metrics.scale_factor)
  if self.cached_layer_pixmaps.contains(key) {
    let cached_rev = self.cached_layer_revisions.get(key)
    let cached_scale = self.cached_layer_scales.get(key)
    if cached_rev is Some(revision) &&
      revision == spec.content_revision &&
      cached_scale is Some(scale) &&
      scale == self.metrics.scale_factor {
      let pixmap = self.cached_layer_pixmaps[key]
      self.draw_cached_layer_pixmap(pixmap, spec.frame, opacity)
      self.cached_layer_admission_record(key).record_hit()
      self.cached_layer_hit_count = self.cached_layer_hit_count + 1
      stats.cache_hit_count = stats.cache_hit_count + 1
      return true
    }
  }
  self.record_unsupported_command(
    "DrawCachedLayer",
    "cached layer \{spec.key} not found in cache or revision/scale mismatch",
  )
  stats.record_missing(spec.key)
  false
}

///|
fn SunRasterRenderer::draw_cached_layer_pixmap(
  self : SunRasterRenderer,
  pixmap : @sun_graphics.Pixmap,
  frame : @core.Rect,
  opacity : Double,
) -> Unit {
  let src_rect = @sun_graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  self.canvas.draw_transformed_quality_pixmap_rect(
    pixmap,
    src_rect,
    frame.origin.x,
    frame.origin.y,
    frame.size.width,
    frame.size.height,
    @sun_graphics.Paint::new().set_opacity(opacity),
    @sun_graphics.ImageQuality::Balanced,
  )
}

///|
fn SunRasterRenderer::evict_cached_layers_if_needed(
  self : SunRasterRenderer,
) -> Int {
  let mut evicted = 0
  while self.cached_layer_order.length() > sun_cached_layer_max_entries {
    if self.cached_layer_order.length() > 0 {
      let old_key = self.cached_layer_order[0]
      ignore(self.cached_layer_order.remove(0))
      ignore(self.cached_layer_pixmaps.remove(old_key))
      ignore(self.cached_layer_revisions.remove(old_key))
      ignore(self.cached_layer_scales.remove(old_key))
      evicted = evicted + 1
    } else {
      break
    }
  }
  evicted
}

///|
fn SunRasterRenderer::remove_cached_layer_entry(
  self : SunRasterRenderer,
  key : String,
) -> Unit {
  self.remove_cached_layer_order_entries(key)
  ignore(self.cached_layer_pixmaps.remove(key))
  ignore(self.cached_layer_revisions.remove(key))
  ignore(self.cached_layer_scales.remove(key))
}

///|
fn SunRasterRenderer::remove_cached_layer_order_entries(
  self : SunRasterRenderer,
  key : String,
) -> Unit {
  let mut index = 0
  while index < self.cached_layer_order.length() {
    if self.cached_layer_order[index] == key {
      ignore(self.cached_layer_order.remove(index))
    } else {
      index = index + 1
    }
  }
}

///|
fn SunRasterRenderer::clear_cached_layers(self : SunRasterRenderer) -> Unit {
  self.cached_layer_pixmaps = Map([])
  self.cached_layer_revisions = Map([])
  self.cached_layer_scales = Map([])
  self.cached_layer_order = []
  self.cached_layer_hit_count = 0
  self.cached_layer_miss_count = 0
  self.cached_layer_update_count = 0
  self.cached_layer_evict_count = 0
  self.cached_layer_admissions.clear()
}

///|
fn copy_sun_cached_layer_keys(keys : Array[String]) -> Array[String] {
  let copied = []
  for key in keys {
    copied.push(key)
  }
  copied
}

///|
fn sun_cached_layer_cache_key(
  spec : @core.CachedLayerSpec,
  scale : Double,
) -> String {
  let physical_w = sun_cached_layer_dim(spec.frame.size.width, scale)
  let physical_h = sun_cached_layer_dim(spec.frame.size.height, scale)
  "\{spec.key}|scale=\{scale}|pw=\{physical_w}|ph=\{physical_h}"
}

///|
fn sun_cached_layer_is_empty(spec : @core.CachedLayerSpec) -> Bool {
  spec.frame.size.width <= 0.0 || spec.frame.size.height <= 0.0
}

///|
fn sun_cached_layer_dim(value : Double, scale : Double) -> Int {
  (value * scale).ceil().max(1.0).to_int()
}
