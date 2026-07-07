///|
priv enum AcpPendingKind {
  Initialize
  NewSession
  NewSessionForPrompt(String)
  Prompt
  ListSessions
  LoadSession
  ResumeSession
  SetMode
  SetConfig
}

///|
priv struct AcpPending {
  id : String
  kind : AcpPendingKind
  emit : (@app.AgentEvent) -> Unit
}

///|
priv struct AcpPermissionPending {
  request_id : String
  rpc_id : Json
}

///|
priv struct AcpWorkerState {
  mut next_id : Int
  mut active_session_id : String?
  mut session_list_supported : Bool
  mut load_session_supported : Bool
  mut resume_session_supported : Bool
  mut set_mode_supported : Bool
  mut pending : Array[AcpPending]
  mut pending_permissions : Array[AcpPermissionPending]
  mut last_emit : ((@app.AgentEvent) -> Unit)?
  writer : @process.WriteToProcess
}

///|
pub async fn acp_worker_loop(owner : AcpBackendOwner) -> Unit {
  if owner.config.command.trim().to_owned().is_empty() {
    while true {
      match owner.queue.get() {
        RunCommands(commands, emit) =>
          for cmd in commands {
            match cmd {
              @app.AgentCommand::Shutdown => return
              _ =>
                emit(
                  @app.AgentEvent::RuntimeNoticeAdded(
                    "ACP command is not configured",
                  ),
                )
            }
          }
      }
    }
  }
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let (stderr_reader, process_stderr) = @process.read_from_process()
    let process = acp_spawn_process(
      group,
      owner.config,
      stdin=process_stdin,
      stdout=process_stdout,
      stderr=process_stderr,
    )
    let state : AcpWorkerState = {
      next_id: 1,
      active_session_id: None,
      session_list_supported: false,
      load_session_supported: false,
      resume_session_supported: false,
      set_mode_supported: false,
      pending: [],
      pending_permissions: [],
      last_emit: None,
      writer: stdin_writer,
    }
    let reader_task = group.spawn(no_wait=true, allow_failure=true) <| () => {
      acp_stdout_loop(stdout_reader, state)
    }
    let stderr_task = group.spawn(no_wait=true, allow_failure=true) <| () => {
      acp_stderr_loop(stderr_reader, state)
    }
    acp_send_request(
      state,
      Initialize,
      _event => (),
      acp_initialize_request_line,
    )
    while true {
      match owner.queue.get() {
        RunCommands(commands, emit) =>
          for cmd in commands {
            if acp_worker_handle_command(owner.config, state, cmd, emit) {
              state.writer.close()
              reader_task.cancel()
              stderr_task.cancel()
              ignore(process.wait())
              return
            }
          }
      }
    }
  })
}

///|
async fn[X] acp_spawn_process(
  group : @async.TaskGroup[X],
  config : AcpNativeTransportConfig,
  stdin~ : &@process.ProcessInput,
  stdout~ : &@process.ProcessOutput,
  stderr? : &@process.ProcessOutput,
) -> @process.Process {
  if config.process_cwd.trim().to_owned().is_empty() {
    @process.spawn(group, config.command, config.args, stdin~, stdout~, stderr?)
  } else {
    @process.spawn(
      group,
      config.command,
      config.args,
      stdin~,
      stdout~,
      stderr?,
      cwd=config.process_cwd,
    )
  }
}

///|
fn acp_next_id(state : AcpWorkerState) -> String {
  let id = "mo-" + state.next_id.to_string()
  state.next_id = state.next_id + 1
  id
}

///|
async fn acp_write_line(state : AcpWorkerState, line : String) -> Unit {
  state.writer.write(line + "\n") catch {
    _ => ()
  }
}

///|
async fn acp_send_request(
  state : AcpWorkerState,
  kind : AcpPendingKind,
  emit : (@app.AgentEvent) -> Unit,
  params_line : (String) -> String,
) -> Unit {
  let id = acp_next_id(state)
  state.pending.push({ id, kind, emit })
  acp_write_line(state, params_line(id))
}

