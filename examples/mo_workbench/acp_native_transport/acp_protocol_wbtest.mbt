///|
test "initialize request advertises conservative client capabilities" {
  let line = acp_initialize_request_line("1")
  guard acp_parse_rpc_line(line) is Some(Json::Object(fields)) else {
    fail("expected json object")
  }
  inspect(
    acp_json_string_field(fields, "method").unwrap(),
    content="initialize",
  )
  guard fields.get("params") is Some(Json::Object(params)) else {
    fail("expected params")
  }
  guard params.get("clientCapabilities") is Some(Json::Object(caps)) else {
    fail("expected client capabilities")
  }
  inspect(
    acp_json_bool_field(caps, "terminal").unwrap_or(true),
    content="false",
  )
  guard caps.get("fs") is Some(Json::Object(fs)) else {
    fail("expected fs capabilities")
  }
  guard caps.get("session") is Some(Json::Object(session_caps)) else {
    fail("expected session capabilities")
  }
  guard session_caps.get("configOptions") is Some(Json::Object(config_caps)) else {
    fail("expected config option capabilities")
  }
  inspect(config_caps.get("boolean") != None, content="true")
  inspect(config_caps.get("select") != None, content="true")
  inspect(
    acp_json_bool_field(fs, "readTextFile").unwrap_or(true),
    content="false",
  )
  inspect(
    acp_json_bool_field(fs, "writeTextFile").unwrap_or(true),
    content="false",
  )
}

///|
test "helper args parse json array or whitespace list" {
  let json_args = acp_helper_args("[\"--stdio\",\"--name\",\"Mo Agent\"]")
  inspect(json_args.length(), content="3")
  inspect(json_args[2], content="Mo Agent")
  let split_args = acp_helper_args("--stdio --debug")
  inspect(split_args.length(), content="2")
  inspect(split_args[1], content="--debug")
}

///|
test "agent message chunk update maps to assistant chunk event" {
  let update : Json = (
    {
      "sessionUpdate": "agent_message_chunk",
      "messageId": "m1",
      "content": { "type": "text", "text": "hello" },
    } : Json)
  let events = acp_session_update_to_events(update)
  inspect(events.length(), content="1")
  guard events[0] is @app.AgentEvent::AssistantMessageChunk(id, text) else {
    fail("expected assistant chunk")
  }
  inspect(id.unwrap(), content="m1")
  inspect(text, content="hello")
}

///|
test "permission request parses options" {
  let params : Json = (
    {
      "sessionId": "s1",
      "toolCall": {
        "toolCallId": "tool-1",
        "title": "Run shell",
        "kind": "execute",
      },
      "options": [
        { "optionId": "allow", "name": "Allow", "kind": "allow_once" },
        { "optionId": "reject", "name": "Reject", "kind": "reject_once" },
      ],
    } : Json)
  guard acp_parse_permission_request("req-1", params) is Some(request) else {
    fail("expected permission request")
  }
  inspect(request.request_id, content="req-1")
  inspect(request.session_id, content="s1")
  inspect(request.title, content="Run shell")
  inspect(request.options.length(), content="2")
  inspect(request.options[0].id, content="allow")
}

///|
test "session setup response maps modes and config options" {
  let result : Json = (
    {
      "sessionId": "s1",
      "modes": {
        "currentModeId": "ask",
        "availableModes": [
          { "id": "ask", "name": "Ask" },
          { "id": "code", "name": "Code" },
        ],
      },
      "configOptions": [
        {
          "id": "autoApply",
          "name": "Auto Apply",
          "type": "boolean",
          "currentValue": true,
        },
        {
          "id": "model",
          "name": "Model",
          "type": "select",
          "currentValue": "fast",
          "options": [
            { "value": "fast", "name": "Fast" },
            { "value": "smart", "name": "Smart" },
          ],
        },
      ],
    } : Json)
  let events = acp_session_setup_events(result)
  inspect(events.length(), content="3")
  guard events[0] is @app.AgentEvent::ActiveSessionChanged(id) else {
    fail("expected active session")
  }
  inspect(id, content="s1")
  guard events[1] is @app.AgentEvent::SessionModeStateChanged(modes) else {
    fail("expected modes")
  }
  inspect(modes.current_mode_id, content="ask")
  guard events[2] is @app.AgentEvent::SessionConfigOptionsChanged(options) else {
    fail("expected config options")
  }
  inspect(options.length(), content="2")
  inspect(
    options[0].current_value == @app.AgentConfigValue::Boolean(true),
    content="true",
  )
  inspect(options[1].values.length(), content="2")
  inspect(options[1].values[0].id, content="fast")
}

///|
test "current mode update maps without losing available mode list" {
  let update : Json = (
    { "sessionUpdate": "current_mode_update", "currentModeId": "code" } : Json)
  let events = acp_session_update_to_events(update)
  inspect(events.length(), content="1")
  guard events[0] is @app.AgentEvent::SessionModeStateChanged(modes) else {
    fail("expected mode state")
  }
  inspect(modes.current_mode_id, content="code")
  inspect(modes.available_modes.length(), content="0")
}
