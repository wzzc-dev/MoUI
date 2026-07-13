///|
pub(all) struct IosViewHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

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
pub(all) struct IosBackendReadiness {
  ready : Bool
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
priv struct IosRedrawSignal {
  mut requested : Bool
}

///|
pub struct IosRuntimeSession {
  priv view : IosViewHandle
  priv runtime : @runtime.AppRuntime
  priv driver : @host.HostRuntimeDriver
  priv renderer : @host.HostWindowRenderer
  priv redraw_signal : IosRedrawSignal
  priv host_channel : @host.MobileHostChannel
  priv image_coordinator : @host.MobileImageCoordinator
  priv mut metrics : @host.HostSurfaceMetrics
  priv mut disposed : Bool
  priv mut async_image_follow_up : Bool
  priv mut async_image_ready_logged : Bool
  priv mut async_image_failed_logged : Bool
}

///|
pub fn IosViewHandle::new(raw~ : UInt64) -> IosViewHandle {
  { raw, }
}

///|
pub fn IosViewHandle::none() -> IosViewHandle {
  { raw: 0UL }
}

///|
pub fn IosViewHandle::raw(self : IosViewHandle) -> UInt64 {
  self.raw
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
fn IosRedrawSignal::new() -> IosRedrawSignal {
  { requested: false }
}

///|
fn IosRedrawSignal::request(self : IosRedrawSignal) -> Unit {
  self.requested = true
}

///|
fn IosRedrawSignal::take(self : IosRedrawSignal) -> Bool {
  let requested = self.requested
  self.requested = false
  requested
}

///|
pub fn ios_service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::none()
}

///|
pub fn ios_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn ios_capability_matrix() -> IosBackendCapabilities {
  {
    embedded_view: true,
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
pub fn ios_readiness() -> IosBackendReadiness {
  {
    ready: false,
    blocked_by: [
      "UIKit UIViewController lifecycle glue has only an experimental Counter simulator shell",
      "first-frame, tap input, resize/lifecycle, IME, clipboard, accessibility, and async image services still need matching-simulator evidence",
    ],
    next_steps: [
      "record a matching iOS Simulator first-frame Skia smoke before marking runtime support passed",
      "add native UIKit service bridges for IME, clipboard, accessibility, and async image loading when evidence requirements are defined",
    ],
  }
}

///|
pub fn backend_info() -> IosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="iOS embedded native host scaffold driven by UIKit UIView callbacks",
    ),
    capabilities: ios_capability_matrix(),
    services: ios_service_capabilities(),
    input: ios_input_capabilities(),
    readiness: ios_readiness(),
    description: "iOS backend exposes an embedded-session contract: the platform owner supplies a UIKit UIView handle, forwards lifecycle/input callbacks, and selects a renderer provider. It is not a passed runtime platform until simulator or device smoke evidence is recorded.",
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
    ime_available=false,
    drag_drop_available=false,
    async_services=false,
    native_accessibility_available=false,
    web_view_available=false,
    web_view_description="iOS native WKWebView embedding is not wired in this scaffold.",
    description="iOS embedded native host scaffold with external UIKit lifecycle and app-driven input forwarding.",
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
      let redraw_signal = IosRedrawSignal::new()
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
      provider.sync(view, metrics)
      Some({
        view,
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
pub fn IosRuntimeSession::metrics(
  self : IosRuntimeSession,
) -> @host.HostSurfaceMetrics {
  self.metrics
}

///|
pub fn IosRuntimeSession::view(self : IosRuntimeSession) -> IosViewHandle {
  self.view
}

///|
pub fn IosRuntimeSession::runtime(
  self : IosRuntimeSession,
) -> @runtime.AppRuntime {
  self.runtime
}

///|
pub fn IosRuntimeSession::disposed(self : IosRuntimeSession) -> Bool {
  self.disposed
}

///|
pub fn IosRuntimeSession::dispatch(
  self : IosRuntimeSession,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  let result = self.driver.dispatch(event)
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn IosRuntimeSession::resize(
  self : IosRuntimeSession,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.metrics = metrics
  self.renderer.resize(metrics)
  let result = self.driver.dispatch(@host.HostEvent::Resized(metrics))
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn IosRuntimeSession::sync_view(
  self : IosRuntimeSession,
  provider : IosRendererProvider,
) -> Unit {
  provider.sync(self.view, self.metrics)
}

///|
pub fn IosRuntimeSession::render_frame(
  self : IosRuntimeSession,
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
pub fn IosRuntimeSession::advance_time(
  self : IosRuntimeSession,
  time_ms : Double,
) -> Unit {
  if !self.disposed {
    self.runtime.advance_time(time_ms)
    ignore(self.host_channel.sync(self.runtime))
  }
}

///|
pub fn IosRuntimeSession::drain_host_updates(
  self : IosRuntimeSession,
) -> Array[@host.MobileHostUpdate] {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates()
}

///|
pub fn IosRuntimeSession::drain_host_updates_json(
  self : IosRuntimeSession,
) -> String {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates_json()
}

///|
pub fn IosRuntimeSession::dispatch_host_response(
  self : IosRuntimeSession,
  response : @host.MobileHostResponse,
) -> Bool {
  let handled = self.host_channel.dispatch_response(response, self.driver)
  if handled {
    ignore(self.host_channel.sync(self.runtime))
  }
  handled
}

///|
pub fn IosRuntimeSession::host_service_bridge(
  self : IosRuntimeSession,
) -> @host.HostServiceBridge {
  self.host_channel.service_bridge()
}

///|
pub fn IosRuntimeSession::redraw_requested(self : IosRuntimeSession) -> Bool {
  self.redraw_signal.requested
}

///|
pub fn IosRuntimeSession::take_redraw_requested(
  self : IosRuntimeSession,
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
pub fn IosRuntimeSession::present_count(self : IosRuntimeSession) -> Int {
  self.renderer.present_count()
}

///|
pub fn IosRuntimeSession::dispose(self : IosRuntimeSession) -> Unit {
  if !self.disposed {
    self.host_channel.dispose()
    self.image_coordinator.dispose()
    self.renderer.dispose()
    self.runtime.destroy()
    self.disposed = true
  }
}
