///|
pub struct MoWorkbenchApp {
  unit : Unit
}

///|
pub(all) struct WorkbenchSession {
  id : String
  title : String
  project_path : String
  branch : String
  status : String
  summary : String
  active_task : String
  unread_events : Int
} derive(Eq, Debug)

///|
pub(all) struct PlanStep {
  id : String
  title : String
  status : String
  owner : String
  detail : String
} derive(Eq, Debug)

///|
pub(all) struct AgentEvent {
  phase : String
  title : String
  detail : String
  tone : String
} derive(Eq, Debug)

///|
pub(all) struct FileContext {
  id : String
  path : String
  summary : String
  change_kind : String
  lines_changed : Int
} derive(Eq, Debug)

///|
pub(all) struct CommandRun {
  id : Int
  command : String
  cwd : String
  status : String
  exit_code : Int?
} derive(Eq, Debug)

///|
pub(all) struct DiagnosticItem {
  source : String
  severity : String
  message : String
} derive(Eq, Debug)

///|
pub(all) struct WorkbenchModel {
  selected_session_id : String
  selected_panel : String
  prompt : String
  expanded_context : Array[String]
  sessions : Array[WorkbenchSession]
  plan : Array[PlanStep]
  events : Array[AgentEvent]
  files : Array[FileContext]
  commands : Array[CommandRun]
  diagnostics : Array[DiagnosticItem]
  transport : PiTransportState
  last_status : String
}

///|
pub(all) enum WorkbenchMsg {
  SelectSession(String)
  SelectPanel(String)
  PromptChanged(String)
  DispatchPrompt
  ReceiveTransport(PiTransportEvent)
  QueueCommand(String)
  MarkCommandComplete(Int, Int)
  CancelRun
  ClearDiagnostics
  ToggleContext(String)
} derive(Eq, Debug)

///|
pub fn MoWorkbenchApp::new() -> MoWorkbenchApp {
  { unit: () }
}

///|
pub fn WorkbenchSession::new(
  id~ : String,
  title~ : String,
  project_path~ : String,
  branch~ : String,
  status~ : String,
  summary~ : String,
  active_task~ : String,
  unread_events~ : Int,
) -> WorkbenchSession {
  { id, title, project_path, branch, status, summary, active_task, unread_events }
}

///|
pub fn PlanStep::new(
  id~ : String,
  title~ : String,
  status~ : String,
  owner~ : String,
  detail~ : String,
) -> PlanStep {
  { id, title, status, owner, detail }
}

///|
pub fn AgentEvent::new(
  phase~ : String,
  title~ : String,
  detail~ : String,
  tone~ : String,
) -> AgentEvent {
  { phase, title, detail, tone }
}

///|
pub fn FileContext::new(
  id~ : String,
  path~ : String,
  summary~ : String,
  change_kind~ : String,
  lines_changed~ : Int,
) -> FileContext {
  { id, path, summary, change_kind, lines_changed }
}

///|
pub fn CommandRun::new(
  id~ : Int,
  command~ : String,
  cwd~ : String,
  status~ : String,
  exit_code? : Int? = None,
) -> CommandRun {
  { id, command, cwd, status, exit_code }
}

///|
pub fn DiagnosticItem::new(
  source~ : String,
  severity~ : String,
  message~ : String,
) -> DiagnosticItem {
  { source, severity, message }
}

///|
pub fn WorkbenchModel::new() -> WorkbenchModel {
  {
    selected_session_id: "moui-skia",
    selected_panel: "agent",
    prompt: "",
    expanded_context: ["repo", "examples"],
    sessions: sample_sessions(),
    plan: sample_plan(),
    events: sample_events(),
    files: sample_files(),
    commands: sample_commands(),
    diagnostics: sample_diagnostics(),
    transport: PiTransportState::new(),
    last_status: "Ready for Pi RPC",
  }
}

///|
pub fn WorkbenchModel::update(
  self : WorkbenchModel,
  message : WorkbenchMsg,
) -> WorkbenchModel {
  match message {
    SelectSession(id) => { ..self, selected_session_id: id }
    SelectPanel(panel) => { ..self, selected_panel: panel }
    PromptChanged(value) => { ..self, prompt: value }
    DispatchPrompt => self.dispatch_prompt()
    ReceiveTransport(event) => self.receive_transport(event)
    QueueCommand(command) => self.queue_command(command)
    MarkCommandComplete(id, code) => self.mark_command_complete(id, code)
    CancelRun => self.cancel_run()
    ClearDiagnostics =>
      {
        ..self,
        diagnostics: [],
        last_status: "Diagnostics cleared for current session",
      }
    ToggleContext(id) => { ..self, expanded_context: toggle_id(self.expanded_context, id) }
  }
}

