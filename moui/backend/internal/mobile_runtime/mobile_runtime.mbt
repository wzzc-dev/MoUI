///|
priv struct MobileRedrawSignal {
  mut requested : Bool
}

///|
let mobile_session_generation_counter : Ref[Int] = Ref(1)

///|
fn next_mobile_session_generation() -> Int {
  let generation = mobile_session_generation_counter.val
  mobile_session_generation_counter.val = generation + 1
  generation
}

///|
/// Shared runtime state for embedded mobile hosts. Platform backends keep this
/// type behind their public session wrappers and own native-handle syncing.
pub struct MobileRuntimeSessionCore {
  priv runtime : @runtime.AppRuntime
  priv driver : @host.HostRuntimeDriver
  priv mut renderer : @host.HostWindowRenderer?
  priv redraw_signal : MobileRedrawSignal
  priv mut host_channel : @host.MobileHostChannel?
  priv mut image_coordinator : @host.MobileImageCoordinator?
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
  driver.set_text_system(@core.TextSystem::fallback())
  let core : MobileRuntimeSessionCore = {
    runtime,
    driver,
    renderer: None,
    redraw_signal,
    host_channel: None,
    image_coordinator: None,
    metrics,
    disposed: false,
    async_image_follow_up: false,
    async_image_ready_logged: false,
    async_image_failed_logged: false,
  }
  ignore(core.attach_surface(renderer~, metrics~, image_loader~))
  core
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
pub fn MobileRuntimeSessionCore::surface_attached(
  self : MobileRuntimeSessionCore,
) -> Bool {
  !self.disposed && self.renderer is Some(_)
}

///|
pub fn MobileRuntimeSessionCore::session_generation(
  self : MobileRuntimeSessionCore,
) -> Int {
  match self.host_channel {
    Some(channel) => channel.session_generation()
    None => 0
  }
}

///|
pub fn MobileRuntimeSessionCore::attach_surface(
  self : MobileRuntimeSessionCore,
  renderer~ : @host.HostWindowRenderer,
  metrics~ : @host.HostSurfaceMetrics,
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> Bool {
  if self.disposed {
    renderer.dispose()
    return false
  }
  ignore(self.detach_surface())
  let host_channel = @host.MobileHostChannel::new(
    session_generation=next_mobile_session_generation(),
  )
  let image_coordinator = @host.MobileImageCoordinator::new(
    renderer~,
    image_loader~,
    request_redraw=() => self.redraw_signal.request(),
  )
  self.renderer = Some(renderer)
  self.host_channel = Some(host_channel)
  self.image_coordinator = Some(image_coordinator)
  self.metrics = metrics
  self.async_image_follow_up = false
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  self.driver.set_text_system(renderer.text_system())
  ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
  self.redraw_signal.request()
  true
}

///|
pub fn MobileRuntimeSessionCore::detach_surface(
  self : MobileRuntimeSessionCore,
) -> Bool {
  if self.disposed || self.renderer is None {
    return false
  }
  match self.host_channel {
    Some(channel) =>
      channel.dispose(
        driver=self.driver,
        reason="mobile surface epoch detached",
      )
    None => ()
  }
  match self.image_coordinator {
    Some(coordinator) => coordinator.dispose()
    None => ()
  }
  match self.renderer {
    Some(renderer) => renderer.dispose()
    None => ()
  }
  self.renderer = None
  self.host_channel = None
  self.image_coordinator = None
  self.async_image_follow_up = false
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  ignore(self.redraw_signal.take())
  self.driver.set_text_system(@core.TextSystem::fallback())
  true
}

///|
fn inactive_host_event_result() -> @host.HostEventResult {
  {
    close_requested: false,
    needs_rebuild: false,
    needs_redraw: false,
    redraw_requested: false,
  }
}

///|
pub fn MobileRuntimeSessionCore::dispatch(
  self : MobileRuntimeSessionCore,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      let result = self.driver.dispatch(event)
      ignore(channel.sync(self.runtime))
      result
    }
    _ => inactive_host_event_result()
  }
}

///|
pub fn MobileRuntimeSessionCore::resize(
  self : MobileRuntimeSessionCore,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  match (self.renderer, self.host_channel) {
    (Some(renderer), Some(channel)) if !self.disposed => {
      self.metrics = metrics
      renderer.resize(metrics)
      let result = self.driver.dispatch(@host.HostEvent::Resized(metrics))
      ignore(channel.sync(self.runtime))
      result
    }
    _ => inactive_host_event_result()
  }
}

