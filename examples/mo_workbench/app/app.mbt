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
pub(all) struct TranscriptItem {
  id : String
  role : String
  summary : String
  detail : String
  tone : String
} derive(Eq, Debug)

///|
pub(all) struct PiCommandInfo {
  name : String
  source : String
  description : String
  source_scope : String
  source_path : String
} derive(Eq, Debug)

///|
pub(all) struct PiSessionStatsSnapshot {
  session_file : String
  session_id : String
  user_messages : Int
  assistant_messages : Int
  tool_calls : Int
  tool_results : Int
  total_messages : Int
  token_input : Int
  token_output : Int
  token_cache_read : Int
  token_cache_write : Int
  token_total : Int
  cost : Double
  context_tokens : Int?
  context_window : Int
  context_percent : Double?
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
  output_path : String
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
  thinking_level : String
  steering_mode : String
  follow_up_mode : String
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
  steering_mode : String
  follow_up_mode : String
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
  transcript : Array[TranscriptItem]
  command_catalog : Array[PiCommandInfo]
  pi_session_stats : PiSessionStatsSnapshot
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
  InvokeCommand(String)
  FollowTranscript(String, String, String)
  InspectFile(String)
  ReviewDiff
  RefreshSession
  ReceiveTransport(PiTransportEvent)
  QueueCommand(String)
  MarkCommandComplete(Int, Int)
  FixDiagnostic(String, String, String)
  SyncSessionName
  CycleThinkingLevel
  ToggleSteeringMode
  ToggleFollowUpMode
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
pub fn TranscriptItem::new(
  id~ : String,
  role~ : String,
  summary~ : String,
  detail~ : String,
  tone~ : String,
) -> TranscriptItem {
  { id, role, summary, detail, tone }
}

///|
pub fn PiCommandInfo::new(
  name~ : String,
  source~ : String,
  description~ : String,
  source_scope~ : String,
  source_path~ : String,
) -> PiCommandInfo {
  { name, source, description, source_scope, source_path }
}

///|
pub fn PiSessionStatsSnapshot::new(
  session_file? : String = "",
  session_id? : String = "",
  user_messages? : Int = 0,
  assistant_messages? : Int = 0,
  tool_calls? : Int = 0,
  tool_results? : Int = 0,
  total_messages? : Int = 0,
  token_input? : Int = 0,
  token_output? : Int = 0,
  token_cache_read? : Int = 0,
  token_cache_write? : Int = 0,
  token_total? : Int = 0,
  cost? : Double = 0.0,
  context_tokens? : Int? = None,
  context_window? : Int = 0,
  context_percent? : Double? = None,
) -> PiSessionStatsSnapshot {
  {
    session_file,
    session_id,
    user_messages,
    assistant_messages,
    tool_calls,
    tool_results,
    total_messages,
    token_input,
    token_output,
    token_cache_read,
    token_cache_write,
    token_total,
    cost,
    context_tokens,
    context_window,
    context_percent,
  }
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
  output_path? : String = "",
) -> CommandRun {
  { id, command, cwd, status, exit_code, tool_call_id, output_path }
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
  thinking_level? : String = "",
  steering_mode? : String = "",
  follow_up_mode? : String = "",
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
    thinking_level,
    steering_mode,
    follow_up_mode,
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
  steering_mode? : String = "one-at-a-time",
  follow_up_mode? : String = "one-at-a-time",
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
    steering_mode,
    follow_up_mode,
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
    plan: [],
    events: [],
    transcript: [],
    command_catalog: [],
    pi_session_stats: PiSessionStatsSnapshot::new(),
    files: [],
    diff: DiffOverview::new(
      changed_files=0,
      additions=0,
      deletions=0,
      status="",
    ),
    commands: [],
    diagnostics: [],
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
    InvokeCommand(name) => self.invoke_command(name)
    FollowTranscript(role, summary, detail) =>
      self.follow_transcript(role, summary, detail)
    InspectFile(path) => self.inspect_file(path)
    ReviewDiff => self.review_diff()
    RefreshSession => self.refresh_session()
    ReceiveTransport(event) => self.receive_transport(event)
    QueueCommand(command) => self.queue_command(command)
    MarkCommandComplete(id, code) => self.mark_command_complete(id, code)
    FixDiagnostic(source, severity, message) =>
      self.fix_diagnostic(source, severity, message)
    SyncSessionName => self.sync_session_name()
    CycleThinkingLevel => self.cycle_thinking_level()
    ToggleSteeringMode => self.toggle_steering_mode()
    ToggleFollowUpMode => self.toggle_follow_up_mode()
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
  let session = self.active_session()
  PiSessionBinding::new(
    workbench_session_id=self.selected_session_id,
    session_file=session.pi_session_path,
  )
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
    InvokeCommand(name) =>
      self.invoke_command_with_transport(name, transport_runtime)
    FollowTranscript(role, summary, detail) =>
      self.follow_transcript_with_transport(
        role, summary, detail, transport_runtime,
      )
    InspectFile(path) =>
      self.inspect_file_with_transport(path, transport_runtime)
    ReviewDiff => self.review_diff_with_transport(transport_runtime)
    RefreshSession => self.refresh_session_with_transport(transport_runtime)
    QueueCommand(command) =>
      self.queue_command_with_transport(command, transport_runtime)
    FixDiagnostic(source, severity, message) =>
      self.fix_diagnostic_with_transport(
        source, severity, message, transport_runtime,
      )
    SyncSessionName => self.sync_session_name_with_transport(transport_runtime)
    CycleThinkingLevel =>
      self.cycle_thinking_level_with_transport(transport_runtime)
    ToggleSteeringMode =>
      self.toggle_steering_mode_with_transport(transport_runtime)
    ToggleFollowUpMode =>
      self.toggle_follow_up_mode_with_transport(transport_runtime)
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
fn WorkbenchModel::refresh_session(self : WorkbenchModel) -> WorkbenchModel {
  let session = self.active_session()
  let commands = self.commands_for_session_selection(session)
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi session refresh queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi session refresh queued",
  }
}

///|
fn WorkbenchModel::refresh_session_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_for_session_selection(session)
  WorkbenchUpdate::new(
    self.refresh_session(),
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
fn WorkbenchModel::invoke_command(
  self : WorkbenchModel,
  name : String,
) -> WorkbenchModel {
  let command_name = name.trim().to_owned()
  if command_name == "" {
    { ..self, last_status: "Pi command is empty" }
  } else {
    let prompt = "/" + command_name
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Pi command queued",
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
      last_status: "Queued Pi command for RPC",
    }
  }
}

///|
fn WorkbenchModel::invoke_command_with_transport(
  self : WorkbenchModel,
  name : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let command_name = name.trim().to_owned()
  if command_name == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Pi command is empty" })
  } else {
    let session = self.active_session()
    let prompt = "/" + command_name
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.invoke_command(name),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::follow_transcript(
  self : WorkbenchModel,
  role : String,
  summary : String,
  detail : String,
) -> WorkbenchModel {
  let clean_summary = summary.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_summary == "" && clean_detail == "" {
    { ..self, last_status: "Transcript item is empty" }
  } else {
    let prompt = transcript_follow_up_prompt(role, summary, detail)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Transcript follow-up queued",
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
      last_status: "Queued transcript follow-up for Pi RPC",
    }
  }
}

///|
fn WorkbenchModel::follow_transcript_with_transport(
  self : WorkbenchModel,
  role : String,
  summary : String,
  detail : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_summary = summary.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_summary == "" && clean_detail == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Transcript item is empty" })
  } else {
    let prompt = transcript_follow_up_prompt(role, summary, detail)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.follow_transcript(role, summary, detail),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn transcript_follow_up_prompt(
  role : String,
  summary : String,
  detail : String,
) -> String {
  let role = role.trim().to_owned()
  let summary = summary.trim().to_owned()
  let detail = detail.trim().to_owned()
  let label = if role == "" { "message" } else { role + " transcript" }
  let body = if summary == "" {
    detail
  } else if detail == "" {
    summary
  } else {
    summary + ". Context: " + detail
  }
  "Follow up on " + label + ": " + body
}

///|
fn WorkbenchModel::inspect_file(
  self : WorkbenchModel,
  path : String,
) -> WorkbenchModel {
  let file_path = path.trim().to_owned()
  if file_path == "" {
    { ..self, last_status: "File context is empty" }
  } else {
    let prompt = "Inspect " + file_path
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="File context queued",
        detail=file_path,
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
      last_status: "Queued file context for Pi RPC",
    }
  }
}

///|
fn WorkbenchModel::inspect_file_with_transport(
  self : WorkbenchModel,
  path : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let file_path = path.trim().to_owned()
  if file_path == "" {
    WorkbenchUpdate::new({ ..self, last_status: "File context is empty" })
  } else {
    let session = self.active_session()
    let prompt = "Inspect " + file_path
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.inspect_file(path),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::review_diff(self : WorkbenchModel) -> WorkbenchModel {
  if self.diff.has_context() {
    let prompt = self.diff_review_prompt()
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Diff review queued",
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
      last_status: "Queued diff review for Pi RPC",
    }
  } else {
    { ..self, last_status: "Diff context is empty" }
  }
}

///|
fn WorkbenchModel::review_diff_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  if self.diff.has_context() {
    let session = self.active_session()
    let prompt = self.diff_review_prompt()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.review_diff(),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  } else {
    WorkbenchUpdate::new({ ..self, last_status: "Diff context is empty" })
  }
}

///|
fn WorkbenchModel::diff_review_prompt(self : WorkbenchModel) -> String {
  "Review diff: " +
  self.diff.status_label() +
  ", " +
  self.diff.changed_files.to_string() +
  " files, +" +
  self.diff.additions.to_string() +
  " -" +
  self.diff.deletions.to_string()
}

///|
fn DiffOverview::has_context(self : DiffOverview) -> Bool {
  self.changed_files > 0 ||
  self.additions > 0 ||
  self.deletions > 0 ||
  self.status.trim().to_owned() != ""
}

///|
fn DiffOverview::status_label(self : DiffOverview) -> String {
  let status = self.status.trim().to_owned()
  if status == "" {
    "changed"
  } else {
    status
  }
}

///|
fn WorkbenchModel::fix_diagnostic(
  self : WorkbenchModel,
  source : String,
  severity : String,
  message : String,
) -> WorkbenchModel {
  let clean_source = source.trim().to_owned()
  let clean_message = message.trim().to_owned()
  if clean_source == "" && clean_message == "" {
    { ..self, last_status: "Diagnostic is empty" }
  } else {
    let prompt = diagnostic_fix_prompt(source, severity, message)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Diagnostic fix queued",
        detail=prompt,
        tone="warning",
      ),
    )
    let command = SendUserInput(session.id, prompt)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued diagnostic fix for Pi RPC",
    }
  }
}

