///|
pub struct MoWorkbenchApp {
  unit : Unit
}

///|
pub(all) struct WorkbenchSession {
  id : String
  title : String
  project_path : String
  backend_id : String
  pi_session_path : String
  branch : String
  status : String
  summary : String
  active_task : String
  unread_events : Int
} derive(Eq, Debug)

///|
pub(all) struct AgentBackendCapabilities {
  uses_pi_transport : Bool
  supports_session_refresh : Bool
  supports_new_session : Bool
  supports_model_catalog : Bool
  supports_command_catalog : Bool
  supports_fork : Bool
  supports_html_export : Bool
  supports_context_compaction : Bool
  supports_thinking_level : Bool
  supports_input_modes : Bool
  supports_shell_commands : Bool
  supports_session_stats : Bool
} derive(Eq, Debug)

///|
pub(all) struct AgentBackendProfile {
  id : String
  label : String
  description : String
  capabilities : AgentBackendCapabilities
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
pub(all) struct PiModelInfo {
  provider : String
  id : String
  name : String
  label : String
} derive(Eq, Debug)

///|
pub(all) struct PiForkMessage {
  entry_id : String
  text : String
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
  output : String
  output_truncated : Bool
  details_expanded : Bool
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
priv struct WorkbenchAgentProfile {
  id : String
  label : String
  prompt_hint : String
}

///|
priv struct WorkbenchCheckPreset {
  label : String
  command : String
}

///|
pub(all) struct WorkbenchModel {
  selected_session_id : String
  selected_panel : String
  selected_agent_id : String
  main_scroll_offset_y : Double
  prompt : String
  composer_controls_expanded : Bool
  expanded_context : Array[String]
  workspace_details_expanded : Bool
  sessions : Array[WorkbenchSession]
  plan : Array[PlanStep]
  events : Array[AgentEvent]
  transcript : Array[TranscriptItem]
  command_catalog : Array[PiCommandInfo]
  model_catalog : Array[PiModelInfo]
  fork_messages : Array[PiForkMessage]
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
  SwitchAgentBackend(String)
  SelectAgent(String)
  PromptChanged(String)
  ToggleComposerControls
  DispatchPrompt
  DispatchSteering
  DispatchFollowUp
  InvokeCommand(String)
  FollowTranscript(String, String, String)
  FollowActivity(String, String, String)
  InspectFile(String)
  ReviewDiff
  RefreshSession
  ReceiveTransport(PiTransportEvent)
  NewSession
  RefreshForkMessages
  ForkFromMessage(String)
  ExportSessionHtml
  QueueCommand(String)
  QueueFocusedChecks
  ToggleCommandDetails(Int)
  ToggleWorkspaceDetails
  InspectCommandRun(String, String, String, String)
  FixCommandRun(String, String, String, String)
  MarkCommandComplete(Int, Int)
  FixDiagnostic(String, String, String)
  SyncSessionName
  SetModel(String, String, String)
  CycleModel
  CompactSession
  CycleThinkingLevel
  ToggleSteeringMode
  ToggleFollowUpMode
  CancelRun
  ClearDiagnostics
  ToggleContext(String)
  MainScrollTo(Double)
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
  backend_id? : String = "pi",
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
    backend_id,
    pi_session_path,
    branch,
    status,
    summary,
    active_task,
    unread_events,
  }
}

///|
pub fn AgentBackendCapabilities::new(
  uses_pi_transport? : Bool = false,
  supports_session_refresh? : Bool = false,
  supports_new_session? : Bool = false,
  supports_model_catalog? : Bool = false,
  supports_command_catalog? : Bool = false,
  supports_fork? : Bool = false,
  supports_html_export? : Bool = false,
  supports_context_compaction? : Bool = false,
  supports_thinking_level? : Bool = false,
  supports_input_modes? : Bool = false,
  supports_shell_commands? : Bool = false,
  supports_session_stats? : Bool = false,
) -> AgentBackendCapabilities {
  {
    uses_pi_transport,
    supports_session_refresh,
    supports_new_session,
    supports_model_catalog,
    supports_command_catalog,
    supports_fork,
    supports_html_export,
    supports_context_compaction,
    supports_thinking_level,
    supports_input_modes,
    supports_shell_commands,
    supports_session_stats,
  }
}

///|
pub fn AgentBackendProfile::new(
  id~ : String,
  label~ : String,
  description~ : String,
  capabilities~ : AgentBackendCapabilities,
) -> AgentBackendProfile {
  { id, label, description, capabilities }
}

///|
pub fn agent_backend_profiles() -> Array[AgentBackendProfile] {
  [
    AgentBackendProfile::new(
      id="pi",
      label="Pi",
      description="真实后端",
      capabilities=AgentBackendCapabilities::new(
        uses_pi_transport=true,
        supports_session_refresh=true,
        supports_new_session=true,
        supports_model_catalog=true,
        supports_command_catalog=true,
        supports_fork=true,
        supports_html_export=true,
        supports_context_compaction=true,
        supports_thinking_level=true,
        supports_input_modes=true,
        supports_shell_commands=true,
        supports_session_stats=true,
      ),
    ),
    AgentBackendProfile::new(
      id="fixture",
      label="本地",
      description="本地演练",
      capabilities=AgentBackendCapabilities::new(),
    ),
  ]
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
pub fn PiModelInfo::new(
  provider~ : String,
  id~ : String,
  name? : String = "",
  label? : String = "",
) -> PiModelInfo {
  let label = if label == "" {
    pi_model_label(provider, id, name)
  } else {
    label
  }
  { provider, id, name, label }
}

///|
pub fn PiForkMessage::new(entry_id~ : String, text~ : String) -> PiForkMessage {
  { entry_id, text }
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
  output? : String = "",
  output_truncated? : Bool = false,
  details_expanded? : Bool = false,
) -> CommandRun {
  {
    id,
    command,
    cwd,
    status,
    exit_code,
    tool_call_id,
    output_path,
    output,
    output_truncated,
    details_expanded,
  }
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
fn WorkbenchAgentProfile::new(
  id~ : String,
  label~ : String,
  prompt_hint~ : String,
) -> WorkbenchAgentProfile {
  { id, label, prompt_hint }
}

///|
fn WorkbenchCheckPreset::new(
  label~ : String,
  command~ : String,
) -> WorkbenchCheckPreset {
  { label, command }
}

///|
fn workbench_check_presets() -> Array[WorkbenchCheckPreset] {
  [
    WorkbenchCheckPreset::new(
      label="Native",
      command="moon test examples/mo_workbench/app --target native",
    ),
    WorkbenchCheckPreset::new(
      label="Wasm",
      command="moon test examples/mo_workbench/app --target wasm-gc",
    ),
    WorkbenchCheckPreset::new(
      label="构建",
      command="moon build examples/mo_workbench/macos_skia --target native",
    ),
    WorkbenchCheckPreset::new(
      label="首帧",
      command="MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native",
    ),
  ]
}

///|
fn workbench_agent_profiles() -> Array[WorkbenchAgentProfile] {
  [
    WorkbenchAgentProfile::new(
      id="general",
      label="通用",
      prompt_hint="general task planning and coordination",
    ),
    WorkbenchAgentProfile::new(
      id="coding",
      label="编码",
      prompt_hint="coding implementation, focused tests, and refactors",
    ),
    WorkbenchAgentProfile::new(
      id="verify",
      label="校验",
      prompt_hint="verification, diagnostics, docs, and handoff",
    ),
  ]
}

///|
fn WorkbenchModel::active_agent_profile(
  self : WorkbenchModel,
) -> WorkbenchAgentProfile? {
  for profile in workbench_agent_profiles() {
    if profile.id == self.selected_agent_id {
      return Some(profile)
    }
  }
  None
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
    selected_agent_id: "",
    main_scroll_offset_y: 0.0,
    prompt: "",
    composer_controls_expanded: false,
    expanded_context: ["repo", "examples"],
    workspace_details_expanded: false,
    sessions: sample_sessions(),
    plan: [],
    events: [],
    transcript: [],
    command_catalog: [],
    model_catalog: [],
    fork_messages: [],
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
    last_status: "Ready for agent backend",
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
    SwitchAgentBackend(id) => self.switch_backend(id)
    SelectAgent(id) => self.select_agent(id)
    PromptChanged(value) => { ..self, prompt: value }
    ToggleComposerControls =>
      { ..self, composer_controls_expanded: !self.composer_controls_expanded }
    DispatchPrompt => self.dispatch_prompt()
    DispatchSteering => self.dispatch_steering()
    DispatchFollowUp => self.dispatch_follow_up()
    InvokeCommand(name) => self.invoke_command(name)
    FollowTranscript(role, summary, detail) =>
      self.follow_transcript(role, summary, detail)
    FollowActivity(phase, title, detail) =>
      self.follow_activity(phase, title, detail)
    InspectFile(path) => self.inspect_file(path)
    ReviewDiff => self.review_diff()
    RefreshSession => self.refresh_session()
    ReceiveTransport(event) => self.receive_transport(event)
    NewSession => self.new_session()
    RefreshForkMessages => self.refresh_fork_messages()
    ForkFromMessage(entry_id) => self.fork_from_message(entry_id)
    ExportSessionHtml => self.export_session_html()
    QueueCommand(command) => self.queue_command(command)
    QueueFocusedChecks => self.queue_focused_checks()
    ToggleCommandDetails(id) => self.toggle_command_details(id)
    ToggleWorkspaceDetails => self.toggle_workspace_details()
    InspectCommandRun(command, status, cwd, output_path) =>
      self.inspect_command_run(command, status, cwd, output_path)
    FixCommandRun(command, status, cwd, output_path) =>
      self.fix_command_run(command, status, cwd, output_path)
    MarkCommandComplete(id, code) => self.mark_command_complete(id, code)
    FixDiagnostic(source, severity, message) =>
      self.fix_diagnostic(source, severity, message)
    SyncSessionName => self.sync_session_name()
    SetModel(provider, id, label) => self.set_model(provider, id, label)
    CycleModel => self.cycle_model()
    CompactSession => self.compact_session()
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
    MainScrollTo(offset_y) => self.scroll_main_to(offset_y)
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
    program=@core.Program::new_with_environment(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => {
        model.update_with_transport(message, transport_runtime).as_tuple()
      },
      view=(model, env) => model.view_with_environment(env),
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
pub fn WorkbenchModel::active_agent_backend_profile(
  self : WorkbenchModel,
) -> AgentBackendProfile {
  let id = self.active_session().backend_id
  for profile in agent_backend_profiles() {
    if profile.id == id {
      return profile
    }
  }
  agent_backend_profiles()[0]
}

///|
pub fn WorkbenchModel::active_agent_backend_capabilities(
  self : WorkbenchModel,
) -> AgentBackendCapabilities {
  self.active_agent_backend_profile().capabilities
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
    DispatchSteering => self.dispatch_steering_with_transport(transport_runtime)
    DispatchFollowUp =>
      self.dispatch_follow_up_with_transport(transport_runtime)
    InvokeCommand(name) =>
      self.invoke_command_with_transport(name, transport_runtime)
    FollowTranscript(role, summary, detail) =>
      self.follow_transcript_with_transport(
        role, summary, detail, transport_runtime,
      )
    FollowActivity(phase, title, detail) =>
      self.follow_activity_with_transport(
        phase, title, detail, transport_runtime,
      )
    InspectFile(path) =>
      self.inspect_file_with_transport(path, transport_runtime)
    ReviewDiff => self.review_diff_with_transport(transport_runtime)
    RefreshSession => self.refresh_session_with_transport(transport_runtime)
    ReceiveTransport(event) =>
      self.receive_transport_with_transport(event, transport_runtime)
    NewSession => self.new_session_with_transport(transport_runtime)
    RefreshForkMessages =>
      self.refresh_fork_messages_with_transport(transport_runtime)
    ForkFromMessage(entry_id) =>
      self.fork_from_message_with_transport(entry_id, transport_runtime)
    ExportSessionHtml =>
      self.export_session_html_with_transport(transport_runtime)
    QueueCommand(command) =>
      self.queue_command_with_transport(command, transport_runtime)
    QueueFocusedChecks =>
      self.queue_focused_checks_with_transport(transport_runtime)
    InspectCommandRun(command, status, cwd, output_path) =>
      self.inspect_command_run_with_transport(
        command, status, cwd, output_path, transport_runtime,
      )
    FixCommandRun(command, status, cwd, output_path) =>
      self.fix_command_run_with_transport(
        command, status, cwd, output_path, transport_runtime,
      )
    FixDiagnostic(source, severity, message) =>
      self.fix_diagnostic_with_transport(
        source, severity, message, transport_runtime,
      )
    SyncSessionName => self.sync_session_name_with_transport(transport_runtime)
    SetModel(provider, id, label) =>
      self.set_model_with_transport(provider, id, label, transport_runtime)
    CycleModel => self.cycle_model_with_transport(transport_runtime)
    CompactSession => self.compact_session_with_transport(transport_runtime)
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
  {
    ..self,
    selected_session_id: id,
    main_scroll_offset_y: 0.0,
    last_status: "Workbench session selected",
  }.reset_active_session_surface()
}

///|
fn WorkbenchModel::reset_active_session_surface(
  self : WorkbenchModel,
) -> WorkbenchModel {
  {
    ..self,
    prompt: "",
    composer_controls_expanded: false,
    workspace_details_expanded: false,
    plan: [],
    events: [],
    transcript: [],
    command_catalog: [],
    model_catalog: [],
    fork_messages: [],
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
  }
}

///|
fn WorkbenchModel::switch_backend(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  let backend_id = id.trim().to_owned()
  let mut profile : AgentBackendProfile? = None
  for candidate in agent_backend_profiles() {
    if candidate.id == backend_id {
      profile = Some(candidate)
    }
  }
  match profile {
    None => { ..self, last_status: "Agent backend unavailable" }
    Some(value) => {
      let current = self.active_session()
      if current.backend_id == value.id {
        {
          ..self,
          last_status: "Agent backend already selected: " + value.label,
        }
      } else {
        let sessions = self.sessions.map(session => {
          if session.id == self.selected_session_id {
            {
              ..session,
              backend_id: value.id,
              status: "active",
              active_task: "",
              unread_events: 0,
            }
          } else {
            session
          }
        })
        let events : Array[AgentEvent] = []
        events.push(
          AgentEvent::new(
            phase="control",
            title="Agent backend switched",
            detail=value.label,
            tone="info",
          ),
        )
        {
          ..self.reset_active_session_surface(),
          sessions,
          events,
          main_scroll_offset_y: 0.0,
          last_status: "Agent backend switched: " + value.label,
        }
      }
    }
  }
}

///|
fn WorkbenchModel::select_agent(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  let clean_id = id.trim().to_owned()
  if clean_id == "" || clean_id == self.selected_agent_id {
    { ..self, selected_agent_id: "", last_status: "Agent focus cleared" }
  } else {
    for profile in workbench_agent_profiles() {
      if profile.id == clean_id {
        return {
          ..self,
          selected_agent_id: clean_id,
          last_status: "Agent focus selected: " + profile.label,
        }
      }
    }
    { ..self, last_status: "Agent focus unavailable" }
  }
}

///|
fn WorkbenchModel::scroll_main_to(
  self : WorkbenchModel,
  offset_y : Double,
) -> WorkbenchModel {
  { ..self, main_scroll_offset_y: workbench_max_double(0.0, offset_y) }
}

///|
fn WorkbenchModel::toggle_command_details(
  self : WorkbenchModel,
  id : Int,
) -> WorkbenchModel {
  let commands = self.commands.map(command => {
    if command.id == id {
      { ..command, details_expanded: !command.details_expanded }
    } else {
      command
    }
  })
  { ..self, commands, last_status: "Command details toggled" }
}

///|
fn WorkbenchModel::toggle_workspace_details(
  self : WorkbenchModel,
) -> WorkbenchModel {
  {
    ..self,
    workspace_details_expanded: !self.workspace_details_expanded,
    last_status: "Workspace evidence details toggled",
  }
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
  if !self.active_agent_backend_capabilities().supports_session_refresh {
    return { ..self, last_status: "Agent backend does not support refresh" }
  }
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
fn WorkbenchModel::new_session(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_new_session {
    return {
      ..self,
      last_status: "Agent backend does not support new sessions",
    }
  }
  let session = self.active_session()
  let commands = self.commands_for_new_session(session)
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi new session queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi new session queued",
  }
}

///|
fn WorkbenchModel::new_session_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_for_new_session(session)
  WorkbenchUpdate::new(
    self.new_session(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::refresh_fork_messages(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_fork {
    return { ..self, last_status: "Agent backend does not support forks" }
  }
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    FetchRpcForkMessages(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi fork discovery queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi fork discovery queued",
  }
}

///|
fn WorkbenchModel::refresh_fork_messages_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    FetchRpcForkMessages(session.id),
  )
  WorkbenchUpdate::new(
    self.refresh_fork_messages(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::fork_from_message(
  self : WorkbenchModel,
  entry_id : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_fork {
    return { ..self, last_status: "Agent backend does not support forks" }
  }
  let clean_entry_id = entry_id.trim().to_owned()
  if clean_entry_id == "" {
    { ..self, last_status: "Fork entry id is empty" }
  } else {
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      ForkRpcSession(session.id, clean_entry_id),
    )
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Pi fork queued",
        detail=session.title + ": " + clean_entry_id,
        tone="info",
      ),
    )
    {
      ..self,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Pi fork queued",
    }
  }
}

///|
fn WorkbenchModel::fork_from_message_with_transport(
  self : WorkbenchModel,
  entry_id : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_entry_id = entry_id.trim().to_owned()
  if clean_entry_id == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Fork entry id is empty" })
  } else {
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      ForkRpcSession(session.id, clean_entry_id),
    )
    WorkbenchUpdate::new(
      self.fork_from_message(entry_id),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::export_session_html(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_html_export {
    return { ..self, last_status: "Agent backend does not support HTML export" }
  }
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    ExportRpcSessionHtml(session.id, ""),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi HTML export queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi HTML export queued",
  }
}

///|
fn WorkbenchModel::export_session_html_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    ExportRpcSessionHtml(session.id, ""),
  )
  WorkbenchUpdate::new(
    self.export_session_html(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::receive_transport_with_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return WorkbenchUpdate::new(self)
  }
  let model = self.receive_transport(event)
  match event.session_replacement_refresh() {
    Some((session_id, title, status)) => {
      let session = model.session_for_id(session_id)
      let commands = if status == "Pi transcript refresh queued" {
        model.commands_for_conversation_refresh(session)
      } else {
        model.commands_for_session_replacement_refresh(session)
      }
      let events = model.events.copy()
      events.push(
        AgentEvent::new(
          phase="control",
          title~,
          detail=session.title,
          tone="info",
        ),
      )
      WorkbenchUpdate::new(
        {
          ..model,
          events,
          transport: model.transport.enqueue_many(commands),
          last_status: status,
        },
        effect=transport_runtime.effect(commands, event => {
          ReceiveTransport(event)
        }),
      )
    }
    None => WorkbenchUpdate::new(model)
  }
}

///|
fn WorkbenchModel::dispatch_prompt(self : WorkbenchModel) -> WorkbenchModel {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.dispatch_prompt_payload(prompt)
    let session = self.active_session()
    let backend = self.active_agent_backend_profile()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="User request queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendUserInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    let transcript = if backend.capabilities.uses_pi_transport {
      self.transcript_with_local_user_message(payload)
    } else {
      self.transcript_with_fixture_reply(payload, backend)
    }
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      workspace_details_expanded: false,
      events,
      transcript,
      transport: self.transport.enqueue_many(commands),
      last_status: if backend.capabilities.uses_pi_transport {
        "Queued prompt for Pi JSONL RPC"
      } else {
        local_agent_prompt_status(backend)
      },
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
    let payload = self.dispatch_prompt_payload(prompt)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, payload),
    )
    WorkbenchUpdate::new(
      self.dispatch_prompt(),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::dispatch_steering(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Steering input queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendSteeringInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued steering input for Pi RPC",
    }
  }
}

///|
fn WorkbenchModel::dispatch_steering_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Prompt is empty" })
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendSteeringInput(session.id, payload),
    )
    WorkbenchUpdate::new(
      self.dispatch_steering(),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::dispatch_follow_up(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Follow-up input queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendFollowUpInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued follow-up input for Pi RPC",
    }
  }
}

