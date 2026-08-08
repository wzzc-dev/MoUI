///|
pub struct WindowImageTaskStarter {
  priv start_fn : (
    @render.RendererImageLoadRequest,
    (@render.RendererImageLoadCompletion) -> Unit,
  ) -> (() -> Unit)?
}

///|
pub fn WindowImageTaskStarter::new(
  start~ : (
    @render.RendererImageLoadRequest,
    (@render.RendererImageLoadCompletion) -> Unit,
  ) -> (() -> Unit)?,
) -> WindowImageTaskStarter {
  { start_fn: start }
}

///|
pub fn WindowImageTaskStarter::immediate() -> WindowImageTaskStarter {
  WindowImageTaskStarter::new(start=(request, complete) => {
    complete(request.load())
    None
  })
}

///|
priv struct WindowImageTask {
  token : @render.RendererImageLoadToken
  cancel : (() -> Unit)?
}

///|
/// Per-window owner for cancellable image I/O only. Resource state, cache
/// residency, staleness, and repaint decisions remain in RendererSession.
pub struct WindowImageTasks {
  priv starter : WindowImageTaskStarter
  priv request_redraw : () -> Unit
  priv mut tasks : Array[WindowImageTask]
  priv mut scheduled_since_observation : Int
  priv mut disposed : Bool
}

///|
pub fn WindowImageTasks::new(
  starter? : WindowImageTaskStarter = WindowImageTaskStarter::immediate(),
  request_redraw~ : () -> Unit,
) -> WindowImageTasks {
  {
    starter,
    request_redraw,
    tasks: [],
    scheduled_since_observation: 0,
    disposed: false,
  }
}

///|
pub fn WindowImageTasks::schedule(
  self : WindowImageTasks,
  renderer : @render.RendererSession,
  request : @render.RendererImageLoadRequest,
) -> Bool {
  if self.disposed || self.contains(request.token()) {
    return false
  }
  self.tasks.push({ token: request.token(), cancel: None })
  self.scheduled_since_observation = self.scheduled_since_observation + 1
  let cancel = (self.starter.start_fn)(request, completion => {
    if self.remove(completion.token()) {
      match renderer.apply_image_load_completion(completion) {
        @render.RendererImageCompletionResult::Applied(true) =>
          (self.request_redraw)()
        @render.RendererImageCompletionResult::Applied(false)
        | @render.RendererImageCompletionResult::Stale
        | @render.RendererImageCompletionResult::Disposed => ()
      }
    }
  })
  self.set_cancel(request.token(), cancel)
  true
}

///|
pub fn WindowImageTasks::take_scheduled_count(self : WindowImageTasks) -> Int {
  let count = self.scheduled_since_observation
  self.scheduled_since_observation = 0
  count
}

///|
pub fn WindowImageTasks::pending_count(self : WindowImageTasks) -> Int {
  if self.disposed {
    0
  } else {
    self.tasks.length()
  }
}

///|
pub fn WindowImageTasks::cancel(self : WindowImageTasks) -> Int {
  if self.disposed {
    return 0
  }
  let tasks = self.tasks
  self.tasks = []
  for task in tasks {
    match task.cancel {
      Some(cancel) => cancel()
      None => ()
    }
  }
  tasks.length()
}

///|
pub fn WindowImageTasks::dispose(self : WindowImageTasks) -> Unit {
  if !self.disposed {
    ignore(self.cancel())
    self.disposed = true
  }
}

///|
fn WindowImageTasks::contains(
  self : WindowImageTasks,
  token : @render.RendererImageLoadToken,
) -> Bool {
  self.tasks.any(task => task.token == token)
}

///|
fn WindowImageTasks::remove(
  self : WindowImageTasks,
  token : @render.RendererImageLoadToken,
) -> Bool {
  let mut removed = false
  let kept : Array[WindowImageTask] = []
  for task in self.tasks {
    if !removed && task.token == token {
      removed = true
    } else {
      kept.push(task)
    }
  }
  self.tasks = kept
  removed
}

///|
fn WindowImageTasks::set_cancel(
  self : WindowImageTasks,
  token : @render.RendererImageLoadToken,
  cancel : (() -> Unit)?,
) -> Unit {
  for index, task in self.tasks {
    if task.token == token {
      self.tasks[index] = { token, cancel }
      return
    }
  }
}
