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
  runtime : @agent_runtime.AgentRuntime
  mut turn_task : @async.Task[Unit]?
}

///|
fn openseek_env_trimmed(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(trimmed)
      }
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
/// Map a Mo Workbench model id to an OpenSeek typed model.
///
/// OpenSeek 0.2.x rejects arbitrary OpenAI-compatible ids, so custom ids stay
/// disabled in the app picker and are ignored here if a stale message arrives.
fn openseek_model_from_string(model_id : String) -> @deepseek.Model? {
  let model = @deepseek.Model::parse(model_id) catch { _ => return None }
  Some(model)
}

///|
fn openseek_thinking_from_choice(
  choice : @app.ThinkingChoice,
) -> @deepseek.ThinkingMode {
  match choice {
    @app.ThinkingChoice::Normal => @deepseek.ThinkingMode::No
    @app.ThinkingChoice::High => @deepseek.ThinkingMode::High
    // OpenAI-compatible gateways (e.g. Sensenova) reject `reasoning_effort=max`.
    @app.ThinkingChoice::Max => @deepseek.ThinkingMode::High
  }
}

///|
fn openseek_default_model() -> @deepseek.Model {
  @deepseek.Model::V4Flash
}

///|
fn openseek_default_thinking() -> @deepseek.ThinkingMode {
  @deepseek.ThinkingMode::No
}

///|
/// OpenAI-compatible `v1/models` listing shape.
struct ModelsResponse {
  data : Array[ModelEntry]
} derive(FromJson)

///|
struct ModelEntry {
  id : String
} derive(FromJson)

///|
/// Build the chat-completions `v1/models` URL from a provider base URL.
fn openseek_models_url(base_url : String) -> String {
  let trimmed = base_url.trim().to_owned()
  if trimmed.is_empty() {
    trimmed
  } else if trimmed.has_suffix("/") {
    trimmed + "models"
  } else {
    trimmed + "/models"
  }
}

///|
/// Parse a `v1/models` JSON body into model id strings. Tolerates providers
/// that wrap the list under `data` (OpenAI/DeepSeek style) and returns an
/// empty list when the body is not the expected shape.
fn openseek_parse_models(text : String) -> Array[String] {
  let out : Array[String] = []
  let parsed = @json.parse(text) catch { _ => return out }
  let resp : ModelsResponse = @json.from_json(parsed) catch { _ => return out }
  for e in resp.data {
    if !e.id.is_empty() {
      out.push(e.id)
    }
  }
  out
}

///|
/// Build a backend config from a persisted settings file, preferring the
/// active provider's connection and selected model. Falls back to environment
/// variables when the provider has no key.
fn openseek_config_from_settings(
  file : @app.MoWorkbenchSettingsFile,
) -> OpenSeekBackendConfig? {
  let provider = match file.active_provider_id {
    Some(id) => {
      let matching = file.providers.filter(fn(p) { p.id == id })
      if matching.is_empty() {
        None
      } else {
        Some(matching[0])
      }
    }
    None =>
      if file.providers.is_empty() {
        None
      } else {
        Some(file.providers[0])
      }
  }
  let (api_key, base_url, model_id) = match provider {
    Some(p) => {
      let key = if !p.api_key.is_empty() {
        p.api_key
      } else {
        openseek_resolve_api_key().unwrap_or("")
      }
      let url = if !p.base_url.is_empty() {
        p.base_url
      } else {
        openseek_resolve_api_url().unwrap_or("https://api.deepseek.com/v1")
      }
      let mid = if !file.current_model.is_empty() &&
        p.models.contains(file.current_model) &&
        @app.mo_workbench_model_supported_by_openseek(file.current_model) {
        file.current_model
      } else {
        match @app.mo_workbench_first_openseek_supported_model(p.models) {
          Some(model_id) => model_id
          None => return None
        }
      }
      (key, url, mid)
    }
    None =>
      match openseek_resolve_api_key() {
        Some(k) =>
          (
            k,
            openseek_resolve_api_url().unwrap_or("https://api.deepseek.com/v1"),
            "deepseek-v4-flash",
          )
        None => return None
      }
  }
  if api_key.is_empty() {
    return None
  }
  let model = match openseek_model_from_string(model_id) {
    Some(model) => model
    None => return None
  }
  let workspace = openseek_resolve_workspace_root()
  Some({
    api_key,
    api_url: Some(openseek_chat_completions_url(base_url)),
    model,
    thinking: openseek_default_thinking(),
    workspace_root: workspace,
    session_root: openseek_resolve_session_root(workspace),
  })
}

