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
    Some("approval_required") =>
      self.ingest_agent_intervention_required(session_id, fields)
    Some("permission_required") =>
      self.ingest_agent_intervention_required(session_id, fields)
    Some("input_required") =>
      self.ingest_agent_intervention_required(session_id, fields)
    Some("file_context") => self.ingest_file_context(session_id, fields)
    Some("diff_summary") => self.ingest_diff_summary(session_id, fields)
    Some("plan_update") => self.ingest_plan_update(session_id, fields)
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
    match command {
      "switch_session" => self.apply_switch_session_success(session_id, fields)
      "new_session" => self.apply_new_session_success(session_id, fields)
      "fork" => self.apply_fork_success(session_id, fields)
      "bash" => self.apply_bash_success(session_id, fields)
      "get_messages" => self.apply_get_messages_success(session_id, fields)
      "get_available_models" =>
        self.apply_get_available_models_success(session_id, fields)
      "get_fork_messages" =>
        self.apply_get_fork_messages_success(session_id, fields)
      "get_commands" => self.apply_get_commands_success(session_id, fields)
      "get_session_stats" =>
        self.apply_get_session_stats_success(session_id, fields)
      "export_html" => self.apply_export_html_success(session_id, fields)
      "set_model" => self.apply_set_model_success(session_id, fields)
      "cycle_model" => self.apply_cycle_model_success(session_id, fields)
      "compact" => self.apply_compact_success(session_id, fields)
      "cycle_thinking_level" =>
        self.apply_cycle_thinking_level_success(session_id, fields)
      "steer" => self.apply_steer_success(session_id)
      "follow_up" => self.apply_follow_up_success(session_id)
      "set_steering_mode" => self.apply_set_steering_mode_success(session_id)
      "set_follow_up_mode" => self.apply_set_follow_up_mode_success(session_id)
      "set_session_name" => self.apply_set_session_name_success(session_id)
      _ => {
        let snapshot = match fields.get("data") {
          Some(Object(data)) => rpc_snapshot_from_data(command, data)
          _ => PiRpcSnapshot::new(command~, success=true)
        }
        self.apply_rpc_success(session_id, snapshot)
      }
    }
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
  let model = self.update_session_from_rpc(session_id, snapshot)
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
fn WorkbenchModel::apply_get_messages_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let messages = match json_object(fields, "data") {
    Some(data) =>
      match json_array(data, "messages") {
        Some(values) => transcript_items_from_messages(values)
        None => []
      }
    None => []
  }
  {
    ..self,
    transcript: messages,
    pi_rpc: {
      ..self.pi_rpc,
      command: "get_messages",
      success: true,
      message_count: messages.length(),
      error: "",
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi messages refreshed",
      detail=session_id + ": " + messages.length().to_string() + " messages",
      tone="success",
    ),
    status="Pi messages refreshed",
  )
}

///|
fn WorkbenchModel::apply_get_available_models_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let models = match json_object(fields, "data") {
    Some(data) =>
      match json_array(data, "models") {
        Some(values) => pi_model_infos_from_values(values)
        None => []
      }
    None => []
  }
  {
    ..self,
    model_catalog: models,
    pi_rpc: {
      ..self.pi_rpc,
      command: "get_available_models",
      success: true,
      error: "",
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi models refreshed",
      detail=session_id + ": " + models.length().to_string() + " models",
      tone="success",
    ),
    status="Pi models refreshed",
  )
}

///|
fn WorkbenchModel::apply_get_fork_messages_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let messages = match json_object(fields, "data") {
    Some(data) =>
      match json_array(data, "messages") {
        Some(values) => pi_fork_messages_from_values(values)
        None => []
      }
    None => []
  }
  {
    ..self,
    fork_messages: messages,
    pi_rpc: {
      ..self.pi_rpc,
      command: "get_fork_messages",
      success: true,
      error: "",
    },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi fork messages refreshed",
      detail=session_id + ": " + messages.length().to_string() + " fork points",
      tone="success",
    ),
    status="Pi fork messages refreshed",
  )
}

