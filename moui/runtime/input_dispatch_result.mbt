///|
/// Result returned to an input host immediately after a pointer event has
/// reached the runtime tree. Hosts use this to decide browser default behavior
/// and native pointer capture; application views remain unaware of the host.
pub struct InputDispatchResult {
  handled : Bool
  capture_pointer : Bool
  release_pointer : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn InputDispatchResult::host_flags(self : InputDispatchResult) -> Int {
  (if self.handled { 1 } else { 0 }) |
  (if self.capture_pointer { 2 } else { 0 }) |
  (if self.release_pointer { 4 } else { 0 })
}
