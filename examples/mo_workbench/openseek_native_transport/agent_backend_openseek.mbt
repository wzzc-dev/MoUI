// OpenSeek agent backend for Mo Workbench (native macOS Skia entrypoint).

///|
struct OpenSeekBackendConfig {
  api_key : String
  api_url : String?
  model : @deepseek.Model
  thinking : @deepseek.ThinkingMode
  workspace_root : String
  session_root : String
}

///|
struct OpenSeekEngineState {
  mut session : @agent_session.Session
  mut model : @deepseek.Model
  mut thinking : @deepseek.ThinkingMode
  mut turn_task : @async.Task[Unit]?
}

///|
fn openseek_env_trimmed(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() { None } else { Some(trimmed) }
    }
    None => None
  }
}

///|
fn openseek_resolve_api_key() -> String? {
  match openseek_env_trimmed("OPENAI_API_KEY") {
    Some(key) => Some(key)
    None => openseek_env_trimmed("DEEPSEEK")
  }
}

///|
fn openseek_resolve_api_url() -> String? {
  match openseek_env_trimmed("OPENAI_BASE_URL") {
    Some(base) => Some(openseek_chat_completions_url(base))
    None => None
  }
}

///|
/// OpenSeek's HTTP client expects a full chat-completions URL (not only `/v1`).
fn openseek_chat_completions_url(base : String) -> String {
  let trimmed = base.trim().to_owned()
  if trimmed.is_empty() {
    trimmed
  } else if trimmed.has_suffix("/chat/completions") {
    trimmed
  } else if trimmed.has_suffix("/") {
    trimmed + "chat/completions"
  } else {
    trimmed + "/chat/completions"
  }
}

///|
fn openseek_resolve_workspace_root() -> String {
  openseek_env_trimmed("MO_WORKBENCH_WORKSPACE").unwrap_or(".")
}

///|
fn openseek_resolve_session_root(workspace : String) -> String {
  match openseek_env_trimmed("MO_WORKBENCH_SESSION_ROOT") {
    Some(root) => root
    None => workspace + "/.openseek"
  }
}

///|
fn openseek_model_from_choice(choice : @app.ModelChoice) -> @deepseek.Model {
  match choice {
    @app.ModelChoice::V4Flash => @deepseek.Model::V4Flash
    @app.ModelChoice::V4Pro => @deepseek.Model::V4Pro
  }
}

///|
fn openseek_thinking_from_choice(
  choice : @app.ThinkingChoice,
) -> @deepseek.ThinkingMode {
  match choice {
    @app.ThinkingChoice::No => @deepseek.ThinkingMode::No
    @app.ThinkingChoice::High => @deepseek.ThinkingMode::High
    @app.ThinkingChoice::Max => @deepseek.ThinkingMode::Max
  }
}

///|
fn openseek_default_model() -> @deepseek.Model {
  @deepseek.Model::V4Flash
}

///|
fn openseek_default_thinking() -> @deepseek.ThinkingMode {
  @deepseek.ThinkingMode::Max
}

///|
let openseek_session_counter : Ref[Int] = Ref(0)

///|
fn openseek_new_session_id(prefix : String) -> @agent_session.SessionId {
  openseek_session_counter.val = openseek_session_counter.val + 1
  @agent_session.SessionId::SessionId(
    prefix + "-" + openseek_session_counter.val.to_string(),
  )
}

///|
fn openseek_system_prompt(model : @deepseek.Model) -> String {
  @prompt.system_prompt_for_model(model)
}

///|
fn openseek_session_to_agent_events(
  session : @agent_session.Session,
) -> Array[@app.AgentEvent] {
  let out : Array[@app.AgentEvent] = []
  for event in session.events() {
    match openseek_item_to_agent_event(event.item()) {
      Some(agent_event) => out.push(agent_event)
      None => ()
    }
  }
  out
}

