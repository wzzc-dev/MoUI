///|
/// Structural identity of a retained-layer cache slot: everything that
/// describes *which* raster lives there, except the content revision. The
/// origin is deliberately absent — layer pixels are recorded in layer-local
/// coordinates, so moving a same-size layer keeps its identity and stays a
/// cache hit. Replaces the former 5-segment string interpolation per lookup.
priv struct SkiaLayerIdentity {
  runtime_key : String
  route : SkiaSurfaceRoute
  scale_factor : Double
  physical_width : Int32
  physical_height : Int32
} derive(Eq, Hash)

///|
/// Structural layer-cache key (identity + content revision). Hashed directly
/// by the cache maps, so hits and misses no longer allocate an interpolated
/// string per lookup.
priv struct SkiaLayerCacheKey {
  identity : SkiaLayerIdentity
  content_revision : Int32
} derive(Eq, Hash)

///|
priv struct SkiaCachedLayerImageEntry {
  identity : SkiaLayerIdentity
  key : SkiaLayerCacheKey
  image : @skia_native.Image
  physical_size : @moui_skia.ISize
  byte_size : Int64
  update_streak : Int32
  mut hit_count : Int32
  skip_reason : String
  last_admitted_frame : Int32
  mut last_used : Int32
  /// Image sources whose runs were rasterized into this entry, recorded at
  /// admission time from the layer's command range. Image load completions
  /// use this to invalidate only the layers that actually drew the source.
  image_sources : Array[String]
}

///|
priv struct SkiaCachedLayerAdmissionRecord {
  identity : SkiaLayerIdentity
  mut update_streak : Int32
  mut hit_count : Int32
  mut skip_reason : String
  mut last_admitted_frame : Int32
  mut last_revision : Int32
}

