///|

///|
let embedded_runtime_generation_counter : Ref[Int] = Ref(1)

///|
fn next_embedded_runtime_generation() -> Int {
  let generation = embedded_runtime_generation_counter.val
  embedded_runtime_generation_counter.val = generation + 1
  generation
}

///|
/// Shared runtime state for embedded runtime backends. Platform backends keep
/// this type behind their public session wrappers and own native-handle syncing.
pub struct EmbeddedRuntimeBackendCore {
  priv runtime : @runtime.AppRuntime
  priv driver : @runtime.HostRuntimeDriver
  priv mut renderer : @render.WindowRenderer?
  priv transport : @host_services_embedded.HostSessionTransport
  priv mut host_bridge : EmbeddedRuntimeHostBridge?
  frame : @window_host.FrameCoordinator
  priv mut metrics : @core.SurfaceMetrics
  priv mut disposed : Bool
  priv mut async_image_ready_logged : Bool
  priv mut async_image_failed_logged : Bool
}

///|
pub fn EmbeddedRuntimeBackendCore::new(
  runtime~ : @runtime.AppRuntime,
  renderer~ : @render.WindowRenderer,
  metrics~ : @core.SurfaceMetrics,
  surface_generation~ : Int,
  image_loader? : @render.ImageLoader? = None,
  frame? : @window_host.FrameCoordinator? = None,
) -> EmbeddedRuntimeBackendCore {
  let transport = @host_services_embedded.HostSessionTransport::new(
    initial_generation=next_embedded_runtime_generation(),
  )
  let frame = match frame {
    Some(frame) => frame
    None =>
      @window_host.FrameCoordinator::new(
        hooks=@window_host.WindowFrameHooks::new(request_redraw=() => {
          transport.request_frame()
        }),
      )
  }
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    transport.request_frame()
  })
  driver.set_text_system(@core.TextSystem::fallback())
  let core : EmbeddedRuntimeBackendCore = {
    runtime,
    driver,
    renderer: None,
    transport,
    host_bridge: None,
    frame,
    metrics,
    disposed: false,
    async_image_ready_logged: false,
    async_image_failed_logged: false,
  }
  ignore(
    core.attach_surface(renderer~, metrics~, surface_generation~, image_loader~),
  )
  core
}

///|
pub fn EmbeddedRuntimeBackendCore::metrics(
  self : EmbeddedRuntimeBackendCore,
) -> @core.SurfaceMetrics {
  self.metrics
}

///|
pub fn EmbeddedRuntimeBackendCore::runtime(
  self : EmbeddedRuntimeBackendCore,
) -> @runtime.AppRuntime {
  self.runtime
}

///|
pub fn EmbeddedRuntimeBackendCore::disposed(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  self.disposed
}

///|
pub fn EmbeddedRuntimeBackendCore::surface_attached(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  !self.disposed && self.renderer is Some(_)
}

