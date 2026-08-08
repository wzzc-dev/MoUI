///|
/// Attach the lifecycle, frame, and image owners atomically. A rejected attach
/// disposes the unclaimed renderer session.
pub fn attach_window_surface(
  lifecycle : @window_lifecycle.WindowLifecycle,
  frames : @window_frame.WindowFrameStates,
  images : @window_image.WindowImageTaskStates,
  id : @backend_host.WindowId,
  renderer : @render.RendererSession,
  actions : @window_lifecycle.WindowSurfaceActions,
  image_task_starter? : @window_image.WindowImageTaskStarter = @window_image.WindowImageTaskStarter::immediate(),
) -> Bool {
  if lifecycle.surface_actions(id) is Some(_) ||
    frames.lookup(id) is Some(_) ||
    images.lookup(id) is Some(_) {
    renderer.dispose()
    return false
  }
  if !lifecycle.attach_surface(id, actions) {
    renderer.dispose()
    return false
  }
  if !frames.attach(
      id,
      renderer,
      hooks=@window_frame.WindowFrameHooks::new(
        request_redraw=actions.request_redraw,
      ),
    ) {
    ignore(lifecycle.detach_surface(id))
    renderer.dispose()
    return false
  }
  if !images.attach(
      id,
      starter=image_task_starter,
      request_redraw=actions.request_redraw,
    ) {
    ignore(lifecycle.detach_surface(id))
    ignore(frames.dispose_window(id))
    return false
  }
  true
}

///|
pub fn dispatch_host_event(
  lifecycle : @window_lifecycle.WindowLifecycle,
  input : @window_input.WindowInputState,
  services : @window_services.WindowServiceState,
  id : @backend_host.WindowId,
  event : @backend_host.Event,
  adjust~ : (@backend_host.Event) -> @backend_host.Event?,
) -> Unit {
  match adjust(event) {
    Some(adjusted) => {
      ignore(lifecycle.apply_host_event(id, adjusted))
      match lifecycle.runtime_slot_lookup(id) {
        Some(slot) =>
          match adjusted {
            @backend_host.Event::Keyboard(key) =>
              ignore(
                slot.driver.dispatch_keyboard_with_services(
                  key,
                  services.bridge(),
                ),
              )
            _ => ignore(slot.driver.dispatch(adjusted))
          }
        None => ()
      }
      ignore(input.publish(id, adjusted))
      sync_text_input_session(lifecycle, input)
    }
    None => ()
  }
}

///|
pub fn sync_text_input_session(
  lifecycle : @window_lifecycle.WindowLifecycle,
  input : @window_input.WindowInputState,
) -> Unit {
  match lifecycle.active_runtime_slot() {
    Some(slot) =>
      match lifecycle.surface_actions(slot.id) {
        Some(actions) =>
          match input.sync(slot.driver.focused_text_input()) {
            @window_input.TextInputSessionAction::NoImeChange => ()
            action => (actions.request_ime_update)(action)
          }
        None => ()
      }
    None => ()
  }
}

///|
pub fn apply_window_request(
  lifecycle : @window_lifecycle.WindowLifecycle,
  input : @window_input.WindowInputState,
  services : @window_services.WindowServiceState,
  request : @backend_host.WindowRequest,
  open_window~ : (@backend_host.WindowOpenRequest) -> @backend_host.WindowRequestResult,
  dispose_window? : (@backend_host.WindowId) -> Unit = _ => (),
  exit~ : () -> Unit,
) -> @backend_host.WindowRequestResult {
  match request {
    @backend_host.WindowRequest::OpenWindow(open_request) =>
      open_window(open_request)
    @backend_host.WindowRequest::FocusWindow(id) =>
      apply_platform_window_request(lifecycle, id, request, actions => {
        (actions.focus)()
      })
    @backend_host.WindowRequest::CloseWindow(id) =>
      apply_platform_window_request(lifecycle, id, request, _ => {
        dispose_window(id)
        if lifecycle.runtime_slots_empty() {
          exit()
        }
      })
    @backend_host.WindowRequest::ResizeWindow(id, metrics) =>
      apply_platform_window_request(lifecycle, id, request, actions => {
        let applied = (actions.request_resize)(metrics)
        dispatch_host_event(
          lifecycle,
          input,
          services,
          id,
          @backend_host.Event::Resized(applied),
          adjust=event => Some(event),
        )
        (actions.request_redraw)()
      })
    @backend_host.WindowRequest::MinimizeWindow(id) =>
      apply_platform_window_request(lifecycle, id, request, actions => {
        (actions.set_minimized)(true)
      })
    @backend_host.WindowRequest::ShowWindow(id) =>
      apply_platform_window_request(lifecycle, id, request, actions => {
        (actions.set_minimized)(false)
        (actions.set_visible)(true)
      })
    @backend_host.WindowRequest::SetPrimaryWindow(id) =>
      apply_platform_window_request(lifecycle, id, request, _ => ())
  }
}

///|
pub fn apply_platform_window_request(
  lifecycle : @window_lifecycle.WindowLifecycle,
  id : @backend_host.WindowId,
  request : @backend_host.WindowRequest,
  apply : (@window_lifecycle.WindowSurfaceActions) -> Unit,
) -> @backend_host.WindowRequestResult {
  match lifecycle.surface_actions(id) {
    Some(actions) => {
      let result = lifecycle.apply_request_state(request)
      match result {
        @backend_host.WindowRequestResult::WindowRejected(_) => ()
        _ => apply(actions)
      }
      result
    }
    None =>
      @backend_host.WindowRequestResult::WindowRejected(
        "window request has no active platform window",
      )
  }
}

