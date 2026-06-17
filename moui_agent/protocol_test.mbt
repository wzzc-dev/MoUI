///|
// Tests for the AgentHost contract using an in-memory MockAgentHost.
// RuntimeAgentHost (over a live AppRuntime) is exercised in
// host_runtime_test.mbt; these tests verify the contract semantics and
// subscription machinery in isolation.

///|
/// Records the semantic root we hand out, so tests can assert it round-trips.
let mock_root : @core.SemanticsNode = {
  element_id: @core.ElementId::new(1),
  role: @core.SemanticsRole::Button,
  label: "mock-button",
  value: "",
  description: "",
  state: @core.SemanticsState::default(),
  actions: [@core.SemanticsAction::Activate],
  focus_order: None,
  frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
  children: [],
}

///|
/// In-memory host for testing: records dispatched intents/events and supports
/// subscribe/unsubscribe with a monotonic sequence counter.
struct MockAgentHost {
  dispatched_intents : Array[@core.CommandIntent]
  dispatched_events : Array[@core.AppEvent]
  mut next_sequence : Int
  mut next_token : Int
  // Map token id -> (filter, sink). MVP: a simple list of live subscriptions.
  mut subscriptions : Array[MockSubscription]
}

struct MockSubscription {
  token : Int
  filter : EventFilter
  sink : (AgentEvent) -> Unit
}

fn MockAgentHost::new() -> MockAgentHost {
  {
    dispatched_intents: [],
    dispatched_events: [],
    next_sequence: 0,
    next_token: 1,
    subscriptions: [],
  }
}

///|
/// Implements AgentHost for the mock. Used by the contract tests below.
impl AgentHost for MockAgentHost with semantics(self : MockAgentHost) -> SemanticsSnapshot {
  SemanticsSnapshot::{ root: mock_root, node_count: 1, depth: 1 }
}

impl AgentHost for MockAgentHost with state(self : MockAgentHost) -> RuntimeStateSnapshot {
  RuntimeStateSnapshot::{
    dispatched_count: self.dispatched_intents.length() +
    self.dispatched_events.length(),
    update_count: self.dispatched_intents.length(),
    pending_message_count: 0,
    active_subscription_count: self.subscriptions.length(),
    active_effect_task_count: 0,
    dirty_element_ids: [],
  }
}

impl AgentHost for MockAgentHost with frame(
  self : MockAgentHost,
) -> FrameSnapshot {
  FrameSnapshot::{ texts: [], draw_command_count: 0 }
}

impl AgentHost for MockAgentHost with capabilities(
  self : MockAgentHost,
) -> Array[AgentCapability] {
  [
    AgentCapability::{
      kind: "dispatch_command",
      description: "Fire a command intent (Activate/Submit/...).",
      schema: ({ "intent": "string" } : Json),
    },
    AgentCapability::{
      kind: "dispatch_event",
      description: "Inject an AppEvent as if from a user.",
      schema: ({ "event": "object" } : Json),
    },
  ]
}

impl AgentHost for MockAgentHost with subscribe_events(
  self : MockAgentHost,
  filter : EventFilter,
  sink : (AgentEvent) -> Unit,
) -> SubscriptionToken {
  let id = self.next_token
  self.next_token = id + 1
  self.subscriptions.push({ token: id, filter, sink })
  SubscriptionToken::new(id)
}

impl AgentHost for MockAgentHost with unsubscribe(
  self : MockAgentHost,
  token : SubscriptionToken,
) -> Unit {
  let target = token.id()
  self.subscriptions = self.subscriptions.filter(s => s.token != target)
}

impl AgentHost for MockAgentHost with dispatch_event(
  self : MockAgentHost,
  event : @core.AppEvent,
) -> DispatchResult {
  self.dispatched_events.push(event)
  // Fan the event out to matching subscribers (best-effort source = Agent).
  self.deliver(event, EventSource::Agent)
  DispatchResult::{ accepted: true, reason: None }
}

impl AgentHost for MockAgentHost with dispatch_command(
  self : MockAgentHost,
  intent : @core.CommandIntent,
) -> DispatchResult {
  self.dispatched_intents.push(intent)
  DispatchResult::{ accepted: true, reason: None }
}

