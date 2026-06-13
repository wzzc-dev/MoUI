///|
fn WorkbenchModel::active_session(self : WorkbenchModel) -> WorkbenchSession {
  for session in self.sessions {
    if session.id == self.selected_session_id {
      return session
    }
  }
  self.sessions[0]
}

///|
fn WorkbenchModel::active_agent_backend_profile(
  self : WorkbenchModel,
) -> AgentBackendProfile {
  let id = self.active_session().backend_id
  for profile in agent_backend_profiles() {
    if profile.id == id {
      return profile
    }
  }
  agent_backend_profiles()[0]
}

///|
fn WorkbenchModel::active_agent_backend_capabilities(
  self : WorkbenchModel,
) -> AgentBackendCapabilities {
  self.active_agent_backend_profile().capabilities
}

///|
fn PiTransportState::display_status_label(self : PiTransportState) -> String {
  match self.status {
    Disconnected => "未连接"
    Starting => "启动中"
    Running => "运行中"
    Failed(reason) => "失败：" + reason
  }
}

///|
fn WorkbenchModel::active_agent_backend_status(
  self : WorkbenchModel,
) -> AgentBackendStatus {
  let backend = self.active_agent_backend_profile()
  if backend.uses_pi_transport() {
    let failed = self.transport.status is Failed(_)
    let pending = self.pending_transport_count()
    let sidebar_visible = match self.transport.status {
      Disconnected => pending > 0
      Failed(_) => true
      _ => false
    }
    AgentBackendStatus::new(
      backend_id=backend.id,
      label=backend.label,
      status_label=self.transport.display_status_label(),
      pending_count=pending,
      failed~,
      sidebar_visible~,
      top_bar_visible=failed,
    )
  } else if backend.uses_connector_transport() {
    let connector = self.active_agent_connector_state()
    let failed = connector.status is ConnectorFailed(_)
    let pending = connector.command_queue.length()
    AgentBackendStatus::new(
      backend_id=backend.id,
      label=backend.label,
      status_label=connector.status_label(),
      pending_count=pending,
      failed~,
      sidebar_visible=pending > 0 || failed,
      top_bar_visible=true,
    )
  } else {
    AgentBackendStatus::new(
      backend_id=backend.id,
      label=backend.label,
      top_bar_visible=true,
    )
  }
}

///|
fn WorkbenchModel::active_agent_session_binding(
  self : WorkbenchModel,
) -> AgentSessionBinding {
  let backend = self.active_agent_backend_profile()
  if backend.uses_pi_transport() {
    self
    .active_pi_session_binding()
    .as_agent_session_binding(backend_id=backend.id)
  } else if backend.uses_connector_transport() {
    let connector = self.active_agent_connector_state()
    AgentSessionBinding::new(
      backend_id=backend.id,
      workbench_session_id=self.selected_session_id,
      provider_session_id=connector.provider_session_id,
      session_name=connector.session_name,
      model=connector.model,
      status=if connector.has_session_binding() { "bound" } else { "unbound" },
      last_command=connector.last_command,
    )
  } else {
    AgentSessionBinding::new(
      backend_id=backend.id,
      workbench_session_id=self.selected_session_id,
    )
  }
}

///|
fn WorkbenchModel::active_agent_model_catalog(
  self : WorkbenchModel,
) -> Array[AgentModelInfo] {
  let models : Array[AgentModelInfo] = []
  if !self.active_agent_backend_capabilities().supports_model_catalog {
    return models
  }
  for model in self.model_catalog {
    models.push(model.as_agent_model_info())
  }
  models
}

///|
fn WorkbenchModel::active_agent_command_catalog(
  self : WorkbenchModel,
) -> Array[AgentCommandInfo] {
  let commands : Array[AgentCommandInfo] = []
  if !self.active_agent_backend_capabilities().supports_command_catalog {
    return commands
  }
  let backend = self.active_agent_backend_profile()
  if backend.uses_connector_transport() {
    agent_connector_command_catalog(backend.id)
  } else if backend.uses_pi_transport() {
    for command in self.command_catalog {
      commands.push(command.as_agent_command_info())
    }
    commands
  } else {
    commands
  }
}

