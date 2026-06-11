///|
pub(all) struct HostServiceRequestId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostPendingServiceRequest {
  id : HostServiceRequestId
  request : HostServiceRequest
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostCompletedServiceResponse {
  id : HostServiceRequestId
  request : HostServiceRequest
  response : HostServiceResponse
} derive(Eq, Debug, ToJson)

///|
pub struct HostServiceAsyncQueue {
  mut next_value : Int
  mut pending : Array[HostPendingServiceRequest]
  mut in_flight : Array[HostPendingServiceRequest]
  mut completed : Array[HostCompletedServiceResponse]
  priv mut next_completion_handler_value : Int
  priv mut completion_handlers : Array[HostServiceCompletionHandler]
}

///|
priv struct HostServiceCompletionHandler {
  token : Int
  id : HostServiceRequestId
  handle : (HostCompletedServiceResponse) -> Unit
}

///|
pub fn HostServiceRequestId::new(value : Int) -> HostServiceRequestId {
  { value, }
}

///|
pub fn HostServiceAsyncQueue::new() -> HostServiceAsyncQueue {
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
pub fn HostServiceAsyncQueue::pending_count(
  self : HostServiceAsyncQueue,
) -> Int {
  self.pending.length()
}

///|
pub fn HostServiceAsyncQueue::completed_count(
  self : HostServiceAsyncQueue,
) -> Int {
  self.completed.length()
}

///|
pub fn HostServiceAsyncQueue::in_flight_count(
  self : HostServiceAsyncQueue,
) -> Int {
  self.in_flight.length()
}

///|
pub fn HostServiceAsyncQueue::outstanding_count(
  self : HostServiceAsyncQueue,
) -> Int {
  self.pending.length() + self.in_flight.length()
}

///|
pub fn HostServiceAsyncQueue::submit(
  self : HostServiceAsyncQueue,
  request : HostServiceRequest,
) -> HostServiceResponse {
  let id = HostServiceRequestId::new(self.next_value)
  self.next_value = self.next_value + 1
  self.pending.push({ id, request })
  HostServiceResponse::Pending(id)
}

///|
pub fn HostServiceAsyncQueue::drain_pending(
  self : HostServiceAsyncQueue,
) -> Array[HostPendingServiceRequest] {
  let pending = self.pending
  for request in pending {
    self.in_flight.push(request)
  }
  self.pending = []
  pending
}

///|
pub fn HostServiceAsyncQueue::drain_completed(
  self : HostServiceAsyncQueue,
) -> Array[HostCompletedServiceResponse] {
  let completed = self.completed
  self.completed = []
  completed
}

///|
pub fn HostServiceAsyncQueue::complete(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
  response : HostServiceResponse,
) -> Bool {
  let mut matched = false
  let mut request : HostServiceRequest? = None
  let remaining : Array[HostPendingServiceRequest] = []
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
    let remaining_in_flight : Array[HostPendingServiceRequest] = []
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
      let completion = { id, request, response }
      if !self.dispatch_completion_handlers(completion) {
        self.completed.push(completion)
      }
      true
    }
    None => false
  }
}

///|
pub fn HostServiceAsyncQueue::on_completed(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
  handle : (HostCompletedServiceResponse) -> Unit,
) -> Bool {
  let (registered, _) = self.on_completed_with_cleanup(id, handle)
  registered
}

///|
fn HostServiceAsyncQueue::on_completed_with_cleanup(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
  handle : (HostCompletedServiceResponse) -> Unit,
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
fn HostServiceAsyncQueue::dispatch_completion_handlers(
  self : HostServiceAsyncQueue,
  completion : HostCompletedServiceResponse,
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
fn HostServiceAsyncQueue::cancel_completion_handler(
  self : HostServiceAsyncQueue,
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
fn HostServiceAsyncQueue::has_outstanding(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
) -> Bool {
  self.pending.any(request => request.id == id) ||
  self.in_flight.any(request => request.id == id)
}

///|
pub fn HostServiceAsyncQueue::reject(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
  reason : String,
) -> Bool {
  self.complete(id, HostServiceResponse::Unavailable(reason))
}

///|
pub fn HostServiceAsyncQueue::take_completed(
  self : HostServiceAsyncQueue,
  id : HostServiceRequestId,
) -> HostCompletedServiceResponse? {
  let mut found : HostCompletedServiceResponse? = None
  let remaining : Array[HostCompletedServiceResponse] = []
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
pub fn HostServiceResponse::is_pending(self : HostServiceResponse) -> Bool {
  match self {
    Pending(_) => true
    _ => false
  }
}

///|
pub fn HostRuntimeDriver::dispatch_service_completion(
  self : HostRuntimeDriver,
  completion : HostCompletedServiceResponse,
  services : HostServiceBridge,
) -> HostEventResult {
  match (completion.request, completion.response) {
    (
      HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
      HostServiceResponse::ClipboardText(text),
    ) => {
      let result = self.runtime.dispatch_focused_text_command(
        @core.CommandIntent::Paste,
        paste_text=Some(text),
      )
      if result.handled {
        self.request_redraw_if_needed()
      } else if self.runtime.dispatch_command(@core.CommandIntent::Paste) {
        self.request_redraw_if_needed()
      }
    }
    (HostServiceRequest::ShowMenu(_), HostServiceResponse::MenuAction(command)) =>
      ignore(self.dispatch_action_command_with_services(command, services))
    (HostServiceRequest::ShowMenu(_), HostServiceResponse::MenuCommand(intent)) =>
      ignore(self.dispatch_command_with_services(intent, services))
    (
      HostServiceRequest::QuerySystemTheme,
      HostServiceResponse::SystemTheme(scheme),
    ) => {
      self.runtime.set_environment(
        self.runtime.environment().with_color_scheme(scheme),
      )
      self.request_redraw_if_needed()
    }
    _ => ()
  }
  self.event_result()
}