///|
async fn acp_worker_handle_command(
  config : AcpNativeTransportConfig,
  state : AcpWorkerState,
  cmd : @app.AgentCommand,
  emit : (@app.AgentEvent) -> Unit,
) -> Bool {
  match cmd {
    @app.AgentCommand::NewSession(_) =>
      acp_send_request(state, NewSession, emit, id => {
        acp_new_session_request_line(
          id,
          acp_absolute_workspace(config.workspace),
        )
      })
    @app.AgentCommand::SendTask(task) =>
      match state.active_session_id {
        Some(session_id) =>
          acp_send_request(state, Prompt, emit, id => {
            acp_prompt_request_line(id, session_id, task)
          })
        None => {
          emit(
            @app.AgentEvent::RuntimeNoticeAdded(
              "ACP session is not ready; creating one.",
            ),
          )
          acp_send_request(state, NewSessionForPrompt(task), emit, id => {
            acp_new_session_request_line(
              id,
              acp_absolute_workspace(config.workspace),
            )
          })
        }
      }
    @app.AgentCommand::FetchSessionList =>
      if state.session_list_supported {
        acp_send_request(state, ListSessions, emit, id => {
          acp_list_sessions_request_line(id)
        })
      } else {
        let summaries : Array[@app.SessionSummary] = []
        match state.active_session_id {
          Some(id) =>
            summaries.push(
              @app.session_summary(id~, first_prompt="ACP session"),
            )
          None => ()
        }
        emit(@app.AgentEvent::SessionListed(summaries))
      }
    @app.AgentCommand::SwitchSession(session_id) =>
      if state.load_session_supported {
        acp_send_request(state, LoadSession, emit, id => {
          acp_load_session_request_line(
            id,
            session_id,
            acp_absolute_workspace(config.workspace),
          )
        })
      } else if state.resume_session_supported {
        acp_send_request(state, ResumeSession, emit, id => {
          acp_resume_session_request_line(
            id,
            session_id,
            acp_absolute_workspace(config.workspace),
          )
        })
      } else {
        emit(
          @app.AgentEvent::RuntimeNoticeAdded(
            "ACP agent does not support session load/resume",
          ),
        )
      }
    @app.AgentCommand::CancelTurn =>
      match state.active_session_id {
        Some(session_id) => {
          acp_write_line(state, acp_cancel_notification_line(session_id))
          for pending in state.pending_permissions {
            acp_write_line(
              state,
              acp_permission_response_line(
                pending.rpc_id,
                @app.PermissionOutcome::Cancelled,
              ),
            )
          }
          state.pending_permissions = []
        }
        None => ()
      }
    @app.AgentCommand::SetSessionMode(mode_id) =>
      match state.active_session_id {
        Some(session_id) =>
          if state.set_mode_supported {
            acp_send_request(state, SetMode, emit, id => {
              acp_set_mode_request_line(id, session_id, mode_id)
            })
          } else {
            emit(
              @app.AgentEvent::RuntimeNoticeAdded(
                "ACP agent did not advertise session modes",
              ),
            )
          }
        None =>
          emit(@app.AgentEvent::RuntimeNoticeAdded("ACP session is not ready"))
      }
    @app.AgentCommand::SetSessionConfigOption(config_id, value) =>
      match state.active_session_id {
        Some(session_id) =>
          acp_send_request(state, SetConfig, emit, id => {
            acp_set_config_option_request_line(id, session_id, config_id, value)
          })
        None =>
          emit(@app.AgentEvent::RuntimeNoticeAdded("ACP session is not ready"))
      }
    @app.AgentCommand::RespondPermission(request_id, outcome) =>
      acp_respond_permission(state, request_id, outcome)
    @app.AgentCommand::Steer(text) =>
      emit(
        @app.AgentEvent::RuntimeNoticeAdded(
          "ACP steer is not supported yet: " + text,
        ),
      )
    @app.AgentCommand::SetModel(_, _, _) | @app.AgentCommand::SetThinking(_) =>
      ()
    @app.AgentCommand::Shutdown => return true
  }
  false
}

