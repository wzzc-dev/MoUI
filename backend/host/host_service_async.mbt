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
}

///|
pub fn HostServiceRequestId::new(value : Int) -> HostServiceRequestId {
  { value, }
}

///|
pub fn HostServiceAsyncQueue::new() -> HostServiceAsyncQueue {
  { next_value: 1, pending: [], in_flight: [], completed: [] }
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
      self.completed.push({ id, request, response })
      true
    }
    None => false
  }
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
