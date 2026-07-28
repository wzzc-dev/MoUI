///|
pub struct HostRendererImageCapability {
  priv image_resources_fn : () -> Array[ImageResourceRecord]
  priv image_resource_snapshot_fn : () -> ImageResourceSnapshot
  priv apply_image_resource_load_completion_fn : (
    ImageResourceLoadCompletion,
  ) -> ImageResourceSnapshot
  priv set_image_resource_change_callback_fn : (
    ((ImageResourceSnapshot) -> Unit)?,
  ) -> Unit
}

///|
pub struct HostRendererPlatformViewCapability {
  priv draw_platform_view_pixels_fn : (
    Bytes,
    Int,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
  ) -> Unit
  priv set_platform_view_draw_fn_fn : ((() -> Unit)?) -> Unit
}

///|
pub struct HostRendererGpuRecoveryCapability {
  priv inject_context_loss_fn : () -> Unit
  priv gpu_recovery_count_fn : () -> Int
  priv gpu_fallback_active_fn : () -> Bool
}

///|
pub struct HostWindowRenderer {
  priv resize_fn : (RendererSurfaceMetrics) -> Unit
  priv render_fn : (Array[@core.DrawCommand]) -> Unit
  priv render_frame_fn : (@core.DrawFrame) -> RenderFrameResult
  priv drain_present_completions_fn : () -> Array[
    RenderPresentCompletion,
  ]
  priv text_system_fn : () -> @core.TextSystem
  priv image : HostRendererImageCapability
  priv present_count_fn : () -> Int
  priv dispose_fn : () -> Unit
  priv platform_view : HostRendererPlatformViewCapability
  priv gpu_recovery : HostRendererGpuRecoveryCapability
  priv layer_cache : HostLayerCommandCache
}

///|
pub fn HostRendererImageCapability::new(
  image_resources? : () -> Array[ImageResourceRecord] = () => [],
  image_resource_snapshot? : (() -> ImageResourceSnapshot)? = None,
  apply_image_resource_load_completion? : ((ImageResourceLoadCompletion) -> ImageResourceSnapshot)? = None,
  set_image_resource_change_callback? : (
    ((ImageResourceSnapshot) -> Unit)?,
  ) -> Unit = _callback => (),
) -> HostRendererImageCapability {
  let image_resource_snapshot = match image_resource_snapshot {
    Some(snapshot) => snapshot
    None => () => ImageResourceSnapshot::from_records(image_resources())
  }
  let apply_image_resource_load_completion = match
    apply_image_resource_load_completion {
    Some(apply) => apply
    None => _completion => image_resource_snapshot()
  }
  {
    image_resources_fn: image_resources,
    image_resource_snapshot_fn: image_resource_snapshot,
    apply_image_resource_load_completion_fn: apply_image_resource_load_completion,
    set_image_resource_change_callback_fn: set_image_resource_change_callback,
  }
}

///|
pub fn HostRendererPlatformViewCapability::new(
  draw_platform_view_pixels? : (
    Bytes,
    Int,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
  ) -> Unit = fn(_pixels, _w, _h, _s, _dx, _dy, _dw, _dh) {  },
  set_platform_view_draw_fn? : ((() -> Unit)?) -> Unit = _fn => (),
) -> HostRendererPlatformViewCapability {
  {
    draw_platform_view_pixels_fn: draw_platform_view_pixels,
    set_platform_view_draw_fn_fn: set_platform_view_draw_fn,
  }
}

///|
pub fn HostRendererGpuRecoveryCapability::new(
  inject_context_loss? : () -> Unit = () => (),
  gpu_recovery_count? : () -> Int = () => 0,
  gpu_fallback_active? : () -> Bool = () => false,
) -> HostRendererGpuRecoveryCapability {
  {
    inject_context_loss_fn: inject_context_loss,
    gpu_recovery_count_fn: gpu_recovery_count,
    gpu_fallback_active_fn: gpu_fallback_active,
  }
}

///|
priv struct HostLayerCommandCacheEntry {
  key : String
  commands : Array[@core.DrawCommand]
  mut last_used : Int
  bytes : Int
}

///|
priv struct HostLayerCommandCache {
  entries : Array[HostLayerCommandCacheEntry]
  mut tick : Int
  budget_bytes : Int
}

