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
                spec, physical_size,
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
        (
          entry.byte_size == candidate_bytes &&
          entry_last_used < candidate_last_used
        ) {
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
