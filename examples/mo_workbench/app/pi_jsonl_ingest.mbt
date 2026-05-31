///|
fn WorkbenchModel::ingest_pi_jsonl(
  self : WorkbenchModel,
  session_id : String,
  line : String,
) -> WorkbenchModel {
  let parsed : Json? = Some(@json.parse(line)) catch { _ => None }
  match parsed {
    Some(Object(fields)) => self.ingest_pi_json_object(session_id, fields)
    _ => self
  }
}

///|
fn WorkbenchModel::ingest_pi_json_object(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  match json_string(fields, "type") {
    Some("response") => self.ingest_rpc_response(session_id, fields)
    Some("command_started") => self.ingest_command_started(session_id, fields)
    Some("command_finished") => self.ingest_command_finished(session_id, fields)
    Some("diagnostic") => self.ingest_diagnostic(session_id, fields)
    Some("file_context") => self.ingest_file_context(session_id, fields)
    Some("diff_summary") => self.ingest_diff_summary(session_id, fields)
    _ => self
  }
}

///|
fn WorkbenchModel::ingest_rpc_response(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let command = json_string(fields, "command").unwrap_or("unknown")
  let success = json_bool(fields, "success").unwrap_or(false)
  if success {
    let snapshot = match fields.get("data") {
      Some(Object(data)) => rpc_snapshot_from_data(command, data)
      _ => PiRpcSnapshot::new(command~, success=true)
    }
    self.apply_rpc_success(session_id, snapshot)
  } else {
    let error = json_string(fields, "error").unwrap_or("Pi RPC command failed")
    self.apply_rpc_failure(session_id, command, error)
  }
}

///|
fn WorkbenchModel::apply_rpc_success(
  self : WorkbenchModel,
  session_id : String,
  snapshot : PiRpcSnapshot,
) -> WorkbenchModel {
  let model = self.update_active_session_from_rpc(snapshot)
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi RPC response: " + snapshot.command,
      detail=rpc_response_detail(session_id, snapshot),
      tone="success",
    ),
    status="Pi RPC response applied",
  )
}

///|
fn WorkbenchModel::apply_rpc_failure(
  self : WorkbenchModel,
  session_id : String,
  command : String,
  error : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(
    DiagnosticItem::new(
      source="Pi RPC",
      severity="error",
      message=command + ": " + error,
    ),
  )
  {
    ..self,
    diagnostics,
    pi_rpc: PiRpcSnapshot::new(command~, success=false, error~),
  }.append_ingested_event(
    AgentEvent::new(
      phase="diagnostic",
      title="Pi RPC failed: " + command,
      detail=session_id + ": " + error,
      tone="danger",
    ),
    status="Pi RPC failure applied",
  )
}

///|
fn WorkbenchModel::update_active_session_from_rpc(
  self : WorkbenchModel,
  snapshot : PiRpcSnapshot,
) -> WorkbenchModel {
  let sessions = self.sessions.map(session => {
    if session.id == self.selected_session_id && snapshot.session_id != "" {
      let model_label = if snapshot.model == "" {
        "unknown model"
      } else {
        snapshot.model
      }
      {
        ..session,
        status: if snapshot.pending_message_count == 0 {
          "active"
        } else {
          "running"
        },
        summary: "Pi RPC session " + snapshot.session_id + " on " + model_label,
        unread_events: snapshot.pending_message_count,
      }
    } else {
      session
    }
  })
  { ..self, sessions, pi_rpc: snapshot }
}

///|
fn rpc_snapshot_from_data(
  command : String,
  data : Map[String, Json],
) -> PiRpcSnapshot {
  PiRpcSnapshot::new(
    command~,
    success=true,
    session_id=json_string(data, "sessionId").unwrap_or(""),
    model=json_model_label(data),
    pending_message_count=json_int(data, "pendingMessageCount").unwrap_or(0),
    message_count=json_int(data, "messageCount").unwrap_or(0),
  )
}

///|
fn rpc_response_detail(session_id : String, snapshot : PiRpcSnapshot) -> String {
  let rpc_session = if snapshot.session_id == "" {
    "no Pi session id"
  } else {
    "Pi session " + snapshot.session_id
  }
  session_id +
  ": " +
  rpc_session +
  ", model " +
  (if snapshot.model == "" { "unknown" } else { snapshot.model }) +
  ", pending " +
  snapshot.pending_message_count.to_string()
}

///|
fn WorkbenchModel::ingest_command_started(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  guard json_int(fields, "id") is Some(id) else { return self }
  guard json_string(fields, "command") is Some(command) else { return self }
  let cwd = json_string(fields, "cwd").unwrap_or(
    self.active_session().project_path,
  )
  let status = json_string(fields, "status").unwrap_or("running")
  let model = self.upsert_command(
    CommandRun::new(id~, command~, cwd~, status~, exit_code=None),
  )
  model.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title="Command started: " + command,
      detail="session " + session_id + " in " + cwd,
      tone="info",
    ),
    status="Pi command update applied",
  )
}

