///|
priv struct SkiaCachedLayerPictureEntry {
  identity_key : String
  key : String
  runtime_key : String
  picture : @skia_native.Picture
  scale_factor : Double
  content_revision : Int
  byte_size : Int64
  mut hit_count : Int
  mut last_used : Int
}

///|
fn SkiaRasterRenderer::draw_frame_to_picture_canvas(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  frame : @core.DrawFrame,
) -> Bool {
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
  let scopes : Array[SkiaCanvasScopeKind] = []
  let stats = SkiaCachedLayerFrameStats::new()
  let complete = self.render_picture_command_range(
    canvas,
    frame.commands,
    start_index=0,
    end_index=frame.commands.length(),
    scopes,
    stats,
  )
  if !scopes.is_empty() {
    for scope in scopes {
      self.record_unsupported_command(
        skia_scope_push_command(scope),
        "picture command stream ended with an open \{skia_scope_name(scope)} scope",
      )
    }
  }
  canvas.restore_to_count(saved)
  complete
}

///|
fn SkiaRasterRenderer::render_picture_command_range(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  commands : Array[@core.DrawCommand],
  start_index~ : Int,
  end_index~ : Int,
  scopes : Array[SkiaCanvasScopeKind],
  stats : SkiaCachedLayerFrameStats,
) -> Bool {
  let mut index = start_index
  while index < end_index {
    match commands[index] {
      @core.DrawCommand::BeginCachedLayer(spec) =>
        match find_cached_layer_end(commands, index + 1, spec.key) {
          Some(layer_end) => {
            if !self.update_picture_cached_layer(
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
              "picture cache command stream ended without matching EndCachedLayer for \{spec.key}",
            )
            return false
          }
        }
      @core.DrawCommand::EndCachedLayer(_) => return true
      @core.DrawCommand::DrawCachedLayer(spec) => {
        if !self.draw_picture_cached_layer(canvas, spec, stats) {
          return false
        }
        index = index + 1
      }
      command => {
        self.render_command(canvas, command, scopes)
        index = index + 1
      }
    }
  }
  true
}

///|
fn SkiaRasterRenderer::update_picture_cached_layer(
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
  let budget = self.layer_cache_budget_bytes()
  let estimated_bytes = skia_cached_layer_byte_size(physical_size)
  if budget > 0L && estimated_bytes > budget {
    return self.render_uncached_picture_layer(
      canvas,
      spec,
      commands,
      start_index~,
      end_index~,
      stats,
    )
  }
  match @skia_native.PictureRecorder::new() {
    None =>
      self.render_uncached_picture_layer(
        canvas,
        spec,
        commands,
        start_index~,
        end_index~,
        stats,
      )
    Some(recorder) => {
      let width = spec.frame.size.width.ceil().max(1.0).to_int()
      let height = spec.frame.size.height.ceil().max(1.0).to_int()
      match recorder.begin(width, height) {
        None =>
          self.render_uncached_picture_layer(
            canvas,
            spec,
            commands,
            start_index~,
            end_index~,
            stats,
          )
        Some(layer_canvas) => {
          let saved = layer_canvas.save()
          layer_canvas.translate(
            @moui_skia.Point::new(
              Float::from_double(0.0 - spec.frame.origin.x),
              Float::from_double(0.0 - spec.frame.origin.y),
            ),
          )
          let layer_scopes : Array[SkiaCanvasScopeKind] = []
          let complete = self.render_picture_command_range(
            layer_canvas,
            commands,
            start_index~,
            end_index~,
            layer_scopes,
            stats,
          )
          layer_canvas.restore_to_count(saved)
          if !complete || !layer_scopes.is_empty() {
            return false
          }
          match recorder.finish() {
            None => false
            Some(picture) => {
              let identity_key = self.skia_layer_cache_identity_key(
                spec, physical_size,
              )
              let key = self.skia_layer_cache_key(spec, physical_size)
              let admission = self.layer_cache_admission_record(identity_key)
              admission.record_update(spec.content_revision)
              let byte_size = picture.approximate_bytes_used().max(1L)
              match
                self.cached_layer_admission_skip_reason(
                  admission, byte_size, budget,
                ) {
                Some(reason) => {
                  admission.skip_reason = reason
                  self.remove_picture_cached_layers_by_identity(identity_key)
                }
                None => {
                  admission.skip_reason = ""
                  self.store_picture_cached_layer({
                    identity_key,
                    key,
                    runtime_key: spec.key,
                    picture,
                    scale_factor: self.metrics.scale_factor,
                    content_revision: spec.content_revision,
                    byte_size,
                    hit_count: admission.hit_count,
                    last_used: 0,
                  })
                  stats.cache_update_count = stats.cache_update_count + 1
                  stats.cache_evict_count += self.evict_picture_cached_layers_if_needed()
                }
              }
              self.draw_picture_at_frame(canvas, picture, spec.frame)
              true
            }
          }
        }
      }
    }
  }
}

