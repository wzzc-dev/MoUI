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
pub(all) enum AgentBackendTransportKind {
  PiJsonlRpcTransport
  AcpConnectorTransport
  FixtureTransport
  NoAgentTransport
} derive(Eq, Debug)

///|
pub(all) struct AgentBackendCapabilities {
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
  transport_kind : AgentBackendTransportKind
  capabilities : AgentBackendCapabilities
} derive(Eq, Debug)

///|
pub(all) struct AgentBackendStatus {
  backend_id : String
  label : String
  status_label : String
  pending_count : Int
  failed : Bool
  sidebar_visible : Bool
  top_bar_visible : Bool
} derive(Eq, Debug)

///|
pub(all) struct AgentSessionBinding {
  backend_id : String
  workbench_session_id : String
  provider_session_id : String
  session_file : String
  session_name : String
  model : String
  status : String
  last_command : String
} derive(Eq, Debug)

///|
pub(all) struct AgentSessionMetrics {
  backend_id : String
  workbench_session_id : String
  total_messages : Int
  tool_calls : Int
  tool_results : Int
  token_total : Int
  context_percent : Double?
} derive(Eq, Debug)

///|
pub(all) struct AgentRuntimeSignal {
  backend_id : String
  status_label : String
  active_tool_name : String
  message_preview : String
  thinking_level : String
  visible : Bool
  active : Bool
} derive(Eq, Debug)

