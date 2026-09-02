///|
priv struct SkiaCachedLayerImageEntry {
  identity_key : String
  key : String
  runtime_key : String
  image : @skia_native.Image
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
}

///|
fn SkiaCachedLayerFrameStats::new() -> SkiaCachedLayerFrameStats {
  {
    cache_hit_count: 0,
    cache_miss_count: 0,
    cache_update_count: 0,
    cache_evict_count: 0,
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
  )
}

///|
fn SkiaRasterRenderer::render_cached_command_range(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  commands : Array[@render_common.PlanOp],
  start_index~ : Int,
  end_index~ : Int,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  stats : SkiaCachedLayerFrameStats,
  damage? : @core.DamageRegion = @core.DamageRegion::full(
    "offscreen layer render",
  ),
) -> Bool {
  let mut index = start_index
  while index < end_index {
    match commands[index] {
      @render_common.PlanOp::BeginRetainedLayer(spec) =>
        match find_cached_layer_end(commands, index + 1, spec.key) {
          Some(layer_end) =>
            if self.should_skip_command_for_damage(spec.frame, damage) ||
              self.draw_cached_layer(canvas, spec, stats) {
              index = layer_end + 1
            } else {
              stats.cache_miss_count = stats.cache_miss_count + 1
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
              "BeginRetainedLayer",
              "cached layer command stream ended without matching EndRetainedLayer for \{spec.key}",
            )
            return false
          }
        }
      @render_common.PlanOp::EndRetainedLayer(_) => return true
      command => {
        self.render_command(canvas, command, canvas_scopes)
        index = index + 1
      }
    }
  }
  true
}

///|
fn SkiaRasterRenderer::should_skip_command_for_damage(
  self : SkiaRasterRenderer,
  bounds : @core.Rect,
  damage : @core.DamageRegion,
) -> Bool {
  let _ = self
  match damage {
    @core.DamageRegion::Empty => false
    @core.DamageRegion::FullSurface(_) => false
    @core.DamageRegion::Rects(rects) => {
      let mut intersects = false
      for rect in rects {
        match bounds.intersection(rect) {
          Some(overlap) =>
            if !overlap.is_empty() {
              intersects = true
              break
            }
          None => ()
        }
      }
      !intersects
    }
  }
}