///|
pub fn HostWindowRenderer::new(
  resize~ : (RendererSurfaceMetrics) -> Unit,
  render~ : (Array[@core.DrawCommand]) -> Unit,
  render_frame? : ((@core.DrawFrame) -> RenderFrameResult)? = None,
  drain_present_completions? : (() -> Array[RenderPresentCompletion])? = None,
  text_system~ : () -> @core.TextSystem,
  present_count? : () -> Int = () => 0,
  dispose? : () -> Unit = () => (),
  image? : HostRendererImageCapability = HostRendererImageCapability::new(),
  platform_view? : HostRendererPlatformViewCapability = HostRendererPlatformViewCapability::new(),
  gpu_recovery? : HostRendererGpuRecoveryCapability = HostRendererGpuRecoveryCapability::new(),
) -> HostWindowRenderer {
  let layer_cache = HostLayerCommandCache::new()
  let render_frame_fn = match render_frame {
    Some(render_frame) => render_frame
    None =>
      frame => {
        let expanded = layer_cache.expand_frame_commands(frame.commands)
        let commands : Array[@core.DrawCommand] = [
          @core.DrawCommand::Clear(frame.clear_color),
        ]
        commands.append(expanded.commands)
        render(commands)
        RenderFrameResult::new(
          cache_hit_count=expanded.cache_hit_count,
          cache_miss_count=expanded.cache_miss_count,
          cache_update_count=expanded.cache_update_count,
          cache_evict_count=expanded.cache_evict_count,
          missing_layer_keys=expanded.missing_layer_keys,
        )
      }
  }
  let drain_present_completions_fn = match drain_present_completions {
    Some(drain) => drain
    None => () => []
  }
  {
    resize_fn: resize,
    render_fn: render,
    render_frame_fn,
    drain_present_completions_fn,
    text_system_fn: text_system,
    image,
    present_count_fn: present_count,
    dispose_fn: dispose,
    platform_view,
    gpu_recovery,
    layer_cache,
  }
}

///|
pub fn HostWindowRenderer::resize(
  self : HostWindowRenderer,
  metrics : RendererSurfaceMetrics,
) -> Unit {
  (self.resize_fn)(metrics)
}

///|
pub fn HostWindowRenderer::render(
  self : HostWindowRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  (self.render_fn)(commands)
}

///|
pub fn HostWindowRenderer::render_frame(
  self : HostWindowRenderer,
  frame : @core.DrawFrame,
) -> RenderFrameResult {
  (self.render_frame_fn)(frame)
}

///|
/// Drain asynchronous renderer-worker completions. Synchronous raster
/// providers return an empty array; GPU workers return one record per frame
/// that reached present, was dropped, or triggered raster fallback.
pub fn HostWindowRenderer::drain_present_completions(
  self : HostWindowRenderer,
) -> Array[RenderPresentCompletion] {
  (self.drain_present_completions_fn)()
}

///|
/// Report whether a renderer-worker completion proves a window present.
pub fn render_present_completion_is_presented(
  completion : RenderPresentCompletion,
) -> Bool {
  completion.status() is RenderPresentStatus::Presented
}

///|
/// Report whether any drained completion proves a window present.
pub fn render_present_completions_have_presented(
  completions : Array[RenderPresentCompletion],
) -> Bool {
  completions.any(render_present_completion_is_presented)
}

///|
/// Report whether a queued frame reached any terminal outcome. `Recorded` is
/// an internal handoff signal and does not complete a window presentation.
pub fn render_present_completions_have_terminal(
  completions : Array[RenderPresentCompletion],
) -> Bool {
  completions.any(completion => {
    match completion.status() {
      RenderPresentStatus::Presented
      | RenderPresentStatus::Dropped
      | RenderPresentStatus::FallbackToRaster => true
      RenderPresentStatus::Recorded => false
    }
  })
}

///|
pub fn HostWindowRenderer::text_system(
  self : HostWindowRenderer,
) -> @core.TextSystem {
  (self.text_system_fn)()
}

///|
pub fn HostWindowRenderer::image_resources(
  self : HostWindowRenderer,
) -> Array[ImageResourceRecord] {
  (self.image.image_resources_fn)()
}

///|
pub fn HostWindowRenderer::image_resource_snapshot(
  self : HostWindowRenderer,
) -> ImageResourceSnapshot {
  (self.image.image_resource_snapshot_fn)()
}

///|
pub fn HostWindowRenderer::apply_image_resource_load_completion(
  self : HostWindowRenderer,
  completion : ImageResourceLoadCompletion,
) -> ImageResourceSnapshot {
  (self.image.apply_image_resource_load_completion_fn)(completion)
}