///|
fn WorkbenchModel::dispatch_follow_up_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Prompt is empty" })
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendFollowUpInput(session.id, payload),
    )
    WorkbenchUpdate::new(
      self.dispatch_follow_up(),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::composer_prompt_payload(
  self : WorkbenchModel,
  prompt : String,
) -> String {
  let context = self.composer_context_prompt_label()
  if context == "" {
    prompt
  } else {
    "Context: " + context + "\n\nTask: " + prompt
  }
}

///|
fn WorkbenchModel::transcript_with_local_user_message(
  self : WorkbenchModel,
  payload : String,
) -> Array[TranscriptItem] {
  let transcript = self.transcript.copy()
  transcript.push(
    TranscriptItem::new(
      id="local-user-" + (transcript.length() + 1).to_string(),
      role="user",
      summary=payload,
      detail=payload,
      tone="info",
    ),
  )
  transcript
}

///|
fn WorkbenchModel::transcript_with_fixture_reply(
  self : WorkbenchModel,
  payload : String,
  backend : AgentBackendProfile,
) -> Array[TranscriptItem] {
  let transcript = self.transcript_with_local_user_message(payload)
  transcript.push(
    TranscriptItem::new(
      id="fixture-agent-" + transcript.length().to_string(),
      role="assistant",
      summary=backend.label + " 已接收任务",
      detail="本地后端会保持会话流转，不启动外部传输。",
      tone="success",
    ),
  )
  transcript
}

///|
fn WorkbenchModel::dispatch_prompt_payload(
  self : WorkbenchModel,
  prompt : String,
) -> String {
  if is_slash_prompt(prompt) {
    prompt
  } else {
    self.composer_prompt_payload(prompt)
  }
}

///|
fn is_slash_prompt(prompt : String) -> Bool {
  let clean = prompt.trim().to_owned()
  let chars = clean.to_array()
  chars.length() > 0 && chars[0] == '/'
}

///|
fn WorkbenchModel::composer_context_prompt_label(
  self : WorkbenchModel,
) -> String {
  let labels : Array[String] = []
  for id in ["repo", "examples", "evidence", "session"] {
    if self.context_is_selected(id) {
      labels.push(context_prompt_label(id))
    }
  }
  for id in self.expanded_context {
    if !known_context_id(id) {
      labels.push(id)
    }
  }
  match self.active_agent_profile() {
    Some(profile) => labels.push("agent focus: " + profile.prompt_hint)
    None => ()
  }
  labels.join(", ")
}

///|
fn WorkbenchModel::context_is_selected(
  self : WorkbenchModel,
  id : String,
) -> Bool {
  self.expanded_context.any(value => value == id)
}

///|
fn context_prompt_label(id : String) -> String {
  match id {
    "repo" => "repo"
    "examples" => "examples"
    "evidence" => "current evidence"
    "session" => "agent session"
    _ => id
  }
}

///|
fn known_context_id(id : String) -> Bool {
  id == "repo" || id == "examples" || id == "evidence" || id == "session"
}

///|
fn WorkbenchModel::invoke_command(
  self : WorkbenchModel,
  name : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_command_catalog {
    return { ..self, last_status: "Agent backend does not support commands" }
  }
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
fn WorkbenchModel::queue_agent_prompt_action(
  self : WorkbenchModel,
  payload : String,
  event_title~ : String,
  event_detail~ : String,
  tone~ : String,
  pi_status~ : String,
) -> WorkbenchModel {
  let backend = self.active_agent_backend_profile()
  let session = self.active_session()
  let events = self.events.copy()
  events.push(
    AgentEvent::new(phase="user", title=event_title, detail=event_detail, tone~),
  )
  if backend.capabilities.uses_pi_transport {
    let command = SendUserInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: pi_status,
    }
  } else {
    {
      ..self,
      prompt: "",
      events,
      transcript: self.transcript_with_fixture_reply(payload, backend),
      last_status: local_agent_prompt_status(backend),
    }
  }
}

///|
fn local_agent_prompt_status(backend : AgentBackendProfile) -> String {
  "已交给" + backend.label + "后端"
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
    self.queue_agent_prompt_action(
      prompt,
      event_title="Transcript follow-up queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued transcript follow-up for Pi RPC",
    )
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
fn WorkbenchModel::follow_activity(
  self : WorkbenchModel,
  phase : String,
  title : String,
  detail : String,
) -> WorkbenchModel {
  let clean_title = title.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_title == "" && clean_detail == "" {
    { ..self, last_status: "Activity item is empty" }
  } else {
    let prompt = activity_follow_up_prompt(phase, title, detail)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Activity follow-up queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued activity follow-up for Pi RPC",
    )
  }
}

///|
fn WorkbenchModel::follow_activity_with_transport(
  self : WorkbenchModel,
  phase : String,
  title : String,
  detail : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_title = title.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_title == "" && clean_detail == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Activity item is empty" })
  } else {
    let prompt = activity_follow_up_prompt(phase, title, detail)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.follow_activity(phase, title, detail),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn activity_follow_up_prompt(
  phase : String,
  title : String,
  detail : String,
) -> String {
  let phase = phase.trim().to_owned()
  let title = title.trim().to_owned()
  let detail = detail.trim().to_owned()
  let label = if phase == "" { "activity" } else { phase + " activity" }
  let body = if title == "" {
    detail
  } else if detail == "" {
    title
  } else {
    title + ". Context: " + detail
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
    let prompt = self.file_inspection_payload(file_path)
    self.queue_agent_prompt_action(
      prompt,
      event_title="File context queued",
      event_detail=file_path,
      tone="info",
      pi_status="Queued file context for Pi RPC",
    )
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
    let prompt = self.file_inspection_payload(file_path)
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
    let prompt = self.diff_review_payload()
    self.queue_agent_prompt_action(
      prompt,
      event_title="Diff review queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued diff review for Pi RPC",
    )
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
    let prompt = self.diff_review_payload()
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
fn WorkbenchModel::file_inspection_payload(
  self : WorkbenchModel,
  file_path : String,
) -> String {
  self.composer_prompt_payload("Inspect " + file_path)
}

///|
fn WorkbenchModel::diff_review_payload(self : WorkbenchModel) -> String {
  self.composer_prompt_payload(self.diff_review_prompt())
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
    let prompt = self.diagnostic_fix_payload(source, severity, message)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Diagnostic fix queued",
      event_detail=prompt,
      tone="warning",
      pi_status="Queued diagnostic fix for Pi RPC",
    )
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
    let prompt = self.diagnostic_fix_payload(source, severity, message)
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
fn WorkbenchModel::diagnostic_fix_payload(
  self : WorkbenchModel,
  source : String,
  severity : String,
  message : String,
) -> String {
  self.composer_prompt_payload(diagnostic_fix_prompt(source, severity, message))
}

///|
fn WorkbenchModel::receive_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return self
  }
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
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return {
      ..self,
      last_status: "Agent backend does not support shell commands",
    }
  }
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
fn WorkbenchModel::queue_focused_checks(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return {
      ..self,
      last_status: "Agent backend does not support shell commands",
    }
  }
  let session = self.active_session()
  let commands = self.commands.copy()
  for preset in workbench_check_presets() {
    commands.push(
      CommandRun::new(
        id=commands.length() + 1,
        command=preset.command,
        cwd=session.project_path,
        status="queued",
      ),
    )
  }
  let transport_commands = self.commands_for_focused_checks(session)
  {
    ..self,
    commands,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Focused checks queued for Pi RPC bash",
  }
}

///|
fn WorkbenchModel::queue_focused_checks_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let transport_commands = self.commands_for_focused_checks(session)
  WorkbenchUpdate::new(
    self.queue_focused_checks(),
    effect=transport_runtime.effect(transport_commands, event => {
      ReceiveTransport(event)
    }),
  )
}