///|
fn find_cached_layer_end(
  commands : Array[@render_common.PlanOp],
  start_index : Int,
  key : String,
) -> Int? {
  let mut depth = 0
  for index in start_index..<commands.length() {
    match commands[index] {
      @render_common.PlanOp::BeginRetainedLayer(_) => depth = depth + 1
      @render_common.PlanOp::EndRetainedLayer(end_key) =>
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
  spec : @core.RetainedLayerSpec,
  commands : Array[@render_common.PlanOp],
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
      "BeginRetainedLayer",
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
          let layer_scopes : Array[@render_common.PlanScopeKind] = []
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
                @render_common.plan_scope_push_command(scope),
                "cached layer command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
              )
            }
          }
          layer_canvas.restore_to_count(saved)
          if !complete {
            return false
          }
          if !layer_surface.flush_and_submit() {
            self.record_unsupported_command(
              "BeginRetainedLayer",
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
                spec, physical_size,
              )
              let admission = self.layer_cache_admission_record(identity_key)
              admission.record_update(spec.content_revision)
              let entry = SkiaCachedLayerImageEntry::{
                identity_key,
                key: self.skia_layer_cache_key(spec, physical_size),
                runtime_key: spec.key,
                image,
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
              match
                self.cached_layer_admission_skip_reason(
                  admission, byte_size, budget,
                ) {
                Some(reason) => {
                  admission.skip_reason = reason
                  self.remove_cached_layers_by_identity(entry.identity_key)
                }
                None =>
                  if self.store_cached_layer(entry, admission) {
                    admission.skip_reason = ""
                    stats.cache_update_count = stats.cache_update_count + 1
                    stats.cache_evict_count += self.evict_cached_layers_if_needed()
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
                "BeginRetainedLayer",
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
            "BeginRetainedLayer",
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
        "BeginRetainedLayer",
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
  spec : @core.RetainedLayerSpec,
  commands : Array[@render_common.PlanOp],
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
  let layer_scopes : Array[@render_common.PlanScopeKind] = []
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
        @render_common.plan_scope_push_command(scope),
        "uncached fallback layer command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
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
  spec : @core.RetainedLayerSpec,
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
      // Cached layer pixels are recorded in layer-local coordinates; origin is
      // the draw destination, so moving a same-size layer remains a cache hit.
      if entry.runtime_key != spec.key ||
        entry.scale_factor != self.metrics.scale_factor ||
        entry.surface_route != self.surface_route ||
        entry.content_revision != spec.content_revision {
        return false
      }
      entry.last_used = self.next_layer_cache_tick()
      entry.hit_count = entry.hit_count + 1
      let identity_key = self.skia_layer_cache_identity_key(spec, physical_size)
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
    // The native GPU producer stores cached layers as immutable pictures.
    // Keep those entries usable when the same renderer falls back to raster.
    None => self.draw_picture_cached_layer(canvas, spec, stats)
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
    Direct3DGpuSurfaceRoute =>
      match self.gpu_context {
        Some(gpu_context) =>
          @skia_native.Surface::for_target_with_gpu_context(target, gpu_context)
        None => None
      }
    VulkanGpuSurfaceRoute =>
      match self.gpu_context {
        Some(gpu_context) =>
          @skia_native.Surface::for_target_with_gpu_context(target, gpu_context)
        None => None
      }
    EglGpuSurfaceRoute =>
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
  spec : @core.RetainedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> String {
  "\{spec.key}|route=\{self.surface_route.label()}|scale=\{self.metrics.scale_factor}|pw=\{physical_size.width}|ph=\{physical_size.height}|rev=\{spec.content_revision}|img=\{self.image_cache_generation}"
}

///|
fn SkiaRasterRenderer::skia_layer_cache_identity_key(
  self : SkiaRasterRenderer,
  spec : @core.RetainedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> String {
  "\{spec.key}|route=\{self.surface_route.label()}|scale=\{self.metrics.scale_factor}|pw=\{physical_size.width}|ph=\{physical_size.height}"
}

///|
fn SkiaRasterRenderer::layer_cache_admission_record(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> SkiaCachedLayerAdmissionRecord {
  match self.layer_cache_admissions.get(identity_key) {
    Some(record) => record
    None => {
      let record = SkiaCachedLayerAdmissionRecord::{
        identity_key,
        update_streak: 0,
        hit_count: 0,
        skip_reason: "",
        last_admitted_frame: 0,
        last_revision: -1,
      }
      self.layer_cache_admissions[identity_key] = record
      self.prune_layer_cache_admission_records(identity_key)
      record
    }
  }
}

///|
fn skia_layer_cache_admission_limit() -> Int {
  512
}

///|
fn SkiaRasterRenderer::prune_layer_cache_admission_records(
  self : SkiaRasterRenderer,
  protected_identity_key : String,
) -> Unit {
  while self.layer_cache_admissions.length() >
        skia_layer_cache_admission_limit() {
    match self.layer_cache_admission_eviction_key(protected_identity_key) {
      Some(key) => self.layer_cache_admissions.remove(key)
      None => return
    }
  }
}

///|
fn SkiaRasterRenderer::layer_cache_admission_eviction_key(
  self : SkiaRasterRenderer,
  protected_identity_key : String,
) -> String? {
  let mut candidate_key : String? = None
  let mut candidate_live = true
  let mut candidate_tick = 0
  for key, record in self.layer_cache_admissions {
    if key == protected_identity_key {
      continue
    }
    let live = self.layer_cache_has_identity(record.identity_key)
    let tick = record.last_admitted_frame
    match candidate_key {
      None => {
        candidate_key = Some(key)
        candidate_live = live
        candidate_tick = tick
      }
      Some(_) =>
        if (candidate_live && !live) ||
          (candidate_live == live && tick < candidate_tick) {
          candidate_key = Some(key)
          candidate_live = live
          candidate_tick = tick
        }
    }
  }
  candidate_key
}

///|
fn SkiaRasterRenderer::layer_cache_has_identity(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> Bool {
  self.layer_cache_identity_index.get(identity_key) is Some(_) ||
  self.picture_layer_cache_identity_index.get(identity_key) is Some(_)
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
  self.layer_cache.get(key)
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
  let new_entry = {
    ..entry,
    hit_count: admission.hit_count,
    skip_reason: admission.skip_reason,
    last_admitted_frame: admitted_frame,
    last_used: admitted_frame,
  }
  match self.layer_cache.get(entry.key) {
    Some(old) => self.layer_cache_total_bytes -= old.byte_size
    None => ()
  }
  self.layer_cache[entry.key] = new_entry
  self.layer_cache_identity_index[entry.identity_key] = entry.key
  self.layer_cache_total_bytes += new_entry.byte_size
  true
}

///|
fn SkiaRasterRenderer::remove_stale_cached_layers_for_entry(
  self : SkiaRasterRenderer,
  entry : SkiaCachedLayerImageEntry,
) -> Unit {
  match self.layer_cache_identity_index.get(entry.identity_key) {
    Some(old_key) =>
      if old_key != entry.key {
        match self.layer_cache.get(old_key) {
          Some(old) => self.layer_cache_total_bytes -= old.byte_size
          None => ()
        }
        self.layer_cache.remove(old_key)
      }
    None => ()
  }
}

///|
fn SkiaRasterRenderer::remove_cached_layers_by_identity(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> Unit {
  match self.layer_cache_identity_index.get(identity_key) {
    Some(key) => {
      match self.layer_cache.get(key) {
        Some(entry) => self.layer_cache_total_bytes -= entry.byte_size
        None => ()
      }
      self.layer_cache.remove(key)
      self.layer_cache_identity_index.remove(identity_key)
    }
    None => ()
  }
}

///|
fn SkiaRasterRenderer::evict_cached_layers_if_needed(
  self : SkiaRasterRenderer,
) -> Int {
  let budget = self.layer_cache_budget_bytes()
  let mut evicted = 0
  while budget > 0L &&
        self.layer_cache_byte_size() > budget &&
        self.layer_cache.length() > 0 {
    let (key, entry) = self.cached_layer_eviction_entry(budget)
    self.layer_cache_total_bytes -= entry.byte_size
    self.layer_cache.remove(key)
    self.layer_cache_identity_index.remove(entry.identity_key)
    evicted = evicted + 1
  }
  evicted
}

///|
fn SkiaRasterRenderer::cached_layer_eviction_entry(
  self : SkiaRasterRenderer,
  budget : Int64,
) -> (String, SkiaCachedLayerImageEntry) {
  let mut candidate_key : String? = None
  let mut candidate_bytes = 0L
  let mut candidate_last_used = 0
  for key, entry in self.layer_cache {
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
      match candidate_key {
        None => {
          candidate_key = Some(key)
          candidate_bytes = entry.byte_size
          candidate_last_used = entry_last_used
        }
        Some(_) =>
          if entry.byte_size > candidate_bytes ||
            (
              entry.byte_size == candidate_bytes &&
              entry_last_used < candidate_last_used
            ) {
            candidate_key = Some(key)
            candidate_bytes = entry.byte_size
            candidate_last_used = entry_last_used
          }
      }
    }
  }
  match candidate_key {
    Some(key) => (key, self.layer_cache[key])
    None => self.oldest_cached_layer_entry()
  }
}

///|
fn SkiaRasterRenderer::oldest_cached_layer_entry(
  self : SkiaRasterRenderer,
) -> (String, SkiaCachedLayerImageEntry) {
  let mut oldest_key : String? = None
  let mut oldest_tick = 0
  for key, entry in self.layer_cache {
    match oldest_key {
      None => {
        oldest_key = Some(key)
        oldest_tick = entry.last_used
      }
      Some(_) =>
        if entry.last_used < oldest_tick {
          oldest_key = Some(key)
          oldest_tick = entry.last_used
        }
    }
  }
  let key = match oldest_key {
    Some(k) => k
    None => abort("oldest_cached_layer_entry called on empty layer cache")
  }
  (key, self.layer_cache[key])
}

///|
fn SkiaRasterRenderer::layer_cache_byte_size(
  self : SkiaRasterRenderer,
) -> Int64 {
  self.layer_cache_total_bytes
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
  self.layer_cache_identity_index.clear()
  self.picture_layer_cache.clear()
  self.picture_layer_cache_identity_index.clear()
  self.layer_cache_admissions.clear()
  self.layer_cache_total_bytes = 0L
  self.picture_layer_cache_total_bytes = 0L
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
