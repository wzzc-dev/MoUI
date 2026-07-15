///|
let acp_protocol_version : Int = 1

///|
fn acp_json_null() -> Json {
  (None : String?).to_json()
}

///|
fn acp_json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn acp_json_bool_field(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn acp_rpc_request(id : String, method_name : String, params : Json) -> Json {
  (
    { "jsonrpc": "2.0", "id": id, "method": method_name, "params": params } :
    Json)
}

///|
fn acp_rpc_notification(method_name : String, params : Json) -> Json {
  ({ "jsonrpc": "2.0", "method": method_name, "params": params } : Json)
}

///|
fn acp_rpc_result(id : Json, result : Json) -> Json {
  ({ "jsonrpc": "2.0", "id": id, "result": result } : Json)
}

///|
fn acp_rpc_error(id : Json, code : Int, message : String) -> Json {
  (
    {
      "jsonrpc": "2.0",
      "id": id,
      "error": { "code": code, "message": message },
    } : Json)
}

///|
pub fn acp_initialize_request_line(id : String) -> String {
  acp_rpc_request(
    id,
    "initialize",
    (
      {
        "protocolVersion": acp_protocol_version,
        "clientInfo": { "name": "Mo Workbench", "version": "0.1.0" },
        "clientCapabilities": {
          "fs": { "readTextFile": false, "writeTextFile": false },
          "session": {
            "configOptions": {
              "boolean": Json::empty_object(),
              "select": Json::empty_object(),
            },
          },
          "terminal": false,
        },
      } : Json),
  ).stringify()
}

///|
fn acp_new_session_request_line(id : String, cwd : String) -> String {
  acp_rpc_request(
    id,
    "session/new",
    (
      {
        "cwd": cwd,
        "mcpServers": ([] : Array[Json]).to_json(),
        "additionalDirectories": ([] : Array[String]).to_json(),
      } : Json),
  ).stringify()
}

///|
fn acp_prompt_request_line(
  id : String,
  session_id : String,
  prompt : String,
) -> String {
  acp_rpc_request(
    id,
    "session/prompt",
    (
      {
        "sessionId": session_id,
        "prompt": [({ "type": "text", "text": prompt } : Json)],
      } : Json),
  ).stringify()
}

///|
fn acp_cancel_notification_line(session_id : String) -> String {
  acp_rpc_notification("session/cancel", ({ "sessionId": session_id } : Json)).stringify()
}

///|
fn acp_list_sessions_request_line(id : String) -> String {
  acp_rpc_request(id, "session/list", Json::empty_object()).stringify()
}

///|
fn acp_load_session_request_line(
  id : String,
  session_id : String,
  cwd : String,
) -> String {
  acp_rpc_request(
    id,
    "session/load",
    (
      {
        "sessionId": session_id,
        "cwd": cwd,
        "mcpServers": ([] : Array[Json]).to_json(),
        "additionalDirectories": ([] : Array[String]).to_json(),
      } : Json),
  ).stringify()
}

///|
fn acp_resume_session_request_line(
  id : String,
  session_id : String,
  cwd : String,
) -> String {
  acp_rpc_request(
    id,
    "session/resume",
    (
      {
        "sessionId": session_id,
        "cwd": cwd,
        "mcpServers": ([] : Array[Json]).to_json(),
        "additionalDirectories": ([] : Array[String]).to_json(),
      } : Json),
  ).stringify()
}

///|
fn acp_set_mode_request_line(
  id : String,
  session_id : String,
  mode_id : String,
) -> String {
  acp_rpc_request(
    id,
    "session/set_mode",
    ({ "sessionId": session_id, "modeId": mode_id } : Json),
  ).stringify()
}

///|
fn acp_set_config_option_request_line(
  id : String,
  session_id : String,
  config_id : String,
  value : @app.AgentConfigValue,
) -> String {
  let payload : Json = match value {
    @app.AgentConfigValue::Boolean(v) =>
      (
        {
          "sessionId": session_id,
          "configId": config_id,
          "type": "boolean",
          "value": v,
        } : Json)
    @app.AgentConfigValue::ValueId(v) =>
      ({ "sessionId": session_id, "configId": config_id, "value": v } : Json)
  }
  acp_rpc_request(id, "session/set_config_option", payload).stringify()
}

///|
fn acp_permission_response_line(
  id : Json,
  outcome : @app.PermissionOutcome,
) -> String {
  let outcome_json : Json = match outcome {
    @app.PermissionOutcome::Selected(option_id) =>
      ({ "outcome": { "outcome": "selected", "optionId": option_id } } : Json)
    @app.PermissionOutcome::Cancelled =>
      ({ "outcome": { "outcome": "cancelled" } } : Json)
  }
  acp_rpc_result(id, outcome_json).stringify()
}

///|
fn acp_unsupported_method_response_line(
  id : Json,
  method_name : String,
) -> String {
  acp_rpc_error(id, -32601, "ACP client method unsupported: " + method_name).stringify()
}

///|
fn acp_json_id_to_key(id : Json) -> String {
  match id {
    Json::String(value) => value
    Json::Number(value, ..) => value.to_string()
    _ => ""
  }
}

///|
fn acp_json_id_from_fields(fields : Map[String, Json]) -> Json {
  match fields.get("id") {
    Some(id) => id
    None => acp_json_null()
  }
}

///|
fn acp_parse_rpc_line(line : String) -> Json? {
  let clean = line.trim().to_owned()
  if clean.is_empty() {
    None
  } else {
    Some(@json.parse(clean) catch { _ => return None })
  }
}

///|
fn acp_response_result(fields : Map[String, Json]) -> Json? {
  fields.get("result")
}

///|
fn acp_response_error_message(fields : Map[String, Json]) -> String? {
  match fields.get("error") {
    Some(Json::Object(error)) =>
      match error.get("message") {
        Some(Json::String(message)) => Some(message)
        _ => Some("ACP request failed")
      }
    _ => None
  }
}

///|
fn acp_content_text(value : Json) -> String {
  match value {
    Json::Object(fields) =>
      match acp_json_string_field(fields, "type") {
        Some("text") => acp_json_string_field(fields, "text").unwrap_or("")
        _ => value.stringify()
      }
    _ => value.stringify()
  }
}

///|
fn acp_tool_content_text(values : Array[Json]) -> String {
  let parts : Array[String] = []
  for value in values {
    match value {
      Json::Object(fields) =>
        match fields.get("content") {
          Some(content) => parts.push(acp_content_text(content))
          None => parts.push(value.stringify())
        }
      _ => parts.push(value.stringify())
    }
  }
  parts.join("\n")
}

///|
fn acp_session_update_to_events(update : Json) -> Array[@app.AgentEvent] {
  guard update is Json::Object(fields) else { return [] }
  guard acp_json_string_field(fields, "sessionUpdate") is Some(kind) else {
    return []
  }
  match kind {
    "user_message_chunk" =>
      [
        @app.AgentEvent::UserMessageChunk(
          acp_json_string_field(fields, "messageId"),
          match fields.get("content") {
            Some(content) => acp_content_text(content)
            None => ""
          },
        ),
      ]
    "agent_message_chunk" =>
      [
        @app.AgentEvent::AssistantMessageChunk(
          acp_json_string_field(fields, "messageId"),
          match fields.get("content") {
            Some(content) => acp_content_text(content)
            None => ""
          },
        ),
      ]
    "agent_thought_chunk" =>
      [
        @app.AgentEvent::ThoughtMessageChunk(
          acp_json_string_field(fields, "messageId"),
          match fields.get("content") {
            Some(content) => acp_content_text(content)
            None => ""
          },
        ),
      ]
    "tool_call" =>
      [
        @app.AgentEvent::ToolResultAdded(
          acp_json_string_field(fields, "title").unwrap_or("tool"),
          match fields.get("content") {
            Some(Json::Array(values)) => acp_tool_content_text(values)
            _ => acp_json_string_field(fields, "status").unwrap_or("pending")
          },
          false,
          acp_json_string_field(fields, "status"),
        ),
      ]
    "tool_call_update" =>
      [
        @app.AgentEvent::ToolResultAdded(
          acp_json_string_field(fields, "title").unwrap_or(
            acp_json_string_field(fields, "toolCallId").unwrap_or("tool"),
          ),
          match fields.get("content") {
            Some(Json::Array(values)) => acp_tool_content_text(values)
            _ => acp_json_string_field(fields, "status").unwrap_or("updated")
          },
          false,
          acp_json_string_field(fields, "status"),
        ),
      ]
    "plan" => [@app.AgentEvent::ProgressNotice("ACP plan updated")]
    "available_commands_update" =>
      [@app.AgentEvent::ProgressNotice("ACP commands updated")]
    "current_mode_update" =>
      [
        @app.AgentEvent::SessionModeStateChanged(
          @app.agent_session_mode_state(
            current_mode_id=acp_json_string_field(fields, "currentModeId").unwrap_or(
              "",
            ),
            available_modes=[],
          ),
        ),
      ]
    "config_option_update" =>
      match fields.get("configOptions") {
        Some(Json::Array(values)) =>
          [
            @app.AgentEvent::SessionConfigOptionsChanged(
              acp_parse_config_options(values),
            ),
          ]
        _ => []
      }
    "session_info_update" =>
      [
        @app.AgentEvent::SessionInfoUpdated(
          "",
          acp_json_string_field(fields, "title"),
          acp_json_string_field(fields, "updatedAt"),
        ),
      ]
    "usage_update" => [@app.AgentEvent::ProgressNotice("ACP usage updated")]
    _ => [@app.AgentEvent::RuntimeNoticeAdded("Unknown ACP update: " + kind)]
  }
}

///|
fn acp_parse_modes(value : Json) -> @app.AgentSessionModeState? {
  guard value is Json::Object(fields) else { return None }
  let current = acp_json_string_field(fields, "currentModeId").unwrap_or("")
  let modes : Array[@app.AgentSessionMode] = []
  match fields.get("availableModes") {
    Some(Json::Array(values)) =>
      for item in values {
        guard item is Json::Object(mode_fields) else { continue }
        let id = acp_json_string_field(mode_fields, "id").unwrap_or("")
        if id.is_empty() {
          continue
        }
        modes.push(
          @app.agent_session_mode(
            id~,
            name=acp_json_string_field(mode_fields, "name").unwrap_or(id),
            description=acp_json_string_field(mode_fields, "description"),
          ),
        )
      }
    _ => ()
  }
  Some(
    @app.agent_session_mode_state(
      current_mode_id=current,
      available_modes=modes,
    ),
  )
}

///|
fn acp_parse_permission_options(
  values : Array[Json],
) -> Array[@app.AgentPermissionOption] {
  let out : Array[@app.AgentPermissionOption] = []
  for item in values {
    guard item is Json::Object(fields) else { continue }
    let id = acp_json_string_field(fields, "optionId").unwrap_or(
      acp_json_string_field(fields, "id").unwrap_or(""),
    )
    if id.is_empty() {
      continue
    }
    out.push(
      @app.agent_permission_option(
        id~,
        name=acp_json_string_field(fields, "name").unwrap_or(id),
        kind=acp_json_string_field(fields, "kind").unwrap_or(""),
      ),
    )
  }
  out
}

///|
fn acp_parse_config_option_values(
  value : Json,
) -> Array[@app.AgentPermissionOption] {
  let out : Array[@app.AgentPermissionOption] = []
  match value {
    Json::Array(items) =>
      for item in items {
        guard item is Json::Object(fields) else { continue }
        match fields.get("options") {
          Some(Json::Array(group_items)) =>
            for group_item in group_items {
              acp_push_config_option_value(out, group_item)
            }
          _ => acp_push_config_option_value(out, item)
        }
      }
    _ => ()
  }
  out
}

///|
fn acp_push_config_option_value(
  out : Array[@app.AgentPermissionOption],
  item : Json,
) -> Unit {
  guard item is Json::Object(fields) else { return }
  let id = acp_json_string_field(fields, "value").unwrap_or(
    acp_json_string_field(fields, "optionId").unwrap_or(
      acp_json_string_field(fields, "id").unwrap_or(""),
    ),
  )
  if id.is_empty() {
    return
  }
  out.push(
    @app.agent_permission_option(
      id~,
      name=acp_json_string_field(fields, "name").unwrap_or(id),
      kind=acp_json_string_field(fields, "kind").unwrap_or(""),
    ),
  )
}

///|
fn acp_config_current_value(
  fields : Map[String, Json],
) -> @app.AgentConfigValue {
  match fields.get("currentValue") {
    Some(Json::True) => @app.AgentConfigValue::Boolean(true)
    Some(Json::False) => @app.AgentConfigValue::Boolean(false)
    Some(Json::String(text)) => @app.AgentConfigValue::ValueId(text)
    _ =>
      match acp_json_bool_field(fields, "value") {
        Some(v) => @app.AgentConfigValue::Boolean(v)
        None =>
          @app.AgentConfigValue::ValueId(
            acp_json_string_field(fields, "value").unwrap_or(""),
          )
      }
  }
}

///|
fn acp_parse_config_options(
  values : Array[Json],
) -> Array[@app.AgentSessionConfigOption] {
  let out : Array[@app.AgentSessionConfigOption] = []
  for item in values {
    guard item is Json::Object(fields) else { continue }
    let id = acp_json_string_field(fields, "configId").unwrap_or(
      acp_json_string_field(fields, "id").unwrap_or(""),
    )
    if id.is_empty() {
      continue
    }
    let value = acp_config_current_value(fields)
    let options = match fields.get("options") {
      Some(items) => acp_parse_config_option_values(items)
      None =>
        match fields.get("values") {
          Some(Json::Array(items)) => acp_parse_permission_options(items)
          _ => []
        }
    }
    out.push(
      @app.agent_session_config_option(
        id~,
        name=acp_json_string_field(fields, "name").unwrap_or(id),
        description=acp_json_string_field(fields, "description"),
        current_value=value,
        values=options,
      ),
    )
  }
  out
}

///|
fn acp_session_setup_events(result : Json) -> Array[@app.AgentEvent] {
  guard result is Json::Object(fields) else { return [] }
  let events : Array[@app.AgentEvent] = []
  match acp_json_string_field(fields, "sessionId") {
    Some(id) => events.push(@app.AgentEvent::ActiveSessionChanged(id))
    None => ()
  }
  match fields.get("modes") {
    Some(value) =>
      match acp_parse_modes(value) {
        Some(modes) =>
          events.push(@app.AgentEvent::SessionModeStateChanged(modes))
        None => ()
      }
    None => ()
  }
  match fields.get("configOptions") {
    Some(Json::Array(values)) =>
      events.push(
        @app.AgentEvent::SessionConfigOptionsChanged(
          acp_parse_config_options(values),
        ),
      )
    _ => ()
  }
  events
}

///|
fn acp_prompt_stop_event(result : Json) -> @app.AgentEvent {
  guard result is Json::Object(fields) else {
    return @app.AgentEvent::TurnTerminal(
      @app.TurnStatus::Failed,
      "Malformed ACP prompt response",
    )
  }
  match acp_json_string_field(fields, "stopReason") {
    Some("end_turn") =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Finished, "Done")
    Some("cancelled") =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Aborted, "Cancelled")
    Some("refusal") =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Interrupted, "Refused")
    Some(reason) =>
      @app.AgentEvent::TurnTerminal(@app.TurnStatus::Interrupted, reason)
    None => @app.AgentEvent::TurnTerminal(@app.TurnStatus::Finished, "Done")
  }
}

