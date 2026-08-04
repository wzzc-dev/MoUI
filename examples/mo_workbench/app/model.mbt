// Shell Model + per-tab sub-models for the  task workbench.
//
// Architecture:
//   WorkbenchModel (shell) holds `active_tab` (Work/Code/Design) + the code
//   sub-model (chat surface) + settings sub-model + a UI projection of
//   sessions as `task_tree`. Msg routing is done via `CodeMsg(...)` /
//   `SettingsMsg(...)` wrapper variants; the shell delegates to the matching
//   sub-update and lifts the sub-effect via `Effect::map`.
//
//   `TaskTreeNode` / `TaskStatus` / `TaskGroup` are package-private UI
//   projections of the backend `SessionSummary` list; the single source of
//   truth remains `code.sessions`, kept in sync by `sync_task_tree` in
//   update.mbt.
//
// `WorkbenchModel` / `WorkbenchMsg` names are kept stable so the public
// `Program[WorkbenchModel, WorkbenchMsg]` type params and the entrypoint
// facade stay unchanged.

///|
/// The active top-level tab. Work/Design render placeholder surfaces; Code is
/// the interactive coding-agent chat surface.
pub(all) enum TopTab {
  Work
  Code
  Design
} derive(Eq, Debug)

///|
/// A single rendered chat message (UI projection of `AgentEvent`).
pub(all) enum ChatMessage {
  User(String)
  Assistant(String, String?)
  ToolResult(String, String, Bool, String?)
  RuntimeNotice(String)
  PermissionRequest(AgentPermissionRequest)
  Terminal(TurnStatus, String)
}

///|
/// Appearance mode for the workbench chrome.
pub(all) enum AppearanceMode {
  System
  Light
  Dark
} derive(Eq, Debug)

///|
/// Tool-call approval policy (UI-only in this prototype).
pub(all) enum ApprovalPolicy {
  NeverAsk
  AskOnWrite
  AskOnCommand
} derive(Eq, Debug)

///|
/// File-system access scope (UI-only in this prototype).
pub(all) enum SandboxMode {
  ReadOnly
  WorkspaceWritable
  FullAccess
} derive(Eq, Debug)

// ---------------------------------------------------------------------------
// Providers (multi-vendor, OpenAI-compatible)
// ---------------------------------------------------------------------------

///|
/// A single LLM provider (OpenAI-compatible). Holds the connection details and
/// the list of model ids the user can pick from. Models can be auto-discovered
/// via the provider's `v1/models` endpoint or added manually in settings.
pub struct ProviderConfig {
  id : String
  name : String
  base_url : String
  api_key : String
  models : Array[String]
} derive(Eq, Debug)

///|
pub fn ProviderConfig::new(
  id~ : String,
  name~ : String,
  base_url~ : String,
  api_key~ : String,
  models? : Array[String] = [],
) -> ProviderConfig {
  { id, name, base_url, api_key, models }
}

///|
/// The default provider seeded on first run: DeepSeek with its two known models.
pub fn default_deepseek_provider() -> ProviderConfig {
  ProviderConfig::new(
    id="deepseek",
    name="DeepSeek",
    base_url="https://api.deepseek.com/v1",
    api_key="",
    models=["deepseek-v4-flash", "deepseek-v4-pro"],
  )
}

///|
fn default_openai_provider() -> ProviderConfig {
  ProviderConfig::new(
    id="openai",
    name="OpenAI",
    base_url="https://api.openai.com/v1",
    api_key="",
    models=["gpt-4o", "gpt-4o-mini"],
  )
}

///|
fn default_providers() -> Array[ProviderConfig] {
  [default_deepseek_provider(), default_openai_provider()]
}

///|
/// Current native backend limit: OpenSeek 0.2.x only exposes these typed model
/// ids. Other provider-discovered/custom ids stay visible but disabled.
pub fn mo_workbench_model_supported_by_openseek(model_id : String) -> Bool {
  match model_id {
    "deepseek-v4-flash"
    | "deepseek-v4-pro"
    | "kimi-k2.7-code"
    | "kimi-k2.7-code-highspeed" => true
    _ => false
  }
}

