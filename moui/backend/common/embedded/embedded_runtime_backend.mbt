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
  priv transport : @host_services_embedded.HostSessionTransport
  priv mut host_bridge : EmbeddedRuntimeHostBridge?
  priv mut frame : @window_frame.WindowFrameState?
  priv mut image : @window_image.WindowImageTasks?
  priv mut metrics : @core.SurfaceMetrics
  priv mut disposed : Bool
}

///|
pub fn EmbeddedRuntimeBackendCore::new(
  runtime~ : @runtime.AppRuntime,
  renderer~ : @render.RendererSession,
  metrics~ : @core.SurfaceMetrics,
  surface_generation~ : Int,
) -> EmbeddedRuntimeBackendCore {
  let transport = @host_services_embedded.HostSessionTransport::new(
    initial_generation=next_embedded_runtime_generation(),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    transport.request_frame()
  })
  driver.set_text_system(@core.TextSystem::fallback())
  let core : EmbeddedRuntimeBackendCore = {
    runtime,
    driver,
    transport,
    host_bridge: None,
    frame: None,
    image: None,
    metrics,
    disposed: false,
  }
  ignore(
    core.attach_surface(renderer~, metrics~, surface_generation~),
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
  !self.disposed && self.frame is Some(_)
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
  renderer~ : @render.RendererSession,
  metrics~ : @core.SurfaceMetrics,
  surface_generation~ : Int,
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
  let frame = @window_frame.WindowFrameState::new(
    renderer~,
    surface_generation~,
    hooks=@window_frame.WindowFrameHooks::new(request_redraw=() => {
      self.transport.request_frame()
    }),
  )
  let image = @window_image.WindowImageTasks::new(
    request_redraw=() => self.transport.request_frame(),
  )
  self.frame = Some(frame)
  self.image = Some(image)
  self.host_bridge = Some(host_bridge)
  self.metrics = metrics
  self.driver.set_text_system(renderer.text_system())
  ignore(self.driver.dispatch(@host.Event::Resized(metrics)))
  self.transport.request_frame()
  true
}

///|
pub fn EmbeddedRuntimeBackendCore::detach_surface(
  self : EmbeddedRuntimeBackendCore,
) -> Bool {
  if self.disposed || self.frame is None {
    return false
  }
  let frame = self.frame
  let image = self.image
  let host_bridge = self.host_bridge
  self.frame = None
  self.image = None
  self.host_bridge = None
  match image {
    Some(owner) => owner.dispose()
    None => ()
  }
  match host_bridge {
    Some(channel) =>
      channel.dispose(
        driver=self.driver,
        reason="embedded runtime surface epoch detached",
      )
    None => ()
  }
  match frame {
    Some(owner) => owner.dispose()
    None => ()
  }
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
  match (self.frame, self.host_bridge) {
    (Some(frame), Some(channel)) if !self.disposed => {
      let renderer = frame.renderer()
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
  guard (self.frame, self.image, self.host_bridge)
    is (Some(frame_state), Some(image_state), Some(host_bridge)) &&
    !self.disposed else {
    return @render.RenderFrameResult::new()
  }
  let renderer = frame_state.renderer()
  if frame_state.pending() {
    let prior_completions = drain_embedded_renderer_events(renderer, image_state)
    let prior_presented = frame_state.accept_present_completions(prior_completions)
    if prior_presented {
      let state = self.driver.event_result()
      if !state.needs_redraw && !state.redraw_requested {
        return @render.RenderFrameResult::new(presented=true)
      }
    }
    return @render.RenderFrameResult::new(
      presented=prior_presented,
      queued=frame_state.pending(),
    )
  }
  self.driver.begin_redraw()
  let draw_frame = self.driver.draw_frame()
  guard frame_state.prepare_submission(draw_frame) is Some(submission) else {
    self.driver.finish_redraw()
    return @render.RenderFrameResult::new(queued=true)
  }
  ignore(host_bridge.sync_platform_views(draw_frame.platform_views))
  let result = renderer.render_frame(submission)
  let completions = drain_embedded_renderer_events(renderer, image_state)
  ignore(frame_state.finish_submission(result, completions))
  self.driver.finish_redraw()
  let scheduled_count = image_state.take_scheduled_count()
  if scheduled_count > 0 {
    self.transport.request_frame()
    ignore(
      host_bridge.push_diagnostic(
        "moui-window service async-image phase=loading scheduled=\{scheduled_count} present=\{renderer.present_count()}",
      ),
    )
  }
  ignore(host_bridge.sync(self.runtime))
  ignore(host_bridge.flush_updates_to_shell(self.transport))
  ignore(self.transport.finish_frame())
  result
}

///|
fn drain_embedded_renderer_events(
  renderer : @render.RendererSession,
  image_tasks : @window_image.WindowImageTasks,
) -> Array[@render.RenderPresentCompletion] {
  let completions : Array[@render.RenderPresentCompletion] = []
  for event in renderer.drain_events() {
    match event {
      @render.RendererEvent::PresentCompleted(completion) =>
        completions.push(completion)
      @render.RendererEvent::ImageLoadRequested(request) =>
        ignore(image_tasks.schedule(renderer, request))
    }
  }
  completions
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
  match self.frame {
    Some(frame) if !self.disposed => frame.renderer().present_count()
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
