///|
fn WorkbenchModel::update_with_transport(
  self : WorkbenchModel,
  message : WorkbenchMsg,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  self.update_with_agent_connectors(message, transport_runtime, [])
}

///|
fn WorkbenchModel::update_with_agent_connectors(
  self : WorkbenchModel,
  message : WorkbenchMsg,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
) -> WorkbenchUpdate {
  match message {
    SelectSession(id) =>
      self.select_session_with_agent_connectors(
        id, transport_runtime, connector_runtimes,
      )
    ReceiveTransport(event) =>
      self.receive_transport_with_transport(event, transport_runtime)
    ReceiveConnector(event) =>
      WorkbenchUpdate::new(self.receive_connector(event))
    _ =>
      WorkbenchUpdate::from_agent_transport_delta(
        self,
        self.update(message),
        transport_runtime,
        connector_runtimes,
      )
  }
}

///|
fn WorkbenchUpdate::from_agent_transport_delta(
  previous : WorkbenchModel,
  model : WorkbenchModel,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
) -> WorkbenchUpdate {
  let effects : Array[@moui.Effect[WorkbenchMsg]] = []
  let commands = model.transport_commands_added_after(previous)
  let pi_effect = transport_runtime.effect(commands, event => {
    ReceiveTransport(event)
  })
  if !(pi_effect is NoEffect) {
    effects.push(pi_effect)
  }
  for runtime in connector_runtimes {
    let connector_commands = model.connector_commands_added_after(
      previous,
      runtime.backend_id(),
    )
    let effect = runtime.effect(connector_commands, event => {
      ReceiveConnector(event)
    })
    if !(effect is NoEffect) {
      effects.push(effect)
    }
  }
  let effect = if effects.is_empty() {
    @moui.Effect::none()
  } else {
    @moui.Effect::batch(effects)
  }
  WorkbenchUpdate::new(model, effect~)
}

///|
fn WorkbenchModel::transport_commands_added_after(
  self : WorkbenchModel,
  previous : WorkbenchModel,
) -> Array[PiTransportCommand] {
  let previous_queue = previous.transport.command_queue
  let current_queue = self.transport.command_queue
  if current_queue.length() <= previous_queue.length() {
    return []
  }
  for index in 0..<previous_queue.length() {
    if current_queue[index] != previous_queue[index] {
      return []
    }
  }
  current_queue[previous_queue.length():].to_owned()
}

///|
fn WorkbenchModel::connector_commands_added_after(
  self : WorkbenchModel,
  previous : WorkbenchModel,
  backend_id : String,
) -> Array[AgentConnectorCommand] {
  let previous_queue = previous.connector_command_queue(backend_id)
  let current_queue = self.connector_command_queue(backend_id)
  if current_queue.length() <= previous_queue.length() {
    return []
  }
  for index in 0..<previous_queue.length() {
    if current_queue[index] != previous_queue[index] {
      return []
    }
  }
  current_queue[previous_queue.length():].to_owned()
}

///|
fn WorkbenchModel::connector_command_queue(
  self : WorkbenchModel,
  backend_id : String,
) -> Array[AgentConnectorCommand] {
  for connector in self.agent_connectors {
    if connector.backend_id == backend_id {
      return connector.command_queue
    }
  }
  []
}

///|
fn WorkbenchModel::enqueue_active_connector_commands(
  self : WorkbenchModel,
  commands : Array[AgentConnectorCommand],
) -> Array[AgentConnectorState] {
  if commands.is_empty() {
    return self.agent_connectors
  }
  let backend_id = self.active_agent_backend_profile().id
  let connectors : Array[AgentConnectorState] = []
  let mut updated = false
  for connector in self.agent_connectors {
    if connector.backend_id == backend_id {
      connectors.push(connector.enqueue_many(commands))
      updated = true
    } else {
      connectors.push(connector)
    }
  }
  if !updated {
    connectors.push(self.active_agent_connector_state().enqueue_many(commands))
  }
  connectors
}

///|
fn WorkbenchModel::select_session(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  {
    ..self,
    selected_session_id: id,
    selected_panel: "agent",
    main_scroll_offset_y: 0.0,
    last_status: "Workbench session selected",
  }.reset_active_session_surface()
}

