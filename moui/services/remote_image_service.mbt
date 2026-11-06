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
  priv available_value : Bool
}

///|
pub fn RemoteImageService::new(
  set_completed_listener~ : ((String, Bytes) -> Unit) -> Unit,
) -> RemoteImageService {
  { set_completed_listener_fn: set_completed_listener, available_value: true, }
}

///|
pub fn RemoteImageService::unavailable() -> RemoteImageService {
  { set_completed_listener_fn: _listener => (), available_value: false, }
}

///|
pub fn RemoteImageService::set_completed_listener(
  self : RemoteImageService,
  listener : (String, Bytes) -> Unit,
) -> Unit {
  (self.set_completed_listener_fn)(listener)
}

///|
pub fn RemoteImageService::is_available(self : RemoteImageService) -> Bool {
  self.available_value
}