///|
fn WorkbenchModel::fix_diagnostic_with_transport(
  self : WorkbenchModel,
  source : String,
  severity : String,
  message : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_source = source.trim().to_owned()
  let clean_message = message.trim().to_owned()
  if clean_source == "" && clean_message == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Diagnostic is empty" })
  } else {
    let prompt = diagnostic_fix_prompt(source, severity, message)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.fix_diagnostic(source, severity, message),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn diagnostic_fix_prompt(
  source : String,
  severity : String,
  message : String,
) -> String {
  let source = source.trim().to_owned()
  let severity = severity.trim().to_owned()
  let message = message.trim().to_owned()
  let label = if severity == "" {
    "diagnostic"
  } else {
    severity + " diagnostic"
  }
  let origin = if source == "" { "" } else { " from " + source }
  let detail = if message == "" { "" } else { ": " + message }
  "Fix " + label + origin + detail
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
fn WorkbenchModel::sync_session_name(self : WorkbenchModel) -> WorkbenchModel {
  let session = self.active_session()
  let name = session.title
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcSessionName(session.id, name),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi session name sync queued",
      detail=session.id + ": " + name,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi session name sync queued",
  }
}

///|
fn WorkbenchModel::sync_session_name_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    SetRpcSessionName(session.id, session.title),
  )
  WorkbenchUpdate::new(
    self.sync_session_name(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::cycle_thinking_level(
  self : WorkbenchModel,
) -> WorkbenchModel {
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CycleRpcThinkingLevel(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi thinking level cycle queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi thinking level cycle queued",
  }
}

///|
fn WorkbenchModel::cycle_thinking_level_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    CycleRpcThinkingLevel(session.id),
  )
  WorkbenchUpdate::new(
    self.cycle_thinking_level(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::toggle_steering_mode(
  self : WorkbenchModel,
) -> WorkbenchModel {
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.steering_mode)
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcSteeringMode(session.id, mode),
  )
  self
  .record_agent_mode_event(
    title="Pi steering mode queued",
    detail=mode,
    status="Pi steering mode queued",
  )
  .set_agent_modes(steering_mode=Some(mode), follow_up_mode=None)
  .enqueue_transport_commands(transport_commands)
}

///|
fn WorkbenchModel::toggle_steering_mode_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.steering_mode)
  let commands = self.commands_with_session_start(
    session,
    SetRpcSteeringMode(session.id, mode),
  )
  WorkbenchUpdate::new(
    self.toggle_steering_mode(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::toggle_follow_up_mode(
  self : WorkbenchModel,
) -> WorkbenchModel {
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.follow_up_mode)
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcFollowUpMode(session.id, mode),
  )
  self
  .record_agent_mode_event(
    title="Pi follow-up mode queued",
    detail=mode,
    status="Pi follow-up mode queued",
  )
  .set_agent_modes(steering_mode=None, follow_up_mode=Some(mode))
  .enqueue_transport_commands(transport_commands)
}

