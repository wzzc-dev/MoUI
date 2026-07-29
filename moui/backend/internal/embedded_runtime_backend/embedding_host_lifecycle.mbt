///|
fn HostServiceAsyncQueue::cancel_outstanding_with_completions(
  self : HostServiceAsyncQueue,
  reason : String,
) -> Array[HostCompletedServiceResponse] {
  let outstanding : Array[HostServiceRequestId] = []
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
/// Dispose one embedded-runtime surface epoch. Outstanding services complete exactly
/// once before teardown so an application retained across reattach cannot
/// remain blocked on the old generation.
pub fn EmbeddingHostBridge::dispose(
  self : EmbeddingHostBridge,
  driver? : @runtime.HostRuntimeDriver,
  reason? : String = "embedded runtime host channel disposed",
) -> Unit {
  if !self.disposed {
    // Fail closed before invoking handlers; cancellation callbacks may try to
    // submit follow-up work through a bridge captured from this epoch.
    self.disposed = true
    let completions = self.service_queue.cancel_outstanding_with_completions(
      reason,
    )
    match driver {
      Some(driver) =>
        for completion in completions {
          ignore(
            driver.dispatch_service_completion(
              completion,
              self.service_bridge(),
            ),
          )
        }
      None => ()
    }
    self.updates = []
    self.last_text_input = None
    self.semantics_cursor = None
    self.last_platform_views = []
    ignore(self.service_queue.cancel_all())
  }
}
