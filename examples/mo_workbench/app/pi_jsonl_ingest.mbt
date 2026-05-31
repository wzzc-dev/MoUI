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
    Some("agent_start") => self.ingest_agent_start(session_id)
    Some("agent_end") => self.ingest_agent_end(session_id, fields)
    Some("turn_start") => self.ingest_turn_start(session_id, fields)
    Some("turn_end") => self.ingest_turn_end(session_id, fields)
    Some("message_start") => self.ingest_message_start(session_id, fields)
    Some("message_update") => self.ingest_message_update(session_id, fields)
    Some("message_end") => self.ingest_message_end(session_id, fields)
    Some("tool_execution_start") =>
      self.ingest_tool_execution_start(session_id, fields)
    Some("tool_execution_update") =>
      self.ingest_tool_execution_update(session_id, fields)
    Some("tool_execution_end") =>
      self.ingest_tool_execution_end(session_id, fields)
    Some("queue_update") => self.ingest_queue_update(session_id, fields)
    Some("session_info_changed") =>
      self.ingest_session_info_changed(session_id, fields)
    Some("thinking_level_changed") =>
      self.ingest_thinking_level_changed(session_id, fields)
    Some("compaction_start") => self.ingest_compaction_start(session_id, fields)
    Some("compaction_end") => self.ingest_compaction_end(session_id, fields)
    Some("auto_retry_start") => self.ingest_auto_retry_start(session_id, fields)
    Some("auto_retry_end") => self.ingest_auto_retry_end(session_id, fields)
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
fn WorkbenchModel::ingest_agent_start(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  let model = {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi agent run in progress",
    ),
    pi_agent: { ..self.pi_agent, phase: "running", message_preview: "" },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi agent started",
      detail=session_id + ": agent loop entered",
      tone="success",
    ),
    status="Pi agent started",
  )
}

///|
fn WorkbenchModel::ingest_agent_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let message_count = json_array_count(fields, "messages")
  let will_retry = json_bool(fields, "willRetry").unwrap_or(false)
  let phase = if will_retry { "retrying" } else { "idle" }
  let status = if will_retry { "running" } else { "active" }
  let retry_suffix = if will_retry { ", retry scheduled" } else { "" }
  let detail = session_id +
    ": " +
    message_count.to_string() +
    " messages" +
    retry_suffix
  let model = {
    ..self.update_active_session_for_pi(
      status~,
      active_task=if will_retry {
        "Pi agent is preparing an automatic retry"
      } else {
        "Pi agent run completed"
      },
    ),
    pi_agent: {
      ..self.pi_agent,
      phase,
      active_tool_call_id: "",
      active_tool_name: "",
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title=if will_retry {
        "Pi agent ended, retry pending"
      } else {
        "Pi agent ended"
      },
      detail~,
      tone=if will_retry { "warning" } else { "success" },
    ),
    status="Pi agent completion applied",
  )
}

///|
fn WorkbenchModel::ingest_turn_start(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let turn_index = json_int(fields, "turnIndex").unwrap_or(
    self.pi_agent.turn_index + 1,
  )
  let model = {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi agent turn " + turn_index.to_string() + " started",
    ),
    pi_agent: { ..self.pi_agent, phase: "turn", turn_index },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi turn started: #" + turn_index.to_string(),
      detail=session_id,
      tone="info",
    ),
    status="Pi turn started",
  )
}

///|
fn WorkbenchModel::ingest_turn_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let turn_index = json_int(fields, "turnIndex").unwrap_or(
    self.pi_agent.turn_index,
  )
  let tool_count = json_array_count(fields, "toolResults")
  let preview = json_message_preview(fields)
  let preview_detail = if preview == "" { "turn complete" } else { preview }
  let tool_suffix = if tool_count == 0 {
    ""
  } else {
    ", " + tool_count.to_string() + " tool results"
  }
  let detail = session_id + ": " + preview_detail + tool_suffix
  let model = {
    ..self.update_active_session_for_pi(
      status="active",
      active_task="Pi agent turn " + turn_index.to_string() + " completed",
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: "turn complete",
      turn_index,
      message_preview: preview,
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi turn ended: #" + turn_index.to_string(),
      detail~,
      tone="success",
    ),
    status="Pi turn completion applied",
  )
}

