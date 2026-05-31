///|
pub struct MoWorkbenchApp {
  unit : Unit
}

///|
pub(all) struct WorkbenchSession {
  id : String
  title : String
  project_path : String
  pi_session_path : String
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
  tool_call_id : String
} derive(Eq, Debug)

///|
pub(all) struct DiagnosticItem {
  source : String
  severity : String
  message : String
} derive(Eq, Debug)

///|
pub(all) struct DiffOverview {
  changed_files : Int
  additions : Int
  deletions : Int
  status : String
} derive(Eq, Debug)

///|
pub(all) struct PiRpcSnapshot {
  command : String
  success : Bool
  session_id : String
  session_file : String
  session_name : String
  model : String
  pending_message_count : Int
  message_count : Int
  error : String
} derive(Eq, Debug)

///|
pub(all) struct PiAgentSnapshot {
  phase : String
  turn_index : Int
  message_role : String
  message_preview : String
  active_tool_call_id : String
  active_tool_name : String
  queued_steering : Int
  queued_follow_up : Int
  thinking_level : String
} derive(Eq, Debug)

///|
pub(all) struct PiSessionBinding {
  workbench_session_id : String
  rpc_session_id : String
  session_file : String
  session_name : String
  model : String
  status : String
  last_command : String
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
  diff : DiffOverview
  commands : Array[CommandRun]
  diagnostics : Array[DiagnosticItem]
  transport : PiTransportState
  pi_rpc : PiRpcSnapshot
  pi_agent : PiAgentSnapshot
  pi_session_bindings : Array[PiSessionBinding]
  last_status : String
}

///|
pub(all) struct WorkbenchUpdate {
  model : WorkbenchModel
  effect : @core.Effect[WorkbenchMsg]
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
  pi_session_path? : String = "",
  branch~ : String,
  status~ : String,
  summary~ : String,
  active_task~ : String,
  unread_events~ : Int,
) -> WorkbenchSession {
  {
    id,
    title,
    project_path,
    pi_session_path,
    branch,
    status,
    summary,
    active_task,
    unread_events,
  }
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
  tool_call_id? : String = "",
) -> CommandRun {
  { id, command, cwd, status, exit_code, tool_call_id }
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
pub fn DiffOverview::new(
  changed_files~ : Int,
  additions~ : Int,
  deletions~ : Int,
  status~ : String,
) -> DiffOverview {
  { changed_files, additions, deletions, status }
}

///|
pub fn PiRpcSnapshot::new(
  command? : String = "",
  success? : Bool = false,
  session_id? : String = "",
  session_file? : String = "",
  session_name? : String = "",
  model? : String = "",
  pending_message_count? : Int = 0,
  message_count? : Int = 0,
  error? : String = "",
) -> PiRpcSnapshot {
  {
    command,
    success,
    session_id,
    session_file,
    session_name,
    model,
    pending_message_count,
    message_count,
    error,
  }
}

///|
pub fn PiSessionBinding::new(
  workbench_session_id~ : String,
  rpc_session_id? : String = "",
  session_file? : String = "",
  session_name? : String = "",
  model? : String = "",
  status? : String = "unbound",
  last_command? : String = "",
) -> PiSessionBinding {
  {
    workbench_session_id,
    rpc_session_id,
    session_file,
    session_name,
    model,
    status,
    last_command,
  }
}

///|
pub fn PiSessionBinding::status_label(self : PiSessionBinding) -> String {
  if self.status == "unbound" {
    "unbound"
  } else {
    let name = if self.session_name != "" {
      self.session_name
    } else if self.rpc_session_id != "" {
      self.rpc_session_id
    } else if self.session_file != "" {
      self.session_file
    } else {
      "Pi session"
    }
    self.status + " · " + name
  }
}

///|
pub fn PiAgentSnapshot::new(
  phase? : String = "idle",
  turn_index? : Int = 0,
  message_role? : String = "",
  message_preview? : String = "",
  active_tool_call_id? : String = "",
  active_tool_name? : String = "",
  queued_steering? : Int = 0,
  queued_follow_up? : Int = 0,
  thinking_level? : String = "",
) -> PiAgentSnapshot {
  {
    phase,
    turn_index,
    message_role,
    message_preview,
    active_tool_call_id,
    active_tool_name,
    queued_steering,
    queued_follow_up,
    thinking_level,
  }
}

///|
pub fn PiAgentSnapshot::status_label(self : PiAgentSnapshot) -> String {
  let tool = if self.active_tool_name == "" {
    ""
  } else {
    " · tool " + self.active_tool_name
  }
  let queue = if self.queued_steering + self.queued_follow_up == 0 {
    ""
  } else {
    " · queued " + (self.queued_steering + self.queued_follow_up).to_string()
  }
  self.phase + tool + queue
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
    diff: sample_diff_overview(),
    commands: sample_commands(),
    diagnostics: sample_diagnostics(),
    transport: PiTransportState::new(),
    pi_rpc: PiRpcSnapshot::new(),
    pi_agent: PiAgentSnapshot::new(),
    pi_session_bindings: [],
    last_status: "Ready for Pi RPC",
  }
}

