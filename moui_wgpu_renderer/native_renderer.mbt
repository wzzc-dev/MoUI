///|
struct RendererHandle {
  mut size : @core.Size
  mut physical_size : @core.Size
  mut scale_factor : Double
  mut last_batches : Array[@render.RectBatch]
  mut configured : Bool
  mut present_count : Int
  mut surface_format : @wgpu_mbt.TextureFormat
  mut instance : @wgpu_mbt.Instance?
  mut adapter : @wgpu_mbt.Adapter?
  mut device : @wgpu_mbt.Device?
  mut queue : @wgpu_mbt.Queue?
  mut surface : @wgpu_mbt.Surface?
  mut visual_shader : @wgpu_mbt.ShaderModule?
  mut visual_pipeline : @wgpu_mbt.RenderPipeline?
  mut visual_vertex_buffer : @wgpu_mbt.Buffer?
  mut visual_vertex_capacity : UInt64
  mut text_shader : @wgpu_mbt.ShaderModule?
  mut text_pipeline : @wgpu_mbt.RenderPipeline?
  mut text_vertex_buffer : @wgpu_mbt.Buffer?
  mut text_vertex_capacity : UInt64
  mut text_atlas_texture : @wgpu_mbt.Texture?
  mut text_atlas_view : @wgpu_mbt.TextureView?
  mut text_sampler : @wgpu_mbt.Sampler?
  mut text_bind_group_layout : @wgpu_mbt.BindGroupLayout?
  mut text_pipeline_layout : @wgpu_mbt.PipelineLayout?
  mut text_bind_group : @wgpu_mbt.BindGroup?
  mut image_shader : @wgpu_mbt.ShaderModule?
  mut image_pipeline : @wgpu_mbt.RenderPipeline?
  mut image_vertex_buffer : @wgpu_mbt.Buffer?
  mut image_vertex_capacity : UInt64
  mut image_sampler : @wgpu_mbt.Sampler?
  mut image_bind_group_layout : @wgpu_mbt.BindGroupLayout?
  mut image_pipeline_layout : @wgpu_mbt.PipelineLayout?
  mut advanced_shader : @wgpu_mbt.ShaderModule?
  mut advanced_pipeline_source_over : @wgpu_mbt.RenderPipeline?
  mut advanced_pipeline_multiply : @wgpu_mbt.RenderPipeline?
  mut advanced_pipeline_screen : @wgpu_mbt.RenderPipeline?
  mut advanced_pipeline_overlay : @wgpu_mbt.RenderPipeline?
  mut advanced_pipeline_darken : @wgpu_mbt.RenderPipeline?
  mut advanced_pipeline_lighten : @wgpu_mbt.RenderPipeline?
  mut advanced_vertex_buffer : @wgpu_mbt.Buffer?
  mut advanced_sampler : @wgpu_mbt.Sampler?
  mut advanced_bind_group_layout : @wgpu_mbt.BindGroupLayout?
  mut advanced_pipeline_layout : @wgpu_mbt.PipelineLayout?
  mut advanced_overlay_bind_group_layout : @wgpu_mbt.BindGroupLayout?
  mut advanced_overlay_pipeline_layout : @wgpu_mbt.PipelineLayout?
  mut white_texture : @wgpu_mbt.Texture?
  mut white_view : @wgpu_mbt.TextureView?
  mut white_bind_group : @wgpu_mbt.BindGroup?
  image_cache : Map[String, NativeImageResource]
  decoded_image_cache : Map[String, NativeDecodedImage]
  failed_images : Map[String, Bool]
  image_lifecycle : @render_common.ImageResourceLifecycle
  font_cache : NativeFontCache
  glyph_atlas : GlyphAtlas
  mut visual_vertices : Array[VisualVertex]
  mut text_vertices : Array[TextVertex]
  mut image_vertices : Array[ImageVertex]
  mut draw_items : Array[NativeDrawItem]
  mut text_atlas_dirty : Bool
  mut unsupported_command_count : Int
}

///|
priv struct NativeOffscreenTexture {
  texture : @wgpu_mbt.Texture
  view : @wgpu_mbt.TextureView
  bind_group : @wgpu_mbt.BindGroup
}

///|
priv struct NativeBackdropTexture {
  texture : @wgpu_mbt.Texture
  view : @wgpu_mbt.TextureView
  bind_group : @wgpu_mbt.BindGroup
}

///|
priv struct NativePlanGpuBuffers {
  visual_buffer : @wgpu_mbt.Buffer?
  text_buffer : @wgpu_mbt.Buffer?
  image_buffer : @wgpu_mbt.Buffer?
  visual_size : UInt64
  text_size : UInt64
  image_size : UInt64
}

///|
fn RendererHandle::create_with_host_surface(
  metrics : @core.SurfaceMetrics,
  host_surface : HostWgpuSurface,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  create_with_surface(
    metrics,
    host_surface.instance(),
    host_surface.surface(),
    native_noop_text_engine(),
  )
}

///|
fn RendererHandle::create_with_host_surface_and_text_engine(
  metrics : @core.SurfaceMetrics,
  host_surface : HostWgpuSurface,
  text_engine : NativeTextEngine,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  create_with_surface(
    metrics,
    host_surface.instance(),
    host_surface.surface(),
    text_engine,
  )
}

///|

///|
/// Prefer non-sRGB surface formats so sRGB palette bytes (e.g. `ColorPalette::light()`
/// primary `0.145`) are presented verbatim. `configure_default` picks
/// `caps.formats[0]` which is `BGRA8UnormSrgb` on macOS/Metal; the fragment
/// shaders output sRGB directly (`visual_shader_wgsl` / `text_shader_wgsl`)
/// and a Srgb target would then apply a spurious `linear->sRGB` encode
/// (`0.145 -> ~0.39`) washing the UI as seen in the Skia vs WGPU showcase
/// comparison. Keep blending in sRGB (matching Skia's `raster_n32_premul` +
/// `NSImageView` path) by forcing `BGRA8Unorm`/`RGBA8Unorm`.
fn wgpu_is_srgb_format(format : @wgpu_mbt.TextureFormat) -> Bool {
  format.raw == @wgpu_mbt.TEXTURE_FORMAT_BGRA8_UNORM_SRGB ||
  format.raw == @wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM_SRGB
}

///|
fn wgpu_contains_format(
  formats : Array[@wgpu_mbt.TextureFormat],
  target : @wgpu_mbt.TextureFormat,
) -> Bool {
  for fmt in formats {
    if fmt.raw == target.raw {
      return true
    }
  }
  false
}

