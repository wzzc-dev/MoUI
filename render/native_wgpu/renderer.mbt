///|
pub struct RendererHandle {
  mut size : @core.Size
  mut last_batches : Array[@render.RectBatch]
  mut configured : Bool
  mut present_count : Int
  priv mut instance : @wgpu.Instance?
  priv mut adapter : @wgpu.Adapter?
  priv mut device : @wgpu.Device?
  priv mut queue : @wgpu.Queue?
  priv mut surface : @wgpu.Surface?
  priv mut shader : @wgpu.ShaderModule?
  priv mut pipeline : @wgpu.RenderPipeline?
  priv mut vertex_buffer : @wgpu.Buffer?
  priv mut vertex_buffer_capacity : UInt64
  priv mut text_shader : @wgpu.ShaderModule?
  priv mut text_pipeline : @wgpu.RenderPipeline?
  priv mut text_vertex_buffer : @wgpu.Buffer?
  priv mut text_vertex_buffer_capacity : UInt64
  priv mut text_atlas_texture : @wgpu.Texture?
  priv mut text_atlas_view : @wgpu.TextureView?
  priv mut text_sampler : @wgpu.Sampler?
  priv mut text_bind_group_layout : @wgpu.BindGroupLayout?
  priv mut text_pipeline_layout : @wgpu.PipelineLayout?
  priv mut text_bind_group : @wgpu.BindGroup?
  priv font_cache : NativeFontCache
  priv glyph_atlas : GlyphAtlas
  priv mut text_vertices : Array[TextVertex]
  priv mut text_atlas_dirty : Bool
}

///|
pub fn RendererHandle::new() -> RendererHandle {
  {
    size: @core.Size::new(width=0.0, height=0.0),
    last_batches: [],
    configured: false,
    present_count: 0,
    instance: None,
    adapter: None,
    device: None,
    queue: None,
    surface: None,
    shader: None,
    pipeline: None,
    vertex_buffer: None,
    vertex_buffer_capacity: 0UL,
    text_shader: None,
    text_pipeline: None,
    text_vertex_buffer: None,
    text_vertex_buffer_capacity: 0UL,
    text_atlas_texture: None,
    text_atlas_view: None,
    text_sampler: None,
    text_bind_group_layout: None,
    text_pipeline_layout: None,
    text_bind_group: None,
    font_cache: NativeFontCache::new(),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    text_vertices: [],
    text_atlas_dirty: false,
  }
}

///|
pub fn RendererHandle::create(
  size : @core.Size,
) -> RendererHandle raise @wgpu.WgpuError {
  // Compatibility path for the old native renderer API. New platform hosts
  // should create HostWgpuSurface themselves and call render/wgpu instead.
  let surface = NativeSurfaceFactory::create_metal_layer()
  RendererHandle::create_with_host_surface(size, surface)
}

///|
pub fn RendererHandle::create_for_windows_hwnd(
  size : @core.Size,
  hwnd : UInt64,
) -> RendererHandle raise @wgpu.WgpuError {
  // Compatibility path for the old Windows renderer API. Windows backend now
  // owns HWND surface creation and passes HostWgpuSurface into render/wgpu.
  let surface = NativeSurfaceFactory::create_windows_hwnd(hwnd)
  RendererHandle::create_with_host_surface(size, surface)
}

///|
pub fn RendererHandle::create_with_host_surface(
  size : @core.Size,
  host_surface : HostWgpuSurface,
) -> RendererHandle raise @wgpu.WgpuError {
  create_with_surface(
    size,
    host_surface.instance,
    host_surface.surface,
  )
}

