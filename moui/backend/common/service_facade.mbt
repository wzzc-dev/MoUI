///|
priv struct HostServicesAdapter {
  bridge : @backend_host.HostServiceBridge
  async_queue : ServiceAsyncQueue?
}

///|
fn HostServicesAdapter::new(
  bridge~ : @backend_host.HostServiceBridge,
  async_queue? : ServiceAsyncQueue? = None,
) -> HostServicesAdapter {
  { bridge, async_queue }
}

///|
fn HostServicesAdapter::dispatch(
  self : HostServicesAdapter,
  request : @backend_host.HostServiceRequest,
) -> @backend_host.HostServiceResponse {
  self.bridge.dispatch(request)
}

///|
fn HostServicesAdapter::on_completed_with_cleanup(
  self : HostServicesAdapter,
  id : @backend_host.HostServiceRequestId,
  handle : (@backend_host.HostCompletedServiceResponse) -> Unit,
) -> (Bool, (() -> Unit)?) {
  match self.async_queue {
    Some(queue) => queue.on_completed_with_cleanup(id, handle)
    None => (false, None)
  }
}
