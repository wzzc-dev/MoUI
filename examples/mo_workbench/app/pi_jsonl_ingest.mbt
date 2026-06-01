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
fn PiTransportEvent::session_replacement_refresh(
  self : PiTransportEvent,
) -> (String, String, String)? {
  match self {
    JsonLineReceived(session_id, line) =>
      if json_line_is_uncancelled_success_response(line, "new_session") {
        Some(
          (
            session_id, "Pi new session refresh queued", "Pi new session refresh queued",
          ),
        )
      } else if json_line_is_uncancelled_success_response(line, "fork") {
        Some((session_id, "Pi fork refresh queued", "Pi fork refresh queued"))
      } else {
        None
      }
    _ => None
  }
}

///|
fn json_line_is_uncancelled_success_response(
  line : String,
  command : String,
) -> Bool {
  let parsed : Json? = Some(@json.parse(line)) catch { _ => None }
  match parsed {
    Some(Object(fields)) => {
      let cancelled = match json_object(fields, "data") {
        Some(data) => json_bool(data, "cancelled").unwrap_or(false)
        None => false
      }
      json_string(fields, "type").unwrap_or("") == "response" &&
      json_string(fields, "command").unwrap_or("") == command &&
      json_bool(fields, "success").unwrap_or(false) &&
      !cancelled
    }
    _ => false
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
      "cycle_thinking_level" =>
        self.apply_cycle_thinking_level_success(session_id, fields)
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
        active_task="Pi thinking level: " + level,
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
    .mark_latest_shell_command_complete(
      session_id, exit_code, cancelled, full_output_path,
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
      active_task="Pi bash completed",
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
      "Pi new session cancelled"
    } else {
      "Pi new session requested"
    },
    summary=Some(
      if cancelled {
        "Pi kept the current session"
      } else {
        "Waiting for Pi new session state"
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
    active_task=if cancelled {
      "Pi fork cancelled"
    } else {
      "Pi fork requested"
    },
    summary=Some(
      if cancelled {
        "Pi kept the current session"
      } else if text == "" {
        "Waiting for Pi fork state"
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
        summary: "Pi RPC session " + snapshot.session_id + " on " + model_label,
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
  let summary = "Pi stats: " +
    stats.total_messages.to_string() +
    " messages, " +
    stats.tool_calls.to_string() +
    " tools, " +
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
  .sync_pi_session_name_binding(
    session_id,
    name,
    last_command="session_info_changed",
  )
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
  {
    ..self.update_active_session_for_pi(
      status=self.active_session().status,
      active_task="Pi thinking level: " + level,
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
fn WorkbenchModel::mark_latest_shell_command_complete(
  self : WorkbenchModel,
  session_id : String,
  exit_code : Int?,
  cancelled : Bool,
  output_path : String,
) -> WorkbenchModel {
  let session = self.session_for_id(session_id)
  let status = shell_command_status(exit_code, cancelled)
  let mut target_id : Int? = None
  for command in self.commands {
    if command.is_active_shell_for_session(session) {
      target_id = Some(command.id)
    }
  }
  match target_id {
    Some(id) => {
      let commands = self.commands.map(command => {
        if command.id == id {
          { ..command, status, exit_code, output_path }
        } else {
          command
        }
      })
      { ..self, commands, }
    }
    None =>
      self.upsert_command(
        CommandRun::new(
          id=self.next_command_id(),
          command="Pi RPC bash",
          cwd=session.project_path,
          status~,
          exit_code~,
          output_path~,
        ),
      )
  }
}

///|
fn WorkbenchModel::append_bash_diagnostics(
  self : WorkbenchModel,
  exit_code : Int?,
  cancelled : Bool,
  truncated : Bool,
  full_output_path : String,
) -> WorkbenchModel {
  let diagnostics = self.diagnostics.copy()
  if cancelled {
    diagnostics.push(
      DiagnosticItem::new(
        source="Pi bash",
        severity="warning",
        message="bash command was cancelled",
      ),
    )
  } else {
    match exit_code {
      Some(0) => ()
      Some(code) =>
        diagnostics.push(
          DiagnosticItem::new(
            source="Pi bash",
            severity="error",
            message="bash exited with code " + code.to_string(),
          ),
        )
      None =>
        diagnostics.push(
          DiagnosticItem::new(
            source="Pi bash",
            severity="error",
            message="bash response did not include an exit code",
          ),
        )
    }
  }
  if truncated {
    diagnostics.push(
      DiagnosticItem::new(
        source="Pi bash",
        severity="warning",
        message=if full_output_path == "" {
          "bash output was truncated"
        } else {
          "bash output was truncated: " + full_output_path
        },
      ),
    )
  }
  { ..self, diagnostics, }
}

///|
fn shell_command_status(exit_code : Int?, cancelled : Bool) -> String {
  if cancelled {
    "cancelled"
  } else {
    match exit_code {
      Some(0) => "passed"
      _ => "failed"
    }
  }
}

///|
fn bash_response_detail(
  session_id : String,
  exit_code : Int?,
  cancelled : Bool,
  truncated : Bool,
  full_output_path : String,
  output : String,
) -> String {
  let state = if cancelled {
    "cancelled"
  } else {
    "exit code " + bash_exit_code_label(exit_code)
  }
  let truncated_suffix = if truncated && full_output_path != "" {
    " - truncated output at " + full_output_path
  } else if truncated {
    " - output truncated"
  } else {
    ""
  }
  let output_suffix = if output == "" { "" } else { " - " + output }
  session_id + ": " + state + truncated_suffix + output_suffix
}

///|
fn bash_exit_code_label(exit_code : Int?) -> String {
  match exit_code {
    Some(code) => code.to_string()
    None => "unknown"
  }
}

///|
fn transcript_items_from_messages(
  values : Array[Json],
) -> Array[TranscriptItem] {
  let items : Array[TranscriptItem] = []
  for index, value in values {
    items.push(transcript_item_from_json(index, value))
  }
  items
}

///|
fn pi_command_infos_from_values(values : Array[Json]) -> Array[PiCommandInfo] {
  let commands : Array[PiCommandInfo] = []
  for index, value in values {
    commands.push(pi_command_info_from_json(index, value))
  }
  commands
}

///|
fn pi_model_infos_from_values(values : Array[Json]) -> Array[PiModelInfo] {
  let models : Array[PiModelInfo] = []
  for index, value in values {
    models.push(pi_model_info_from_json(index, value))
  }
  models
}

///|
fn pi_fork_messages_from_values(values : Array[Json]) -> Array[PiForkMessage] {
  let messages : Array[PiForkMessage] = []
  for index, value in values {
    messages.push(pi_fork_message_from_json(index, value))
  }
  messages
}

///|
fn pi_session_stats_from_data(
  data : Map[String, Json],
) -> PiSessionStatsSnapshot {
  let tokens = json_object(data, "tokens").unwrap_or({})
  let context = json_object(data, "contextUsage").unwrap_or({})
  PiSessionStatsSnapshot::new(
    session_file=json_string(data, "sessionFile").unwrap_or(""),
    session_id=json_string(data, "sessionId").unwrap_or(""),
    user_messages=json_int(data, "userMessages").unwrap_or(0),
    assistant_messages=json_int(data, "assistantMessages").unwrap_or(0),
    tool_calls=json_int(data, "toolCalls").unwrap_or(0),
    tool_results=json_int(data, "toolResults").unwrap_or(0),
    total_messages=json_int(data, "totalMessages").unwrap_or(0),
    token_input=json_int(tokens, "input").unwrap_or(0),
    token_output=json_int(tokens, "output").unwrap_or(0),
    token_cache_read=json_int(tokens, "cacheRead").unwrap_or(0),
    token_cache_write=json_int(tokens, "cacheWrite").unwrap_or(0),
    token_total=json_int(tokens, "total").unwrap_or(0),
    cost=json_number(data, "cost").unwrap_or(0.0),
    context_tokens=json_int(context, "tokens"),
    context_window=json_int(context, "contextWindow").unwrap_or(0),
    context_percent=json_number(context, "percent"),
  )
}

///|
fn pi_command_info_from_json(index : Int, value : Json) -> PiCommandInfo {
  match value {
    Object(fields) => {
      let source_info = json_object(fields, "sourceInfo").unwrap_or({})
      PiCommandInfo::new(
        name=json_string(fields, "name").unwrap_or(
          "command-" + index.to_string(),
        ),
        source=json_string(fields, "source").unwrap_or("unknown"),
        description=json_string(fields, "description").unwrap_or(""),
        source_scope=json_string(source_info, "scope").unwrap_or(""),
        source_path=json_string(source_info, "path").unwrap_or(""),
      )
    }
    _ =>
      PiCommandInfo::new(
        name="command-" + index.to_string(),
        source="unknown",
        description=value.stringify(),
        source_scope="",
        source_path="",
      )
  }
}

///|
fn pi_model_info_from_json(index : Int, value : Json) -> PiModelInfo {
  match value {
    Object(fields) => {
      let provider = json_string(fields, "provider").unwrap_or("")
      let id = json_string(fields, "id").unwrap_or(
        json_string(fields, "model").unwrap_or(
          json_string(fields, "name").unwrap_or("model-" + index.to_string()),
        ),
      )
      let name = json_string(fields, "name").unwrap_or("")
      PiModelInfo::new(provider~, id~, name~)
    }
    _ =>
      PiModelInfo::new(
        provider="",
        id="model-" + index.to_string(),
        name=value.stringify(),
      )
  }
}

///|
fn pi_fork_message_from_json(index : Int, value : Json) -> PiForkMessage {
  match value {
    Object(fields) =>
      PiForkMessage::new(
        entry_id=json_string(fields, "entryId").unwrap_or(
          "entry-" + index.to_string(),
        ),
        text=json_string(fields, "text").unwrap_or(""),
      )
    _ =>
      PiForkMessage::new(
        entry_id="entry-" + index.to_string(),
        text=value.stringify(),
      )
  }
}

///|
fn transcript_item_from_json(index : Int, value : Json) -> TranscriptItem {
  match value {
    Object(fields) => {
      let role = json_string(fields, "role").unwrap_or("message")
      TranscriptItem::new(
        id=json_string(fields, "id").unwrap_or(role + "-" + index.to_string()),
        role~,
        summary=transcript_summary(role, fields),
        detail=transcript_detail(role, fields),
        tone=transcript_tone(role),
      )
    }
    _ =>
      TranscriptItem::new(
        id="message-" + index.to_string(),
        role="message",
        summary="Pi message",
        detail=value.stringify(),
        tone="neutral",
      )
  }
}

///|
fn transcript_summary(role : String, fields : Map[String, Json]) -> String {
  match role {
    "user" => non_empty(json_message_content_summary(fields), "User message")
    "assistant" =>
      non_empty(json_message_content_summary(fields), "Assistant message")
    "toolResult" =>
      "Tool result: " + json_string(fields, "toolName").unwrap_or("tool")
    "bashExecution" =>
      non_empty(json_string(fields, "command").unwrap_or(""), "Bash execution")
    "branchSummary" => "Branch summary"
    "compactionSummary" => "Compaction summary"
    "custom" =>
      "Custom: " + json_string(fields, "customType").unwrap_or("message")
    _ => non_empty(json_message_content_summary(fields), role)
  }
}

///|
fn transcript_detail(role : String, fields : Map[String, Json]) -> String {
  match role {
    "bashExecution" => {
      let exit_code = json_int(fields, "exitCode")
      let output = json_string(fields, "output").unwrap_or("")
      let output_suffix = if output == "" { "" } else { " - " + output }
      "exit code " + bash_exit_code_label(exit_code) + output_suffix
    }
    "branchSummary" =>
      non_empty(json_string(fields, "summary").unwrap_or(""), "summary")
    "compactionSummary" =>
      non_empty(json_string(fields, "summary").unwrap_or(""), "summary")
    _ => non_empty(json_message_content_summary(fields), "message")
  }
}

///|
fn transcript_tone(role : String) -> String {
  match role {
    "assistant" => "success"
    "toolResult" | "bashExecution" => "warning"
    "user" => "info"
    _ => "neutral"
  }
}

///|
fn non_empty(value : String, fallback : String) -> String {
  if value == "" {
    fallback
  } else {
    value
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
fn json_number(fields : Map[String, Json], key : String) -> Double? {
  match fields.get(key) {
    Some(Number(value, ..)) => Some(value)
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
fn pi_model_label(provider : String, id : String, name : String) -> String {
  let provider_id = if provider == "" {
    id
  } else if id == "" {
    provider
  } else {
    provider + "/" + id
  }
  if name == "" || name == id || name == provider_id {
    provider_id
  } else if provider_id == "" {
    name
  } else {
    name + " (" + provider_id + ")"
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