///|
fn WorkbenchModel::apply_set_session_name_success(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  let binding = self.pi_session_binding_for_id(session_id)
  let session = self.session_for_id(session_id)
  let name = if binding.session_name == "" {
    session.title
  } else {
    binding.session_name
  }
  {
    ..self.sync_pi_session_name_binding(
      session_id,
      name,
      last_command="set_session_name",
    ),
    pi_rpc: PiRpcSnapshot::new(command="set_session_name", success=true),
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi session name synced",
      detail=session_id + ": " + name,
      tone="success",
    ),
    status="Pi session name synced",
  )
}

///|
fn WorkbenchModel::apply_get_commands_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let commands = match json_object(fields, "data") {
    Some(data) =>
      match json_array(data, "commands") {
        Some(values) => pi_command_infos_from_values(values)
        None => []
      }
    None => []
  }
  {
    ..self,
    command_catalog: commands,
    pi_rpc: { ..self.pi_rpc, command: "get_commands", success: true, error: "" },
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi commands refreshed",
      detail=session_id + ": " + commands.length().to_string() + " commands",
      tone="success",
    ),
    status="Pi commands refreshed",
  )
}

///|
fn WorkbenchModel::apply_get_session_stats_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let stats = match json_object(fields, "data") {
    Some(data) => pi_session_stats_from_data(data)
    None => PiSessionStatsSnapshot::new()
  }
  {
    ..self.update_session_from_stats(session_id, stats),
    pi_rpc: {
      ..self.pi_rpc,
      command: "get_session_stats",
      success: true,
      session_id: if stats.session_id == "" {
        self.pi_rpc.session_id
      } else {
        stats.session_id
      },
      session_file: if stats.session_file == "" {
        self.pi_rpc.session_file
      } else {
        stats.session_file
      },
      message_count: stats.total_messages,
      error: "",
    },
    pi_session_stats: stats,
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi session stats refreshed",
      detail=session_stats_detail(session_id, stats),
      tone="success",
    ),
    status="Pi session stats refreshed",
  )
}

///|
fn WorkbenchModel::apply_export_html_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let path = match json_object(fields, "data") {
    Some(data) => json_string(data, "path").unwrap_or("")
    None => ""
  }
  let model = if path == "" {
    self
  } else {
    self.upsert_file(
      FileContext::new(
        id="pi-export-" + session_id,
        path~,
        summary="Pi session HTML export",
        change_kind="export",
        lines_changed=0,
      ),
    )
  }
  { ..model, pi_rpc: PiRpcSnapshot::new(command="export_html", success=true) }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi session exported",
      detail=if path == "" { session_id } else { session_id + ": " + path },
      tone="success",
    ),
    status="Pi session exported",
  )
}

///|
fn WorkbenchModel::apply_cycle_model_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let data = json_object(fields, "data")
  let model_label = match data {
    Some(data) => json_model_label(data)
    None => ""
  }
  let thinking_level = match data {
    Some(data) => json_string(data, "thinkingLevel").unwrap_or("")
    None => ""
  }
  let model = if model_label == "" {
    { ..self, pi_rpc: PiRpcSnapshot::new(command="cycle_model", success=true) }
  } else {
    let updated = self
      .update_pi_session_binding_model(
        session_id,
        model_label,
        last_command="cycle_model",
      )
      .update_active_session_for_pi(
        status=self.active_session().status,
        active_task="模型：" + model_label,
        summary=Some("模型已切换为 " + model_label),
      )
    {
      ..updated,
      pi_rpc: {
        ..self.pi_rpc,
        command: "cycle_model",
        success: true,
        model: model_label,
        error: "",
      },
      pi_agent: {
        ..updated.pi_agent,
        thinking_level: if thinking_level == "" {
          updated.pi_agent.thinking_level
        } else {
          thinking_level
        },
      },
    }
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi model cycled",
      detail=if model_label == "" {
        session_id + ": no alternate model"
      } else {
        session_id + ": " + model_label
      },
      tone=if model_label == "" { "warning" } else { "success" },
    ),
    status=if model_label == "" {
      "Pi model cycle acknowledged"
    } else {
      "Pi model changed"
    },
  )
}