///|
fn WorkbenchModel::inspect_command_run(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> WorkbenchModel {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    { ..self, last_status: "Command evidence is empty" }
  } else {
    let prompt = self.command_evidence_payload(
      command, status, cwd, output_path,
    )
    self.queue_agent_prompt_action(
      prompt,
      event_title="Command evidence queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued command evidence for Pi RPC",
    )
  }
}

///|
fn WorkbenchModel::inspect_command_run_with_transport(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Command evidence is empty" })
  } else {
    let prompt = self.command_evidence_payload(
      command, status, cwd, output_path,
    )
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.inspect_command_run(command, status, cwd, output_path),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::fix_command_run(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> WorkbenchModel {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    { ..self, last_status: "Command evidence is empty" }
  } else {
    let prompt = self.command_fix_payload(command, status, cwd, output_path)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Command fix queued",
      event_detail=prompt,
      tone="warning",
      pi_status="Queued command fix for Pi RPC",
    )
  }
}

///|
fn WorkbenchModel::fix_command_run_with_transport(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Command evidence is empty" })
  } else {
    let prompt = self.command_fix_payload(command, status, cwd, output_path)
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SendUserInput(session.id, prompt),
    )
    WorkbenchUpdate::new(
      self.fix_command_run(command, status, cwd, output_path),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn command_evidence_prompt(
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  let command = command.trim().to_owned()
  let status = status.trim().to_owned()
  let cwd = cwd.trim().to_owned()
  let output_path = output_path.trim().to_owned()
  let command_label = if command == "" { "command run" } else { command }
  let prefix = if output_path == "" {
    "Inspect command run: " + command_label
  } else {
    "Inspect command output for " + command_label + ": " + output_path
  }
  let context : Array[String] = []
  if status != "" {
    context.push("status " + status)
  }
  if cwd != "" {
    context.push("cwd " + cwd)
  }
  if context.is_empty() {
    prefix
  } else {
    prefix + " (" + context.join(", ") + ")"
  }
}

///|
fn WorkbenchModel::command_evidence_payload(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  self.composer_prompt_payload(
    command_evidence_prompt(command, status, cwd, output_path),
  )
}

///|
fn command_fix_prompt(
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  let command = command.trim().to_owned()
  let status = status.trim().to_owned()
  let cwd = cwd.trim().to_owned()
  let output_path = output_path.trim().to_owned()
  let command_label = if command == "" { "command run" } else { command }
  let prefix = if output_path == "" {
    "Fix failed command run: " + command_label
  } else {
    "Fix failed command " + command_label + " using output " + output_path
  }
  let context : Array[String] = []
  if status != "" {
    context.push("status " + status)
  }
  if cwd != "" {
    context.push("cwd " + cwd)
  }
  if context.is_empty() {
    prefix
  } else {
    prefix + " (" + context.join(", ") + ")"
  }
}

///|
fn WorkbenchModel::command_fix_payload(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  self.composer_prompt_payload(
    command_fix_prompt(command, status, cwd, output_path),
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
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return {
      ..self,
      last_status: "Agent backend does not support session name sync",
    }
  }
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
fn WorkbenchModel::set_model(
  self : WorkbenchModel,
  provider : String,
  id : String,
  label : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_model_catalog {
    return {
      ..self,
      last_status: "Agent backend does not support model selection",
    }
  }
  let provider = provider.trim().to_owned()
  let id = id.trim().to_owned()
  if provider == "" || id == "" {
    { ..self, last_status: "Pi model selection is empty" }
  } else {
    let session = self.active_session()
    let model_label = if label == "" { provider + "/" + id } else { label }
    let transport_commands = self.commands_with_session_start(
      session,
      SetRpcModel(session.id, provider, id),
    )
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Pi model set queued",
        detail=model_label,
        tone="info",
      ),
    )
    {
      ..self,
      events,
      transport: self.transport.enqueue_many(transport_commands),
      last_status: "Pi model set queued",
    }
  }
}

