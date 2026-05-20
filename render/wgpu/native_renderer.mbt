///|
struct RendererHandle {
  mut size : @core.Size
  mut physical_size : @core.Size
  mut scale_factor : Double
  mut last_batches : Array[@render.RectBatch]
  mut configured : Bool
  mut present_count : Int
  mut instance : @wgpu_mbt.Instance?
  mut adapter : @wgpu_mbt.Adapter?
  mut device : @wgpu_mbt.Device?
  mut queue : @wgpu_mbt.Queue?
  mut surface : @wgpu_mbt.Surface?
  mut visual_shader : @wgpu_mbt.ShaderModule?
  mut visual_pipeline : @wgpu_mbt.RenderPipeline?
  mut visual_vertex_buffer : @wgpu_mbt.Buffer?
  mut visual_vertex_buffer_capacity : UInt64
  mut text_shader : @wgpu_mbt.ShaderModule?
  mut text_pipeline : @wgpu_mbt.RenderPipeline?
  mut text_vertex_buffer : @wgpu_mbt.Buffer?
  mut text_vertex_buffer_capacity : UInt64
  mut text_atlas_texture : @wgpu_mbt.Texture?
  mut text_atlas_view : @wgpu_mbt.TextureView?
  mut text_sampler : @wgpu_mbt.Sampler?
  mut text_bind_group_layout : @wgpu_mbt.BindGroupLayout?
  mut text_pipeline_layout : @wgpu_mbt.PipelineLayout?
  mut text_bind_group : @wgpu_mbt.BindGroup?
  mut image_pipeline : NativeImagePipeline?
  font_cache : NativeFontCache
  glyph_atlas : GlyphAtlas
  mut visual_vertices : Array[VisualVertex]
  mut text_vertices : Array[TextVertex]
  mut draw_items : Array[NativeDrawItem]
  mut text_atlas_dirty : Bool
  mut unsupported_command_count : Int
}

///|
fn RendererHandle::create_with_host_surface(
  metrics : @render.RendererSurfaceMetrics,
  host_surface : HostWgpuSurface,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  create_with_surface(metrics, host_surface.instance, host_surface.surface)
}

///|
fn create_with_surface(
  metrics : @render.RendererSurfaceMetrics,
  instance : @wgpu_mbt.Instance,
  surface : @wgpu_mbt.Surface,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
  )
  let format = surface.configure_default(
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
  let image_pipeline = NativeImagePipeline::new(device, format)
  {
    size: metrics.logical_size,
    physical_size: metrics.physical_size,
    scale_factor: metrics.scale_factor,
    last_batches: [],
    configured: true,
    present_count: 0,
    instance: Some(instance),
    adapter: Some(adapter),
    device: Some(device),
    queue: Some(queue),
    surface: Some(surface),
    visual_shader: Some(visual_shader),
    visual_pipeline: Some(visual_pipeline),
    visual_vertex_buffer: None,
    visual_vertex_buffer_capacity: 0UL,
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
    image_pipeline: Some(image_pipeline),
    font_cache: NativeFontCache::new(),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    visual_vertices: [],
    text_vertices: [],
    draw_items: [],
    text_atlas_dirty: true,
    unsupported_command_count: 0,
  }
}

