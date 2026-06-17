///|
// The AgentHost contract: how any agent (MCP client, self-built, test) interacts
// with a running MoUI app instance.
//
// Design rules (see docs/superpowers/specs/2026-06-17-moui-agent-runtime-design.md):
//   - Reads return pure snapshot data (no references into live runtime state).
//   - All writes go through the app's existing dispatch path (AppEvent /
//     CommandIntent), never around `update`. An agent is a privileged user.
//   - The trait is transport-agnostic — moui_agent_mcp adapts it to JSON-RPC,
//     tests adapt it to in-memory mocks.

///|
/// Opaque handle identifying an event subscription, used to unsubscribe.
pub struct SubscriptionToken {
  // Internal id is private so callers can't forge tokens; access goes through
  // the constructor and the internal accessor below.
  priv id : Int
}

///|
pub fn SubscriptionToken::id(self : SubscriptionToken) -> Int {
  self.id
}

///|
/// Construct a token. Exposed so alternative AgentHost implementations (and
/// tests) can mint tokens for their own subscription registries.
pub fn SubscriptionToken::new(id : Int) -> SubscriptionToken {
  { id, }
}

///|
/// Which event kinds a subscriber wants. MVP filters coarsely; `All` includes
/// everything except FrameTick (which is pure render noise for an agent).
pub(all) enum EventFilter {
  All
  /// Only the listed coarse categories: "pointer", "keyboard", "text",
  /// "dragdrop", "webview", "resize", "close". Unknown categories are ignored.
  Only(Array[String])
} derive(Eq, Debug, ToJson)

///|
/// Returns true if a coarse event category passes the filter.
pub fn EventFilter::accept(self : EventFilter, category : String) -> Bool {
  match self {
    All => true
    Only(categories) => categories.contains(category)
  }
}

///|
/// Coarse category tag for an AppEvent, used for subscription filtering.
/// FrameTick maps to "frame" and is excluded by default (see subscribe_events).
pub fn event_category(event : @core.AppEvent) -> String {
  match event {
    FrameTick(_) => "frame"
    Pointer(_) => "pointer"
    Keyboard(_) => "keyboard"
    TextInput(_) => "text"
    DragDrop(_) => "dragdrop"
    PlatformView(_, _) => "platform-view"
    Resize(_) => "resize"
    Redraw(_) => "redraw"
    CloseRequested => "close"
  }
}

///|
/// The contract between an agent and a running MoUI app.
///
/// Declared `pub(open)` so it can be implemented outside this package — both
/// by `RuntimeAgentHost` (this package, over a live AppRuntime) and by
/// downstream packages or tests (mocks, alternative backends).
///
/// Implementations:
///   - `RuntimeAgentHost` (moui_agent/host.mbt) wraps a live `AppRuntime`.
///   - `MockAgentHost` (tests) records calls for assertions.
pub(open) trait AgentHost {
  // —— Reads ————————————————————————————————————————————————

  /// Snapshot of the current semantics tree (the app's "DOM" for the agent).
  fn semantics(self : Self) -> SemanticsSnapshot

  /// Snapshot of runtime state (message/effect/subscription counters + dirty).
  fn state(self : Self) -> RuntimeStateSnapshot

  /// What the compositor renders to the screen right now — the painted text of
  /// the current frame. This is the surface an agent's action becomes visible
  /// on (a window backend rasterizes exactly these draw commands).
  fn frame(self : Self) -> FrameSnapshot

  /// Operations this host accepts (capabilities). MVP returns a static list.
  fn capabilities(self : Self) -> Array[AgentCapability]

  // —— Event subscription ————————————————————————————————————

  /// Register an event sink. Returns a token usable with `unsubscribe`.
  /// The sink receives an AgentEvent per matching AppEvent, tagged with a
  /// monotonic sequence and best-effort source.
  fn subscribe_events(
    self : Self,
    filter : EventFilter,
    sink : (AgentEvent) -> Unit,
  ) -> SubscriptionToken

  /// Stop delivering events to the subscription identified by `token`.
  /// No-op if the token is unknown.
  fn unsubscribe(self : Self, token : SubscriptionToken) -> Unit

  // —— Writes (go through the app's existing dispatch path) ——————

  /// Inject an AppEvent (Pointer/Keyboard/TextInput/...) as if from a user.
  fn dispatch_event(self : Self, event : @core.AppEvent) -> DispatchResult

  /// Fire a command intent (Activate/Submit/Copy/...) via the runtime's
  /// command dispatch. This is the primary MVP path for agent actions.
  fn dispatch_command(self : Self, intent : @core.CommandIntent) -> DispatchResult
}
