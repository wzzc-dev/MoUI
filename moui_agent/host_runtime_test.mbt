///|
// Integration tests for RuntimeAgentHost over a live AppRuntime.
// These exercise the real runtime seams: semantics tree export, command
// dispatch, and the event-observer-driven subscription fan-out.

// —— A minimal in-test counter program, so these tests are self-contained. ——

///|
struct CounterModel {
  count : Int
}

///|
enum CounterMsg {
  Increment
  Decrement
}

///|
fn counter_init() -> CounterModel {
  { count: 0 }
}

///|
fn counter_update(model : CounterModel, msg : CounterMsg) -> CounterModel {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
  }
}

///|
fn counter_view(model : CounterModel) -> @core.View[CounterMsg] {
  @views.column([
    @views.text("Count: \{model.count}"),
    @views.button("Increment", on_click=Increment),
  ])
}

///|
fn counter_program() -> @core.Program[CounterModel, CounterMsg] {
  @core.Program::simple(
    init=counter_init(),
    update=counter_update,
    view=counter_view,
  )
}

///|
fn new_counter_runtime() -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=counter_program(),
    width=200.0,
    height=200.0,
  )
}

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

///|
test "RuntimeAgentHost: semantics returns a non-empty tree" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let snap = host.semantics()
  if snap.node_count < 1 {
    fail("expected non-empty semantics tree; got node_count=\{snap.node_count}")
  }
  if snap.depth < 1 {
    fail("expected depth >= 1; got \{snap.depth}")
  }
}

///|
test "RuntimeAgentHost: state reports runtime counters" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let s = host.state()
  // A fresh program runtime has dispatched zero messages before any input.
  if s.dispatched_count < 0 {
    fail("expected non-negative dispatched_count; got \{s.dispatched_count}")
  }
}

///|
test "RuntimeAgentHost: capabilities lists the agent ops" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let kinds = host.capabilities().map(c => c.kind)
  for
    expected in [
      "get_semantics", "get_state", "dispatch_command", "dispatch_event", "subscribe_events",
    ] {
    if not(kinds.contains(expected)) {
      fail("expected capability \{expected}; got \{kinds}")
    }
  }
}

///|
test "RuntimeAgentHost: subscribe delivers pointer events with sequence" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let received : Array[AgentEvent] = []
  let _ = host.subscribe_events(EventFilter::All, e => received.push(e))
  // Inject a pointer event through the host (goes via runtime.dispatch_event,
  // which triggers the observer -> host.deliver -> subscriber).
  ignore(
    host.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  if received.length() < 1 {
    fail("expected at least one delivered event; got \{received.length()}")
  }
  // First delivered event should be sequence 0.
  if received[0].sequence != 0 {
    fail("expected first sequence == 0; got \{received[0].sequence}")
  }
}

///|
test "RuntimeAgentHost: unsubscribe stops delivery" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let received : Array[AgentEvent] = []
  let token = host.subscribe_events(EventFilter::All, e => received.push(e))
  host.unsubscribe(token)
  ignore(
    host.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  if received.length() != 0 {
    fail("expected no delivery after unsubscribe; got \{received.length()}")
  }
}

///|
test "RuntimeAgentHost: dispatch_event is accepted and runs through runtime" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let result = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if not(result.accepted) {
    fail("expected dispatch_event to be accepted")
  }
}

///|
test "RuntimeAgentHost: dispatch_command routes through runtime and reports acceptance" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  // Activate may or may not be handled depending on focus; either way the host
  // must return a DispatchResult (accepted reflects the runtime bool).
  let _ = host.dispatch_command(@core.CommandIntent::Activate)
  // No assertion crash = the path executed without throwing. We additionally
  // check that the result is well-formed by re-dispatching.
  let r2 = host.dispatch_command(@core.CommandIntent::SelectAll)
  if r2.accepted {
    // ok — runtime accepted
    ()
  } else {
    // ok — runtime rejected; reason must be present when not accepted
    match r2.reason {
      Some(_) => ()
      None => fail("expected a reason when not accepted")
    }
  }
}

// ---------------------------------------------------------------------------
// activate / deactivate: runtime gating
// ---------------------------------------------------------------------------

///|
test "RuntimeAgentHost: new host is active by default" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  if not(host.is_active()) {
    fail("expected a freshly constructed host to be active")
  }
}

///|
test "RuntimeAgentHost: deactivate rejects dispatch_event" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  host.deactivate()
  if host.is_active() {
    fail("expected deactivated host to report inactive")
  }
  let result = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if result.accepted {
    fail("expected dispatch_event to be rejected while deactivated")
  }
  match result.reason {
    Some(msg) =>
      if not(msg.contains("deactivated")) {
        fail("expected reason to mention deactivation; got \{msg}")
      }
    None => fail("expected a reason when rejected due to deactivation")
  }
}

///|
test "RuntimeAgentHost: deactivate rejects dispatch_command" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  host.deactivate()
  let result = host.dispatch_command(@core.CommandIntent::Activate)
  if result.accepted {
    fail("expected dispatch_command to be rejected while deactivated")
  }
}

///|
test "RuntimeAgentHost: deactivate returns empty reads" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  // Sanity: active host returns a non-empty tree.
  if host.semantics().node_count < 1 {
    fail("expected active host to return a non-empty semantics tree")
  }
  host.deactivate()
  // Deactivated: reads come back empty.
  if host.semantics().node_count != 0 {
    fail("expected deactivated host to return empty semantics")
  }
  if host.state().dispatched_count != 0 {
    fail("expected deactivated host to return zeroed state")
  }
  if host.frame().draw_command_count != 0 {
    fail("expected deactivated host to return empty frame")
  }
}

///|
test "RuntimeAgentHost: activate restores full behavior" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  host.deactivate()
  // While offline, a dispatch is rejected.
  let blocked = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if blocked.accepted {
    fail("expected dispatch to be rejected before activate")
  }
  // Bring it back online.
  host.activate()
  if not(host.is_active()) {
    fail("expected host to be active after activate()")
  }
  // Now reads are populated again...
  if host.semantics().node_count < 1 {
    fail("expected semantics to be populated after activate")
  }
  // ...and dispatch is accepted again.
  let ok = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if not(ok.accepted) {
    fail("expected dispatch to be accepted after activate")
  }
}

///|
test "RuntimeAgentHost: deactivate stops event delivery, activate resumes" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  let received : Array[AgentEvent] = []
  let _ = host.subscribe_events(EventFilter::All, e => received.push(e))
  host.deactivate()
  // Offline: dispatch is rejected AND no event is delivered.
  let blocked = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if blocked.accepted {
    fail("expected dispatch rejected while deactivated")
  }
  if received.length() != 0 {
    fail(
      "expected no events delivered while deactivated; got \{received.length()}",
    )
  }
  // Reactivate; a fresh subscription + dispatch should deliver again.
  host.activate()
  let _ = host.subscribe_events(EventFilter::All, e => received.push(e))
  let ok = host.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  if not(ok.accepted) {
    fail("expected dispatch accepted after reactivate")
  }
  if received.length() < 1 {
    fail("expected an event delivered after reactivate")
  }
}

///|
test "RuntimeAgentHost: activate/deactivate are idempotent" {
  let runtime = new_counter_runtime()
  let host = RuntimeAgentHost::new(runtime)
  // Double-deactivate is a no-op.
  host.deactivate()
  host.deactivate()
  if host.is_active() {
    fail("expected host to remain inactive after double deactivate")
  }
  // Double-activate is a no-op.
  host.activate()
  host.activate()
  if not(host.is_active()) {
    fail("expected host to remain active after double activate")
  }
}
