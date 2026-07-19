///|
/// Dispatches a general application event through the runtime tree.
pub fn AppRuntime::dispatch_event(
  self : AppRuntime,
  event : @core.AppEvent,
) -> Unit {
  self.state.dispatch_event(event)
}

///|
/// Dispatches pointer input and returns the synchronous host-consumption result.
/// Browser backends use it to retain native default behavior at scroll edges.
pub fn AppRuntime::dispatch_pointer_input(
  self : AppRuntime,
  event : @core.PointerEvent,
) -> InputDispatchResult {
  (self.state.event_observer)(@core.AppEvent::Pointer(event))
  self.state.dispatch_pointer_event(event)
}
