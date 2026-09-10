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
/// A starter that resolves remote sources on a worker and everything else
/// synchronously.
///
/// The completion callback must never run on a worker thread: it mutates
/// `WindowImageTasks` bookkeeping and the renderer's image lifecycle, both of
/// which belong to the UI thread. `deferred` therefore takes two host hooks
/// and keeps the ordering explicit:
///
/// * `spawn` runs a closure off the caller's thread and returns an optional
///   cancel handle — an OS thread, a thread pool, a GCD queue.
/// * `post` marshals a closure back onto the UI thread — a main-queue
///   dispatch. The worker only ever touches `post`.
///
/// Non-remote sources complete inline, so a local file never leaves the UI
/// thread. Without host hooks a platform can keep using `immediate`, which
/// makes this a purely additive seam.
pub fn WindowImageTaskStarter::deferred(
  fetch~ : (String) -> Bytes?,
  spawn~ : ((() -> Unit)) -> (() -> Unit)?,
  post~ : ((() -> Unit)) -> Unit,
) -> WindowImageTaskStarter {
  WindowImageTaskStarter::new(start=(request, complete) => {
    let source = request.source()
    if !window_image_source_is_remote(source) {
      complete(request.load())
      return None
    }
    spawn(() => {
      match fetch(source) {
        Some(bytes) =>
          post(() => {
            complete(request.load_bytes(bytes))
          })
        // A failed fetch falls back to the default path, which surfaces the
        // failure through the renderer's image lifecycle rather than stalling
        // the request in the loading state.
        None =>
          post(() => {
            complete(request.load())
          })
      }
    })
  })
}

///|
/// True for sources a platform must reach over the network rather than through
/// the filesystem.
pub fn window_image_source_is_remote(source : String) -> Bool {
  source.has_prefix("http://") || source.has_prefix("https://")
}

///|
/// App-installed starter that replaces the backends' built-in default.
///
/// Platform backends create one image task workspace per window and otherwise
/// hardcode `immediate()`. An application that can resolve sources the backend
/// cannot — remote `https:` assets fetched through an async runtime, say —
/// installs its starter here before launching, and every backend picks it up
/// without each app needing a bespoke host option. An explicitly passed
/// `image_task_starter` still wins, which keeps tests and multi-starter hosts
/// unaffected.
let window_image_task_starter_override : Ref[WindowImageTaskStarter?] = Ref(
  None,
)

///|
/// Install the starter used by backends that were not given one explicitly.
pub fn window_image_task_starter_install(
  starter : WindowImageTaskStarter,
) -> Unit {
  window_image_task_starter_override.val = Some(starter)
}

///|
/// Drop the installed starter, restoring the synchronous default.
pub fn window_image_task_starter_reset() -> Unit {
  window_image_task_starter_override.val = None
}

///|
/// The starter a backend should use when it has none of its own: the installed
/// starter when present, otherwise the synchronous `immediate` starter.
pub fn window_image_task_starter_default() -> WindowImageTaskStarter {
  match window_image_task_starter_override.val {
    Some(starter) => starter
    None => WindowImageTaskStarter::immediate()
  }
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