///|
priv struct SkiaCachedLayerFrameStats {
  mut cache_hit_count : Int32
  mut cache_miss_count : Int32
  mut cache_update_count : Int32
  mut cache_evict_count : Int32
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
/// Reset in place: the renderer owns one stats record for its lifetime and
/// draw_frame_to_canvas resets it per frame instead of allocating a new one.
fn SkiaCachedLayerFrameStats::reset(self : SkiaCachedLayerFrameStats) -> Unit {
  self.cache_hit_count = 0
  self.cache_miss_count = 0
  self.cache_update_count = 0
  self.cache_evict_count = 0
}

///|
/// Frame result assembly merges the retained-layer cache counters with the
/// session shaping cache delta recorded since the frame began (ADR 0034
/// batch: shaping hits are visible through the existing protocol fields).
fn SkiaRasterRenderer::render_frame_result(
  self : SkiaRasterRenderer,
  stats : SkiaCachedLayerFrameStats,
  presented~ : Bool,
) -> @render.RenderFrameResult {
  let (shaping_hits, shaping_misses) = self.text_shaping_cache.frame_delta()
  @render.RenderFrameResult::new(
    presented~,
    cache_hit_count=stats.cache_hit_count + shaping_hits,
    cache_miss_count=stats.cache_miss_count + shaping_misses,
    cache_update_count=stats.cache_update_count,
    cache_evict_count=stats.cache_evict_count,
  )
}

///|
fn SkiaRasterRenderer::render_cached_command_range(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  commands : Array[@core.DrawCommand],
  start_index~ : Int32,
  end_index~ : Int32,
  canvas_scopes : Array[@render_common.PlanScopeKind],
  stats : SkiaCachedLayerFrameStats,
  damage~ : @core.DamageRegion = @core.DamageRegion::full(
    "offscreen layer render",
  ),
) -> Bool {
  let mut index = start_index
  while index < end_index {
    match commands[index] {
      BeginRetainedLayer(spec) =>
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
      EndRetainedLayer(_) => return true
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
    Empty => false
    FullSurface(_) => false
    Rects(rects) => {
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
  commands : Array[@core.DrawCommand],
  start_index : Int32,
  key : String,
) -> Int32? {
  let mut depth = 0
  for index in start_index..<commands.length() {
    match commands[index] {
      BeginRetainedLayer(_) => depth = depth + 1
      EndRetainedLayer(end_key) =>
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
  commands : Array[@core.DrawCommand],
  start_index~ : Int32,
  end_index~ : Int32,
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
              let identity = self.skia_layer_identity(spec, physical_size)
              let admission = self.layer_cache_admission_record(identity)
              admission.record_update(spec.content_revision)
              let entry = SkiaCachedLayerImageEntry::{
                identity,
                key: SkiaLayerCacheKey::{
                  identity,
                  content_revision: spec.content_revision,
                },
                image,
                physical_size,
                byte_size,
                update_streak: admission.update_streak,
                hit_count: admission.hit_count,
                skip_reason: admission.skip_reason,
                last_admitted_frame: admission.last_admitted_frame,
                last_used: 0,
                image_sources: skia_layer_image_sources(
                  commands, start_index, end_index,
                ),
              }
              match
                self.cached_layer_admission_skip_reason(
                  admission, byte_size, budget,
                ) {
                Some(reason) => {
                  admission.skip_reason = reason
                  self.remove_cached_layers_by_identity(entry.identity)
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
  commands : Array[@core.DrawCommand],
  start_index~ : Int32,
  end_index~ : Int32,
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  let saved = canvas.save_count()
  self.push_layer(
    canvas,
    @core.LayerSpec::new(mask=RectMask(spec.frame), offscreen=true),
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
      // The structural key already covers runtime key, route, scale factor,
      // physical size, and content revision, so no per-field re-checks here.
      entry.last_used = self.next_layer_cache_tick()
      entry.hit_count = entry.hit_count + 1
      let admission = self.layer_cache_admission_record(entry.identity)
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
    skia_anti_alias_paint,
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
fn SkiaRasterRenderer::skia_layer_identity(
  self : SkiaRasterRenderer,
  spec : @core.RetainedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> SkiaLayerIdentity {
  {
    runtime_key: spec.key,
    route: self.surface_route,
    scale_factor: self.metrics.scale_factor,
    physical_width: physical_size.width,
    physical_height: physical_size.height,
  }
}

///|
fn SkiaRasterRenderer::skia_layer_cache_key(
  self : SkiaRasterRenderer,
  spec : @core.RetainedLayerSpec,
  physical_size : @moui_skia.ISize,
) -> SkiaLayerCacheKey {
  {
    identity: self.skia_layer_identity(spec, physical_size),
    content_revision: spec.content_revision,
  }
}

///|
/// Image sources whose `DrawImage` runs appear in the command range
/// `[start_index, end_index)`. Retained layers rasterize those runs into the
/// cached image, so a load completion for any of them must rebuild the layer
/// (targeted invalidation — the record is taken once per layer update, never
/// per frame). Nested retained layers are covered: their commands sit inside
/// the outer range and their pixels end up in the outer raster too.
fn skia_layer_image_sources(
  commands : Array[@core.DrawCommand],
  start_index : Int32,
  end_index : Int32,
) -> Array[String] {
  let sources : Array[String] = []
  let mut index = start_index
  while index < end_index {
    match commands[index] {
      DrawImage(run) =>
        if !sources.contains(run.source) {
          sources.push(run.source)
        }
      _ => ()
    }
    index = index + 1
  }
  sources
}

///|
/// Image load completion invalidates only the cached layers whose recorded
/// command stream draws the completed source. Chrome layers (no image runs)
/// survive, so a gallery completing several images back-to-back no longer
/// drops every retained layer. Entry removal keeps both index invariants:
/// `layer_cache_identity_index` entries are dropped together with their cache
/// entry, and the O(1) byte accumulators are decremented per removal.
fn SkiaRasterRenderer::invalidate_cached_layers_for_image_source(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  let stale_image_keys : Array[SkiaLayerCacheKey] = []
  for key, entry in self.layer_cache {
    if entry.image_sources.contains(source) {
      stale_image_keys.push(key)
    }
  }
  for key in stale_image_keys {
    match self.layer_cache.get(key) {
      Some(entry) => {
        self.layer_cache_total_bytes -= entry.byte_size
        self.layer_cache.remove(key)
        if self.layer_cache_identity_index.get(entry.identity) == Some(key) {
          self.layer_cache_identity_index.remove(entry.identity)
        }
      }
      None => ()
    }
  }
  let stale_picture_keys : Array[SkiaLayerCacheKey] = []
  for key, entry in self.picture_layer_cache {
    if entry.image_sources.contains(source) {
      stale_picture_keys.push(key)
    }
  }
  for key in stale_picture_keys {
    match self.picture_layer_cache.get(key) {
      Some(entry) => {
        self.picture_layer_cache_total_bytes -= entry.byte_size
        self.picture_layer_cache.remove(key)
        let indexed = self.picture_layer_cache_identity_index.get(
          entry.identity,
        )
        if indexed == Some(key) {
          self.picture_layer_cache_identity_index.remove(entry.identity)
        }
      }
      None => ()
    }
  }
}

///|
fn SkiaRasterRenderer::layer_cache_admission_record(
  self : SkiaRasterRenderer,
  identity : SkiaLayerIdentity,
) -> SkiaCachedLayerAdmissionRecord {
  match self.layer_cache_admissions.get(identity) {
    Some(record) => record
    None => {
      let record = SkiaCachedLayerAdmissionRecord::{
        identity,
        update_streak: 0,
        hit_count: 0,
        skip_reason: "",
        last_admitted_frame: 0,
        last_revision: -1,
      }
      self.layer_cache_admissions[identity] = record
      self.prune_layer_cache_admission_records(identity)
      record
    }
  }
}

///|
fn skia_layer_cache_admission_limit() -> Int32 {
  512
}

///|
fn SkiaRasterRenderer::prune_layer_cache_admission_records(
  self : SkiaRasterRenderer,
  protected_identity : SkiaLayerIdentity,
) -> Unit {
  while self.layer_cache_admissions.length() >
        skia_layer_cache_admission_limit() {
    match self.layer_cache_admission_eviction_key(protected_identity) {
      Some(key) => self.layer_cache_admissions.remove(key)
      None => return
    }
  }
}

///|
fn SkiaRasterRenderer::layer_cache_admission_eviction_key(
  self : SkiaRasterRenderer,
  protected_identity : SkiaLayerIdentity,
) -> SkiaLayerIdentity? {
  let mut candidate_identity : SkiaLayerIdentity? = None
  let mut candidate_live = true
  let mut candidate_tick = 0
  for identity, record in self.layer_cache_admissions {
    if identity == protected_identity {
      continue
    }
    let live = self.layer_cache_has_identity(record.identity)
    let tick = record.last_admitted_frame
    match candidate_identity {
      None => {
        candidate_identity = Some(identity)
        candidate_live = live
        candidate_tick = tick
      }
      Some(_) =>
        if (candidate_live && !live) ||
          (candidate_live == live && tick < candidate_tick) {
          candidate_identity = Some(identity)
          candidate_live = live
          candidate_tick = tick
        }
    }
  }
  candidate_identity
}

///|
fn SkiaRasterRenderer::layer_cache_has_identity(
  self : SkiaRasterRenderer,
  identity : SkiaLayerIdentity,
) -> Bool {
  self.layer_cache_identity_index.get(identity) is Some(_) ||
  self.picture_layer_cache_identity_index.get(identity) is Some(_)
}

///|
fn SkiaCachedLayerAdmissionRecord::record_update(
  self : SkiaCachedLayerAdmissionRecord,
  revision : Int32,
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
  key : SkiaLayerCacheKey,
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
  self.layer_cache_identity_index[entry.identity] = entry.key
  self.layer_cache_total_bytes += new_entry.byte_size
  true
}

///|
fn SkiaRasterRenderer::remove_stale_cached_layers_for_entry(
  self : SkiaRasterRenderer,
  entry : SkiaCachedLayerImageEntry,
) -> Unit {
  match self.layer_cache_identity_index.get(entry.identity) {
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
  identity : SkiaLayerIdentity,
) -> Unit {
  match self.layer_cache_identity_index.get(identity) {
    Some(key) => {
      match self.layer_cache.get(key) {
        Some(entry) => self.layer_cache_total_bytes -= entry.byte_size
        None => ()
      }
      self.layer_cache.remove(key)
      self.layer_cache_identity_index.remove(identity)
    }
    None => ()
  }
}

///|
fn SkiaRasterRenderer::evict_cached_layers_if_needed(
  self : SkiaRasterRenderer,
) -> Int32 {
  let budget = self.layer_cache_budget_bytes()
  let mut evicted = 0
  while budget > 0L &&
        self.layer_cache_byte_size() > budget &&
        self.layer_cache.length() > 0 {
    let (key, entry) = self.cached_layer_eviction_entry(budget)
    self.layer_cache_total_bytes -= entry.byte_size
    self.layer_cache.remove(key)
    self.layer_cache_identity_index.remove(entry.identity)
    evicted = evicted + 1
  }
  evicted
}

///|
fn SkiaRasterRenderer::cached_layer_eviction_entry(
  self : SkiaRasterRenderer,
  budget : Int64,
) -> (SkiaLayerCacheKey, SkiaCachedLayerImageEntry) {
  let mut candidate_key : SkiaLayerCacheKey? = None
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
) -> (SkiaLayerCacheKey, SkiaCachedLayerImageEntry) {
  let mut oldest_key : SkiaLayerCacheKey? = None
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
fn SkiaRasterRenderer::next_layer_cache_tick(
  self : SkiaRasterRenderer,
) -> Int32 {
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
