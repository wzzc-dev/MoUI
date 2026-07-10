///|
// Router tests: feed parsed JSON-RPC requests through `route` against a local
// mock AgentHost, and assert the response shape. No real stdin/stdout.

// —— A minimal recording host for routing tests. ——

///|
struct RecordingHost {
  intents : Array[@core.CommandIntent]
  mut next_sequence : Int
  mut subscriptions : Array[RecordingSubscription]
}

///|
struct RecordingSubscription {
  token : Int
  filter : @agent.EventFilter
  sink : (@agent.AgentEvent) -> Unit
}

///|
fn RecordingHost::new() -> RecordingHost {
  { intents: [], next_sequence: 0, subscriptions: [] }
}

///|
let test_semantics_root : @core.SemanticsNode = {
  element_id: @core.ElementId::new(1),
  role: @core.SemanticsRole::Button,
  level: None,
  url: "",
  label: "click-me",
  value: "",
  description: "",
  state: @core.SemanticsState::default(),
  actions: [@core.SemanticsAction::Activate],
  focus_order: None,
  frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
  children: [],
}

///|
pub impl @agent.AgentHost for RecordingHost with fn semantics(
  _self : RecordingHost,
) -> @agent.SemanticsSnapshot {
  @agent.SemanticsSnapshot::{
    root: test_semantics_root,
    node_count: 1,
    depth: 1,
  }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn state(self : RecordingHost) -> @agent.RuntimeStateSnapshot {
  @agent.RuntimeStateSnapshot::{
    dispatched_count: self.intents.length(),
    update_count: 0,
    pending_message_count: 0,
    active_subscription_count: 0,
    active_effect_task_count: 0,
    dirty_element_ids: [],
  }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn frame(_self : RecordingHost) -> @agent.FrameSnapshot {
  @agent.FrameSnapshot::{ texts: [], draw_command_count: 0 }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn capabilities(
  _self : RecordingHost,
) -> Array[@agent.AgentCapability] {
  [
    @agent.AgentCapability::{
      kind: "dispatch_command",
      description: "Fire a command intent.",
      schema: ({ "intent": "string" } : Json),
    },
  ]
}

///|
pub impl @agent.AgentHost for RecordingHost with fn subscribe_events(
  self : RecordingHost,
  filter : @agent.EventFilter,
  sink : (@agent.AgentEvent) -> Unit,
) -> @agent.SubscriptionToken {
  let id = self.subscriptions.length() + 1
  self.subscriptions.push({ token: id, filter, sink })
  @agent.SubscriptionToken::new(id)
}

///|
pub impl @agent.AgentHost for RecordingHost with fn unsubscribe(
  self : RecordingHost,
  token : @agent.SubscriptionToken,
) -> Unit {
  let target = token.id()
  self.subscriptions = self.subscriptions.filter(s => s.token != target)
}

///|
pub impl @agent.AgentHost for RecordingHost with fn dispatch_event(
  self : RecordingHost,
  event : @core.AppEvent,
) -> @agent.DispatchResult {
  // Fan the event out to subscribers (same semantics as RuntimeAgentHost).
  self.deliver(event)
  @agent.DispatchResult::{ accepted: true, reason: None }
}

///|
/// Deliver an observed AppEvent to matching subscribers (FrameTick suppressed).
fn RecordingHost::deliver(self : RecordingHost, event : @core.AppEvent) -> Unit {
  match event {
    FrameTick(_) => return
    _ => ()
  }
  let category = @agent.event_category(event)
  let seq = self.next_sequence
  self.next_sequence = seq + 1
  let agent_event = @agent.AgentEvent::{
    sequence: seq,
    source: @agent.EventSource::Agent,
    event,
  }
  for sub in self.subscriptions {
    if @agent.EventFilter::accept(sub.filter, category) {
      (sub.sink)(agent_event)
    }
  }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn dispatch_command(
  self : RecordingHost,
  intent : @core.CommandIntent,
) -> @agent.DispatchResult {
  self.intents.push(intent)
  @agent.DispatchResult::{ accepted: true, reason: None }
}

// —— Helpers. ——

///|
/// Parse a JSON request string, aborting on failure (test inputs are literals).
fn req(line : String) -> Json {
  @json.parse(line) catch {
    _ => abort("failed to parse test JSON: \{line}")
  }
}

///|
/// Stringify a response for substring assertions.
fn str_of(j : Json) -> String {
  (j : Json).stringify()
}

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

///|
test "route: initialize returns protocolVersion and server info" {
  let host = RecordingHost::new()
  let request = req("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}")
  let s = str_of(route(host, request))
  if !s.contains("protocolVersion") {
    fail("expected protocolVersion; got \{s}")
  }
  if !s.contains("moui-agent") {
    fail("expected server name; got \{s}")
  }
}

///|
test "route: tools/list advertises the agent tools" {
  let host = RecordingHost::new()
  let request = req("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}")
  let s = str_of(route(host, request))
  for
    tool in ["get_semantics", "get_state", "dispatch_command", "dispatch_event"] {
    if !s.contains(tool) {
      fail("expected tool \{tool} in tools/list; got \{s}")
    }
  }
}

///|
test "route: tools/call dispatch_command invokes the host" {
  let host = RecordingHost::new()
  let request = req(
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_command\",\"arguments\":{\"intent\":\"Activate\"}}}",
  )
  let s = str_of(route(host, request))
  if !s.contains("content") {
    fail("expected content wrapper; got \{s}")
  }
  if host.intents.length() != 1 {
    fail("expected one recorded intent; got \{host.intents.length()}")
  }
  match host.intents[0] {
    @core.CommandIntent::Activate => ()
    _ => fail("expected Activate intent")
  }
}

///|
test "route: tools/call get_semantics returns the tree" {
  let host = RecordingHost::new()
  let request = req(
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"get_semantics\",\"arguments\":{}}}",
  )
  let s = str_of(route(host, request))
  if !s.contains("click-me") {
    fail("expected semantics label in response; got \{s}")
  }
}

///|
test "route: unknown method returns -32601" {
  let host = RecordingHost::new()
  let request = req(
    "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"no/such/method\"}",
  )
  let s = str_of(route(host, request))
  if !s.contains("-32601") {
    fail("expected -32601; got \{s}")
  }
}

///|
test "route: unknown tool returns -32602" {
  let host = RecordingHost::new()
  let request = req(
    "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{\"name\":\"bogus_tool\",\"arguments\":{}}}",
  )
  let s = str_of(route(host, request))
  if !s.contains("-32602") {
    fail("expected -32602; got \{s}")
  }
}

///|
test "route: dispatch_command with bad intent returns -32602" {
  let host = RecordingHost::new()
  let request = req(
    "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_command\",\"arguments\":{\"intent\":\"NotARealIntent\"}}}",
  )
  let s = str_of(route(host, request))
  if !s.contains("-32602") {
    fail("expected -32602 for unknown intent; got \{s}")
  }
  if host.intents.length() != 0 {
    fail(
      "expected no recorded intent for bad input; got \{host.intents.length()}",
    )
  }
}

///|
/// subscribe_events registers a subscription via the router; subsequent
/// dispatch_event calls push notifications through the notify sink.
test "route_notify: subscribe_events streams events to the notify sink" {
  let host = RecordingHost::new()
  let notifications : Array[String] = []
  // Subscribe — returns a token, no notification yet.
  let sub_resp = route_notify(
    host,
    req(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"subscribe_events\",\"arguments\":{}}}",
    ),
    n => notifications.push((n : Json).stringify()),
  )
  let sub_str = (sub_resp : Json).stringify()
  if !(sub_str.contains("subscribed") && sub_str.contains("token")) {
    fail("expected subscribed+token in response; got \{sub_str}")
  }
  // Now dispatch an event; the host must fan it out and the router must notify.
  let _ = route_notify(
    host,
    req(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"dispatch_event\",\"arguments\":{\"event\":{\"kind\":\"Pointer\",\"position\":{\"x\":5,\"y\":5},\"phase\":\"Up\"}}}}",
    ),
    n => notifications.push((n : Json).stringify()),
  )
  if notifications.length() < 1 {
    fail(
      "expected at least one notification after dispatch_event; got \{notifications.length()}",
    )
  }
  if !notifications[0].contains("notifications/events") {
    fail("expected notifications/events method; got \{notifications[0]}")
  }
}