///|
fn WorkbenchModel::apply_set_model_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let model_label = match json_object(fields, "data") {
    Some(data) => json_model_label(data)
    None => ""
  }
  let model = if model_label == "" {
    { ..self, pi_rpc: PiRpcSnapshot::new(command="set_model", success=true) }
  } else {
    let updated = self
      .update_pi_session_binding_model(
        session_id,
        model_label,
        last_command="set_model",
      )
      .update_active_session_for_pi(
        status=self.active_session().status,
        active_task="模型：" + model_label,
        summary=Some("模型已设为 " + model_label),
      )
    {
      ..updated,
      pi_rpc: {
        ..self.pi_rpc,
        command: "set_model",
        success: true,
        model: model_label,
        error: "",
      },
    }
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi model set",
      detail=if model_label == "" {
        session_id
      } else {
        session_id + ": " + model_label
      },
      tone="success",
    ),
    status="Pi model set",
  )
}

///|
fn WorkbenchModel::apply_compact_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let data = json_object(fields, "data").unwrap_or({})
  let summary = json_string(data, "summary").unwrap_or("")
  let first_kept_entry_id = json_string(data, "firstKeptEntryId").unwrap_or("")
  let tokens_before = json_int(data, "tokensBefore").unwrap_or(0)
  let transcript = self.transcript.copy()
  if summary != "" {
    transcript.push(
      TranscriptItem::new(
        id=compact_transcript_id(session_id, first_kept_entry_id),
        role="compactionSummary",
        summary="Compaction summary",
        detail=summary,
        tone="neutral",
      ),
    )
  }
  let model = {
    ..self
    .update_pi_session_binding_command(session_id, last_command="compact")
    .update_active_session_for_pi(
      status="active",
      active_task="上下文已压缩",
      summary=Some(compact_session_summary(tokens_before)),
    ),
    transcript,
    pi_rpc: PiRpcSnapshot::new(command="compact", success=true),
    pi_agent: { ..self.pi_agent, phase: "compaction complete" },
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi context compacted",
      detail=compact_response_detail(session_id, tokens_before, summary),
      tone="success",
    ),
    status="Pi context compacted",
  )
}

///|
fn WorkbenchModel::apply_cycle_thinking_level_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let level = match json_object(fields, "data") {
    Some(data) => json_string(data, "level").unwrap_or("")
    None => ""
  }
  let model = if level == "" {
    {
      ..self,
      pi_rpc: PiRpcSnapshot::new(command="cycle_thinking_level", success=true),
    }
  } else {
    {
      ..self.update_active_session_for_pi(
        status=self.active_session().status,
        active_task="思考等级：" + level,
      ),
      pi_agent: { ..self.pi_agent, thinking_level: level },
      pi_rpc: PiRpcSnapshot::new(command="cycle_thinking_level", success=true),
    }
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi thinking level cycled",
      detail=if level == "" {
        session_id + ": accepted"
      } else {
        session_id + ": " + level
      },
      tone="success",
    ),
    status="Pi thinking level cycle acknowledged",
  )
}

///|
fn WorkbenchModel::apply_set_steering_mode_success(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  {
    ..self,
    pi_rpc: PiRpcSnapshot::new(command="set_steering_mode", success=true),
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi steering mode applied",
      detail=session_id + ": " + self.pi_agent.steering_mode,
      tone="success",
    ),
    status="Pi steering mode acknowledged",
  )
}

///|
fn WorkbenchModel::apply_steer_success(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  { ..self, pi_rpc: PiRpcSnapshot::new(command="steer", success=true) }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi steering accepted",
      detail=session_id,
      tone="success",
    ),
    status="Pi steering accepted",
  )
}

///|
fn WorkbenchModel::apply_follow_up_success(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  { ..self, pi_rpc: PiRpcSnapshot::new(command="follow_up", success=true) }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi follow-up accepted",
      detail=session_id,
      tone="success",
    ),
    status="Pi follow-up accepted",
  )
}

