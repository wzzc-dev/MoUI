///|
pub(all) enum WebGpuWasmBindingKind {
  JsFfi
  Wit
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebGpuWasmCapability {
  BrowserUnavailable
  BindingUnavailable
  ContractOnly
  Ready
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuWasmAdapterInfo {
  renderer : @render.RendererBackendInfo
  binding : WebGpuWasmBindingKind
  capability : WebGpuWasmCapability
  surface_contract : @render.WgpuSurfaceContract
  requires_secure_context : Bool
  requires_gpu_adapter : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuWasmDeviceContract {
  can_request_adapter : Bool
  can_request_device : Bool
  can_create_surface_from_canvas : Bool
  can_configure_surface : Bool
  can_create_render_pipeline : Bool
  can_present : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebGpuWasmRenderer {
  surface : @render.CanvasWgpuSurface
  mut size : @core.Size
  mut present_count : Int
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    status=@render.RendererCapabilityStatus::Unsupported,
    can_render=false,
    can_resize=false,
    owns_surface=false,
    description="Browser WebGPU renderer contract for wasm-gc; real JS FFI/WIT bindings are not wired yet.",
  )
}

///|
pub fn webgpu_available() -> Bool {
  false
}

///|
pub fn adapter_contract_ready() -> Bool {
  false
}

///|
pub fn adapter_info() -> WebGpuWasmAdapterInfo {
  {
    renderer: backend_info(),
    binding: WebGpuWasmBindingKind::JsFfi,
    capability: WebGpuWasmCapability::ContractOnly,
    surface_contract: canvas_surface_contract(),
    requires_secure_context: true,
    requires_gpu_adapter: true,
    description: "MoonBit wasm host can own the canvas through window/web, but browser WebGPU device/surface/pipeline bindings still need JS FFI or WIT implementation.",
  }
}

///|
pub fn device_contract() -> WebGpuWasmDeviceContract {
  {
    can_request_adapter: false,
    can_request_device: false,
    can_create_surface_from_canvas: false,
    can_configure_surface: false,
    can_create_render_pipeline: false,
    can_present: false,
  }
}

///|
pub fn canvas_surface_contract() -> @render.WgpuSurfaceContract {
  @render.WgpuSurfaceContract::new(
    source=@render.WgpuSurfaceSourceKind::WebCanvasSurface,
    backend=@render.RendererBackendKind::WebGpuWasm,
    ready=false,
    description="Canvas surface source is defined, but WebGPU wasm surface creation is not implemented yet.",
  )
}

///|
pub fn create_canvas_surface(
  canvas_id~ : String,
  logical_size~ : @core.Size,
  scale_factor? : Double = 1.0,
) -> @render.CanvasWgpuSurface {
  @render.CanvasWgpuSurface::from_logical(
    canvas_id~,
    size=logical_size,
    scale_factor~,
  )
}

///|
pub fn create_renderer_placeholder(
  surface : @render.CanvasWgpuSurface,
) -> WebGpuWasmRenderer {
  { surface, size: surface.metrics.logical_size, present_count: 0 }
}

///|
pub fn WebGpuWasmRenderer::backend_kind(
  self : WebGpuWasmRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  @render.RendererBackendKind::WebGpuWasm
}

///|
pub fn WebGpuWasmRenderer::backend_info(
  self : WebGpuWasmRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn WebGpuWasmRenderer::resize(
  self : WebGpuWasmRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit {
  self.size = metrics.logical_size
}

///|
pub fn WebGpuWasmRenderer::render(
  self : WebGpuWasmRenderer,
  _commands : Array[@core.DrawCommand],
) -> Unit {
  if webgpu_available() {
    self.present_count = self.present_count + 1
  }
}

///|
pub fn WebGpuWasmRenderer::dispose(self : WebGpuWasmRenderer) -> Unit {
  let _ = self
}

///|
pub fn WebGpuWasmRenderer::present_count(self : WebGpuWasmRenderer) -> Int {
  self.present_count
}
