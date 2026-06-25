///|
let sun_cached_layer_max_entries : Int = 32

///|
fn sun_find_cached_layer_end(
  commands : Array[@core.DrawCommand],
  start : Int,
  key : String,
) -> Int? {
  let mut depth = 0
  for index in start..<commands.length() {
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
fn SunRasterRenderer::render_cached_command_range(
  self : SunRasterRenderer,
  commands : Array[@core.DrawCommand],
  start : Int,
  end : Int,
  canvas_scopes : Array[SunCanvasScopeKind],
  opacity_stack : Array[Double],
  blend_mode_stack : Array[@sun_graphics.BlendMode],
) -> Unit {
  let mut index = start
  while index < end {
    match commands[index] {
      @core.DrawCommand::BeginCachedLayer(spec) =>
        match sun_find_cached_layer_end(commands, index + 1, spec.key) {
          Some(layer_end) => {
           self.render_or_draw_cached_layer(
             spec,
             commands,
              index + 1,
              layer_end,
            )
            index = layer_end + 1
          }
          None => {
            self.record_unsupported_command(
              "BeginCachedLayer",
              "cached layer command stream ended without matching EndCachedLayer for \{spec.key}",
            )
            index = index + 1
          }
        }
      @core.DrawCommand::EndCachedLayer(_) => {
        self.record_unsupported_command(
          "EndCachedLayer",
          "EndCachedLayer encountered without matching BeginCachedLayer",
        )
        index = index + 1
      }
      @core.DrawCommand::DrawCachedLayer(spec) => {
        self.draw_cached_layer_from_cache(spec)
        index = index + 1
      }
      command => {
        self.render_command(command, canvas_scopes, opacity_stack, blend_mode_stack)
        index = index + 1
      }
    }
  }
}

///|
fn SunRasterRenderer::render_or_draw_cached_layer(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
  commands : Array[@core.DrawCommand],
  child_start : Int,
  child_end : Int,
) -> Unit {
  let cache_key = spec.key
  if self.cached_layer_pixmaps.contains(cache_key) {
    let cached_rev = self.cached_layer_revisions.get(cache_key)
    let cached_scale = self.cached_layer_scales.get(cache_key)
    if cached_rev is Some(revision) &&
      revision == spec.content_revision &&
      cached_scale is Some(scale) &&
      scale == self.metrics.scale_factor {
      let pixmap = self.cached_layer_pixmaps[cache_key]
      self.draw_cached_layer_pixmap(pixmap, spec.frame)
      self.cached_layer_hit_count = self.cached_layer_hit_count + 1
      return
    }
  }
  self.update_cached_layer(spec, commands, child_start, child_end)
}

///|
fn SunRasterRenderer::update_cached_layer(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
  commands : Array[@core.DrawCommand],
  child_start : Int,
  child_end : Int,
) -> Unit {
  let physical_w = sun_cached_layer_dim(spec.frame.size.width, self.metrics.scale_factor)
  let physical_h = sun_cached_layer_dim(spec.frame.size.height, self.metrics.scale_factor)
  guard physical_w > 0 && physical_h > 0 else { return }
  let layer_canvas = @sun_graphics.Canvas::new(physical_w, physical_h)
  layer_canvas.clear(@sun_graphics.Color::new(r=0, g=0, b=0, a=0))
  layer_canvas.scale(sx=self.metrics.scale_factor, sy=self.metrics.scale_factor)
  layer_canvas.translate(tx=0.0 - spec.frame.origin.x, ty=0.0 - spec.frame.origin.y)
  let saved_canvas = self.canvas
  let saved_canvas_stack = self.canvas_stack
  let saved_filter_stack = self.filter_stack
  self.canvas = layer_canvas
  self.canvas_stack = []
  self.filter_stack = []
  let child_scopes : Array[SunCanvasScopeKind] = []
  let child_opacity : Array[Double] = []
  let child_blend : Array[@sun_graphics.BlendMode] = []
  self.render_cached_command_range(
    commands,
    child_start,
    child_end,
    child_scopes,
    child_opacity,
    child_blend,
  )
  if !child_scopes.is_empty() {
    for scope in child_scopes {
      self.record_unsupported_command(
        sun_scope_push_command(scope),
        "cached layer command stream ended with an open \{sun_scope_name(scope)} scope",
      )
    }
    while !self.canvas_stack.is_empty() {
      match self.canvas_stack.pop() {
        Some(parent) => self.canvas = parent
        None => ()
      }
    }
    self.filter_stack.clear()
  }
  let pixmap = self.canvas.get_pixmap()
  self.cached_layer_pixmaps[cache_key(spec.key)] = pixmap
  self.cached_layer_revisions[cache_key(spec.key)] = spec.content_revision
  self.cached_layer_scales[cache_key(spec.key)] = self.metrics.scale_factor
  self.cached_layer_order.push(cache_key(spec.key))
  self.evict_cached_layers_if_needed()
  self.canvas = saved_canvas
  self.canvas_stack = saved_canvas_stack
  self.filter_stack = saved_filter_stack
  self.draw_cached_layer_pixmap(pixmap, spec.frame)
  self.cached_layer_miss_count = self.cached_layer_miss_count + 1
}

///|
fn SunRasterRenderer::draw_cached_layer_from_cache(
  self : SunRasterRenderer,
  spec : @core.CachedLayerSpec,
) -> Unit {
  let key = cache_key(spec.key)
  if self.cached_layer_pixmaps.contains(key) {
    let cached_rev = self.cached_layer_revisions.get(key)
    let cached_scale = self.cached_layer_scales.get(key)
    if cached_rev is Some(revision) &&
      revision == spec.content_revision &&
      cached_scale is Some(scale) &&
      scale == self.metrics.scale_factor {
      let pixmap = self.cached_layer_pixmaps[key]
      self.draw_cached_layer_pixmap(pixmap, spec.frame)
      self.cached_layer_hit_count = self.cached_layer_hit_count + 1
      return
    }
  }
  self.record_unsupported_command(
    "DrawCachedLayer",
    "cached layer \{spec.key} not found in cache or revision/scale mismatch",
  )
}

///|
fn SunRasterRenderer::draw_cached_layer_pixmap(
  self : SunRasterRenderer,
  pixmap : @sun_graphics.Pixmap,
  frame : @core.Rect,
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
    @sun_graphics.Paint::new(),
    @sun_graphics.ImageQuality::Balanced,
  )
}

///|
fn SunRasterRenderer::evict_cached_layers_if_needed(
  self : SunRasterRenderer,
) -> Unit {
  while self.cached_layer_order.length() > sun_cached_layer_max_entries {
    if self.cached_layer_order.length() > 0 {
      let old_key = self.cached_layer_order[0]
      ignore(self.cached_layer_order.remove(0))
      ignore(self.cached_layer_pixmaps.remove(old_key))
      ignore(self.cached_layer_revisions.remove(old_key))
      ignore(self.cached_layer_scales.remove(old_key))
    } else {
      break
    }
  }
}

///|
fn SunRasterRenderer::clear_cached_layers(
  self : SunRasterRenderer,
) -> Unit {
  self.cached_layer_pixmaps = {}
  self.cached_layer_revisions = {}
  self.cached_layer_scales = {}
  self.cached_layer_order = []
  self.cached_layer_hit_count = 0
  self.cached_layer_miss_count = 0
}

///|
fn cache_key(key : String) -> String {
  key
}

///|
fn sun_cached_layer_dim(value : Double, scale : Double) -> Int {
  (value * scale).ceil().max(1.0).to_int()
}