///|
fn RendererHandle::resize(
  self : RendererHandle,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit {
  self.size = metrics.logical_size
  self.physical_size = metrics.physical_size
  self.scale_factor = metrics.scale_factor
  let physical_size = self.effective_physical_size()
  match (self.surface, self.adapter, self.device) {
    (Some(surface), Some(adapter), Some(device)) => {
      let usage = @wgpu_mbt.TextureUsage::from_u64(
        @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT |
        @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
      )
      ignore(
        surface.configure_default(
          adapter,
          device,
          @render.size_dim_to_uint(physical_size.width),
          @render.size_dim_to_uint(physical_size.height),
          usage,
        ),
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
  let plan = build_native_draw_plan(
    self.font_cache,
    self.glyph_atlas,
    commands,
    self.size,
    self.scale_factor,
  )
  self.visual_vertices = plan.visual_vertices
  self.text_vertices = plan.text_vertices
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
  self.visual_vertex_buffer_capacity = 0UL
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
  self.visual_vertices = []
  self.text_vertices = []
  self.draw_items = []
  self.text_atlas_dirty = false
  self.unsupported_command_count = 0
  self.configured = false
}

///|
fn count_native_unsupported_commands(
  commands : Array[@core.DrawCommand],
) -> Int {
  let _ = commands
  0
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
        let encoder = device.create_command_encoder()
        let pass = encoder.begin_render_pass_color_clear(
          view,
          Float::from_double(clear.r),
          Float::from_double(clear.g),
          Float::from_double(clear.b),
          Float::from_double(clear.a),
        )
        if self.visual_vertices.length() > 0 {
          let vertex_bytes = visual_vertices_to_bytes(self.visual_vertices)
          self.ensure_visual_vertex_buffer(
            device,
            vertex_bytes.length().to_uint64(),
          )
          match self.visual_vertex_buffer {
            Some(buffer) => queue.write_buffer(buffer, 0UL, vertex_bytes)
            None => ()
          }
        }
        if self.text_vertices.length() > 0 {
          match self.text_pipeline {
            Some(_) => {
              let vertex_bytes = text_vertices_to_bytes(self.text_vertices)
              self.ensure_text_vertex_buffer(
                device,
                vertex_bytes.length().to_uint64(),
              )
              match self.text_vertex_buffer {
                Some(buffer) => {
                  queue.write_buffer(buffer, 0UL, vertex_bytes)
                  ignore(buffer)
                }
                None => ()
              }
            }
            _ => ()
          }
        }
        self.draw_plan_items(pass, visual_pipeline)
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
fn RendererHandle::draw_plan_items(
  self : RendererHandle,
  pass : @wgpu_mbt.RenderPass,
  visual_pipeline : @wgpu_mbt.RenderPipeline,
) -> Unit {
  self.apply_scissor(pass, None)
  for item in self.draw_items {
    match item {
      NativeDrawItem::NativeVisual(start, count, scissor) =>
        match self.visual_vertex_buffer {
          Some(buffer) => {
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(visual_pipeline)
            pass.set_vertex_buffer(
              0U,
              buffer,
              0UL,
              self.visual_vertex_buffer_capacity,
            )
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
        match
          (self.text_pipeline, self.text_bind_group, self.text_vertex_buffer) {
          (Some(text_pipeline), Some(text_bind_group), Some(buffer)) => {
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(text_pipeline)
            pass.set_bind_group0(text_bind_group)
            pass.set_vertex_buffer(
              0U,
              buffer,
              0UL,
              self.text_vertex_buffer_capacity,
            )
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
        match self.visual_vertex_buffer {
          Some(buffer) => {
            ignore(run.source)
            ignore(run.frame)
            ignore(run.opacity)
            ignore(run.fit)
            self.apply_scissor(pass, scissor)
            pass.set_pipeline(visual_pipeline)
            pass.set_vertex_buffer(
              0U,
              buffer,
              0UL,
              self.visual_vertex_buffer_capacity,
            )
            pass.draw(
              count.reinterpret_as_uint(),
              1U,
              start.reinterpret_as_uint(),
              0U,
            )
          }
          None => ()
        }
    }
  }
  self.apply_scissor(pass, None)
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
fn RendererHandle::ensure_visual_vertex_buffer(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
  required : UInt64,
) -> Unit {
  if required == 0UL || self.visual_vertex_buffer_capacity >= required {
    ()
  } else {
    match self.visual_vertex_buffer {
      Some(buffer) => buffer.release()
      None => ()
    }
    let capacity = @render.grow_capacity(required)
    let usage = @wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    )
    self.visual_vertex_buffer = Some(
      device.create_buffer(size=capacity, usage~),
    )
    self.visual_vertex_buffer_capacity = capacity
  }
}

///|
fn RendererHandle::ensure_text_vertex_buffer(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
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
    let usage = @wgpu_mbt.BufferUsage::from_u64(
      @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
    )
    self.text_vertex_buffer = Some(device.create_buffer(size=capacity, usage~))
    self.text_vertex_buffer_capacity = capacity
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
fn create_text_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
  layout : @wgpu_mbt.PipelineLayout,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader, layout~)
  try! builder.set_color_target_format(format)
  try! builder.enable_alpha_blend()
  try! builder.set_vertex_buffer_layout(32UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X2, 8UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 16UL, 2U)
  try! builder.create_pipeline(device)
}
