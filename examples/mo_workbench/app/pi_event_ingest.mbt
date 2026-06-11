///|
fn WorkbenchModel::ingest_agent_start(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  let model = {
    ..self.update_active_session_for_pi(
      status="running",
      active_task="Agent 正在运行",
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
    ..self
    .merge_agent_end_transcript(fields)
    .update_active_session_for_pi(
      status~,
      active_task=if will_retry {
        "Agent 准备自动重试"
      } else {
        "Agent 运行完成"
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
      active_task="Agent 回合 " + turn_index.to_string() + " 开始",
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
      active_task="Agent 回合 " + turn_index.to_string() + " 完成",
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
      active_task=agent_message_task_label(role, "started"),
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
      active_task=agent_message_task_label(role, "streaming"),
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
    ..self
    .merge_live_message_end_transcript(role, fields, preview)
    .update_active_session_for_pi(
      status="active",
      active_task=agent_message_task_label(role, "finished"),
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
fn agent_message_task_label(role : String, state : String) -> String {
  if role == "assistant" {
    match state {
      "started" => "Agent 回复开始"
      "streaming" => "Agent 回复中"
      "finished" => "Agent 回复完成"
      _ => "Agent 回复"
    }
  } else {
    match state {
      "started" => "Agent 消息开始"
      "streaming" => "Agent 消息中"
      "finished" => "Agent 消息完成"
      _ => "Agent 消息"
    }
  }
}

///|
fn WorkbenchModel::merge_live_message_end_transcript(
  self : WorkbenchModel,
  role : String,
  fields : Map[String, Json],
  preview : String,
) -> WorkbenchModel {
  match json_object(fields, "message") {
    Some(message) => self.merge_live_message_fields_transcript(role, message)
    None => self.merge_live_message_transcript(role, preview)
  }
}

///|
fn WorkbenchModel::merge_agent_end_transcript(
  self : WorkbenchModel,
  fields : Map[String, Json],
) -> WorkbenchModel {
  match json_array(fields, "messages") {
    Some(messages) => {
      let mut model = self
      for message in messages {
        match message {
          Object(message_fields) => {
            let role = json_string(message_fields, "role").unwrap_or("message")
            model = model.merge_live_message_fields_transcript(
              role, message_fields,
            )
          }
          _ => ()
        }
      }
      model
    }
    None => self
  }
}

///|
fn WorkbenchModel::merge_live_message_fields_transcript(
  self : WorkbenchModel,
  role : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  if role == "assistant" {
    self
    .merge_live_message_transcript(
      role,
      json_message_visible_content_summary(fields),
    )
    .merge_live_message_transcript(
      "assistantProcess",
      json_message_process_content_summary(fields),
    )
  } else {
    self.merge_live_message_transcript(role, transcript_summary(role, fields))
  }
}

///|
fn WorkbenchModel::merge_live_message_transcript(
  self : WorkbenchModel,
  role : String,
  summary : String,
) -> WorkbenchModel {
  let clean_summary = summary.trim().to_owned()
  if clean_summary == "" || role == "user" {
    self
  } else {
    let transcript = self.transcript.copy()
    let mut found = false
    for index in 0..<transcript.length() {
      if !found &&
        transcript[index].role == role &&
        (
          transcript[index].summary == clean_summary ||
          transcript[index].detail == clean_summary
        ) {
        found = true
      }
    }
    if !found {
      transcript.push(
        TranscriptItem::new(
          id="local-" + role + "-" + transcript.length().to_string(),
          role~,
          summary=clean_summary,
          detail=clean_summary,
          tone=transcript_tone(role),
        ),
      )
    }
    { ..self, transcript, }
  }
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
      active_task="工具运行中：" + tool_name,
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
      active_task="工具输出中：" + tool_name,
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
  let output = tool_result_summary(fields.get("result")).unwrap_or("")
  let output_path = tool_result_output_path(fields.get("result"))
  let output_truncated = tool_result_truncated(fields.get("result"))
  let model = self.mark_tool_command_complete(
    tool_call_id, tool_name, exit_code, is_error, output, output_path, output_truncated,
  )
  {
    ..model.update_active_session_for_pi(
      status=if is_error { "failed" } else { "active" },
      active_task="工具已完成：" + tool_name,
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
        "输入队列已清空"
      } else {
        "输入队列有 " + queued.to_string() + " 条待处理"
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
  let summary = if name == "" { None } else { Some("会话名：" + name) }
  self
  .sync_pi_session_name_binding(
    session_id,
    name,
    last_command="session_info_changed",
  )
  .update_active_session_for_pi(
    status=self.active_session().status,
    active_task=if name == "" {
      "会话信息已更新"
    } else {
      "会话已重命名为 " + name
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
  {
    ..self.update_active_session_for_pi(
      status=self.active_session().status,
      active_task="思考等级：" + level,
    ),
    pi_agent: { ..self.pi_agent, thinking_level: level },
  }.append_ingested_event(
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
      active_task="上下文压缩开始",
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
        "上下文压缩结束，准备重试"
      } else {
        "上下文压缩结束"
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
      active_task="自动重试 " +
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
        "自动重试已恢复"
      } else {
        "自动重试失败"
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
fn WorkbenchModel::ingest_agent_intervention_required(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let event_type = json_string(fields, "type").unwrap_or(
    "intervention_required",
  )
  let data = json_object(fields, "data")
  let source = agent_intervention_source_label(event_type)
  let kind_label = agent_intervention_kind_label(event_type)
  let detail = agent_intervention_first_string(fields, data, [
    "message", "reason", "detail", "title", "prompt", "description",
  ])
  let target = agent_intervention_first_string(fields, data, [
    "command", "toolName", "tool", "path", "scope", "action",
  ])
  let message = agent_intervention_message(kind_label, detail, target)
  let diagnostics = self.diagnostics.copy()
  diagnostics.push(DiagnosticItem::new(source~, severity="warning", message~))
  let model = {
    ..self.update_active_session_for_pi(
      status="waiting",
      active_task=agent_intervention_task_label(event_type),
      unread_events=Some(self.active_session().unread_events + 1),
      summary=Some("等待用户处理 Agent 请求"),
    ),
    diagnostics,
    pi_agent: { ..self.pi_agent, phase: "waiting", message_preview: message },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title=agent_intervention_event_title(event_type),
      detail=session_id + ": " + message,
      tone="warning",
    ),
    status="Pi agent intervention required",
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
fn WorkbenchModel::ingest_plan_update(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let plan = match json_array(fields, "steps") {
    Some(values) => plan_steps_from_values(values)
    None => []
  }
  let active_step = current_plan_step(plan)
  let model = {
    ..self.update_active_session_for_pi(
      status=if plan_has_running_step(plan) { "running" } else { "active" },
      active_task=match active_step {
        Some(step) => "计划：" + step.title
        None => ""
      },
      unread_events=Some(plan_open_count(plan)),
      summary=if plan.is_empty() { None } else { Some(plan_summary(plan)) },
    ),
    plan,
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="plan",
      title="Pi plan updated",
      detail=session_id + ": " + plan.length().to_string() + " steps",
      tone=if plan_has_blocked_step(plan) { "warning" } else { "info" },
    ),
    status="Pi plan updated",
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
fn WorkbenchModel::pi_session_binding_for_id(
  self : WorkbenchModel,
  workbench_session_id : String,
) -> PiSessionBinding {
  for binding in self.pi_session_bindings {
    if binding.workbench_session_id == workbench_session_id {
      return binding
    }
  }
  let session = self.session_for_id(workbench_session_id)
  PiSessionBinding::new(
    workbench_session_id~,
    session_file=session.pi_session_path,
  )
}

///|
fn WorkbenchModel::sync_pi_session_name_binding(
  self : WorkbenchModel,
  workbench_session_id : String,
  name : String,
  last_command~ : String,
) -> WorkbenchModel {
  if name == "" {
    self
  } else {
    let existing = self.pi_session_binding_for_id(workbench_session_id)
    let status = if existing.status == "unbound" {
      "named"
    } else {
      existing.status
    }
    self.upsert_pi_session_binding(
      PiSessionBinding::new(
        workbench_session_id~,
        rpc_session_id=existing.rpc_session_id,
        session_file=existing.session_file,
        session_name=name,
        model=existing.model,
        status~,
        last_command~,
      ),
    )
  }
}

///|
fn WorkbenchModel::update_pi_session_binding_model(
  self : WorkbenchModel,
  workbench_session_id : String,
  model : String,
  last_command~ : String,
) -> WorkbenchModel {
  if model == "" {
    self
  } else {
    let existing = self.pi_session_binding_for_id(workbench_session_id)
    let status = if existing.status == "unbound" {
      "bound"
    } else {
      existing.status
    }
    self.upsert_pi_session_binding(
      PiSessionBinding::new(
        workbench_session_id~,
        rpc_session_id=existing.rpc_session_id,
        session_file=existing.session_file,
        session_name=existing.session_name,
        model~,
        status~,
        last_command~,
      ),
    )
  }
}

///|
fn WorkbenchModel::update_pi_session_binding_command(
  self : WorkbenchModel,
  workbench_session_id : String,
  last_command~ : String,
) -> WorkbenchModel {
  let existing = self.pi_session_binding_for_id(workbench_session_id)
  let status = if existing.status == "unbound" {
    "bound"
  } else {
    existing.status
  }
  self.upsert_pi_session_binding(
    PiSessionBinding::new(
      workbench_session_id~,
      rpc_session_id=existing.rpc_session_id,
      session_file=existing.session_file,
      session_name=existing.session_name,
      model=existing.model,
      status~,
      last_command~,
    ),
  )
}

///|
fn WorkbenchModel::upsert_pi_session_binding(
  self : WorkbenchModel,
  binding : PiSessionBinding,
) -> WorkbenchModel {
  let mut found = false
  let bindings = self.pi_session_bindings.map(existing => {
    if existing.workbench_session_id == binding.workbench_session_id {
      found = true
      binding
    } else {
      existing
    }
  })
  if found {
    { ..self, pi_session_bindings: bindings }
  } else {
    let next = bindings.copy()
    next.push(binding)
    { ..self, pi_session_bindings: next }
  }
}

///|
fn WorkbenchModel::session_for_id(
  self : WorkbenchModel,
  id : String,
) -> WorkbenchSession {
  for session in self.sessions {
    if session.id == id {
      return session
    }
  }
  self.active_session()
}
