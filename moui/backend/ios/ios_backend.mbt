///|
pub type IosViewHandle = @shell_ios.IosNativeView

///|
pub fn ios_shell_embedding_api_version() -> Int {
  @shell_embedding.embedding_api_version()
}

///|
/// iOS keeps its `UIView` and CADisplayLink contract in the platform SDK.
pub fn ios_shell_descriptor() -> @shell_embedding.ShellPlatformDescriptor {
  @shell_ios.ios_descriptor()
}

///|
pub fn ios_shell_renderer_configure(mode : String) -> Bool {
  @embedded_runtime_session.shell_renderer_configure(mode)
}

///|
pub fn ios_shell_renderer_selection(
  gpu_available~ : Bool,
) -> @render.NativeRendererSelection {
  @embedded_runtime_session.shell_renderer_selection(
    @render.NativeGpuPlatform::Ios,
    gpu_available~,
  )
}

///|
pub fn ios_shell_renderer_status_json(gpu_available~ : Bool) -> String {
  @embedded_runtime_session.shell_renderer_status_json(
    @render.NativeGpuPlatform::Ios,
    gpu_available~,
  )
}

///|
pub(all) struct IosBackendCapabilities {
  embedded_view : Bool
  external_event_loop : Bool
  renderer_provider : Bool
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  system_theme : Bool
  accessibility : Bool
  async_image : Bool
} derive(Eq, Debug, ToJson)

