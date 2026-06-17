///|
// RuntimeAgentHost: the production AgentHost implementation, wrapping a live
// AppRuntime. It wires the runtime's additive event_observer hook into the
// AgentHost subscription fan-out, and maps read/write trait methods onto the
// runtime's existing pub fn seams.
//
// Lifecycle: construct with `RuntimeAgentHost::new(runtime)` — this installs
// the event observer and activates the host. Use `deactivate()` to take the
// host offline at runtime (stops event flow, clears subscriptions, rejects all
// trait calls) and `activate()` to bring it back. The host borrows the runtime
// for the rest of its life.

///|
struct Subscription {
  token : Int
  filter : EventFilter
  sink : (AgentEvent) -> Unit
}

///|
/// AgentHost over a live AppRuntime.
pub struct RuntimeAgentHost {
  runtime : @runtime.AppRuntime
  /// When false, the host is offline: the runtime event observer is detached,
  /// subscriptions are cleared, and every AgentHost method returns a rejected
  /// DispatchResult (or empty for reads). Toggled by activate()/deactivate().
  mut active : Bool
  mut next_token : Int
  mut next_sequence : Int
  mut subscriptions : Array[Subscription]
  /// Self-reference cell so the runtime observer closure (which can only
  /// capture a cell, not `self`) can reach this host on each event, and so
  /// activate() can re-install the observer after deactivate() detached it.
  priv self_cell : @ref.Ref[RuntimeAgentHost?]
}

///|
/// Construct a host bound to `runtime`. Installs the event observer that fans
/// AppEvents out to subscribers, and activates the host. The host borrows the
/// runtime for the rest of its life.
pub fn RuntimeAgentHost::new(
  runtime : @runtime.AppRuntime,
) -> RuntimeAgentHost {
  // MoonBit closures capture by reference. We need the observer to call back
  // into the host on each event, so we store the host in a nullable cell that
  // the closure captures. Build the cell empty first, then fill it.
  let cell : @ref.Ref[RuntimeAgentHost?] = @ref.Ref(None)
  let host : RuntimeAgentHost = {
    runtime,
    active: true,
    next_token: 1,
    next_sequence: 0,
    subscriptions: [],
    self_cell: cell,
  }
  cell.val = Some(host)
  install_observer(cell, runtime)
  host
}

///|
/// Install the event observer on the host's runtime so observed AppEvents fan
/// out to subscribers via the host stored in `cell`. Idempotent.
fn install_observer(
  cell : @ref.Ref[RuntimeAgentHost?],
  runtime : @runtime.AppRuntime,
) -> Unit {
  runtime.set_event_observer(event => {
    match cell.val {
      Some(h) => h.deliver(event, EventSource::System)
      None => ()
    }
  })
}

///|
/// Bring the host online: re-installs the event observer so events flow to
/// subscribers again, and unblocks all AgentHost methods. No-op if already
/// active.
pub fn RuntimeAgentHost::activate(self : RuntimeAgentHost) -> Unit {
  if self.active {
    return
  }
  self.active = true
  install_observer(self.self_cell, self.runtime)
}

///|
/// Take the host offline at runtime: detaches the runtime event observer
/// (events stop flowing to subscribers), clears all subscriptions, and makes
/// every AgentHost method return a rejected/empty result. The host can be
/// brought back with activate(). No-op if already inactive.
pub fn RuntimeAgentHost::deactivate(self : RuntimeAgentHost) -> Unit {
  if not(self.active) {
    return
  }
  self.active = false
  self.subscriptions.clear()
  // Detach the observer so the runtime stops calling back into this host.
  self.runtime.set_event_observer(_event => ())
}

///|
/// Whether the host is currently online (accepting calls and streaming events).
pub fn RuntimeAgentHost::is_active(self : RuntimeAgentHost) -> Bool {
  self.active
}

// —— Reads ————————————————————————————————————————————————

///|
pub impl AgentHost for RuntimeAgentHost with semantics(
  self : RuntimeAgentHost,
) -> SemanticsSnapshot {
  if not(self.active) {
    // Offline: return an empty snapshot rather than failing.
    let empty : @core.SemanticsNode = {
      element_id: @core.ElementId::new(0),
      role: @core.SemanticsRole::None,
      label: "",
      value: "",
      description: "",
      state: @core.SemanticsState::default(),
      actions: [],
      focus_order: None,
      frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
      children: [],
    }
    return SemanticsSnapshot::{ root: empty, node_count: 0, depth: 0 }
  }
  let root = self.runtime.semantics()
  SemanticsSnapshot::{
    root,
    node_count: count_semantics_nodes(root),
    depth: semantics_depth(root),
  }
}

