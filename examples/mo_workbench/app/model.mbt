// Shell Model + per-workspace sub-models for the multi-workspace workbench.
//
// Architecture (mirrors DeepSeek-GUI's workbench/entry model):
//   WorkbenchModel (shell) holds `active_workspace` + one sub-model per
//   workspace. Msg routing is done via `CodeMsg(...)` / `SettingsMsg(...)`
//   wrapper variants; the shell delegates to the matching sub-update and
//   lifts the sub-effect via `Effect::map`.
//
// `WorkbenchModel` / `WorkbenchMsg` names are kept stable so the public
// `Program[WorkbenchModel, WorkbenchMsg]` type params and the entrypoint
// facade stay unchanged.

///|
/// The active workspace surface. Code/Settings are interactive; the other
/// product routes render static shells until their backend workflows land.
pub(all) enum Workspace {
  Code
  Write
  Settings
  ConnectPhone
  ScheduledTasks
  Plugins
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
  scroll_state : @core.ScrollState
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
    current_model: ModelChoice::V4Pro,
    current_thinking: ThinkingChoice::Max,
    error: None,
    scroll_state: @core.ScrollState::new(),
  }
}

///|
/// Settings workspace sub-model: agent runtime + chrome settings form state.
/// UI-only in this prototype; persistence is reserved for the future backend
/// integration.
pub struct SettingsWorkspace {
  api_key : String
  base_url : String
  approval_policy : ApprovalPolicy
  sandbox_mode : SandboxMode
  working_dir : String
  font_size : Int
}

///|
fn SettingsWorkspace::new() -> SettingsWorkspace {
  {
    api_key: "",
    base_url: "https://api.deepseek.com",
    approval_policy: ApprovalPolicy::AskOnWrite,
    sandbox_mode: SandboxMode::WorkspaceWritable,
    working_dir: "",
    font_size: 14,
  }
}

///|
/// Write workspace sub-model: placeholder for the future Markdown writing
/// surface (file tree, editor state, completion). Currently holds no state.
pub struct WriteWorkspace {
  // Reserved for future write-mode state (file tree / editor / completion).
  reserved : Unit
}

///|
fn WriteWorkspace::new() -> WriteWorkspace {
  { reserved: () }
}

///|
/// The workbench shell model. Holds the active workspace + per-workspace
/// sub-models + shared chrome state + the injected backend runtime.
pub struct WorkbenchModel {
  active_workspace : Workspace
  code : CodeWorkspace
  write : WriteWorkspace
  settings : SettingsWorkspace
  appearance : AppearanceMode
  backend : AgentBackendRuntime
  /// Animation progress (0.0–1.0) for workspace switch transitions.
  animation_progress : Double
}

///|
fn WorkbenchModel::new(backend~ : AgentBackendRuntime) -> WorkbenchModel {
  {
    active_workspace: Workspace::Code,
    code: CodeWorkspace::new(),
    write: WriteWorkspace::new(),
    settings: SettingsWorkspace::new(),
    appearance: AppearanceMode::System,
    backend,
    animation_progress: 1.0,
  }
}

///|
/// Shell messages. Workspace-scoped variants wrap the sub-workspace msgs;
/// the shell routes them and lifts sub-effects via `Effect::map`. Agent events
/// are owned by the Code workspace (`CodeMsg::ReceiveAgentEvent`) so the code
/// surface fully encapsulates its backend dispatch + event projection.
pub(all) enum WorkbenchMsg {
  SwitchWorkspace(Workspace)
  CodeMsg(CodeMsg)
  SettingsMsg(SettingsMsg)
  WriteMsg(WriteMsg)
  ToggleAppearance
  /// Advance workspace switch animation by one frame.
  AnimationTick
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
  ApiKeyChanged(String)
  BaseUrlChanged(String)
  ApprovalChanged(ApprovalPolicy)
  SandboxChanged(SandboxMode)
  WorkingDirChanged(String)
  FontSizeChanged(Int)
}

///|
/// Write workspace messages. Reserved for future write-mode interactions.
pub(all) enum WriteMsg {
  Reserved
}

///|
/// Public facade so the entrypoint can construct the program without touching
/// the private model internals.
pub struct MoWorkbenchApp {
  priv backend : AgentBackendRuntime
}

///|
fn MoWorkbenchApp::new(backend~ : AgentBackendRuntime) -> MoWorkbenchApp {
  { backend, }
}
