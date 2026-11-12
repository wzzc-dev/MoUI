// Caller-owned diagnostics sink exposed to renderer-frame owners. The sink is
// bounded and shares its array with copies, so a frame hook can push without
// holding the runtime.

///|
pub fn AppRuntime::diagnostics_sink(
  self : AppRuntime,
) -> @diagnostics.DiagnosticSink {
  self.state.diagnostics
}

///|
pub fn AppRuntime::push_diagnostics(
  self : AppRuntime,
  events : Array[@diagnostics.DiagnosticEvent],
) -> Unit {
  for event in events {
    self.state.diagnostics.push(event)
  }
}

///|
pub fn AppRuntime::drain_diagnostics(
  self : AppRuntime,
) -> Array[@diagnostics.DiagnosticEvent] {
  self.state.diagnostics.drain()
}
