///|
pub(all) enum PiTransportKind {
  NativeProcessJsonl
  WebBridge
  Fixture
} derive(Eq, Debug)

///|
pub(all) enum PiTransportStatus {
  Disconnected
  Starting
  Running
  Failed(String)
} derive(Eq, Debug)

///|
pub(all) enum PiTransportCommand {
  StartRpc(String, String)
  NewRpcSession(String)
  SwitchRpcSession(String, String)
  FetchRpcAvailableModels(String)
  FetchRpcMessages(String)
  FetchRpcForkMessages(String)
  FetchRpcCommands(String)
  FetchRpcSessionStats(String)
  ForkRpcSession(String, String)
  ExportRpcSessionHtml(String, String)
  CycleRpcModel(String)
  CompactRpcSession(String, String)
  CycleRpcThinkingLevel(String)
  SetRpcSteeringMode(String, String)
  SetRpcFollowUpMode(String, String)
  SetRpcSessionName(String, String)
  SendUserInput(String, String)
  RunShellCommand(String, String)
  CancelShellCommand(String)
  CancelRpcRun(String)
  Shutdown
} derive(Eq, Debug)

///|
pub struct PiTransportRuntime {
  priv run : (Array[PiTransportCommand], (PiTransportEvent) -> Unit) -> Unit
}

///|
pub(all) enum PiTransportEvent {
  ProcessStarted(String)
  JsonLineSent(String, String)
  JsonLineReceived(String, String)
  ProcessStderr(String, String)
  ProcessExited(Int)
  TransportFailed(String)
} derive(Eq, Debug)

///|
pub(all) struct PiTransportState {
  kind : PiTransportKind
  status : PiTransportStatus
  command_queue : Array[PiTransportCommand]
  last_json_line : String
} derive(Eq, Debug)

///|
pub fn PiTransportState::new() -> PiTransportState {
  {
    kind: NativeProcessJsonl,
    status: Disconnected,
    command_queue: [],
    last_json_line: "",
  }
}

///|
pub fn PiTransportState::enqueue(
  self : PiTransportState,
  command : PiTransportCommand,
) -> PiTransportState {
  self.enqueue_many([command])
}

///|
pub fn PiTransportState::enqueue_many(
  self : PiTransportState,
  commands : Array[PiTransportCommand],
) -> PiTransportState {
  let command_queue = self.command_queue.copy()
  for command in commands {
    command_queue.push(command)
  }
  { ..self, command_queue, status: Starting }
}

///|
pub fn PiTransportState::apply_event(
  self : PiTransportState,
  event : PiTransportEvent,
) -> PiTransportState {
  match event {
    ProcessStarted(pid) =>
      { ..self, status: Running, last_json_line: "pid " + pid }
    JsonLineSent(_session, line) =>
      {
        ..self,
        command_queue: drop_first_command(self.command_queue),
        last_json_line: line,
      }
    JsonLineReceived(_session, line) => { ..self, last_json_line: line }
    ProcessStderr(_session, line) =>
      { ..self, last_json_line: "stderr: " + line }
    ProcessExited(code) =>
      {
        ..self,
        status: Disconnected,
        command_queue: [],
        last_json_line: "process exited: " + code.to_string(),
      }
    TransportFailed(reason) =>
      {
        ..self,
        status: Failed(reason),
        command_queue: [],
        last_json_line: reason,
      }
  }
}

///|
pub fn PiTransportState::status_label(self : PiTransportState) -> String {
  self.status.label()
}

///|
pub fn PiTransportStatus::label(self : PiTransportStatus) -> String {
  match self {
    Disconnected => "Disconnected"
    Starting => "Starting"
    Running => "Running"
    Failed(reason) => "Failed: " + reason
  }
}

///|
pub fn PiTransportKind::label(self : PiTransportKind) -> String {
  match self {
    NativeProcessJsonl => "native pi --mode rpc JSONL"
    WebBridge => "web bridge"
    Fixture => "fixture"
  }
}

///|
pub fn PiTransportCommand::label(self : PiTransportCommand) -> String {
  match self {
    StartRpc(session, cwd) => "start rpc for " + session + " in " + cwd
    NewRpcSession(session) => "new rpc session for " + session
    SwitchRpcSession(session, path) =>
      "switch rpc session for " + session + ": " + path
    FetchRpcAvailableModels(session) =>
      "fetch rpc available models for " + session
    FetchRpcMessages(session) => "fetch rpc messages for " + session
    FetchRpcForkMessages(session) => "fetch rpc fork messages for " + session
    FetchRpcCommands(session) => "fetch rpc commands for " + session
    FetchRpcSessionStats(session) => "fetch rpc session stats for " + session
    ForkRpcSession(session, entry_id) =>
      "fork rpc session for " + session + ": " + entry_id
    ExportRpcSessionHtml(session, path) =>
      if path == "" {
        "export rpc session html for " + session
      } else {
        "export rpc session html for " + session + ": " + path
      }
    CycleRpcModel(session) => "cycle rpc model for " + session
    CompactRpcSession(session, instructions) =>
      if instructions == "" {
        "compact rpc session for " + session
      } else {
        "compact rpc session for " + session + ": " + instructions
      }
    CycleRpcThinkingLevel(session) => "cycle rpc thinking level for " + session
    SetRpcSteeringMode(session, mode) =>
      "set rpc steering mode for " + session + ": " + mode
    SetRpcFollowUpMode(session, mode) =>
      "set rpc follow-up mode for " + session + ": " + mode
    SetRpcSessionName(session, name) =>
      "set rpc session name for " + session + ": " + name
    SendUserInput(session, text) => "send prompt for " + session + ": " + text
    RunShellCommand(session, command) =>
      "run shell command for " + session + ": " + command
    CancelShellCommand(session) => "cancel shell command for " + session
    CancelRpcRun(session) => "cancel run for " + session
    Shutdown => "shutdown rpc"
  }
}

///|
pub fn PiTransportRuntime::new(
  run~ : (Array[PiTransportCommand], (PiTransportEvent) -> Unit) -> Unit,
) -> PiTransportRuntime {
  { run, }
}

///|
pub fn PiTransportRuntime::unavailable(
  reason? : String = "Pi transport runtime is unavailable",
) -> PiTransportRuntime {
  PiTransportRuntime::new(run=(_commands, emit) => emit(TransportFailed(reason)))
}

///|
pub fn PiTransportRuntime::fixture(
  events~ : (Array[PiTransportCommand]) -> Array[PiTransportEvent],
) -> PiTransportRuntime {
  PiTransportRuntime::new(run=(commands, emit) => {
    for event in events(commands) {
      emit(event)
    }
  })
}

///|
pub fn PiTransportRuntime::dispatch(
  self : PiTransportRuntime,
  commands : Array[PiTransportCommand],
  emit : (PiTransportEvent) -> Unit,
) -> Unit {
  (self.run)(commands, emit)
}

///|
pub fn[Msg] PiTransportRuntime::effect(
  self : PiTransportRuntime,
  commands : Array[PiTransportCommand],
  map : (PiTransportEvent) -> Msg,
) -> @core.Effect[Msg] {
  if commands.is_empty() {
    @core.Effect::none()
  } else {
    @core.Effect::dispatch(dispatch => {
      self.dispatch(commands, event => dispatch(map(event)))
    })
  }
}

///|
fn drop_first_command(
  commands : Array[PiTransportCommand],
) -> Array[PiTransportCommand] {
  if commands.length() == 0 {
    []
  } else {
    commands[1:].to_owned()
  }
}