///|
fn wgpu_contains_u32(values : Array[UInt], target : UInt) -> Bool {
  for v in values {
    if v == target {
      return true
    }
  }
  false
}

///|
fn wgpu_pick_preferred_surface_format(
  surface : @wgpu_mbt.Surface,
  adapter : @wgpu_mbt.Adapter,
) -> @wgpu_mbt.TextureFormat {
  let formats = surface.capabilities_formats(adapter)
  let prefs = [
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_BGRA8_UNORM),
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM),
  ]
  for pref in prefs {
    if wgpu_contains_format(formats, pref) {
      return pref
    }
  }
  for fmt in formats {
    if !wgpu_is_srgb_format(fmt) {
      return fmt
    }
  }
  if formats.length() > 0 {
    let first = formats[0]
    if wgpu_is_srgb_format(first) {
      if first.raw == @wgpu_mbt.TEXTURE_FORMAT_BGRA8_UNORM_SRGB {
        let alt = @wgpu_mbt.TextureFormat::from_u32(
          @wgpu_mbt.TEXTURE_FORMAT_BGRA8_UNORM,
        )
        if wgpu_contains_format(formats, alt) {
          return alt
        }
      } else if first.raw == @wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM_SRGB {
        let alt = @wgpu_mbt.TextureFormat::from_u32(
          @wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM,
        )
        if wgpu_contains_format(formats, alt) {
          return alt
        }
      }
    }
    return first
  }
  @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_BGRA8_UNORM)
}

///|
fn wgpu_configure_surface_preferred(
  surface : @wgpu_mbt.Surface,
  adapter : @wgpu_mbt.Adapter,
  device : @wgpu_mbt.Device,
  width : UInt,
  height : UInt,
  usage : @wgpu_mbt.TextureUsage,
) -> @wgpu_mbt.TextureFormat {
  let format = wgpu_pick_preferred_surface_format(surface, adapter)
  let present_modes = surface.capabilities_present_modes(adapter)
  let alpha_modes = surface.capabilities_alpha_modes(adapter)
  let mut present_mode = @wgpu_mbt.PRESENT_MODE_FIFO
  let present_prefs = [
    @wgpu_mbt.PRESENT_MODE_FIFO,
    @wgpu_mbt.PRESENT_MODE_FIFO_RELAXED,
  ]
  for pref in present_prefs {
    if wgpu_contains_u32(present_modes, pref) {
      present_mode = pref
      break
    }
  }
  if !wgpu_contains_u32(present_modes, present_mode) &&
    present_modes.length() > 0 {
    present_mode = present_modes[0]
  }
  let mut alpha_mode = @wgpu_mbt.COMPOSITE_ALPHA_MODE_AUTO
  let alpha_prefs = [
    @wgpu_mbt.COMPOSITE_ALPHA_MODE_AUTO,
    @wgpu_mbt.COMPOSITE_ALPHA_MODE_OPAQUE,
    @wgpu_mbt.COMPOSITE_ALPHA_MODE_PREMULTIPLIED,
    @wgpu_mbt.COMPOSITE_ALPHA_MODE_UNPREMULTIPLIED,
    @wgpu_mbt.COMPOSITE_ALPHA_MODE_INHERIT,
  ]
  for pref in alpha_prefs {
    if wgpu_contains_u32(alpha_modes, pref) {
      alpha_mode = pref
      break
    }
  }
  if !wgpu_contains_u32(alpha_modes, alpha_mode) && alpha_modes.length() > 0 {
    alpha_mode = alpha_modes[0]
  }
  let supported_usage = surface.capabilities_usages_u64(adapter)
  let actual_usage_raw = if (usage.raw & supported_usage.raw) == 0UL {
    supported_usage.raw
  } else {
    usage.raw & supported_usage.raw
  }
  let actual_usage = @wgpu_mbt.TextureUsage::from_u64(actual_usage_raw)
  let ok = surface.configure_u32(
    adapter, device, width, height, actual_usage, format, present_mode, alpha_mode,
  )
  if ok {
    return format
  }
  surface.configure_default(adapter, device, width, height, usage)
}