///|
pub fn sync_observed_resize(
  lifecycle : @window_lifecycle.WindowLifecycle,
  input : @window_input.WindowInputState,
  services : @window_services.WindowServiceState,
  id : @backend_host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> @core.SurfaceMetrics? {
  match lifecycle.surface_actions(id) {
    Some(actions) => {
      let applied = (actions.sync_observed_resize)(metrics)
      dispatch_host_event(
        lifecycle,
        input,
        services,
        id,
        @backend_host.Event::Resized(applied),
        adjust=event => Some(event),
      )
      (actions.request_redraw)()
      Some(applied)
    }
    None => None
  }
}

///|
pub fn run_window_redraw(
  lifecycle : @window_lifecycle.WindowLifecycle,
  frames : @window_frame.WindowFrameStates,
  images : @window_image.WindowImageTaskStates,
  input : @window_input.WindowInputState,
  id : @backend_host.WindowId,
  render~ : (
    @render.RendererSession,
    @window_lifecycle.WindowRuntimeSlot,
    @render.RenderFrameSubmission,
  ) -> @render.RenderFrameResult,
  finish_presented? : (@window_lifecycle.WindowRuntimeSlot) -> Bool = _ => false,
) -> Bool {
  match (lifecycle.runtime_slot_lookup(id), frames.lookup(id)) {
    (Some(slot), Some(frame_state)) => {
      let renderer = frame_state.renderer()
      if frame_state.pending() {
        let prior = drain_renderer_events(renderer, images.lookup(id))
        let prior_presented = frame_state.accept_present_completions(prior)
        if prior_presented {
          sync_text_input_session(lifecycle, input)
          if finish_presented(slot) {
            return true
          }
        }
        return prior_presented
      }
      slot.driver.begin_redraw()
      let draw_frame = slot.driver.draw_frame()
      guard frame_state.prepare_submission(draw_frame) is Some(submission) else {
        slot.driver.finish_redraw()
        return false
      }
      let result = render(renderer, slot, submission)
      let completions = drain_renderer_events(renderer, images.lookup(id))
      slot.driver.finish_redraw()
      let presented = frame_state.finish_submission(result, completions)
      sync_text_input_session(lifecycle, input)
      presented && finish_presented(slot)
    }
    _ => false
  }
}

///|
fn drain_renderer_events(
  renderer : @render.RendererSession,
  image_tasks : @window_image.WindowImageTasks?,
) -> Array[@render.RenderPresentCompletion] {
  let completions : Array[@render.RenderPresentCompletion] = []
  for event in renderer.drain_events() {
    match event {
      @render.RendererEvent::PresentCompleted(completion) =>
        completions.push(completion)
      @render.RendererEvent::ImageLoadRequested(request) =>
        match image_tasks {
          Some(tasks) => ignore(tasks.schedule(renderer, request))
          None => ()
        }
    }
  }
  completions
}

///|
pub fn request_redraw_window_if_needed(
  lifecycle : @window_lifecycle.WindowLifecycle,
  _images : @window_image.WindowImageTaskStates,
  id : @backend_host.WindowId,
) -> Unit {
  match lifecycle.runtime_slot_lookup(id) {
    Some(slot) => {
      if runtime_slot_needs_redraw(slot) {
        request_platform_redraw(lifecycle, id)
      }
    }
    None => ()
  }
}

///|
pub fn request_redraw(
  lifecycle : @window_lifecycle.WindowLifecycle,
  images : @window_image.WindowImageTaskStates,
) -> Unit {
  match lifecycle.active_runtime_slot() {
    Some(slot) => request_redraw_window_if_needed(lifecycle, images, slot.id)
    None => ()
  }
}

///|
pub fn request_platform_redraw(
  lifecycle : @window_lifecycle.WindowLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  match lifecycle.surface_actions(id) {
    Some(actions) => (actions.request_redraw)()
    None => ()
  }
}

///|
pub fn dispose_window(
  lifecycle : @window_lifecycle.WindowLifecycle,
  frames : @window_frame.WindowFrameStates,
  images : @window_image.WindowImageTaskStates,
  services : @window_services.WindowServiceState,
  id : @backend_host.WindowId,
) -> Unit {
  guard lifecycle.begin_close(id) else { return }
  let actions = lifecycle.surface_actions(id)
  let closes_host = lifecycle.runtime_slots().count() == 1
  // Stop image callbacks and tasks before disposing the renderer session.
  ignore(images.dispose_window(id))
  if closes_host {
    services.dispose()
  }
  ignore(frames.dispose_window(id))
  match actions {
    Some(surface) => {
      (surface.dispose_platform_views)()
      (surface.drop)()
    }
    None => ()
  }
  lifecycle.finish_close(id)
}

///|
pub fn runtime_slot_needs_redraw(
  slot : @window_lifecycle.WindowRuntimeSlot,
) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
pub fn to_host_id(render_id : @render.RenderWindowId) -> @backend_host.WindowId {
  @backend_host.WindowId::new(render_id.value)
}

///|
pub fn to_render_id(id : @backend_host.WindowId) -> @render.RenderWindowId {
  @render.RenderWindowId::new(id.value)
}

///|
pub fn to_render_metrics(
  metrics : @core.SurfaceMetrics,
) -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}
