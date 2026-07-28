///|
/// Window-hosted native surface handle.
pub(all) struct AndroidSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn AndroidSurfaceHandle::new(raw~ : UInt64) -> AndroidSurfaceHandle {
  { raw, }
}

///|
pub fn AndroidSurfaceHandle::none() -> AndroidSurfaceHandle {
  { raw: 0UL }
}

///|
pub fn AndroidSurfaceHandle::raw(self : AndroidSurfaceHandle) -> UInt64 {
  self.raw
}

///|
pub(all) struct AndroidBackendCapabilities {
  embedded_surface : Bool
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
/// `ready` means the window-hosted path is usable for app development
/// and demos (aligned with Linux host usability). It does **not** mean full
/// L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `runtime_partial` until window-hosted
/// matching-device smoke and presenter verification close the remaining gaps.
pub(all) struct AndroidBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AndroidBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : AndroidBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : AndroidBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct AndroidRendererProvider {
  priv create_renderer : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|
pub struct AndroidRuntimeSession {
  priv mut surface : AndroidSurfaceHandle
  priv core : @embedded_runtime_session.EmbeddedSessionCore
}

///|
pub fn AndroidRendererProvider::new(
  create_renderer~ : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> AndroidRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn AndroidRendererProvider::create(
  self : AndroidRendererProvider,
  surface : AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostWindowRenderer? {
  (self.create_renderer)(surface, metrics)
}

///|
fn AndroidRendererProvider::sync(
  self : AndroidRendererProvider,
  surface : AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn AndroidRendererProvider::has_async_image_loader(
  self : AndroidRendererProvider,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn android_service_capabilities() -> @host.HostServiceCapabilities {
  // Platform callbacks supply window-hosted services. Matching-device evidence
  // remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn android_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn android_capability_matrix() -> AndroidBackendCapabilities {
  {
    embedded_surface: true,
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
pub fn android_readiness() -> AndroidBackendReadiness {
  {
    ready: true,
    status: "runtime_partial",
    blocked_by: [
      "window-hosted Android matching-device smoke still needs re-recording", "real-device signing observation and verified direct presenter route remain open",
      "GPU seven-gate promotion is not claimed (gpuPromotionEvidence.claimed=false)",
    ],
    next_steps: [
      "re-run MoUI Showcase window-hosted smoke with --require-passed on emulator/device",
      "record actualPresenterRoute direct-present evidence in checks/platforms/android.json",
      "land GPU seven-gate claim only after matching-device promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> AndroidBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Android window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: android_capability_matrix(),
    services: android_service_capabilities(),
    input: android_input_capabilities(),
    readiness: android_readiness(),
    description: "Android backend exposes a native-session contract: wzzc-dev/window/android supplies an ANativeWindow surface and lifecycle/input callbacks, while the backend selects a Skia renderer provider. The host path is usable for development (ready=true, status=runtime_partial). It is not product-complete until window-hosted matching-device L3 and presenter verification close remaining gaps.",
  }
}

///|
pub fn android_capability_summary(
  services? : @host.HostServiceCapabilities = android_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=android_input_capabilities(),
    label="Android host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="Android native WebView is not part of the current mobile host contract.",
    description="Android native host with window HostCmd lifecycle and an ApplicationHandler session. The window host owns lifecycle, surface, input, IME, clipboard, and accessibility adaptation. Runtime evidence remains partial.",
  )
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : AndroidSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  provider~ : AndroidRendererProvider,
) -> AndroidRuntimeSession? {
  match provider.create(surface, metrics) {
    Some(renderer) => {
      let core = @embedded_runtime_session.EmbeddedSessionCore::new(
        runtime~,
        renderer~,
        image_loader=provider.image_loader,
        metrics~,
      )
      provider.sync(surface, metrics)
      Some({ surface, core })
    }
    None => None
  }
}

///|
pub fn AndroidRuntimeSession::metrics(
  self : AndroidRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.core.metrics()
}

///|
pub fn AndroidRuntimeSession::surface(
  self : AndroidRuntimeSession,
) -> AndroidSurfaceHandle {
  self.surface
}

///|
pub fn AndroidRuntimeSession::runtime(
  self : AndroidRuntimeSession,
) -> @runtime.AppRuntime {
  self.core.runtime()
}

///|
pub fn AndroidRuntimeSession::disposed(self : AndroidRuntimeSession) -> Bool {
  self.core.disposed()
}

///|
pub fn AndroidRuntimeSession::surface_attached(
  self : AndroidRuntimeSession,
) -> Bool {
  self.core.surface_attached()
}

///|
pub fn AndroidRuntimeSession::session_generation(
  self : AndroidRuntimeSession,
) -> Int {
  self.core.session_generation()
}

///|
pub fn AndroidRuntimeSession::surface_epoch(
  self : AndroidRuntimeSession,
) -> Int {
  self.core.surface_epoch()
}

///|
pub fn AndroidRuntimeSession::attach_surface(
  self : AndroidRuntimeSession,
  surface : AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  provider : AndroidRendererProvider,
) -> Bool {
  match provider.create(surface, metrics) {
    Some(renderer) =>
      if self.core.attach_surface(
          renderer~,
          metrics~,
          image_loader=provider.image_loader,
        ) {
        self.surface = surface
        provider.sync(surface, metrics)
        true
      } else {
        false
      }
    None => false
  }
}

///|
pub fn AndroidRuntimeSession::detach_surface(
  self : AndroidRuntimeSession,
) -> Bool {
  if self.core.detach_surface() {
    self.surface = AndroidSurfaceHandle::none()
    true
  } else {
    false
  }
}

///|
pub fn AndroidRuntimeSession::dispatch(
  self : AndroidRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  self.core.dispatch(event)
}

///|
pub fn AndroidRuntimeSession::resize(
  self : AndroidRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.core.resize(metrics)
}

///|
pub fn AndroidRuntimeSession::sync_surface(
  self : AndroidRuntimeSession,
  provider : AndroidRendererProvider,
) -> Unit {
  if self.surface_attached() {
    provider.sync(self.surface, self.core.metrics())
  }
}

///|
pub fn AndroidRuntimeSession::render_frame(
  self : AndroidRuntimeSession,
) -> @render.RenderFrameResult {
  self.core.render_frame()
}

///|
pub fn AndroidRuntimeSession::advance_time(
  self : AndroidRuntimeSession,
  time_ms : Double,
) -> Unit {
  self.core.advance_time(time_ms)
}

///|
pub fn AndroidRuntimeSession::drain_host_updates(
  self : AndroidRuntimeSession,
) -> Array[@embedded_runtime_session.EmbeddingHostUpdate] {
  self.core.drain_host_updates()
}

///|
pub fn AndroidRuntimeSession::drain_host_updates_json(
  self : AndroidRuntimeSession,
) -> String {
  self.core.drain_host_updates_json()
}

///|
pub fn AndroidRuntimeSession::drain_host_update_envelope_json(
  self : AndroidRuntimeSession,
) -> String {
  self.core.drain_host_update_envelope_json()
}

///|
pub fn AndroidRuntimeSession::dispatch_host_response(
  self : AndroidRuntimeSession,
  response : @embedded_runtime_session.EmbeddingHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn AndroidRuntimeSession::dispatch_host_response_envelope(
  self : AndroidRuntimeSession,
  envelope : @embedded_runtime_session.EmbeddingHostResponseEnvelope,
) -> Bool {
  self.core.dispatch_host_response_envelope(envelope)
}

///|
pub fn AndroidRuntimeSession::dispatch_host_response_envelope_json(
  self : AndroidRuntimeSession,
  text : String,
) -> Bool {
  self.core.dispatch_host_response_envelope_json(text)
}

///|
pub fn AndroidRuntimeSession::host_service_bridge(
  self : AndroidRuntimeSession,
) -> @host.HostServiceBridge {
  self.core.host_service_bridge()
}

///|
pub fn AndroidRuntimeSession::redraw_requested(
  self : AndroidRuntimeSession,
) -> Bool {
  self.core.redraw_requested()
}

///|
pub fn AndroidRuntimeSession::take_redraw_requested(
  self : AndroidRuntimeSession,
) -> Bool {
  self.core.take_redraw_requested()
}

///|
pub fn AndroidRuntimeSession::present_count(
  self : AndroidRuntimeSession,
) -> Int {
  self.core.present_count()
}

///|
pub fn AndroidRuntimeSession::dispose(self : AndroidRuntimeSession) -> Unit {
  self.core.dispose()
}