///|
fn WorkbenchModel::reset_active_session_surface(
  self : WorkbenchModel,
) -> WorkbenchModel {
  {
    ..self,
    prompt: "",
    selected_panel: "agent",
    composer_controls_expanded: false,
    workspace_details_expanded: false,
    plan: [],
    events: [],
    transcript: [],
    command_catalog: [],
    model_catalog: [],
    fork_messages: [],
    pi_session_stats: PiSessionStatsSnapshot::new(),
    files: [],
    diff: DiffOverview::new(
      changed_files=0,
      additions=0,
      deletions=0,
      status="",
    ),
    commands: [],
    diagnostics: [],
    transport: PiTransportState::new(),
    agent_connectors: default_agent_connector_states(),
    pi_rpc: PiRpcSnapshot::new(),
    pi_agent: PiAgentSnapshot::new(),
    pi_session_bindings: [],
  }
}

///|
fn WorkbenchModel::switch_backend(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  let backend_id = id.trim().to_owned()
  let mut profile : AgentBackendProfile? = None
  for candidate in agent_backend_profiles() {
    if candidate.id == backend_id {
      profile = Some(candidate)
    }
  }
  match profile {
    None => { ..self, last_status: "Agent backend unavailable" }
    Some(value) => {
      let current = self.active_session()
      if current.backend_id == value.id {
        {
          ..self,
          last_status: "Agent backend already selected: " + value.label,
        }
      } else {
        let sessions = self.sessions.map(session => {
          if session.id == self.selected_session_id {
            {
              ..session,
              backend_id: value.id,
              status: "active",
              active_task: "",
              unread_events: 0,
            }
          } else {
            session
          }
        })
        let events : Array[AgentEvent] = []
        events.push(
          AgentEvent::new(
            phase="control",
            title="Agent backend switched",
            detail=value.label,
            tone="info",
          ),
        )
        {
          ..self.reset_active_session_surface(),
          sessions,
          events,
          main_scroll_offset_y: 0.0,
          last_status: "Agent backend switched: " + value.label,
        }
      }
    }
  }
}

///|
fn WorkbenchModel::create_conversation(self : WorkbenchModel) -> WorkbenchModel {
  let current = self.active_session()
  let index = self.next_conversation_index()
  let session = WorkbenchSession::new(
    id="conversation-" + index.to_string(),
    title="新对话 " + index.to_string(),
    project_path=current.project_path,
    backend_id=current.backend_id,
    branch=current.branch,
    status="idle",
    summary="等待任务",
    active_task="",
    unread_events=0,
  )
  let sessions : Array[WorkbenchSession] = [session]
  sessions.append(self.sessions)
  {
    ..self,
    selected_session_id: session.id,
    sessions,
    main_scroll_offset_y: 0.0,
    last_status: "Workbench conversation created",
  }.reset_active_session_surface()
}

///|
fn WorkbenchModel::next_conversation_index(self : WorkbenchModel) -> Int {
  let mut index = 1
  while self.sessions.any(session => {
          session.id == "conversation-" + index.to_string()
        }) {
    index = index + 1
  }
  index
}