///|
pub fn WorkbenchModel::update(
  self : WorkbenchModel,
  message : WorkbenchMsg,
) -> WorkbenchModel {
  match message {
    SelectSession(id) => self.select_session(id)
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
    ToggleContext(id) =>
      { ..self, expanded_context: toggle_id(self.expanded_context, id) }
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
pub fn MoWorkbenchApp::runtime_with_transport(
  self : MoWorkbenchApp,
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime_with_transport(transport_runtime, width~, height~)
}

///|
pub fn runtime(
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime(width~, height~)
}

///|
pub fn runtime_with_transport(
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  WorkbenchModel::new().runtime_with_transport(
    transport_runtime,
    width~,
    height~,
  )
}

///|
pub fn WorkbenchModel::runtime(
  self : WorkbenchModel,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  self.runtime_with_transport(
    PiTransportRuntime::unavailable(),
    width~,
    height~,
  )
}

///|
pub fn WorkbenchModel::runtime_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  width? : Double = 1220.0,
  height? : Double = 780.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => {
        model.update_with_transport(message, transport_runtime).as_tuple()
      },
      view~,
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn WorkbenchUpdate::new(
  model : WorkbenchModel,
  effect? : @core.Effect[WorkbenchMsg] = @core.Effect::none(),
) -> WorkbenchUpdate {
  { model, effect }
}

///|
pub fn WorkbenchUpdate::as_tuple(
  self : WorkbenchUpdate,
) -> (WorkbenchModel, @core.Effect[WorkbenchMsg]) {
  (self.model, self.effect)
}

///|
pub fn WorkbenchModel::active_session(
  self : WorkbenchModel,
) -> WorkbenchSession {
  for session in self.sessions {
    if session.id == self.selected_session_id {
      return session
    }
  }
  self.sessions[0]
}

///|
pub fn WorkbenchModel::active_pi_session_binding(
  self : WorkbenchModel,
) -> PiSessionBinding {
  for binding in self.pi_session_bindings {
    if binding.workbench_session_id == self.selected_session_id {
      return binding
    }
  }
  PiSessionBinding::new(workbench_session_id=self.selected_session_id)
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
pub fn WorkbenchModel::update_with_transport(
  self : WorkbenchModel,
  message : WorkbenchMsg,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  match message {
    SelectSession(id) =>
      self.select_session_with_transport(id, transport_runtime)
    DispatchPrompt => self.dispatch_prompt_with_transport(transport_runtime)
    QueueCommand(command) =>
      self.queue_command_with_transport(command, transport_runtime)
    CancelRun => self.cancel_run_with_transport(transport_runtime)
    _ => WorkbenchUpdate::new(self.update(message))
  }
}

///|
fn WorkbenchModel::select_session(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  { ..self, selected_session_id: id, last_status: "Workbench session selected" }
}

///|
fn WorkbenchModel::select_session_with_transport(
  self : WorkbenchModel,
  id : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let selected = self.select_session(id)
  let session = selected.active_session()
  let commands = selected.commands_for_session_selection(session)
  WorkbenchUpdate::new(
    { ..selected, transport: selected.transport.enqueue_many(commands) },
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
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
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued prompt for Pi JSONL RPC",
    }
  }
}

///|
fn WorkbenchModel::dispatch_prompt_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Prompt is empty" })
  } else {
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.dispatch_prompt(),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::receive_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(event.to_agent_event())
  let model = {
    ..self,
    events,
    transport: self.transport.apply_event(event),
    last_status: "Pi transport event received",
  }
  match event {
    JsonLineReceived(session, line) => model.ingest_pi_jsonl(session, line)
    ProcessStderr(session, line) => model.record_transport_stderr(session, line)
    _ => model
  }
}

///|
fn WorkbenchModel::queue_command(
  self : WorkbenchModel,
  command : String,
) -> WorkbenchModel {
  let session = self.active_session()
  let commands = self.commands.copy()
  let transport_commands = self.commands_with_session_start(
    session,
    RunShellCommand(session.id, command),
  )
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
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Command queued for Pi RPC bash",
  }
}

///|
fn WorkbenchModel::queue_command_with_transport(
  self : WorkbenchModel,
  command : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    RunShellCommand(session.id, command),
  )
  WorkbenchUpdate::new(
    self.queue_command(command),
    effect=transport_runtime.effect(transport_commands, event => {
      ReceiveTransport(event)
    }),
  )
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
        status: if code == 0 {
          "passed"
        } else {
          "failed"
        },
        exit_code: Some(code),
      }
    } else {
      command
    }
  })
  { ..self, commands, last_status: "Command " + id.to_string() + " completed" }
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
    transport: self.transport.enqueue(CancelRpcRun(session.id)),
    last_status: "Cancellation queued",
  }
}

///|
fn WorkbenchModel::cancel_run_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = [CancelRpcRun(session.id)]
  WorkbenchUpdate::new(
    self.cancel_run(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::commands_for_session_selection(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  ignore(self)
  if session.pi_session_path == "" {
    [StartRpc(session.id, session.project_path)]
  } else {
    [
      SwitchRpcSession(session.id, session.pi_session_path),
      StartRpc(session.id, session.project_path),
    ]
  }
}

///|
fn WorkbenchModel::commands_with_session_start(
  self : WorkbenchModel,
  session : WorkbenchSession,
  command : PiTransportCommand,
) -> Array[PiTransportCommand] {
  let commands : Array[PiTransportCommand] = []
  if self.transport.status is Disconnected {
    commands.push(StartRpc(session.id, session.project_path))
  }
  commands.push(command)
  commands
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
    ProcessStderr(session, line) =>
      AgentEvent::new(
        phase="transport",
        title="Pi stderr: " + session,
        detail=line,
        tone="warning",
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
fn WorkbenchModel::record_transport_stderr(
  self : WorkbenchModel,
  session : String,
  line : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(
    DiagnosticItem::new(
      source="Pi stderr",
      severity="warning",
      message=session + ": " + line,
    ),
  )
  { ..self, diagnostics, last_status: "Pi stderr received" }
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
