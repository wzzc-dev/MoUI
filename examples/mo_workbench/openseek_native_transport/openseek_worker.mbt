// Async command worker for OpenSeek (must not call run_async_main from UI effects).

///|
enum OpenSeekWork {
  RunCommands(
    Array[@app.AgentCommand],
    (@app.AgentEvent) -> Unit,
  )
}

///|
pub struct OpenSeekBackendOwner {
  config : OpenSeekBackendConfig
  engine : Ref[OpenSeekEngineState?]
  queue : @async.Queue[OpenSeekWork]
}

///|
pub fn OpenSeekBackendOwner::new(
  config : OpenSeekBackendConfig,
) -> OpenSeekBackendOwner {
  {
    config,
    engine: Ref(None),
    queue: @async.Queue(kind=Unbounded),
  }
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
pub async fn openseek_worker_loop(owner : OpenSeekBackendOwner) -> Unit {
  while true {
    let work = owner.queue.get()
    match work {
      RunCommands(commands, emit) =>
        for cmd in commands {
          openseek_worker_handle_command(owner, cmd, emit)
        }
    }
  }
}

///|
async fn openseek_worker_handle_command(
  owner : OpenSeekBackendOwner,
  cmd : @app.AgentCommand,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  match cmd {
    @app.AgentCommand::SendTask(task) =>
      openseek_worker_send_task(owner, task, emit)
    @app.AgentCommand::Steer(text) => openseek_worker_steer(owner, text, emit)
    @app.AgentCommand::NewSession(prefix) =>
      openseek_worker_new_session(owner, prefix, emit)
    @app.AgentCommand::SwitchSession(id) =>
      openseek_worker_switch_session(owner, id, emit)
    @app.AgentCommand::SetModel(choice) => {
      let state = openseek_ensure_engine(owner.config, owner.engine)
      state.model = openseek_model_from_choice(choice)
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
      emit(@app.AgentEvent::SessionListed([]))
      emit(
        @app.AgentEvent::RuntimeNoticeAdded(
          "session list failed: \{err}",
        ),
      )
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
    owner.engine.val = Some({
      session,
      model: config.model,
      thinking: config.thinking,
      turn_task: None,
    })
    emit(@app.AgentEvent::ActiveSessionChanged(id.value()))
    emit(
      @app.AgentEvent::SessionListed([
        @app.session_summary(id=id.value(), first_prompt=""),
      ]),
    )
    emit(@app.AgentEvent::SessionRebuilt([]))
  } catch {
    err =>
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "create session failed: \{err}",
        ),
      )
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
    owner.engine.val = Some({
      session,
      model: config.model,
      thinking: config.thinking,
      turn_task: None,
    })
    emit(@app.AgentEvent::ActiveSessionChanged(id))
    emit(
      @app.AgentEvent::SessionRebuilt(
        openseek_session_to_agent_events(session),
      ),
    )
  } catch {
    err =>
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "load session failed: \{err}",
        ),
      )
  }
}

///|
async fn openseek_worker_steer(
  owner : OpenSeekBackendOwner,
  text : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  match owner.engine.val {
    Some(_) =>
      emit(
        @app.AgentEvent::RuntimeNoticeAdded(
          "Steer noted (shared runtime pending): " + text,
        ),
      )
    None =>
      emit(@app.AgentEvent::RuntimeNoticeAdded("Steer ignored: no active session"))
  }
}

///|
async fn openseek_worker_send_task(
  owner : OpenSeekBackendOwner,
  task : String,
  emit : (@app.AgentEvent) -> Unit,
) -> Unit {
  emit(@app.AgentEvent::ProgressNotice("Running OpenSeek turn..."))
  let config = owner.config
  let state = openseek_ensure_engine(config, owner.engine)
  @async.with_task_group(group => {
    let runtime = @agent_runtime.AgentRuntime(workspace_root=config.workspace_root)
    let scope = @agent_runtime.AgentTaskScope(group)
    let tools = try @agent.build_tools(runtime, scope) catch {
      err => {
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
      let _ = @agent.run_turn_in_scope(
        runtime,
        scope,
        config.api_key,
        model,
        session_ref.val,
        task,
        append_item=async fn(current, item) {
          let next = try store.append(current, item) catch {
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
    }
    state.turn_task = Some(turn)
    try turn.wait() catch {
      err =>
        emit(
          @app.AgentEvent::TurnTerminal(
            @app.TurnStatus::Failed,
            "turn failed: \{err}",
          ),
        )
    }
    state.turn_task = None
  }) catch {
    err =>
      emit(
        @app.AgentEvent::TurnTerminal(
          @app.TurnStatus::Failed,
          "OpenSeek turn error: \{err}",
        ),
      )
  }
}