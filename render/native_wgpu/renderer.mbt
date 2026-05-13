///|
extern "C" fn win32_hinstance() -> @wgpu_c.OpaquePtr = "moui_win32_hinstance"

///|
extern "C" fn win32_hwnd_from_u64(hwnd : UInt64) -> @wgpu_c.OpaquePtr = "moui_win32_hwnd_from_u64"

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
  }
}

///|
pub fn RendererHandle::create(
  size : @core.Size,
) -> RendererHandle raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_metal_layer()
  create_with_surface(size, instance, surface)
}

///|
pub fn RendererHandle::create_for_windows_hwnd(
  size : @core.Size,
  hwnd : UInt64,
) -> RendererHandle raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_windows_hwnd(
    win32_hinstance(),
    win32_hwnd_from_u64(hwnd),
  )
  create_with_surface(size, instance, surface)
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
  self.render_wgpu(commands)
}

///|
pub fn RendererHandle::dispose(self : RendererHandle) -> Unit {
  match self.vertex_buffer {
    Some(buffer) => buffer.release()
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