///|
fn WorkbenchModel::ingest_message_start(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let role = json_message_role(fields)
  let preview = json_message_preview(fields)
  let model = {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi " + role + " message started",
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: "message",
      message_role: role,
      message_preview: preview,
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase=role,
      title="Pi message started: " + role,
      detail=message_event_detail(session_id, preview),
      tone="info",
    ),
    status="Pi message started",
  )
}

///|
fn WorkbenchModel::ingest_message_update(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let role = json_message_role(fields)
  let preview = json_message_preview(fields)
  let detail = assistant_update_detail(fields, preview)
  let model = {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi " + role + " message streaming",
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: "streaming",
      message_role: role,
      message_preview: if preview == "" {
        detail
      } else {
        preview
      },
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase=role,
      title="Pi message update: " + role,
      detail=message_event_detail(session_id, detail),
      tone="info",
    ),
    status="Pi assistant message streaming",
  )
}

///|
fn WorkbenchModel::ingest_message_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let role = json_message_role(fields)
  let preview = json_message_preview(fields)
  let model = {
    ..self.update_active_session_for_pi(
      status="active",
      active_task="Pi " + role + " message finished",
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: "message complete",
      message_role: role,
      message_preview: preview,
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase=role,
      title="Pi message ended: " + role,
      detail=message_event_detail(session_id, preview),
      tone="success",
    ),
    status="Pi message completion applied",
  )
}

///|
fn WorkbenchModel::ingest_tool_execution_start(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let tool_call_id = json_string(fields, "toolCallId").unwrap_or("")
  let tool_name = json_string(fields, "toolName").unwrap_or("tool")
  let command = tool_command_summary(tool_name, fields.get("args"))
  let cwd = tool_command_cwd(
    self.active_session().project_path,
    fields.get("args"),
  )
  let id = self
    .command_id_for_tool_call(tool_call_id)
    .unwrap_or(self.next_command_id())
  let model = self.upsert_command(
    CommandRun::new(
      id~,
      command~,
      cwd~,
      status="running",
      exit_code=None,
      tool_call_id~,
    ),
  )
  {
    ..model.update_active_session_for_pi(
      status="running",
      active_task="Pi tool running: " + tool_name,
    ),
    pi_agent: {
      ..model.pi_agent,
      phase: "tool",
      active_tool_call_id: tool_call_id,
      active_tool_name: tool_name,
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title="Pi tool started: " + tool_name,
      detail=session_id + ": " + command,
      tone="info",
    ),
    status="Pi tool execution started",
  )
}

///|
fn WorkbenchModel::ingest_tool_execution_update(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let tool_name = json_string(fields, "toolName").unwrap_or("tool")
  let detail = tool_result_summary(fields.get("partialResult")).unwrap_or(
    "partial result",
  )
  {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi tool streaming: " + tool_name,
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: "tool streaming",
      active_tool_call_id: json_string(fields, "toolCallId").unwrap_or(
        self.pi_agent.active_tool_call_id,
      ),
      active_tool_name: tool_name,
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title="Pi tool update: " + tool_name,
      detail=session_id + ": " + detail,
      tone="info",
    ),
    status="Pi tool execution streaming",
  )
}