///|
/// Deliver an event to all matching subscribers, assigning a sequence.
fn MockAgentHost::deliver(
  self : MockAgentHost,
  event : @core.AppEvent,
  source : EventSource,
) -> Unit {
  // FrameTick is pure render noise; never deliver it.
  match event {
    FrameTick(_) => return
    _ => ()
  }
  let category = event_category(event)
  let seq = self.next_sequence
  self.next_sequence = seq + 1
  let agent_event = AgentEvent::{ sequence: seq, source, event }
  for sub in self.subscriptions {
    if EventFilter::accept(sub.filter, category) {
      (sub.sink)(agent_event)
    }
  }
}

// ---------------------------------------------------------------------------
// Contract tests.
// ---------------------------------------------------------------------------

///|
test "AgentHost: semantics returns the wrapped tree" {
  let host = MockAgentHost::new()
  let snap = host.semantics()
  if snap.node_count != 1 {
    fail("expected node_count 1; got \{snap.node_count}")
  }
  if snap.root.label != "mock-button" {
    fail("expected mock-button label; got \{snap.root.label}")
  }
}

///|
test "AgentHost: capabilities lists dispatch ops" {
  let host = MockAgentHost::new()
  let caps = host.capabilities()
  let kinds = caps.map(c => c.kind)
  if not(kinds.contains("dispatch_command")) {
    fail("expected dispatch_command capability; got \{kinds}")
  }
}

///|
test "AgentHost: dispatch_command records the intent" {
  let host = MockAgentHost::new()
  let r = host.dispatch_command(@core.CommandIntent::Activate)
  if not(r.accepted) {
    fail("expected accepted")
  }
  if host.dispatched_intents.length() != 1 {
    fail("expected one recorded intent")
  }
  match host.dispatched_intents[0] {
    @core.CommandIntent::Activate => ()
    _ => fail("expected Activate")
  }
}

///|
test "AgentHost: subscribe delivers matching events with sequence" {
  let host = MockAgentHost::new()
  let received : Array[AgentEvent] = []
  let _ = host.subscribe_events(EventFilter::All, e => received.push(e))
  ignore(
    host.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=1.0, y=1.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  if received.length() != 1 {
    fail("expected one delivered event; got \{received.length()}")
  }
  if received[0].sequence != 0 {
    fail("expected first sequence == 0; got \{received[0].sequence}")
  }
}

///|
test "AgentHost: unsubscribe stops delivery" {
  let host = MockAgentHost::new()
  let received : Array[AgentEvent] = []
  let token = host.subscribe_events(EventFilter::All, e => received.push(e))
  host.unsubscribe(token)
  ignore(
    host.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=1.0, y=1.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  if received.length() != 0 {
    fail("expected no delivery after unsubscribe; got \{received.length()}")
  }
}

///|
test "AgentHost: EventFilter::Only restricts categories" {
  let host = MockAgentHost::new()
  let received : Array[String] = []
  let _ = host.subscribe_events(
    EventFilter::Only(["keyboard"]),
    e => received.push(event_category(e.event)),
  )
  // A pointer event should be filtered out...
  ignore(
    host.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=1.0, y=1.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  // ...but a keyboard event should pass.
  ignore(
    host.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::{
          key: "a",
          text: None,
          pressed: true,
          repeat: false,
          modifiers: @core.KeyModifiers::none(),
        },
      ),
    ),
  )
  if received != ["keyboard"] {
    fail("expected only keyboard event; got \{received}")
  }
}

///|
test "AgentHost: FrameTick is never delivered" {
  let host = MockAgentHost::new()
  let received : Array[AgentEvent] = []
  let _ = host.subscribe_events(EventFilter::All, e => received.push(e))
  ignore(
    host.dispatch_event(
      @core.AppEvent::FrameTick(@core.Frame::new(time_ms=0.0, delta_ms=0.0)),
    ),
  )
  if received.length() != 0 {
    fail("expected FrameTick to be suppressed; got \{received.length()}")
  }
}