///|
pub fn mo_workbench_first_openseek_supported_model(
  models : Array[String],
) -> String? {
  for model_id in models {
    if mo_workbench_model_supported_by_openseek(model_id) {
      return Some(model_id)
    }
  }
  None
}

///|
fn next_provider_id(providers : Array[ProviderConfig]) -> String {
  let mut index = providers.length() + 1
  while provider_id_exists(providers, "provider-" + index.to_string()) {
    index = index + 1
  }
  "provider-" + index.to_string()
}

///|
fn provider_id_exists(providers : Array[ProviderConfig], id : String) -> Bool {
  for p in providers {
    if p.id == id {
      return true
    }
  }
  false
}

///|
fn next_provider_name(providers : Array[ProviderConfig]) -> String {
  "Provider " + (providers.length() + 1).to_string()
}

///|
/// Resolve the active provider, falling back to the first provider when the
/// stored `active_provider_id` is missing or points at a removed provider.
pub fn SettingsWorkspace::active_provider(
  self : SettingsWorkspace,
) -> ProviderConfig? {
  let target = match self.active_provider_id {
    Some(id) => id
    None => ""
  }
  match self.provider_index(target) {
    Some(i) => Some(self.providers[i])
    None =>
      if self.providers.is_empty() {
        None
      } else {
        Some(self.providers[0])
      }
  }
}

///|
pub fn SettingsWorkspace::find_provider(
  self : SettingsWorkspace,
  id : String,
) -> ProviderConfig? {
  match self.provider_index(id) {
    Some(i) => Some(self.providers[i])
    None => None
  }
}

