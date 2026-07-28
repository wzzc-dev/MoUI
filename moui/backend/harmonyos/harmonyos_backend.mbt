///|
/// Window-hosted native surface handle.
pub(all) struct HarmonyOsSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn HarmonyOsSurfaceHandle::new(raw~ : UInt64) -> HarmonyOsSurfaceHandle {
  { raw, }
}

///|
pub fn HarmonyOsSurfaceHandle::none() -> HarmonyOsSurfaceHandle {
  { raw: 0UL }
}

///|
pub fn HarmonyOsSurfaceHandle::raw(self : HarmonyOsSurfaceHandle) -> UInt64 {
  self.raw
}

///|
pub(all) struct HarmonyOsBackendCapabilities {
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
/// L3 runtime promotion, commercial signing, or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `runtime_partial` until signed-device
/// full smoke and presenter verification close remaining gaps.
pub(all) struct HarmonyOsBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HarmonyOsBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : HarmonyOsBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : HarmonyOsBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct HarmonyOsRendererProvider {
  priv create_renderer : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|
pub struct HarmonyOsRuntimeSession {
  priv mut surface : HarmonyOsSurfaceHandle
  priv core : @embedded_runtime_session.EmbeddedSessionCore
}

///|
pub fn HarmonyOsRendererProvider::new(
  create_renderer~ : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> HarmonyOsRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn HarmonyOsRendererProvider::create(
  self : HarmonyOsRendererProvider,
  surface : HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostWindowRenderer? {
  (self.create_renderer)(surface, metrics)
}

///|
fn HarmonyOsRendererProvider::sync(
  self : HarmonyOsRendererProvider,
  surface : HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn HarmonyOsRendererProvider::has_async_image_loader(
  self : HarmonyOsRendererProvider,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn harmonyos_service_capabilities() -> @host.HostServiceCapabilities {
  // Platform callbacks supply window-hosted services. Matching-device evidence
  // remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn harmonyos_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn harmonyos_capability_matrix() -> HarmonyOsBackendCapabilities {
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
pub fn harmonyos_readiness() -> HarmonyOsBackendReadiness {
  {
    ready: true,
    status: "runtime_partial",
    blocked_by: [
      "commercial/signed-device window-hosted smoke is not yet status=passed", "checked-in smoke still lacks a complete attach/resize/input/IME/clipboard suite",
      "actualPresenterRoute remains unverified; GPU seven-gate promotion is not claimed",
    ],
    next_steps: [
      "configure MOUI_HARMONYOS_SIGNING_CONFIG and record a full matching-device smoke",
      "promote checks/platforms/harmonyos.json runtimeL3 only after --require-passed evidence",
      "land GPU seven-gate claim only after matching-device promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> HarmonyOsBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="HarmonyOS window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: harmonyos_capability_matrix(),
    services: harmonyos_service_capabilities(),
    input: harmonyos_input_capabilities(),
    readiness: harmonyos_readiness(),
    description: "HarmonyOS backend exposes a native-session contract: wzzc-dev/window/harmonyos supplies an XComponent native-window handle and lifecycle/input callbacks, while the backend selects a Skia renderer provider. The host path is usable for development (ready=true, status=runtime_partial). It is not product-complete until signed-device full L3 smoke and presenter verification close remaining gaps.",
  }
}

///|
pub fn harmonyos_capability_summary(
  services? : @host.HostServiceCapabilities = harmonyos_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=harmonyos_input_capabilities(),
    label="HarmonyOS host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="HarmonyOS native WebView is not part of the current mobile host contract.",
    description="HarmonyOS native host with window HostCmd lifecycle and an ApplicationHandler session. The window host owns lifecycle, surface, input, IME, clipboard, and accessibility adaptation. Runtime evidence remains partial.",
  )
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : HarmonyOsSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  provider~ : HarmonyOsRendererProvider,
) -> HarmonyOsRuntimeSession? {
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
pub fn HarmonyOsRuntimeSession::metrics(
  self : HarmonyOsRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.core.metrics()
}

///|
pub fn HarmonyOsRuntimeSession::surface(
  self : HarmonyOsRuntimeSession,
) -> HarmonyOsSurfaceHandle {
  self.surface
}

///|
pub fn HarmonyOsRuntimeSession::runtime(
  self : HarmonyOsRuntimeSession,
) -> @runtime.AppRuntime {
  self.core.runtime()
}

///|
pub fn HarmonyOsRuntimeSession::disposed(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.core.disposed()
}

///|
pub fn HarmonyOsRuntimeSession::surface_attached(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.core.surface_attached()
}

///|
pub fn HarmonyOsRuntimeSession::session_generation(
  self : HarmonyOsRuntimeSession,
) -> Int {
  self.core.session_generation()
}

///|
pub fn HarmonyOsRuntimeSession::surface_epoch(
  self : HarmonyOsRuntimeSession,
) -> Int {
  self.core.surface_epoch()
}

///|
pub fn HarmonyOsRuntimeSession::attach_surface(
  self : HarmonyOsRuntimeSession,
  surface : HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  provider : HarmonyOsRendererProvider,
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
pub fn HarmonyOsRuntimeSession::detach_surface(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  if self.core.detach_surface() {
    self.surface = HarmonyOsSurfaceHandle::none()
    true
  } else {
    false
  }
}

///|
pub fn HarmonyOsRuntimeSession::dispatch(
  self : HarmonyOsRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  self.core.dispatch(event)
}

///|
pub fn HarmonyOsRuntimeSession::resize(
  self : HarmonyOsRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.core.resize(metrics)
}

///|
pub fn HarmonyOsRuntimeSession::sync_surface(
  self : HarmonyOsRuntimeSession,
  provider : HarmonyOsRendererProvider,
) -> Unit {
  if self.surface_attached() {
    provider.sync(self.surface, self.core.metrics())
  }
}

///|
pub fn HarmonyOsRuntimeSession::render_frame(
  self : HarmonyOsRuntimeSession,
) -> @render.RenderFrameResult {
  self.core.render_frame()
}

///|
pub fn HarmonyOsRuntimeSession::advance_time(
  self : HarmonyOsRuntimeSession,
  time_ms : Double,
) -> Unit {
  self.core.advance_time(time_ms)
}

///|
pub fn HarmonyOsRuntimeSession::drain_host_updates(
  self : HarmonyOsRuntimeSession,
) -> Array[@embedded_runtime_session.EmbeddingHostUpdate] {
  self.core.drain_host_updates()
}

///|
pub fn HarmonyOsRuntimeSession::drain_host_updates_json(
  self : HarmonyOsRuntimeSession,
) -> String {
  self.core.drain_host_updates_json()
}

///|
pub fn HarmonyOsRuntimeSession::drain_host_update_envelope_json(
  self : HarmonyOsRuntimeSession,
) -> String {
  self.core.drain_host_update_envelope_json()
}

///|
pub fn HarmonyOsRuntimeSession::dispatch_host_response(
  self : HarmonyOsRuntimeSession,
  response : @embedded_runtime_session.EmbeddingHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn HarmonyOsRuntimeSession::dispatch_host_response_envelope(
  self : HarmonyOsRuntimeSession,
  envelope : @embedded_runtime_session.EmbeddingHostResponseEnvelope,
) -> Bool {
  self.core.dispatch_host_response_envelope(envelope)
}

///|
pub fn HarmonyOsRuntimeSession::dispatch_host_response_envelope_json(
  self : HarmonyOsRuntimeSession,
  text : String,
) -> Bool {
  self.core.dispatch_host_response_envelope_json(text)
}

///|
pub fn HarmonyOsRuntimeSession::host_service_bridge(
  self : HarmonyOsRuntimeSession,
) -> @host.HostServiceBridge {
  self.core.host_service_bridge()
}

///|
pub fn HarmonyOsRuntimeSession::redraw_requested(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.core.redraw_requested()
}

///|
pub fn HarmonyOsRuntimeSession::take_redraw_requested(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.core.take_redraw_requested()
}

///|
pub fn HarmonyOsRuntimeSession::present_count(
  self : HarmonyOsRuntimeSession,
) -> Int {
  self.core.present_count()
}

///|
pub fn HarmonyOsRuntimeSession::dispose(self : HarmonyOsRuntimeSession) -> Unit {
  self.core.dispose()
}
