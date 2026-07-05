// Backend-agnostic abstraction for the Mo Workbench agent.
//
// The app package stays portable (native + wasm-gc) and does not depend on any
// native-only LLM SDK. A concrete backend (currently `stub()`; a future
// Kun-compatible HTTP/SSE transport, mirroring DeepSeek-GUI's
// `LocalHttpRuntimeAdapter`, may live in a `native_transport` subpackage and
// inject an `AgentBackendRuntime` here) is supplied by the platform entrypoint.
//
// Communication flow:
//   UI side  -> Effect::run callback (sync) -> runtime.run(commands, emit)
//   backend  -> async worker -> emit(event) -> dispatch(map(event)) into UI queue

///|
/// Model provider choice. Mirrors openseek's `Model` but stays portable.
pub(all) enum ModelChoice {
  V4Flash
  V4Pro
} derive(Eq, Debug)

///|
/// Thinking mode choice. Mirrors openseek's `ThinkingMode`.
pub(all) enum ThinkingChoice {
  No
  High
  Max
} derive(Eq, Debug)

///|
/// Terminal status of an agent turn. Mirrors openseek's `TurnTerminal`.
pub(all) enum TurnStatus {
  Finished
  Aborted
  Interrupted
  Failed
} derive(Eq, Debug)

///|
/// Neutral agent events projected from the backend into the UI.
/// The backend (openseek) maps its `SessionItem` / runtime events into these.
pub(all) enum AgentEvent {
  /// A user message was committed to the session.
  UserMessageAdded(String)
  /// An assistant message (final content) was committed. The second argument
  /// is optional thinking/reasoning content shown collapsed.
  AssistantMessageAdded(String, String?)
  /// A tool call produced a result: (tool_name, content, is_error, brief?).
  ToolResultAdded(String, String, Bool, String?)
  /// A runtime notice (e.g. compaction, watcher snapshot) was committed.
  RuntimeNoticeAdded(String)
  /// The turn terminated: (status, message).
  TurnTerminal(TurnStatus, String)
  /// Best-effort progress notice (lossy, e.g. "calling model...", "running tool...").
  ProgressNotice(String)
  /// The active session's full message stream was rebuilt (e.g. after switch).
  /// Carries the complete ordered list of items to replace the UI message list.
  SessionRebuilt(Array[AgentEvent])
  /// Session list refreshed (from the persistent store).
  SessionListed(Array[SessionSummary])
  /// Active session id changed.
  ActiveSessionChanged(String)
}

///|
/// A lightweight session summary for the sidebar list.
pub struct SessionSummary {
  id : String
  first_prompt : String
  last_active_unix_seconds : Int64?
} derive(Eq, Debug)

///|
fn SessionSummary::new(
  id~ : String,
  first_prompt~ : String,
  last_active_unix_seconds? : Int64? = None,
) -> SessionSummary {
  { id, first_prompt, last_active_unix_seconds }
}

///|
pub fn session_summary(
  id~ : String,
  first_prompt~ : String,
  last_active_unix_seconds? : Int64? = None,
) -> SessionSummary {
  SessionSummary::new(id~, first_prompt~, last_active_unix_seconds~)
}

///|
/// Commands dispatched from the UI to the backend.
pub(all) enum AgentCommand {
  /// Send a user task to the active session and run a turn.
  SendTask(String)
  /// Mid-turn steering text (lossless).
  Steer(String)
  /// Create a new session with the given name prefix.
  NewSession(String)
  /// Switch to an existing session by id.
  SwitchSession(String)
  /// Change the active model.
  SetModel(ModelChoice)
  /// Change the thinking mode.
  SetThinking(ThinkingChoice)
  /// Request the session list from the store.
  FetchSessionList
  /// Stop the backend loop.
  Shutdown
}

///|
/// A backend runtime is a closure that accepts a batch of commands and an emit
/// callback for events. Concrete backends (openseek owner) construct this.
pub struct AgentBackendRuntime {
  run : (Array[AgentCommand], (AgentEvent) -> Unit) -> Unit
}