///|
fn create_with_surface(
  metrics : @core.SurfaceMetrics,
  instance : @wgpu_mbt.Instance,
  surface : @wgpu_mbt.Surface,
  text_engine : NativeTextEngine,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
  )
  let format = wgpu_configure_surface_preferred(
    surface,
    adapter,
    device,
    @render.size_dim_to_uint(metrics.physical_size.width),
    @render.size_dim_to_uint(metrics.physical_size.height),
    usage,
  )
  let visual_shader = device.create_shader_module_wgsl(visual_shader_wgsl())
  let visual_pipeline = create_visual_pipeline(device, visual_shader, format)
  let text_shader = device.create_shader_module_wgsl(text_shader_wgsl())
  let text_bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let text_pipeline_layout = device.create_pipeline_layout_1(
    text_bind_group_layout,
  )
  let text_pipeline = create_text_pipeline(
    device, text_shader, format, text_pipeline_layout,
  )
  let text_usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING | @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
  )
  let text_atlas_texture = device.create_texture_rgba8_2d_with_usage(
    atlas_width.reinterpret_as_uint(),
    atlas_height.reinterpret_as_uint(),
    text_usage,
  )
  let text_atlas_view = text_atlas_texture.create_view()
  let text_sampler = device.create_sampler_nearest_clamp()
  let text_bind_group = device.create_bind_group_sampler_texture_2d(
    text_bind_group_layout, text_sampler, text_atlas_view,
  )
  let image_shader = device.create_shader_module_wgsl(image_shader_wgsl())
  let image_bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let image_pipeline_layout = device.create_pipeline_layout_1(
    image_bind_group_layout,
  )
  let image_pipeline = create_image_pipeline(
    device, image_shader, format, image_pipeline_layout,
  )
  let image_sampler = device.create_sampler_linear_clamp()
  let advanced_shader = device.create_shader_module_wgsl(advanced_shader_wgsl())
  let advanced_bind_group_layout = create_advanced_overlay_bind_group_layout(
    device,
  )
  let advanced_pipeline_layout = device.create_pipeline_layout_1(
    advanced_bind_group_layout,
  )
  let advanced_overlay_bind_group_layout = create_advanced_overlay_bind_group_layout(
    device,
  )
  let advanced_overlay_pipeline_layout = device.create_pipeline_layout_1(
    advanced_overlay_bind_group_layout,
  )
  let advanced_pipeline_source_over = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::SourceOver,
  )
  let advanced_pipeline_multiply = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Multiply,
  )
  let advanced_pipeline_screen = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Screen,
  )
  let advanced_pipeline_overlay = create_advanced_overlay_pipeline(
    device, advanced_shader, format, advanced_overlay_pipeline_layout,
  )
  let advanced_pipeline_darken = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Darken,
  )
  let advanced_pipeline_lighten = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Lighten,
  )
  let advanced_sampler = device.create_sampler_linear_clamp()
  let white_usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING | @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
  )
  let white_texture = device.create_texture_rgba8_2d_with_usage(
    1U, 1U, white_usage,
  )
  queue.write_texture_rgba8_2d(
    white_texture,
    1U,
    1U,
    Bytes::from_array([b'\xff', b'\xff', b'\xff', b'\xff']),
  )
  let white_view = white_texture.create_view()
  let white_bind_group = create_advanced_bind_group(
    device, advanced_bind_group_layout, advanced_sampler, white_view, white_view,
  )
  {
    size: metrics.logical_size,
    physical_size: metrics.physical_size,
    scale_factor: metrics.scale_factor,
    last_batches: [],
    configured: true,
    present_count: 0,
    surface_format: format,
    instance: Some(instance),
    adapter: Some(adapter),
    device: Some(device),
    queue: Some(queue),
    surface: Some(surface),
    visual_shader: Some(visual_shader),
    visual_pipeline: Some(visual_pipeline),
    visual_vertex_buffer: None,
    visual_vertex_capacity: 0UL,
    text_shader: Some(text_shader),
    text_pipeline: Some(text_pipeline),
    text_vertex_buffer: None,
    text_vertex_capacity: 0UL,
    text_atlas_texture: Some(text_atlas_texture),
    text_atlas_view: Some(text_atlas_view),
    text_sampler: Some(text_sampler),
    text_bind_group_layout: Some(text_bind_group_layout),
    text_pipeline_layout: Some(text_pipeline_layout),
    text_bind_group: Some(text_bind_group),
    image_shader: Some(image_shader),
    image_pipeline: Some(image_pipeline),
    image_vertex_buffer: None,
    image_vertex_capacity: 0UL,
    image_sampler: Some(image_sampler),
    image_bind_group_layout: Some(image_bind_group_layout),
    image_pipeline_layout: Some(image_pipeline_layout),
    advanced_shader: Some(advanced_shader),
    advanced_pipeline_source_over: Some(advanced_pipeline_source_over),
    advanced_pipeline_multiply: Some(advanced_pipeline_multiply),
    advanced_pipeline_screen: Some(advanced_pipeline_screen),
    advanced_pipeline_overlay: Some(advanced_pipeline_overlay),
    advanced_pipeline_darken: Some(advanced_pipeline_darken),
    advanced_pipeline_lighten: Some(advanced_pipeline_lighten),
    advanced_vertex_buffer: None,
    advanced_sampler: Some(advanced_sampler),
    advanced_bind_group_layout: Some(advanced_bind_group_layout),
    advanced_pipeline_layout: Some(advanced_pipeline_layout),
    advanced_overlay_bind_group_layout: Some(advanced_overlay_bind_group_layout),
    advanced_overlay_pipeline_layout: Some(advanced_overlay_pipeline_layout),
    white_texture: Some(white_texture),
    white_view: Some(white_view),
    white_bind_group: Some(white_bind_group),
    image_cache: Map([]),
    decoded_image_cache: Map([]),
    failed_images: Map([]),
    image_lifecycle: @render_common.ImageResourceLifecycle::new(),
    font_cache: NativeFontCache::new_with_engine(text_engine),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    visual_vertices: [],
    text_vertices: [],
    image_vertices: [],
    draw_items: [],
    text_atlas_dirty: true,
    unsupported_command_count: 0,
  }
}

///|
fn RendererHandle::resize(
  self : RendererHandle,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  let scale_changed = self.scale_factor != metrics.scale_factor
  self.size = metrics.logical_size
  self.physical_size = metrics.physical_size
  self.scale_factor = metrics.scale_factor
  if scale_changed {
    self.glyph_atlas.clear()
  }
  let physical_size = self.effective_physical_size()
  match (self.surface, self.adapter, self.device) {
    (Some(surface), Some(adapter), Some(device)) => {
      let usage = @wgpu_mbt.TextureUsage::from_u64(
        @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT |
        @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
      )
      self.surface_format = wgpu_configure_surface_preferred(
        surface,
        adapter,
        device,
        @render.size_dim_to_uint(physical_size.width),
        @render.size_dim_to_uint(physical_size.height),
        usage,
      )
      self.configured = true
    }
    _ => ()
  }
}

///|
fn RendererHandle::effective_physical_size(self : RendererHandle) -> @core.Size {
  if self.physical_size.width > 0.0 && self.physical_size.height > 0.0 {
    self.physical_size
  } else {
    @core.Size::new(
      width=self.size.width * self.scale_factor,
      height=self.size.height * self.scale_factor,
    )
  }
}

///|
fn RendererHandle::render(
  self : RendererHandle,
  commands : Array[@core.DrawCommand],
) -> Unit {
  self.last_batches = @render.collect_rect_batches(commands)
  self.record_native_image_commands(commands)
  let lowered = @render_common.lower_draw_commands(commands)
  let plan = build_native_draw_plan(
    self.font_cache,
    self.glyph_atlas,
    lowered.ops,
    self.size,
    self.scale_factor,
  )
  self.visual_vertices = plan.visual_vertices
  self.text_vertices = plan.text_vertices
  self.image_vertices = plan.image_vertices
  self.draw_items = plan.items
  self.text_atlas_dirty = plan.atlas_dirty
  self.unsupported_command_count = count_native_unsupported_commands(commands)
  self.render_wgpu(commands)
}

