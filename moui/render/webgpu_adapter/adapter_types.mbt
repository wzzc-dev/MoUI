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
pub(all) struct WebGpuHostCapabilities {
  webgpu_available : Bool
  adapter_ready : Bool
  can_render : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostImportInfo {
  import_module : String
  target : String
  surface_resource : String
  renderer_resource : String
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostAdapterInfo {
  renderer : @render.RendererBackendInfo
  surface_contract : @render.WgpuSurfaceContract
  imports : WebGpuHostImportInfo
  capabilities : WebGpuHostCapabilities
  description : String
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
pub(all) struct WebGpuHostSurface {
  canvas_id : String
  mut metrics : @render.RendererSurfaceMetrics
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuHostRendererPort {
  capabilities : () -> WebGpuHostCapabilities raise WebGpuHostError
  create_surface : (String, @render.RendererSurfaceMetrics) -> WebGpuHostSurface raise WebGpuHostError
  create_renderer : (WebGpuHostSurface) -> Unit raise WebGpuHostError
  resize : (@render.RendererSurfaceMetrics) -> Unit raise WebGpuHostError
  measure_text : (@core.TextLayoutInput) -> @core.TextLayoutResult
  register_font_data : (@core.FontFamily, Bytes) -> Unit
  image_resource : (String) -> @render.ImageResourceRecord?
  submit : (Array[WebGpuHostCall]) -> Unit raise WebGpuHostError
  dispose : () -> Unit
}

///|
pub(all) struct WebGpuWasmRenderer {
  surface : WebGpuHostSurface
  port : WebGpuHostRendererPort
  mut size : @core.Size
  mut present_count : Int
  mut last_calls : Array[WebGpuHostCall]
  mut last_fallback_plan : @render.RendererCommandPlan
  image_lifecycle : @render.ImageResourceLifecycle
  priv layer_cache : WebGpuLayerCommandCache
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