///|
async fn acp_respond_permission(
  state : AcpWorkerState,
  request_id : String,
  outcome : @app.PermissionOutcome,
) -> Unit {
  let remaining : Array[AcpPermissionPending] = []
  let mut matched : Json? = None
  for pending in state.pending_permissions {
    if pending.request_id == request_id {
      matched = Some(pending.rpc_id)
    } else {
      remaining.push(pending)
    }
  }
  state.pending_permissions = remaining
  match matched {
    Some(id) => acp_write_line(state, acp_permission_response_line(id, outcome))
    None => ()
  }
}

///|
async fn acp_stdout_loop(
  reader : @process.ReadFromProcess,
  state : AcpWorkerState,
) -> Unit {
  defer reader.close()
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    match acp_parse_rpc_line(line) {
      Some(message) => acp_handle_rpc_message(state, message)
      None => ()
    }
  }
}

///|
async fn acp_stderr_loop(
  reader : @process.ReadFromProcess,
  state : AcpWorkerState,
) -> Unit {
  defer reader.close()
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let clean = line.trim(char_set="\r\n").to_owned()
    if !clean.is_empty() {
      let notice = "[ACP stderr] " + clean
      match state.last_emit {
        Some(emit) => emit(@app.AgentEvent::RuntimeNoticeAdded(notice))
        None => println("[Mo Workbench ACP] " + clean)
      }
    }
  }
}

///|
async fn acp_handle_rpc_message(state : AcpWorkerState, message : Json) -> Unit {
  guard message is Json::Object(fields) else { return }
  match fields.get("method") {
    Some(Json::String(method_name)) =>
      acp_handle_agent_method(state, method_name, fields)
    _ =>
      match fields.get("id") {
        Some(id) => acp_handle_response(state, acp_json_id_to_key(id), fields)
        None => ()
      }
  }
}

///|
async fn acp_handle_agent_method(
  state : AcpWorkerState,
  method_name : String,
  fields : Map[String, Json],
) -> Unit {
  let id = acp_json_id_from_fields(fields)
  match method_name {
    "session/update" =>
      match fields.get("params") {
        Some(Json::Object(params)) =>
          match params.get("update") {
            Some(update) => {
              let session_id = acp_json_string_field(params, "sessionId").unwrap_or(
                "",
              )
              for event in acp_session_update_to_events(update) {
                acp_emit_to_active_pending(
                  state,
                  acp_attach_session_id(session_id, event),
                )
              }
            }
            None => ()
          }
        _ => ()
      }
    "session/request_permission" => {
      let request_id = acp_json_id_to_key(id)
      match fields.get("params") {
        Some(params) =>
          match acp_parse_permission_request(request_id, params) {
            Some(request) => {
              state.pending_permissions.push({ request_id, rpc_id: id })
              acp_emit_to_active_pending(
                state,
                @app.AgentEvent::PermissionRequested(request),
              )
            }
            None =>
              acp_write_line(
                state,
                acp_unsupported_method_response_line(id, method_name),
              )
          }
        None =>
          acp_write_line(
            state,
            acp_unsupported_method_response_line(id, method_name),
          )
      }
    }
    _ =>
      if acp_json_id_to_key(id) != "" {
        acp_write_line(
          state,
          acp_unsupported_method_response_line(id, method_name),
        )
      }
  }
}

///|
fn acp_attach_session_id(
  session_id : String,
  event : @app.AgentEvent,
) -> @app.AgentEvent {
  match event {
    @app.AgentEvent::SessionInfoUpdated("", title, updated_at) =>
      @app.AgentEvent::SessionInfoUpdated(session_id, title, updated_at)
    _ => event
  }
}