///|
fn create_with_surface(
  size : @core.Size,
  instance : @wgpu.Instance,
  surface : @wgpu.Surface,
) -> RendererHandle raise @wgpu.WgpuError {
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let usage = @wgpu.TextureUsage::from_u64(
    @wgpu.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu.TEXTURE_USAGE_COPY_SRC,
  )
  let format = surface.configure_default(
    adapter,
    device,
    @render.size_dim_to_uint(size.width),
    @render.size_dim_to_uint(size.height),
    usage,
  )
  let shader = device.create_shader_module_wgsl(@render.rect_shader_wgsl())
  let pipeline = create_rect_pipeline(device, shader, format)
  let text_shader = device.create_shader_module_wgsl(text_shader_wgsl())
  let text_bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let text_pipeline_layout = device.create_pipeline_layout_1(
    text_bind_group_layout,
  )
  let text_pipeline = create_text_pipeline(
    device, text_shader, format, text_pipeline_layout,
  )
  let text_usage = @wgpu.TextureUsage::from_u64(
    @wgpu.TEXTURE_USAGE_TEXTURE_BINDING | @wgpu.TEXTURE_USAGE_COPY_DST,
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
  {
    size,
    last_batches: [],
    configured: true,
    present_count: 0,
    instance: Some(instance),
    adapter: Some(adapter),
    device: Some(device),
    queue: Some(queue),
    surface: Some(surface),
    shader: Some(shader),
    pipeline: Some(pipeline),
    vertex_buffer: None,
    vertex_buffer_capacity: 0UL,
    text_shader: Some(text_shader),
    text_pipeline: Some(text_pipeline),
    text_vertex_buffer: None,
    text_vertex_buffer_capacity: 0UL,
    text_atlas_texture: Some(text_atlas_texture),
    text_atlas_view: Some(text_atlas_view),
    text_sampler: Some(text_sampler),
    text_bind_group_layout: Some(text_bind_group_layout),
    text_pipeline_layout: Some(text_pipeline_layout),
    text_bind_group: Some(text_bind_group),
    font_cache: NativeFontCache::new(),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    text_vertices: [],
    text_atlas_dirty: true,
  }
}

///|
pub fn RendererHandle::resize(self : RendererHandle, size : @core.Size) -> Unit {
  self.size = size
  match (self.surface, self.adapter, self.device) {
    (Some(surface), Some(adapter), Some(device)) => {
      let usage = @wgpu.TextureUsage::from_u64(
        @wgpu.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu.TEXTURE_USAGE_COPY_SRC,
      )
      ignore(
        surface.configure_default(
          adapter,
          device,
          @render.size_dim_to_uint(size.width),
          @render.size_dim_to_uint(size.height),
          usage,
        ),
      )
      self.configured = true
    }
    _ => ()
  }
}

///|
pub fn RendererHandle::render(
  self : RendererHandle,
  commands : Array[@core.DrawCommand],
) -> Unit {
  self.last_batches = @render.collect_rect_batches(commands)
  let text = build_native_text_frame(
    self.font_cache,
    self.glyph_atlas,
    commands,
    self.size,
  )
  self.text_vertices = text.vertices
  self.text_atlas_dirty = text.atlas_dirty
  self.render_wgpu(commands)
}

///|
pub fn RendererHandle::dispose(self : RendererHandle) -> Unit {
  match self.vertex_buffer {
    Some(buffer) => buffer.release()
    None => ()
  }
  match self.text_vertex_buffer {
    Some(buffer) => buffer.release()
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
  match self.pipeline {
    Some(pipeline) => pipeline.release()
    None => ()
  }
  match self.shader {
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
  self.pipeline = None
  self.shader = None
  self.surface = None
  self.queue = None
  self.device = None
  self.adapter = None
  self.instance = None
  self.vertex_buffer = None
  self.vertex_buffer_capacity = 0UL
  self.text_vertex_buffer = None
  self.text_vertex_buffer_capacity = 0UL
  self.text_bind_group = None
  self.text_pipeline = None
  self.text_pipeline_layout = None
  self.text_bind_group_layout = None
  self.text_sampler = None
  self.text_atlas_view = None
  self.text_atlas_texture = None
  self.text_shader = None
  self.text_vertices = []
  self.text_atlas_dirty = false
  self.configured = false
}

///|
fn RendererHandle::render_wgpu(
  self : RendererHandle,
  commands : Array[@core.DrawCommand],
) -> Unit {
  match (self.surface, self.device, self.queue, self.pipeline) {
    (Some(surface), Some(device), Some(queue), Some(pipeline)) => {
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
        let encoder = device.create_command_encoder()
        let pass = encoder.begin_render_pass_color_clear(
          view,
          Float::from_double(clear.r),
          Float::from_double(clear.g),
          Float::from_double(clear.b),
          Float::from_double(clear.a),
        )
        if self.last_batches.length() > 0 {
          let vertices = @render.rect_batches_to_vertices(
            self.last_batches,
            self.size,
          )
          let vertex_bytes = @render.rect_vertices_to_bytes(vertices)
          self.ensure_vertex_buffer(device, vertex_bytes.length().to_uint64())
          match self.vertex_buffer {
            Some(buffer) => {
              queue.write_buffer(buffer, 0UL, vertex_bytes)
              pass.set_pipeline(pipeline)
              pass.set_vertex_buffer(
                0U,
                buffer,
                0UL,
                vertex_bytes.length().to_uint64(),
              )
              pass.draw(vertices.length().reinterpret_as_uint(), 1U, 0U, 0U)
            }
            None => ()
          }
        }
        if self.text_vertices.length() > 0 {
          match (self.text_pipeline, self.text_bind_group) {
            (Some(text_pipeline), Some(text_bind_group)) => {
              let vertex_bytes = text_vertices_to_bytes(self.text_vertices)
              self.ensure_text_vertex_buffer(
                device,
                vertex_bytes.length().to_uint64(),
              )
              match self.text_vertex_buffer {
                Some(buffer) => {
                  queue.write_buffer(buffer, 0UL, vertex_bytes)
                  pass.set_pipeline(text_pipeline)
                  pass.set_bind_group0(text_bind_group)
                  pass.set_vertex_buffer(
                    0U,
                    buffer,
                    0UL,
                    vertex_bytes.length().to_uint64(),
                  )
                  pass.draw(
                    self.text_vertices.length().reinterpret_as_uint(),
                    1U,
                    0U,
                    0U,
                  )
                }
                None => ()
              }
            }
            _ => ()
          }
        }
        pass.end()
        pass.release()
        let command_buffer = encoder.finish()
        queue.submit_one(command_buffer)
        ignore(surface.present())
        command_buffer.release()
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
fn RendererHandle::ensure_vertex_buffer(
  self : RendererHandle,
  device : @wgpu.Device,
  required : UInt64,
) -> Unit {
  if required == 0UL || self.vertex_buffer_capacity >= required {
    ()
  } else {
    match self.vertex_buffer {
      Some(buffer) => buffer.release()
      None => ()
    }
    let capacity = @render.grow_capacity(required)
    let usage = @wgpu.BufferUsage::from_u64(
      @wgpu.BUFFER_USAGE_VERTEX | @wgpu.BUFFER_USAGE_COPY_DST,
    )
    self.vertex_buffer = Some(device.create_buffer(size=capacity, usage~))
    self.vertex_buffer_capacity = capacity
  }
}

///|
fn RendererHandle::ensure_text_vertex_buffer(
  self : RendererHandle,
  device : @wgpu.Device,
  required : UInt64,
) -> Unit {
  if required == 0UL || self.text_vertex_buffer_capacity >= required {
    ()
  } else {
    match self.text_vertex_buffer {
      Some(buffer) => buffer.release()
      None => ()
    }
    let capacity = @render.grow_capacity(required)
    let usage = @wgpu.BufferUsage::from_u64(
      @wgpu.BUFFER_USAGE_VERTEX | @wgpu.BUFFER_USAGE_COPY_DST,
    )
    self.text_vertex_buffer = Some(device.create_buffer(size=capacity, usage~))
    self.text_vertex_buffer_capacity = capacity
  }
}

///|
fn create_rect_pipeline(
  device : @wgpu.Device,
  shader : @wgpu.ShaderModule,
  format : @wgpu.TextureFormat,
) -> @wgpu.RenderPipeline {
  let builder = try! @wgpu.RenderPipelineDescBuilder::new(shader)
  try! builder.set_color_target_format(format)
  try! builder.set_vertex_buffer_layout(24UL, @wgpu.VERTEX_STEP_MODE_VERTEX)
  try! builder.add_vertex_attribute(@wgpu.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu.VERTEX_FORMAT_FLOAT32X4, 8UL, 1U)
  try! builder.create_pipeline(device)
}

///|
fn create_text_pipeline(
  device : @wgpu.Device,
  shader : @wgpu.ShaderModule,
  format : @wgpu.TextureFormat,
  layout : @wgpu.PipelineLayout,
) -> @wgpu.RenderPipeline {
  let builder = try! @wgpu.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(32UL, @wgpu.VERTEX_STEP_MODE_VERTEX)
  try! builder.add_vertex_attribute(@wgpu.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.create_pipeline(device)
}
