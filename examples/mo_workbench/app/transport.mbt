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
  StartRpc(String)
  SendUserInput(String, String)
  CancelRun(String)
  Shutdown
} derive(Eq, Debug)

///|
pub(all) enum PiTransportEvent {
  ProcessStarted(String)
  JsonLineSent(String, String)
  JsonLineReceived(String, String)
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
  let command_queue = self.command_queue.copy()
  command_queue.push(command)
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
    JsonLineSent(_session, line) => { ..self, last_json_line: line }
    JsonLineReceived(_session, line) => { ..self, last_json_line: line }
    ProcessExited(code) =>
      {
        ..self,
        status: Disconnected,
        last_json_line: "process exited: " + code.to_string(),
      }
    TransportFailed(reason) =>
      { ..self, status: Failed(reason), last_json_line: reason }
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
    StartRpc(cwd) => "start rpc in " + cwd
    SendUserInput(session, text) => "send prompt for " + session + ": " + text
    CancelRun(session) => "cancel run for " + session
    Shutdown => "shutdown rpc"
  }
}
