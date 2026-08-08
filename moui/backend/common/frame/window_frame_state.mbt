///|
pub struct WindowFrameHooks {
  prepare_frame : () -> Unit
  finish_presented : (Bool) -> Unit
  request_redraw : () -> Unit
  sync_ime : () -> Unit
}

///|
pub fn WindowFrameHooks::new(
  prepare_frame? : () -> Unit = () => (),
  finish_presented? : (Bool) -> Unit = _ => (),
  request_redraw? : () -> Unit = () => (),
  sync_ime? : () -> Unit = () => (),
) -> WindowFrameHooks {
  { prepare_frame, finish_presented, request_redraw, sync_ime }
}

///|
/// Per-window frame and renderer-session owner.
pub struct WindowFrameState {
  renderer : @render.RendererSession
  hooks : WindowFrameHooks
  surface_generation : Int
  mut next_sequence : Int
  mut current_token : @render.FrameToken?
  mut presented_frames : Int
  mut disposed : Bool
}

///|
pub fn WindowFrameState::new(
  renderer~ : @render.RendererSession,
  surface_generation? : Int = 1,
  hooks? : WindowFrameHooks = WindowFrameHooks::new(),
) -> WindowFrameState {
  {
    renderer,
    hooks,
    surface_generation: surface_generation.max(1),
    next_sequence: 1,
    current_token: None,
    presented_frames: 0,
    disposed: false,
  }
}

///|
pub fn WindowFrameState::renderer(
  self : WindowFrameState,
) -> @render.RendererSession {
  self.renderer
}

///|
pub fn WindowFrameState::prepare_submission(
  self : WindowFrameState,
  frame : @core.DrawFrame,
) -> @render.RenderFrameSubmission? {
  if self.disposed || self.current_token is Some(_) {
    if !self.disposed {
      (self.hooks.request_redraw)()
    }
    None
  } else {
    (self.hooks.prepare_frame)()
    let token = @render.FrameToken::new(
      surface_generation=self.surface_generation,
      sequence=self.next_sequence,
    )
    self.next_sequence = self.next_sequence + 1
    self.current_token = Some(token)
    Some(@render.RenderFrameSubmission::new(token~, frame~))
  }
}

///|
pub fn WindowFrameState::finish_submission(
  self : WindowFrameState,
  result : @render.RenderFrameResult,
  completions : Array[@render.RenderPresentCompletion],
) -> Bool {
  if self.disposed {
    return false
  }
  guard self.current_token is Some(token) else { return false }
  let accepted = completions.filter(completion => completion.token() == token)
  let terminal = @render.render_present_completions_have_terminal(accepted)
  let presented = @render.render_present_completions_have_presented(accepted) ||
    (accepted.is_empty() && result.presented)
  if !result.queued || terminal {
    self.current_token = None
  }
  if presented {
    self.presented_frames = self.presented_frames + 1
  }
  (self.hooks.finish_presented)(presented)
  if self.pending() || (result.queued && terminal && !presented) {
    (self.hooks.request_redraw)()
  }
  (self.hooks.sync_ime)()
  presented
}

///|
/// Accept asynchronous completions only for the currently pending submission.
/// Stale generations, out-of-order sequences, and duplicate completions have
/// no effect on frame state.
pub fn WindowFrameState::accept_present_completions(
  self : WindowFrameState,
  completions : Array[@render.RenderPresentCompletion],
) -> Bool {
  if self.disposed {
    return false
  }
  guard self.current_token is Some(token) else { return false }
  let accepted = completions.filter(completion => completion.token() == token)
  let terminal = @render.render_present_completions_have_terminal(accepted)
  let presented = @render.render_present_completions_have_presented(accepted)
  if terminal {
    self.current_token = None
    if presented {
      self.presented_frames = self.presented_frames + 1
    }
    (self.hooks.finish_presented)(presented)
  }
  if self.pending() {
    (self.hooks.request_redraw)()
  } else if terminal && !presented {
    (self.hooks.request_redraw)()
  }
  (self.hooks.sync_ime)()
  presented
}

///|
pub fn WindowFrameState::request_redraw(self : WindowFrameState) -> Unit {
  if !self.disposed {
    (self.hooks.request_redraw)()
  }
}

///|
pub fn WindowFrameState::sync_ime(self : WindowFrameState) -> Unit {
  if !self.disposed {
    (self.hooks.sync_ime)()
  }
}

///|
pub fn WindowFrameState::pending(self : WindowFrameState) -> Bool {
  !self.disposed && self.current_token is Some(_)
}

///|
pub fn WindowFrameState::surface_generation(self : WindowFrameState) -> Int {
  self.surface_generation
}

///|
pub fn WindowFrameState::presented_count(self : WindowFrameState) -> Int {
  self.presented_frames
}

///|
pub fn WindowFrameState::dispose(self : WindowFrameState) -> Unit {
  if !self.disposed {
    self.disposed = true
    self.current_token = None
    self.renderer.dispose()
  }
}
