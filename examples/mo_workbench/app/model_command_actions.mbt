///|
fn WorkbenchModel::receive_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
) -> WorkbenchModel {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return self
  }
  let events = self.events.copy()
  events.push(event.to_agent_event())
  let model = {
    ..self,
    events,
    transport: self.transport.apply_event(event),
    last_status: "Pi transport event received",
  }
  match event {
    JsonLineReceived(session, line) => model.ingest_pi_jsonl(session, line)
    ProcessStderr(session, line) => model.record_transport_stderr(session, line)
    _ => model
  }
}

///|
fn WorkbenchModel::queue_command(
  self : WorkbenchModel,
  command : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return {
      ..self,
      last_status: "Agent backend does not support shell commands",
    }
  }
  let session = self.active_session()
  let commands = self.commands.copy()
  let transport_commands = self.commands_with_session_start(
    session,
    RunShellCommand(session.id, command),
  )
  commands.push(
    CommandRun::new(
      id=commands.length() + 1,
      command~,
      cwd=session.project_path,
      status="queued",
    ),
  )
  {
    ..self,
    commands,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Command queued for Pi RPC bash",
  }.scroll_main_to_latest()
}

///|
fn WorkbenchModel::queue_focused_checks(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return {
      ..self,
      last_status: "Agent backend does not support shell commands",
    }
  }
  let session = self.active_session()
  let commands = self.commands.copy()
  for preset in workbench_check_presets() {
    commands.push(
      CommandRun::new(
        id=commands.length() + 1,
        command=preset.command,
        cwd=session.project_path,
        status="queued",
      ),
    )
  }
  let transport_commands = self.commands_for_focused_checks(session)
  {
    ..self,
    commands,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Focused checks queued for Pi RPC bash",
  }.scroll_main_to_latest()
}

///|
fn WorkbenchModel::inspect_command_run(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> WorkbenchModel {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    { ..self, last_status: "Command evidence is empty" }
  } else {
    let prompt = self.command_evidence_payload(
      command, status, cwd, output_path,
    )
    self.queue_agent_prompt_action(
      prompt,
      event_title="Command evidence queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued command evidence for Pi RPC",
    )
  }
}

///|
fn WorkbenchModel::fix_command_run(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> WorkbenchModel {
  let clean_command = command.trim().to_owned()
  let clean_output_path = output_path.trim().to_owned()
  if clean_command == "" && clean_output_path == "" {
    { ..self, last_status: "Command evidence is empty" }
  } else {
    let prompt = self.command_fix_payload(command, status, cwd, output_path)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Command fix queued",
      event_detail=prompt,
      tone="warning",
      pi_status="Queued command fix for Pi RPC",
    )
  }
}

///|
fn command_evidence_prompt(
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  let command = command.trim().to_owned()
  let status = status.trim().to_owned()
  let cwd = cwd.trim().to_owned()
  let output_path = output_path.trim().to_owned()
  let command_label = if command == "" { "command run" } else { command }
  let prefix = if output_path == "" {
    "Inspect command run: " + command_label
  } else {
    "Inspect command output for " + command_label + ": " + output_path
  }
  let context : Array[String] = []
  if status != "" {
    context.push("status " + status)
  }
  if cwd != "" {
    context.push("cwd " + cwd)
  }
  if context.is_empty() {
    prefix
  } else {
    prefix + " (" + context.join(", ") + ")"
  }
}

///|
fn WorkbenchModel::command_evidence_payload(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  self.composer_prompt_payload(
    command_evidence_prompt(command, status, cwd, output_path),
  )
}

///|
fn command_fix_prompt(
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  let command = command.trim().to_owned()
  let status = status.trim().to_owned()
  let cwd = cwd.trim().to_owned()
  let output_path = output_path.trim().to_owned()
  let command_label = if command == "" { "command run" } else { command }
  let prefix = if output_path == "" {
    "Fix failed command run: " + command_label
  } else {
    "Fix failed command " + command_label + " using output " + output_path
  }
  let context : Array[String] = []
  if status != "" {
    context.push("status " + status)
  }
  if cwd != "" {
    context.push("cwd " + cwd)
  }
  if context.is_empty() {
    prefix
  } else {
    prefix + " (" + context.join(", ") + ")"
  }
}

///|
fn WorkbenchModel::command_fix_payload(
  self : WorkbenchModel,
  command : String,
  status : String,
  cwd : String,
  output_path : String,
) -> String {
  self.composer_prompt_payload(
    command_fix_prompt(command, status, cwd, output_path),
  )
}

///|
fn WorkbenchModel::mark_command_complete(
  self : WorkbenchModel,
  id : Int,
  code : Int,
) -> WorkbenchModel {
  let commands = self.commands.map(command => {
    if command.id == id {
      {
        ..command,
        status: if code == 0 {
          "passed"
        } else {
          "failed"
        },
        exit_code: Some(code),
      }
    } else {
      command
    }
  })
  { ..self, commands, last_status: "Command " + id.to_string() + " completed" }
}

