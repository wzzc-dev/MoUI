///|
fn WorkbenchModel::receive_transport_with_transport(
  self : WorkbenchModel,
  event : PiTransportEvent,
  transport_runtime : PiTransportRuntime,
) -> WorkbenchUpdate {
  if !self.active_agent_backend_profile().uses_pi_transport() {
    return WorkbenchUpdate::new(self)
  }
  let model = self.receive_transport(event)
  match event.session_replacement_refresh() {
    Some((session_id, title, status)) => {
      let session = model.session_for_id(session_id)
      let commands = if status == "Pi transcript refresh queued" {
        model.commands_for_conversation_refresh(session)
      } else {
        model.commands_for_session_replacement_refresh(session)
      }
      let events = model.events.copy()
      events.push(
        AgentEvent::new(
          phase="control",
          title~,
          detail=session.title,
          tone="info",
        ),
      )
      WorkbenchUpdate::new(
        {
          ..model,
          events,
          transport: model.transport.enqueue_many(commands),
          last_status: status,
        },
        effect=transport_runtime.effect(commands, event => {
          ReceiveTransport(event)
        }),
      )
    }
    None => WorkbenchUpdate::new(model)
  }
}

///|
fn WorkbenchModel::dispatch_prompt(self : WorkbenchModel) -> WorkbenchModel {
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.dispatch_prompt_payload(prompt)
    let session = self.active_session()
    let backend = self.active_agent_backend_profile()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="User request queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendUserInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    let connector_commands = self.connector_commands_with_session_start(
      session,
      SendConnectorMessage(session.id, payload),
    )
    let transcript = if backend.uses_pi_transport() {
      self.transcript_with_local_user_message(payload)
    } else if backend.uses_connector_transport() {
      self.transcript_with_local_user_message(payload)
    } else {
      self.transcript_with_fixture_reply(payload, backend)
    }
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      workspace_details_expanded: false,
      events,
      transcript,
      transport: self.transport.enqueue_many(commands),
      agent_connectors: self.enqueue_active_connector_commands(
        connector_commands,
      ),
      last_status: if backend.uses_pi_transport() {
        "Queued prompt for Pi JSONL RPC"
      } else if backend.uses_connector_transport() {
        "Queued prompt for Agent connector"
      } else {
        local_agent_prompt_status(backend)
      },
    }.scroll_main_to_latest()
  }
}

///|
fn WorkbenchModel::dispatch_steering(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Steering input queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendSteeringInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued steering input for Pi RPC",
    }.scroll_main_to_latest()
  }
}

///|
fn WorkbenchModel::dispatch_follow_up(self : WorkbenchModel) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_input_modes {
    return { ..self, last_status: "Agent backend does not support input modes" }
  }
  let prompt = self.prompt.trim().to_owned()
  if prompt == "" {
    { ..self, last_status: "Prompt is empty" }
  } else {
    let payload = self.composer_prompt_payload(prompt)
    let session = self.active_session()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title="Follow-up input queued",
        detail=payload,
        tone="info",
      ),
    )
    let command = SendFollowUpInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      composer_controls_expanded: false,
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: "Queued follow-up input for Pi RPC",
    }.scroll_main_to_latest()
  }
}

///|
fn WorkbenchModel::composer_prompt_payload(
  self : WorkbenchModel,
  prompt : String,
) -> String {
  let context = self.composer_context_prompt_label()
  if context == "" {
    prompt
  } else {
    "Context: " + context + "\n\nTask: " + prompt
  }
}

///|
fn WorkbenchModel::transcript_with_local_user_message(
  self : WorkbenchModel,
  payload : String,
) -> Array[TranscriptItem] {
  let transcript = self.transcript.copy()
  transcript.push(
    TranscriptItem::new(
      id="local-user-" + (transcript.length() + 1).to_string(),
      role="user",
      summary=payload,
      detail=payload,
      tone="info",
    ),
  )
  transcript
}

///|
fn WorkbenchModel::transcript_with_fixture_reply(
  self : WorkbenchModel,
  payload : String,
  backend : AgentBackendProfile,
) -> Array[TranscriptItem] {
  let transcript = self.transcript_with_local_user_message(payload)
  transcript.push(
    TranscriptItem::new(
      id="fixture-agent-" + transcript.length().to_string(),
      role="assistant",
      summary=backend.label + " 已接收任务",
      detail="本地后端会保持会话流转，不启动外部传输。",
      tone="success",
    ),
  )
  transcript
}

///|
fn WorkbenchModel::dispatch_prompt_payload(
  self : WorkbenchModel,
  prompt : String,
) -> String {
  if is_slash_prompt(prompt) {
    prompt
  } else {
    self.composer_prompt_payload(prompt)
  }
}

///|
fn is_slash_prompt(prompt : String) -> Bool {
  let clean = prompt.trim().to_owned()
  let chars = clean.to_array()
  chars.length() > 0 && chars[0] == '/'
}

