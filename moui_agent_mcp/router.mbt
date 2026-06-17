///|
// JSON-RPC 2.0 router mapping MCP requests onto an AgentHost.
//
// The router is pure: it takes a parsed request (Json) + a host and returns a
// response (Json). I/O (the stdio NDJSON loop) lives in main.mbt, so the
// router is unit-testable with a mock host and no real stdin/stdout.
//
// MCP methods implemented (subset for MVP):
//   - initialize            -> capabilities + protocol version
//   - tools/list            -> the agent ops (get_semantics, get_state, ...)
//   - tools/call            -> dispatch to the named tool
// Unknown methods return a JSON-RPC error (-32601).

///|
/// JSON-RPC protocol version string we report in initialize results.
let mcp_protocol_version : String = "2024-11-05"

///|
/// MCP tool descriptor: name + description + a minimal input schema.
fn tool_descriptor(name : String, description : String, schema : Json) -> Json {
  ({
    "name": name,
    "description": description,
    "inputSchema": schema,
  } : Json)
}

///|
/// A reusable JSON null (built via ToJson since Json::Null is read-only).
fn json_null() -> Json {
  (None : String?).to_json()
}

///|
/// The static list of MCP tools this server exposes (mirrors AgentHost::capabilities).
fn mcp_tools() -> Json {
  // Build via ToJson on an array of Json objects (Json::Array is read-only).
  let tools : Array[Json] = [
    tool_descriptor(
      "get_semantics",
      "Read the app's current semantics tree (its DOM).",
      ({
        "type": "object",
        "properties": {
          "filter": {
            "type": "object",
            "optional": true,
            "description": "Optional filter (role/id). Reserved for later.",
          },
        },
      } : Json),
    ),
    tool_descriptor(
      "get_state",
      "Read runtime counters and dirty element ids.",
      ({ "type": "object", "properties": {} } : Json),
    ),
    tool_descriptor(
      "get_frame",
      "Read what the compositor paints to the screen right now (the visible frame's text).",
      ({ "type": "object", "properties": {} } : Json),
    ),
    tool_descriptor(
      "get_capabilities",
      "List the operations this host accepts.",
      ({ "type": "object", "properties": {} } : Json),
    ),
    tool_descriptor(
      "dispatch_command",
      "Fire a command intent (Activate/Submit/Copy/Paste/...).",
      ({
        "type": "object",
        "properties": {
          "intent": {
            "type": "string",
            "enum": [
              "Activate",
              "Submit",
              "Cancel",
              "Copy",
              "Cut",
              "Paste",
              "Undo",
              "Redo",
              "SelectAll",
              "OpenContextMenu",
            ],
          },
        },
        "required": ["intent"],
      } : Json),
    ),
    tool_descriptor(
      "dispatch_event",
      "Inject an AppEvent as if from a user (pointer/keyboard/...).",
      ({
        "type": "object",
        "properties": {
          "event": { "type": "object", "description": "An AppEvent JSON object (MVP: {kind:'Pointer',position:{x,y},phase:'Down'|'Up'})." },
        },
        "required": ["event"],
      } : Json),
    ),
    tool_descriptor(
      "subscribe_events",
      "Stream AppEvents to the agent as notifications/events (FrameTick suppressed).",
      ({
        "type": "object",
        "properties": {
          "types": { "type": "array", "optional": true, "description": "Optional coarse category filter." },
        },
      } : Json),
    ),
  ]
  tools.to_json()
}

///|
/// Build a JSON-RPC error response.
pub fn rpc_error(id : Json, code : Int, message : String) -> Json {
  ({
    "jsonrpc": "2.0",
    "id": id,
    "error": { "code": code, "message": message },
  } : Json)
}

///|
/// Convenience: build an error response when the request id is unavailable
/// (e.g. the request failed to parse). The id is emitted as JSON null.
pub fn rpc_error_no_id(code : Int, message : String) -> Json {
  rpc_error(json_null(), code, message)
}

///|
/// Build a JSON-RPC success response.
fn rpc_result(id : Json, result : Json) -> Json {
  ({ "jsonrpc": "2.0", "id": id, "result": result } : Json)
}

///|
/// Extract the request id from a JSON-RPC request (number, string, or null).
fn rpc_id(request : Json) -> Json {
  match request {
    Json::Object(fields) =>
      match fields.get("id") {
        Some(v) => v
        None => json_null()
      }
    _ => json_null()
  }
}

///|
/// Extract the method name from a JSON-RPC request.
fn rpc_method(request : Json) -> String? {
  match request {
    Json::Object(fields) =>
      match fields.get("method") {
        Some(Json::String(m)) => Some(m)
        _ => None
      }
    _ => None
  }
}