///|
pub impl AgentHost for RuntimeAgentHost with state(
  self : RuntimeAgentHost,
) -> RuntimeStateSnapshot {
  if not(self.active) {
    return RuntimeStateSnapshot::{
      dispatched_count: 0,
      update_count: 0,
      pending_message_count: 0,
      active_subscription_count: 0,
      active_effect_task_count: 0,
      dirty_element_ids: [],
    }
  }
  let snap = self.runtime.program_runtime_snapshot()
  let dirty = self.runtime.dirty_element_ids().map(id =>
    "\{id.value()}"
  )
  RuntimeStateSnapshot::{
    dispatched_count: snap.dispatched_count,
    update_count: snap.update_count,
    pending_message_count: snap.pending_message_count,
    active_subscription_count: snap.active_subscription_count,
    active_effect_task_count: snap.active_effect_task_count,
    dirty_element_ids: dirty,
  }
}

///|
/// Read what the compositor renders to the screen right now — the text strings
/// painted in the current frame. This is the "screen" an agent's action shows
/// up on (the runtime's draw_commands are exactly what a window backend
/// rasterizes).
pub impl AgentHost for RuntimeAgentHost with frame(
  self : RuntimeAgentHost,
) -> FrameSnapshot {
  if not(self.active) {
    return FrameSnapshot::{ texts: [], draw_command_count: 0 }
  }
  let commands = self.runtime.draw_commands()
  let texts : Array[String] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
  FrameSnapshot::{ texts, draw_command_count: commands.length() }
}

///|
pub impl AgentHost for RuntimeAgentHost with capabilities(
  self : RuntimeAgentHost,
) -> Array[AgentCapability] {
  // Capabilities are always advertised; deactivation is a runtime gate, not a
  // change in what the host can do. Callers learn the host is offline from the
  // rejected DispatchResult / empty reads on actual calls.
  [
    AgentCapability::{
      kind: "get_semantics",
      description: "Read the current semantics tree (the app's DOM).",
      schema: ({ "filter": "object-optional" } : Json),
    },
    AgentCapability::{
      kind: "get_state",
      description: "Read runtime counters and dirty element ids.",
      schema: ({} : Json),
    },
    AgentCapability::{
      kind: "dispatch_command",
      description: "Fire a command intent (Activate/Submit/Copy/...).",
      schema: ({ "intent": "string" } : Json),
    },
    AgentCapability::{
      kind: "dispatch_event",
      description: "Inject an AppEvent (Pointer/Keyboard/...) as if from a user.",
      schema: ({ "event": "object" } : Json),
    },
    AgentCapability::{
      kind: "subscribe_events",
      description: "Stream AppEvents to the agent (FrameTick suppressed).",
      schema: ({ "types": "string-array-optional" } : Json),
    },
  ]
}

// —— Event subscription ————————————————————————————————————

///|
pub impl AgentHost for RuntimeAgentHost with subscribe_events(
  self : RuntimeAgentHost,
  filter : EventFilter,
  sink : (AgentEvent) -> Unit,
) -> SubscriptionToken {
  if not(self.active) {
    // Offline: hand back a token the host will never deliver to. Callers can
    // still unsubscribe it; it just won't receive events until activate().
    return SubscriptionToken::new(0)
  }
  let id = self.next_token
  self.next_token = id + 1
  self.subscriptions.push({ token: id, filter, sink })
  SubscriptionToken::new(id)
}

///|
pub impl AgentHost for RuntimeAgentHost with unsubscribe(
  self : RuntimeAgentHost,
  token : SubscriptionToken,
) -> Unit {
  let target = token.id()
  self.subscriptions = self.subscriptions.filter(s => s.token != target)
}

// —— Writes (through the runtime's existing dispatch path) ——————

///|
pub impl AgentHost for RuntimeAgentHost with dispatch_event(
  self : RuntimeAgentHost,
  event : @core.AppEvent,
) -> DispatchResult {
  if not(self.active) {
    return DispatchResult::{
      accepted: false,
      reason: Some("agent host is deactivated"),
    }
  }
  self.runtime.dispatch_event(event)
  DispatchResult::{ accepted: true, reason: None }
}

///|
pub impl AgentHost for RuntimeAgentHost with dispatch_command(
  self : RuntimeAgentHost,
  intent : @core.CommandIntent,
) -> DispatchResult {
  if not(self.active) {
    return DispatchResult::{
      accepted: false,
      reason: Some("agent host is deactivated"),
    }
  }
  let ok = self.runtime.dispatch_command(intent)
  DispatchResult::{ accepted: ok, reason: if ok { None } else {
    Some("runtime did not dispatch the command intent")
  } }
}

// —— Internal: fan an observed AppEvent out to matching subscribers ———

///|
/// Deliver an observed AppEvent to matching subscribers. FrameTick is never
/// delivered (pure render noise). Assigns a monotonic sequence number.
fn RuntimeAgentHost::deliver(
  self : RuntimeAgentHost,
  event : @core.AppEvent,
  source : EventSource,
) -> Unit {
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

// —— Tree statistics helpers (mirror devtools_runtime counters) ————

///|
fn count_semantics_nodes(node : @core.SemanticsNode) -> Int {
  let mut count = 1
  for child in node.children {
    count += count_semantics_nodes(child)
  }
  count
}

///|
fn semantics_depth(node : @core.SemanticsNode) -> Int {
  let mut depth = 1
  for child in node.children {
    let child_depth = 1 + semantics_depth(child)
    if child_depth > depth {
      depth = child_depth
    }
  }
  depth
}