///|
fn WorkbenchModel::apply_set_follow_up_mode_success(
  self : WorkbenchModel,
  session_id : String,
) -> WorkbenchModel {
  {
    ..self,
    pi_rpc: PiRpcSnapshot::new(command="set_follow_up_mode", success=true),
  }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title="Pi follow-up mode applied",
      detail=session_id + ": " + self.pi_agent.follow_up_mode,
      tone="success",
    ),
    status="Pi follow-up mode acknowledged",
  )
}

///|
fn WorkbenchModel::apply_bash_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let data : Map[String, Json] = match json_object(fields, "data") {
    Some(data) => data
    None => {}
  }
  let exit_code = json_int(data, "exitCode")
  let cancelled = json_bool(data, "cancelled").unwrap_or(false)
  let truncated = json_bool(data, "truncated").unwrap_or(false)
  let full_output_path = json_string(data, "fullOutputPath").unwrap_or("")
  let output = json_string(data, "output").unwrap_or("")
  let model = self
    .mark_next_shell_command_complete(
      session_id, exit_code, cancelled, full_output_path, output, truncated,
    )
    .append_bash_diagnostics(exit_code, cancelled, truncated, full_output_path)
  {
    ..model.update_active_session_for_pi(
      status=if cancelled {
        "cancelled"
      } else if exit_code.unwrap_or(1) == 0 {
        "active"
      } else {
        "failed"
      },
      active_task="命令已完成",
    ),
    pi_rpc: PiRpcSnapshot::new(command="bash", success=true),
  }.append_ingested_event(
    AgentEvent::new(
      phase="tool",
      title=if cancelled { "Pi bash cancelled" } else { "Pi bash completed" },
      detail=bash_response_detail(
        session_id, exit_code, cancelled, truncated, full_output_path, output,
      ),
      tone=if cancelled {
        "warning"
      } else if exit_code.unwrap_or(1) == 0 {
        "success"
      } else {
        "danger"
      },
    ),
    status="Pi bash response applied",
  )
}

///|
fn WorkbenchModel::apply_switch_session_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let cancelled = match json_object(fields, "data") {
    Some(data) => json_bool(data, "cancelled").unwrap_or(false)
    None => false
  }
  let session = self.session_for_id(session_id)
  let binding = PiSessionBinding::new(
    workbench_session_id=session_id,
    session_file=session.pi_session_path,
    status=if cancelled { "cancelled" } else { "switching" },
    last_command="switch_session",
  )
  let model = {
    ..self.upsert_pi_session_binding(binding),
    pi_rpc: PiRpcSnapshot::new(command="switch_session", success=true),
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title=if cancelled {
        "Pi session switch cancelled"
      } else {
        "Pi session switch accepted"
      },
      detail=if session.pi_session_path == "" {
        session_id
      } else {
        session_id + ": " + session.pi_session_path
      },
      tone=if cancelled { "warning" } else { "success" },
    ),
    status=if cancelled {
      "Pi session switch cancelled"
    } else {
      "Pi session switch accepted"
    },
  )
}

///|
fn WorkbenchModel::apply_new_session_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let cancelled = match json_object(fields, "data") {
    Some(data) => json_bool(data, "cancelled").unwrap_or(false)
    None => false
  }
  let existing = self.pi_session_binding_for_id(session_id)
  let bound = self.upsert_pi_session_binding(
    PiSessionBinding::new(
      workbench_session_id=session_id,
      rpc_session_id=if cancelled { existing.rpc_session_id } else { "" },
      session_file=if cancelled { existing.session_file } else { "" },
      session_name=if cancelled { existing.session_name } else { "" },
      model=if cancelled { existing.model } else { "" },
      status=if cancelled { "cancelled" } else { "creating" },
      last_command="new_session",
    ),
  )
  let updated = bound.update_active_session_for_pi(
    status=if cancelled { "active" } else { "running" },
    active_task=if cancelled {
      "新会话已取消"
    } else {
      "新会话已请求"
    },
    summary=Some(
      if cancelled {
        "保留当前会话"
      } else {
        "等待新会话状态"
      },
    ),
  )
  let model = {
    ..updated,
    pi_rpc: PiRpcSnapshot::new(command="new_session", success=true),
  }
  model.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title=if cancelled {
        "Pi new session cancelled"
      } else {
        "Pi new session accepted"
      },
      detail=session_id,
      tone=if cancelled { "warning" } else { "success" },
    ),
    status=if cancelled {
      "Pi new session cancelled"
    } else {
      "Pi new session accepted"
    },
  )
}

