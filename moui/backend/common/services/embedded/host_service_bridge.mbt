///|
using @window_services {type ServiceAsyncQueue}

///|
/// Asynchronous host services shared by Android, iOS, and HarmonyOS.
///
/// The neutral bridge accepts only services implemented by the embedded
/// native callback channel. Requests complete exactly once through their
/// request id; unsupported desktop-only services fail synchronously.
pub struct EmbeddedHostServices {
  queue : @window_services.ServiceAsyncQueue
  capabilities : @host.HostServiceCapabilities
  mut disposed : Bool
}

///|
pub fn EmbeddedHostServices::new(
  capabilities? : @host.HostServiceCapabilities = @host.HostServiceCapabilities::new(
    clipboard=true,
  ),
) -> EmbeddedHostServices {
  {
    queue: @window_services.ServiceAsyncQueue::new(),
    capabilities,
    disposed: false,
  }
}

///|
pub fn EmbeddedHostServices::bridge(
  self : EmbeddedHostServices,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(capabilities=self.capabilities, handle=request => {
    if self.disposed {
      return @host.HostServiceResponse::Unavailable(
        "embedded runtime host services are disposed",
      )
    }
    match request {
      @host.HostServiceRequest::Clipboard(_)
      | @host.HostServiceRequest::PlatformChannel(_) =>
        self.queue.submit(request)
      _ => @host.HostServiceResponse::Unavailable(request.unavailable_message())
    }
  })
}

///|
pub fn EmbeddedHostServices::drain_pending(
  self : EmbeddedHostServices,
) -> Array[@host.HostPendingServiceRequest] {
  if self.disposed {
    []
  } else {
    self.queue.drain_pending()
  }
}

///|
pub fn EmbeddedHostServices::complete(
  self : EmbeddedHostServices,
  id : @host.HostServiceRequestId,
  response : @host.HostServiceResponse,
) -> Bool {
  !self.disposed && self.queue.complete(id, response)
}

///|
pub fn EmbeddedHostServices::on_completed(
  self : EmbeddedHostServices,
  id : @host.HostServiceRequestId,
  handle : (@host.HostCompletedServiceResponse) -> Unit,
) -> Bool {
  !self.disposed && self.queue.on_completed(id, handle)
}

///|
pub fn EmbeddedHostServices::drain_completed(
  self : EmbeddedHostServices,
) -> Array[@host.HostCompletedServiceResponse] {
  self.queue.drain_completed()
}

///|
pub fn EmbeddedHostServices::outstanding_count(
  self : EmbeddedHostServices,
) -> Int {
  self.queue.outstanding_count()
}

///|
fn ServiceAsyncQueue::cancel_outstanding_with_completions(
  self : ServiceAsyncQueue,
  reason : String,
) -> Array[@host.HostCompletedServiceResponse] {
  let outstanding : Array[@host.HostServiceRequestId] = []
  for request in self.pending {
    outstanding.push(request.id)
  }
  for request in self.in_flight {
    outstanding.push(request.id)
  }
  for id in outstanding {
    ignore(self.cancel(id, reason))
  }
  self.drain_completed()
}

///|
pub fn EmbeddedHostServices::dispose(
  self : EmbeddedHostServices,
  reason? : String = "embedded runtime host services disposed",
) -> Array[@host.HostCompletedServiceResponse] {
  if self.disposed {
    []
  } else {
    self.disposed = true
    self.queue.cancel_outstanding_with_completions(reason)
  }
}

///|
pub fn EmbeddedHostServices::disposed(self : EmbeddedHostServices) -> Bool {
  self.disposed
}