///|
fn WorkbenchModel::ingest_tool_execution_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let tool_call_id = json_string(fields, "toolCallId").unwrap_or("")
  let tool_name = json_string(fields, "toolName").unwrap_or("tool")
  let is_error = json_bool(fields, "isError").unwrap_or(false)
  let exit_code = tool_result_exit_code(fields.get("result")).unwrap_or(
    if is_error {
      1
    } else {
      0
    },
  )
  let model = self.mark_tool_command_complete(
    tool_call_id, tool_name, exit_code, is_error,
  )
  {
    ..model.update_active_session_for_pi(
      status=if is_error { "failed" } else { "active" },
      active_task="Pi tool finished: " + tool_name,
    ),
    pi_agent: {
      ..model.pi_agent,
      phase: if is_error {
        "tool failed"
      } else {
        "tool complete"
      },
      active_tool_call_id: "",
      active_tool_name: "",
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title="Pi tool ended: " + tool_name,
      detail=session_id + ": exit code " + exit_code.to_string(),
      tone=if is_error || exit_code != 0 { "danger" } else { "success" },
    ),
    status="Pi tool execution completed",
  )
}

///|
fn WorkbenchModel::ingest_queue_update(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let steering = json_array_count(fields, "steering")
  let follow_up = json_array_count(fields, "followUp")
  let queued = steering + follow_up
  let model = {
    ..self.update_active_session_for_pi(
      status=if queued == 0 { "active" } else { "running" },
      active_task=if queued == 0 {
        "Pi prompt queue drained"
      } else {
        "Pi prompt queue has " + queued.to_string() + " pending inputs"
      },
      unread_events=Some(queued),
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: if queued == 0 {
        "queue idle"
      } else {
        "queue pending"
      },
      queued_steering: steering,
      queued_follow_up: follow_up,
    },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi queue updated",
      detail=session_id +
        ": steering " +
        steering.to_string() +
        ", follow-up " +
        follow_up.to_string(),
      tone=if queued == 0 { "success" } else { "warning" },
    ),
    status="Pi queue update applied",
  )
}

///|
fn WorkbenchModel::ingest_session_info_changed(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let name = json_string(fields, "name").unwrap_or("")
  let summary = if name == "" { None } else { Some("Pi session name: " + name) }
  self
  .update_active_session_for_pi(
    status=self.active_session().status,
    active_task=if name == "" {
      "Pi session info changed"
    } else {
      "Pi session renamed to " + name
    },
    summary~,
  )
  .append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi session info changed",
      detail=if name == "" { session_id } else { session_id + ": " + name },
      tone="info",
    ),
    status="Pi session info applied",
  )
}

///|
fn WorkbenchModel::ingest_thinking_level_changed(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let level = json_string(fields, "level").unwrap_or("default")
  { ..self, pi_agent: { ..self.pi_agent, thinking_level: level } }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi thinking level changed",
      detail=session_id + ": " + level,
      tone="info",
    ),
    status="Pi thinking level applied",
  )
}

///|
fn WorkbenchModel::ingest_compaction_start(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let reason = json_string(fields, "reason").unwrap_or("manual")
  {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi context compaction started",
    ),
    pi_agent: { ..self.pi_agent, phase: "compacting" },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi compaction started",
      detail=session_id + ": " + reason,
      tone="warning",
    ),
    status="Pi compaction started",
  )
}

///|
fn WorkbenchModel::ingest_compaction_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let aborted = json_bool(fields, "aborted").unwrap_or(false)
  let will_retry = json_bool(fields, "willRetry").unwrap_or(false)
  let error = json_string(fields, "errorMessage").unwrap_or("")
  {
    ..self.update_active_session_for_pi(
      status=if aborted || error != "" { "failed" } else { "active" },
      active_task=if will_retry {
        "Pi compaction ended; retry scheduled"
      } else {
        "Pi context compaction ended"
      },
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: if aborted {
        "compaction aborted"
      } else {
        "compaction complete"
      },
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi compaction ended",
      detail=if error == "" { session_id } else { session_id + ": " + error },
      tone=if aborted || error != "" { "danger" } else { "success" },
    ),
    status="Pi compaction ended",
  )
}

