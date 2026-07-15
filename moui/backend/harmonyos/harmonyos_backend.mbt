///|
pub(all) struct HarmonyOsSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

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
pub(all) struct HarmonyOsBackendReadiness {
  ready : Bool
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
  priv create_renderer : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
pub struct HarmonyOsRuntimeSession {
  priv mut surface : HarmonyOsSurfaceHandle
  priv core : @mobile_runtime.MobileRuntimeSessionCore
}

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
pub fn HarmonyOsRendererProvider::new(
  create_renderer~ : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (HarmonyOsSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> HarmonyOsRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn HarmonyOsRendererProvider::create(
  self : HarmonyOsRendererProvider,
  surface : HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostWindowRenderer? {
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
  @host.HostServiceCapabilities::none()
}

///|
pub fn harmonyos_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=false,
    clipboard=false,
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
    ime: false,
    clipboard: false,
    system_theme: false,
    accessibility: false,
    async_image: false,
  }
}

///|
pub fn harmonyos_readiness() -> HarmonyOsBackendReadiness {
  {
    ready: false,
    blocked_by: [
      "HarmonyOS ArkTS Stage Ability, XComponent, and NAPI lifecycle glue is experimental and not backed by device smoke yet",
      "first-frame, tap input, resize/lifecycle, IME, clipboard, accessibility, and async image services still need matching-device evidence",
    ],
    next_steps: [
      "connect HarmonyOsRuntimeSession to Stage Ability and XComponent callbacks through NAPI native glue",
      "record a matching HarmonyOS device/emulator first-frame Skia smoke before marking runtime support passed",
    ],
  }
}

///|
pub fn backend_info() -> HarmonyOsBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="HarmonyOS embedded native host scaffold driven by Stage Ability/XComponent callbacks",
    ),
    capabilities: harmonyos_capability_matrix(),
    services: harmonyos_service_capabilities(),
    input: harmonyos_input_capabilities(),
    readiness: harmonyos_readiness(),
    description: "HarmonyOS backend exposes an embedded-session contract: the platform owner supplies a native XComponent surface handle, forwards lifecycle/input callbacks, and selects a renderer provider. It is not a passed runtime platform until device or emulator smoke evidence is recorded.",
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
    ime_available=false,
    drag_drop_available=false,
    async_services=false,
    native_accessibility_available=false,
    web_view_available=false,
    web_view_description="HarmonyOS native WebView embedding is not wired in this scaffold.",
    description="HarmonyOS embedded native host scaffold with external Stage Ability/XComponent lifecycle and app-driven input forwarding.",
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
      let core = @mobile_runtime.MobileRuntimeSessionCore::new(
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
) -> Array[@host.MobileHostUpdate] {
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
  response : @host.MobileHostResponse,
) -> Bool {
  self.core.dispatch_host_response(response)
}

///|
pub fn HarmonyOsRuntimeSession::dispatch_host_response_envelope(
  self : HarmonyOsRuntimeSession,
  envelope : @host.MobileHostResponseEnvelope,
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