///|
fn AgentBackendRuntime::new(
  run~ : (Array[AgentCommand], (AgentEvent) -> Unit) -> Unit,
) -> AgentBackendRuntime {
  { run, }
}

///|
/// Construct a backend runtime from a command handler (used by native entrypoints).
pub fn agent_backend_runtime(
  run~ : (Array[AgentCommand], (AgentEvent) -> Unit) -> Unit,
) -> AgentBackendRuntime {
  AgentBackendRuntime::new(run~)
}

///|
/// A stub backend that echoes canned replies, so the UI is fully interactive
/// without an LLM. Native macOS Skia injects `openseek_native_transport` when
/// an API key is set.
pub fn AgentBackendRuntime::stub() -> AgentBackendRuntime {
  AgentBackendRuntime::new(run=(commands, emit) => {
    for cmd in commands {
      match cmd {
        SendTask(task) => {
          emit(ProgressNotice("Thinking..."))
          emit(
            AssistantMessageAdded(
              "(stub reply) You said: " +
              task +
              ". This is an offline placeholder; set openai_api_key in settings.json for OpenSeek.",
              None,
            ),
          )
          emit(TurnTerminal(TurnStatus::Finished, "Done"))
        }
        Steer(text) =>
          emit(RuntimeNoticeAdded("Steer recorded (stub): " + text))
        NewSession(prefix) => {
          let id = prefix + "-" + stub_timestamp()
          emit(ActiveSessionChanged(id))
          emit(SessionListed([SessionSummary::new(id~, first_prompt="")]))
        }
        SwitchSession(id) => {
          emit(ActiveSessionChanged(id))
          emit(SessionRebuilt([]))
        }
        SetModel(_) => ()
        SetThinking(_) => ()
        FetchSessionList => emit(SessionListed([]))
        Shutdown => ()
      }
    }
  })
}

///|
fn stub_timestamp() -> String {
  "stub"
}

///|
/// Dispatch a batch of commands through the backend, mapping emitted events
/// into `Msg` via `map`. Returns a no-op effect when the batch is empty.
pub fn[Msg] AgentBackendRuntime::effect(
  self : AgentBackendRuntime,
  commands : Array[AgentCommand],
  map : (AgentEvent) -> Msg,
) -> @moui.Effect[Msg] {
  if commands.is_empty() {
    @moui.Effect::none()
  } else {
    @moui.Effect::run(
      key="agent-backend:dispatch",
      kind="agent-backend",
      label="Agent backend dispatch",
      run=dispatch => (self.run)(commands, event => dispatch(map(event))),
    )
  }
}

// ---------------------------------------------------------------------------
// Fixture backend (for portable tests; no real LLM calls)
// ---------------------------------------------------------------------------

///|
/// A fixture backend that records dispatched commands and replays a scripted
/// event sequence. Used by wbtest to drive the update loop without a network.
pub struct AgentBackendFixture {
  dispatched : Array[AgentCommand]
  script : (AgentCommand) -> Array[AgentEvent]
}

///|
pub fn AgentBackendFixture::new(
  script~ : (AgentCommand) -> Array[AgentEvent],
) -> AgentBackendFixture {
  { dispatched: [], script }
}

///|
pub fn AgentBackendFixture::dispatched_commands(
  self : AgentBackendFixture,
) -> Array[AgentCommand] {
  let out : Array[AgentCommand] = []
  for cmd in self.dispatched {
    out.push(cmd)
  }
  out
}

///|
pub fn AgentBackendFixture::runtime(
  self : AgentBackendFixture,
) -> AgentBackendRuntime {
  AgentBackendRuntime::new(run=(commands, emit) => {
    for cmd in commands {
      self.dispatched.push(cmd)
      for event in (self.script)(cmd) {
        emit(event)
      }
    }
  })
}
