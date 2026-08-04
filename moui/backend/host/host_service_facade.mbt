///|
priv struct HostServicesAdapter {
  bridge : HostServiceBridge
  async_queue : HostServiceAsyncQueue?
}

///|
fn HostServicesAdapter::new(
  bridge~ : HostServiceBridge,
  async_queue? : HostServiceAsyncQueue? = None,
) -> HostServicesAdapter {
  { bridge, async_queue }
}

///|
fn HostServicesAdapter::dispatch(
  self : HostServicesAdapter,
  request : HostServiceRequest,
) -> HostServiceResponse {
  self.bridge.dispatch(request)
}

///|
fn HostServicesAdapter::on_completed_with_cleanup(
  self : HostServicesAdapter,
  id : HostServiceRequestId,
  handle : (HostCompletedServiceResponse) -> Unit,
) -> (Bool, (() -> Unit)?) {
  match self.async_queue {
    Some(queue) => queue.on_completed_with_cleanup(id, handle)
    None => (false, None)
  }
}
