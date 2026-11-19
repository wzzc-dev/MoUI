///|
/// App-facing contract for remote image loading. The framework only knows that
/// a host can fetch remote image bytes and notify the app when they arrive;
/// the HTTP stack, retry policy, worker, and cache live behind an implementation
/// package (currently `moui/backend/common/services/native`).
///
/// This keeps app code on `moui/services` instead of importing the concrete
/// native image loader or `backend/common/image`.
pub struct RemoteImageService {
  priv set_completed_listener_fn : ((String, Bytes) -> Unit) -> Unit
  priv fetch_fn : (String, (Bytes?) -> Unit) -> RemoteImageRequest?
  priv available_value : Bool
}

///|
/// Cancellable handle for one explicitly requested remote-image fetch.
///
/// `cancel` marks the request cancelled and asks the host implementation to
/// drop the work; a completion that arrives after cancellation is not
/// delivered. Calling it more than once is inert.
pub struct RemoteImageRequest {
  priv cancel_fn : () -> Unit
  priv cancelled : Ref[Bool]
}

///|
pub fn RemoteImageRequest::new(cancel~ : () -> Unit) -> RemoteImageRequest {
  { cancel_fn: cancel, cancelled: Ref(false), }
}

///|
pub fn RemoteImageRequest::cancel(self : RemoteImageRequest) -> Unit {
  if self.cancelled.val {
    return
  }
  self.cancelled.val = true
  (self.cancel_fn)()
}

///|
pub fn RemoteImageRequest::is_cancelled(self : RemoteImageRequest) -> Bool {
  self.cancelled.val
}

///|
/// Builds a service with a completion listener and an optional explicit fetch
/// entry. `fetch` is the cancellable request path: it returns `null` when the
/// host cannot serve the request. Implementations that only feed the
/// renderer-driven completion stream may omit it and stay listener-only.
pub fn RemoteImageService::new(
  set_completed_listener~ : ((String, Bytes) -> Unit) -> Unit,
  fetch~ : (String, (Bytes?) -> Unit) -> RemoteImageRequest? = (
    _source,
    _on_complete,
  ) => None,
) -> RemoteImageService {
  {
    set_completed_listener_fn: set_completed_listener,
    fetch_fn: fetch,
    available_value: true,
  }
}

///|
pub fn RemoteImageService::unavailable() -> RemoteImageService {
  {
    set_completed_listener_fn: _listener => (),
    fetch_fn: (_source, _on_complete) => None,
    available_value: false,
  }
}

///|
pub fn RemoteImageService::set_completed_listener(
  self : RemoteImageService,
  listener : (String, Bytes) -> Unit,
) -> Unit {
  (self.set_completed_listener_fn)(listener)
}

///|
/// Requests one remote-image fetch and returns its cancellable handle, or
/// `None` when the host cannot fetch (unavailable service or rejected queue).
pub fn RemoteImageService::fetch(
  self : RemoteImageService,
  source~ : String,
  on_complete~ : (Bytes?) -> Unit,
) -> RemoteImageRequest? {
  if !self.available_value {
    return None
  }
  (self.fetch_fn)(source, on_complete)
}

///|
pub fn RemoteImageService::is_available(self : RemoteImageService) -> Bool {
  self.available_value
}
