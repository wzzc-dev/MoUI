///|
priv struct MobileRedrawSignal {
  mut requested : Bool
}

///|
/// Shared runtime state for embedded mobile hosts. Platform backends keep this
/// type behind their public session wrappers and own native-handle syncing.
pub struct MobileRuntimeSessionCore {
  priv runtime : @runtime.AppRuntime
  priv driver : @host.HostRuntimeDriver
  priv renderer : @host.HostWindowRenderer
  priv redraw_signal : MobileRedrawSignal
  priv host_channel : @host.MobileHostChannel
  priv image_coordinator : @host.MobileImageCoordinator
  priv mut metrics : @host.HostSurfaceMetrics
  priv mut disposed : Bool
  priv mut async_image_follow_up : Bool
  priv mut async_image_ready_logged : Bool
  priv mut async_image_failed_logged : Bool
}

///|
fn MobileRedrawSignal::new() -> MobileRedrawSignal {
  { requested: false }
}

///|
fn MobileRedrawSignal::request(self : MobileRedrawSignal) -> Unit {
  self.requested = true
}

///|
fn MobileRedrawSignal::take(self : MobileRedrawSignal) -> Bool {
  let requested = self.requested
  self.requested = false
  requested
}

///|
pub fn MobileRuntimeSessionCore::new(
  runtime~ : @runtime.AppRuntime,
  renderer~ : @host.HostWindowRenderer,
  metrics~ : @host.HostSurfaceMetrics,
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> MobileRuntimeSessionCore {
  let redraw_signal = MobileRedrawSignal::new()
  let driver = @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    redraw_signal.request()
  })
  let host_channel = @host.MobileHostChannel::new()
  let image_coordinator = @host.MobileImageCoordinator::new(
    renderer~,
    image_loader~,
    request_redraw=() => redraw_signal.request(),
  )
  driver.set_text_system(renderer.text_system())
  ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
  {
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
  }
}

///|
pub fn MobileRuntimeSessionCore::metrics(
  self : MobileRuntimeSessionCore,
) -> @host.HostSurfaceMetrics {
  self.metrics
}

///|
pub fn MobileRuntimeSessionCore::runtime(
  self : MobileRuntimeSessionCore,
) -> @runtime.AppRuntime {
  self.runtime
}

///|
pub fn MobileRuntimeSessionCore::disposed(
  self : MobileRuntimeSessionCore,
) -> Bool {
  self.disposed
}

///|
pub fn MobileRuntimeSessionCore::dispatch(
  self : MobileRuntimeSessionCore,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  let result = self.driver.dispatch(event)
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn MobileRuntimeSessionCore::resize(
  self : MobileRuntimeSessionCore,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  self.metrics = metrics
  self.renderer.resize(metrics)
  let result = self.driver.dispatch(@host.HostEvent::Resized(metrics))
  ignore(self.host_channel.sync(self.runtime))
  result
}

///|
pub fn MobileRuntimeSessionCore::render_frame(
  self : MobileRuntimeSessionCore,
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
pub fn MobileRuntimeSessionCore::advance_time(
  self : MobileRuntimeSessionCore,
  time_ms : Double,
) -> Unit {
  if !self.disposed {
    self.runtime.advance_time(time_ms)
    ignore(self.host_channel.sync(self.runtime))
  }
}

///|
pub fn MobileRuntimeSessionCore::drain_host_updates(
  self : MobileRuntimeSessionCore,
) -> Array[@host.MobileHostUpdate] {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates()
}

///|
pub fn MobileRuntimeSessionCore::drain_host_updates_json(
  self : MobileRuntimeSessionCore,
) -> String {
  ignore(self.host_channel.sync(self.runtime))
  self.host_channel.drain_updates_json()
}

///|
pub fn MobileRuntimeSessionCore::dispatch_host_response(
  self : MobileRuntimeSessionCore,
  response : @host.MobileHostResponse,
) -> Bool {
  let handled = self.host_channel.dispatch_response(response, self.driver)
  if handled {
    ignore(self.host_channel.sync(self.runtime))
  }
  handled
}

///|
pub fn MobileRuntimeSessionCore::host_service_bridge(
  self : MobileRuntimeSessionCore,
) -> @host.HostServiceBridge {
  self.host_channel.service_bridge()
}

///|
pub fn MobileRuntimeSessionCore::redraw_requested(
  self : MobileRuntimeSessionCore,
) -> Bool {
  self.redraw_signal.requested
}

///|
pub fn MobileRuntimeSessionCore::take_redraw_requested(
  self : MobileRuntimeSessionCore,
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
pub fn MobileRuntimeSessionCore::present_count(
  self : MobileRuntimeSessionCore,
) -> Int {
  self.renderer.present_count()
}

///|
pub fn MobileRuntimeSessionCore::dispose(
  self : MobileRuntimeSessionCore,
) -> Unit {
  if !self.disposed {
    self.host_channel.dispose()
    self.image_coordinator.dispose()
    self.renderer.dispose()
    self.runtime.destroy()
    self.disposed = true
  }
}
