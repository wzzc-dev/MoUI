///|
priv struct LayerCommandCacheEntry {
  key : String
  commands : Array[@core.DrawCommand]
  mut last_used : Int
  bytes : Int
}

///|
priv struct LayerCommandCache {
  entries : Array[LayerCommandCacheEntry]
  mut tick : Int
  budget_bytes : Int
}

///|
priv struct LayerCommandExpansion {
  commands : Array[@core.DrawCommand]
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  missing_layer_keys : Array[String]
}

///|
priv struct LayerCommandCapture {
  spec : @core.CachedLayerSpec
  commands : Array[@core.DrawCommand]
}

///|
pub fn window_renderer_with_cached_layer_fallback(
  resize~ : (@core.SurfaceMetrics) -> Unit,
  render~ : (Array[@core.DrawCommand]) -> Unit,
  drain_present_completions? : (() -> Array[@render.RenderPresentCompletion])? = None,
  text_system~ : () -> @core.TextSystem,
  present_count? : () -> Int = () => 0,
  dispose? : () -> Unit = () => (),
  image? : @render.HostRendererImageCapability = @render.HostRendererImageCapability::new(),
  platform_view? : @render.HostRendererPlatformViewCapability = @render.HostRendererPlatformViewCapability::new(),
  gpu_recovery? : @render.HostRendererGpuRecoveryCapability = @render.HostRendererGpuRecoveryCapability::new(),
) -> @render.WindowRenderer {
  let cache = LayerCommandCache::new()
  let drain = match drain_present_completions {
    Some(drain) => drain
    None => () => []
  }
  @render.WindowRenderer::new(
    resize~,
    render~,
    render_frame=Some(frame => {
      let expanded = cache.expand_frame_commands(frame.commands)
      let commands : Array[@core.DrawCommand] = [
        @core.DrawCommand::Clear(frame.clear_color),
      ]
      commands.append(expanded.commands)
      render(commands)
      @render.RenderFrameResult::new(
        cache_hit_count=expanded.cache_hit_count,
        cache_miss_count=expanded.cache_miss_count,
        cache_update_count=expanded.cache_update_count,
        cache_evict_count=expanded.cache_evict_count,
        missing_layer_keys=expanded.missing_layer_keys,
      )
    }),
    drain_present_completions=Some(drain),
    text_system~,
    present_count~,
    dispose=() => {
      cache.clear()
      dispose()
    },
    image~,
    platform_view~,
    gpu_recovery~,
  )
}

///|
fn LayerCommandCache::new() -> LayerCommandCache {
  { entries: [], tick: 0, budget_bytes: 64 * 1024 * 1024 }
}

///|
fn LayerCommandCache::clear(self : LayerCommandCache) -> Unit {
  self.entries.clear()
}

///|
fn LayerCommandCache::expand_frame_commands(
  self : LayerCommandCache,
  commands : Array[@core.DrawCommand],
) -> LayerCommandExpansion {
  self.tick = self.tick + 1
  let output : Array[@core.DrawCommand] = []
  let captures : Array[LayerCommandCapture] = []
  let missing : Array[String] = []
  let mut hits = 0
  let mut misses = 0
  let mut updates = 0
  for command in commands {
    match command {
      @core.DrawCommand::BeginCachedLayer(spec) => {
        let layer = @core.DrawCommand::PushLayer(
          @core.LayerSpec::new(
            mask=@core.LayerMask::RectMask(spec.frame),
            offscreen=true,
          ),
        )
        append_layer_cache_command(output, captures, layer)
        captures.push({ spec, commands: [layer] })
      }
      @core.DrawCommand::EndCachedLayer(key) => {
        append_layer_cache_command(
          output,
          captures,
          @core.DrawCommand::PopLayer,
        )
        match captures.pop() {
          Some(capture) =>
            if capture.spec.key == key {
              self.store(capture.spec.key, capture.commands)
              updates = updates + 1
            }
          None => ()
        }
      }
      @core.DrawCommand::DrawCachedLayer(spec) =>
        match self.lookup(spec.key) {
          Some(cached) => {
            hits = hits + 1
            for cached_command in cached {
              append_layer_cache_command(output, captures, cached_command)
            }
          }
          None => {
            misses = misses + 1
            missing.push(spec.key)
          }
        }
      _ => append_layer_cache_command(output, captures, command)
    }
  }
  {
    commands: output,
    cache_hit_count: hits,
    cache_miss_count: misses,
    cache_update_count: updates,
    cache_evict_count: self.evict_if_needed(),
    missing_layer_keys: missing,
  }
}

///|
fn append_layer_cache_command(
  output : Array[@core.DrawCommand],
  captures : Array[LayerCommandCapture],
  command : @core.DrawCommand,
) -> Unit {
  output.push(command)
  for capture in captures {
    capture.commands.push(command)
  }
}

///|
fn LayerCommandCache::lookup(
  self : LayerCommandCache,
  key : String,
) -> Array[@core.DrawCommand]? {
  for entry in self.entries {
    if entry.key == key {
      entry.last_used = self.tick
      return Some(entry.commands)
    }
  }
  None
}

///|
fn LayerCommandCache::store(
  self : LayerCommandCache,
  key : String,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.commands.clear()
      entry.commands.append(commands)
      entry.last_used = self.tick
      return
    }
  }
  self.entries.push({
    key,
    commands,
    last_used: self.tick,
    bytes: commands.length() * 256,
  })
}

///|
fn LayerCommandCache::evict_if_needed(self : LayerCommandCache) -> Int {
  let mut bytes = 0
  for entry in self.entries {
    bytes = bytes + entry.bytes
  }
  let mut evicted = 0
  while bytes > self.budget_bytes && !self.entries.is_empty() {
    let index = self.oldest_entry_index()
    bytes = bytes - self.entries[index].bytes
    ignore(self.entries.remove(index))
    evicted = evicted + 1
  }
  evicted
}

///|
fn LayerCommandCache::oldest_entry_index(self : LayerCommandCache) -> Int {
  let mut oldest = 0
  let mut oldest_tick = self.entries[0].last_used
  for index in 1..<self.entries.length() {
    if self.entries[index].last_used < oldest_tick {
      oldest = index
      oldest_tick = self.entries[index].last_used
    }
  }
  oldest
}
