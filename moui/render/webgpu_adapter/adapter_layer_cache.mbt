///|
fn WebGpuLayerCommandCache::new() -> WebGpuLayerCommandCache {
  { entries: [], tick: 0 }
}

///|
fn WebGpuLayerCommandCache::expand_frame_commands(
  self : WebGpuLayerCommandCache,
  commands : Array[@core.DrawCommand],
) -> WebGpuLayerCommandExpansion {
  self.tick = self.tick + 1
  let output : Array[@core.DrawCommand] = []
  let captures : Array[WebGpuLayerCommandCapture] = []
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
        append_webgpu_layer_cache_command(output, captures, layer)
        captures.push({ spec, commands: [layer] })
      }
      @core.DrawCommand::EndCachedLayer(key) => {
        append_webgpu_layer_cache_command(
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
              append_webgpu_layer_cache_command(
                output, captures, cached_command,
              )
            }
          }
          None => {
            misses = misses + 1
            missing.push(spec.key)
          }
        }
      _ => append_webgpu_layer_cache_command(output, captures, command)
    }
  }
  {
    commands: output,
    cache_hit_count: hits,
    cache_miss_count: misses,
    cache_update_count: updates,
    missing_layer_keys: missing,
  }
}

///|
fn append_webgpu_layer_cache_command(
  output : Array[@core.DrawCommand],
  captures : Array[WebGpuLayerCommandCapture],
  command : @core.DrawCommand,
) -> Unit {
  output.push(command)
  for capture in captures {
    capture.commands.push(command)
  }
}

///|
fn WebGpuLayerCommandCache::lookup(
  self : WebGpuLayerCommandCache,
  key : String,
) -> Array[@core.DrawCommand]? {
  for entry in self.entries {
    if entry.key == key {
      return Some(entry.commands)
    }
  }
  None
}

///|
fn WebGpuLayerCommandCache::store(
  self : WebGpuLayerCommandCache,
  key : String,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.commands.clear()
      entry.commands.append(commands)
      return ()
    }
  }
  self.entries.push({ key, commands })
}
