///|

///|
let embedded_runtime_session_generation_counter : Ref[Int] = Ref(1)

///|
fn next_embedded_runtime_session_generation() -> Int {
  let generation = embedded_runtime_session_generation_counter.val
  embedded_runtime_session_generation_counter.val = generation + 1
  generation
}

///|
/// Shared runtime state for window-hosted mobile apps. Platform backends keep this
/// type behind their public session wrappers and own native-handle syncing.
pub struct EmbeddedSessionCore {
  priv runtime : @runtime.AppRuntime
  priv driver : @runtime.HostRuntimeDriver
  priv mut renderer : @render.HostWindowRenderer?
  priv transport : @host_session.HostSessionTransport
  priv mut host_bridge : EmbeddingHostBridge?
  priv mut image_coordinator : EmbeddedImageCoordinator?
  priv mut metrics : @host.HostSurfaceMetrics
  priv mut disposed : Bool
  priv mut async_image_ready_logged : Bool
  priv mut async_image_failed_logged : Bool
}

///|
pub fn EmbeddedSessionCore::new(
  runtime~ : @runtime.AppRuntime,
  renderer~ : @render.HostWindowRenderer,
  metrics~ : @host.HostSurfaceMetrics,
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> EmbeddedSessionCore {
  let transport = @host_session.HostSessionTransport::new(
    initial_generation=next_embedded_runtime_session_generation(),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    transport.request_frame()
  })
  driver.set_text_system(@core.TextSystem::fallback())
  let core : EmbeddedSessionCore = {
    runtime,
    driver,
    renderer: None,
    transport,
    host_bridge: None,
    image_coordinator: None,
    metrics,
    disposed: false,
    async_image_ready_logged: false,
    async_image_failed_logged: false,
  }
  ignore(core.attach_surface(renderer~, metrics~, image_loader~))
  core
}

///|
pub fn EmbeddedSessionCore::metrics(
  self : EmbeddedSessionCore,
) -> @host.HostSurfaceMetrics {
  self.metrics
}

///|
pub fn EmbeddedSessionCore::runtime(
  self : EmbeddedSessionCore,
) -> @runtime.AppRuntime {
  self.runtime
}

///|
pub fn EmbeddedSessionCore::disposed(self : EmbeddedSessionCore) -> Bool {
  self.disposed
}

///|
pub fn EmbeddedSessionCore::surface_attached(
  self : EmbeddedSessionCore,
) -> Bool {
  !self.disposed && self.renderer is Some(_)
}

///|
pub fn EmbeddedSessionCore::session_generation(
  self : EmbeddedSessionCore,
) -> Int {
  if self.surface_attached() {
    self.transport.session_generation()
  } else {
    0
  }
}

///|
pub fn EmbeddedSessionCore::surface_epoch(self : EmbeddedSessionCore) -> Int {
  self.transport.surface_epoch()
}

