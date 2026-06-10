///|
pub(all) enum RendererBackendKind {
  NativeWgpu
  WebGpuWasm
  SkiaRasterNative
  SkiaRasterWeb
  SkiaGpuNative
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererCapabilityStatus {
  Ready
  Unavailable
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererFamily {
  Wgpu
  WebGpu
  Skia
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererPresentationModel {
  HostGpuSurface
  WebCanvas
  CpuPixelFrame
  ExternalSurface
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererTarget {
  Native
  WasmGc
  Web
} derive(Eq, Debug, ToJson)

///|
pub(all) enum RendererSelection {
  Default
  Backend(RendererBackendKind)
  Family(RendererFamily)
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
pub(all) struct RendererDescriptor {
  backend : RendererBackendKind
  family : RendererFamily
  presentation : RendererPresentationModel
  supported_targets : Array[RendererTarget]
  capabilities : Array[RendererBackendFeatureCapability]
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RenderFrameInput {
  metrics : RendererSurfaceMetrics
  commands : Array[@core.DrawCommand]
  damage : @core.DamageRegion
  clear_color : @core.Color?
  cache_epoch : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RenderFrameResult {
  presented : Bool
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  missing_layer_keys : Array[String]
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
pub fn RendererBackendKind::label(self : RendererBackendKind) -> String {
  match self {
    NativeWgpu => "native-wgpu"
    WebGpuWasm => "webgpu-wasm"
    SkiaRasterNative => "skia-raster-native"
    SkiaRasterWeb => "skia-raster-web"
    SkiaGpuNative => "skia-gpu-native"
  }
}

///|
pub fn RendererBackendKind::short_label(self : RendererBackendKind) -> String {
  match self {
    NativeWgpu => "wgpu"
    WebGpuWasm => "webgpu"
    SkiaRasterNative => "skia"
    SkiaRasterWeb => "skia-web"
    SkiaGpuNative => "skia-gpu"
  }
}

///|
pub fn RendererFamily::label(self : RendererFamily) -> String {
  match self {
    Wgpu => "wgpu"
    WebGpu => "webgpu"
    Skia => "skia"
  }
}

///|
pub fn RendererPresentationModel::label(
  self : RendererPresentationModel,
) -> String {
  match self {
    HostGpuSurface => "host-gpu-surface"
    WebCanvas => "web-canvas"
    CpuPixelFrame => "cpu-pixel-frame"
    ExternalSurface => "external-surface"
  }
}

///|
pub fn RendererSelection::native_default() -> RendererSelection {
  RendererSelection::Backend(RendererBackendKind::SkiaRasterNative)
}

///|
pub fn RendererSelection::web_default() -> RendererSelection {
  RendererSelection::Backend(RendererBackendKind::WebGpuWasm)
}

///|
pub fn RendererSelection::matches_backend(
  self : RendererSelection,
  backend : RendererBackendKind,
) -> Bool {
  match self {
    Default => false
    Backend(selected) => selected == backend
    Family(family) => backend.family() == family
  }
}

///|
pub fn RendererBackendKind::family(
  self : RendererBackendKind,
) -> RendererFamily {
  match self {
    NativeWgpu => RendererFamily::Wgpu
    WebGpuWasm => RendererFamily::WebGpu
    SkiaRasterNative | SkiaRasterWeb | SkiaGpuNative => RendererFamily::Skia
  }
}

///|
pub fn RendererDescriptor::new(
  backend~ : RendererBackendKind,
  family~ : RendererFamily,
  presentation~ : RendererPresentationModel,
  supported_targets~ : Array[RendererTarget],
  capabilities~ : Array[RendererBackendFeatureCapability],
  description? : String = "",
) -> RendererDescriptor {
  {
    backend,
    family,
    presentation,
    supported_targets,
    capabilities,
    description,
  }
}

///|
pub fn RenderFrameInput::new(
  metrics~ : RendererSurfaceMetrics,
  commands~ : Array[@core.DrawCommand],
  damage? : @core.DamageRegion = @core.DamageRegion::full("legacy render frame input"),
  clear_color? : @core.Color? = None,
  cache_epoch? : Int = 0,
) -> RenderFrameInput {
  { metrics, commands, damage, clear_color, cache_epoch }
}

///|
pub fn RenderFrameResult::new(
  presented? : Bool = true,
  cache_hit_count? : Int = 0,
  cache_miss_count? : Int = 0,
  cache_update_count? : Int = 0,
  cache_evict_count? : Int = 0,
  missing_layer_keys? : Array[String] = [],
) -> RenderFrameResult {
  {
    presented,
    cache_hit_count,
    cache_miss_count,
    cache_update_count,
    cache_evict_count,
    missing_layer_keys,
  }
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
      | @core.DrawCommand::BeginCachedLayer(_)
      | @core.DrawCommand::EndCachedLayer(_)
      | @core.DrawCommand::DrawCachedLayer(_)
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
    @core.Brush::RadialGradient(gradient) => gradient.center_color
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
