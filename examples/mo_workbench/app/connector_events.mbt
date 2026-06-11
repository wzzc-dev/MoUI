///|
fn PiTransportEvent::to_agent_event(self : PiTransportEvent) -> AgentEvent {
  match self {
    ProcessStarted(pid) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC process started",
        detail="pid " + pid,
        tone="success",
      )
    JsonLineSent(session, line) =>
      AgentEvent::new(
        phase="transport",
        title="JSONL sent: " + session,
        detail=line,
        tone="info",
      )
    JsonLineReceived(session, line) =>
      AgentEvent::new(
        phase="agent",
        title="JSONL received: " + session,
        detail=line,
        tone="success",
      )
    ProcessStderr(session, line) =>
      AgentEvent::new(
        phase="transport",
        title="Pi stderr: " + session,
        detail=line,
        tone="warning",
      )
    ProcessExited(code) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC process exited",
        detail="exit code " + code.to_string(),
        tone="warning",
      )
    TransportFailed(reason) =>
      AgentEvent::new(
        phase="transport",
        title="Pi RPC transport failed",
        detail=reason,
        tone="danger",
      )
  }
}

///|
fn AgentConnectorEvent::to_agent_event(
  self : AgentConnectorEvent,
) -> AgentEvent {
  match self {
    ConnectorProfileLoaded(backend_id, profile) =>
      AgentEvent::new(
        phase="connector",
        title="Agent connector profile loaded: " + backend_id,
        detail=profile.name + " · " + profile.protocol_label,
        tone="success",
      )
    ConnectorSessionBound(backend_id, provider_session_id, session_name, model) =>
      AgentEvent::new(
        phase="connector",
        title="Agent connector session bound: " + backend_id,
        detail=connector_session_bound_detail(
          provider_session_id, session_name, model,
        ),
        tone="success",
      )
    ConnectorCommandSent(backend_id, label) =>
      AgentEvent::new(
        phase="connector",
        title="Agent connector command sent: " + backend_id,
        detail=label,
        tone="info",
      )
    ConnectorAssistantMessage(_backend_id, summary, detail) =>
      AgentEvent::new(phase="assistant", title=summary, detail~, tone="success")
    ConnectorRunCompleted(backend_id) =>
      AgentEvent::new(
        phase="connector",
        title="Agent connector run completed",
        detail=backend_id,
        tone="success",
      )
    ConnectorTransportFailed(backend_id, reason) =>
      AgentEvent::new(
        phase="connector",
        title="Agent connector failed: " + backend_id,
        detail=reason,
        tone="danger",
      )
  }
}

///|
fn connector_session_bound_detail(
  provider_session_id : String,
  session_name : String,
  model : String,
) -> String {
  let parts : Array[String] = []
  if provider_session_id != "" {
    parts.push(provider_session_id)
  }
  if session_name != "" {
    parts.push(session_name)
  }
  if model != "" {
    parts.push(model)
  }
  parts.join(" · ")
}

///|
fn WorkbenchModel::receive_connector(
  self : WorkbenchModel,
  event : AgentConnectorEvent,
) -> WorkbenchModel {
  let backend = self.active_agent_backend_profile()
  if !backend.uses_connector_transport() || event.backend_id() != backend.id {
    return self
  }
  let events = self.events.copy()
  events.push(event.to_agent_event())
  let connectors = self.agent_connectors.map(connector => {
    if connector.backend_id == event.backend_id() {
      connector.apply_event(event)
    } else {
      connector
    }
  })
  let model = {
    ..self,
    events,
    agent_connectors: connectors,
    last_status: "Agent connector event received",
  }
  match event {
    ConnectorAssistantMessage(_backend_id, summary, detail) =>
      model.append_connector_assistant_message(summary, detail)
    ConnectorTransportFailed(backend_id, reason) =>
      model.record_connector_failure(backend_id, reason)
    _ => model
  }
}

///|
fn WorkbenchModel::append_connector_assistant_message(
  self : WorkbenchModel,
  summary : String,
  detail : String,
) -> WorkbenchModel {
  let transcript = self.transcript.copy()
  transcript.push(
    TranscriptItem::new(
      id="connector-assistant-" + (transcript.length() + 1).to_string(),
      role="assistant",
      summary~,
      detail~,
      tone="success",
    ),
  )
  { ..self, transcript, last_status: "Agent connector message received" }.scroll_main_to_latest()
}

///|
fn WorkbenchModel::record_connector_failure(
  self : WorkbenchModel,
  backend_id : String,
  reason : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(
    DiagnosticItem::new(
      source="Agent connector " + backend_id,
      severity="error",
      message=reason,
    ),
  )
  { ..self, diagnostics, last_status: "Agent connector failed" }
}

///|
fn WorkbenchModel::record_transport_stderr(
  self : WorkbenchModel,
  session : String,
  line : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(
    DiagnosticItem::new(
      source="Pi stderr",
      severity="warning",
      message=session + ": " + line,
    ),
  )
  { ..self, diagnostics, last_status: "Pi stderr received" }
}

///|
fn toggle_id(values : Array[String], id : String) -> Array[String] {
  if values.any(value => value == id) {
    values.filter(value => value != id)
  } else {
    let next = values.copy()
    next.push(id)
    next
  }
}
