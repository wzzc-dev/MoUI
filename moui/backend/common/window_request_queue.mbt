///|
priv struct HostWindowCompletionHandler {
  token : Int
  handle : (@backend_host.WindowRequestCompletion) -> Unit
}

///|
pub struct WindowRequestQueue {
  mut requests : Array[@backend_host.WindowRequest]
  mut completed : Array[@backend_host.WindowRequestCompletion]
  priv mut next_completion_handler : Int
  priv mut completion_handlers : Array[HostWindowCompletionHandler]
}

///|
pub fn WindowRequestQueue::new() -> WindowRequestQueue {
  {
    requests: [],
    completed: [],
    next_completion_handler: 1,
    completion_handlers: [],
  }
}

///|
/// Erase queue storage behind the root backend request protocol.
pub fn WindowRequestQueue::requests(
  self : WindowRequestQueue,
) -> @backend_host.WindowRequests {
  @backend_host.WindowRequests::new(
    push=request => self.push(request),
    pending_count=() => self.pending_count(),
    completed_count=() => self.completed_count(),
    drain=() => self.drain(),
    record_result=fn(request, result) { self.record_result(request, result) },
    subscribe_completed=handle => self.subscribe_completed(handle),
  )
}

///|
pub fn WindowRequestQueue::pending_count(self : WindowRequestQueue) -> Int {
  self.requests.length()
}

///|
pub fn WindowRequestQueue::completed_count(self : WindowRequestQueue) -> Int {
  self.completed.length()
}

///|
pub fn WindowRequestQueue::is_empty(self : WindowRequestQueue) -> Bool {
  self.requests.is_empty()
}

///|
pub fn WindowRequestQueue::push(
  self : WindowRequestQueue,
  request : @backend_host.WindowRequest,
) -> Unit {
  self.requests.push(request)
}

///|
pub fn WindowRequestQueue::open_window(
  self : WindowRequestQueue,
  title~ : String,
  scene? : @backend_host.WindowScene = @backend_host.WindowScene::main(),
  metrics~ : @core.SurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.push(
    @backend_host.WindowRequest::OpenWindow(
      @backend_host.WindowOpenRequest::new(title~, scene~, metrics~, primary~),
    ),
  )
}

///|
pub fn WindowRequestQueue::focus_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
) -> Unit {
  self.push(@backend_host.WindowRequest::FocusWindow(id))
}

///|
pub fn WindowRequestQueue::close_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
) -> Unit {
  self.push(@backend_host.WindowRequest::CloseWindow(id))
}

///|
pub fn WindowRequestQueue::resize_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.push(@backend_host.WindowRequest::ResizeWindow(id, metrics))
}

///|
pub fn WindowRequestQueue::minimize_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
) -> Unit {
  self.push(@backend_host.WindowRequest::MinimizeWindow(id))
}

///|
pub fn WindowRequestQueue::show_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
) -> Unit {
  self.push(@backend_host.WindowRequest::ShowWindow(id))
}

///|
pub fn WindowRequestQueue::set_primary_window(
  self : WindowRequestQueue,
  id : @backend_host.WindowId,
) -> Unit {
  self.push(@backend_host.WindowRequest::SetPrimaryWindow(id))
}

///|
pub fn WindowRequestQueue::drain(
  self : WindowRequestQueue,
) -> Array[@backend_host.WindowRequest] {
  let requests = self.requests
  self.requests = []
  requests
}

///|
pub fn WindowRequestQueue::record_result(
  self : WindowRequestQueue,
  request : @backend_host.WindowRequest,
  result : @backend_host.WindowRequestResult,
) -> Unit {
  self.record_completion({ request, result })
}

///|
/// Observe request completions without consuming the diagnostic completion
/// queue. The returned callback removes the observer.
pub fn WindowRequestQueue::subscribe_completed(
  self : WindowRequestQueue,
  handle : (@backend_host.WindowRequestCompletion) -> Unit,
) -> () -> Unit {
  let token = self.next_completion_handler
  self.next_completion_handler = token + 1
  self.completion_handlers.push({ token, handle })
  () => ignore(self.remove_completion_handler(token))
}

///|
pub fn WindowRequestQueue::drain_with_handler(
  self : WindowRequestQueue,
  handle : (@backend_host.WindowRequest) -> @backend_host.WindowRequestResult,
) -> Array[@backend_host.WindowRequestCompletion] {
  let completions = []
  for request in self.drain() {
    let result = handle(request)
    let completion = @backend_host.WindowRequestCompletion::{ request, result }
    self.record_completion(completion)
    completions.push(completion)
  }
  completions
}

///|
pub fn WindowRequestQueue::drain_completed(
  self : WindowRequestQueue,
) -> Array[@backend_host.WindowRequestCompletion] {
  let completed = self.completed
  self.completed = []
  completed
}

///|
fn WindowRequestQueue::record_completion(
  self : WindowRequestQueue,
  completion : @backend_host.WindowRequestCompletion,
) -> Unit {
  self.completed.push(completion)
  for handler in self.completion_handlers.copy() {
    (handler.handle)(completion)
  }
}

///|
fn WindowRequestQueue::remove_completion_handler(
  self : WindowRequestQueue,
  token : Int,
) -> Bool {
  let remaining = []
  let mut removed = false
  for handler in self.completion_handlers {
    if handler.token == token {
      removed = true
    } else {
      remaining.push(handler)
    }
  }
  self.completion_handlers = remaining
  removed
}
