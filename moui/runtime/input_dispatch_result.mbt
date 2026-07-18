///|
/// Result returned to an input host immediately after a pointer event has
/// reached the runtime tree. Hosts use this to decide browser default behavior
/// and native pointer capture; application views remain unaware of the host.
pub(all) struct InputDispatchResult {
  handled : Bool
  capture_pointer : Bool
  release_pointer : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn InputDispatchResult::ignored() -> InputDispatchResult {
  { handled: false, capture_pointer: false, release_pointer: false }
}