///|
pub fn update(model : WorkbenchModel, message : WorkbenchMsg) -> WorkbenchModel {
  model.update(message)
}

///|
pub fn view(model : WorkbenchModel) -> @core.View[WorkbenchMsg] {
  model.view()
}

///|
pub fn MoWorkbenchApp::runtime(
  self : MoWorkbenchApp,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime(width~, height~)
}

///|
pub fn runtime(
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime(width~, height~)
}

///|
pub fn WorkbenchModel::runtime(
  self : WorkbenchModel,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple(init=self, update~, view~),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn WorkbenchModel::active_session(self : WorkbenchModel) -> WorkbenchSession {
  for session in self.sessions {
    if session.id == self.selected_session_id {
      return session
    }
  }
  self.sessions[0]
}

///|
pub fn WorkbenchModel::pending_transport_count(self : WorkbenchModel) -> Int {
  self.transport.command_queue.length()
}

///|
pub fn WorkbenchModel::open_diagnostic_count(self : WorkbenchModel) -> Int {
  self.diagnostics.length()
}

///|
fn WorkbenchModel::dispatch_prompt(self : WorkbenchModel) -> WorkbenchModel {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="User request queued",
        detail=prompt,
        tone="info",
      ),
    )
    let command = SendUserInput(session.id, prompt)
    {
      ..self,
      prompt: "",
      events,
      transport: self.transport.enqueue(command),
      last_status: "Queued prompt for Pi JSONL RPC",
    }
  }
}

///|
fn WorkbenchModel::receive_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(event.to_agent_event())
  {
    ..self,
    events,
    transport: self.transport.apply_event(event),
    last_status: "Pi transport event received",
  }
}

///|
fn WorkbenchModel::queue_command(
  self : WorkbenchModel,
  command : String,
) -> WorkbenchModel {
  let session = self.active_session()
  let commands = self.commands.copy()
  commands.push(
    CommandRun::new(
      id=commands.length() + 1,
      command~,
      cwd=session.project_path,
      status="queued",
    ),
  )
  {
    ..self,
    commands,
    transport: self.transport.enqueue(
      SendUserInput(session.id, "run: " + command),
    ),
    last_status: "Command queued for agent execution",
  }
}

///|
fn WorkbenchModel::mark_command_complete(
  self : WorkbenchModel,
  id : Int,
  code : Int,
) -> WorkbenchModel {
  let commands = self.commands.map(command => {
    if command.id == id {
      {
        ..command,
        status: if code == 0 { "passed" } else { "failed" },
        exit_code: Some(code),
      }
    } else {
      command
    }
  })
  {
    ..self,
    commands,
    last_status: "Command " + id.to_string() + " completed",
  }
}

///|
fn WorkbenchModel::cancel_run(self : WorkbenchModel) -> WorkbenchModel {
  let session = self.active_session()
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Run cancellation requested",
      detail=session.title,
      tone="warning",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue(CancelRun(session.id)),
    last_status: "Cancellation queued",
  }
}

///|
fn PiTransportEvent::to_agent_event(self : PiTransportEvent) -> AgentEvent {
  match self {
    ProcessStarted(pid) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC process started",
        detail="pid " + pid,
        tone="success",
      )
    JsonLineSent(session, line) =>
      AgentEvent::new(
        phase="transport",
        title="JSONL sent: " + session,
        detail=line,
        tone="info",
      )
    JsonLineReceived(session, line) =>
      AgentEvent::new(
        phase="agent",
        title="JSONL received: " + session,
        detail=line,
        tone="success",
      )
    ProcessExited(code) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC process exited",
        detail="exit code " + code.to_string(),
        tone="warning",
      )
    TransportFailed(reason) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC transport failed",
        detail=reason,
        tone="danger",
      )
  }
}

///|
fn toggle_id(values : Array[String], id : String) -> Array[String] {
  if values.any(value => value == id) {
    values.filter(value => value != id)
  } else {
    let next = values.copy()
    next.push(id)
    next
  }
}