///|
fn WorkbenchModel::apply_fork_success(
  self : WorkbenchModel,
  session_id : String,
  fields : Map[String, Json],
) -> WorkbenchModel {
  let data = json_object(fields, "data").unwrap_or({})
  let cancelled = json_bool(data, "cancelled").unwrap_or(false)
  let text = json_string(data, "text").unwrap_or("")
  let existing = self.pi_session_binding_for_id(session_id)
  let bound = self.upsert_pi_session_binding(
    PiSessionBinding::new(
      workbench_session_id=session_id,
      rpc_session_id=if cancelled { existing.rpc_session_id } else { "" },
      session_file=if cancelled { existing.session_file } else { "" },
      session_name=if cancelled { existing.session_name } else { "" },
      model=if cancelled { existing.model } else { "" },
      status=if cancelled { "cancelled" } else { "forking" },
      last_command="fork",
    ),
  )
  let updated = bound.update_active_session_for_pi(
    status=if cancelled { "active" } else { "running" },
    active_task=if cancelled { "分叉已取消" } else { "分叉已请求" },
    summary=Some(
      if cancelled {
        "保留当前会话"
      } else if text == "" {
        "等待分叉状态"
      } else {
        "Forking before: " + text
      },
    ),
  )
  { ..updated, pi_rpc: PiRpcSnapshot::new(command="fork", success=true) }.append_ingested_event(
    AgentEvent::new(
      phase="agent",
      title=if cancelled { "Pi fork cancelled" } else { "Pi fork accepted" },
      detail=if text == "" { session_id } else { session_id + ": " + text },
      tone=if cancelled { "warning" } else { "success" },
    ),
    status=if cancelled { "Pi fork cancelled" } else { "Pi fork accepted" },
  )
}

///|
fn WorkbenchModel::update_session_from_rpc(
  self : WorkbenchModel,
  workbench_session_id : String,
  snapshot : PiRpcSnapshot,
) -> WorkbenchModel {
  let sessions = self.sessions.map(session => {
    if session.id == workbench_session_id && snapshot.session_id != "" {
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
        summary: "Agent session " + snapshot.session_id + " on " + model_label,
        unread_events: snapshot.pending_message_count,
      }
    } else {
      session
    }
  })
  let model = {
    ..self,
    sessions,
    pi_rpc: snapshot,
    pi_agent: {
      ..self.pi_agent,
      thinking_level: if snapshot.thinking_level == "" {
        self.pi_agent.thinking_level
      } else {
        snapshot.thinking_level
      },
      steering_mode: if snapshot.steering_mode == "" {
        self.pi_agent.steering_mode
      } else {
        snapshot.steering_mode
      },
      follow_up_mode: if snapshot.follow_up_mode == "" {
        self.pi_agent.follow_up_mode
      } else {
        snapshot.follow_up_mode
      },
    },
  }
  if snapshot.session_id == "" && snapshot.session_file == "" {
    model
  } else {
    model.upsert_pi_session_binding(
      PiSessionBinding::new(
        workbench_session_id~,
        rpc_session_id=snapshot.session_id,
        session_file=snapshot.session_file,
        session_name=snapshot.session_name,
        model=snapshot.model,
        status="bound",
        last_command=snapshot.command,
      ),
    )
  }
}

