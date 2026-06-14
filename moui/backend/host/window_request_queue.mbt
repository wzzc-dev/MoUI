///|
pub struct HostWindowRequestQueue {
  mut requests : Array[HostWindowRequest]
  mut completed : Array[HostWindowRequestCompletion]
}

///|
pub fn HostWindowRequestQueue::new() -> HostWindowRequestQueue {
  { requests: [], completed: [] }
}

///|
pub fn HostWindowRequestQueue::pending_count(
  self : HostWindowRequestQueue,
) -> Int {
  self.requests.length()
}

///|
pub fn HostWindowRequestQueue::completed_count(
  self : HostWindowRequestQueue,
) -> Int {
  self.completed.length()
}

///|
pub fn HostWindowRequestQueue::is_empty(self : HostWindowRequestQueue) -> Bool {
  self.requests.is_empty()
}

///|
pub fn HostWindowRequestQueue::push(
  self : HostWindowRequestQueue,
  request : HostWindowRequest,
) -> Unit {
  self.requests.push(request)
}

///|
pub fn HostWindowRequestQueue::open_window(
  self : HostWindowRequestQueue,
  title~ : String,
  scene? : HostWindowScene = HostWindowScene::main(),
  metrics~ : HostSurfaceMetrics,
  primary? : Bool = false,
) -> Unit {
  self.push(
    HostWindowRequest::OpenWindow(
      HostWindowOpenRequest::new(title~, scene~, metrics~, primary~),
    ),
  )
}

///|
pub fn HostWindowRequestQueue::focus_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::FocusWindow(id))
}

///|
pub fn HostWindowRequestQueue::close_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::CloseWindow(id))
}

///|
pub fn HostWindowRequestQueue::resize_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
  metrics : HostSurfaceMetrics,
) -> Unit {
  self.push(HostWindowRequest::ResizeWindow(id, metrics))
}

///|
pub fn HostWindowRequestQueue::minimize_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::MinimizeWindow(id))
}

///|
pub fn HostWindowRequestQueue::show_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::ShowWindow(id))
}

///|
pub fn HostWindowRequestQueue::set_primary_window(
  self : HostWindowRequestQueue,
  id : HostWindowId,
) -> Unit {
  self.push(HostWindowRequest::SetPrimaryWindow(id))
}

///|
pub fn HostWindowRequestQueue::drain(
  self : HostWindowRequestQueue,
) -> Array[HostWindowRequest] {
  let requests = self.requests
  self.requests = []
  requests
}

///|
pub fn HostWindowRequestQueue::record_result(
  self : HostWindowRequestQueue,
  request : HostWindowRequest,
  result : HostWindowRequestResult,
) -> Unit {
  self.completed.push({ request, result })
}

///|
pub fn HostWindowRequestQueue::drain_with_handler(
  self : HostWindowRequestQueue,
  handle : (HostWindowRequest) -> HostWindowRequestResult,
) -> Array[HostWindowRequestCompletion] {
  let completions = []
  for request in self.drain() {
    let result = handle(request)
    let completion = HostWindowRequestCompletion::{ request, result }
    self.completed.push(completion)
    completions.push(completion)
  }
  completions
}

///|
pub fn HostWindowRequestQueue::drain_completed(
  self : HostWindowRequestQueue,
) -> Array[HostWindowRequestCompletion] {
  let completed = self.completed
  self.completed = []
  completed
}