///|
fn RendererHandle::dispose(self : RendererHandle) -> Unit {
  match self.visual_vertex_buffer {
    Some(buffer) => buffer.release()
    None => ()
  }
  match self.text_vertex_buffer {
    Some(buffer) => buffer.release()
    None => ()
  }
  match self.image_vertex_buffer {
    Some(buffer) => buffer.release()
    None => ()
  }
  for resource in self.image_cache.values() {
    resource.release()
  }
  self.image_cache.clear()
  self.decoded_image_cache.clear()
  self.failed_images.clear()
  match self.image_pipeline {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.image_pipeline_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.image_bind_group_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.image_sampler {
    Some(sampler) => sampler.release()
    None => ()
  }
  match self.image_shader {
    Some(shader) => shader.release()
    None => ()
  }
  match self.white_bind_group {
    Some(bind_group) => bind_group.release()
    None => ()
  }
  match self.white_view {
    Some(view) => view.release()
    None => ()
  }
  match self.white_texture {
    Some(texture) => {
      texture.destroy()
      texture.release()
    }
    None => ()
  }
  match self.advanced_vertex_buffer {
    Some(buffer) => buffer.release()
    None => ()
  }
  match self.advanced_pipeline_source_over {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_multiply {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_screen {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_overlay {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_darken {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_lighten {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.advanced_pipeline_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.advanced_overlay_pipeline_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.advanced_bind_group_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.advanced_overlay_bind_group_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.advanced_sampler {
    Some(sampler) => sampler.release()
    None => ()
  }
  match self.advanced_shader {
    Some(shader) => shader.release()
    None => ()
  }
  match self.text_bind_group {
    Some(bind_group) => bind_group.release()
    None => ()
  }
  match self.text_pipeline {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.text_pipeline_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.text_bind_group_layout {
    Some(layout) => layout.release()
    None => ()
  }
  match self.text_sampler {
    Some(sampler) => sampler.release()
    None => ()
  }
  match self.text_atlas_view {
    Some(view) => view.release()
    None => ()
  }
  match self.text_atlas_texture {
    Some(texture) => texture.release()
    None => ()
  }
  match self.text_shader {
    Some(shader) => shader.release()
    None => ()
  }
  match self.visual_pipeline {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.visual_shader {
    Some(shader) => shader.release()
    None => ()
  }
  match self.surface {
    Some(surface) => {
      if self.configured {
        surface.unconfigure()
      }
      surface.release()
    }
    None => ()
  }
  match self.queue {
    Some(queue) => queue.release()
    None => ()
  }
  match self.device {
    Some(device) => device.release()
    None => ()
  }
  match self.adapter {
    Some(adapter) => adapter.release()
    None => ()
  }
  match self.instance {
    Some(instance) => instance.release()
    None => ()
  }
  self.visual_pipeline = None
  self.visual_shader = None
  self.surface = None
  self.queue = None
  self.device = None
  self.adapter = None
  self.instance = None
  self.visual_vertex_buffer = None
  self.visual_vertex_capacity = 0UL
  self.text_vertex_buffer = None
  self.text_vertex_capacity = 0UL
  self.image_vertex_buffer = None
  self.image_vertex_capacity = 0UL
  self.image_pipeline = None
  self.image_pipeline_layout = None
  self.image_bind_group_layout = None
  self.image_sampler = None
  self.image_shader = None
  self.advanced_shader = None
  self.advanced_pipeline_source_over = None
  self.advanced_pipeline_multiply = None
  self.advanced_pipeline_screen = None
  self.advanced_pipeline_overlay = None
  self.advanced_pipeline_darken = None
  self.advanced_pipeline_lighten = None
  self.advanced_vertex_buffer = None
  self.advanced_sampler = None
  self.advanced_bind_group_layout = None
  self.advanced_pipeline_layout = None
  self.advanced_overlay_bind_group_layout = None
  self.advanced_overlay_pipeline_layout = None
  self.white_texture = None
  self.white_view = None
  self.white_bind_group = None
  self.text_bind_group = None
  self.text_pipeline = None
  self.text_pipeline_layout = None
  self.text_bind_group_layout = None
  self.text_sampler = None
  self.text_atlas_view = None
  self.text_atlas_texture = None
  self.text_shader = None
  self.visual_vertices = []
  self.text_vertices = []
  self.image_vertices = []
  self.draw_items = []
  self.text_atlas_dirty = false
  self.unsupported_command_count = 0
  self.configured = false
}

///|
fn count_native_unsupported_commands(
  commands : Array[@core.DrawCommand],
) -> Int {
  @render_common.plan_renderer_command_fallbacks(commands).fallback_count()
}

///|
fn RendererHandle::render_wgpu(
  self : RendererHandle,
  commands : Array[@core.DrawCommand],
) -> Unit {
  match (self.surface, self.device, self.queue, self.visual_pipeline) {
    (Some(surface), Some(device), Some(queue), Some(visual_pipeline)) => {
      let surface_texture = surface.get_current_texture()
      if surface_texture.is_success() {
        let texture = surface_texture.take_texture()
        surface_texture.release()
        let view = texture.create_view()
        let clear = @render.first_clear_color(commands)
        if self.text_atlas_dirty {
          match self.text_atlas_texture {
            Some(atlas_texture) => {
              queue.write_texture_rgba8_2d(
                atlas_texture,
                self.glyph_atlas.width.reinterpret_as_uint(),
                self.glyph_atlas.height.reinterpret_as_uint(),
                self.glyph_atlas.to_bytes(),
              )
              self.text_atlas_dirty = false
              self.glyph_atlas.dirty = false
            }
            None => ()
          }
        }
        self.prepare_native_image_items(device, queue)
        let root_plan = {
          visual_vertices: self.visual_vertices,
          text_vertices: self.text_vertices,
          image_vertices: self.image_vertices,
          items: self.draw_items,
          atlas_dirty: self.text_atlas_dirty,
        }
        let encoder = device.create_command_encoder()
        let frame_offscreens : Array[NativeOffscreenTexture] = []
        let frame_backdrops : Array[NativeBackdropTexture] = []
        let frame_buffers : Array[@wgpu_mbt.Buffer] = []
        self.encode_plan_to_view(
          encoder, device, queue, texture, view, visual_pipeline, root_plan, clear,
          frame_offscreens, frame_backdrops, frame_buffers, true,
        )
        let command_buffer = encoder.finish()
        queue.submit_one(command_buffer)
        ignore(surface.present())
        command_buffer.release()
        release_frame_buffers(frame_buffers)
        release_frame_backdrops(frame_backdrops)
        release_frame_offscreens(frame_offscreens)
        encoder.release()
        view.release()
        texture.release()
        self.present_count += 1
      } else {
        surface_texture.release()
      }
    }
    _ => ()
  }
}

///|
fn RendererHandle::encode_plan_to_view(
  self : RendererHandle,
  encoder : @wgpu_mbt.CommandEncoder,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  target_texture : @wgpu_mbt.Texture,
  view : @wgpu_mbt.TextureView,
  visual_pipeline : @wgpu_mbt.RenderPipeline,
  plan : NativeDrawPlan,
  clear : @core.Color,
  frame_offscreens : Array[NativeOffscreenTexture],
  frame_backdrops : Array[NativeBackdropTexture],
  frame_buffers : Array[@wgpu_mbt.Buffer],
  persistent_buffers : Bool,
) -> Unit {
  let buffers = if persistent_buffers {
    self.upload_root_gpu_buffers(device, queue, plan)
  } else {
    let buffers = upload_plan_gpu_buffers(device, queue, plan)
    buffers.append_to_frame(frame_buffers)
    buffers
  }
  let mut first_pass = true
  let mut span_start = 0
  let mut index = 0
  while index < plan.items.length() {
    match plan.items[index] {
      NativeDrawItem::NativeLayer(layer) => {
        if span_start < index {
          self.draw_plan_item_span(
            encoder,
            view,
            visual_pipeline,
            device,
            queue,
            plan.items,
            buffers,
            start_index=span_start,
            end_index=index,
            clear~,
            clear_pass=first_pass,
            frame_buffers~,
          )
          first_pass = false
        }
        if self.draw_native_layer_to_view(
            encoder,
            target_texture,
            view,
            visual_pipeline,
            device,
            queue,
            layer,
            clear~,
            clear_pass=first_pass,
            frame_offscreens~,
            frame_backdrops~,
            frame_buffers~,
          ) {
          first_pass = false
        }
        index += 1
        span_start = index
      }
      _ => index += 1
    }
  }
  if span_start < plan.items.length() {
    self.draw_plan_item_span(
      encoder,
      view,
      visual_pipeline,
      device,
      queue,
      plan.items,
      buffers,
      start_index=span_start,
      end_index=plan.items.length(),
      clear~,
      clear_pass=first_pass,
      frame_buffers~,
    )
    first_pass = false
  }
  if first_pass {
    clear_render_target(encoder, view, clear)
  }
}

///|
fn RendererHandle::draw_plan_item_span(
  self : RendererHandle,
  encoder : @wgpu_mbt.CommandEncoder,
  view : @wgpu_mbt.TextureView,
  visual_pipeline : @wgpu_mbt.RenderPipeline,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  items : Array[NativeDrawItem],
  buffers : NativePlanGpuBuffers,
  start_index~ : Int,
  end_index~ : Int,
  clear~ : @core.Color,
  clear_pass~ : Bool,
  frame_buffers~ : Array[@wgpu_mbt.Buffer],
) -> Unit {
  let pass = if clear_pass {
    encoder.begin_render_pass_color_clear(
      view,
      Float::from_double(clear.r),
      Float::from_double(clear.g),
      Float::from_double(clear.b),
      Float::from_double(clear.a),
    )
  } else {
    encoder.begin_render_pass_color_load(view)
  }
  self.apply_scissor(pass, None)
  for index in start_index..<end_index {
    let item = items[index]
    match item {
      NativeDrawItem::NativeVisual(start, count, scissor) =>
        match buffers.visual_buffer {
          Some(buffer) => {
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(visual_pipeline)
            pass.set_vertex_buffer(0U, buffer, 0UL, buffers.visual_size)
            pass.draw(
              count.reinterpret_as_uint(),
              1U,
              start.reinterpret_as_uint(),
              0U,
            )
          }
          None => ()
        }
      NativeDrawItem::NativeText(start, count, scissor) =>
        match (self.text_pipeline, self.text_bind_group, buffers.text_buffer) {
          (Some(text_pipeline), Some(text_bind_group), Some(buffer)) => {
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(text_pipeline)
            pass.set_bind_group0(text_bind_group)
            pass.set_vertex_buffer(0U, buffer, 0UL, buffers.text_size)
            pass.draw(
              count.reinterpret_as_uint(),
              1U,
              start.reinterpret_as_uint(),
              0U,
            )
          }
          _ => ()
        }
      NativeDrawItem::NativeImage(start, count, scissor, run) =>
        match
          (
            self.image_pipeline,
            buffers.image_buffer,
            self.image_cache.get(run.source),
          ) {
          (Some(image_pipeline), Some(buffer), Some(resource)) => {
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(image_pipeline)
            pass.set_bind_group0(resource.bind_group)
            pass.set_vertex_buffer(0U, buffer, 0UL, buffers.image_size)
            pass.draw(
              count.reinterpret_as_uint(),
              1U,
              start.reinterpret_as_uint(),
              0U,
            )
          }
          _ => ()
        }
      NativeDrawItem::NativeLayer(_) => ()
      NativeDrawItem::NativeShaderEffect(effect) =>
        self.draw_native_shader_effect(
          pass, device, queue, effect, frame_buffers,
        )
    }
  }
  self.apply_scissor(pass, None)
  pass.end()
  pass.release()
}

///|
fn RendererHandle::draw_native_layer_to_view(
  self : RendererHandle,
  encoder : @wgpu_mbt.CommandEncoder,
  target_texture : @wgpu_mbt.Texture,
  view : @wgpu_mbt.TextureView,
  visual_pipeline : @wgpu_mbt.RenderPipeline,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  layer : NativeLayerRun,
  clear~ : @core.Color,
  clear_pass~ : Bool,
  frame_offscreens~ : Array[NativeOffscreenTexture],
  frame_backdrops~ : Array[NativeBackdropTexture],
  frame_buffers~ : Array[@wgpu_mbt.Buffer],
) -> Bool {
  guard self.create_offscreen_texture(device) is Some(offscreen) else {
    return false
  }
  frame_offscreens.push(offscreen)
  self.encode_plan_to_view(
    encoder,
    device,
    queue,
    offscreen.texture,
    offscreen.view,
    visual_pipeline,
    layer.plan,
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    frame_offscreens,
    frame_backdrops,
    frame_buffers,
    false,
  )
  if layer.blend_mode == @core.BlendMode::Overlay {
    return self.draw_overlay_layer_to_view(
      encoder,
      target_texture,
      view,
      device,
      queue,
      layer,
      offscreen.view,
      clear~,
      clear_pass~,
      frame_backdrops~,
      frame_buffers~,
    )
  }
  let pass = if clear_pass {
    encoder.begin_render_pass_color_clear(
      view,
      Float::from_double(clear.r),
      Float::from_double(clear.g),
      Float::from_double(clear.b),
      Float::from_double(clear.a),
    )
  } else {
    encoder.begin_render_pass_color_load(view)
  }
  let vertices = advanced_layer_vertices(self.size, layer)
  self.draw_advanced_vertices(
    pass,
    device,
    queue,
    vertices,
    offscreen.bind_group,
    layer.blend_mode,
    layer.scissor,
    frame_buffers,
  )
  pass.end()
  pass.release()
  true
}

///|
fn RendererHandle::draw_native_shader_effect(
  self : RendererHandle,
  pass : @wgpu_mbt.RenderPass,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  effect : NativeShaderEffectRun,
  frame_buffers : Array[@wgpu_mbt.Buffer],
) -> Unit {
  match self.white_bind_group {
    Some(bind_group) => {
      let colors = native_shader_effect_colors(effect)
      let vertices = advanced_rect_vertices(
        self.size,
        effect.frame,
        opacity=effect.opacity,
        blend_mode=@core.BlendMode::SourceOver,
        shader_kind=native_shader_kind(effect.name),
        effect_amount=native_shader_effect_amount(effect),
        filter=None,
        color0=colors.0,
        color1=colors.1,
        transform=effect.transform,
      )
      self.draw_advanced_vertices(
        pass,
        device,
        queue,
        vertices,
        bind_group,
        @core.BlendMode::SourceOver,
        effect.scissor,
        frame_buffers,
      )
    }
    None => ()
  }
}

///|
fn RendererHandle::draw_overlay_layer_to_view(
  self : RendererHandle,
  encoder : @wgpu_mbt.CommandEncoder,
  target_texture : @wgpu_mbt.Texture,
  view : @wgpu_mbt.TextureView,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  layer : NativeLayerRun,
  layer_view : @wgpu_mbt.TextureView,
  clear~ : @core.Color,
  clear_pass~ : Bool,
  frame_backdrops~ : Array[NativeBackdropTexture],
  frame_buffers~ : Array[@wgpu_mbt.Buffer],
) -> Bool {
  if clear_pass {
    clear_render_target(encoder, view, clear)
  }
  guard self.create_backdrop_texture(device, target_texture, layer_view)
    is Some(backdrop) else {
    return false
  }
  encoder.copy_texture_to_texture_rgba8(
    target_texture,
    backdrop.texture,
    @render.size_dim_to_uint(self.effective_physical_size().width),
    @render.size_dim_to_uint(self.effective_physical_size().height),
  )
  let vertices = advanced_layer_vertices(self.size, layer)
  let pass = encoder.begin_render_pass_color_load(view)
  self.draw_advanced_overlay_vertices(
    pass,
    device,
    queue,
    vertices,
    backdrop.bind_group,
    layer.scissor,
    frame_buffers,
  )
  pass.end()
  pass.release()
  frame_backdrops.push(backdrop)
  true
}

///|
fn RendererHandle::draw_advanced_vertices(
  self : RendererHandle,
  pass : @wgpu_mbt.RenderPass,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  vertices : Array[AdvancedVertex],
  bind_group : @wgpu_mbt.BindGroup,
  blend_mode : @core.BlendMode,
  scissor : NativeScissor?,
  frame_buffers : Array[@wgpu_mbt.Buffer],
) -> Unit {
  if vertices.length() == 0 {
    return
  }
  match self.advanced_pipeline_for_blend(blend_mode) {
    Some(pipeline) => {
      let bytes = advanced_vertices_to_bytes(vertices)
      let required = bytes.length().to_uint64()
      if required == 0UL {
        return
      }
      let usage = @wgpu_mbt.BufferUsage::from_u64(
        @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
      )
      let buffer = device.create_buffer(
        size=@render.grow_capacity(required),
        usage~,
      )
      queue.write_buffer(buffer, 0UL, bytes)
      frame_buffers.push(buffer)
      self.apply_scissor(pass, scissor)
      pass.set_pipeline(pipeline)
      pass.set_bind_group0(bind_group)
      pass.set_vertex_buffer(0U, buffer, 0UL, required)
      pass.draw(vertices.length().reinterpret_as_uint(), 1U, 0U, 0U)
    }
    None => ()
  }
}

///|
fn RendererHandle::draw_advanced_overlay_vertices(
  self : RendererHandle,
  pass : @wgpu_mbt.RenderPass,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  vertices : Array[AdvancedVertex],
  bind_group : @wgpu_mbt.BindGroup,
  scissor : NativeScissor?,
  frame_buffers : Array[@wgpu_mbt.Buffer],
) -> Unit {
  if vertices.length() == 0 {
    return
  }
  match self.advanced_pipeline_overlay {
    Some(pipeline) => {
      let bytes = advanced_vertices_to_bytes(vertices)
      let required = bytes.length().to_uint64()
      if required == 0UL {
        return
      }
      let usage = @wgpu_mbt.BufferUsage::from_u64(
        @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
      )
      let buffer = device.create_buffer(
        size=@render.grow_capacity(required),
        usage~,
      )
      queue.write_buffer(buffer, 0UL, bytes)
      frame_buffers.push(buffer)
      self.apply_scissor(pass, scissor)
      pass.set_pipeline(pipeline)
      pass.set_bind_group0(bind_group)
      pass.set_vertex_buffer(0U, buffer, 0UL, required)
      pass.draw(vertices.length().reinterpret_as_uint(), 1U, 0U, 0U)
    }
    None => ()
  }
}

///|
fn RendererHandle::advanced_pipeline_for_blend(
  self : RendererHandle,
  blend_mode : @core.BlendMode,
) -> @wgpu_mbt.RenderPipeline? {
  match blend_mode {
    @core.BlendMode::SourceOver => self.advanced_pipeline_source_over
    @core.BlendMode::Multiply => self.advanced_pipeline_multiply
    @core.BlendMode::Screen => self.advanced_pipeline_screen
    @core.BlendMode::Overlay => self.advanced_pipeline_source_over
    @core.BlendMode::Darken => self.advanced_pipeline_darken
    @core.BlendMode::Lighten => self.advanced_pipeline_lighten
  }
}

///|
fn RendererHandle::create_offscreen_texture(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
) -> NativeOffscreenTexture? {
  match (self.advanced_bind_group_layout, self.advanced_sampler) {
    (Some(layout), Some(sampler)) => {
      let size = self.effective_physical_size()
      let usage = @wgpu_mbt.TextureUsage::from_u64(
        @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT |
        @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
        @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
      )
      let texture = device.create_texture_u32(
        @render.size_dim_to_uint(size.width),
        @render.size_dim_to_uint(size.height),
        1U,
        usage,
        @wgpu_mbt.TextureDimension::from_u32(@wgpu_mbt.TEXTURE_DIMENSION_2D),
        self.surface_format,
      )
      let view = texture.create_view()
      let bind_group = create_advanced_bind_group(
        device, layout, sampler, view, view,
      )
      Some({ texture, view, bind_group })
    }
    _ => None
  }
}

///|
fn RendererHandle::create_backdrop_texture(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
  target_texture : @wgpu_mbt.Texture,
  layer_view : @wgpu_mbt.TextureView,
) -> NativeBackdropTexture? {
  match (self.advanced_overlay_bind_group_layout, self.advanced_sampler) {
    (Some(layout), Some(sampler)) => {
      let width = @render.size_dim_to_uint(self.effective_physical_size().width)
      let height = @render.size_dim_to_uint(
        self.effective_physical_size().height,
      )
      let usage = @wgpu_mbt.TextureUsage::from_u64(
        @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
        @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
      )
      let texture = device.create_texture_u32(
        width,
        height,
        1U,
        usage,
        @wgpu_mbt.TextureDimension::from_u32(@wgpu_mbt.TEXTURE_DIMENSION_2D),
        target_texture.format_u32(),
      )
      let view = texture.create_view()
      let bind_group = create_advanced_bind_group(
        device, layout, sampler, layer_view, view,
      )
      Some({ texture, view, bind_group })
    }
    _ => None
  }
}

///|
fn NativeOffscreenTexture::release(self : NativeOffscreenTexture) -> Unit {
  self.bind_group.release()
  self.view.release()
  self.texture.destroy()
  self.texture.release()
}

///|
fn NativeBackdropTexture::release(self : NativeBackdropTexture) -> Unit {
  self.bind_group.release()
  self.view.release()
  self.texture.destroy()
  self.texture.release()
}

///|
fn upload_plan_gpu_buffers(
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  plan : NativeDrawPlan,
) -> NativePlanGpuBuffers {
  let mut visual_buffer : @wgpu_mbt.Buffer? = None
  let mut text_buffer : @wgpu_mbt.Buffer? = None
  let mut image_buffer : @wgpu_mbt.Buffer? = None
  let mut visual_size = 0UL
  let mut text_size = 0UL
  let mut image_size = 0UL
  if plan.visual_vertices.length() > 0 {
    let bytes = visual_vertices_to_bytes(plan.visual_vertices)
    visual_size = bytes.length().to_uint64()
    let usage = @wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    )
    let buffer = device.create_buffer(
      size=@render.grow_capacity(visual_size),
      usage~,
    )
    queue.write_buffer(buffer, 0UL, bytes)
    visual_buffer = Some(buffer)
  }
  if plan.text_vertices.length() > 0 {
    let bytes = text_vertices_to_bytes(plan.text_vertices)
    text_size = bytes.length().to_uint64()
    let usage = @wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    )
    let buffer = device.create_buffer(
      size=@render.grow_capacity(text_size),
      usage~,
    )
    queue.write_buffer(buffer, 0UL, bytes)
    text_buffer = Some(buffer)
  }
  if plan.image_vertices.length() > 0 {
    let bytes = image_vertices_to_bytes(plan.image_vertices)
    image_size = bytes.length().to_uint64()
    let usage = @wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    )
    let buffer = device.create_buffer(
      size=@render.grow_capacity(image_size),
      usage~,
    )
    queue.write_buffer(buffer, 0UL, bytes)
    image_buffer = Some(buffer)
  }
  {
    visual_buffer,
    text_buffer,
    image_buffer,
    visual_size,
    text_size,
    image_size,
  }
}

///|
/// Upload the root draw plan into buffers retained by the renderer. The root
/// plan is rebuilt for every frame, but its vertex layout is stable during a
/// scroll; reusing these allocations avoids a native buffer create/write/
/// release cycle on every display tick. Nested offscreen layers continue to
/// use frame-owned buffers because their plans can be encoded recursively.
fn RendererHandle::upload_root_gpu_buffers(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
  plan : NativeDrawPlan,
) -> NativePlanGpuBuffers {
  let usage = @wgpu_mbt.BufferUsage::from_u64(
    @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
  )
  let mut visual_size = 0UL
  let mut text_size = 0UL
  let mut image_size = 0UL
  let visual_buffer = if plan.visual_vertices.length() > 0 {
    let bytes = visual_vertices_to_bytes(plan.visual_vertices)
    let required = bytes.length().to_uint64()
    visual_size = required
    match self.visual_vertex_buffer {
      Some(buffer) if self.visual_vertex_capacity >= required => {
        queue.write_buffer(buffer, 0UL, bytes)
        Some(buffer)
      }
      _ => {
        match self.visual_vertex_buffer {
          Some(buffer) => buffer.release()
          None => ()
        }
        let buffer = device.create_buffer(
          size=@render.grow_capacity(required),
          usage~,
        )
        queue.write_buffer(buffer, 0UL, bytes)
        self.visual_vertex_buffer = Some(buffer)
        self.visual_vertex_capacity = @render.grow_capacity(required)
        Some(buffer)
      }
    }
  } else {
    None
  }
  let text_buffer = if plan.text_vertices.length() > 0 {
    let bytes = text_vertices_to_bytes(plan.text_vertices)
    let required = bytes.length().to_uint64()
    text_size = required
    match self.text_vertex_buffer {
      Some(buffer) if self.text_vertex_capacity >= required => {
        queue.write_buffer(buffer, 0UL, bytes)
        Some(buffer)
      }
      _ => {
        match self.text_vertex_buffer {
          Some(buffer) => buffer.release()
          None => ()
        }
        let buffer = device.create_buffer(
          size=@render.grow_capacity(required),
          usage~,
        )
        queue.write_buffer(buffer, 0UL, bytes)
        self.text_vertex_buffer = Some(buffer)
        self.text_vertex_capacity = @render.grow_capacity(required)
        Some(buffer)
      }
    }
  } else {
    None
  }
  let image_buffer = if plan.image_vertices.length() > 0 {
    let bytes = image_vertices_to_bytes(plan.image_vertices)
    let required = bytes.length().to_uint64()
    image_size = required
    match self.image_vertex_buffer {
      Some(buffer) if self.image_vertex_capacity >= required => {
        queue.write_buffer(buffer, 0UL, bytes)
        Some(buffer)
      }
      _ => {
        match self.image_vertex_buffer {
          Some(buffer) => buffer.release()
          None => ()
        }
        let buffer = device.create_buffer(
          size=@render.grow_capacity(required),
          usage~,
        )
        queue.write_buffer(buffer, 0UL, bytes)
        self.image_vertex_buffer = Some(buffer)
        self.image_vertex_capacity = @render.grow_capacity(required)
        Some(buffer)
      }
    }
  } else {
    None
  }
  {
    visual_buffer,
    text_buffer,
    image_buffer,
    visual_size,
    text_size,
    image_size,
  }
}

///|
fn NativePlanGpuBuffers::append_to_frame(
  self : NativePlanGpuBuffers,
  frame_buffers : Array[@wgpu_mbt.Buffer],
) -> Unit {
  match self.visual_buffer {
    Some(buffer) => frame_buffers.push(buffer)
    None => ()
  }
  match self.text_buffer {
    Some(buffer) => frame_buffers.push(buffer)
    None => ()
  }
  match self.image_buffer {
    Some(buffer) => frame_buffers.push(buffer)
    None => ()
  }
}

///|
fn release_frame_buffers(frame_buffers : Array[@wgpu_mbt.Buffer]) -> Unit {
  for buffer in frame_buffers {
    buffer.release()
  }
  frame_buffers.clear()
}

///|
fn release_frame_backdrops(
  frame_backdrops : Array[NativeBackdropTexture],
) -> Unit {
  for backdrop in frame_backdrops {
    backdrop.release()
  }
  frame_backdrops.clear()
}

///|
fn release_frame_offscreens(
  frame_offscreens : Array[NativeOffscreenTexture],
) -> Unit {
  for offscreen in frame_offscreens {
    offscreen.release()
  }
  frame_offscreens.clear()
}

///|
fn clear_render_target(
  encoder : @wgpu_mbt.CommandEncoder,
  view : @wgpu_mbt.TextureView,
  clear : @core.Color,
) -> Unit {
  let pass = encoder.begin_render_pass_color_clear(
    view,
    Float::from_double(clear.r),
    Float::from_double(clear.g),
    Float::from_double(clear.b),
    Float::from_double(clear.a),
  )
  pass.end()
  pass.release()
}

///|
fn RendererHandle::apply_scissor(
  self : RendererHandle,
  pass : @wgpu_mbt.RenderPass,
  scissor : NativeScissor?,
) -> Unit {
  match scissor {
    Some(scissor) => {
      let width = max_native_int(0, scissor.width)
      let height = max_native_int(0, scissor.height)
      pass.set_scissor_rect(
        max_native_int(0, scissor.x).reinterpret_as_uint(),
        max_native_int(0, scissor.y).reinterpret_as_uint(),
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
      )
    }
    None =>
      pass.set_scissor_rect(
        0U,
        0U,
        @render.size_dim_to_uint(self.effective_physical_size().width),
        @render.size_dim_to_uint(self.effective_physical_size().height),
      )
  }
}

///|
fn max_native_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn create_visual_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(
    visual_vertex_stride,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 32UL, 3U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 48UL, 4U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 56UL, 5U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 72UL, 6U)
  try! builder.create_pipeline(device)
}

///|
fn create_image_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(
    image_vertex_stride,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32, 16UL, 2U)
  try! builder.create_pipeline(device)
}

///|
fn create_text_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(
    text_vertex_stride,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32, 32UL, 3U)
  try! builder.create_pipeline(device)
}

///|
fn create_advanced_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
  blend_mode : @core.BlendMode,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  set_advanced_blend(builder, blend_mode)
  try! builder.set_vertex_buffer_layout(
    advanced_vertex_stride,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 32UL, 3U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 48UL, 4U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 64UL, 5U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 80UL, 6U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 96UL, 7U)
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    112UL,
    8U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    128UL,
    9U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    144UL,
    10U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    160UL,
    11U,
  )
  try! builder.create_pipeline(device)
}

///|
fn create_advanced_overlay_bind_group_layout(
  device : @wgpu_mbt.Device,
) -> @wgpu_mbt.BindGroupLayout {
  let builder = @wgpu_mbt.BindGroupLayoutBuilder::new(max_entries=3UL)
  let stage = @wgpu_mbt.ShaderStage::from_u64(@wgpu_mbt.SHADER_STAGE_FRAGMENT)
  ignore(
    builder.add_sampler(0U, stage, @wgpu_mbt.SAMPLER_BINDING_TYPE_FILTERING),
  )
  ignore(
    builder.add_texture(
      1U,
      stage,
      @wgpu_mbt.TEXTURE_SAMPLE_TYPE_FLOAT,
      @wgpu_mbt.TEXTURE_VIEW_DIMENSION_2D,
    ),
  )
  ignore(
    builder.add_texture(
      2U,
      stage,
      @wgpu_mbt.TEXTURE_SAMPLE_TYPE_FLOAT,
      @wgpu_mbt.TEXTURE_VIEW_DIMENSION_2D,
    ),
  )
  builder.finish(device)
}

///|
fn create_advanced_bind_group(
  device : @wgpu_mbt.Device,
  layout : @wgpu_mbt.BindGroupLayout,
  sampler : @wgpu_mbt.Sampler,
  layer_view : @wgpu_mbt.TextureView,
  backdrop_view : @wgpu_mbt.TextureView,
) -> @wgpu_mbt.BindGroup {
  let builder = @wgpu_mbt.BindGroupBuilder::new(max_entries=3UL)
  ignore(builder.add_sampler(0U, sampler))
  ignore(builder.add_texture_view(1U, layer_view))
  ignore(builder.add_texture_view(2U, backdrop_view))
  builder.finish(device, layout)
}

///|
fn create_advanced_overlay_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.disable_blend()
  try! builder.set_vertex_buffer_layout(
    advanced_vertex_stride,
    @wgpu_mbt.VERTEX_STEP_MODE_VERTEX,
  )
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 32UL, 3U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 48UL, 4U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 64UL, 5U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 80UL, 6U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 96UL, 7U)
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    112UL,
    8U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    128UL,
    9U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    144UL,
    10U,
  )
  try! builder.add_vertex_attribute(
    @wgpu_mbt.VERTEX_FORMAT_FLOAT32X4,
    160UL,
    11U,
  )
  try! builder.create_pipeline(device)
}