///|
fn WorkbenchModel::toggle_follow_up_mode_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.follow_up_mode)
  let commands = self.commands_with_session_start(
    session,
    SetRpcFollowUpMode(session.id, mode),
  )
  WorkbenchUpdate::new(
    self.toggle_follow_up_mode(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::record_agent_mode_event(
  self : WorkbenchModel,
  title~ : String,
  detail~ : String,
  status~ : String,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(AgentEvent::new(phase="control", title~, detail~, tone="info"))
  { ..self, events, last_status: status }
}

///|
fn WorkbenchModel::set_agent_modes(
  self : WorkbenchModel,
  steering_mode~ : String?,
  follow_up_mode~ : String?,
) -> WorkbenchModel {
  {
    ..self,
    pi_agent: {
      ..self.pi_agent,
      steering_mode: steering_mode.unwrap_or(self.pi_agent.steering_mode),
      follow_up_mode: follow_up_mode.unwrap_or(self.pi_agent.follow_up_mode),
    },
  }
}

///|
fn WorkbenchModel::enqueue_transport_commands(
  self : WorkbenchModel,
  commands : Array[PiTransportCommand],
) -> WorkbenchModel {
  { ..self, transport: self.transport.enqueue_many(commands) }
}

///|
fn next_agent_input_mode(mode : String) -> String {
  if mode == "all" {
    "one-at-a-time"
  } else {
    "all"
  }
}

///|
fn WorkbenchModel::cancel_run(self : WorkbenchModel) -> WorkbenchModel {
  let session = self.active_session()
  let transport_command = self.cancel_transport_command(session)
  let shell_cancel = transport_command is CancelShellCommand(_)
  let model = if shell_cancel {
    self.mark_latest_shell_command_cancelling(session)
  } else {
    self
  }
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title=if shell_cancel {
        "Shell command cancellation requested"
      } else {
        "Run cancellation requested"
      },
      detail=session.title,
      tone="warning",
    ),
  )
  {
    ..model,
    events,
    transport: model.transport.enqueue(transport_command),
    last_status: if shell_cancel {
      "Shell command cancellation queued"
    } else {
      "Cancellation queued"
    },
  }
}