///|
fn WorkbenchModel::ingest_command_finished(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  guard json_int(fields, "id") is Some(id) else { return self }
  guard json_int(fields, "exit_code") is Some(exit_code) else { return self }
  let model = self.mark_command_complete(id, exit_code)
  let tone = if exit_code == 0 { "success" } else { "danger" }
  model.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title="Command finished: #" + id.to_string(),
      detail="session " + session_id + " exit code " + exit_code.to_string(),
      tone~,
    ),
    status="Pi command completion applied",
  )
}

///|
fn WorkbenchModel::ingest_diagnostic(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let source = json_string(fields, "source").unwrap_or("Pi")
  guard json_string(fields, "message") is Some(message) else { return self }
  let severity = json_string(fields, "severity").unwrap_or("note")
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(DiagnosticItem::new(source~, severity~, message~))
  { ..self, diagnostics, }.append_ingested_event(
    AgentEvent::new(
      phase="diagnostic",
      title="Diagnostic from " + source,
      detail=session_id + ": " + message,
      tone=diagnostic_tone(severity),
    ),
    status="Pi diagnostic applied",
  )
}

///|
fn WorkbenchModel::ingest_file_context(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  guard json_string(fields, "path") is Some(path) else { return self }
  let id = json_string(fields, "id").unwrap_or(path)
  let summary = json_string(fields, "summary").unwrap_or("Updated by Pi")
  let change_kind = json_string(fields, "change_kind").unwrap_or("modified")
  let lines_changed = json_int(fields, "lines_changed").unwrap_or(0)
  let model = self.upsert_file(
    FileContext::new(id~, path~, summary~, change_kind~, lines_changed~),
  )
  { ..model, diff: { ..model.diff, changed_files: model.files.length() } }.append_ingested_event(
    AgentEvent::new(
      phase="context",
      title="File context updated",
      detail=session_id + ": " + path,
      tone="info",
    ),
    status="Pi file context applied",
  )
}

///|
fn WorkbenchModel::ingest_diff_summary(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let changed_files = json_int(fields, "changed_files").unwrap_or(
    self.diff.changed_files,
  )
  let additions = json_int(fields, "additions").unwrap_or(self.diff.additions)
  let deletions = json_int(fields, "deletions").unwrap_or(self.diff.deletions)
  let status = json_string(fields, "status").unwrap_or(self.diff.status)
  {
    ..self,
    diff: DiffOverview::new(changed_files~, additions~, deletions~, status~),
  }.append_ingested_event(
    AgentEvent::new(
      phase="diff",
      title="Diff summary updated",
      detail=session_id +
        ": +" +
        additions.to_string() +
        " -" +
        deletions.to_string(),
      tone="success",
    ),
    status="Pi diff summary applied",
  )
}

///|
fn WorkbenchModel::upsert_command(
  self : WorkbenchModel,
  run : CommandRun,
) -> WorkbenchModel {
  let mut found = false
  let commands = self.commands.map(command => {
    if command.id == run.id {
      found = true
      run
    } else {
      command
    }
  })
  if found {
    { ..self, commands, }
  } else {
    let next = commands.copy()
    next.push(run)
    { ..self, commands: next }
  }
}

///|
fn WorkbenchModel::upsert_file(
  self : WorkbenchModel,
  file : FileContext,
) -> WorkbenchModel {
  let mut found = false
  let files = self.files.map(existing => {
    if existing.id == file.id || existing.path == file.path {
      found = true
      file
    } else {
      existing
    }
  })
  if found {
    { ..self, files, }
  } else {
    let next = files.copy()
    next.push(file)
    { ..self, files: next }
  }
}

///|
fn WorkbenchModel::append_ingested_event(
  self : WorkbenchModel,
  event : AgentEvent,
  status~ : String,
) -> WorkbenchModel {
  let events = self.events.copy()
  events.push(event)
  { ..self, events, last_status: status }
}

///|
fn json_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_int(fields : Map[String, Json], key : String) -> Int? {
  match fields.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn json_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn json_model_label(fields : Map[String, Json]) -> String {
  match fields.get("model") {
    Some(Object(model)) => {
      let provider = json_string(model, "provider").unwrap_or("")
      let id = json_string(model, "id").unwrap_or(
        json_string(model, "name").unwrap_or(""),
      )
      if provider == "" {
        id
      } else if id == "" {
        provider
      } else {
        provider + "/" + id
      }
    }
    _ => ""
  }
}

///|
fn diagnostic_tone(severity : String) -> String {
  match severity {
    "error" | "failed" => "danger"
    "warning" | "warn" => "warning"
    _ => "info"
  }
}
