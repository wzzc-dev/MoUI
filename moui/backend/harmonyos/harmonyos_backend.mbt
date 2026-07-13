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
priv struct HarmonyOsRedrawSignal {
  mut requested : Bool
}

///|
pub struct HarmonyOsRuntimeSession {
  priv surface : HarmonyOsSurfaceHandle
  priv runtime : @runtime.AppRuntime
  priv driver : @host.HostRuntimeDriver
  priv renderer : @host.HostWindowRenderer
  priv redraw_signal : HarmonyOsRedrawSignal
  priv host_channel : @host.MobileHostChannel
  priv image_coordinator : @host.MobileImageCoordinator
  priv mut metrics : @host.HostSurfaceMetrics
  priv mut disposed : Bool
  priv mut async_image_follow_up : Bool
  priv mut async_image_ready_logged : Bool
  priv mut async_image_failed_logged : Bool
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
fn HarmonyOsRedrawSignal::new() -> HarmonyOsRedrawSignal {
  { requested: false }
}

///|
fn HarmonyOsRedrawSignal::request(self : HarmonyOsRedrawSignal) -> Unit {
  self.requested = true
}

///|
fn HarmonyOsRedrawSignal::take(self : HarmonyOsRedrawSignal) -> Bool {
  let requested = self.requested
  self.requested = false
  requested
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
      let redraw_signal = HarmonyOsRedrawSignal::new()
      let driver = @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
        redraw_signal.request()
      })
      let host_channel = @host.MobileHostChannel::new()
      let image_coordinator = @host.MobileImageCoordinator::new(
        renderer~,
        image_loader=provider.image_loader,
        request_redraw=() => redraw_signal.request(),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      provider.sync(surface, metrics)
      Some({
        surface,
        runtime,
        driver,
        renderer,
        redraw_signal,
        host_channel,
        image_coordinator,
        metrics,
        disposed: false,
        async_image_follow_up: false,
        async_image_ready_logged: false,
        async_image_failed_logged: false,
      })
    }
    None => None
  }
}

///|
pub fn HarmonyOsRuntimeSession::metrics(
  self : HarmonyOsRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.metrics
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
  self.runtime
}

///|
pub fn HarmonyOsRuntimeSession::disposed(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.disposed
}

///|
pub fn HarmonyOsRuntimeSession::dispatch(
  self : HarmonyOsRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  let result = self.driver.dispatch(event)
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn HarmonyOsRuntimeSession::resize(
  self : HarmonyOsRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.metrics = metrics
  self.renderer.resize(metrics)
  let result = self.driver.dispatch(@host.HostEvent::Resized(metrics))
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn HarmonyOsRuntimeSession::sync_surface(
  self : HarmonyOsRuntimeSession,
  provider : HarmonyOsRendererProvider,
) -> Unit {
  provider.sync(self.surface, self.metrics)
}

///|
pub fn HarmonyOsRuntimeSession::render_frame(
  self : HarmonyOsRuntimeSession,
) -> @render.RenderFrameResult {
  self.driver.begin_redraw()
  let result = self.renderer.render_frame(self.driver.draw_frame())
  ignore(self.renderer.drain_present_completions())
  self.driver.apply_render_frame_result(result)
  self.driver.finish_redraw()
  let image = self.image_coordinator.after_present(
    present_count=self.renderer.present_count(),
  )
  if image.scheduled_count > 0 {
    self.async_image_follow_up = true
    self.redraw_signal.request()
    ignore(
      self.host_channel.push_diagnostic(
        "moui-mobile service async-image phase=loading scheduled=\{image.scheduled_count} present=\{image.present_count}",
      ),
    )
  }
  if image.ready_count > 0 &&
    image.present_count > 1 &&
    !self.async_image_ready_logged {
    self.async_image_ready_logged = true
    ignore(
      self.host_channel.push_diagnostic(
        "moui-mobile service async-image phase=ready ready=\{image.ready_count} present=\{image.present_count}",
      ),
    )
  }
  if image.failed_count > 0 && !self.async_image_failed_logged {
    self.async_image_failed_logged = true
    ignore(
      self.host_channel.push_diagnostic(
        "moui-mobile service async-image phase=failed failed=\{image.failed_count} present=\{image.present_count}",
      ),
    )
  }
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn HarmonyOsRuntimeSession::advance_time(
  self : HarmonyOsRuntimeSession,
  time_ms : Double,
) -> Unit {
  if !self.disposed {
    self.runtime.advance_time(time_ms)
    ignore(self.host_channel.sync(self.runtime))
  }
}

///|
pub fn HarmonyOsRuntimeSession::drain_host_updates(
  self : HarmonyOsRuntimeSession,
) -> Array[@host.MobileHostUpdate] {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates()
}

///|
pub fn HarmonyOsRuntimeSession::drain_host_updates_json(
  self : HarmonyOsRuntimeSession,
) -> String {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates_json()
}

///|
pub fn HarmonyOsRuntimeSession::dispatch_host_response(
  self : HarmonyOsRuntimeSession,
  response : @host.MobileHostResponse,
) -> Bool {
  let handled = self.host_channel.dispatch_response(response, self.driver)
  if handled {
    ignore(self.host_channel.sync(self.runtime))
  }
  handled
}

///|
pub fn HarmonyOsRuntimeSession::host_service_bridge(
  self : HarmonyOsRuntimeSession,
) -> @host.HostServiceBridge {
  self.host_channel.service_bridge()
}

///|
pub fn HarmonyOsRuntimeSession::redraw_requested(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  self.redraw_signal.requested
}

///|
pub fn HarmonyOsRuntimeSession::take_redraw_requested(
  self : HarmonyOsRuntimeSession,
) -> Bool {
  let requested = self.redraw_signal.take()
  if self.async_image_follow_up {
    self.async_image_follow_up = false
    true
  } else {
    requested
  }
}

///|
pub fn HarmonyOsRuntimeSession::present_count(
  self : HarmonyOsRuntimeSession,
) -> Int {
  self.renderer.present_count()
}

///|
pub fn HarmonyOsRuntimeSession::dispose(self : HarmonyOsRuntimeSession) -> Unit {
  if !self.disposed {
    self.host_channel.dispose()
    self.image_coordinator.dispose()
    self.renderer.dispose()
    self.runtime.destroy()
    self.disposed = true
  }
}