///|
fn WorkbenchModel::cancel_run_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = [self.cancel_transport_command(session)]
  WorkbenchUpdate::new(
    self.cancel_run(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::cancel_transport_command(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> PiTransportCommand {
  if self.has_active_shell_command(session) {
    CancelShellCommand(session.id)
  } else {
    CancelRpcRun(session.id)
  }
}

///|
fn WorkbenchModel::has_active_shell_command(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Bool {
  self.commands.any(command => command.is_active_shell_for_session(session))
}

///|
fn WorkbenchModel::mark_latest_shell_command_cancelling(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> WorkbenchModel {
  let mut target_id : Int? = None
  for command in self.commands {
    if command.is_active_shell_for_session(session) {
      target_id = Some(command.id)
    }
  }
  match target_id {
    Some(id) => {
      let commands = self.commands.map(command => {
        if command.id == id {
          { ..command, status: "cancelling" }
        } else {
          command
        }
      })
      { ..self, commands, }
    }
    None => self
  }
}

///|
fn CommandRun::is_active_shell_for_session(
  self : CommandRun,
  session : WorkbenchSession,
) -> Bool {
  self.cwd == session.project_path &&
  self.tool_call_id == "" &&
  shell_command_status_is_active(self.status)
}

///|
fn shell_command_status_is_active(status : String) -> Bool {
  status == "queued" || status == "running" || status == "cancelling"
}

///|
fn WorkbenchModel::commands_for_session_selection(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  ignore(self)
  if session.pi_session_path == "" {
    [
      StartRpc(session.id, session.project_path),
      FetchRpcMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
    ]
  } else {
    [
      SwitchRpcSession(session.id, session.pi_session_path),
      StartRpc(session.id, session.project_path),
      FetchRpcMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
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