///|
fn WorkbenchModel::composer_context_prompt_label(
  self : WorkbenchModel,
) -> String {
  let labels : Array[String] = []
  for id in ["repo", "examples", "evidence", "session"] {
    if self.context_is_selected(id) {
      labels.push(context_prompt_label(id))
    }
  }
  for id in self.expanded_context {
    if !known_context_id(id) {
      labels.push(id)
    }
  }
  match self.active_agent_profile() {
    Some(profile) => labels.push("agent focus: " + profile.prompt_hint)
    None => ()
  }
  labels.join(", ")
}

///|
fn WorkbenchModel::context_is_selected(
  self : WorkbenchModel,
  id : String,
) -> Bool {
  self.expanded_context.any(value => value == id)
}

///|
fn context_prompt_label(id : String) -> String {
  match id {
    "repo" => "repo"
    "examples" => "examples"
    "evidence" => "current evidence"
    "session" => "agent session"
    _ => id
  }
}

///|
fn known_context_id(id : String) -> Bool {
  id == "repo" || id == "examples" || id == "evidence" || id == "session"
}

///|
fn WorkbenchModel::invoke_command(
  self : WorkbenchModel,
  name : String,
) -> WorkbenchModel {
  if !self.active_agent_backend_capabilities().supports_command_catalog {
    return { ..self, last_status: "Agent backend does not support commands" }
  }
  let command_name = name.trim().to_owned()
  if command_name == "" {
    { ..self, last_status: "Pi command is empty" }
  } else {
    let prompt = "/" + command_name
    let session = self.active_session()
    let backend = self.active_agent_backend_profile()
    let events = self.events.copy()
    events.push(
      AgentEvent::new(
        phase="user",
        title=if backend.uses_connector_transport() {
          "Agent connector command queued"
        } else {
          "Pi command queued"
        },
        detail=prompt,
        tone="info",
      ),
    )
    if backend.uses_connector_transport() {
      let commands = self.connector_commands_with_session_start(
        session,
        InvokeConnectorCommand(session.id, command_name),
      )
      {
        ..self,
        prompt: "",
        events,
        agent_connectors: self.enqueue_active_connector_commands(commands),
        last_status: "Queued command for Agent connector",
      }
    } else {
      let command = SendUserInput(session.id, prompt)
      let commands = self.commands_with_session_start(session, command)
      {
        ..self,
        prompt: "",
        events,
        transport: self.transport.enqueue_many(commands),
        last_status: "Queued Pi command for RPC",
      }
    }
  }
}

///|
fn WorkbenchModel::queue_agent_prompt_action(
  self : WorkbenchModel,
  payload : String,
  event_title~ : String,
  event_detail~ : String,
  tone~ : String,
  pi_status~ : String,
) -> WorkbenchModel {
  let backend = self.active_agent_backend_profile()
  let session = self.active_session()
  let events = self.events.copy()
  events.push(
    AgentEvent::new(phase="user", title=event_title, detail=event_detail, tone~),
  )
  if backend.uses_pi_transport() {
    let command = SendUserInput(session.id, payload)
    let commands = self.commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      events,
      transport: self.transport.enqueue_many(commands),
      last_status: pi_status,
    }.scroll_main_to_latest()
  } else if backend.uses_connector_transport() {
    let command = SendConnectorMessage(session.id, payload)
    let commands = self.connector_commands_with_session_start(session, command)
    {
      ..self,
      prompt: "",
      events,
      transcript: self.transcript_with_local_user_message(payload),
      agent_connectors: self.enqueue_active_connector_commands(commands),
      last_status: "Queued prompt for Agent connector",
    }.scroll_main_to_latest()
  } else {
    {
      ..self,
      prompt: "",
      events,
      transcript: self.transcript_with_fixture_reply(payload, backend),
      last_status: local_agent_prompt_status(backend),
    }.scroll_main_to_latest()
  }
}

///|
fn local_agent_prompt_status(backend : AgentBackendProfile) -> String {
  "已交给" + backend.label + "后端"
}

///|
fn WorkbenchModel::follow_transcript(
  self : WorkbenchModel,
  role : String,
  summary : String,
  detail : String,
) -> WorkbenchModel {
  let clean_summary = summary.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_summary == "" && clean_detail == "" {
    { ..self, last_status: "Transcript item is empty" }
  } else {
    let prompt = transcript_follow_up_prompt(role, summary, detail)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Transcript follow-up queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued transcript follow-up for Pi RPC",
    )
  }
}

///|
fn transcript_follow_up_prompt(
  role : String,
  summary : String,
  detail : String,
) -> String {
  let role = role.trim().to_owned()
  let summary = summary.trim().to_owned()
  let detail = detail.trim().to_owned()
  let label = if role == "" { "message" } else { role + " transcript" }
  let body = if summary == "" {
    detail
  } else if detail == "" {
    summary
  } else {
    summary + ". Context: " + detail
  }
  "Follow up on " + label + ": " + body
}

