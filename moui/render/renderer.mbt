///|
pub(all) enum RendererBackendKind {
  NativeWgpu
  WebGpuWasm
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererCapabilityStatus {
  Ready
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererSurfaceMetrics {
  logical_size : @core.Size
  physical_size : @core.Size
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RendererBackendInfo {
  backend : RendererBackendKind
  status : RendererCapabilityStatus
  can_render : Bool
  can_resize : Bool
  owns_surface : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WgpuSurfaceSourceKind {
  NativeHostSurface
  WebCanvasSurface
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WgpuSurfaceContract {
  source : WgpuSurfaceSourceKind
  backend : RendererBackendKind
  ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn RendererSurfaceMetrics::new(
  logical_size~ : @core.Size,
  physical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> RendererSurfaceMetrics {
  { logical_size, physical_size, scale_factor }
}

///|
pub fn RendererSurfaceMetrics::from_logical(
  size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> RendererSurfaceMetrics {
  {
    logical_size: size,
    physical_size: @core.Size::new(
      width=size.width * scale_factor,
      height=size.height * scale_factor,
    ),
    scale_factor,
  }
}

///|
pub fn RendererBackendInfo::new(
  backend~ : RendererBackendKind,
  status~ : RendererCapabilityStatus,
  can_render~ : Bool,
  can_resize~ : Bool,
  owns_surface~ : Bool,
  description? : String = "",
) -> RendererBackendInfo {
  { backend, status, can_render, can_resize, owns_surface, description }
}

///|
pub fn WgpuSurfaceContract::new(
  source~ : WgpuSurfaceSourceKind,
  backend~ : RendererBackendKind,
  ready~ : Bool,
  description? : String = "",
) -> WgpuSurfaceContract {
  { source, backend, ready, description }
}

///|
pub(all) struct RectBatch {
  rect : @core.Rect
  color : @core.Color
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RectVertex {
  x : Double
  y : Double
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Debug, ToJson)

///|
pub fn collect_rect_batches(
  commands : Array[@core.DrawCommand],
) -> Array[RectBatch] {
  let batches : Array[RectBatch] = []
  for command in commands {
    match command {
      @core.DrawCommand::FillRect(rect, color) => batches.push({ rect, color })
      @core.DrawCommand::FillRoundedRect(rounded, color) =>
        batches.push({ rect: rounded.rect, color })
      @core.DrawCommand::StrokeRect(rect, color, width) =>
        append_stroke_rect_batches(batches, rect, color, width)
      @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
        append_stroke_rect_batches(batches, rounded.rect, color, width)
      @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
        batches.push({ rect: rounded.rect, color: brush_fallback_color(brush) })
      @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
        append_stroke_rect_batches(
          batches,
          rounded.rect,
          brush_fallback_color(brush),
          width,
        )
      @core.DrawCommand::DrawShadow(shadow) =>
        append_shadow_batches(batches, shadow)
      @core.DrawCommand::Clear(_)
      | @core.DrawCommand::DrawText(_)
      | @core.DrawCommand::DrawImage(_)
      | @core.DrawCommand::PushClip(_)
      | @core.DrawCommand::PopClip
      | @core.DrawCommand::PushRoundedClip(_)
      | @core.DrawCommand::PopRoundedClip
      | @core.DrawCommand::PushTransform(_)
      | @core.DrawCommand::PopTransform
      | @core.DrawCommand::PushOpacity(_)
      | @core.DrawCommand::PopOpacity
      | @core.DrawCommand::PushLayer(_)
      | @core.DrawCommand::PopLayer
      | @core.DrawCommand::PushFilter(_)
      | @core.DrawCommand::PopFilter
      | @core.DrawCommand::DrawPath(_)
      | @core.DrawCommand::DrawShaderEffect(_) => ()
    }
  }
  batches
}

///|
fn brush_fallback_color(brush : @core.Brush) -> @core.Color {
  match brush {
    @core.Brush::Solid(color) => color
    @core.Brush::LinearGradient(gradient) => gradient.start_color
  }
}

///|
fn append_shadow_batches(
  batches : Array[RectBatch],
  shadow : @core.ShadowSpec,
) -> Unit {
  let layers = 3
  for index in 0..<layers {
    let grow = shadow.spread +
      (index + 1).to_double() * shadow.blur_radius / 3.0
    let alpha = shadow.color.a / (index + 2).to_double()
    batches.push({
      rect: @core.Rect::new(
        x=shadow.rect.rect.origin.x + shadow.offset.x - grow,
        y=shadow.rect.rect.origin.y + shadow.offset.y - grow,
        width=shadow.rect.rect.size.width + grow * 2.0,
        height=shadow.rect.rect.size.height + grow * 2.0,
      ),
      color: @core.Color::rgba(
        r=shadow.color.r,
        g=shadow.color.g,
        b=shadow.color.b,
        a=alpha,
      ),
    })
  }
}

///|
fn append_stroke_rect_batches(
  batches : Array[RectBatch],
  rect : @core.Rect,
  color : @core.Color,
  width : Double,
) -> Unit {
  if width <= 0.0 || rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    return
  }
  let stroke_width = clamp_stroke_width(width, rect)
  let x = rect.origin.x
  let y = rect.origin.y
  let w = rect.size.width
  let h = rect.size.height
  batches.push({
    rect: @core.Rect::new(x~, y~, width=w, height=stroke_width),
    color,
  })
  batches.push({
    rect: @core.Rect::new(
      x~,
      y=y + h - stroke_width,
      width=w,
      height=stroke_width,
    ),
    color,
  })
  if h > stroke_width * 2.0 {
    batches.push({
      rect: @core.Rect::new(
        x~,
        y=y + stroke_width,
        width=stroke_width,
        height=h - stroke_width * 2.0,
      ),
      color,
    })
    batches.push({
      rect: @core.Rect::new(
        x=x + w - stroke_width,
        y=y + stroke_width,
        width=stroke_width,
        height=h - stroke_width * 2.0,
      ),
      color,
    })
  }
}

///|
fn clamp_stroke_width(width : Double, rect : @core.Rect) -> Double {
  let max_width = rect.size.width.min(rect.size.height) / 2.0
  if width > max_width {
    max_width
  } else {
    width
  }
}

///|
pub fn rect_batches_to_vertices(
  batches : Array[RectBatch],
  size : @core.Size,
) -> Array[RectVertex] {
  let vertices : Array[RectVertex] = []
  for batch in batches {
    append_rect_vertices(vertices, batch, size)
  }
  vertices
}

///|
pub fn rect_vertices_to_bytes(vertices : Array[RectVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_f32le(out, vertex.x)
    push_f32le(out, vertex.y)
    push_f32le(out, vertex.r)
    push_f32le(out, vertex.g)
    push_f32le(out, vertex.b)
    push_f32le(out, vertex.a)
  }
  Bytes::from_array(out)
}

///|
pub fn first_clear_color(commands : Array[@core.DrawCommand]) -> @core.Color {
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
fn append_rect_vertices(
  vertices : Array[RectVertex],
  batch : RectBatch,
  size : @core.Size,
) -> Unit {
  let rect = batch.rect
  let color = batch.color
  let x0 = pixel_x_to_ndc(rect.origin.x, size.width)
  let x1 = pixel_x_to_ndc(rect.origin.x + rect.size.width, size.width)
  let y0 = pixel_y_to_ndc(rect.origin.y, size.height)
  let y1 = pixel_y_to_ndc(rect.origin.y + rect.size.height, size.height)
  push_vertex(vertices, x0, y0, color)
  push_vertex(vertices, x0, y1, color)
  push_vertex(vertices, x1, y1, color)
  push_vertex(vertices, x0, y0, color)
  push_vertex(vertices, x1, y1, color)
  push_vertex(vertices, x1, y0, color)
}

///|
fn push_vertex(
  vertices : Array[RectVertex],
  x : Double,
  y : Double,
  color : @core.Color,
) -> Unit {
  vertices.push({ x, y, r: color.r, g: color.g, b: color.b, a: color.a })
}

///|
fn pixel_x_to_ndc(x : Double, width : Double) -> Double {
  if width <= 0.0 {
    -1.0
  } else {
    x / width * 2.0 - 1.0
  }
}

///|
fn pixel_y_to_ndc(y : Double, height : Double) -> Double {
  if height <= 0.0 {
    1.0
  } else {
    1.0 - y / height * 2.0
  }
}

///|
fn push_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
pub fn grow_capacity(required : UInt64) -> UInt64 {
  let mut capacity = 256UL
  while capacity < required {
    capacity = capacity * 2UL
  }
  capacity
}

///|
pub fn size_dim_to_uint(value : Double) -> UInt {
  if value < 1.0 {
    1U
  } else {
    value.to_int().reinterpret_as_uint()
  }
}
