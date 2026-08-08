///|
pub struct ServiceAsyncQueue {
  mut next_value : Int
  mut pending : Array[@backend_host.HostPendingServiceRequest]
  mut in_flight : Array[@backend_host.HostPendingServiceRequest]
  mut completed : Array[@backend_host.HostCompletedServiceResponse]
  priv mut next_completion_handler_value : Int
  priv mut completion_handlers : Array[HostServiceCompletionHandler]
}

///|
priv struct HostServiceCompletionHandler {
  token : Int
  id : @backend_host.HostServiceRequestId
  handle : (@backend_host.HostCompletedServiceResponse) -> Unit
}

///|
pub fn ServiceAsyncQueue::new() -> ServiceAsyncQueue {
  {
    next_value: 1,
    pending: [],
    in_flight: [],
    completed: [],
    next_completion_handler_value: 1,
    completion_handlers: [],
  }
}

///|
pub fn ServiceAsyncQueue::pending_count(self : ServiceAsyncQueue) -> Int {
  self.pending.length()
}

///|
pub fn ServiceAsyncQueue::completed_count(self : ServiceAsyncQueue) -> Int {
  self.completed.length()
}

///|
pub fn ServiceAsyncQueue::in_flight_count(self : ServiceAsyncQueue) -> Int {
  self.in_flight.length()
}

///|
pub fn ServiceAsyncQueue::outstanding_count(self : ServiceAsyncQueue) -> Int {
  self.pending.length() + self.in_flight.length()
}

///|
pub fn ServiceAsyncQueue::submit(
  self : ServiceAsyncQueue,
  request : @backend_host.HostServiceRequest,
) -> @backend_host.HostServiceResponse {
  let id = @backend_host.HostServiceRequestId::new(self.next_value)
  self.next_value = self.next_value + 1
  self.pending.push({ id, request })
  @backend_host.HostServiceResponse::Pending(id)
}

///|
pub fn ServiceAsyncQueue::drain_pending(
  self : ServiceAsyncQueue,
) -> Array[@backend_host.HostPendingServiceRequest] {
  let pending = self.pending
  for request in pending {
    self.in_flight.push(request)
  }
  self.pending = []
  pending
}

///|
pub fn ServiceAsyncQueue::drain_completed(
  self : ServiceAsyncQueue,
) -> Array[@backend_host.HostCompletedServiceResponse] {
  let completed = self.completed
  self.completed = []
  completed
}

///|
pub fn ServiceAsyncQueue::complete(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
  response : @backend_host.HostServiceResponse,
) -> Bool {
  let mut matched = false
  let mut request : @backend_host.HostServiceRequest? = None
  let remaining : Array[@backend_host.HostPendingServiceRequest] = []
  for pending in self.pending {
    if !matched && pending.id == id {
      matched = true
      request = Some(pending.request)
    } else {
      remaining.push(pending)
    }
  }
  self.pending = remaining
  if !matched {
    let remaining_in_flight : Array[@backend_host.HostPendingServiceRequest] = []
    for pending in self.in_flight {
      if !matched && pending.id == id {
        matched = true
        request = Some(pending.request)
      } else {
        remaining_in_flight.push(pending)
      }
    }
    self.in_flight = remaining_in_flight
  }
  match request {
    Some(request) => {
      let completion : @backend_host.HostCompletedServiceResponse = {
        id,
        request,
        response,
      }
      if !self.dispatch_completion_handlers(completion) {
        self.completed.push(completion)
      }
      true
    }
    None => false
  }
}

///|
pub fn ServiceAsyncQueue::on_completed(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
  handle : (@backend_host.HostCompletedServiceResponse) -> Unit,
) -> Bool {
  let (registered, _) = self.on_completed_with_cleanup(id, handle)
  registered
}

///|
fn ServiceAsyncQueue::on_completed_with_cleanup(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
  handle : (@backend_host.HostCompletedServiceResponse) -> Unit,
) -> (Bool, (() -> Unit)?) {
  match self.take_completed(id) {
    Some(completion) => {
      handle(completion)
      (true, None)
    }
    None =>
      if self.has_outstanding(id) {
        let token = self.next_completion_handler_value
        self.next_completion_handler_value = self.next_completion_handler_value +
          1
        self.completion_handlers.push({ token, id, handle })
        (true, Some(() => ignore(self.cancel_completion_handler(token))))
      } else {
        (false, None)
      }
  }
}

///|
fn ServiceAsyncQueue::dispatch_completion_handlers(
  self : ServiceAsyncQueue,
  completion : @backend_host.HostCompletedServiceResponse,
) -> Bool {
  let handlers : Array[HostServiceCompletionHandler] = []
  let remaining : Array[HostServiceCompletionHandler] = []
  for handler in self.completion_handlers {
    if handler.id == completion.id {
      handlers.push(handler)
    } else {
      remaining.push(handler)
    }
  }
  self.completion_handlers = remaining
  for handler in handlers {
    (handler.handle)(completion)
  }
  !handlers.is_empty()
}

///|
fn ServiceAsyncQueue::cancel_completion_handler(
  self : ServiceAsyncQueue,
  token : Int,
) -> Bool {
  let mut cancelled = false
  let remaining : Array[HostServiceCompletionHandler] = []
  for handler in self.completion_handlers {
    if !cancelled && handler.token == token {
      cancelled = true
    } else {
      remaining.push(handler)
    }
  }
  self.completion_handlers = remaining
  cancelled
}

///|
fn ServiceAsyncQueue::has_outstanding(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
) -> Bool {
  self.pending.any(request => request.id == id) ||
  self.in_flight.any(request => request.id == id)
}

///|
pub fn ServiceAsyncQueue::reject(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
  reason : String,
) -> Bool {
  self.complete(id, @backend_host.HostServiceResponse::Unavailable(reason))
}

///|
/// Cancel one outstanding request. Completion is still delivered through the
/// normal exactly-once path so app subscriptions observe the cancellation.
pub fn ServiceAsyncQueue::cancel(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
  reason : String,
) -> Bool {
  self.reject(id, reason)
}

///|
/// Drop every outstanding request and completion handler during host teardown.
/// Subsequent completions are rejected because their request ids no longer
/// exist in either pending or in-flight state.
pub fn ServiceAsyncQueue::cancel_all(self : ServiceAsyncQueue) -> Int {
  let count = self.outstanding_count()
  self.pending = []
  self.in_flight = []
  self.completed = []
  self.completion_handlers = []
  count
}

///|
pub fn ServiceAsyncQueue::take_completed(
  self : ServiceAsyncQueue,
  id : @backend_host.HostServiceRequestId,
) -> @backend_host.HostCompletedServiceResponse? {
  let mut found : @backend_host.HostCompletedServiceResponse? = None
  let remaining : Array[@backend_host.HostCompletedServiceResponse] = []
  for completed in self.completed {
    match found {
      None =>
        if completed.id == id {
          found = Some(completed)
        } else {
          remaining.push(completed)
        }
      Some(_) => remaining.push(completed)
    }
  }
  self.completed = remaining
  found
}

///|