///|
pub(all) struct AgentInputSettings {
  backend_id : String
  thinking_level : String
  steering_mode : String
  follow_up_mode : String
  queued_steering : Int
  queued_follow_up : Int
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
pub(all) struct AgentCommandInfo {
  name : String
  source : String
  description : String
  source_scope : String
  source_path : String
} derive(Eq, Debug)

///|
pub(all) struct AgentModelInfo {
  provider : String
  id : String
  name : String
  label : String
} derive(Eq, Debug)

///|
pub(all) struct AgentForkPoint {
  entry_id : String
  text : String
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
  appearance_mode : String
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
  agent_connectors : Array[AgentConnectorState]
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
  SetAppearanceMode(String)
  SwitchAgentBackend(String)
  CreateConversation
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
  ReceiveConnector(AgentConnectorEvent)
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
  transport_kind? : AgentBackendTransportKind = NoAgentTransport,
  capabilities~ : AgentBackendCapabilities,
) -> AgentBackendProfile {
  { id, label, description, transport_kind, capabilities }
}

///|
pub fn AgentBackendTransportKind::label(
  self : AgentBackendTransportKind,
) -> String {
  match self {
    PiJsonlRpcTransport => "pi jsonl rpc"
    AcpConnectorTransport => "acp connector"
    FixtureTransport => "fixture"
    NoAgentTransport => "local"
  }
}

///|
pub fn AgentBackendTransportKind::uses_pi_transport(
  self : AgentBackendTransportKind,
) -> Bool {
  self is PiJsonlRpcTransport
}

///|
pub fn AgentBackendTransportKind::uses_connector_transport(
  self : AgentBackendTransportKind,
) -> Bool {
  self is AcpConnectorTransport
}

///|
pub fn AgentBackendProfile::uses_pi_transport(
  self : AgentBackendProfile,
) -> Bool {
  self.transport_kind.uses_pi_transport()
}

///|
pub fn AgentBackendProfile::uses_connector_transport(
  self : AgentBackendProfile,
) -> Bool {
  self.transport_kind.uses_connector_transport()
}

///|
pub fn AgentBackendStatus::new(
  backend_id~ : String,
  label~ : String,
  status_label? : String = "",
  pending_count? : Int = 0,
  failed? : Bool = false,
  sidebar_visible? : Bool = false,
  top_bar_visible? : Bool = false,
) -> AgentBackendStatus {
  {
    backend_id,
    label,
    status_label,
    pending_count,
    failed,
    sidebar_visible,
    top_bar_visible,
  }
}

///|
pub fn AgentBackendStatus::has_sidebar_status(
  self : AgentBackendStatus,
) -> Bool {
  self.sidebar_visible
}

///|
pub fn AgentBackendStatus::has_top_bar_chip(self : AgentBackendStatus) -> Bool {
  self.top_bar_visible
}

///|
pub fn AgentSessionBinding::new(
  backend_id~ : String,
  workbench_session_id~ : String,
  provider_session_id? : String = "",
  session_file? : String = "",
  session_name? : String = "",
  model? : String = "",
  status? : String = "unbound",
  last_command? : String = "",
) -> AgentSessionBinding {
  {
    backend_id,
    workbench_session_id,
    provider_session_id,
    session_file,
    session_name,
    model,
    status,
    last_command,
  }
}

///|
pub fn AgentSessionMetrics::new(
  backend_id~ : String,
  workbench_session_id~ : String,
  total_messages? : Int = 0,
  tool_calls? : Int = 0,
  tool_results? : Int = 0,
  token_total? : Int = 0,
  context_percent? : Double? = None,
) -> AgentSessionMetrics {
  {
    backend_id,
    workbench_session_id,
    total_messages,
    tool_calls,
    tool_results,
    token_total,
    context_percent,
  }
}

///|
pub fn AgentSessionMetrics::has_visible_metrics(
  self : AgentSessionMetrics,
) -> Bool {
  if self.total_messages > 0 ||
    self.tool_calls > 0 ||
    self.tool_results > 0 ||
    self.token_total > 0 {
    true
  } else {
    match self.context_percent {
      Some(_) => true
      None => false
    }
  }
}

///|
pub fn AgentRuntimeSignal::new(
  backend_id~ : String,
  status_label? : String = "",
  active_tool_name? : String = "",
  message_preview? : String = "",
  thinking_level? : String = "",
  visible? : Bool = false,
  active? : Bool = false,
) -> AgentRuntimeSignal {
  {
    backend_id,
    status_label,
    active_tool_name,
    message_preview,
    thinking_level,
    visible,
    active,
  }
}

///|
pub fn AgentRuntimeSignal::has_visible_signal(
  self : AgentRuntimeSignal,
) -> Bool {
  self.visible
}

///|
pub fn AgentRuntimeSignal::has_active_signal(self : AgentRuntimeSignal) -> Bool {
  self.active
}

///|
pub fn AgentInputSettings::new(
  backend_id~ : String,
  thinking_level? : String = "",
  steering_mode? : String = "one-at-a-time",
  follow_up_mode? : String = "one-at-a-time",
  queued_steering? : Int = 0,
  queued_follow_up? : Int = 0,
) -> AgentInputSettings {
  {
    backend_id,
    thinking_level,
    steering_mode,
    follow_up_mode,
    queued_steering,
    queued_follow_up,
  }
}

///|
pub fn AgentInputSettings::has_visible_thinking_level(
  self : AgentInputSettings,
) -> Bool {
  self.thinking_level != ""
}

///|
pub fn AgentInputSettings::queued_input_count(self : AgentInputSettings) -> Int {
  self.queued_steering + self.queued_follow_up
}

///|
pub fn AgentInputSettings::has_visible_input_modes(
  self : AgentInputSettings,
) -> Bool {
  self.steering_mode != "one-at-a-time" ||
  self.follow_up_mode != "one-at-a-time" ||
  self.queued_input_count() > 0
}

///|
pub fn agent_backend_profiles() -> Array[AgentBackendProfile] {
  [
    AgentBackendProfile::new(
      id="pi",
      label="Pi",
      description="真实后端",
      transport_kind=PiJsonlRpcTransport,
      capabilities=AgentBackendCapabilities::new(
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
      id="acp-demo",
      label="ACP Demo",
      description="ACP connector fixture",
      transport_kind=AcpConnectorTransport,
      capabilities=AgentBackendCapabilities::new(
        supports_session_refresh=true,
        supports_new_session=true,
        supports_command_catalog=true,
        supports_session_stats=true,
      ),
    ),
    AgentBackendProfile::new(
      id="fixture",
      label="本地",
      description="本地演练",
      transport_kind=FixtureTransport,
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
pub fn AgentCommandInfo::new(
  name~ : String,
  source~ : String,
  description~ : String,
  source_scope~ : String,
  source_path~ : String,
) -> AgentCommandInfo {
  { name, source, description, source_scope, source_path }
}

///|
pub fn AgentModelInfo::new(
  provider~ : String,
  id~ : String,
  name? : String = "",
  label? : String = "",
) -> AgentModelInfo {
  let label = if label == "" {
    agent_model_label(provider, id, name)
  } else {
    label
  }
  { provider, id, name, label }
}

///|
pub fn AgentForkPoint::new(
  entry_id~ : String,
  text? : String = "",
) -> AgentForkPoint {
  { entry_id, text }
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
pub fn PiCommandInfo::as_agent_command_info(
  self : PiCommandInfo,
) -> AgentCommandInfo {
  AgentCommandInfo::new(
    name=self.name,
    source=self.source,
    description=self.description,
    source_scope=self.source_scope,
    source_path=self.source_path,
  )
}

///|
pub fn PiModelInfo::new(
  provider~ : String,
  id~ : String,
  name? : String = "",
  label? : String = "",
) -> PiModelInfo {
  let label = if label == "" {
    agent_model_label(provider, id, name)
  } else {
    label
  }
  { provider, id, name, label }
}

///|
pub fn PiModelInfo::as_agent_model_info(self : PiModelInfo) -> AgentModelInfo {
  AgentModelInfo::new(
    provider=self.provider,
    id=self.id,
    name=self.name,
    label=self.label,
  )
}

///|
fn agent_model_label(provider : String, id : String, name : String) -> String {
  let scoped = if provider == "" && id == "" {
    ""
  } else if provider == "" {
    id
  } else if id == "" {
    provider
  } else {
    provider + "/" + id
  }
  if name == "" || name == id || name == scoped {
    scoped
  } else if scoped == "" {
    name
  } else {
    name + " (" + scoped + ")"
  }
}

///|
pub fn PiForkMessage::new(entry_id~ : String, text~ : String) -> PiForkMessage {
  { entry_id, text }
}

///|
pub fn PiForkMessage::as_agent_fork_point(
  self : PiForkMessage,
) -> AgentForkPoint {
  AgentForkPoint::new(entry_id=self.entry_id, text=self.text)
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
pub fn PiSessionStatsSnapshot::as_agent_session_metrics(
  self : PiSessionStatsSnapshot,
  backend_id? : String = "pi",
  workbench_session_id~ : String,
) -> AgentSessionMetrics {
  AgentSessionMetrics::new(
    backend_id~,
    workbench_session_id~,
    total_messages=self.total_messages,
    tool_calls=self.tool_calls,
    tool_results=self.tool_results,
    token_total=self.token_total,
    context_percent=self.context_percent,
  )
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
pub fn PiSessionBinding::as_agent_session_binding(
  self : PiSessionBinding,
  backend_id? : String = "pi",
) -> AgentSessionBinding {
  AgentSessionBinding::new(
    backend_id~,
    workbench_session_id=self.workbench_session_id,
    provider_session_id=self.rpc_session_id,
    session_file=self.session_file,
    session_name=self.session_name,
    model=self.model,
    status=self.status,
    last_command=self.last_command,
  )
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
      label="首帧 smoke",
      command="moon build moui_tester/macos_skia_first_frame_smoke --target native",
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
    appearance_mode: "system",
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
    agent_connectors: default_agent_connector_states(),
    pi_rpc: PiRpcSnapshot::new(),
    pi_agent: PiAgentSnapshot::new(),
    pi_session_bindings: [],
    last_status: "Ready for agent backend",
  }
}

///|