///|
fn WorkbenchModel::ingest_auto_retry_start(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let attempt = json_int(fields, "attempt").unwrap_or(1)
  let max_attempts = json_int(fields, "maxAttempts").unwrap_or(attempt)
  let error = json_string(fields, "errorMessage").unwrap_or("retry requested")
  {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Pi auto retry " +
        attempt.to_string() +
        "/" +
        max_attempts.to_string(),
    ),
    pi_agent: { ..self.pi_agent, phase: "retrying" },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi auto retry started",
      detail=session_id + ": " + error,
      tone="warning",
    ),
    status="Pi auto retry started",
  )
}

///|
fn WorkbenchModel::ingest_auto_retry_end(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let success = json_bool(fields, "success").unwrap_or(false)
  let attempt = json_int(fields, "attempt").unwrap_or(1)
  let final_error = json_string(fields, "finalError").unwrap_or("")
  let final_error_suffix = if final_error == "" {
    ""
  } else {
    ", " + final_error
  }
  {
    ..self.update_active_session_for_pi(
      status=if success { "active" } else { "failed" },
      active_task=if success {
        "Pi auto retry recovered"
      } else {
        "Pi auto retry failed"
      },
    ),
    pi_agent: {
      ..self.pi_agent,
      phase: if success {
        "active"
      } else {
        "failed"
      },
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi auto retry ended",
      detail=session_id +
        ": attempt " +
        attempt.to_string() +
        final_error_suffix,
      tone=if success { "success" } else { "danger" },
    ),
    status="Pi auto retry ended",
  )
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
fn WorkbenchModel::update_active_session_for_pi(
  self : WorkbenchModel,
  status~ : String,
  active_task~ : String,
  unread_events? : Int? = None,
  summary? : String? = None,
) -> WorkbenchModel {
  let sessions = self.sessions.map(session => {
    if session.id == self.selected_session_id {
      {
        ..session,
        status,
        active_task,
        unread_events: unread_events.unwrap_or(session.unread_events),
        summary: summary.unwrap_or(session.summary),
      }
    } else {
      session
    }
  })
  { ..self, sessions, }
}

///|
fn WorkbenchModel::next_command_id(self : WorkbenchModel) -> Int {
  let mut next = self.commands.length() + 1
  for command in self.commands {
    if command.id >= next {
      next = command.id + 1
    }
  }
  next
}

///|
fn WorkbenchModel::command_id_for_tool_call(
  self : WorkbenchModel,
  tool_call_id : String,
) -> Int? {
  if tool_call_id == "" {
    None
  } else {
    for command in self.commands {
      if command.tool_call_id == tool_call_id {
        return Some(command.id)
      }
    }
    None
  }
}

///|
fn WorkbenchModel::mark_tool_command_complete(
  self : WorkbenchModel,
  tool_call_id : String,
  tool_name : String,
  exit_code : Int,
  is_error : Bool,
) -> WorkbenchModel {
  let status = if is_error || exit_code != 0 { "failed" } else { "passed" }
  let mut found = false
  let commands = self.commands.map(command => {
    if tool_call_id != "" && command.tool_call_id == tool_call_id {
      found = true
      { ..command, status, exit_code: Some(exit_code) }
    } else {
      command
    }
  })
  if found {
    { ..self, commands, }
  } else {
    let next = commands.copy()
    next.push(
      CommandRun::new(
        id=self.next_command_id(),
        command=tool_name,
        cwd=self.active_session().project_path,
        status~,
        exit_code=Some(exit_code),
        tool_call_id~,
      ),
    )
    { ..self, commands: next }
  }
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
fn json_object(fields : Map[String, Json], key : String) -> Map[String, Json]? {
  match fields.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn json_array(fields : Map[String, Json], key : String) -> Array[Json]? {
  match fields.get(key) {
    Some(Array(value)) => Some(value)
    _ => None
  }
}

///|
fn json_array_count(fields : Map[String, Json], key : String) -> Int {
  match json_array(fields, key) {
    Some(value) => value.length()
    None => 0
  }
}

///|
fn json_message_role(fields : Map[String, Json]) -> String {
  match json_object(fields, "message") {
    Some(message) => json_string(message, "role").unwrap_or("message")
    None => "message"
  }
}

///|
fn json_message_preview(fields : Map[String, Json]) -> String {
  match json_object(fields, "message") {
    Some(message) => json_message_content_summary(message)
    None => ""
  }
}

///|
fn json_message_content_summary(message : Map[String, Json]) -> String {
  match message.get("content") {
    Some(String(value)) => value
    Some(Array(values)) => json_content_array_summary(values)
    _ =>
      json_string(message, "display").unwrap_or(
        json_string(message, "errorMessage").unwrap_or(""),
      )
  }
}

///|
fn json_content_array_summary(values : Array[Json]) -> String {
  let segments : Array[String] = []
  for value in values {
    let segment = json_content_block_summary(value)
    if segment != "" {
      segments.push(segment)
    }
  }
  segments.join("")
}

///|
fn json_content_block_summary(value : Json) -> String {
  match value {
    String(text) => text
    Object(fields) =>
      match json_string(fields, "type") {
        Some("text") => json_string(fields, "text").unwrap_or("")
        Some("thinking") => "thinking"
        Some("toolCall") =>
          "tool call: " + json_string(fields, "name").unwrap_or("tool")
        Some("image") => "[image]"
        _ => json_string(fields, "text").unwrap_or("")
      }
    _ => ""
  }
}

///|
fn message_event_detail(session_id : String, detail : String) -> String {
  if detail == "" {
    session_id
  } else {
    session_id + ": " + detail
  }
}

///|
fn assistant_update_detail(
  fields : Map[String, Json],
  fallback : String,
) -> String {
  match json_object(fields, "assistantMessageEvent") {
    Some(event) => {
      let event_type = json_string(event, "type").unwrap_or("update")
      let value = json_string(event, "delta").unwrap_or(
        json_string(event, "content").unwrap_or(fallback),
      )
      if value == "" {
        event_type
      } else {
        event_type + ": " + value
      }
    }
    None => if fallback == "" { "assistant message update" } else { fallback }
  }
}

///|
fn tool_command_summary(tool_name : String, args : Json?) -> String {
  match args {
    Some(Object(fields)) => {
      let command = json_string(fields, "command").unwrap_or(
        json_string(fields, "cmd").unwrap_or(""),
      )
      if command != "" {
        command
      } else {
        let path = json_string(fields, "path").unwrap_or(
          json_string(fields, "filePath").unwrap_or(
            json_string(fields, "file_path").unwrap_or(""),
          ),
        )
        if path == "" {
          tool_name
        } else {
          tool_name + ": " + path
        }
      }
    }
    Some(String(value)) => tool_name + ": " + value
    Some(value) => tool_name + ": " + value.stringify()
    None => tool_name
  }
}

///|
fn tool_command_cwd(default_cwd : String, args : Json?) -> String {
  match args {
    Some(Object(fields)) => json_string(fields, "cwd").unwrap_or(default_cwd)
    _ => default_cwd
  }
}

///|
fn tool_result_exit_code(result : Json?) -> Int? {
  match result {
    Some(Object(fields)) =>
      match json_int(fields, "exitCode") {
        Some(code) => Some(code)
        None =>
          match json_int(fields, "exit_code") {
            Some(code) => Some(code)
            None =>
              match json_int(fields, "code") {
                Some(code) => Some(code)
                None =>
                  match json_object(fields, "details") {
                    Some(details) => json_int(details, "exitCode")
                    None => None
                  }
              }
          }
      }
    _ => None
  }
}

///|
fn tool_result_summary(result : Json?) -> String? {
  match result {
    Some(Object(fields)) =>
      match json_string(fields, "output") {
        Some(output) => Some(output)
        None =>
          match json_array(fields, "content") {
            Some(content) => Some(json_content_array_summary(content))
            None =>
              match json_object(fields, "details") {
                Some(details) => json_string(details, "output")
                None => None
              }
          }
      }
    Some(String(value)) => Some(value)
    Some(value) => Some(value.stringify())
    None => None
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