///|
fn set_advanced_blend(
  builder : @wgpu_mbt.RenderPipelineDescBuilder,
  blend_mode : @core.BlendMode,
) -> Unit {
  match blend_mode {
    @core.BlendMode::SourceOver | @core.BlendMode::Overlay =>
      try! builder.enable_alpha_blend()
    @core.BlendMode::Multiply =>
      try! builder.set_blend_components(
        @wgpu_mbt.BLEND_FACTOR_DST,
        @wgpu_mbt.BLEND_FACTOR_ZERO,
        @wgpu_mbt.BLEND_OPERATION_ADD,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        @wgpu_mbt.BLEND_OPERATION_ADD,
      )
    @core.BlendMode::Screen =>
      try! builder.set_blend_components(
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE_MINUS_SRC,
        @wgpu_mbt.BLEND_OPERATION_ADD,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        @wgpu_mbt.BLEND_OPERATION_ADD,
      )
    @core.BlendMode::Darken =>
      try! builder.set_blend_components(
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_OPERATION_MIN,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        @wgpu_mbt.BLEND_OPERATION_ADD,
      )
    @core.BlendMode::Lighten =>
      try! builder.set_blend_components(
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_OPERATION_MAX,
        @wgpu_mbt.BLEND_FACTOR_ONE,
        @wgpu_mbt.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        @wgpu_mbt.BLEND_OPERATION_ADD,
      )
  }
}
