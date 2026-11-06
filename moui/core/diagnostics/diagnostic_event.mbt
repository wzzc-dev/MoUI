///|
/// Stable severity for a diagnostic event. `Info` is a normal degrade or
/// fallback, `Warning` is a capability gap the app can continue through, and
/// `Error` is a host/render failure that needs attention.
#derive(Eq, Debug, ToJson)
pub(all) enum DiagnosticSeverity {
  Info
  Warning
  Error
}

///|
pub extend DiagnosticSeverity with Debug::{to_repr}

///|
pub extend DiagnosticSeverity with Eq::{not_equal, equal}

///|
pub extend DiagnosticSeverity with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum DiagnosticDomain {
  Runtime
  Render
  Backend
  Text
  Accessibility
  Services
}

///|
pub extend DiagnosticDomain with Debug::{to_repr}

///|
pub extend DiagnosticDomain with Eq::{not_equal, equal}

///|
pub extend DiagnosticDomain with ToJson::{to_json}

///|
/// One cross-layer diagnostic fact. Capability notes stay in the renderer
/// capability report; this envelope carries the stable code, severity, and
/// short message that DevTools, Showcase, embedded wire transport, and Agent
/// hosts can all consume.
#derive(Eq, Debug, ToJson)
pub(all) struct DiagnosticEvent {
  code : String
  severity : DiagnosticSeverity
  domain : DiagnosticDomain
  message : String
  source : String
  generation : UInt64?
  frame : UInt64?
  detail : String?
}

///|
pub extend DiagnosticEvent with Debug::{to_repr}

///|
pub extend DiagnosticEvent with Eq::{not_equal, equal}

///|
pub extend DiagnosticEvent with ToJson::{to_json}

///|
pub fn DiagnosticEvent::new(
  code~ : String,
  severity~ : DiagnosticSeverity,
  domain~ : DiagnosticDomain,
  message~ : String,
  source~ : String = "",
  generation~ : UInt64? = None,
  frame~ : UInt64? = None,
  detail~ : String? = None,
) -> DiagnosticEvent {
  { code, severity, domain, message, source, generation, frame, detail, }
}

///|
pub fn DiagnosticEvent::is_error(self : DiagnosticEvent) -> Bool {
  self.severity == Error
}

///|
/// Caller-owned bounded diagnostic sink. It is deliberately not a runtime
/// global log (ADR 0056): a tool/host creates one, passes it to the producers
/// it cares about, and drains it at a sampling boundary.
pub struct DiagnosticSink {
  priv events : Array[DiagnosticEvent]
  priv capacity : Int32
}

///|
pub fn DiagnosticSink::new(capacity~ : Int32 = 64) -> DiagnosticSink {
  { events: [], capacity: if capacity < 1 { 1 } else { capacity }, }
}

///|
pub fn DiagnosticSink::push(
  self : DiagnosticSink,
  event : DiagnosticEvent,
) -> Unit {
  self.events.push(event)
  while self.events.length() > self.capacity {
    ignore(self.events.remove(0))
  }
}

///|
pub fn DiagnosticSink::snapshot(
  self : DiagnosticSink,
) -> Array[DiagnosticEvent] {
  self.events.copy()
}

///|
pub fn DiagnosticSink::drain(self : DiagnosticSink) -> Array[DiagnosticEvent] {
  let drained = self.events.copy()
  self.events.clear()
  drained
}

///|
pub fn DiagnosticSink::length(self : DiagnosticSink) -> Int32 {
  self.events.length()
}

///|
pub fn DiagnosticSink::clear(self : DiagnosticSink) -> Unit {
  self.events.clear()
}

///|
test "diagnostic sink keeps the newest events within its capacity" {
  let sink = DiagnosticSink::new(capacity=2)
  sink.push(
    DiagnosticEvent::new(
      code="a",
      severity=Info,
      domain=Runtime,
      message="first",
    ),
  )
  sink.push(
    DiagnosticEvent::new(
      code="b",
      severity=Warning,
      domain=Render,
      message="second",
    ),
  )
  sink.push(
    DiagnosticEvent::new(
      code="c",
      severity=Error,
      domain=Backend,
      message="third",
    ),
  )
  inspect(sink.length(), content="2")
  let events = sink.snapshot()
  inspect(events[0].code, content="b")
  inspect(events[1].code, content="c")
  inspect(events[1].is_error(), content="true")
}

///|
test "diagnostic sink drain returns the retained events once" {
  let sink = DiagnosticSink::new()
  sink.push(
    DiagnosticEvent::new(
      code="renderer.feature.gap",
      severity=Warning,
      domain=Render,
      message="text is partial",
    ),
  )
  let drained = sink.drain()
  inspect(drained.length(), content="1")
  inspect(sink.length(), content="0")
}
