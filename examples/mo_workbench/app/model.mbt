// Shell Model + per-tab sub-models for the TRAE-style task workbench.
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
  current_model : ModelChoice
  current_thinking : ThinkingChoice
  error : String?
  scroll_state : @state.ScrollState
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
    current_model: ModelChoice::V4Flash,
    current_thinking: ThinkingChoice::No,
    error: None,
    scroll_state: @state.ScrollState::new(),
  }
}

///|
/// Settings workspace sub-model: agent runtime + workbench preferences.
/// Values load from `settings.json` (template: `settings.json.example`).
pub struct SettingsWorkspace {
  api_key : String
  base_url : String
  approval_policy : ApprovalPolicy
  sandbox_mode : SandboxMode
  working_dir : String
  session_root : String
  font_size : Int
  active_section : SettingsSection
  save_notice : String?
  env_source : String
}

///|
pub(all) enum SettingsSection {
  Api
  Agent
  Editor
} derive(Eq, Debug)

///|
fn SettingsWorkspace::new() -> SettingsWorkspace {
  {
    api_key: "",
    base_url: "https://api.deepseek.com/v1",
    approval_policy: ApprovalPolicy::AskOnWrite,
    sandbox_mode: SandboxMode::WorkspaceWritable,
    working_dir: ".",
    session_root: "./.openseek",
    font_size: 14,
    active_section: SettingsSection::Api,
    save_notice: None,
    env_source: ".mo_workbench/settings.json.example",
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
  settings_open : Bool
  sidebar_visible : Bool
  code : CodeWorkspace
  settings : SettingsWorkspace
  appearance : AppearanceMode
  backend : AgentBackendRuntime
  settings_load : SettingsLoadFn?
  settings_persist : SettingsPersistFn?
  /// Animation progress (0.0–1.0) for tab switch transitions.
  animation_progress : Double
}

///|
fn WorkbenchModel::new(
  backend~ : AgentBackendRuntime,
  settings_load? : SettingsLoadFn? = None,
  settings_persist? : SettingsPersistFn? = None,
) -> WorkbenchModel {
  let mut settings = SettingsWorkspace::new()
  let mut appearance = AppearanceMode::System
  match settings_load {
    Some(load) =>
      match load() {
        Some(file) => {
          settings = SettingsWorkspace::merge_settings_file(settings, file)
          appearance = AppearanceMode::merge_settings_file(appearance, file)
          settings = { ..settings, env_source: ".mo_workbench/settings.json" }
        }
        None => ()
      }
    None => ()
  }
  {
    active_tab: TopTab::Code,
    task_tree: [],
    settings_open: false,
    sidebar_visible: true,
    code: CodeWorkspace::new(),
    settings,
    appearance,
    backend,
    settings_load,
    settings_persist,
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
  ModelChanged(ModelChoice)
  ThinkingChanged(ThinkingChoice)
  ClearError
  ReceiveAgentEvent(AgentEvent)
}

///|
/// Settings workspace messages (form interactions).
pub(all) enum SettingsMsg {
  SelectSection(SettingsSection)
  ApiKeyChanged(String)
  BaseUrlChanged(String)
  ApprovalChanged(ApprovalPolicy)
  SandboxChanged(SandboxMode)
  WorkingDirChanged(String)
  SessionRootChanged(String)
  FontSizeChanged(Int)
  AppearanceChanged(AppearanceMode)
  SaveToDisk
  DismissSaveNotice
}

///|
/// Public facade so the entrypoint can construct the program without touching
/// the private model internals.
pub struct MoWorkbenchApp {
  priv backend : AgentBackendRuntime
  priv settings_load : SettingsLoadFn?
  priv settings_persist : SettingsPersistFn?
}

///|
fn MoWorkbenchApp::new(
  backend~ : AgentBackendRuntime,
  settings_load? : SettingsLoadFn? = None,
  settings_persist? : SettingsPersistFn? = None,
) -> MoWorkbenchApp {
  { backend, settings_load, settings_persist }
}
