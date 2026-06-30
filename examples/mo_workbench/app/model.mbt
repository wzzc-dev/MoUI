// Slimmed-down Model / Msg / ChatMessage for the Codex-style workbench.

/// A single rendered chat message (UI projection of `AgentEvent`).
pub(all) enum ChatMessage {
  User(String)
  Assistant(String, String?)
  ToolResult(String, String, Bool, String?)
  RuntimeNotice(String)
  Terminal(TurnStatus, String)
}

/// Appearance mode for the workbench chrome.
pub(all) enum AppearanceMode {
  System
  Light
  Dark
} derive(Eq, Debug)

/// The workbench model. Deliberately small (~10 fields) compared to the old
/// 30+ field WorkbenchModel.
pub struct WorkbenchModel {
  sessions : Array[SessionSummary]
  active_session_id : String?
  messages : Array[ChatMessage]
  prompt : String
  steer_text : String
  is_streaming : Bool
  current_model : ModelChoice
  current_thinking : ThinkingChoice
  error : String?
  appearance : AppearanceMode
  scroll_state : @core.ScrollState
  backend : AgentBackendRuntime
}

fn WorkbenchModel::new(backend~ : AgentBackendRuntime) -> WorkbenchModel {
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
    appearance: AppearanceMode::System,
    scroll_state: @core.ScrollState::new(),
    backend,
  }
}

/// Workbench messages. ~12 variants (down from 40+).
pub(all) enum WorkbenchMsg {
  PromptChanged(String)
  SubmitPrompt
  SteerChanged(String)
  SubmitSteer
  NewSession
  SelectSession(String)
  ModelChanged(ModelChoice)
  ThinkingChanged(ThinkingChoice)
  ReceiveAgentEvent(AgentEvent)
  ClearError
  ToggleAppearance
}

/// Public facade so the entrypoint can construct the program without touching
/// the private model internals.
pub struct MoWorkbenchApp {
  priv backend : AgentBackendRuntime
}

fn MoWorkbenchApp::new(backend~ : AgentBackendRuntime) -> MoWorkbenchApp {
  { backend, }
}