///|
fn WorkbenchModel::follow_activity(
  self : WorkbenchModel,
  phase : String,
  title : String,
  detail : String,
) -> WorkbenchModel {
  let clean_title = title.trim().to_owned()
  let clean_detail = detail.trim().to_owned()
  if clean_title == "" && clean_detail == "" {
    { ..self, last_status: "Activity item is empty" }
  } else {
    let prompt = activity_follow_up_prompt(phase, title, detail)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Activity follow-up queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued activity follow-up for Pi RPC",
    )
  }
}

///|
fn activity_follow_up_prompt(
  phase : String,
  title : String,
  detail : String,
) -> String {
  let phase = phase.trim().to_owned()
  let title = title.trim().to_owned()
  let detail = detail.trim().to_owned()
  let label = if phase == "" { "activity" } else { phase + " activity" }
  let body = if title == "" {
    detail
  } else if detail == "" {
    title
  } else {
    title + ". Context: " + detail
  }
  "Follow up on " + label + ": " + body
}

///|
fn WorkbenchModel::inspect_file(
  self : WorkbenchModel,
  path : String,
) -> WorkbenchModel {
  let file_path = path.trim().to_owned()
  if file_path == "" {
    { ..self, last_status: "File context is empty" }
  } else {
    let prompt = self.file_inspection_payload(file_path)
    self.queue_agent_prompt_action(
      prompt,
      event_title="File context queued",
      event_detail=file_path,
      tone="info",
      pi_status="Queued file context for Pi RPC",
    )
  }
}

///|
fn WorkbenchModel::review_diff(self : WorkbenchModel) -> WorkbenchModel {
  if self.diff.has_context() {
    let prompt = self.diff_review_payload()
    self.queue_agent_prompt_action(
      prompt,
      event_title="Diff review queued",
      event_detail=prompt,
      tone="info",
      pi_status="Queued diff review for Pi RPC",
    )
  } else {
    { ..self, last_status: "Diff context is empty" }
  }
}

///|
fn WorkbenchModel::diff_review_prompt(self : WorkbenchModel) -> String {
  "Review diff: " +
  self.diff.status_label() +
  ", " +
  self.diff.changed_files.to_string() +
  " files, +" +
  self.diff.additions.to_string() +
  " -" +
  self.diff.deletions.to_string()
}

///|
fn WorkbenchModel::file_inspection_payload(
  self : WorkbenchModel,
  file_path : String,
) -> String {
  self.composer_prompt_payload("Inspect " + file_path)
}

///|
fn WorkbenchModel::diff_review_payload(self : WorkbenchModel) -> String {
  self.composer_prompt_payload(self.diff_review_prompt())
}

///|
fn DiffOverview::has_context(self : DiffOverview) -> Bool {
  self.changed_files > 0 ||
  self.additions > 0 ||
  self.deletions > 0 ||
  self.status.trim().to_owned() != ""
}

///|
fn DiffOverview::status_label(self : DiffOverview) -> String {
  let status = self.status.trim().to_owned()
  if status == "" {
    "changed"
  } else {
    status
  }
}

///|
fn WorkbenchModel::fix_diagnostic(
  self : WorkbenchModel,
  source : String,
  severity : String,
  message : String,
) -> WorkbenchModel {
  let clean_source = source.trim().to_owned()
  let clean_message = message.trim().to_owned()
  if clean_source == "" && clean_message == "" {
    { ..self, last_status: "Diagnostic is empty" }
  } else {
    let prompt = self.diagnostic_fix_payload(source, severity, message)
    self.queue_agent_prompt_action(
      prompt,
      event_title="Diagnostic fix queued",
      event_detail=prompt,
      tone="warning",
      pi_status="Queued diagnostic fix for Pi RPC",
    )
  }
}

///|
fn diagnostic_fix_prompt(
  source : String,
  severity : String,
  message : String,
) -> String {
  let source = source.trim().to_owned()
  let severity = severity.trim().to_owned()
  let message = message.trim().to_owned()
  if diagnostic_source_is_agent_intervention(source) {
    let detail = if message == "" { "" } else { ": " + message }
    return "Resolve " + source + " request" + detail
  }
  let label = if severity == "" {
    "diagnostic"
  } else {
    severity + " diagnostic"
  }
  let origin = if source == "" { "" } else { " from " + source }
  let detail = if message == "" { "" } else { ": " + message }
  "Fix " + label + origin + detail
}

///|
fn diagnostic_source_is_agent_intervention(source : String) -> Bool {
  source == "Agent approval" ||
  source == "Agent permission" ||
  source == "Agent input" ||
  source == "Agent intervention"
}

///|
fn WorkbenchModel::diagnostic_fix_payload(
  self : WorkbenchModel,
  source : String,
  severity : String,
  message : String,
) -> String {
  self.composer_prompt_payload(diagnostic_fix_prompt(source, severity, message))
}
