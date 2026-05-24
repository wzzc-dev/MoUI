///|
priv struct ImageVertex {
  x : Double
  y : Double
  u : Double
  v : Double
  opacity : Double
}

///|
priv struct NativeImagePlacement {
  frame : @core.Rect
  u0 : Double
  v0 : Double
  u1 : Double
  v1 : Double
}

///|
priv struct NativeDecodedImage {
  width : Int
  height : Int
  data : Bytes
}

///|
priv struct NativeImageResource {
  width : Int
  height : Int
  texture : @wgpu_mbt.Texture
  view : @wgpu_mbt.TextureView
  bind_group : @wgpu_mbt.BindGroup
}

///|
fn calculate_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> NativeImagePlacement {
  if image_size.width <= 0.0 ||
    image_size.height <= 0.0 ||
    frame.size.width <= 0.0 ||
    frame.size.height <= 0.0 {
    return { frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
  }
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame.size.width / frame.size.height

  match fit {
    @core.ImageFit::Contain =>
      if image_ratio > frame_ratio {
        let scaled_height = frame.size.width / image_ratio
        let offset_y = (frame.size.height - scaled_height) / 2.0
        {
          frame: @core.Rect::new(
            x=frame.origin.x,
            y=frame.origin.y + offset_y,
            width=frame.size.width,
            height=scaled_height,
          ),
          u0: 0.0,
          v0: 0.0,
          u1: 1.0,
          v1: 1.0,
        }
      } else {
        let scaled_width = frame.size.height * image_ratio
        let offset_x = (frame.size.width - scaled_width) / 2.0
        {
          frame: @core.Rect::new(
            x=frame.origin.x + offset_x,
            y=frame.origin.y,
            width=scaled_width,
            height=frame.size.height,
          ),
          u0: 0.0,
          v0: 0.0,
          u1: 1.0,
          v1: 1.0,
        }
      }
    @core.ImageFit::Cover =>
      if image_ratio > frame_ratio {
        let visible = frame_ratio / image_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
      } else {
        let visible = image_ratio / frame_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
      }
  }
}

///|
fn generate_image_vertices(
  frame : @core.Rect,
  transform : @core.Transform2D,
  u0 : Double,
  v0 : Double,
  u1 : Double,
  v1 : Double,
  opacity : Double,
  screen_size : @core.Size,
) -> Array[ImageVertex] {
  let x0 = frame.origin.x
  let y0 = frame.origin.y
  let x1 = frame.origin.x + frame.size.width
  let y1 = frame.origin.y + frame.size.height

  let vertices : Array[ImageVertex] = []

  push_image_vertex(vertices, transform, x0, y0, u0, v0, opacity, screen_size)
  push_image_vertex(vertices, transform, x0, y1, u0, v1, opacity, screen_size)
  push_image_vertex(vertices, transform, x1, y1, u1, v1, opacity, screen_size)
  push_image_vertex(vertices, transform, x0, y0, u0, v0, opacity, screen_size)
  push_image_vertex(vertices, transform, x1, y1, u1, v1, opacity, screen_size)
  push_image_vertex(vertices, transform, x1, y0, u1, v0, opacity, screen_size)

  vertices
}

///|
fn push_image_vertex(
  vertices : Array[ImageVertex],
  transform : @core.Transform2D,
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  opacity : Double,
  screen_size : @core.Size,
) -> Unit {
  let point = transform_point(transform, x, y)
  vertices.push({
    x: visual_pixel_x_to_ndc(point.x, screen_size.width),
    y: visual_pixel_y_to_ndc(point.y, screen_size.height),
    u,
    v,
    opacity,
  })
}

///|
fn load_native_image_data(source : String) -> NativeDecodedImage? {
  match native_image_source_bytes(source) {
    Some(bytes) => decode_native_image_bytes(bytes)
    None => None
  }
}

///|
fn native_image_source_bytes(source : String) -> Bytes? {
  if source.has_prefix("data:") {
    native_image_data_uri_bytes(source)
  } else if @fs.path_exists(source) {
    Some(@fs.read_file_to_bytes(source)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
fn native_image_data_uri_bytes(source : String) -> Bytes? {
  let parts = source.split(",").to_array()
  if parts.length() < 2 {
    return None
  }
  let meta = parts[0]
  if !meta.has_prefix("data:") || !meta.contains(";base64") {
    return None
  }
  Some(@base64.decode(parts[1], ignore_whitespace=true)) catch {
    _ => None
  }
}

///|
fn decode_native_image_bytes(bytes : Bytes) -> NativeDecodedImage? {
  let decoded = if native_bytes_are_png(bytes) {
    Some(@image.decode_png(bytes)) catch {
      _ => None
    }
  } else if native_bytes_are_jpeg(bytes) {
    Some(@image.decode_jpeg(bytes)) catch {
      _ => None
    }
  } else if native_bytes_are_bmp(bytes) {
    Some(@image.decode_bmp(bytes)) catch {
      _ => None
    }
  } else {
    None
  }
  match decoded {
    Some(image) =>
      Some({ width: image.width, height: image.height, data: image.data })
    None => None
  }
}

///|
fn native_bytes_are_png(bytes : Bytes) -> Bool {
  bytes.length() >= 8 &&
  bytes[0] == b'\x89' &&
  bytes[1] == b'\x50' &&
  bytes[2] == b'\x4E' &&
  bytes[3] == b'\x47' &&
  bytes[4] == b'\x0D' &&
  bytes[5] == b'\x0A' &&
  bytes[6] == b'\x1A' &&
  bytes[7] == b'\x0A'
}

///|
fn native_bytes_are_jpeg(bytes : Bytes) -> Bool {
  bytes.length() >= 3 &&
  bytes[0] == b'\xFF' &&
  bytes[1] == b'\xD8' &&
  bytes[2] == b'\xFF'
}

///|
fn native_bytes_are_bmp(bytes : Bytes) -> Bool {
  bytes.length() >= 2 && bytes[0] == b'\x42' && bytes[1] == b'\x4D'
}

///|
fn RendererHandle::ensure_native_image_resource(
  self : RendererHandle,
  source : String,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
) -> NativeImageResource? {
  match self.image_cache.get(source) {
    Some(resource) => return Some(resource)
    None => ()
  }
  if self.failed_images.get(source).unwrap_or(false) {
    return None
  }
  guard load_native_image_data(source) is Some(image) else {
    self.failed_images[source] = true
    return None
  }
  match (self.image_bind_group_layout, self.image_sampler) {
    (Some(layout), Some(sampler)) => {
      let usage = @wgpu_mbt.TextureUsage::from_u64(
        @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING |
        @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
      )
      let texture = device.create_texture_rgba8_2d_with_usage(
        image.width.reinterpret_as_uint(),
        image.height.reinterpret_as_uint(),
        usage,
      )
      queue.write_texture_rgba8_2d(
        texture,
        image.width.reinterpret_as_uint(),
        image.height.reinterpret_as_uint(),
        image.data,
      )
      let view = texture.create_view()
      let bind_group = device.create_bind_group_sampler_texture_2d(
        layout, sampler, view,
      )
      let resource = {
        width: image.width,
        height: image.height,
        texture,
        view,
        bind_group,
      }
      self.image_cache[source] = resource
      Some(resource)
    }
    _ => None
  }
}

///|
fn RendererHandle::prepare_native_image_items(
  self : RendererHandle,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
) -> Unit {
  let items : Array[NativeDrawItem] = []
  self.image_vertices = []
  for item in self.draw_items {
    match item {
      NativeDrawItem::NativeImage(_, _, scissor, run) =>
        match self.ensure_native_image_resource(run.source, device, queue) {
          Some(resource) => {
            let start = self.image_vertices.length()
            append_prepared_image_vertices(
              self.image_vertices,
              run,
              resource,
              self.size,
            )
            items.push(
              NativeDrawItem::NativeImage(
                start,
                self.image_vertices.length() - start,
                scissor,
                run,
              ),
            )
          }
          None => {
            let start = self.visual_vertices.length()
            append_visual_quad(
              self.visual_vertices,
              run.frame,
              radius=0.0,
              brush=native_image_placeholder_brush(run),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              state={
                opacity: 1.0,
                transform: run.transform,
                clip: None,
                clip_radius: 0.0,
                clip_empty: false,
              },
              size=self.size,
            )
            items.push(
              NativeDrawItem::NativeVisual(
                start,
                self.visual_vertices.length() - start,
                scissor,
              ),
            )
          }
        }
      NativeDrawItem::NativeLayer(layer) => {
        self.prepare_native_image_plan(layer.plan, device, queue)
        items.push(NativeDrawItem::NativeLayer(layer))
      }
      NativeDrawItem::NativeShaderEffect(_) => items.push(item)
      _ => items.push(item)
    }
  }
  self.draw_items = items
}

///|
fn RendererHandle::prepare_native_image_plan(
  self : RendererHandle,
  plan : NativeDrawPlan,
  device : @wgpu_mbt.Device,
  queue : @wgpu_mbt.Queue,
) -> Unit {
  let items : Array[NativeDrawItem] = []
  plan.image_vertices.clear()
  for item in plan.items {
    match item {
      NativeDrawItem::NativeImage(_, _, scissor, run) =>
        match self.ensure_native_image_resource(run.source, device, queue) {
          Some(resource) => {
            let start = plan.image_vertices.length()
            append_prepared_image_vertices(
              plan.image_vertices,
              run,
              resource,
              self.size,
            )
            items.push(
              NativeDrawItem::NativeImage(
                start,
                plan.image_vertices.length() - start,
                scissor,
                run,
              ),
            )
          }
          None => {
            let start = plan.visual_vertices.length()
            append_visual_quad(
              plan.visual_vertices,
              run.frame,
              radius=0.0,
              brush=native_image_placeholder_brush(run),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              state={
                opacity: 1.0,
                transform: run.transform,
                clip: None,
                clip_radius: 0.0,
                clip_empty: false,
              },
              size=self.size,
            )
            items.push(
              NativeDrawItem::NativeVisual(
                start,
                plan.visual_vertices.length() - start,
                scissor,
              ),
            )
          }
        }
      NativeDrawItem::NativeLayer(layer) => {
        self.prepare_native_image_plan(layer.plan, device, queue)
        items.push(NativeDrawItem::NativeLayer(layer))
      }
      _ => items.push(item)
    }
  }
  plan.items.clear()
  for item in items {
    plan.items.push(item)
  }
}

///|
fn append_prepared_image_vertices(
  vertices : Array[ImageVertex],
  run : NativeImageRun,
  resource : NativeImageResource,
  screen_size : @core.Size,
) -> Unit {
  let placement = calculate_image_placement(
    run.frame,
    @core.Size::new(
      width=resource.width.to_double(),
      height=resource.height.to_double(),
    ),
    run.fit,
  )
  for
    vertex in generate_image_vertices(
      placement.frame,
      run.transform,
      placement.u0,
      placement.v0,
      placement.u1,
      placement.v1,
      run.opacity,
      screen_size,
    ) {
    vertices.push(vertex)
  }
}

///|
fn NativeImageResource::release(self : NativeImageResource) -> Unit {
  self.bind_group.release()
  self.view.release()
  self.texture.destroy()
  self.texture.release()
}

///|
fn native_image_placeholder_brush(run : NativeImageRun) -> @core.Brush {
  @core.Brush::linear_gradient(
    start=run.frame.origin,
    end=@core.Point::new(
      x=run.frame.origin.x + run.frame.size.width,
      y=run.frame.origin.y + run.frame.size.height,
    ),
    start_color=@core.Color::rgba(r=0.72, g=0.78, b=0.86, a=run.opacity),
    end_color=@core.Color::rgba(r=0.42, g=0.50, b=0.62, a=run.opacity),
  )
}

///|
fn image_vertices_to_bytes(vertices : Array[ImageVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.u)
    push_visual_f32le(out, vertex.v)
    push_visual_f32le(out, vertex.opacity)
  }
  Bytes::from_array(out)
}

///|
fn image_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) opacity: f32,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) opacity: f32,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.opacity = opacity;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var image_sampler : sampler;
    #|@group(0) @binding(1) var image_texture : texture_2d<f32>;
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let sample = textureSample(image_texture, image_sampler, in.uv);
    #|  return vec4<f32>(sample.rgb, sample.a * in.opacity);
    #|}
    #|
  shader
}

///|
let image_vertex_stride : UInt64 = 20UL