///|
fn SkiaRasterRenderer::render_uncached_picture_layer(
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
  let scopes : Array[SkiaCanvasScopeKind] = []
  let complete = self.render_picture_command_range(
    canvas,
    commands,
    start_index~,
    end_index~,
    scopes,
    stats,
  )
  canvas.restore_to_count(saved)
  complete && scopes.is_empty()
}

///|
fn SkiaRasterRenderer::draw_picture_cached_layer(
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
  match self.picture_layer_cache.get(key) {
    None => {
      stats.record_missing(spec.key)
      false
    }
    Some(entry) => {
      if entry.runtime_key != spec.key ||
        entry.scale_factor != self.metrics.scale_factor ||
        entry.content_revision != spec.content_revision {
        stats.record_missing(spec.key)
        return false
      }
      entry.last_used = self.next_layer_cache_tick()
      entry.hit_count = entry.hit_count + 1
      let admission = self.layer_cache_admission_record(entry.identity_key)
      admission.hit_count = admission.hit_count + 1
      stats.cache_hit_count = stats.cache_hit_count + 1
      self.draw_picture_at_frame(canvas, entry.picture, spec.frame)
      true
    }
  }
}

///|
fn SkiaRasterRenderer::draw_picture_at_frame(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  picture : @skia_native.Picture,
  frame : @core.Rect,
) -> Unit {
  let _ = self
  let saved = canvas.save()
  canvas.translate(
    @moui_skia.Point::new(
      Float::from_double(frame.origin.x),
      Float::from_double(frame.origin.y),
    ),
  )
  canvas.draw_picture(picture)
  canvas.restore_to_count(saved)
}

///|
fn SkiaRasterRenderer::store_picture_cached_layer(
  self : SkiaRasterRenderer,
  entry : SkiaCachedLayerPictureEntry,
) -> Unit {
  self.remove_picture_cached_layers_by_identity(entry.identity_key)
  let tick = self.next_layer_cache_tick()
  let stored = { ..entry, last_used: tick }
  self.picture_layer_cache[entry.key] = stored
  self.picture_layer_cache_identity_index[entry.identity_key] = entry.key
  self.picture_layer_cache_total_bytes += entry.byte_size
}

///|
fn SkiaRasterRenderer::remove_picture_cached_layers_by_identity(
  self : SkiaRasterRenderer,
  identity_key : String,
) -> Unit {
  match self.picture_layer_cache_identity_index.get(identity_key) {
    Some(key) => {
      match self.picture_layer_cache.get(key) {
        Some(entry) => self.picture_layer_cache_total_bytes -= entry.byte_size
        None => ()
      }
      self.picture_layer_cache.remove(key)
      self.picture_layer_cache_identity_index.remove(identity_key)
    }
    None => ()
  }
}

///|
fn SkiaRasterRenderer::evict_picture_cached_layers_if_needed(
  self : SkiaRasterRenderer,
) -> Int {
  let budget = self.layer_cache_budget_bytes()
  let mut evicted = 0
  while budget >= 0L && self.picture_layer_cache_total_bytes > budget {
    let mut oldest_key : String? = None
    let mut oldest_tick = 2147483647
    for key, entry in self.picture_layer_cache {
      if entry.last_used < oldest_tick {
        oldest_tick = entry.last_used
        oldest_key = Some(key)
      }
    }
    match oldest_key {
      None => break
      Some(key) => {
        match self.picture_layer_cache.get(key) {
          Some(entry) => {
            self.picture_layer_cache_total_bytes -= entry.byte_size
            self.picture_layer_cache_identity_index.remove(entry.identity_key)
          }
          None => ()
        }
        self.picture_layer_cache.remove(key)
        evicted = evicted + 1
      }
    }
  }
  evicted
}