///|
fn agent_connector_command_catalog(
  backend_id : String,
) -> Array[AgentCommandInfo] {
  [
    AgentCommandInfo::new(
      name="profile",
      source="ACP",
      description="Inspect the connector agentprofile metadata.",
      source_scope=backend_id,
      source_path="agentprofile.json",
    ),
    AgentCommandInfo::new(
      name="session",
      source="ACP",
      description="Refresh the current connector session binding.",
      source_scope=backend_id,
      source_path="session",
    ),
    AgentCommandInfo::new(
      name="message",
      source="ACP",
      description="Send a fixture ACP message through the connector.",
      source_scope=backend_id,
      source_path="message",
    ),
  ]
}

///|
fn WorkbenchModel::active_agent_session_metrics(
  self : WorkbenchModel,
) -> AgentSessionMetrics {
  let backend = self.active_agent_backend_profile()
  if backend.capabilities.supports_session_stats && backend.uses_pi_transport() {
    self.pi_session_stats.as_agent_session_metrics(
      backend_id=backend.id,
      workbench_session_id=self.selected_session_id,
    )
  } else if backend.capabilities.supports_session_stats &&
    backend.uses_connector_transport() {
    let connector = self.active_agent_connector_state()
    AgentSessionMetrics::new(
      backend_id=backend.id,
      workbench_session_id=self.selected_session_id,
      total_messages=connector.total_messages,
    )
  } else {
    AgentSessionMetrics::new(
      backend_id=backend.id,
      workbench_session_id=self.selected_session_id,
    )
  }
}

///|
fn WorkbenchModel::active_agent_input_settings(
  self : WorkbenchModel,
) -> AgentInputSettings {
  let backend = self.active_agent_backend_profile()
  if backend.uses_pi_transport() &&
    (
      backend.capabilities.supports_thinking_level ||
      backend.capabilities.supports_input_modes
    ) {
    AgentInputSettings::new(
      backend_id=backend.id,
      thinking_level=self.pi_agent.thinking_level,
      steering_mode=self.pi_agent.steering_mode,
      follow_up_mode=self.pi_agent.follow_up_mode,
      queued_steering=self.pi_agent.queued_steering,
      queued_follow_up=self.pi_agent.queued_follow_up,
    )
  } else {
    AgentInputSettings::new(backend_id=backend.id)
  }
}

///|
fn WorkbenchModel::active_pi_session_binding(
  self : WorkbenchModel,
) -> PiSessionBinding {
  for binding in self.pi_session_bindings {
    if binding.workbench_session_id == self.selected_session_id {
      return binding
    }
  }
  let session = self.active_session()
  PiSessionBinding::new(
    workbench_session_id=self.selected_session_id,
    session_file=session.pi_session_path,
  )
}

///|
fn WorkbenchModel::active_agent_connector_state(
  self : WorkbenchModel,
) -> AgentConnectorState {
  let backend = self.active_agent_backend_profile()
  for connector in self.agent_connectors {
    if connector.backend_id == backend.id {
      return connector
    }
  }
  AgentConnectorState::new(
    backend_id=backend.id,
    profile=AgentConnectorProfile::new(
      backend_id=backend.id,
      name=backend.label,
      description=backend.description,
      protocol_label=backend.transport_kind.label(),
    ),
  )
}

///|
fn WorkbenchModel::pending_transport_count(self : WorkbenchModel) -> Int {
  let backend = self.active_agent_backend_profile()
  if backend.uses_pi_transport() {
    self.transport.command_queue.length()
  } else if backend.uses_connector_transport() {
    self.active_agent_connector_state().command_queue.length()
  } else {
    0
  }
}

///|
fn WorkbenchModel::open_diagnostic_count(self : WorkbenchModel) -> Int {
  self.diagnostics.length()
}
