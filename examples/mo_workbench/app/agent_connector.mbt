///|
enum AgentConnectorStatus {
  ConnectorDisconnected
  ConnectorReady
  ConnectorStarting
  ConnectorRunning
  ConnectorFailed(String)
} derive(Eq, Debug)

///|
pub(all) struct AgentConnectorProfile {
  backend_id : String
  aid : String
  name : String
  description : String
  protocol_label : String
  endpoint : String
  capabilities : Array[String]
} derive(Eq, Debug)

///|
pub(all) enum AgentConnectorCommand {
  StartConnectorSession(String, String)
  RefreshConnectorSession(String)
  NewConnectorSession(String)
  SendConnectorMessage(String, String)
  InvokeConnectorCommand(String, String)
  CancelConnectorRun(String)
  ShutdownConnector
} derive(Eq, Debug)

///|
pub(all) enum AgentConnectorEvent {
  ConnectorProfileLoaded(String, AgentConnectorProfile)
  ConnectorSessionBound(String, String, String, String)
  ConnectorCommandSent(String, String)
  ConnectorAssistantMessage(String, String, String)
  ConnectorRunCompleted(String)
  ConnectorTransportFailed(String, String)
} derive(Eq, Debug)

///|
struct AgentConnectorState {
  backend_id : String
  profile : AgentConnectorProfile
  status : AgentConnectorStatus
  command_queue : Array[AgentConnectorCommand]
  provider_session_id : String
  session_name : String
  model : String
  last_command : String
  last_activity : String
  total_messages : Int
} derive(Eq, Debug)

///|
pub struct AgentConnectorRuntime {
  priv backend_id : String
  priv available : Bool
  priv run : (Array[AgentConnectorCommand], (AgentConnectorEvent) -> Unit) -> Unit
}

///|
pub fn AgentConnectorProfile::new(
  backend_id~ : String,
  aid? : String = "",
  name~ : String,
  description? : String = "",
  protocol_label? : String = "ACP",
  endpoint? : String = "",
  capabilities? : Array[String] = [],
) -> AgentConnectorProfile {
  { backend_id, aid, name, description, protocol_label, endpoint, capabilities }
}

///|
pub fn AgentConnectorProfile::acp_demo() -> AgentConnectorProfile {
  AgentConnectorProfile::new(
    backend_id="acp-demo",
    aid="aid:demo:mo-workbench",
    name="ACP Demo",
    description="Fixture-backed Agent Connect Protocol connector.",
    protocol_label="ACP fixture",
    endpoint="agentprofile.json",
    capabilities=["agentprofile", "session", "message"],
  )
}

///|
fn AgentConnectorState::new(
  backend_id~ : String,
  profile~ : AgentConnectorProfile,
) -> AgentConnectorState {
  {
    backend_id,
    profile,
    status: ConnectorDisconnected,
    command_queue: [],
    provider_session_id: "",
    session_name: "",
    model: "",
    last_command: "",
    last_activity: "",
    total_messages: 0,
  }
}

///|
fn AgentConnectorState::acp_demo() -> AgentConnectorState {
  AgentConnectorState::new(
    backend_id="acp-demo",
    profile=AgentConnectorProfile::acp_demo(),
  )
}

///|
fn default_agent_connector_states() -> Array[AgentConnectorState] {
  [AgentConnectorState::acp_demo()]
}

///|
fn AgentConnectorState::enqueue_many(
  self : AgentConnectorState,
  commands : Array[AgentConnectorCommand],
) -> AgentConnectorState {
  if commands.is_empty() {
    return self
  }
  let command_queue = self.command_queue.copy()
  for command in commands {
    command_queue.push(command)
  }
  { ..self, command_queue, status: ConnectorStarting }
}

