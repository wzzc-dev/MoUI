// Async command worker for OpenSeek (must not call run_async_main from UI effects).

///|
enum OpenSeekWork {
  RunCommands(Array[@app.AgentCommand], (@app.AgentEvent) -> Unit)
  // Performs an async `GET {base}/models` and reports discovered ids via the
  // callback. The callback dispatches a `ModelsDetected` message back to the
  // app, so detection must run on the worker's task group (not a UI effect).
  DetectModels(String, String, (Array[String]?) -> Unit)
}

///|
pub struct OpenSeekBackendOwner {
  mut config : OpenSeekBackendConfig
  engine : Ref[OpenSeekEngineState?]
  queue : @async.Queue[OpenSeekWork]
}

///|
pub fn OpenSeekBackendOwner::new(
  config : OpenSeekBackendConfig,
) -> OpenSeekBackendOwner {
  { config, engine: Ref(None), queue: @async.Queue(kind=Unbounded) }
}

///|
fn openseek_enqueue_commands(
  owner : OpenSeekBackendOwner,
  commands : Array[@app.AgentCommand],
  emit : (@app.AgentEvent) -> Unit,
) -> Unit raise {
  ignore(owner.queue.try_put(OpenSeekWork::RunCommands(commands, emit)))
}

///|
/// Enqueue a model auto-detection job. The job runs on the worker's async task
/// group and reports results through `on_result` — never call this from a UI
/// effect that expects a synchronous answer.
pub fn openseek_enqueue_detect(
  owner : OpenSeekBackendOwner,
  base_url : String,
  api_key : String,
  on_result : (Array[String]?) -> Unit,
) -> Unit raise {
  ignore(
    owner.queue.try_put(
      OpenSeekWork::DetectModels(base_url, api_key, on_result),
    ),
  )
}

///|
/// Async `v1/models` detection handler. Runs on the worker task group so the
/// native async HTTP client is legal, then reports discovered ids (or None on
/// any failure) back through the `on_result` callback.
async fn openseek_worker_handle_detect(
  base_url : String,
  api_key : String,
  on_result : (Array[String]?) -> Unit,
) -> Unit {
  if base_url.is_empty() {
    on_result(None)
    return
  }
  try {
    let (resp, data) = @http.get(openseek_models_url(base_url), headers={
      "Authorization": "Bearer " + api_key,
      "Accept": "application/json",
    })
    if resp.code >= 200 && resp.code < 300 {
      let ids = openseek_parse_models(data.text())
      on_result(Some(ids))
    } else {
      on_result(None)
    }
  } catch {
    _ => on_result(None)
  }
}

///|
pub async fn openseek_worker_loop(owner : OpenSeekBackendOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let work = owner.queue.get()
      match work {
        RunCommands(commands, emit) =>
          for cmd in commands {
            openseek_worker_handle_command(owner, group, cmd, emit)
          }
        DetectModels(base_url, api_key, on_result) =>
          openseek_worker_handle_detect(base_url, api_key, on_result)
      }
    }
  })
}

///|
async fn openseek_worker_handle_command(
  owner : OpenSeekBackendOwner,
  group : @async.TaskGroup[Unit],
  cmd : @app.AgentCommand,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  match cmd {
    @app.AgentCommand::SendTask(task) =>
      openseek_worker_send_task(owner, group, task, emit)
    @app.AgentCommand::Steer(text) => openseek_worker_steer(owner, text, emit)
    @app.AgentCommand::NewSession(prefix) =>
      openseek_worker_new_session(owner, prefix, emit)
    @app.AgentCommand::SwitchSession(id) =>
      openseek_worker_switch_session(owner, id, emit)
    @app.AgentCommand::SetModel(model_id, api_key, base_url) => {
      let model = match openseek_model_from_string(model_id) {
        Some(model) => model
        None => {
          emit(
            @app.AgentEvent::RuntimeNoticeAdded(
              "Model not supported by OpenSeek yet: " + model_id,
            ),
          )
          return
        }
      }
      let state = openseek_ensure_engine(owner.config, owner.engine)
      state.model = model
      // Swap the live provider connection so the next turn hits the chosen
      // endpoint with the chosen key.
      let api_url = if base_url.is_empty() {
        None
      } else {
        Some(openseek_chat_completions_url(base_url))
      }
      owner.config = { ..owner.config, api_key, api_url, model }
    }
    @app.AgentCommand::SetThinking(choice) => {
      let state = openseek_ensure_engine(owner.config, owner.engine)
      state.thinking = openseek_thinking_from_choice(choice)
    }
    @app.AgentCommand::FetchSessionList =>
      openseek_worker_fetch_sessions(owner.config, emit)
    @app.AgentCommand::Shutdown => ()
  }
}

