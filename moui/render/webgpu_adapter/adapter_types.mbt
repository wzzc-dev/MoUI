///|
type HostWebGpuSurface = Int

///|
type HostWebGpuRenderer = Int

///|
type HostWebGpuString = Int

///|
pub(all) suberror WebGpuHostError {
  Unavailable
  AdapterUnavailable
  DeviceUnavailable
  SurfaceUnavailable
  PipelineUnavailable
  InvalidResource
  HostError(String)
} derive(Eq, Debug, ToJson)

///|
pub struct WebGpuHostCapabilities {
  priv webgpu_available : Bool
  priv adapter_ready : Bool
  priv can_render : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct WebGpuHostImportInfo {
  priv import_module : String
  priv target : String
  priv surface_resource : String
  priv renderer_resource : String
  priv description : String
} derive(Eq, Debug, ToJson)

///|
pub struct WebGpuHostAdapterInfo {
  priv renderer : @render.RendererBackendInfo
  priv surface_contract : @render.WgpuSurfaceContract
  priv imports : WebGpuHostImportInfo
  priv capabilities : WebGpuHostCapabilities
  priv description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebGpuHostCall {
  BeginFrame(@core.Size)
  Clear(@core.Color)
  FillRect(@core.Rect, @core.Color)
  StrokeRect(@core.Rect, @core.Color, Double)
  FillRoundedRect(@core.RoundedRect, @core.Color)
  StrokeRoundedRect(@core.RoundedRect, @core.Color, Double)
  FillRoundedRectBrush(@core.RoundedRect, @core.Brush)
  StrokeRoundedRectBrush(@core.RoundedRect, @core.Brush, Double)
  DrawShadow(@core.ShadowSpec)
  DrawText(@core.TextRun)
  DrawImage(@core.ImageRun)
  DrawPath(@core.PathSpec)
  PushClip(@core.Rect)
  PopClip
  PushRoundedClip(@core.RoundedRect)
  PopRoundedClip
  PushTransform(@core.Transform2D)
  PopTransform
  PushOpacity(Double)
  PopOpacity
  PushLayer(@core.LayerSpec)
  PopLayer
  PushFilter(@core.FilterEffect)
  PopFilter
  DrawShaderEffect(@core.ShaderEffectSpec)
  Present
} derive(Eq, Debug, ToJson)

///|
priv struct HostBrushPayload {
  start : @core.Point
  end : @core.Point
  start_color : @core.Color
  end_color : @core.Color
}

///|
priv struct HostRadialBrushPayload {
  center : @core.Point
  radius : Double
  center_color : @core.Color
  edge_color : @core.Color
}

///|
priv enum RoundedBrushHostPayload {
  SolidColor(@core.Color)
  LinearGradientPayload(HostBrushPayload)
  RadialGradientPayload(HostRadialBrushPayload)
}

///|
pub struct WebGpuHostSurface {
  priv canvas_id : String
  priv mut metrics : @core.SurfaceMetrics
} derive(Eq, Debug, ToJson)

///|
pub struct WebGpuHostRendererPort {
  priv capabilities : () -> WebGpuHostCapabilities raise WebGpuHostError
  priv create_surface : (String, @core.SurfaceMetrics) -> WebGpuHostSurface raise WebGpuHostError
  priv create_renderer : (WebGpuHostSurface) -> Unit raise WebGpuHostError
  priv resize : (@core.SurfaceMetrics) -> Unit raise WebGpuHostError
  priv measure_text : (@core.TextLayoutInput) -> @core.TextLayoutResult
  priv register_font_data : (@core.FontFamily, Bytes) -> Unit
  priv image_resource : (String) -> @render.ImageResourceRecord?
  priv submit : (Array[WebGpuHostCall]) -> Unit raise WebGpuHostError
  priv dispose : () -> Unit
}

///|
pub struct WebGpuWasmRenderer {
  priv surface : WebGpuHostSurface
  priv port : WebGpuHostRendererPort
  priv mut size : @core.Size
  priv mut present_count : Int
  priv mut last_calls : Array[WebGpuHostCall]
  priv mut last_fallback_plan : @render.RendererCommandPlan
  priv image_lifecycle : @render_common.ImageResourceLifecycle
  priv layer_cache : WebGpuLayerCommandCache
}

///|
pub fn WebGpuHostCapabilities::new(
  webgpu_available? : Bool = true,
  adapter_ready? : Bool = true,
  can_render? : Bool = true,
) -> WebGpuHostCapabilities {
  { webgpu_available, adapter_ready, can_render }
}

///|
pub fn WebGpuHostImportInfo::new(
  import_module~ : String,
  target~ : String,
  surface_resource~ : String,
  renderer_resource~ : String,
  description? : String = "",
) -> WebGpuHostImportInfo {
  { import_module, target, surface_resource, renderer_resource, description }
}

///|
pub fn WebGpuHostAdapterInfo::new(
  renderer~ : @render.RendererBackendInfo,
  surface_contract~ : @render.WgpuSurfaceContract,
  imports~ : WebGpuHostImportInfo,
  capabilities~ : WebGpuHostCapabilities,
  description? : String = "",
) -> WebGpuHostAdapterInfo {
  { renderer, surface_contract, imports, capabilities, description }
}

///|
pub fn WebGpuHostSurface::new(
  canvas_id~ : String,
  metrics~ : @core.SurfaceMetrics,
) -> WebGpuHostSurface {
  { canvas_id, metrics }
}

///|
pub fn WebGpuHostRendererPort::new(
  capabilities~ : () -> WebGpuHostCapabilities raise WebGpuHostError,
  create_surface~ : (String, @core.SurfaceMetrics) -> WebGpuHostSurface raise WebGpuHostError,
  create_renderer~ : (WebGpuHostSurface) -> Unit raise WebGpuHostError,
  resize~ : (@core.SurfaceMetrics) -> Unit raise WebGpuHostError,
  measure_text~ : (@core.TextLayoutInput) -> @core.TextLayoutResult,
  register_font_data~ : (@core.FontFamily, Bytes) -> Unit,
  image_resource~ : (String) -> @render.ImageResourceRecord?,
  submit~ : (Array[WebGpuHostCall]) -> Unit raise WebGpuHostError,
  dispose~ : () -> Unit,
) -> WebGpuHostRendererPort {
  {
    capabilities,
    create_surface,
    create_renderer,
    resize,
    measure_text,
    register_font_data,
    image_resource,
    submit,
    dispose,
  }
}

///|
pub fn WebGpuHostCapabilities::webgpu_available(
  self : WebGpuHostCapabilities,
) -> Bool {
  self.webgpu_available
}

///|
pub fn WebGpuHostCapabilities::adapter_ready(
  self : WebGpuHostCapabilities,
) -> Bool {
  self.adapter_ready
}

///|
pub fn WebGpuHostCapabilities::can_render(
  self : WebGpuHostCapabilities,
) -> Bool {
  self.can_render
}

///|
pub fn WebGpuHostImportInfo::import_module(
  self : WebGpuHostImportInfo,
) -> String {
  self.import_module
}

///|
pub fn WebGpuHostImportInfo::target(self : WebGpuHostImportInfo) -> String {
  self.target
}

///|
pub fn WebGpuHostImportInfo::surface_resource(
  self : WebGpuHostImportInfo,
) -> String {
  self.surface_resource
}

///|
pub fn WebGpuHostImportInfo::renderer_resource(
  self : WebGpuHostImportInfo,
) -> String {
  self.renderer_resource
}

///|
pub fn WebGpuHostImportInfo::description(self : WebGpuHostImportInfo) -> String {
  self.description
}

///|
pub fn WebGpuHostAdapterInfo::renderer(
  self : WebGpuHostAdapterInfo,
) -> @render.RendererBackendInfo {
  self.renderer
}

///|
pub fn WebGpuHostAdapterInfo::surface_contract(
  self : WebGpuHostAdapterInfo,
) -> @render.WgpuSurfaceContract {
  self.surface_contract
}

///|
pub fn WebGpuHostAdapterInfo::imports(
  self : WebGpuHostAdapterInfo,
) -> WebGpuHostImportInfo {
  self.imports
}

///|
pub fn WebGpuHostAdapterInfo::capabilities(
  self : WebGpuHostAdapterInfo,
) -> WebGpuHostCapabilities {
  self.capabilities
}

///|
pub fn WebGpuHostAdapterInfo::description(
  self : WebGpuHostAdapterInfo,
) -> String {
  self.description
}

///|
pub fn WebGpuHostSurface::canvas_id(self : WebGpuHostSurface) -> String {
  self.canvas_id
}

///|
pub fn WebGpuHostSurface::metrics(
  self : WebGpuHostSurface,
) -> @core.SurfaceMetrics {
  self.metrics
}

///|
pub fn WebGpuHostRendererPort::capabilities(
  self : WebGpuHostRendererPort,
) -> WebGpuHostCapabilities raise WebGpuHostError {
  (self.capabilities)()
}

///|
pub fn WebGpuHostRendererPort::create_surface(
  self : WebGpuHostRendererPort,
  canvas_id : String,
  metrics : @core.SurfaceMetrics,
) -> WebGpuHostSurface raise WebGpuHostError {
  (self.create_surface)(canvas_id, metrics)
}

///|
pub fn WebGpuHostRendererPort::create_renderer(
  self : WebGpuHostRendererPort,
  surface : WebGpuHostSurface,
) -> Unit raise WebGpuHostError {
  (self.create_renderer)(surface)
}

///|
pub fn WebGpuHostRendererPort::resize(
  self : WebGpuHostRendererPort,
  metrics : @core.SurfaceMetrics,
) -> Unit raise WebGpuHostError {
  (self.resize)(metrics)
}

///|
pub fn WebGpuHostRendererPort::measure_text(
  self : WebGpuHostRendererPort,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  (self.measure_text)(input)
}

///|
pub fn WebGpuHostRendererPort::register_font_data(
  self : WebGpuHostRendererPort,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  (self.register_font_data)(family, data)
}

///|
pub fn WebGpuHostRendererPort::image_resource(
  self : WebGpuHostRendererPort,
  source : String,
) -> @render.ImageResourceRecord? {
  (self.image_resource)(source)
}

///|
pub fn WebGpuHostRendererPort::submit(
  self : WebGpuHostRendererPort,
  calls : Array[WebGpuHostCall],
) -> Unit raise WebGpuHostError {
  (self.submit)(calls)
}

///|
pub fn WebGpuHostRendererPort::dispose(self : WebGpuHostRendererPort) -> Unit {
  (self.dispose)()
}

///|
pub fn WebGpuWasmRenderer::surface(
  self : WebGpuWasmRenderer,
) -> WebGpuHostSurface {
  self.surface
}

///|
priv struct WebGpuLayerCommandCacheEntry {
  key : String
  commands : Array[@core.DrawCommand]
}

///|
priv struct WebGpuLayerCommandCache {
  entries : Array[WebGpuLayerCommandCacheEntry]
  mut tick : Int
}

///|
priv struct WebGpuLayerCommandExpansion {
  commands : Array[@core.DrawCommand]
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  missing_layer_keys : Array[String]
}

///|
priv struct WebGpuLayerCommandCapture {
  spec : @core.CachedLayerSpec
  commands : Array[@core.DrawCommand]
}

///|