///|
pub fn EmbeddedSessionCore::attach_surface(
  self : EmbeddedSessionCore,
  renderer~ : @render.HostWindowRenderer,
  metrics~ : @host.HostSurfaceMetrics,
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> Bool {
  if self.disposed {
    renderer.dispose()
    return false
  }
  ignore(self.detach_surface())
  if !self.transport.attach() {
    renderer.dispose()
    return false
  }
  let host_bridge = EmbeddingHostBridge::new(
    session_generation=self.transport.session_generation(),
  )
  let image_coordinator = EmbeddedImageCoordinator::new(
    renderer~,
    image_loader~,
    request_redraw=() => self.transport.request_frame(),
  )
  self.renderer = Some(renderer)
  self.host_bridge = Some(host_bridge)
  self.image_coordinator = Some(image_coordinator)
  self.metrics = metrics
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  self.driver.set_text_system(renderer.text_system())
  ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
  self.transport.request_frame()
  true
}

///|
pub fn EmbeddedSessionCore::detach_surface(self : EmbeddedSessionCore) -> Bool {
  if self.disposed || self.renderer is None {
    return false
  }
  match self.host_bridge {
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
  self.host_bridge = None
  self.image_coordinator = None
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  ignore(self.transport.detach())
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
pub fn EmbeddedSessionCore::dispatch(
  self : EmbeddedSessionCore,
  event : @host.HostEvent,
) -> @host.HostEventResult {
  match self.host_bridge {
    Some(channel) if !self.disposed => {
      let result = self.driver.dispatch(event)
      ignore(channel.sync(self.runtime))
      result
    }
    _ => inactive_host_event_result()
  }
}

///|
pub fn EmbeddedSessionCore::resize(
  self : EmbeddedSessionCore,
  metrics : @host.HostSurfaceMetrics,
) -> @host.HostEventResult {
  match (self.renderer, self.host_bridge) {
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
pub fn EmbeddedSessionCore::render_frame(
  self : EmbeddedSessionCore,
) -> @render.RenderFrameResult {
  guard (self.renderer, self.host_bridge, self.image_coordinator)
    is (Some(renderer), Some(host_bridge), Some(image_coordinator)) &&
    !self.disposed else {
    return @render.RenderFrameResult::new()
  }
  self.driver.begin_redraw()
  let frame = self.driver.draw_frame()
  ignore(host_bridge.sync_platform_views(frame.platform_views))
  let result = renderer.render_frame(frame)
  ignore(renderer.drain_present_completions())
  self.driver.apply_render_frame_result(result)
  self.driver.finish_redraw()
  let image = image_coordinator.after_present(
    present_count=renderer.present_count(),
  )
  if image.scheduled_count > 0 {
    self.transport.request_frame()
    ignore(
      host_bridge.push_diagnostic(
        "moui-window service async-image phase=loading scheduled=\{image.scheduled_count} present=\{image.present_count}",
      ),
    )
  }
  if image.ready_count > 0 &&
    image.present_count > 1 &&
    !self.async_image_ready_logged {
    self.async_image_ready_logged = true
    ignore(
      host_bridge.push_diagnostic(
        "moui-window service async-image phase=ready ready=\{image.ready_count} present=\{image.present_count}",
      ),
    )
  }
  if image.failed_count > 0 && !self.async_image_failed_logged {
    self.async_image_failed_logged = true
    ignore(
      host_bridge.push_diagnostic(
        "moui-window service async-image phase=failed failed=\{image.failed_count} present=\{image.present_count}",
      ),
    )
  }
  ignore(host_bridge.sync(self.runtime))
  ignore(host_bridge.flush_updates_to_shell(self.transport))
  ignore(self.transport.finish_frame())
  result
}

///|
pub fn EmbeddedSessionCore::advance_time(
  self : EmbeddedSessionCore,
  time_ms : Double,
) -> Unit {
  if self.surface_attached() {
    self.runtime.advance_time(time_ms)
    match self.host_bridge {
      Some(bridge) => {
        ignore(bridge.sync(self.runtime))
        ignore(bridge.flush_updates_to_shell(self.transport))
      }
      None => ()
    }
  }
}

///|
pub fn EmbeddedSessionCore::drain_host_updates(
  self : EmbeddedSessionCore,
) -> Array[EmbeddingHostUpdate] {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      ignore(bridge.sync(self.runtime))
      bridge.drain_updates()
    }
    _ => []
  }
}

///|
pub fn EmbeddedSessionCore::drain_host_updates_json(
  self : EmbeddedSessionCore,
) -> String {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      ignore(bridge.sync(self.runtime))
      bridge.drain_updates_json()
    }
    _ => "[]"
  }
}

///|
pub fn EmbeddedSessionCore::drain_host_update_envelope_json(
  self : EmbeddedSessionCore,
) -> String {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      ignore(bridge.sync(self.runtime))
      ignore(bridge.flush_updates_to_shell(self.transport))
      self.transport.drain_update_envelope_json()
    }
    _ =>
      (
        {
          "schemaVersion": 1,
          "sessionGeneration": 0,
          "surfaceEpoch": 0,
          "updates": ([] : Array[Json]),
        } : Json).stringify()
  }
}

///|
pub fn EmbeddedSessionCore::dispatch_host_response(
  self : EmbeddedSessionCore,
  response : EmbeddingHostResponse,
) -> Bool {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      guard embedding_host_response_request_id(response) is None ||
        self.transport.complete_request(
          id=embedding_host_response_request_id(response).unwrap(),
        ) else {
        return false
      }
      let handled = bridge.dispatch_response(response, self.driver)
      if handled {
        ignore(bridge.sync(self.runtime))
        ignore(bridge.flush_updates_to_shell(self.transport))
      }
      handled
    }
    _ => false
  }
}

///|
pub fn EmbeddedSessionCore::dispatch_host_response_envelope(
  self : EmbeddedSessionCore,
  envelope : EmbeddingHostResponseEnvelope,
) -> Bool {
  match self.host_bridge {
    Some(bridge) if !self.disposed &&
      self.transport.accepts_response_generation(
        generation=envelope.session_generation,
      ) => {
      match embedding_host_response_request_id(envelope.response) {
        Some(id) if !self.transport.complete_request(id~) => return false
        _ => ()
      }
      let handled = bridge.dispatch_response_envelope(envelope, self.driver)
      if handled {
        ignore(bridge.sync(self.runtime))
        ignore(bridge.flush_updates_to_shell(self.transport))
      }
      handled
    }
    _ => false
  }
}

///|
pub fn EmbeddedSessionCore::host_service_bridge(
  self : EmbeddedSessionCore,
) -> @host.HostServiceBridge {
  match self.host_bridge {
    Some(bridge) if !self.disposed => bridge.service_bridge()
    _ => @host.HostServiceBridge::unavailable()
  }
}

///|
pub fn EmbeddedSessionCore::redraw_requested(
  self : EmbeddedSessionCore,
) -> Bool {
  self.surface_attached() && self.transport.frame_requested()
}

///|
pub fn EmbeddedSessionCore::take_redraw_requested(
  self : EmbeddedSessionCore,
) -> Bool {
  self.surface_attached() && self.transport.take_requested_frame()
}

///|
pub fn EmbeddedSessionCore::present_count(self : EmbeddedSessionCore) -> Int {
  match self.renderer {
    Some(renderer) if !self.disposed => renderer.present_count()
    _ => 0
  }
}

///|
pub fn EmbeddedSessionCore::dispose(self : EmbeddedSessionCore) -> Unit {
  if !self.disposed {
    ignore(self.detach_surface())
    ignore(self.transport.destroy())
    self.runtime.destroy()
    self.disposed = true
  }
}