///|
fn WorkbenchModel::select_agent(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchModel {
  let clean_id = id.trim().to_owned()
  if clean_id == "" || clean_id == self.selected_agent_id {
    { ..self, selected_agent_id: "", last_status: "Agent focus cleared" }
  } else {
    for profile in workbench_agent_profiles() {
      if profile.id == clean_id {
        return {
          ..self,
          selected_agent_id: clean_id,
          last_status: "Agent focus selected: " + profile.label,
        }
      }
    }
    { ..self, last_status: "Agent focus unavailable" }
  }
}

///|
fn WorkbenchModel::scroll_main_to(
  self : WorkbenchModel,
  offset_y : Double,
) -> WorkbenchModel {
  { ..self, main_scroll_offset_y: workbench_max_double(0.0, offset_y) }
}

///|
fn WorkbenchModel::scroll_main_to_latest(
  self : WorkbenchModel,
) -> WorkbenchModel {
  { ..self, main_scroll_offset_y: 1000000000.0 }
}

///|
fn WorkbenchModel::toggle_command_details(
  self : WorkbenchModel,
  id : Int,
) -> WorkbenchModel {
  let commands = self.commands.map(command => {
    if command.id == id {
      { ..command, details_expanded: !command.details_expanded }
    } else {
      command
    }
  })
  { ..self, commands, last_status: "Command details toggled" }
}

///|
fn WorkbenchModel::toggle_workspace_details(
  self : WorkbenchModel,
) -> WorkbenchModel {
  {
    ..self,
    workspace_details_expanded: !self.workspace_details_expanded,
    last_status: "Workspace evidence details toggled",
  }
}

///|
fn WorkbenchModel::select_session_with_agent_connectors(
  self : WorkbenchModel,
  id : String,
  transport_runtime : PiTransportRuntime,
  connector_runtimes : Array[AgentConnectorRuntime],
) -> WorkbenchUpdate {
  let selected = self.select_session(id)
  let session = selected.active_session()
  let commands = selected.commands_for_session_selection(session)
  let connector_commands = selected.commands_for_connector_session_selection(
    session,
  )
  let model = {
    ..selected,
    transport: selected.transport.enqueue_many(commands),
    agent_connectors: selected.enqueue_active_connector_commands(
      connector_commands,
    ),
  }
  let effects : Array[@moui.Effect[WorkbenchMsg]] = []
  let pi_effect = transport_runtime.effect(commands, event => {
    ReceiveTransport(event)
  })
  if !(pi_effect is NoEffect) {
    effects.push(pi_effect)
  }
  let backend_id = selected.active_agent_backend_profile().id
  for runtime in connector_runtimes {
    if runtime.backend_id() == backend_id {
      let connector_effect = runtime.effect(connector_commands, event => {
        ReceiveConnector(event)
      })
      if !(connector_effect is NoEffect) {
        effects.push(connector_effect)
      }
    }
  }
  let effect = if effects.is_empty() {
    @moui.Effect::none()
  } else {
    @moui.Effect::batch(effects)
  }
  WorkbenchUpdate::new(model, effect~)
}

///|
fn WorkbenchModel::refresh_session(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_session_refresh {
    return { ..self, last_status: "Agent backend does not support refresh" }
  }
  let session = self.active_session()
  let backend = self.active_agent_backend_profile()
  if backend.uses_connector_transport() {
    let commands = self.commands_for_connector_session_selection(session)
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Agent connector refresh queued",
        detail=session.title,
        tone="info",
      ),
    )
    return {
      ..self,
      events,
      agent_connectors: self.enqueue_active_connector_commands(commands),
      last_status: "Agent connector refresh queued",
    }
  }
  let commands = self.commands_for_session_selection(session)
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi session refresh queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi session refresh queued",
  }
}

///|
fn WorkbenchModel::new_session(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_new_session {
    return {
      ..self,
      last_status: "Agent backend does not support new sessions",
    }
  }
  let session = self.active_session()
  let backend = self.active_agent_backend_profile()
  if backend.uses_connector_transport() {
    let commands = self.commands_for_connector_new_session(session)
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Agent connector new session queued",
        detail=session.title,
        tone="info",
      ),
    )
    return {
      ..self,
      events,
      agent_connectors: self.enqueue_active_connector_commands(commands),
      last_status: "Agent connector new session queued",
    }
  }
  let commands = self.commands_for_new_session(session)
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi new session queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi new session queued",
  }
}

///|
fn WorkbenchModel::refresh_fork_messages(
  self : WorkbenchModel,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_fork {
    return { ..self, last_status: "Agent backend does not support forks" }
  }
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    FetchRpcForkMessages(session.id),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi fork discovery queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi fork discovery queued",
  }
}

///|
fn WorkbenchModel::fork_from_message(
  self : WorkbenchModel,
  entry_id : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_fork {
    return { ..self, last_status: "Agent backend does not support forks" }
  }
  let clean_entry_id = entry_id.trim().to_owned()
  if clean_entry_id == "" {
    { ..self, last_status: "Fork entry id is empty" }
  } else {
    let session = self.active_session()
    let commands = self.commands_with_session_start(
      session,
      ForkRpcSession(session.id, clean_entry_id),
    )
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="control",
        title="Pi fork queued",
        detail=session.title + ": " + clean_entry_id,
        tone="info",
      ),
    )
    {
      ..self,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Pi fork queued",
    }
  }
}

///|
fn WorkbenchModel::export_session_html(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_html_export {
    return { ..self, last_status: "Agent backend does not support HTML export" }
  }
  let session = self.active_session()
  let commands = self.commands_with_session_start(
    session,
    ExportRpcSessionHtml(session.id, ""),
  )
  let events = self.events.copy()
  events.push(
    AgentEvent::new(
      phase="control",
      title="Pi HTML export queued",
      detail=session.title,
      tone="info",
    ),
  )
  {
    ..self,
    events,
    transport: self.transport.enqueue_many(commands),
    last_status: "Pi HTML export queued",
  }
}
