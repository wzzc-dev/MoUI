///|
pub(all) struct AndroidSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

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
pub(all) struct AndroidBackendReadiness {
  ready : Bool
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
  priv create_renderer : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
priv struct AndroidRedrawSignal {
  mut requested : Bool
}

///|
pub struct AndroidRuntimeSession {
  priv surface : AndroidSurfaceHandle
  priv runtime : @runtime.AppRuntime
  priv driver : @host.HostRuntimeDriver
  priv renderer : @host.HostWindowRenderer
  priv redraw_signal : AndroidRedrawSignal
  priv mut metrics : @host.HostSurfaceMetrics
  priv mut disposed : Bool
}

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
pub fn AndroidRendererProvider::new(
  create_renderer~ : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (AndroidSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> AndroidRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn AndroidRendererProvider::create(
  self : AndroidRendererProvider,
  surface : AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostWindowRenderer? {
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
fn AndroidRedrawSignal::new() -> AndroidRedrawSignal {
  { requested: false }
}

///|
fn AndroidRedrawSignal::request(self : AndroidRedrawSignal) -> Unit {
  self.requested = true
}

///|
fn AndroidRedrawSignal::take(self : AndroidRedrawSignal) -> Bool {
  let requested = self.requested
  self.requested = false
  requested
}

///|
pub fn android_service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::none()
}

///|
pub fn android_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn android_capability_matrix() -> AndroidBackendCapabilities {
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
pub fn android_readiness() -> AndroidBackendReadiness {
  {
    ready: false,
    blocked_by: [
      "Android Activity/JNI lifecycle glue is not wired into a checked APK smoke yet",
      "native IME, clipboard, accessibility, and async image services still need matching-device evidence",
    ],
    next_steps: [
      "connect AndroidRuntimeSession to Activity/Surface callbacks through JNI or CMake glue",
      "record a matching Android device/emulator first-frame Skia smoke before marking runtime support passed",
    ],
  }
}

///|
pub fn backend_info() -> AndroidBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Android embedded native host scaffold driven by Activity/Surface callbacks",
    ),
    capabilities: android_capability_matrix(),
    services: android_service_capabilities(),
    input: android_input_capabilities(),
    readiness: android_readiness(),
    description: "Android backend exposes an embedded-session contract: the platform owner supplies an Android native surface handle, forwards lifecycle/input callbacks, and selects a renderer provider. It is not a passed runtime platform until device smoke evidence is recorded.",
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
    ime_available=false,
    drag_drop_available=false,
    async_services=false,
    native_accessibility_available=false,
    web_view_available=false,
    web_view_description="Android native WebView embedding is not wired in this scaffold.",
    description="Android embedded native host scaffold with external Activity/Surface lifecycle and app-driven input forwarding.",
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
      let redraw_signal = AndroidRedrawSignal::new()
      let driver = @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
        redraw_signal.request()
      })
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      provider.sync(surface, metrics)
      Some({
        surface,
        runtime,
        driver,
        renderer,
        redraw_signal,
        metrics,
        disposed: false,
      })
    }
    None => None
  }
}

///|
pub fn AndroidRuntimeSession::metrics(
  self : AndroidRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.metrics
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
  self.runtime
}

///|
pub fn AndroidRuntimeSession::disposed(self : AndroidRuntimeSession) -> Bool {
  self.disposed
}

///|
pub fn AndroidRuntimeSession::dispatch(
  self : AndroidRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  self.driver.dispatch(event)
}

///|
pub fn AndroidRuntimeSession::resize(
  self : AndroidRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.metrics = metrics
  self.renderer.resize(metrics)
  self.driver.dispatch(@host.HostEvent::Resized(metrics))
}

///|
pub fn AndroidRuntimeSession::sync_surface(
  self : AndroidRuntimeSession,
  provider : AndroidRendererProvider,
) -> Unit {
  provider.sync(self.surface, self.metrics)
}

///|
pub fn AndroidRuntimeSession::render_frame(
  self : AndroidRuntimeSession,
) -> @render.RenderFrameResult {
  self.driver.begin_redraw()
  let result = self.renderer.render_frame(self.driver.draw_frame())
  self.driver.apply_render_frame_result(result)
  self.driver.finish_redraw()
  result
}

///|
pub fn AndroidRuntimeSession::redraw_requested(
  self : AndroidRuntimeSession,
) -> Bool {
  self.redraw_signal.requested
}

///|
pub fn AndroidRuntimeSession::take_redraw_requested(
  self : AndroidRuntimeSession,
) -> Bool {
  self.redraw_signal.take()
}

///|
pub fn AndroidRuntimeSession::present_count(
  self : AndroidRuntimeSession,
) -> Int {
  self.renderer.present_count()
}

///|
pub fn AndroidRuntimeSession::dispose(self : AndroidRuntimeSession) -> Unit {
  if !self.disposed {
    self.renderer.dispose()
    self.runtime.destroy()
    self.disposed = true
  }
}