///|
fn openseek_item_to_agent_event(
  item : @agent_session.SessionItem,
) -> @app.AgentEvent? {
  match item {
    @agent_session.SessionItem::User(message) =>
      Some(@app.AgentEvent::UserMessageAdded(message.content()))
    @agent_session.SessionItem::Assistant(message) => {
      let content = message.content()
      if content.trim().is_empty() {
        None
      } else {
        Some(
          @app.AgentEvent::AssistantMessageAdded(
            content,
            message.reasoning_content(),
          ),
        )
      }
    }
    @agent_session.SessionItem::Tool(result) =>
      Some(
        @app.AgentEvent::ToolResultAdded(
          result.tool_name(),
          result.content(),
          result.is_error(),
          result.brief(),
        ),
      )
    @agent_session.SessionItem::Runtime(notice) =>
      Some(@app.AgentEvent::RuntimeNoticeAdded(notice.content()))
    @agent_session.SessionItem::Summary(_) => None
    @agent_session.SessionItem::Terminal(terminal) =>
      Some(openseek_terminal_to_agent_event(terminal))
  }
}

///|
fn openseek_terminal_to_agent_event(
  terminal : @agent_session.TurnTerminal,
) -> @app.AgentEvent {
  match terminal {
    @agent_session.TurnTerminal::Finished(message) =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Finished, message)
    @agent_session.TurnTerminal::Aborted(message) =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Aborted, message)
    @agent_session.TurnTerminal::Interrupted(message) =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Interrupted, message)
    @agent_session.TurnTerminal::Failed(message) =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Failed, message)
  }
}

///|
fn openseek_listing_to_summary(
  listing : @store.SessionListing,
) -> @app.SessionSummary {
  @app.session_summary(
    id=listing.id().value(),
    first_prompt=listing.first_prompt(),
    last_active_unix_seconds=listing.last_active_unix_seconds(),
  )
}

///|
pub struct OpenSeekBackendBundle {
  runtime : @app.AgentBackendRuntime
  owner : OpenSeekBackendOwner
}

///|
fn openseek_config_from_env() -> OpenSeekBackendConfig? {
  match openseek_resolve_api_key() {
    Some(api_key) => {
      let workspace = openseek_resolve_workspace_root()
      Some({
        api_key,
        api_url: openseek_resolve_api_url(),
        model: openseek_default_model(),
        thinking: openseek_default_thinking(),
        workspace_root: workspace,
        session_root: openseek_resolve_session_root(workspace),
      })
    }
    None => None
  }
}

///|
/// Build runtime + worker owner when `OPENAI_API_KEY` or `DEEPSEEK` is set.
pub fn openseek_backend_bundle_from_env() -> OpenSeekBackendBundle? {
  match openseek_config_from_env() {
    Some(config) => Some(openseek_backend_bundle(config))
    None => None
  }
}

///|
pub fn openseek_backend_bundle(
  config : OpenSeekBackendConfig,
) -> OpenSeekBackendBundle {
  let owner = OpenSeekBackendOwner::new(config)
  {
    runtime: openseek_backend_runtime(owner),
    owner,
  }
}

///|
fn openseek_backend_runtime(
  owner : OpenSeekBackendOwner,
) -> @app.AgentBackendRuntime {
  @app.agent_backend_runtime(run=(commands, emit) => {
    try openseek_enqueue_commands(owner, commands, emit) catch {
      _ => ()
    }
  })
}

///|
fn openseek_ensure_engine(
  config : OpenSeekBackendConfig,
  engine : Ref[OpenSeekEngineState?],
) -> OpenSeekEngineState {
  match engine.val {
    Some(state) => state
    None => {
      let id = openseek_new_session_id("mo-workbench")
      let session = @agent_session.Session(
        id,
        system_prompt=openseek_system_prompt(config.model),
      )
      let state = {
        session,
        model: config.model,
        thinking: config.thinking,
        turn_task: None,
      }
      engine.val = Some(state)
      state
    }
  }
}