///|
async fn openseek_worker_fetch_sessions(
  config : OpenSeekBackendConfig,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  let store = @store.SessionStore(config.session_root)
  let listings = store.listings() catch {
    err => {
      mo_workbench_log_caught("session list", err)
      emit(@app.AgentEvent::SessionListed([]))
      emit(@app.AgentEvent::RuntimeNoticeAdded("session list failed: \{err}"))
      return
    }
  }
  let summaries : Array[@app.SessionSummary] = []
  for listing in listings {
    summaries.push(openseek_listing_to_summary(listing))
  }
  emit(@app.AgentEvent::SessionListed(summaries))
}

///|
async fn openseek_worker_new_session(
  owner : OpenSeekBackendOwner,
  prefix : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  let config = owner.config
  let id = openseek_new_session_id(prefix)
  let session = @agent_session.Session(
    id,
    system_prompt=openseek_system_prompt(config.model),
  )
  let store = @store.SessionStore(config.session_root)
  try {
    store.create(session)
    owner.engine.val = Some(openseek_engine_state(config, session))
    emit(@app.AgentEvent::ActiveSessionChanged(id.value()))
    emit(
      @app.AgentEvent::SessionListed([
        @app.session_summary(id=id.value(), first_prompt=""),
      ]),
    )
    emit(@app.AgentEvent::SessionRebuilt([]))
  } catch {
    err => {
      mo_workbench_log_caught("create session", err)
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "create session failed: \{err}",
        ),
      )
    }
  }
}

///|
async fn openseek_worker_switch_session(
  owner : OpenSeekBackendOwner,
  id : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  let config = owner.config
  let store = @store.SessionStore(config.session_root)
  let session_id = @agent_session.SessionId::SessionId(id)
  try {
    let session = store.load(session_id)
    owner.engine.val = Some(openseek_engine_state(config, session))
    emit(@app.AgentEvent::ActiveSessionChanged(id))
    emit(
      @app.AgentEvent::SessionRebuilt(openseek_session_to_agent_events(session)),
    )
  } catch {
    err => {
      mo_workbench_log_caught("load session", err)
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "load session failed: \{err}",
        ),
      )
    }
  }
}

///|
async fn openseek_worker_steer(
  owner : OpenSeekBackendOwner,
  text : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  match owner.engine.val {
    Some(state) =>
      match openseek_active_turn_task(state) {
        Some(_) => {
          state.runtime.queue_steer(@agent_runtime.Prompt(text))
          emit(@app.AgentEvent::RuntimeNoticeAdded("Steer queued: " + text))
          @async.sleep(0)
        }
        None =>
          emit(
            @app.AgentEvent::RuntimeNoticeAdded(
              "Steer ignored: no running turn",
            ),
          )
      }
    None =>
      emit(
        @app.AgentEvent::RuntimeNoticeAdded("Steer ignored: no active session"),
      )
  }
}

///|
fn openseek_worker_send_task(
  owner : OpenSeekBackendOwner,
  group : @async.TaskGroup[Unit],
  task : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  let config = owner.config
  let state = openseek_ensure_engine(config, owner.engine)
  match openseek_active_turn_task(state) {
    Some(_) => {
      emit(
        @app.AgentEvent::RuntimeNoticeAdded(
          "OpenSeek turn already running; use Steer to adjust it.",
        ),
      )
      return
    }
    None => ()
  }
  emit(@app.AgentEvent::ProgressNotice("Running OpenSeek turn..."))
  let runtime = state.runtime
  let scope = @agent_runtime.AgentTaskScope(group)
  let tools = @agent.build_tools(runtime, scope) catch {
    err => {
      mo_workbench_log_caught("agent setup", err)
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "agent setup failed: \{err}",
        ),
      )
      return
    }
  }
  let store = @store.SessionStore(config.session_root)
  let session_ref = Ref(state.session)
  let model = state.model
  let thinking = state.thinking
  let turn = group.spawn() <| async fn() {
    try {
      let _ = @agent.run_turn_in_scope(
        runtime~,
        scope~,
        api_key=config.api_key,
        model~,
        session=session_ref.val,
        task~,
        append_item=async fn(current, item) {
          let next = store.append(current, item) catch {
            _ => current.append(item)
          }
          session_ref.val = next
          state.session = next
          match openseek_item_to_agent_event(item) {
            Some(event) => emit(event)
            None => ()
          }
          next
        },
        thinking~,
        api_url?=config.api_url,
        tools~,
      )
    } catch {
      err => {
        mo_workbench_log_caught("chat/API request (turn)", err)
        emit(
          @app.AgentEvent::TurnTerminal(
            @app.TurnStatus::Failed,
            "turn failed: \{err}",
          ),
        )
      }
    }
    state.turn_task = None
  }
  state.turn_task = Some(turn)
}

///|
fn openseek_active_turn_task(state : OpenSeekEngineState) -> @async.Task[Unit]? {
  match state.turn_task {
    Some(task) =>
      match (task.try_wait() catch { _ => Some(()) }) {
        Some(_) => {
          state.turn_task = None
          None
        }
        None => Some(task)
      }
    None => None
  }
}