///|
fn AgentConnectorState::apply_event(
  self : AgentConnectorState,
  event : AgentConnectorEvent,
) -> AgentConnectorState {
  match event {
    ConnectorProfileLoaded(_backend_id, profile) =>
      {
        ..self,
        profile,
        status: ConnectorReady,
        last_activity: "profile loaded: " + profile.name,
      }
    ConnectorSessionBound(_backend_id, provider_session_id, session_name, model) =>
      {
        ..self,
        status: ConnectorRunning,
        provider_session_id,
        session_name,
        model,
        last_activity: "session bound: " + provider_session_id,
      }
    ConnectorCommandSent(_backend_id, label) =>
      {
        ..self,
        status: ConnectorRunning,
        command_queue: drop_first_connector_command(self.command_queue),
        last_command: label,
        last_activity: label,
      }
    ConnectorAssistantMessage(_backend_id, summary, _detail) =>
      {
        ..self,
        status: ConnectorRunning,
        last_activity: summary,
        total_messages: self.total_messages + 1,
      }
    ConnectorRunCompleted(_backend_id) =>
      {
        ..self,
        status: ConnectorReady,
        command_queue: [],
        last_activity: "run completed",
      }
    ConnectorTransportFailed(_backend_id, reason) =>
      {
        ..self,
        status: ConnectorFailed(reason),
        command_queue: [],
        last_activity: reason,
      }
  }
}

///|
fn AgentConnectorStatus::label(self : AgentConnectorStatus) -> String {
  match self {
    ConnectorDisconnected => "未连接"
    ConnectorReady => "就绪"
    ConnectorStarting => "启动中"
    ConnectorRunning => "运行中"
    ConnectorFailed(reason) => "失败：" + reason
  }
}

///|
fn AgentConnectorState::status_label(self : AgentConnectorState) -> String {
  self.status.label()
}

///|
pub fn AgentConnectorEvent::backend_id(self : AgentConnectorEvent) -> String {
  match self {
    ConnectorProfileLoaded(backend_id, _) => backend_id
    ConnectorSessionBound(backend_id, _, _, _) => backend_id
    ConnectorCommandSent(backend_id, _) => backend_id
    ConnectorAssistantMessage(backend_id, _, _) => backend_id
    ConnectorRunCompleted(backend_id) => backend_id
    ConnectorTransportFailed(backend_id, _) => backend_id
  }
}

///|
fn AgentConnectorState::has_active_transport(
  self : AgentConnectorState,
) -> Bool {
  match self.status {
    ConnectorStarting | ConnectorRunning => true
    _ => false
  }
}

///|
fn AgentConnectorState::has_session_binding(self : AgentConnectorState) -> Bool {
  self.provider_session_id != "" || self.session_name != "" || self.model != ""
}

///|
pub fn AgentConnectorCommand::label(self : AgentConnectorCommand) -> String {
  match self {
    StartConnectorSession(session, cwd) =>
      "start connector session for " + session + " in " + cwd
    RefreshConnectorSession(session) =>
      "refresh connector session for " + session
    NewConnectorSession(session) => "new connector session for " + session
    SendConnectorMessage(session, text) =>
      "send connector message for " + session + ": " + text
    InvokeConnectorCommand(session, command) =>
      "invoke connector command for " + session + ": /" + command
    CancelConnectorRun(session) => "cancel connector run for " + session
    ShutdownConnector => "shutdown connector"
  }
}

///|
pub fn AgentConnectorRuntime::new(
  backend_id~ : String,
  run~ : (Array[AgentConnectorCommand], (AgentConnectorEvent) -> Unit) -> Unit,
) -> AgentConnectorRuntime {
  { backend_id, available: true, run }
}

///|
pub fn AgentConnectorRuntime::unavailable(
  backend_id~ : String,
  reason? : String = "Agent connector runtime is unavailable",
) -> AgentConnectorRuntime {
  {
    backend_id,
    available: false,
    run: (_commands, emit) => emit(ConnectorTransportFailed(backend_id, reason)),
  }
}