///|
pub fn HostWindowRenderer::set_image_resource_change_callback(
  self : HostWindowRenderer,
  callback : ((ImageResourceSnapshot) -> Unit)?,
) -> Unit {
  (self.image.set_image_resource_change_callback_fn)(callback)
}

///|
pub fn HostWindowRenderer::present_count(self : HostWindowRenderer) -> Int {
  (self.present_count_fn)()
}

///|
/// Inject a synthetic GPU context-loss control for promotion harnesses.
pub fn HostWindowRenderer::inject_context_loss(
  self : HostWindowRenderer,
) -> Unit {
  (self.gpu_recovery.inject_context_loss_fn)()
}

///|
pub fn HostWindowRenderer::gpu_recovery_count(self : HostWindowRenderer) -> Int {
  (self.gpu_recovery.gpu_recovery_count_fn)()
}

///|
pub fn HostWindowRenderer::gpu_fallback_active(
  self : HostWindowRenderer,
) -> Bool {
  (self.gpu_recovery.gpu_fallback_active_fn)()
}

///|
pub fn HostWindowRenderer::dispose(self : HostWindowRenderer) -> Unit {
  self.layer_cache.clear()
  (self.dispose_fn)()
}

///|
/// Draw platform view pixels onto the renderer surface (e.g., offscreen webview)
pub fn HostWindowRenderer::draw_platform_view_pixels(
  self : HostWindowRenderer,
  pixels : Bytes,
  src_width : Int,
  src_height : Int,
  src_stride : Int,
  dst_x : Double,
  dst_y : Double,
  dst_width : Double,
  dst_height : Double,
) -> Unit {
  (self.platform_view.draw_platform_view_pixels_fn)(
    pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
  )
}

///| Set a callback to draw platform view content after command rendering but before flush.

///|
/// Used by Linux to composite offscreen webview pixels into the Skia surface.
pub fn HostWindowRenderer::set_platform_view_draw_fn(
  self : HostWindowRenderer,
  draw_fn : (() -> Unit)?,
) -> Unit {
  (self.platform_view.set_platform_view_draw_fn_fn)(draw_fn)
}

///|
priv struct HostLayerCommandExpansion {
  commands : Array[@core.DrawCommand]
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  missing_layer_keys : Array[String]
}

///|
priv struct HostLayerCommandCapture {
  spec : @core.CachedLayerSpec
  commands : Array[@core.DrawCommand]
}

///|
fn HostLayerCommandCache::new() -> HostLayerCommandCache {
  { entries: [], tick: 0, budget_bytes: 64 * 1024 * 1024 }
}

///|
fn HostLayerCommandCache::clear(self : HostLayerCommandCache) -> Unit {
  self.entries.clear()
}

///|
fn HostLayerCommandCache::expand_frame_commands(
  self : HostLayerCommandCache,
  commands : Array[@core.DrawCommand],
) -> HostLayerCommandExpansion {
  self.tick = self.tick + 1
  let output : Array[@core.DrawCommand] = []
  let captures : Array[HostLayerCommandCapture] = []
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
  let evicted = self.evict_if_needed()
  {
    commands: output,
    cache_hit_count: hits,
    cache_miss_count: misses,
    cache_update_count: updates,
    cache_evict_count: evicted,
    missing_layer_keys: missing,
  }
}

///|
fn append_layer_cache_command(
  output : Array[@core.DrawCommand],
  captures : Array[HostLayerCommandCapture],
  command : @core.DrawCommand,
) -> Unit {
  output.push(command)
  for capture in captures {
    capture.commands.push(command)
  }
}

///|
fn HostLayerCommandCache::lookup(
  self : HostLayerCommandCache,
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
fn HostLayerCommandCache::store(
  self : HostLayerCommandCache,
  key : String,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.commands.clear()
      entry.commands.append(commands)
      entry.last_used = self.tick
      return ()
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
fn HostLayerCommandCache::evict_if_needed(self : HostLayerCommandCache) -> Int {
  let mut bytes = 0
  for entry in self.entries {
    bytes = bytes + entry.bytes
  }
  let mut evicted = 0
  while bytes > self.budget_bytes && self.entries.length() > 0 {
    let index = self.oldest_entry_index()
    let entry = self.entries[index]
    bytes = bytes - entry.bytes
    ignore(self.entries.remove(index))
    evicted = evicted + 1
  }
  evicted
}

///|
fn HostLayerCommandCache::oldest_entry_index(
  self : HostLayerCommandCache,
) -> Int {
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
