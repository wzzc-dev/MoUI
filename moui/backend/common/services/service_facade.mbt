///|
priv struct HostServicesAdapter {
  bridge : @backend_host.HostServiceBridge
  async_queue : ServiceAsyncQueue?
}

///|
/// Host service bridge lifetime owner. Backends keep this owner directly so
/// callbacks can be rejected after the service channel has been closed.
pub struct WindowServiceState {
  priv bridge : @backend_host.HostServiceBridge
  priv dispose_fn : () -> Unit
  priv mut open : Bool
}

///|
pub fn WindowServiceState::new(
  bridge~ : @backend_host.HostServiceBridge,
  dispose? : () -> Unit = () => (),
) -> WindowServiceState {
  { bridge, dispose_fn: dispose, open: true }
}

///|
pub fn WindowServiceState::bridge(
  self : WindowServiceState,
) -> @backend_host.HostServiceBridge {
  if self.open {
    self.bridge
  } else {
    @backend_host.HostServiceBridge::unavailable()
  }
}

///|
pub fn WindowServiceState::dispose(self : WindowServiceState) -> Unit {
  if self.open {
    // Fail closed before invoking host cleanup because cleanup may re-enter.
    self.open = false
    (self.dispose_fn)()
  }
}

///|
pub fn WindowServiceState::is_open(self : WindowServiceState) -> Bool {
  self.open
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