///|
pub fn AgentConnectorRuntime::fixture(
  backend_id? : String = "acp-demo",
) -> AgentConnectorRuntime {
  AgentConnectorRuntime::new(backend_id~, run=(commands, emit) => {
    for event in fixture_connector_events(backend_id, commands) {
      emit(event)
    }
  })
}

///|
pub fn AgentConnectorRuntime::backend_id(
  self : AgentConnectorRuntime,
) -> String {
  self.backend_id
}

///|
pub fn AgentConnectorRuntime::is_available(
  self : AgentConnectorRuntime,
) -> Bool {
  self.available
}

///|
pub fn AgentConnectorRuntime::dispatch(
  self : AgentConnectorRuntime,
  commands : Array[AgentConnectorCommand],
  emit : (AgentConnectorEvent) -> Unit,
) -> Unit {
  (self.run)(commands, emit)
}

///|
pub fn[Msg] AgentConnectorRuntime::effect(
  self : AgentConnectorRuntime,
  commands : Array[AgentConnectorCommand],
  map : (AgentConnectorEvent) -> Msg,
) -> @moui.Effect[Msg] {
  if commands.is_empty() {
    @moui.Effect::none()
  } else {
    @moui.Effect::run(
      key="agent-connector:" + self.backend_id + ":dispatch",
      kind="agent-connector",
      label="Agent connector dispatch: " + self.backend_id,
      run=dispatch => self.dispatch(commands, event => dispatch(map(event))),
    )
  }
}

///|
fn fixture_connector_events(
  backend_id : String,
  commands : Array[AgentConnectorCommand],
) -> Array[AgentConnectorEvent] {
  let events : Array[AgentConnectorEvent] = []
  for command in commands {
    match command {
      StartConnectorSession(session, _cwd) => {
        let profile = AgentConnectorProfile::acp_demo()
        events.push(ConnectorProfileLoaded(backend_id, profile))
        events.push(
          ConnectorSessionBound(
            backend_id,
            "acp-fixture:" + session,
            "ACP Demo session",
            "acp-fixture",
          ),
        )
        events.push(ConnectorCommandSent(backend_id, command.label()))
      }
      RefreshConnectorSession(session) => {
        events.push(ConnectorCommandSent(backend_id, command.label()))
        events.push(
          ConnectorAssistantMessage(
            backend_id,
            "ACP session refreshed",
            "Fixture refreshed session " + session,
          ),
        )
        events.push(ConnectorRunCompleted(backend_id))
      }
      NewConnectorSession(session) => {
        events.push(ConnectorCommandSent(backend_id, command.label()))
        events.push(
          ConnectorSessionBound(
            backend_id,
            "acp-fixture:" + session + ":new",
            "ACP Demo new session",
            "acp-fixture",
          ),
        )
        events.push(ConnectorRunCompleted(backend_id))
      }
      SendConnectorMessage(session, text) => {
        events.push(ConnectorCommandSent(backend_id, command.label()))
        events.push(
          ConnectorAssistantMessage(
            backend_id,
            "ACP Demo 已接收任务",
            "Fixture session " + session + " received: " + text,
          ),
        )
        events.push(ConnectorRunCompleted(backend_id))
      }
      InvokeConnectorCommand(session, name) => {
        events.push(ConnectorCommandSent(backend_id, command.label()))
        events.push(
          ConnectorAssistantMessage(
            backend_id,
            "ACP /" + name + " 已执行",
            "Fixture session " + session + " handled ACP command.",
          ),
        )
        events.push(ConnectorRunCompleted(backend_id))
      }
      CancelConnectorRun(session) => {
        events.push(ConnectorCommandSent(backend_id, command.label()))
        events.push(
          ConnectorTransportFailed(
            backend_id,
            "connector run canceled: " + session,
          ),
        )
      }
      ShutdownConnector => ()
    }
  }
  events
}

///|
fn drop_first_connector_command(
  commands : Array[AgentConnectorCommand],
) -> Array[AgentConnectorCommand] {
  if commands.length() == 0 {
    []
  } else {
    commands[1:].to_owned()
  }
}