///|
/// Build a backend bundle from a persisted settings file (active provider).
pub fn openseek_backend_bundle_from_settings(
  file : @app.MoWorkbenchSettingsFile,
) -> OpenSeekBackendBundle? {
  match openseek_config_from_settings(file) {
    Some(config) => Some(openseek_backend_bundle(config))
    None => None
  }
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
    for agent_event in openseek_item_to_agent_events(event.item()) {
      out.push(agent_event)
    }
  }
  out
}

///|
fn openseek_item_to_agent_events(
  item : @agent_session.SessionItem,
) -> Array[@app.AgentEvent] {
  match item {
    @agent_session.SessionItem::User(message) =>
      [@app.AgentEvent::UserMessageAdded(message.content())]
    @agent_session.SessionItem::Assistant(message) => {
      let content = message.content()
      if content.trim().is_empty() {
        []
      } else {
        [
          @app.AgentEvent::AssistantMessageAdded(
            content,
            message.reasoning_content(),
          ),
        ]
      }
    }
    @agent_session.SessionItem::Tool(result) =>
      [
        @app.AgentEvent::ToolResultAdded(
          result.tool_name(),
          result.content(),
          result.is_error(),
          result.brief(),
        ),
      ]
    @agent_session.SessionItem::Runtime(notice) =>
      [@app.AgentEvent::RuntimeNoticeAdded(notice.content())]
    @agent_session.SessionItem::Summary(_) => []
    @agent_session.SessionItem::Terminal(terminal) =>
      openseek_terminal_to_agent_events(terminal)
  }
}

///|
fn openseek_terminal_to_agent_events(
  terminal : @agent_session.TurnTerminal,
) -> Array[@app.AgentEvent] {
  match terminal {
    @agent_session.TurnTerminal::Finished(message) => {
      let out : Array[@app.AgentEvent] = []
      if !message.trim().is_empty() {
        out.push(@app.AgentEvent::AssistantMessageAdded(message, None))
      }
      out.push(@app.AgentEvent::TurnTerminal(@app.TurnStatus::Finished, ""))
      out
    }
    @agent_session.TurnTerminal::Aborted(message) =>
      [@app.AgentEvent::TurnTerminal(@app.TurnStatus::Aborted, message)]
    @agent_session.TurnTerminal::Interrupted(message) =>
      [@app.AgentEvent::TurnTerminal(@app.TurnStatus::Interrupted, message)]
    @agent_session.TurnTerminal::Failed(message) =>
      [@app.AgentEvent::TurnTerminal(@app.TurnStatus::Failed, message)]
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
  { runtime: openseek_backend_runtime(owner), owner }
}

///|
fn openseek_backend_runtime(
  owner : OpenSeekBackendOwner,
) -> @app.AgentBackendRuntime {
  @app.agent_backend_runtime(run=(commands, emit) => {
    openseek_enqueue_commands(owner, commands, emit) catch {
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
      let state = openseek_engine_state(config, session)
      engine.val = Some(state)
      state
    }
  }
}

///|
fn openseek_engine_state(
  config : OpenSeekBackendConfig,
  session : @agent_session.Session,
) -> OpenSeekEngineState {
  {
    session,
    model: config.model,
    thinking: config.thinking,
    runtime: @agent_runtime.AgentRuntime(workspace_root=config.workspace_root),
    turn_task: None,
  }
}