///|
fn WorkbenchModel::sync_session_name(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return {
      ..self,
      last_status: "Agent backend does not support session name sync",
    }
  }
  let session = self.active_session()
  let name = session.title
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcSessionName(session.id, name),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi session name sync queued",
      detail=session.id + ": " + name,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi session name sync queued",
  }
}

///|
fn WorkbenchModel::set_model(
  self : WorkbenchModel,
  provider : String,
  id : String,
  label : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_model_catalog {
    return {
      ..self,
      last_status: "Agent backend does not support model selection",
    }
  }
  let provider = provider.trim().to_owned()
  let id = id.trim().to_owned()
  if provider == "" || id == "" {
    { ..self, last_status: "Pi model selection is empty" }
  } else {
    let session = self.active_session()
    let model_label = if label == "" { provider + "/" + id } else { label }
    let transport_commands = self.commands_with_session_start(
      session,
      SetRpcModel(session.id, provider, id),
    )
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Pi model set queued",
        detail=model_label,
        tone="info",
      ),
    )
    {
      ..self,
      events,
      transport: self.transport.enqueue_many(transport_commands),
      last_status: "Pi model set queued",
    }
  }
}

///|
fn WorkbenchModel::cycle_model(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_model_catalog {
    return {
      ..self,
      last_status: "Agent backend does not support model selection",
    }
  }
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CycleRpcModel(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi model cycle queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi model cycle queued",
  }
}

///|
fn WorkbenchModel::compact_session(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_context_compaction {
    return { ..self, last_status: "Agent backend does not support compaction" }
  }
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CompactRpcSession(session.id, ""),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi compact queued",
      detail=session.title,
      tone="warning",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi compact queued",
  }
}

///|
fn WorkbenchModel::cycle_thinking_level(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_thinking_level {
    return {
      ..self,
      last_status: "Agent backend does not support thinking level",
    }
  }
  let session = self.active_session()
  let transport_commands = self.commands_with_session_start(
    session,
    CycleRpcThinkingLevel(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi thinking level cycle queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(transport_commands),
    last_status: "Pi thinking level cycle queued",
  }
}

///|
fn WorkbenchModel::toggle_steering_mode(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.steering_mode)
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcSteeringMode(session.id, mode),
  )
  self
  .record_agent_mode_event(
    title="Pi steering mode queued",
    detail=mode,
    status="Pi steering mode queued",
  )
  .set_agent_modes(steering_mode=Some(mode), follow_up_mode=None)
  .enqueue_transport_commands(transport_commands)
}

///|
fn WorkbenchModel::toggle_follow_up_mode(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let session = self.active_session()
  let mode = next_agent_input_mode(self.pi_agent.follow_up_mode)
  let transport_commands = self.commands_with_session_start(
    session,
    SetRpcFollowUpMode(session.id, mode),
  )
  self
  .record_agent_mode_event(
    title="Pi follow-up mode queued",
    detail=mode,
    status="Pi follow-up mode queued",
  )
  .set_agent_modes(steering_mode=None, follow_up_mode=Some(mode))
  .enqueue_transport_commands(transport_commands)
}

///|
fn WorkbenchModel::record_agent_mode_event(
  self : WorkbenchModel,
  title~ : String,
  detail~ : String,
  status~ : String,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(AgentEvent::new(phase="control", title~, detail~, tone="info"))
  { ..self, events, last_status: status }
}

///|
fn WorkbenchModel::set_agent_modes(
  self : WorkbenchModel,
  steering_mode~ : String?,
  follow_up_mode~ : String?,
) -> WorkbenchModel {
  {
    ..self,
    pi_agent: {
      ..self.pi_agent,
      steering_mode: steering_mode.unwrap_or(self.pi_agent.steering_mode),
      follow_up_mode: follow_up_mode.unwrap_or(self.pi_agent.follow_up_mode),
    },
  }
}

///|
fn WorkbenchModel::enqueue_transport_commands(
  self : WorkbenchModel,
  commands : Array[PiTransportCommand],
) -> WorkbenchModel {
  { ..self, transport: self.transport.enqueue_many(commands) }
}

///|
fn next_agent_input_mode(mode : String) -> String {
  if mode == "all" {
    "one-at-a-time"
  } else {
    "all"
  }
}

///|
fn WorkbenchModel::cancel_run(self : WorkbenchModel) -> WorkbenchModel {
  if self.active_agent_backend_profile().uses_connector_transport() {
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Connector run cancellation queued",
        detail=session.title,
        tone="warning",
      ),
    )
    return {
      ..self,
      events,
      agent_connectors: self.enqueue_active_connector_commands([
        CancelConnectorRun(session.id),
      ]),
      last_status: "Connector cancellation queued",
    }
  }
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return {
      ..self,
      last_status: "Agent backend does not support cancellation",
    }
  }
  let session = self.active_session()
  let transport_command = self.cancel_transport_command(session)
  let shell_cancel = transport_command is CancelShellCommand(_)
  let model = if shell_cancel {
    self.mark_next_shell_command_cancelling(session)
  } else {
    self
  }
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title=if shell_cancel {
        "Shell command cancellation requested"
      } else {
        "Run cancellation requested"
      },
      detail=session.title,
      tone="warning",
    ),
  )
  {
    ..model,
    events,
    transport: model.transport.enqueue(transport_command),
    last_status: if shell_cancel {
      "Shell command cancellation queued"
    } else {
      "Cancellation queued"
    },
  }
}

