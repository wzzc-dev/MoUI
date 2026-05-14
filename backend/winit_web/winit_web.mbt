///|
pub type WinitWebApp = @web.WebApp

///|
pub type WinitWebBootContext = @web.WebBootContext

///|
pub type WinitWebEventResult = @web.WebEventResult

///|
pub(all) struct WinitWebBackendInfo {
  host_info : @host.HostAppInfo
  uses_current_js_webgpu_backend : Bool
  keeps_wasm_path_experimental : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn backend_info() -> WinitWebBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Web,
      description="winit web facade over the current canvas + JS WebGPU backend",
    ),
    uses_current_js_webgpu_backend: true,
    keeps_wasm_path_experimental: true,
    description: "Stable web host boundary for the future winit canvas + wgpu wasm path; currently delegates to backend/web on JS builds.",
  }
}

///|
pub fn runtime_for_canvas(
  root~ : @core.ViewNode,
  width~ : Double,
  height~ : Double,
) -> @backend.AppRuntime {
  @web.runtime_for_canvas(root~, width~, height~)
}

///|
pub fn component_runtime_for_canvas(
  root~ : @core.Component,
  width~ : Double,
  height~ : Double,
) -> @backend.AppRuntime {
  @web.component_runtime_for_canvas(root~, width~, height~)
}

///|
pub fn renderer(context : WinitWebBootContext) -> @webgpu.WebGpuRenderer {
  context.renderer()
}

///|
pub fn width(context : WinitWebBootContext) -> Double {
  context.width()
}

///|
pub fn height(context : WinitWebBootContext) -> Double {
  context.height()
}

///|
pub fn new_app(
  runtime~ : @backend.AppRuntime,
  renderer~ : @webgpu.WebGpuRenderer,
) -> WinitWebApp {
  @web.WebApp::new(runtime~, renderer~)
}

///|
pub fn attach_dom_events(
  app : WinitWebApp,
  context : WinitWebBootContext,
) -> Unit {
  app.attach_dom_events(context)
}

///|
pub fn start(app : WinitWebApp) -> Unit {
  app.start()
}

///|
pub fn host_dispatch(
  app : WinitWebApp,
  event : @host.HostEvent,
) -> WinitWebEventResult {
  app.host_dispatch(event)
}

///|
pub fn text_input(
  app : WinitWebApp,
  text : String,
) -> WinitWebEventResult {
  app.text_input(text)
}

///|
pub fn surface_metrics(app : WinitWebApp) -> @host.HostSurfaceMetrics {
  app.surface_metrics()
}
