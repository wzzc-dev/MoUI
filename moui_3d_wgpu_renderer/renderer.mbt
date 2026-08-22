///|
extern "C" fn wgpu_ptr_from_u64(value : UInt64) -> @wgpu_c.OpaquePtr = "moui_wgpu_ptr_from_u64"

///|
extern "C" fn wgpu_windows_hinstance() -> @wgpu_c.OpaquePtr = "moui_wgpu_windows_hinstance"

///|
priv struct Native3DRenderer {
  mut instance : @wgpu_mbt.Instance?
  mut adapter : @wgpu_mbt.Adapter?
  mut device : @wgpu_mbt.Device?
  mut queue : @wgpu_mbt.Queue?
  mut surface : @wgpu_mbt.Surface?
  mut depth_texture : @wgpu_mbt.Texture?
  mut depth_view : @wgpu_mbt.TextureView?
  mut shader : @wgpu_mbt.ShaderModule?
  mut pipeline : @wgpu_mbt.RenderPipeline?
  mut vertex_buffer : @wgpu_mbt.Buffer?
  mut vertex_payload : Bytes?
  mut upload_count : Int
  mut disposed : Bool
}

///|
fn Native3DRenderer::new(
  metrics : @core.SurfaceMetrics,
  platform : WgpuNative3DPlatform,
  native_surface : @moui_render.NativeSurface,
) -> Native3DRenderer raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let surface = match platform {
    WgpuNative3DPlatform::MacOS => {
      let descriptor = @wgpu_mbt.surface_descriptor_metal_layer_new(
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
      let result = instance.create_surface(descriptor)
      @wgpu_mbt.surface_descriptor_free(descriptor)
      result
    }
    WgpuNative3DPlatform::Windows =>
      instance.create_surface_windows_hwnd(
        wgpu_windows_hinstance(),
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
    WgpuNative3DPlatform::Linux =>
      instance.create_surface_wayland(
        wgpu_ptr_from_u64(native_surface.display_handle().unwrap()),
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
  }
  let adapter = instance.request_adapter_sync_options_surface_u32(surface)
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let format = surface.configure_default(
    adapter,
    device,
    physical_width(metrics),
    physical_height(metrics),
    @wgpu_mbt.TextureUsage::from_u64(@wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT),
  )
  let shader = device.create_shader_module_wgsl(native_3d_shader())
  let pipeline = create_native_3d_pipeline(device, shader, format)
  let (depth_texture, depth_view) = create_depth(device, metrics)
  {
    instance: Some(instance),
    adapter: Some(adapter),
    device: Some(device),
    queue: Some(queue),
    surface: Some(surface),
    depth_texture: Some(depth_texture),
    depth_view: Some(depth_view),
    shader: Some(shader),
    pipeline: Some(pipeline),
    vertex_buffer: None,
    vertex_payload: None,
    upload_count: 0,
    disposed: false,
  }
}

///|
fn physical_width(metrics : @core.SurfaceMetrics) -> UInt {
  let width = if metrics.physical_size.width > 0.0 {
    metrics.physical_size.width
  } else {
    metrics.logical_size.width * metrics.scale_factor
  }
  width.max(1.0).to_int().reinterpret_as_uint()
}

///|
fn physical_height(metrics : @core.SurfaceMetrics) -> UInt {
  let height = if metrics.physical_size.height > 0.0 {
    metrics.physical_size.height
  } else {
    metrics.logical_size.height * metrics.scale_factor
  }
  height.max(1.0).to_int().reinterpret_as_uint()
}

///|
fn create_depth(
  device : @wgpu_mbt.Device,
  metrics : @core.SurfaceMetrics,
) -> (@wgpu_mbt.Texture, @wgpu_mbt.TextureView) {
  let texture = device.create_texture_depth24plus_2d(
    physical_width(metrics),
    physical_height(metrics),
  )
  let view = texture.create_view()
  (texture, view)
}

///|
fn Native3DRenderer::resize(
  self : Native3DRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  match (self.surface, self.adapter, self.device) {
    (Some(surface), Some(adapter), Some(device)) => {
      ignore(
        surface.configure_default(
          adapter,
          device,
          physical_width(metrics),
          physical_height(metrics),
          @wgpu_mbt.TextureUsage::from_u64(
            @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT,
          ),
        ),
      )
      match self.depth_view {
        Some(view) => view.release()
        None => ()
      }
      match self.depth_texture {
        Some(texture) => {
          texture.destroy()
          texture.release()
        }
        None => ()
      }
      let (texture, view) = create_depth(device, metrics)
      self.depth_texture = Some(texture)
      self.depth_view = Some(view)
    }
    _ => ()
  }
}

///|
fn Native3DRenderer::render(
  self : Native3DRenderer,
  frame : @render.ThreeDFrame,
) -> @render.ThreeDRenderResult {
  if self.disposed {
    return @render.ThreeDRenderResult::Failed("native WGPU renderer disposed")
  }
  match
    (self.surface, self.device, self.queue, self.pipeline, self.depth_view) {
    (Some(surface), Some(device), Some(queue), Some(pipeline), Some(depth_view)) => {
      let current = surface.get_current_texture()
      if !current.is_success() {
        current.release()
        return @render.ThreeDRenderResult::Failed("surface acquire failed")
      }
      let texture = current.take_texture()
      current.release()
      let view = texture.create_view()
      let packet = frame.packet()
      let bytes = packet_vertices(packet)
      let upload_bytes = if bytes.length() == 0 {
        Bytes::from_array(Array::make(44, b'\x00'))
      } else {
        bytes
      }
      let buffer = match self.vertex_buffer {
        Some(value) if self.vertex_payload == Some(upload_bytes) => value
        _ => {
          match self.vertex_buffer {
            Some(value) => {
              value.destroy()
              value.release()
            }
            None => ()
          }
          let value = device.create_buffer(
            size=upload_bytes.length().to_uint64(),
            usage=@wgpu_mbt.BufferUsage::from_u64(
              @wgpu_mbt.BUFFER_USAGE_VERTEX | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
            ),
          )
          queue.write_buffer(value, 0UL, upload_bytes)
          self.vertex_buffer = Some(value)
          self.vertex_payload = Some(upload_bytes)
          self.upload_count = self.upload_count + 1
          value
        }
      }
      let encoder = device.create_command_encoder()
      let pass = encoder.begin_render_pass_color_depth_u32(
        view,
        depth_view,
        color_load_op_u32=2U,
        color_store_op_u32=1U,
        color_clear_r_f32=0.035,
        color_clear_g_f32=0.045,
        color_clear_b_f32=0.07,
        color_clear_a_f32=1.0,
        depth_load_op_u32=2U,
        depth_store_op_u32=1U,
        depth_clear_value_f32=1.0,
      )
      pass.set_pipeline(pipeline)
      pass.set_vertex_buffer(0U, buffer, 0UL, upload_bytes.length().to_uint64())
      pass.draw((bytes.length() / 44).reinterpret_as_uint(), 1U, 0U, 0U)
      pass.end()
      pass.release()
      let command_buffer = encoder.finish()
      queue.submit_one(command_buffer)
      ignore(surface.present())
      command_buffer.release()
      encoder.release()
      view.release()
      texture.release()
      @render.ThreeDRenderResult::Presented
    }
    _ =>
      @render.ThreeDRenderResult::Unavailable(
        "native WGPU device/surface/depth resources are unavailable",
      )
  }
}

///|
fn Native3DRenderer::dispose(self : Native3DRenderer) -> Unit {
  if self.disposed {
    return ()
  }
  self.disposed = true
  match self.depth_view {
    Some(value) => value.release()
    None => ()
  }
  match self.depth_texture {
    Some(value) => {
      value.destroy()
      value.release()
    }
    None => ()
  }
  match self.pipeline {
    Some(value) => value.release()
    None => ()
  }
  match self.vertex_buffer {
    Some(value) => {
      value.destroy()
      value.release()
    }
    None => ()
  }
  match self.shader {
    Some(value) => value.release()
    None => ()
  }
  match self.surface {
    Some(value) => value.release()
    None => ()
  }
  match self.queue {
    Some(value) => value.release()
    None => ()
  }
  match self.device {
    Some(value) => value.release()
    None => ()
  }
  match self.adapter {
    Some(value) => value.release()
    None => ()
  }
  match self.instance {
    Some(value) => value.release()
    None => ()
  }
  self.depth_view = None
  self.depth_texture = None
  self.pipeline = None
  self.vertex_buffer = None
  self.vertex_payload = None
  self.shader = None
  self.surface = None
  self.queue = None
  self.device = None
  self.adapter = None
  self.instance = None
}

///|
fn Native3DRenderer::to_session(
  self : Native3DRenderer,
) -> @render.ThreeDRendererSession {
  @render.ThreeDRendererSession::new(
    descriptor=@render.ThreeDRendererDescriptor::new(
      id="moui-3d-native-wgpu",
      backend=@render.ThreeDRendererBackend::NativeWgpu,
      status=@render.ThreeDRendererStatus::Available,
      description="Experimental WGPU forward pass with depth testing.",
    ),
    resize=size => {
      self.resize(
        @core.SurfaceMetrics::new(
          logical_size=@core.Size::new(
            width=size.width().to_double(),
            height=size.height().to_double(),
          ),
          physical_size=@core.Size::new(
            width=size.width().to_double() * size.scale_factor(),
            height=size.height().to_double() * size.scale_factor(),
          ),
          scale_factor=size.scale_factor(),
        ),
      )
    },
    render=frame => self.render(frame),
    dispose=() => self.dispose(),
  )
}

///|
fn packet_vertices(packet : @render.ThreeDRenderPacket) -> Bytes {
  let bytes : Array[Byte] = []
  for item in packet.items() {
    let mvp = packet.projection().mul(packet.view()).mul(item.model())
    let vertices = item.vertices()
    for index in item.indices() {
      match vertices.get(index) {
        Some(vertex) => {
          let world_position = item
            .model()
            .transform_homogeneous(vertex.position())
          let clip = mvp.transform_homogeneous(vertex.position())
          let normal = item
            .model()
            .transform_point(vertex.position().add(vertex.normal()))
            .sub(
              @moui_3d.Vec3::new(
                x=world_position.x,
                y=world_position.y,
                z=world_position.z,
              ),
            )
            .normalized()
          let light = normal
            .dot(@moui_3d.Vec3::new(x=0.35, y=0.8, z=0.5).normalized())
            .max(0.18)
          push_f32(bytes, clip.x)
          push_f32(bytes, clip.y)
          push_f32(bytes, clip.z)
          push_f32(bytes, clip.w)
          push_f32(bytes, normal.x())
          push_f32(bytes, normal.y())
          push_f32(bytes, normal.z())
          push_f32(bytes, item.base_color().x() * light)
          push_f32(bytes, item.base_color().y() * light)
          push_f32(bytes, item.base_color().z() * light)
          push_f32(bytes, item.base_color().w())
        }
        None => ()
      }
    }
  }
  Bytes::from_array(bytes)
}

///|
fn push_f32(out : Array[Byte], value : Double) -> Unit {
  let bits = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn create_native_3d_pipeline(
  device : @wgpu_mbt.Device,
  shader : @wgpu_mbt.ShaderModule,
  format : @wgpu_mbt.TextureFormat,
) -> @wgpu_mbt.RenderPipeline {
  let builder = try! @wgpu_mbt.RenderPipelineDescBuilder::new(shader)
  try! builder.set_color_target_format(format)
  try! builder.set_depth_stencil(
    @wgpu_mbt.TextureFormat::from_u32(@wgpu_mbt.TEXTURE_FORMAT_DEPTH24_PLUS),
    depth_write_enabled=true,
    depth_compare_u32=@wgpu_mbt.COMPARE_FUNCTION_LESS,
  )
  try! builder.set_cull_mode_u32(@wgpu_mbt.CULL_MODE_BACK)
  try! builder.set_topology_u32(@wgpu_mbt.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)
  try! builder.set_vertex_buffer_layout(44UL, @wgpu_mbt.VERTEX_STEP_MODE_VERTEX)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 0UL, 0U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X3, 16UL, 1U)
  try! builder.add_vertex_attribute(@wgpu_mbt.VERTEX_FORMAT_FLOAT32X4, 28UL, 2U)
  try! builder.create_pipeline(device)
}

///|
fn native_3d_shader() -> String {
  (
    #|struct Out { @builtin(position) position: vec4<f32>, @location(0) color: vec4<f32> };
    #|@vertex fn vs_main(@location(0) clip_position: vec4<f32>, @location(1) normal: vec3<f32>, @location(2) color: vec4<f32>) -> Out {
    #|  var out: Out;
    #|  out.position = clip_position;
    #|  out.color = color;
    #|  return out;
    #|}
    #|@fragment fn fs_main(in: Out) -> @location(0) vec4<f32> { return in.color; }
  )
}