///|
/// `ready` means the managed-shell host path is usable for app development
/// and demos (aligned with Linux host usability). It does **not** mean full
/// L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `runtime_partial` until managed
/// SwiftUI matching-simulator smoke and presenter verification close gaps.
pub(all) struct IosBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct IosBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : IosBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : IosBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct IosRendererProvider {
  priv create_renderer : (IosViewHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_view : (IosViewHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
pub struct IosRuntimeSession {
  priv mut view : IosViewHandle
  priv core : @embedded_runtime_session.EmbeddedSessionCore
}

///|
pub fn IosRendererProvider::new(
  create_renderer~ : (IosViewHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_view? : (IosViewHandle, @host.HostSurfaceMetrics) -> Unit = (
    _view,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> IosRendererProvider {
  { create_renderer, sync_view, image_loader }
}

///|
fn IosRendererProvider::create(
  self : IosRendererProvider,
  view : IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostWindowRenderer? {
  (self.create_renderer)(view, metrics)
}

///|
fn IosRendererProvider::sync(
  self : IosRendererProvider,
  view : IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_view)(view, metrics)
}

///|
pub fn IosRendererProvider::has_async_image_loader(
  self : IosRendererProvider,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn ios_service_capabilities() -> @host.HostServiceCapabilities {
  // Code-level host services wired through EmbedderHostChannel + Swift shell
  // adapters. Matching-simulator evidence remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn ios_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=true,
    clipboard=true,
    drag_drop=false,
  )
}

///|
pub fn ios_capability_matrix() -> IosBackendCapabilities {
  {
    embedded_view: true,
    external_event_loop: true,
    renderer_provider: true,
    pointer: true,
    scroll: true,
    keyboard: true,
    text_input: true,
    ime: true,
    clipboard: true,
    system_theme: false,
    accessibility: true,
    async_image: true,
  }
}

///|
pub fn ios_readiness() -> IosBackendReadiness {
  {
    ready: true,
    status: "runtime_partial",
    blocked_by: [
      "managed SwiftUI shell matching-simulator smoke still needs re-recording with --require-passed",
      "physical-device and real VoiceOver observations remain open", "GPU seven-gate promotion is not claimed (gpuPromotionEvidence.claimed=false)",
    ],
    next_steps: [
      "re-run MoUI Showcase managed SwiftUI smoke on Simulator without shell probes",
      "record actualPresenterRoute metal-direct evidence in checks/platforms/ios.json",
      "land GPU seven-gate claim only after matching-host promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> IosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="iOS embedded native host with managed SwiftUI shell, UIKit/Metal view callbacks, and EmbedderHostChannel services",
    ),
    capabilities: ios_capability_matrix(),
    services: ios_service_capabilities(),
    input: ios_input_capabilities(),
    readiness: ios_readiness(),
    description: "iOS backend exposes an embedded-session contract: the managed shell supplies a view/Metal surface, forwards lifecycle/input callbacks, and selects a Skia renderer provider. Host path is usable for development (ready=true, status=runtime_partial). It is not product-complete until managed-shell matching-simulator L3 and presenter verification close remaining gaps.",
  }
}

///|
pub fn ios_capability_summary(
  services? : @host.HostServiceCapabilities = ios_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=ios_input_capabilities(),
    label="iOS host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="iOS native WKWebView embedding is not part of the current shell host contract.",
    description="iOS embedded native host with managed shell lifecycle, EmbedderHostChannel IME/clipboard/a11y bridges, and app-driven input forwarding. Runtime evidence remains partial.",
  )
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  view~ : IosViewHandle,
  metrics~ : @host.HostSurfaceMetrics,
  provider~ : IosRendererProvider,
) -> IosRuntimeSession? {
  match provider.create(view, metrics) {
    Some(renderer) => {
      let core = @embedded_runtime_session.EmbeddedSessionCore::new(
        runtime~,
        renderer~,
        image_loader=provider.image_loader,
        metrics~,
      )
      provider.sync(view, metrics)
      Some({ view, core })
    }
    None => None
  }
}

///|
pub fn IosRuntimeSession::metrics(
  self : IosRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.core.metrics()
}

///|
pub fn IosRuntimeSession::view(self : IosRuntimeSession) -> IosViewHandle {
  self.view
}

///|
pub fn IosRuntimeSession::runtime(
  self : IosRuntimeSession,
) -> @runtime.AppRuntime {
  self.core.runtime()
}

///|
pub fn IosRuntimeSession::disposed(self : IosRuntimeSession) -> Bool {
  self.core.disposed()
}

///|
pub fn IosRuntimeSession::surface_attached(self : IosRuntimeSession) -> Bool {
  self.core.surface_attached()
}

///|
pub fn IosRuntimeSession::session_generation(self : IosRuntimeSession) -> Int {
  self.core.session_generation()
}

///|
pub fn IosRuntimeSession::surface_epoch(self : IosRuntimeSession) -> Int {
  self.core.surface_epoch()
}

///|
pub fn IosRuntimeSession::attach_view(
  self : IosRuntimeSession,
  view : IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
  provider : IosRendererProvider,
) -> Bool {
  match provider.create(view, metrics) {
    Some(renderer) =>
      if self.core.attach_surface(
          renderer~,
          metrics~,
          image_loader=provider.image_loader,
        ) {
        self.view = view
        provider.sync(view, metrics)
        true
      } else {
        false
      }
    None => false
  }
}

///|
pub fn IosRuntimeSession::detach_view(self : IosRuntimeSession) -> Bool {
  if self.core.detach_surface() {
    self.view = IosViewHandle::none()
    true
  } else {
    false
  }
}

///|
pub fn IosRuntimeSession::dispatch(
  self : IosRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  self.core.dispatch(event)
}

///|
pub fn IosRuntimeSession::resize(
  self : IosRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.core.resize(metrics)
}

///|
pub fn IosRuntimeSession::sync_view(
  self : IosRuntimeSession,
  provider : IosRendererProvider,
) -> Unit {
  if self.surface_attached() {
    provider.sync(self.view, self.core.metrics())
  }
}

///|
pub fn IosRuntimeSession::render_frame(
  self : IosRuntimeSession,
) -> @render.RenderFrameResult {
  self.core.render_frame()
}

///|
pub fn IosRuntimeSession::advance_time(
  self : IosRuntimeSession,
  time_ms : Double,
) -> Unit {
  self.core.advance_time(time_ms)
}

///|
pub fn IosRuntimeSession::drain_host_updates(
  self : IosRuntimeSession,
) -> Array[@embedded_runtime_session.EmbeddingHostUpdate] {
  self.core.drain_host_updates()
}

///|
pub fn IosRuntimeSession::drain_host_updates_json(
  self : IosRuntimeSession,
) -> String {
  self.core.drain_host_updates_json()
}

///|
pub fn IosRuntimeSession::drain_host_update_envelope_json(
  self : IosRuntimeSession,
) -> String {
  self.core.drain_host_update_envelope_json()
}

///|
pub fn IosRuntimeSession::dispatch_host_response(
  self : IosRuntimeSession,
  response : @embedded_runtime_session.EmbeddingHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn IosRuntimeSession::dispatch_host_response_envelope(
  self : IosRuntimeSession,
  envelope : @embedded_runtime_session.EmbeddingHostResponseEnvelope,
) -> Bool {
  self.core.dispatch_host_response_envelope(envelope)
}

///|
pub fn IosRuntimeSession::dispatch_host_response_envelope_json(
  self : IosRuntimeSession,
  text : String,
) -> Bool {
  self.core.dispatch_host_response_envelope_json(text)
}

///|
pub fn IosRuntimeSession::host_service_bridge(
  self : IosRuntimeSession,
) -> @host.HostServiceBridge {
  self.core.host_service_bridge()
}

///|
pub fn IosRuntimeSession::redraw_requested(self : IosRuntimeSession) -> Bool {
  self.core.redraw_requested()
}

///|
pub fn IosRuntimeSession::take_redraw_requested(
  self : IosRuntimeSession,
) -> Bool {
  self.core.take_redraw_requested()
}

///|
pub fn IosRuntimeSession::present_count(self : IosRuntimeSession) -> Int {
  self.core.present_count()
}

///|
pub fn IosRuntimeSession::dispose(self : IosRuntimeSession) -> Unit {
  self.core.dispose()
}
