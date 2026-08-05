///|
/// Stateless request port shared by runtime composition and backend/common.
/// Queue storage and completion fanout live in `backend/common`.
pub struct WindowRequests {
  push_fn : (WindowRequest) -> Unit
  pending_count_fn : () -> Int
  completed_count_fn : () -> Int
  drain_fn : () -> Array[WindowRequest]
  record_result_fn : (WindowRequest, WindowRequestResult) -> Unit
  subscribe_completed_fn : ((WindowRequestCompletion) -> Unit) -> () -> Unit
}

///|
pub fn WindowRequests::new(
  push? : (WindowRequest) -> Unit = _request => (),
  pending_count? : () -> Int = () => 0,
  completed_count? : () -> Int = () => 0,
  drain? : () -> Array[WindowRequest] = () => [],
  record_result? : (WindowRequest, WindowRequestResult) -> Unit = fn(
    _request,
    _result,
  ) {

  },
  subscribe_completed? : ((WindowRequestCompletion) -> Unit) -> () -> Unit = _handle => {
    () => ()
  },
) -> WindowRequests {
  {
    push_fn: push,
    pending_count_fn: pending_count,
    completed_count_fn: completed_count,
    drain_fn: drain,
    record_result_fn: record_result,
    subscribe_completed_fn: subscribe_completed,
  }
}

///|
pub fn WindowRequests::unavailable() -> WindowRequests {
  WindowRequests::new()
}

///|
pub fn WindowRequests::pending_count(self : WindowRequests) -> Int {
  (self.pending_count_fn)()
}

///|
pub fn WindowRequests::completed_count(self : WindowRequests) -> Int {
  (self.completed_count_fn)()
}

///|
pub fn WindowRequests::push(
  self : WindowRequests,
  request : WindowRequest,
) -> Unit {
  (self.push_fn)(request)
}

///|
pub fn WindowRequests::drain(self : WindowRequests) -> Array[WindowRequest] {
  (self.drain_fn)()
}

///|
pub fn WindowRequests::record_result(
  self : WindowRequests,
  request : WindowRequest,
  result : WindowRequestResult,
) -> Unit {
  (self.record_result_fn)(request, result)
}

///|
pub fn WindowRequests::subscribe_completed(
  self : WindowRequests,
  handle : (WindowRequestCompletion) -> Unit,
) -> () -> Unit {
  (self.subscribe_completed_fn)(handle)
}

///|
pub fn WindowRequests::drain_with_handler(
  self : WindowRequests,
  handle : (WindowRequest) -> WindowRequestResult,
) -> Array[WindowRequestCompletion] {
  let completions = []
  for request in self.drain() {
    let result = handle(request)
    let completion : WindowRequestCompletion = { request, result }
    self.record_result(request, result)
    completions.push(completion)
  }
  completions
}