///|
fn WorkbenchModel::set_model_with_transport(
  self : WorkbenchModel,
  provider : String,
  id : String,
  label : String,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let provider = provider.trim().to_owned()
  let id = id.trim().to_owned()
  if provider == "" || id == "" {
    WorkbenchUpdate::new({ ..self, last_status: "Pi model selection is empty" })
  } else {
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      SetRpcModel(session.id, provider, id),
    )
    WorkbenchUpdate::new(
      self.set_model(provider, id, label),
      effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
    )
  }
}

///|
fn WorkbenchModel::cycle_model(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_model_catalog {
    return {
      ..self,
      last_status: "Agent backend does not support model selection",
    }
  }
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CycleRpcModel(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi model cycle queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi model cycle queued",
  }
}

///|
fn WorkbenchModel::cycle_model_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    CycleRpcModel(session.id),
  )
  WorkbenchUpdate::new(
    self.cycle_model(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::compact_session(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_context_compaction {
    return { ..self, last_status: "Agent backend does not support compaction" }
  }
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CompactRpcSession(session.id, ""),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi compact queued",
      detail=session.title,
      tone="warning",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi compact queued",
  }
}

///|
fn WorkbenchModel::compact_session_with_transport(
  self : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    CompactRpcSession(session.id, ""),
  )
  WorkbenchUpdate::new(
    self.compact_session(),
    effect=transport_runtime.effect(commands, event => ReceiveTransport(event)),
  )
}