///|
fn WorkbenchModel::cancel_transport_command(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> PiTransportCommand {
  if self.has_active_shell_command(session) {
    CancelShellCommand(session.id)
  } else {
    CancelRpcRun(session.id)
  }
}

///|
fn WorkbenchModel::has_active_shell_command(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Bool {
  self.commands.any(command => command.is_active_shell_for_session(session))
}

///|
fn WorkbenchModel::mark_next_shell_command_cancelling(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> WorkbenchModel {
  let mut target_id : Int? = None
  for command in self.commands {
    if target_id is None && command.is_active_shell_for_session(session) {
      target_id = Some(command.id)
    }
  }
  match target_id {
    Some(id) => {
      let commands = self.commands.map(command => {
        if command.id == id {
          { ..command, status: "cancelling" }
        } else {
          command
        }
      })
      { ..self, commands, }
    }
    None => self
  }
}

///|
fn CommandRun::is_active_shell_for_session(
  self : CommandRun,
  session : WorkbenchSession,
) -> Bool {
  self.cwd == session.project_path &&
  self.tool_call_id == "" &&
  shell_command_status_is_active(self.status)
}

///|
fn shell_command_status_is_active(status : String) -> Bool {
  status == "queued" || status == "running" || status == "cancelling"
}

///|
fn WorkbenchModel::commands_for_session_selection(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return []
  }
  if session.pi_session_path == "" {
    [
      StartRpc(session.id, session.project_path),
      FetchRpcAvailableModels(session.id),
      FetchRpcMessages(session.id),
      FetchRpcForkMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
    ]
  } else {
    [
      SwitchRpcSession(session.id, session.pi_session_path),
      StartRpc(session.id, session.project_path),
      FetchRpcAvailableModels(session.id),
      FetchRpcMessages(session.id),
      FetchRpcForkMessages(session.id),
      FetchRpcCommands(session.id),
      FetchRpcSessionStats(session.id),
    ]
  }
}

///|
fn WorkbenchModel::commands_for_new_session(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().supports_new_session {
    return []
  }
  [NewRpcSession(session.id)]
}

///|
fn WorkbenchModel::commands_for_session_replacement_refresh(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return []
  }
  let commands : Array[PiTransportCommand] = []
  commands.push(StartRpc(session.id, session.project_path))
  commands.push(FetchRpcAvailableModels(session.id))
  commands.push(FetchRpcMessages(session.id))
  commands.push(FetchRpcForkMessages(session.id))
  commands.push(FetchRpcCommands(session.id))
  commands.push(FetchRpcSessionStats(session.id))
  commands
}

///|
fn WorkbenchModel::commands_for_conversation_refresh(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return []
  }
  [
    FetchRpcMessages(session.id),
    FetchRpcForkMessages(session.id),
    FetchRpcSessionStats(session.id),
  ]
}

///|
fn WorkbenchModel::commands_for_focused_checks(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_capabilities().supports_shell_commands {
    return []
  }
  let commands : Array[PiTransportCommand] = []
  if self.transport.status is Disconnected {
    commands.push(StartRpc(session.id, session.project_path))
  }
  for preset in workbench_check_presets() {
    commands.push(RunShellCommand(session.id, preset.command))
  }
  commands
}

///|
fn WorkbenchModel::commands_with_session_start(
  self : WorkbenchModel,
  session : WorkbenchSession,
  command : PiTransportCommand,
) -> Array[PiTransportCommand] {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return []
  }
  let commands : Array[PiTransportCommand] = []
  if self.transport.status is Disconnected {
    commands.push(StartRpc(session.id, session.project_path))
  }
  commands.push(command)
  commands
}

///|
fn WorkbenchModel::commands_for_connector_session_selection(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[AgentConnectorCommand] {
  if !self.active_agent_backend_profile().uses_connector_transport() {
    return []
  }
  [
    StartConnectorSession(session.id, session.project_path),
    RefreshConnectorSession(session.id),
  ]
}

///|
fn WorkbenchModel::commands_for_connector_new_session(
  self : WorkbenchModel,
  session : WorkbenchSession,
) -> Array[AgentConnectorCommand] {
  if !self.active_agent_backend_profile().uses_connector_transport() {
    return []
  }
  self.connector_commands_with_session_start(
    session,
    NewConnectorSession(session.id),
  )
}

///|
fn WorkbenchModel::connector_commands_with_session_start(
  self : WorkbenchModel,
  session : WorkbenchSession,
  command : AgentConnectorCommand,
) -> Array[AgentConnectorCommand] {
  if !self.active_agent_backend_profile().uses_connector_transport() {
    return []
  }
  let commands : Array[AgentConnectorCommand] = []
  let connector = self.active_agent_connector_state()
  if !connector.has_session_binding() && !connector.has_active_transport() {
    commands.push(StartConnectorSession(session.id, session.project_path))
  }
  commands.push(command)
  commands
}