///|
fn acp_emit_to_active_pending(
  state : AcpWorkerState,
  event : @app.AgentEvent,
) -> Unit {
  match state.last_emit {
    Some(emit) => emit(event)
    None =>
      if !state.pending.is_empty() {
        let pending = state.pending[state.pending.length() - 1]
        (pending.emit)(event)
      }
  }
}

///|
async fn acp_handle_response(
  state : AcpWorkerState,
  id : String,
  fields : Map[String, Json],
) -> Unit {
  let (pending, rest) = acp_take_pending(state.pending, id)
  state.pending = rest
  match pending {
    Some(p) =>
      match acp_response_error_message(fields) {
        Some(message) =>
          (p.emit)(
            @app.AgentEvent::TurnTerminal(@app.TurnStatus::Failed, message),
          )
        None =>
          match acp_response_result(fields) {
            Some(result) => acp_handle_pending_result(state, p, result)
            None => ()
          }
      }
    None => ()
  }
}

///|
fn acp_take_pending(
  pending : Array[AcpPending],
  id : String,
) -> (AcpPending?, Array[AcpPending]) {
  let rest : Array[AcpPending] = []
  let mut found : AcpPending? = None
  for item in pending {
    match found {
      None => if item.id == id { found = Some(item) } else { rest.push(item) }
      Some(_) => rest.push(item)
    }
  }
  (found, rest)
}

///|
async fn acp_handle_pending_result(
  state : AcpWorkerState,
  pending : AcpPending,
  result : Json,
) -> Unit {
  match pending.kind {
    Initialize => acp_handle_initialize_result(state, result)
    NewSession | NewSessionForPrompt(_) | LoadSession | ResumeSession => {
      for event in acp_session_setup_events(result) {
        match event {
          @app.AgentEvent::ActiveSessionChanged(id) =>
            state.active_session_id = Some(id)
          @app.AgentEvent::SessionModeStateChanged(modes) =>
            state.set_mode_supported = !modes.available_modes.is_empty()
          _ => ()
        }
        (pending.emit)(event)
      }
      state.last_emit = Some(pending.emit)
      (pending.emit)(@app.AgentEvent::SessionRebuilt([]))
      match pending.kind {
        NewSessionForPrompt(task) =>
          match state.active_session_id {
            Some(session_id) =>
              acp_send_request(state, Prompt, pending.emit, id => {
                acp_prompt_request_line(id, session_id, task)
              })
            None => ()
          }
        _ => ()
      }
    }
    Prompt => (pending.emit)(acp_prompt_stop_event(result))
    ListSessions =>
      (pending.emit)(
        @app.AgentEvent::SessionListed(acp_parse_session_list(result)),
      )
    SetMode => ()
    SetConfig =>
      match result {
        Json::Object(fields) =>
          match fields.get("configOptions") {
            Some(Json::Array(values)) =>
              (pending.emit)(
                @app.AgentEvent::SessionConfigOptionsChanged(
                  acp_parse_config_options(values),
                ),
              )
            _ => ()
          }
        _ => ()
      }
  }
}

///|
fn acp_handle_initialize_result(state : AcpWorkerState, result : Json) -> Unit {
  guard result is Json::Object(fields) else { return }
  match fields.get("agentCapabilities") {
    Some(Json::Object(caps)) => {
      state.load_session_supported = acp_json_bool_field(caps, "loadSession").unwrap_or(
        false,
      )
      match caps.get("sessionCapabilities") {
        Some(Json::Object(session_caps)) => {
          state.session_list_supported = session_caps.get("list") != None
          state.resume_session_supported = session_caps.get("resume") != None
        }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn acp_absolute_workspace(workspace : String) -> String {
  let clean = workspace.trim().to_owned()
  if clean.is_empty() {
    return @env.current_dir().unwrap_or(".")
  }
  if clean.has_prefix("/") {
    clean
  } else {
    let cwd = @env.current_dir().unwrap_or(".")
    if cwd.has_suffix("/") {
      cwd + clean
    } else {
      cwd + "/" + clean
    }
  }
}