///|
fn acp_parse_permission_request(
  request_id : String,
  params : Json,
) -> @app.AgentPermissionRequest? {
  guard params is Json::Object(fields) else { return None }
  let session_id = acp_json_string_field(fields, "sessionId").unwrap_or("")
  let (tool_call_id, title, kind) = match fields.get("toolCall") {
    Some(Json::Object(tool)) =>
      (
        acp_json_string_field(tool, "toolCallId").unwrap_or(""),
        acp_json_string_field(tool, "title").unwrap_or(""),
        acp_json_string_field(tool, "kind").unwrap_or(""),
      )
    _ => ("", "", "")
  }
  let options = match fields.get("options") {
    Some(Json::Array(values)) => acp_parse_permission_options(values)
    _ => []
  }
  Some(
    @app.agent_permission_request(
      request_id~,
      session_id~,
      tool_call_id~,
      title~,
      kind~,
      options~,
    ),
  )
}

///|
fn acp_parse_session_list(result : Json) -> Array[@app.SessionSummary] {
  let summaries : Array[@app.SessionSummary] = []
  guard result is Json::Object(fields) else { return summaries }
  let values = match fields.get("sessions") {
    Some(Json::Array(items)) => items
    _ => return summaries
  }
  for item in values {
    guard item is Json::Object(session) else { continue }
    let id = acp_json_string_field(session, "sessionId").unwrap_or(
      acp_json_string_field(session, "id").unwrap_or(""),
    )
    if id.is_empty() {
      continue
    }
    let title = acp_json_string_field(session, "title").unwrap_or("")
    summaries.push(@app.session_summary(id~, first_prompt=title))
  }
  summaries
}

///|
pub fn acp_helper_args(value : String) -> Array[String] {
  let clean = value.trim().to_owned()
  if clean == "" {
    return []
  }
  if clean.to_array().length() > 0 && clean.to_array()[0] == '[' {
    match acp_helper_json_args(clean) {
      Some(args) => return args
      None => ()
    }
  }
  acp_helper_split_args(clean)
}

///|
fn acp_helper_json_args(value : String) -> Array[String]? {
  let parsed = @json.parse(value) catch { _ => return None }
  guard parsed is Json::Array(values) else { return None }
  let args : Array[String] = []
  for item in values {
    guard item is Json::String(arg) else { return None }
    let clean = arg.trim().to_owned()
    if clean != "" {
      args.push(clean)
    }
  }
  Some(args)
}

///|
fn acp_helper_split_args(value : String) -> Array[String] {
  let args : Array[String] = []
  let current : Array[Char] = []
  for ch in value.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !current.is_empty() {
        args.push(String::from_array(current))
        current.clear()
      }
    } else {
      current.push(ch)
    }
  }
  if !current.is_empty() {
    args.push(String::from_array(current))
  }
  args
}