///|
pub fn EmbeddedRuntimeBackendCore::session_generation(
  self : EmbeddedRuntimeBackendCore,
) -> Int {
  if self.surface_attached() {
    self.transport.session_generation()
  } else {
    0
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::surface_epoch(
  self : EmbeddedRuntimeBackendCore,
) -> Int {
  self.transport.surface_epoch()
}

///|
pub fn EmbeddedRuntimeBackendCore::attach_surface(
  self : EmbeddedRuntimeBackendCore,
  renderer~ : @render.WindowRenderer,
  metrics~ : @core.SurfaceMetrics,
  surface_generation~ : Int,
  image_loader? : @render.ImageLoader? = None,
) -> Bool {
  if self.disposed {
    renderer.dispose()
    return false
  }
  ignore(self.detach_surface())
  if !self.transport.attach(surface_epoch=surface_generation) {
    renderer.dispose()
    return false
  }
  let host_bridge = EmbeddedRuntimeHostBridge::new(
    session_generation=self.transport.session_generation(),
  )
  self.renderer = Some(renderer)
  self.host_bridge = Some(host_bridge)
  self.frame.attach_image_resources(
    @render.RenderWindowId::new(1),
    renderer,
    image_loader,
  )
  self.metrics = metrics
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  self.driver.set_text_system(renderer.text_system())
  ignore(self.driver.dispatch(@host.Event::Resized(metrics)))
  self.transport.request_frame()
  true
}

///|
pub fn EmbeddedRuntimeBackendCore::detach_surface(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  if self.disposed || self.renderer is None {
    return false
  }
  match self.host_bridge {
    Some(channel) =>
      channel.dispose(
        driver=self.driver,
        reason="embedded runtime surface epoch detached",
      )
    None => ()
  }
  self.frame.dispose_image_resources()
  match self.renderer {
    Some(renderer) => renderer.dispose()
    None => ()
  }
  self.renderer = None
  self.host_bridge = None
  self.async_image_ready_logged = false
  self.async_image_failed_logged = false
  ignore(self.transport.detach())
  self.driver.set_text_system(@core.TextSystem::fallback())
  true
}

///|
fn inactive_host_event_result() -> @host.EventResult {
  {
    close_requested: false,
    needs_rebuild: false,
    needs_redraw: false,
    redraw_requested: false,
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::dispatch(
  self : EmbeddedRuntimeBackendCore,
  event : @host.Event,
) -> @host.EventResult {
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
pub fn EmbeddedRuntimeBackendCore::resize(
  self : EmbeddedRuntimeBackendCore,
  metrics : @core.SurfaceMetrics,
) -> @host.EventResult {
  match (self.renderer, self.host_bridge) {
    (Some(renderer), Some(channel)) if !self.disposed => {
      self.metrics = metrics
      renderer.resize(
        @core.SurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      )
      let result = self.driver.dispatch(@host.Event::Resized(metrics))
      ignore(channel.sync(self.runtime))
      result
    }
    _ => inactive_host_event_result()
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::render_frame(
  self : EmbeddedRuntimeBackendCore,
) -> @render.RenderFrameResult {
  guard (self.renderer, self.host_bridge) is (Some(renderer), Some(host_bridge)) &&
    !self.disposed else {
    return @render.RenderFrameResult::new()
  }
  let prior_completions = if self.frame.pending() {
    renderer.drain_present_completions()
  } else {
    []
  }
  let prior_presented = @render.render_present_completions_have_presented(
    prior_completions,
  )
  let prior_terminal = @render.render_present_completions_have_terminal(
    prior_completions,
  )
  if self.frame.pending() {
    ignore(self.frame.finish_presented(true, prior_terminal, prior_presented))
    if self.frame.pending() {
      return @render.RenderFrameResult::new(queued=true)
    }
    if prior_presented {
      ignore(
        self.frame.finish_image_frame(renderer.present_count(), presented=true),
      )
      let state = self.driver.event_result()
      if !state.needs_redraw && !state.redraw_requested {
        return @render.RenderFrameResult::new(presented=true)
      }
    }
  }
  if !self.frame.prepare_frame() {
    return @render.RenderFrameResult::new(queued=true)
  }
  self.driver.begin_redraw()
  let frame = self.driver.draw_frame()
  ignore(host_bridge.sync_platform_views(frame.platform_views))
  let result = renderer.render_frame(frame)
  let completions = renderer.drain_present_completions()
  let completion_presented = @render.render_present_completions_have_presented(
    completions,
  )
  let completion_terminal = @render.render_present_completions_have_terminal(
    completions,
  )
  let presented = completion_presented ||
    (completions.is_empty() && result.presented)
  ignore(
    self.frame.finish_presented(result.queued, completion_terminal, presented),
  )
  self.driver.apply_render_frame_result(result)
  self.driver.finish_redraw()
  let image = self.frame.finish_image_frame(
    renderer.present_count(),
    presented~,
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
pub fn EmbeddedRuntimeBackendCore::advance_time(
  self : EmbeddedRuntimeBackendCore,
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
pub fn EmbeddedRuntimeBackendCore::drain_host_updates(
  self : EmbeddedRuntimeBackendCore,
) -> Array[EmbeddedHostUpdate] {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      ignore(bridge.sync(self.runtime))
      bridge.drain_updates()
    }
    _ => []
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::drain_host_updates_json(
  self : EmbeddedRuntimeBackendCore,
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
pub fn EmbeddedRuntimeBackendCore::drain_host_update_envelope_json(
  self : EmbeddedRuntimeBackendCore,
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
pub fn EmbeddedRuntimeBackendCore::dispatch_host_response(
  self : EmbeddedRuntimeBackendCore,
  response : EmbeddedHostResponse,
) -> Bool {
  match self.host_bridge {
    Some(bridge) if !self.disposed => {
      guard embedded_host_response_request_id(response) is None ||
        self.transport.complete_request(
          id=embedded_host_response_request_id(response).unwrap(),
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
pub fn EmbeddedRuntimeBackendCore::dispatch_host_response_envelope(
  self : EmbeddedRuntimeBackendCore,
  envelope : EmbeddedHostResponseEnvelope,
) -> Bool {
  match self.host_bridge {
    Some(bridge) if !self.disposed &&
      self.transport.accepts_response_generation(
        generation=envelope.session_generation,
      ) => {
      match embedded_host_response_request_id(envelope.response) {
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
pub fn EmbeddedRuntimeBackendCore::host_service_bridge(
  self : EmbeddedRuntimeBackendCore,
) -> @host.HostServiceBridge {
  match self.host_bridge {
    Some(bridge) if !self.disposed => bridge.service_bridge()
    _ => @host.HostServiceBridge::unavailable()
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::redraw_requested(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  self.surface_attached() && self.transport.frame_requested()
}

///|
pub fn EmbeddedRuntimeBackendCore::take_redraw_requested(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  self.surface_attached() && self.transport.take_requested_frame()
}

///|
pub fn EmbeddedRuntimeBackendCore::present_count(
  self : EmbeddedRuntimeBackendCore,
) -> Int {
  match self.renderer {
    Some(renderer) if !self.disposed => renderer.present_count()
    _ => 0
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::dispose(
  self : EmbeddedRuntimeBackendCore,
) -> Unit {
  if !self.disposed {
    ignore(self.detach_surface())
    ignore(self.transport.destroy())
    self.runtime.destroy()
    self.disposed = true
  }
}
