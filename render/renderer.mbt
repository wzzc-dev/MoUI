///|
pub(all) struct RectBatch {
  rect : @core.Rect
  color : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub struct RendererHandle {
  mut size : @core.Size
  mut last_batches : Array[RectBatch]
  mut configured : Bool
  mut present_count : Int
  priv mut instance : @wgpu.Instance?
  priv mut adapter : @wgpu.Adapter?
  priv mut device : @wgpu.Device?
  priv mut queue : @wgpu.Queue?
  priv mut surface : @wgpu.Surface?
  priv mut shader : @wgpu.ShaderModule?
  priv mut pipeline : @wgpu.RenderPipeline?
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
  }
}

///|
pub fn RendererHandle::create(
  size : @core.Size,
) -> RendererHandle raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_metal_layer()
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let usage = @wgpu.TextureUsage::from_u64(
    @wgpu.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu.TEXTURE_USAGE_COPY_SRC,
  )
  let format = surface.configure_default(
    adapter,
    device,
    size_dim_to_uint(size.width),
    size_dim_to_uint(size.height),
    usage,
  )
  let shader = device.create_shader_module_wgsl(rect_shader_wgsl())
  let pipeline = device.create_render_pipeline_color_format(shader, format)
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
          size_dim_to_uint(size.width),
          size_dim_to_uint(size.height),
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
  self.last_batches = collect_rect_batches(commands)
  self.render_wgpu(commands)
}

///|
pub fn RendererHandle::dispose(self : RendererHandle) -> Unit {
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
  self.configured = false
}

///|
pub fn collect_rect_batches(
  commands : Array[@core.DrawCommand],
) -> Array[RectBatch] {
  let batches : Array[RectBatch] = []
  for command in commands {
    match command {
      @core.DrawCommand::FillRect(rect, color) => batches.push({ rect, color })
      @core.DrawCommand::Clear(_)
      | @core.DrawCommand::PushClip(_)
      | @core.DrawCommand::PopClip => ()
    }
  }
  batches
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
        let clear = first_clear_color(commands)
        let encoder = device.create_command_encoder()
        let pass = encoder.begin_render_pass_color_clear(
          view,
          Float::from_double(clear.r),
          Float::from_double(clear.g),
          Float::from_double(clear.b),
          Float::from_double(clear.a),
        )
        if self.last_batches.length() > 0 {
          pass.set_pipeline(pipeline)
          pass.draw(3U, 1U, 0U, 0U)
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
fn first_clear_color(commands : Array[@core.DrawCommand]) -> @core.Color {
  let mut clear = @core.Color::white()
  let mut found = false
  for command in commands {
    if !found {
      match command {
        @core.DrawCommand::Clear(color) => {
          clear = color
          found = true
        }
        _ => ()
      }
    }
  }
  clear
}

///|
fn size_dim_to_uint(value : Double) -> UInt {
  if value < 1.0 {
    1U
  } else {
    value.to_int().reinterpret_as_uint()
  }
}