///|
pub fn SettingsWorkspace::provider_index(
  self : SettingsWorkspace,
  id : String,
) -> Int? {
  let mut i = 0
  for p in self.providers {
    if p.id == id {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Return a copy of `providers` with `field` of provider `id` set to `value`.
fn update_provider_field(
  providers : Array[ProviderConfig],
  id : String,
  field : ProviderField,
  value : String,
) -> Array[ProviderConfig] {
  let out : Array[ProviderConfig] = []
  for p in providers {
    if p.id == id {
      match field {
        Name => out.push({ ..p, name: value })
        BaseUrl => out.push({ ..p, base_url: value })
        ApiKey => out.push({ ..p, api_key: value })
      }
    } else {
      out.push(p)
    }
  }
  out
}

///|
/// Return a copy of `providers` with `model_id` appended to provider `id`
/// (no-op when the id is blank or already present).
fn add_manual_model(
  providers : Array[ProviderConfig],
  id : String,
  model_id : String,
) -> Array[ProviderConfig] {
  let trimmed = model_id.trim().to_owned()
  if trimmed.is_empty() {
    return providers
  }
  let out : Array[ProviderConfig] = []
  for p in providers {
    if p.id == id {
      if p.models.contains(trimmed) {
        out.push(p)
      } else {
        out.push({ ..p, models: p.models + [trimmed] })
      }
    } else {
      out.push(p)
    }
  }
  out
}

///|
/// Return a copy of `providers` with provider `id`'s model list replaced by
/// `models` (preserving unknown ids if needed).
fn replace_provider_models(
  providers : Array[ProviderConfig],
  id : String,
  models : Array[String],
) -> Array[ProviderConfig] {
  let out : Array[ProviderConfig] = []
  for p in providers {
    if p.id == id {
      out.push({ ..p, models, })
    } else {
      out.push(p)
    }
  }
  out
}

// ---------------------------------------------------------------------------
// Task tree projection (UI-only; derived from `code.sessions` by `sync_task_tree`)
// ---------------------------------------------------------------------------

///|
/// Lifecycle status of a task, derived from the session's streaming state and
/// the last terminal turn status.
enum TaskStatus {
  Pending
  Running
  Completed
  Failed
} derive(Eq, Debug)

///|
/// Sidebar task filter. Kept app-local; it only changes the projected task
/// tree, not the backend session list.
enum TaskFilter {
  AllTasks
  ActiveTask
  RunningTasks
  FailedTasks
} derive(Eq, Debug)

///|
/// Time-based grouping for the task list.
enum TaskGroup {
  Today
  Yesterday
  Earlier
} derive(Eq, Debug)

///|
/// A node in the sidebar task tree. Can be a folder (group header) or a leaf
/// (session-backed task). Folder nodes can be expanded/collapsed.
enum TaskTreeNode {
  Folder(String, String, TaskGroup, Array[TaskTreeNode], Bool)
  Task(String, String, TaskGroup, TaskStatus, Int)
} derive(Eq, Debug)

///|
/// Code workspace sub-model: the coding-agent chat surface.
/// Migrated from the previous flat `WorkbenchModel` chat fields.
pub struct CodeWorkspace {
  sessions : Array[SessionSummary]
  active_session_id : String?
  messages : Array[ChatMessage]
  prompt : String
  steer_text : String
  is_streaming : Bool
  progress_notice : String?
  current_model : String
  current_provider_id : String?
  model_picker_open : Bool
  current_thinking : ThinkingChoice
  agent_info : String?
  session_modes : AgentSessionModeState?
  session_config_options : Array[AgentSessionConfigOption]
  last_user_message_id : String?
  last_assistant_message_id : String?
  last_thought_message_id : String?
  error : String?
  scroll_state : @state.ScrollState
  follow_latest : Bool
}

///|
fn CodeWorkspace::new() -> CodeWorkspace {
  {
    sessions: [],
    active_session_id: None,
    messages: [],
    prompt: "",
    steer_text: "",
    is_streaming: false,
    progress_notice: None,
    current_model: "deepseek-v4-flash",
    current_provider_id: Some("deepseek"),
    model_picker_open: false,
    current_thinking: ThinkingChoice::Normal,
    agent_info: None,
    session_modes: None,
    session_config_options: [],
    last_user_message_id: None,
    last_assistant_message_id: None,
    last_thought_message_id: None,
    error: None,
    scroll_state: @state.ScrollState::new(),
    follow_latest: true,
  }
}

///|
/// Settings workspace sub-model: agent runtime + workbench preferences.
/// Values load from `settings.json` (template: `settings.json.example`).
///
/// Providers replace the previous single `api_key`/`base_url` pair: each
/// `ProviderConfig` is an OpenAI-compatible endpoint the user can add, edit,
/// and auto-detect models from. The chat surface uses `active_provider_id`
/// plus `code.current_model`.
pub struct SettingsWorkspace {
  agent_backend : AgentBackendKind
  providers : Array[ProviderConfig]
  active_provider_id : String?
  approval_policy : ApprovalPolicy
  sandbox_mode : SandboxMode
  working_dir : String
  session_root : String
  acp_command : String
  acp_args : String
  acp_process_cwd : String
  font_size : Int
  active_section : SettingsSection
  priv scroll_state : @state.ScrollState
  save_notice : String?
  env_source : String
  /// True while a `v1/models` auto-detect request is in flight.
  detect_busy : Bool
  /// Last auto-detect error (cleared on success).
  detect_error : String?
  /// Transient text in the "add model" field of the active provider (UI-only,
  /// not persisted).
  new_model_id : String
}

///|
pub(all) enum SettingsSection {
  Api
  Agent
  Editor
} derive(Eq, Debug)

///|
fn SettingsWorkspace::new() -> SettingsWorkspace {
  let providers = default_providers()
  {
    agent_backend: AgentBackendKind::OpenSeek,
    providers,
    active_provider_id: Some("deepseek"),
    approval_policy: ApprovalPolicy::AskOnWrite,
    sandbox_mode: SandboxMode::WorkspaceWritable,
    working_dir: ".",
    session_root: "./.openseek",
    acp_command: "",
    acp_args: "",
    acp_process_cwd: "",
    font_size: 14,
    active_section: SettingsSection::Api,
    scroll_state: @state.ScrollState::new(),
    save_notice: None,
    env_source: ".mo_workbench/settings.json.example",
    detect_busy: false,
    detect_error: None,
    new_model_id: "",
  }
}

///|
/// The workbench shell model. Holds the active tab + the code/settings
/// sub-models + a UI projection of sessions as `task_tree` + shared chrome
/// state + the injected backend runtime. The settings overlay open/close state
/// is tracked by `settings_open`.
pub struct WorkbenchModel {
  active_tab : TopTab
  task_tree : Array[TaskTreeNode]
  task_filter : TaskFilter
  task_search_query : String
  settings_open : Bool
  sidebar_visible : Bool
  code : CodeWorkspace
  settings : SettingsWorkspace
  appearance : AppearanceMode
  backend : AgentBackendRuntime
  settings_load : SettingsLoadFn?
  settings_persist : SettingsPersistFn?
  /// Injected model auto-detection (calls `v1/models`). None in the portable
  /// web build; the native macOS entrypoint supplies the HTTP implementation.
  model_detect : ModelDetectFn?
  /// Animation progress (0.0–1.0) for tab switch transitions.
  animation_progress : Double
}

///|
fn WorkbenchModel::new(
  backend~ : AgentBackendRuntime,
  settings_load? : SettingsLoadFn? = None,
  settings_persist? : SettingsPersistFn? = None,
  model_detect? : ModelDetectFn? = None,
) -> WorkbenchModel {
  let mut settings = SettingsWorkspace::new()
  let mut appearance = AppearanceMode::System
  let mut applied_model : String = "deepseek-v4-flash"
  let mut applied_provider : String? = Some("deepseek")
  match settings_load {
    Some(load) =>
      match load() {
        Some(file) => {
          settings = SettingsWorkspace::merge_settings_file(settings, file)
          appearance = AppearanceMode::merge_settings_file(appearance, file)
          settings = { ..settings, env_source: ".mo_workbench/settings.json" }
          if !file.current_model.is_empty() &&
            mo_workbench_model_supported_by_openseek(file.current_model) {
            applied_model = file.current_model
          }
          applied_provider = file.active_provider_id
        }
        None => ()
      }
    None => ()
  }
  {
    active_tab: TopTab::Code,
    task_tree: [],
    task_filter: TaskFilter::AllTasks,
    task_search_query: "",
    settings_open: false,
    sidebar_visible: true,
    code: {
      ..CodeWorkspace::new(),
      current_model: applied_model,
      current_provider_id: applied_provider,
    },
    settings,
    appearance,
    backend,
    settings_load,
    settings_persist,
    model_detect,
    animation_progress: 1.0,
  }
}

///|
/// Shell messages. Tab-scoped + task-scoped variants drive the shell; the
/// `CodeMsg(...)` / `SettingsMsg(...)` wrappers delegate to the matching
/// sub-update and lift the sub-effect via `Effect::map`. Agent events are
/// owned by the Code workspace (`CodeMsg::ReceiveAgentEvent`) so the code
/// surface fully encapsulates its backend dispatch + event projection.
pub(all) enum WorkbenchMsg {
  SwitchTab(TopTab)
  NewTask
  SelectTask(String)
  ToggleFolder(String)
  CycleTaskFilter
  ShowAllTasks
  ShowRunningTasks
  ShowFailedTasks
  TaskSearchChanged(String)
  ToggleSidebar
  ToggleSettings
  CodeMsg(CodeMsg)
  SettingsMsg(SettingsMsg)
  ToggleAppearance
}

///|
/// Code workspace messages (chat surface). Migrated from the previous flat
/// `WorkbenchMsg` chat variants, plus `ReceiveAgentEvent` so the code
/// workspace owns its backend dispatch + event handling end-to-end.
pub(all) enum CodeMsg {
  PromptChanged(String)
  SubmitPrompt
  SteerChanged(String)
  SubmitSteer
  NewSession
  SelectSession(String)
  /// Switch the active model. Carries `(provider_id, model_id)` so the shell
  /// can resolve the provider's connection and update the backend live.
  ModelChanged(String, String)
  /// Switch the active provider from the chat picker, keeping the model in
  /// sync. The shell resolves the provider and re-points the backend.
  SelectProvider(String)
  /// Toggle the inline model picker open/closed.
  ToggleModelPicker
  /// Request a native folder picker for the active workspace context.
  PickWorkspaceFolder
  /// Folder picker result. `None` means the picker was cancelled.
  WorkspaceFolderSelected(String?)
  /// Folder picker failed because host services are unavailable or errored.
  WorkspaceFolderPickFailed(String)
  ThinkingChanged(ThinkingChoice)
  CancelTurn
  SetSessionMode(String)
  SetSessionConfigOption(String, AgentConfigValue)
  RespondPermission(String, PermissionOutcome)
  ClearError
  MessageListScrolled(@geometry.Point)
  ReceiveAgentEvent(AgentEvent)
}

///|
/// Settings workspace messages (form interactions).
pub(all) enum SettingsMsg {
  SelectSection(SettingsSection)
  BackendChanged(AgentBackendKind)
  ApprovalChanged(ApprovalPolicy)
  SandboxChanged(SandboxMode)
  WorkingDirChanged(String)
  SessionRootChanged(String)
  AcpCommandChanged(String)
  AcpArgsChanged(String)
  AcpProcessCwdChanged(String)
  FontSizeChanged(Int)
  AppearanceChanged(AppearanceMode)
  SaveToDisk
  DismissSaveNotice
  // --- Provider management ---
  /// Make the provider with `id` the active one (drives the chat surface).
  SelectProvider(String)
  /// Add a new empty provider.
  AddProvider
  /// Edit one field of a provider: (provider_id, field, value).
  UpdateProviderField(String, ProviderField, String)
  /// Remove a provider by id (only when more than one remains).
  RemoveProvider(String)
  /// Trigger `v1/models` auto-detection for a provider.
  DetectModels(String)
  /// Result of auto-detection: (provider_id, model_ids | None on failure).
  ModelsDetected(String, Array[String]?)
  /// Manually add a model id to a provider: (provider_id, model_id).
  AddManualModel(String, String)
  /// Typed text in the "add model" field of the active provider.
  NewModelInputChanged(String)
}

///|
/// Editable field of a `ProviderConfig`.
pub(all) enum ProviderField {
  Name
  BaseUrl
  ApiKey
} derive(Eq, Debug)

///|
/// Injected model auto-detection. Calls `v1/models` for `(base_url, api_key)`
/// and reports discovered model ids via `on_result` (None on failure). The
/// portable web build leaves this unset; the native entrypoint supplies it.
pub type ModelDetectFn = (String, String, (Array[String]?) -> Unit) -> Unit

///|
/// Public facade so the entrypoint can construct the program without touching
/// the private model internals.
pub struct MoWorkbenchApp {
  priv backend : AgentBackendRuntime
  priv settings_load : SettingsLoadFn?
  priv settings_persist : SettingsPersistFn?
  priv model_detect : ModelDetectFn?
  priv environment : @services.AppEnvironment
}

///|
fn MoWorkbenchApp::new(
  backend~ : AgentBackendRuntime,
  settings_load? : SettingsLoadFn? = None,
  settings_persist? : SettingsPersistFn? = None,
  model_detect? : ModelDetectFn? = None,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> MoWorkbenchApp {
  { backend, settings_load, settings_persist, model_detect, environment }
}
