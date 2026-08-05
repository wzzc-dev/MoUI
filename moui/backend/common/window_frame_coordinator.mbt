///|
/// Hooks supplied by a host adapter for the shared frame state machine.
///
/// The hooks are deliberately capability-shaped: platform code can request a
/// native redraw or synchronize IME/platform services without owning any
/// lifecycle or completion state.
pub struct WindowFrameHooks {
  prepare_frame : () -> Unit
  finish_presented : (Bool) -> Unit
  request_redraw : () -> Unit
  sync_ime : () -> Unit
}

///|
pub fn WindowFrameHooks::new(
  prepare_frame? : () -> Unit = () => (),
  finish_presented? : (Bool) -> Unit = _presented => (),
  request_redraw? : () -> Unit = () => (),
  sync_ime? : () -> Unit = () => (),
) -> WindowFrameHooks {
  { prepare_frame, finish_presented, request_redraw, sync_ime }
}

///|
/// Shared begin/draw/present coordination state used by native/Web and
/// embedded hosts. A queued frame remains pending until a terminal renderer
/// completion is observed; a non-presented terminal completion requests a
/// follow-up redraw.
pub struct FrameCoordinator {
  hooks : WindowFrameHooks
  mut pending : Bool
  mut presented_frames : Int
  priv mut image_state : WindowFrameImageState?
}

///|
/// Image repaint bookkeeping is part of the shared frame owner as well. The
/// embedder only supplies a redraw hook; it does not own a second image loop.
priv struct WindowFrameImageState {
  window_id : @render.RenderWindowId
  renderer : @render.WindowRenderer
  tracker : @render_common.ImageResourceRepaintTracker
  completion_source : @render_common.ImageResourceCompletionSource
  loader : @render.ImageLoader?
  window_open : Ref[Bool]
}

///|
pub struct WindowFrameImageObservation {
  present_count : Int
  loading_count : Int
  ready_count : Int
  failed_count : Int
  scheduled_count : Int
}

///|
pub fn FrameCoordinator::new(
  hooks? : WindowFrameHooks = WindowFrameHooks::new(),
) -> FrameCoordinator {
  { hooks, pending: false, presented_frames: 0, image_state: None }
}

///|
pub fn FrameCoordinator::attach_image_resources(
  self : FrameCoordinator,
  window_id : @render.RenderWindowId,
  renderer : @render.WindowRenderer,
  loader : @render.ImageLoader?,
) -> Unit {
  self.dispose_image_resources()
  let tracker = @render_common.ImageResourceRepaintTracker::new()
  let window_open = Ref(true)
  let completion_source = @render_common.ImageResourceCompletionSource::new(
    tracker~,
    window_open=id => window_open.val && id == window_id,
    request_redraw=_id => (self.hooks.request_redraw)(),
  )
  self.image_state = Some({
    window_id,
    renderer,
    tracker,
    completion_source,
    loader,
    window_open,
  })
}

///|
pub fn FrameCoordinator::dispose_image_resources(
  self : FrameCoordinator,
) -> Unit {
  self.pending = false
  match self.image_state {
    Some(state) => {
      if state.window_open.val {
        state.window_open.val = false
        match state.loader {
          Some(loader) => ignore(loader.cancel_window(state.window_id))
          None => ()
        }
        ignore(state.tracker.remove_window(state.window_id))
      }
      self.image_state = None
    }
    None => ()
  }
}

///|
pub fn FrameCoordinator::finish_image_frame(
  self : FrameCoordinator,
  present_count : Int,
  presented? : Bool = true,
) -> WindowFrameImageObservation {
  match self.image_state {
    Some(state) => {
      let baseline = if presented {
        state.tracker.record_presented(state.window_id, state.renderer)
      } else {
        state.tracker.request_redraw_if_changed(
          state.window_id,
          state.renderer,
          window_open=state.window_open.val,
          request_redraw=_id => (self.hooks.request_redraw)(),
        )
      }
      let counts = baseline.current_status_counts()
      let scheduled_count = match state.loader {
        Some(loader) =>
          loader
          .schedule_loading_resources(state.window_id, state.renderer, complete=(
            id,
            renderer,
            completion,
          ) => {
            ignore(state.completion_source.complete(id, renderer, completion))
          })
          .scheduled_count()
        None => 0
      }
      {
        present_count,
        loading_count: counts.loading_count(),
        ready_count: counts.ready_count(),
        failed_count: counts.failed_count(),
        scheduled_count,
      }
    }
    None =>
      {
        present_count,
        loading_count: 0,
        ready_count: 0,
        failed_count: 0,
        scheduled_count: 0,
      }
  }
}

///|
/// Request a repaint when the renderer's image snapshot advanced since the
/// last frame observed by this coordinator.
pub fn FrameCoordinator::request_image_redraw_if_changed(
  self : FrameCoordinator,
) -> Bool {
  match self.image_state {
    Some(state) => {
      let result = state.tracker.request_redraw_if_changed(
        state.window_id,
        state.renderer,
        window_open=state.window_open.val,
        request_redraw=_id => (self.hooks.request_redraw)(),
      )
      result.status() ==
      @render_common.ImageResourceRepaintStatus::ImageRepaintRequested
    }
    None => false
  }
}

///|
/// Route renderer image notifications back through this frame owner.
pub fn FrameCoordinator::bind_image_resource_changes(
  self : FrameCoordinator,
) -> Unit {
  match self.image_state {
    Some(state) =>
      state.renderer.set_image_resource_change_callback(
        Some(snapshot => {
          match self.image_state {
            Some(current) if current.window_open.val =>
              ignore(
                current.tracker.request_redraw_for_snapshot_if_changed(
                  current.window_id,
                  snapshot,
                  window_open=true,
                  request_redraw=_id => (self.hooks.request_redraw)(),
                ),
              )
            _ => ()
          }
        }),
      )
    None => ()
  }
}

///|
pub fn FrameCoordinator::cancel_image_resources(self : FrameCoordinator) -> Int {
  match self.image_state {
    Some(state) =>
      match state.loader {
        Some(loader) => loader.cancel_window(state.window_id)
        None => 0
      }
    None => 0
  }
}

///|
/// Begin a frame. Returns false while an earlier asynchronous frame is still
/// pending, allowing the adapter to avoid submitting duplicate work.
pub fn FrameCoordinator::prepare_frame(self : FrameCoordinator) -> Bool {
  if self.pending {
    (self.hooks.request_redraw)()
    false
  } else {
    (self.hooks.prepare_frame)()
    true
  }
}

///|
/// Record renderer completion and schedule the next frame when required.
pub fn FrameCoordinator::finish_presented(
  self : FrameCoordinator,
  queued : Bool,
  terminal : Bool,
  presented : Bool,
) -> Bool {
  self.pending = queued && !terminal
  if presented {
    self.presented_frames = self.presented_frames + 1
  }
  (self.hooks.finish_presented)(presented)
  if self.pending || (queued && terminal && !presented) {
    (self.hooks.request_redraw)()
  }
  (self.hooks.sync_ime)()
  presented
}

///|
pub fn FrameCoordinator::request_redraw(self : FrameCoordinator) -> Unit {
  (self.hooks.request_redraw)()
}

///|
pub fn FrameCoordinator::sync_ime(self : FrameCoordinator) -> Unit {
  (self.hooks.sync_ime)()
}

///|
pub fn FrameCoordinator::pending(self : FrameCoordinator) -> Bool {
  self.pending
}

///|
pub fn FrameCoordinator::presented_count(self : FrameCoordinator) -> Int {
  self.presented_frames
}