///|
fn WorkbenchModel::update_session_from_stats(
  self : WorkbenchModel,
  workbench_session_id : String,
  stats : PiSessionStatsSnapshot,
) -> WorkbenchModel {
  let summary = "会话统计：" +
    stats.total_messages.to_string() +
    " 消息，" +
    stats.tool_calls.to_string() +
    " 工具，" +
    stats.token_total.to_string() +
    " tokens"
  let sessions = self.sessions.map(session => {
    if session.id == workbench_session_id {
      {
        ..session,
        status: if session.status == "running" {
          "running"
        } else {
          "active"
        },
        summary,
      }
    } else {
      session
    }
  })
  let existing = self.pi_session_binding_for_id(workbench_session_id)
  let rpc_session_id = if stats.session_id == "" {
    existing.rpc_session_id
  } else {
    stats.session_id
  }
  let session_file = if stats.session_file == "" {
    existing.session_file
  } else {
    stats.session_file
  }
  let status = if rpc_session_id == "" && session_file == "" {
    existing.status
  } else {
    "bound"
  }
  { ..self, sessions, }.upsert_pi_session_binding(
    PiSessionBinding::new(
      workbench_session_id~,
      rpc_session_id~,
      session_file~,
      session_name=existing.session_name,
      model=existing.model,
      status~,
      last_command="get_session_stats",
    ),
  )
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
    session_file=json_string(data, "sessionFile").unwrap_or(""),
    session_name=json_string(data, "sessionName").unwrap_or(""),
    model=json_model_label(data),
    thinking_level=json_string(data, "thinkingLevel").unwrap_or(""),
    steering_mode=json_string(data, "steeringMode").unwrap_or(""),
    follow_up_mode=json_string(data, "followUpMode").unwrap_or(""),
    pending_message_count=json_int(data, "pendingMessageCount").unwrap_or(0),
    message_count=json_int(data, "messageCount").unwrap_or(0),
  )
}

///|
fn session_stats_detail(
  session_id : String,
  stats : PiSessionStatsSnapshot,
) -> String {
  session_id +
  ": " +
  stats.total_messages.to_string() +
  " messages, " +
  stats.tool_calls.to_string() +
  " tool calls, " +
  stats.token_total.to_string() +
  " tokens" +
  session_stats_context_suffix(stats)
}

///|
fn compact_transcript_id(
  session_id : String,
  first_kept_entry_id : String,
) -> String {
  if first_kept_entry_id == "" {
    "pi-compact-" + session_id
  } else {
    "pi-compact-" + first_kept_entry_id
  }
}

///|
fn compact_session_summary(tokens_before : Int) -> String {
  if tokens_before > 0 {
    "Pi compacted context from " + tokens_before.to_string() + " tokens"
  } else {
    "Pi compacted context"
  }
}

///|
fn compact_response_detail(
  session_id : String,
  tokens_before : Int,
  summary : String,
) -> String {
  let tokens = if tokens_before > 0 {
    ", " + tokens_before.to_string() + " tokens before"
  } else {
    ""
  }
  let summary_suffix = if summary == "" { "" } else { ": " + summary }
  session_id + tokens + summary_suffix
}

///|
fn session_stats_context_suffix(stats : PiSessionStatsSnapshot) -> String {
  match stats.context_percent {
    Some(percent) => ", context " + compact_stats_percent(percent)
    None => ""
  }
}

///|
fn compact_stats_percent(percent : Double) -> String {
  if percent > 0.0 && percent < 1.0 {
    "<1%"
  } else {
    percent.to_int().to_string() + "%"
  }
}

///|
fn rpc_response_detail(session_id : String, snapshot : PiRpcSnapshot) -> String {
  let rpc_session = if snapshot.session_id == "" {
    "no Pi session id"
  } else {
    "Pi session " + snapshot.session_id
  }
  let file = if snapshot.session_file == "" {
    ""
  } else {
    ", file " + snapshot.session_file
  }
  session_id +
  ": " +
  rpc_session +
  ", model " +
  (if snapshot.model == "" { "unknown" } else { snapshot.model }) +
  ", pending " +
  snapshot.pending_message_count.to_string() +
  file
}