///|
/// Route a single parsed JSON-RPC request onto `host`. Returns the response
/// (a Json object). Events are not streamed (no notification sink); use
/// `route_notify` to receive event notifications from a subscribe_events call.
pub fn[Host : @agent.AgentHost] route(
  host : Host,
  request : Json,
) -> Json {
  route_notify(host, request, _notification => ())
}

///|
/// Like `route`, but `notify` receives one JSON-RPC notification object per
/// observed event once the agent has called `subscribe_events`. Used by the
/// stdio main loop to push `notifications/events` lines to the client.
pub fn[Host : @agent.AgentHost] route_notify(
  host : Host,
  request : Json,
  notify : (Json) -> Unit,
) -> Json {
  let id = rpc_id(request)
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") =>
      rpc_result(
        id,
        ({
          "protocolVersion": mcp_protocol_version,
          "capabilities": { "tools": {} },
          "serverInfo": {
            "name": "moui-agent",
            "version": "0.1.0",
          },
        } : Json),
      )
    Some("tools/list") => {
      let result : Json = { "tools": mcp_tools() }
      rpc_result(id, result)
    }
    Some("tools/call") => route_tool_call(host, id, request, notify)
    Some(name) =>
      rpc_error(id, -32601, "Method not found: \{name}")
  }
}

///|
/// Handle a tools/call request: look up the tool by name and invoke it.
fn[Host : @agent.AgentHost] route_tool_call(
  host : Host,
  id : Json,
  request : Json,
  notify : (Json) -> Unit,
) -> Json {
  let params = match request {
    Json::Object(fields) =>
      match fields.get("params") {
        Some(Json::Object(p)) => p
        _ => return rpc_error(id, -32602, "Invalid params: missing params object")
      }
    _ => return rpc_error(id, -32602, "Invalid params")
  }
  let name = match params.get("name") {
    Some(Json::String(n)) => n
    _ => return rpc_error(id, -32602, "Invalid params: missing tool name")
  }
  // MCP wraps tool results in a content array. MVP returns a single text block.
  let text = match name {
    "get_semantics" => (host.semantics().to_json() : Json).stringify()
    "get_state" => (host.state().to_json() : Json).stringify()
    "get_frame" => {
      // The compositor's current rendered output — what the user SEES on screen.
      (host.frame().to_json() : Json).stringify()
    }
    "get_capabilities" => {
      let caps : Array[Json] = host.capabilities().map(c => c.to_json())
      caps.to_json().stringify()
    }
    "dispatch_command" => {
      match read_intent(params) {
        Some(intent) =>
          (host.dispatch_command(intent).to_json() : Json).stringify()
        None =>
          return rpc_error(
            id,
            -32602,
            "Invalid params: missing or unknown 'intent'",
          )
      }
    }
    "dispatch_event" => {
      // Decode the AppEvent payload and inject it through the host. The host
      // routes it via runtime.dispatch_event — same path a real input takes.
      match read_event(params) {
        Some(event) =>
          (host.dispatch_event(event).to_json() : Json).stringify()
        None =>
          return rpc_error(
            id,
            -32602,
            "Invalid params: could not decode 'event' as an AppEvent (MVP supports Pointer)",
          )
      }
    }
    "subscribe_events" => {
      // Register a host subscription that pushes each event to `notify` as a
      // JSON-RPC notification. Returns the subscription token immediately.
      let token = host.subscribe_events(
        @agent.EventFilter::All,
        event => {
          let notification : Json = {
            "jsonrpc": "2.0",
            "method": "notifications/events",
            "params": { "event": event.to_json() },
          }
          notify(notification)
        },
      )
      return rpc_result(
        id,
        ({ "subscribed": true, "token": token.id() } : Json),
      )
    }
    _ =>
      return rpc_error(id, -32602, "Unknown tool: \{name}")
  }
  rpc_result(
    id,
    ({
      "content": [{ "type": "text", "text": text }],
    } : Json),
  )
}

///|
/// Read a CommandIntent from a tools/call params object's arguments.intent.
fn read_intent(params : Map[String, Json]) -> @core.CommandIntent? {
  match params.get("arguments") {
    Some(Json::Object(args)) =>
      match args.get("intent") {
        Some(v) => @agent.command_intent_from_json(v)
        None => None
      }
    _ => None
  }
}

///|
/// Read an AppEvent from a tools/call params object's arguments.event.
fn read_event(params : Map[String, Json]) -> @core.AppEvent? {
  match params.get("arguments") {
    Some(Json::Object(args)) =>
      match args.get("event") {
        Some(v) => @agent.app_event_from_json(v)
        None => None
      }
    _ => None
  }
}