///|
fn WorkbenchModel::cycle_thinking_level(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_thinking_level {
    return {
      ..self,
      last_status: "Agent backend does not support thinking level",
    }
  }
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
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
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
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
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
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return {
      ..self,
      last_status: "Agent backend does not support cancellation",
    }
  }
  let session = self.active_session()
  let transport_command = self.cancel_transport_command(session)
  let shell_cancel = transport_command is CancelShellCommand(_)
  let model = if shell_cancel {
    self.mark_next_shell_command_cancelling(session)
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
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return WorkbenchUpdate::new(self.cancel_run())
  }
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
fn WorkbenchModel::mark_next_shell_command_cancelling(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> WorkbenchModel {
  let mut target_id : Int? = None
  for command in self.commands {
    if target_id is None && command.is_active_shell_for_session(session) {
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
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return []
  }
  if session.pi_session_path == "" {
    [
      StartRpc(session.id, session.project_path),
      FetchRpcAvailableModels(session.id),
      FetchRpcMessages(session.id),
      FetchRpcForkMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
    ]
  } else {
    [
      SwitchRpcSession(session.id, session.pi_session_path),
      StartRpc(session.id, session.project_path),
      FetchRpcAvailableModels(session.id),
      FetchRpcMessages(session.id),
      FetchRpcForkMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
    ]
  }
}

///|
fn WorkbenchModel::commands_for_new_session(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().supports_new_session {
    return []
  }
  [NewRpcSession(session.id)]
}

///|
fn WorkbenchModel::commands_for_session_replacement_refresh(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return []
  }
  let commands : Array[PiTransportCommand] = []
  commands.push(StartRpc(session.id, session.project_path))
  commands.push(FetchRpcAvailableModels(session.id))
  commands.push(FetchRpcMessages(session.id))
  commands.push(FetchRpcForkMessages(session.id))
  commands.push(FetchRpcCommands(session.id))
  commands.push(FetchRpcSessionStats(session.id))
  commands
}

///|
fn WorkbenchModel::commands_for_conversation_refresh(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return []
  }
  [
    FetchRpcMessages(session.id),
    FetchRpcForkMessages(session.id),
    FetchRpcSessionStats(session.id),
  ]
}

///|
fn WorkbenchModel::commands_for_focused_checks(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return []
  }
  let commands : Array[PiTransportCommand] = []
  if self.transport.status is Disconnected {
    commands.push(StartRpc(session.id, session.project_path))
  }
  for preset in workbench_check_presets() {
    commands.push(RunShellCommand(session.id, preset.command))
  }
  commands
}

///|
fn WorkbenchModel::commands_with_session_start(
  self : WorkbenchModel,
  session : WorkbenchSession,
  command : PiTransportCommand,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().uses_pi_transport {
    return []
  }
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