///|
pub fn MobileRuntimeSessionCore::render_frame(
  self : MobileRuntimeSessionCore,
) -> @render.RenderFrameResult {
  guard (self.renderer, self.host_channel, self.image_coordinator)
    is (Some(renderer), Some(host_channel), Some(image_coordinator)) &&
    !self.disposed else {
    return @render.RenderFrameResult::new()
  }
  self.driver.begin_redraw()
  let frame = self.driver.draw_frame()
  ignore(host_channel.sync_platform_views(frame.platform_views))
  let result = renderer.render_frame(frame)
  ignore(renderer.drain_present_completions())
  self.driver.apply_render_frame_result(result)
  self.driver.finish_redraw()
  let image = image_coordinator.after_present(
    present_count=renderer.present_count(),
  )
  if image.scheduled_count > 0 {
    self.async_image_follow_up = true
    self.redraw_signal.request()
    ignore(
      host_channel.push_diagnostic(
        "moui-mobile service async-image phase=loading scheduled=\{image.scheduled_count} present=\{image.present_count}",
      ),
    )
  }
  if image.ready_count > 0 &&
    image.present_count > 1 &&
    !self.async_image_ready_logged {
    self.async_image_ready_logged = true
    ignore(
      host_channel.push_diagnostic(
        "moui-mobile service async-image phase=ready ready=\{image.ready_count} present=\{image.present_count}",
      ),
    )
  }
  if image.failed_count > 0 && !self.async_image_failed_logged {
    self.async_image_failed_logged = true
    ignore(
      host_channel.push_diagnostic(
        "moui-mobile service async-image phase=failed failed=\{image.failed_count} present=\{image.present_count}",
      ),
    )
  }
  ignore(host_channel.sync(self.runtime))
  result
}

///|
pub fn MobileRuntimeSessionCore::advance_time(
  self : MobileRuntimeSessionCore,
  time_ms : Double,
) -> Unit {
  if self.surface_attached() {
    self.runtime.advance_time(time_ms)
    match self.host_channel {
      Some(channel) => ignore(channel.sync(self.runtime))
      None => ()
    }
  }
}

///|
pub fn MobileRuntimeSessionCore::drain_host_updates(
  self : MobileRuntimeSessionCore,
) -> Array[@host.MobileHostUpdate] {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      ignore(channel.sync(self.runtime))
      channel.drain_updates()
    }
    _ => []
  }
}

///|
pub fn MobileRuntimeSessionCore::drain_host_updates_json(
  self : MobileRuntimeSessionCore,
) -> String {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      ignore(channel.sync(self.runtime))
      channel.drain_updates_json()
    }
    _ => "[]"
  }
}

///|
pub fn MobileRuntimeSessionCore::drain_host_update_envelope_json(
  self : MobileRuntimeSessionCore,
) -> String {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      ignore(channel.sync(self.runtime))
      channel.drain_update_envelope_json()
    }
    _ =>
      (
        {
          "schemaVersion": 1,
          "sessionGeneration": 0,
          "updates": ([] : Array[Json]),
        } : Json).stringify()
  }
}

///|
pub fn MobileRuntimeSessionCore::dispatch_host_response(
  self : MobileRuntimeSessionCore,
  response : @host.MobileHostResponse,
) -> Bool {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      let handled = channel.dispatch_response(response, self.driver)
      if handled {
        ignore(channel.sync(self.runtime))
      }
      handled
    }
    _ => false
  }
}

///|
pub fn MobileRuntimeSessionCore::dispatch_host_response_envelope(
  self : MobileRuntimeSessionCore,
  envelope : @host.MobileHostResponseEnvelope,
) -> Bool {
  match self.host_channel {
    Some(channel) if !self.disposed => {
      let handled = channel.dispatch_response_envelope(envelope, self.driver)
      if handled {
        ignore(channel.sync(self.runtime))
      }
      handled
    }
    _ => false
  }
}

///|
pub fn MobileRuntimeSessionCore::host_service_bridge(
  self : MobileRuntimeSessionCore,
) -> @host.HostServiceBridge {
  match self.host_channel {
    Some(channel) if !self.disposed => channel.service_bridge()
    _ => @host.HostServiceBridge::unavailable()
  }
}

///|
pub fn MobileRuntimeSessionCore::redraw_requested(
  self : MobileRuntimeSessionCore,
) -> Bool {
  self.surface_attached() && self.redraw_signal.requested
}

///|
pub fn MobileRuntimeSessionCore::take_redraw_requested(
  self : MobileRuntimeSessionCore,
) -> Bool {
  let requested = self.redraw_signal.take()
  if !self.surface_attached() {
    false
  } else if self.async_image_follow_up {
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
  match self.renderer {
    Some(renderer) if !self.disposed => renderer.present_count()
    _ => 0
  }
}

///|
pub fn MobileRuntimeSessionCore::dispose(
  self : MobileRuntimeSessionCore,
) -> Unit {
  if !self.disposed {
    ignore(self.detach_surface())
    self.runtime.destroy()
    self.disposed = true
  }
}
