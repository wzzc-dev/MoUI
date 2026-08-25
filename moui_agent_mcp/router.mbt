///|
let mcp_protocol_version : String = "2024-11-05"

///|
priv enum ToolInvocation {
  ReadSemantics(@core.SemanticsGeneration?)
  PerformAction(@agent.AgentActionRequest)
  AgentReadTrace(UInt64)
  AgentReplayTrace(@agent.AgentReplayRequest)
  AgentReadPolicyState
  DiagnosticsReadState
  DiagnosticsReadPaint
  DiagnosticsDispatchEvent(@core.AppEvent)
  DiagnosticsDispatchCommand(@core.CommandIntent)
}

///|
/// Agent observability tools are opt-in. Keeping this registry separate from
/// the default semantic registry preserves compatibility for existing MCP
/// clients that expect exactly two tools.
fn[Host : @agent.AgentTraceHost] agent_tool_registry(
  _host : Host,
) -> Array[ToolSpec[Host]] {
  [
    {
      name: "agent_read_trace",
      description: "Read Agent action trace entries from an explicit cursor.",
      input: agent_read_trace_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_agent_read_trace_tool,
      },
    },
    {
      name: "agent_replay_trace",
      description: "Replay trace entries with Generation and policy checks.",
      input: agent_replay_trace_input_codec(),
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_agent_replay_trace_tool,
      },
    },
    {
      name: "agent_read_policy_state",
      description: "Read pending confirmations and trace counters.",
      input: {
        schema: object_schema(Json::empty_object()),
        decode: decode_agent_read_policy_state_invocation,
      },
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_agent_read_policy_state_tool,
      },
    },
  ]
}

///|
fn[Host : @agent.AgentHost] semantic_tool_registry(
  _host : Host,
) -> Array[ToolSpec[Host]] {
  [
    {
      name: "read_semantics",
      description: "Read an atomically committed semantics snapshot or delta.",
      input: read_semantics_input_codec(),
      output: {
        schema: tool_output_schema(semantics_read_value_schema()),
        dispatch: dispatch_read_semantics_tool,
      },
    },
    {
      name: "perform_action",
      description: "Perform a typed action on a committed semantics target.",
      input: perform_action_input_codec(),
      output: {
        schema: tool_output_schema(action_receipt_value_schema()),
        dispatch: dispatch_perform_action_tool,
      },
    },
  ]
}

///|
fn[Host : @agent.AgentDiagnosticsHost] diagnostics_tool_registry(
  _host : Host,
) -> Array[ToolSpec[Host]] {
  [
    {
      name: "diagnostics_read_state",
      description: "Read aggregate runtime lifecycle counters.",
      input: {
        schema: object_schema(Json::empty_object()),
        decode: decode_diagnostics_read_state_invocation,
      },
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_diagnostics_read_state_tool,
      },
    },
    {
      name: "diagnostics_read_paint",
      description: "Read the current paint command summary.",
      input: {
        schema: object_schema(Json::empty_object()),
        decode: decode_diagnostics_read_paint_invocation,
      },
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_diagnostics_read_paint_tool,
      },
    },
    {
      name: "diagnostics_dispatch_event",
      description: "Inject a raw diagnostic input event.",
      input: {
        schema: object_schema(({ "event": { "type": "object" } } : Json), required=[
          "event",
        ]),
        decode: decode_diagnostics_dispatch_event_invocation,
      },
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_diagnostics_event_tool,
      },
    },
    {
      name: "diagnostics_dispatch_command",
      description: "Dispatch a global diagnostic command intent.",
      input: {
        schema: object_schema(({ "intent": { "type": "string" } } : Json), required=[
          "intent",
        ]),
        decode: decode_diagnostics_dispatch_command_invocation,
      },
      output: {
        schema: tool_output_schema(({ "type": "object" } : Json)),
        dispatch: dispatch_diagnostics_command_tool,
      },
    },
  ]
}

///|
fn[Host : @agent.AgentHost + @agent.AgentDiagnosticsHost] full_tool_registry(
  host : Host,
) -> Array[ToolSpec[Host]] {
  let tools = semantic_tool_registry(host)
  tools.append(diagnostics_tool_registry(host))
  tools
}

///|
fn[Host] ToolSpec::descriptor(self : ToolSpec[Host]) -> Json {
  (
    {
      "name": self.name,
      "description": self.description,
      "inputSchema": self.input.schema,
      "outputSchema": self.output.schema,
    } : Json)
}

///|
fn[Host] ToolSpec::invoke(
  self : ToolSpec[Host],
  host : Host,
  id : Json,
  arguments : Map[String, Json],
) -> Json {
  match (self.input.decode)(arguments) {
    Err(message) => tool_failure(id, "invalid_arguments", message)
    Ok(invocation) => (self.output.dispatch)(host, id, invocation)
  }
}

///|
fn[Host] find_tool(
  name : String,
  registry : Array[ToolSpec[Host]],
) -> ToolSpec[Host]? {
  for spec in registry {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
fn json_null() -> Json {
  (None : String?).to_json()
}

///|
pub fn rpc_error(id : Json, code : Int, message : String) -> Json {
  (
    {
      "jsonrpc": "2.0",
      "id": id,
      "error": { "code": code, "message": message },
    } : Json)
}

///|
pub fn rpc_error_no_id(code : Int, message : String) -> Json {
  rpc_error(json_null(), code, message)
}

///|
fn rpc_result(id : Json, result : Json) -> Json {
  ({ "jsonrpc": "2.0", "id": id, "result": result } : Json)
}

///|
fn rpc_id(request : Json) -> Json {
  match request {
    Json::Object(fields) => fields.get("id").unwrap_or(json_null())
    _ => json_null()
  }
}

///|
fn rpc_method(request : Json) -> String? {
  match request {
    Json::Object(fields) =>
      match fields.get("jsonrpc") {
        Some(Json::String("2.0")) =>
          match fields.get("method") {
            Some(Json::String(method_name)) => Some(method_name)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn tool_envelope_success(value : Json) -> Json {
  ({ "ok": true, "value": value } : Json)
}

///|
fn tool_envelope_error(code : String, message : String, details : Json) -> Json {
  (
    {
      "ok": false,
      "error": { "code": code, "message": message, "details": details },
    } : Json)
}

///|
fn tool_response(id : Json, envelope : Json, is_error : Bool) -> Json {
  let result : Json = {
    "content": [{ "type": "text", "text": envelope.stringify() }],
    "structuredContent": envelope,
    "isError": is_error,
  }
  rpc_result(id, result)
}

///|
fn tool_success(id : Json, value : Json) -> Json {
  tool_response(id, tool_envelope_success(value), false)
}

///|
fn tool_failure(
  id : Json,
  code : String,
  message : String,
  details? : Json = Json::empty_object(),
) -> Json {
  tool_response(id, tool_envelope_error(code, message, details), true)
}

///|
fn semantics_action_kind_code(kind : @core.SemanticsActionKind) -> String {
  match kind {
    @core.SemanticsActionKind::Activate => "activate"
    @core.SemanticsActionKind::Focus => "focus"
    @core.SemanticsActionKind::SetText => "set_text"
    @core.SemanticsActionKind::Submit => "submit"
    @core.SemanticsActionKind::Scroll => "scroll"
    @core.SemanticsActionKind::Select => "select"
    @core.SemanticsActionKind::Expand => "expand"
    @core.SemanticsActionKind::Collapse => "collapse"
    @core.SemanticsActionKind::Dismiss => "dismiss"
    @core.SemanticsActionKind::Increment => "increment"
    @core.SemanticsActionKind::Decrement => "decrement"
    @core.SemanticsActionKind::SetNumericValue => "set_numeric_value"
    @core.SemanticsActionKind::SetSelection => "set_selection"
    @core.SemanticsActionKind::ShowMenu => "show_menu"
  }
}

///|
fn semantics_target_json(target : @core.SemanticsTarget) -> Json {
  match target {
    @core.SemanticsTarget::BySemanticId(id) =>
      ({ "kind": "semantic_id", "id": id } : Json)
    @core.SemanticsTarget::ByNodeId(id) =>
      ({ "kind": "node_id", "id": id } : Json)
  }
}

///|
fn agent_action_error_details(error : @agent.AgentActionError) -> Json {
  match error {
    @agent.AgentActionError::HostClosed
    | @agent.AgentActionError::ReentrantDispatch => Json::empty_object()
    @agent.AgentActionError::PolicyDenied(reason)
    | @agent.AgentActionError::ConfirmationRejected(reason) =>
      ({ "reason": reason } : Json)
    @agent.AgentActionError::ConfirmationRequired(request_id)
    | @agent.AgentActionError::ConfirmationExpired(request_id) =>
      ({ "request_id": request_id } : Json)
    @agent.AgentActionError::StaleGeneration(expected, current) =>
      ({ "expected": expected, "current": current } : Json)
    @agent.AgentActionError::TargetNotFound(target)
    | @agent.AgentActionError::TargetDisabled(target) =>
      ({ "target": semantics_target_json(target) } : Json)
    @agent.AgentActionError::TargetAmbiguous(id) =>
      ({ "semantic_id": id } : Json)
    @agent.AgentActionError::ActionUnavailable(target, kind)
    | @agent.AgentActionError::HandlerRejected(target, kind) =>
      (
        {
          "target": semantics_target_json(target),
          "action": semantics_action_kind_code(kind),
        } : Json)
  }
}

///|
fn initialize_result() -> Json {
  (
    {
      "protocolVersion": mcp_protocol_version,
      "capabilities": { "tools": Json::empty_object() },
      "serverInfo": { "name": "moui-agent", "version": "0.1.10" },
    } : Json)
}

///|
fn[Host] list_tools(id : Json, registry : Array[ToolSpec[Host]]) -> Json {
  let tools : Array[Json] = registry.map(spec => spec.descriptor())
  rpc_result(id, ({ "tools": tools } : Json))
}

///|
pub fn[Host : @agent.AgentHost] route(host : Host, request : Json) -> Json {
  let id = rpc_id(request)
  let registry = semantic_tool_registry(host)
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") => rpc_result(id, initialize_result())
    Some("tools/list") => list_tools(id, registry)
    Some("tools/call") => route_tool_call(host, id, request, registry)
    Some(method_name) =>
      rpc_error(id, -32601, "Method not found: \{method_name}")
  }
}

///|
pub fn[Host : @agent.AgentHost + @agent.AgentDiagnosticsHost] route_with_diagnostics(
  host : Host,
  request : Json,
) -> Json {
  let id = rpc_id(request)
  let registry = full_tool_registry(host)
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") => rpc_result(id, initialize_result())
    Some("tools/list") => list_tools(id, registry)
    Some("tools/call") => route_tool_call(host, id, request, registry)
    Some(method_name) =>
      rpc_error(id, -32601, "Method not found: \{method_name}")
  }
}

///|
/// Route semantic tools plus the explicit Agent Inspector surface. This is a
/// separate entrypoint by design: callers must opt in before trace, replay or
/// policy state becomes visible to an MCP client.
pub fn[Host : @agent.AgentHost + @agent.AgentTraceHost] route_with_agent_tools(
  host : Host,
  request : Json,
) -> Json {
  let id = rpc_id(request)
  let registry = semantic_tool_registry(host)
  registry.append(agent_tool_registry(host))
  match rpc_method(request) {
    None => rpc_error(id, -32600, "Invalid Request: missing method")
    Some("initialize") => rpc_result(id, initialize_result())
    Some("tools/list") => list_tools(id, registry)
    Some("tools/call") => route_tool_call(host, id, request, registry)
    Some(method_name) =>
      rpc_error(id, -32601, "Method not found: \{method_name}")
  }
}

///|
fn call_envelope(
  id : Json,
  request : Json,
) -> Result[(String, Map[String, Json]), Json] {
  guard request is Json::Object(fields) else {
    return Err(rpc_error(id, -32600, "Invalid Request"))
  }
  guard fields.get("params") is Some(Json::Object(params)) else {
    return Err(rpc_error(id, -32602, "Invalid tools/call params object"))
  }
  guard params.get("name") is Some(Json::String(name)) else {
    return Err(rpc_error(id, -32602, "Invalid tools/call tool name"))
  }
  let arguments = match params.get("arguments") {
    None => Map([])
    Some(Json::Object(arguments)) => arguments
    _ =>
      return Err(rpc_error(id, -32602, "Invalid tools/call arguments object"))
  }
  Ok((name, arguments))
}

///|
fn[Host] route_tool_call(
  host : Host,
  id : Json,
  request : Json,
  registry : Array[ToolSpec[Host]],
) -> Json {
  match call_envelope(id, request) {
    Err(response) => response
    Ok((name, arguments)) =>
      match find_tool(name, registry) {
        None => tool_failure(id, "unknown_tool", "Unknown tool: \{name}")
        Some(spec) => spec.invoke(host, id, arguments)
      }
  }
}

///|
fn[Host : @agent.AgentHost] dispatch_read_semantics_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ReadSemantics(since) =>
      match host.read_semantics(since) {
        Ok(read) => tool_success(id, agent_semantics_read_json(read))
        Err(error) =>
          tool_failure(
            id,
            error.code(),
            "Agent host could not read committed semantics.",
          )
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentHost] dispatch_perform_action_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    PerformAction(action_request) =>
      match host.perform_action(action_request) {
        Ok(receipt) => tool_success(id, receipt.to_json())
        Err(error) =>
          tool_failure(
            id,
            error.code(),
            "Semantic action was rejected.",
            details=agent_action_error_details(error),
          )
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentTraceHost] dispatch_agent_read_trace_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ToolInvocation::AgentReadTrace(cursor) =>
      match @agent.AgentTraceHost::read_trace(host, cursor) {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(id, error.code(), "Agent trace host is closed.")
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentTraceHost] dispatch_agent_replay_trace_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ToolInvocation::AgentReplayTrace(request) =>
      match @agent.AgentTraceHost::replay_trace(host, request) {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(
            id,
            error.code(),
            "Agent trace replay was rejected.",
            details=agent_action_error_details(error),
          )
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentTraceHost] dispatch_agent_read_policy_state_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    ToolInvocation::AgentReadPolicyState =>
      tool_success(id, @agent.AgentTraceHost::read_policy_state(host).to_json())
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentDiagnosticsHost] dispatch_diagnostics_read_state_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    DiagnosticsReadState =>
      match host.runtime_state() {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(id, error.code(), "Diagnostics host is closed.")
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentDiagnosticsHost] dispatch_diagnostics_read_paint_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    DiagnosticsReadPaint =>
      match host.paint_summary() {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(id, error.code(), "Diagnostics host is closed.")
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentDiagnosticsHost] dispatch_diagnostics_event_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    DiagnosticsDispatchEvent(event) =>
      match host.dispatch_event(event) {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(id, error.code(), "Diagnostics host is closed.")
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn[Host : @agent.AgentDiagnosticsHost] dispatch_diagnostics_command_tool(
  host : Host,
  id : Json,
  invocation : ToolInvocation,
) -> Json {
  match invocation {
    DiagnosticsDispatchCommand(intent) =>
      match host.dispatch_command(intent) {
        Ok(value) => tool_success(id, value.to_json())
        Err(error) =>
          tool_failure(id, error.code(), "Diagnostics host is closed.")
      }
    _ => tool_registry_mismatch(id)
  }
}

///|
fn tool_registry_mismatch(id : Json) -> Json {
  tool_failure(
    id, "internal_tool_registry_error", "Tool registry decoder and dispatcher do not match.",
  )
}

///|
fn fields_are_exact(
  fields : Map[String, Json],
  allowed : Array[String],
) -> Bool {
  for name, _ in fields {
    if !allowed.contains(name) {
      return false
    }
  }
  true
}

///|
fn decode_read_semantics_invocation_with_codec(
  arguments : Map[String, Json],
  generation : JsonCodec[UInt64],
) -> Result[ToolInvocation, String] {
  if !fields_are_exact(arguments, ["since"]) {
    return Err("read_semantics contains unknown arguments.")
  }
  match decode_since_with_codec(arguments, generation) {
    Ok(since) => Ok(ToolInvocation::ReadSemantics(since))
    Err(message) => Err(message)
  }
}

///|
fn decode_action_request_with_codecs(
  arguments : Map[String, Json],
  target : JsonCodec[@core.SemanticsTarget],
  action : JsonCodec[@core.SemanticsAction],
  precondition : JsonCodec[@agent.AgentGenerationPrecondition],
) -> Result[ToolInvocation, String] {
  if !fields_are_exact(arguments, ["target", "action", "precondition"]) {
    return Err("perform_action contains unknown arguments.")
  }
  guard arguments.get("target") is Some(target_json) else {
    return Err("Missing tagged 'target' object.")
  }
  guard arguments.get("action") is Some(action_json) else {
    return Err("Missing tagged 'action' object.")
  }
  guard arguments.get("precondition") is Some(precondition_json) else {
    return Err("Missing tagged 'precondition' object.")
  }
  match
    (
      (target.decode)(target_json),
      (action.decode)(action_json),
      (precondition.decode)(precondition_json),
    ) {
    (Ok(target), Ok(action), Ok(precondition)) =>
      Ok(ToolInvocation::PerformAction({ target, action, precondition }))
    (Err(message), _, _) => Err(message)
    (_, Err(message), _) => Err(message)
    (_, _, Err(message)) => Err(message)
  }
}

///|
fn decode_diagnostics_read_state_invocation(
  arguments : Map[String, Json],
) -> Result[ToolInvocation, String] {
  if arguments.length() == 0 {
    Ok(ToolInvocation::DiagnosticsReadState)
  } else {
    Err("diagnostics_read_state does not accept arguments.")
  }
}

///|
fn decode_diagnostics_read_paint_invocation(
  arguments : Map[String, Json],
) -> Result[ToolInvocation, String] {
  if arguments.length() == 0 {
    Ok(ToolInvocation::DiagnosticsReadPaint)
  } else {
    Err("diagnostics_read_paint does not accept arguments.")
  }
}

///|
fn decode_diagnostics_dispatch_event_invocation(
  arguments : Map[String, Json],
) -> Result[ToolInvocation, String] {
  if !fields_are_exact(arguments, ["event"]) {
    return Err("diagnostics_dispatch_event contains unknown arguments.")
  }
  match decode_event_argument(arguments) {
    Some(event) => Ok(ToolInvocation::DiagnosticsDispatchEvent(event))
    None => Err("Invalid event payload.")
  }
}

///|
fn decode_diagnostics_dispatch_command_invocation(
  arguments : Map[String, Json],
) -> Result[ToolInvocation, String] {
  if !fields_are_exact(arguments, ["intent"]) {
    return Err("diagnostics_dispatch_command contains unknown arguments.")
  }
  match decode_command_argument(arguments) {
    Some(intent) => Ok(ToolInvocation::DiagnosticsDispatchCommand(intent))
    None => Err("Invalid command intent.")
  }
}

///|
fn decode_since_with_codec(
  arguments : Map[String, Json],
  generation : JsonCodec[UInt64],
) -> Result[@core.SemanticsGeneration?, String] {
  match arguments.get("since") {
    None => Ok(None)
    Some(value) =>
      match (generation.decode)(value) {
        Ok(generation) => Ok(Some(@core.SemanticsGeneration::new(generation)))
        Err(_) => Err("'since' must be a canonical UInt64 decimal string.")
      }
  }
}

///|
fn json_string_field(fields : Map[String, Json], name : String) -> String? {
  match fields.get(name) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn decode_target_with_codecs(
  fields : Map[String, Json],
  semantic_id : JsonCodec[@core.SemanticId],
  node_id : JsonCodec[UInt64],
) -> Result[@core.SemanticsTarget, String] {
  if !fields_are_exact(fields, ["kind", "id"]) {
    return Err("Target contains unknown fields.")
  }
  guard json_string_field(fields, "kind") is Some(kind) else {
    return Err("Target requires string 'kind'.")
  }
  guard fields.get("id") is Some(value) else {
    return Err("Target requires 'id'.")
  }
  match kind {
    "semantic_id" =>
      match (semantic_id.decode)(value) {
        Ok(id) => Ok(@core.SemanticsTarget::BySemanticId(id))
        Err(message) => Err(message)
      }
    "node_id" =>
      match (node_id.decode)(value) {
        Ok(id) =>
          Ok(@core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(id)))
        Err(_) => Err("Invalid node_id.")
      }
    _ => Err("Unknown target kind.")
  }
}

///|
fn decode_action(
  fields : Map[String, Json],
) -> Result[@core.SemanticsAction, String] {
  guard json_string_field(fields, "kind") is Some(kind) else {
    return Err("Action requires string 'kind'.")
  }
  match kind {
    "activate" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Activate)
      } else {
        Err("activate contains unknown fields.")
      }
    "focus" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Focus)
      } else {
        Err("focus contains unknown fields.")
      }
    "set_text" =>
      match
        (
          fields_are_exact(fields, ["kind", "value"]),
          json_string_field(fields, "value"),
        ) {
        (false, _) => Err("set_text contains unknown fields.")
        (true, Some(value)) => Ok(@core.SemanticsAction::SetText(value))
        (true, None) => Err("set_text requires string 'value'.")
      }
    "submit" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Submit)
      } else {
        Err("submit contains unknown fields.")
      }
    "scroll" =>
      match
        (
          fields_are_exact(fields, ["kind", "direction"]),
          json_string_field(fields, "direction"),
        ) {
        (false, _) => Err("scroll contains unknown fields.")
        (true, Some(direction)) =>
          match decode_scroll_direction(direction) {
            Some(value) => Ok(@core.SemanticsAction::Scroll(value))
            None => Err("Invalid scroll direction.")
          }
        (true, None) => Err("scroll requires string 'direction'.")
      }
    "select" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Select)
      } else {
        Err("select contains unknown fields.")
      }
    "expand" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Expand)
      } else {
        Err("expand contains unknown fields.")
      }
    "collapse" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Collapse)
      } else {
        Err("collapse contains unknown fields.")
      }
    "dismiss" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Dismiss)
      } else {
        Err("dismiss contains unknown fields.")
      }
    "increment" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Increment)
      } else {
        Err("increment contains unknown fields.")
      }
    "decrement" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::Decrement)
      } else {
        Err("decrement contains unknown fields.")
      }
    "set_numeric_value" =>
      match fields.get("value") {
        Some(Json::Number(value, repr=_)) if fields_are_exact(fields, [
            "kind", "value",
          ]) => Ok(@core.SemanticsAction::SetNumericValue(value))
        Some(_) => Err("set_numeric_value requires numeric 'value'.")
        None => Err("set_numeric_value requires numeric 'value'.")
      }
    "set_selection" =>
      match (fields.get("start"), fields.get("end")) {
        (Some(Json::Number(start, repr=_)), Some(Json::Number(end, repr=_))) if fields_are_exact(
            fields,
            ["kind", "start", "end"],
          ) &&
          start >= 0.0 &&
          end >= 0.0 &&
          start == start.to_int().to_double() &&
          end == end.to_int().to_double() =>
          Ok(
            @core.SemanticsAction::SetSelection(
              @core.TextRange::new(start=start.to_int(), end=end.to_int()),
            ),
          )
        _ => Err("set_selection requires non-negative integer start and end.")
      }
    "show_menu" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@core.SemanticsAction::ShowMenu)
      } else {
        Err("show_menu contains unknown fields.")
      }
    _ => Err("Unknown action kind.")
  }
}

///|
fn decode_scroll_direction(value : String) -> @core.SemanticsScrollDirection? {
  match value {
    "forward" => Some(@core.SemanticsScrollDirection::Forward)
    "backward" => Some(@core.SemanticsScrollDirection::Backward)
    "up" => Some(@core.SemanticsScrollDirection::Up)
    "down" => Some(@core.SemanticsScrollDirection::Down)
    "left" => Some(@core.SemanticsScrollDirection::Left)
    "right" => Some(@core.SemanticsScrollDirection::Right)
    _ => None
  }
}

///|
fn decode_precondition_with_codec(
  fields : Map[String, Json],
  generation : JsonCodec[UInt64],
) -> Result[@agent.AgentGenerationPrecondition, String] {
  guard json_string_field(fields, "kind") is Some(kind) else {
    return Err("Precondition requires string 'kind'.")
  }
  match kind {
    "latest" =>
      if fields_are_exact(fields, ["kind"]) {
        Ok(@agent.AgentGenerationPrecondition::Latest)
      } else {
        Err("latest precondition contains unknown fields.")
      }
    "exact" =>
      match
        (
          fields_are_exact(fields, ["kind", "generation"]),
          fields.get("generation"),
        ) {
        (false, _) => Err("exact precondition contains unknown fields.")
        (true, Some(value)) =>
          match (generation.decode)(value) {
            Ok(generation) =>
              Ok(
                @agent.AgentGenerationPrecondition::Exact(
                  @core.SemanticsGeneration::new(generation),
                ),
              )
            Err(_) => Err("Invalid exact generation.")
          }
        (true, None) => Err("exact precondition requires string 'generation'.")
      }
    _ => Err("Unknown precondition kind.")
  }
}

///|
fn agent_semantics_issue_json(issue : @agent.AgentSemanticsIssue) -> Json {
  match issue {
    @agent.AgentSemanticsIssue::DuplicateSemanticId(id, nodes) =>
      (
        { "kind": "duplicate_semantic_id", "semantic_id": id, "nodes": nodes } :
        Json)
    @agent.AgentSemanticsIssue::MissingRelationTarget(source, kind, id) =>
      (
        {
          "kind": "missing_relation_target",
          "source": source,
          "relation": semantics_relation_kind_code(kind),
          "semantic_id": id,
        } : Json)
    @agent.AgentSemanticsIssue::AmbiguousRelationTarget(source, kind, id, nodes) =>
      (
        {
          "kind": "ambiguous_relation_target",
          "source": source,
          "relation": semantics_relation_kind_code(kind),
          "semantic_id": id,
          "nodes": nodes,
        } : Json)
  }
}

///|
fn semantics_relation_kind_code(kind : @core.SemanticsRelationKind) -> String {
  match kind {
    @core.SemanticsRelationKind::LabelledBy => "labelled_by"
    @core.SemanticsRelationKind::DescribedBy => "described_by"
    @core.SemanticsRelationKind::Controls => "controls"
    @core.SemanticsRelationKind::ErrorMessage => "error_message"
    @core.SemanticsRelationKind::ActiveDescendant => "active_descendant"
  }
}

///|
fn semantics_role_code(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "none"
    @core.SemanticsRole::Text => "text"
    @core.SemanticsRole::Link => "link"
    @core.SemanticsRole::Heading => "heading"
    @core.SemanticsRole::Navigation => "navigation"
    @core.SemanticsRole::Main => "main"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "text_field"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "list_item"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "scroll_view"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radio"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progress"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::ButtonGroup => "button_group"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "form_field"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "tree_item"
    @core.SemanticsRole::Group => "group"
    @core.SemanticsRole::WebView => "web_view"
    @core.SemanticsRole::Image => "image"
    @core.SemanticsRole::Alert => "alert"
    @core.SemanticsRole::Status => "status"
    @core.SemanticsRole::ComboBox => "combo_box"
    @core.SemanticsRole::Option => "option"
    @core.SemanticsRole::Table => "table"
    @core.SemanticsRole::Row => "row"
    @core.SemanticsRole::Cell => "cell"
    @core.SemanticsRole::Separator => "separator"
  }
}

///|
fn optional_node_id_json(value : @core.SemanticsNodeId?) -> Json {
  match value {
    Some(node_id) => node_id.to_json()
    None => json_null()
  }
}

///|
fn optional_semantic_id_json(value : @core.SemanticId?) -> Json {
  match value {
    Some(semantic_id) => semantic_id.to_json()
    None => json_null()
  }
}

///|
fn optional_int_json(value : Int?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => json_null()
  }
}

///|
fn optional_checked_json(value : @core.SemanticsCheckedState?) -> Json {
  match value {
    Some(@core.SemanticsCheckedState::Unchecked) => "unchecked".to_json()
    Some(@core.SemanticsCheckedState::Checked) => "checked".to_json()
    Some(@core.SemanticsCheckedState::Mixed) => "mixed".to_json()
    None => json_null()
  }
}

///|
fn semantics_state_json(state : @core.SemanticsState) -> Json {
  (
    {
      "focused": state.focused,
      "disabled": state.disabled,
      "selected": state.selected,
      "pressed": state.pressed,
      "checked": optional_checked_json(state.checked),
      "expanded": state.expanded,
      "invalid": state.invalid,
      "required": state.required,
      "read_only": state.read_only,
      "busy": state.busy,
      "multiline": state.multiline,
      "password": state.password,
      "modal": state.modal,
    } : Json)
}

///|
fn semantics_live_code(value : @core.SemanticsLive) -> String {
  match value {
    @core.SemanticsLive::Off => "off"
    @core.SemanticsLive::Polite => "polite"
    @core.SemanticsLive::Assertive => "assertive"
  }
}

///|
fn accessibility_announcement_json(
  announcement : @agent.AgentAccessibilityAnnouncement,
) -> Json {
  (
    {
      "node_id": announcement.node_id,
      "generation": announcement.generation,
      "live": semantics_live_code(announcement.live),
      "atomic": announcement.is_atomic,
      "text": announcement.text,
    } : Json)
}

///|
fn semantics_node_json(node : @core.SemanticsNode) -> Json {
  (
    {
      "node_id": node.node_id,
      "semantic_id": optional_semantic_id_json(node.semantic_id),
      "role": semantics_role_code(node.role),
      "level": optional_int_json(node.level),
      "url": node.url,
      "label": node.label,
      "value": node.value,
      "description": node.description,
      "state": semantics_state_json(node.state),
      "numeric": node.numeric,
      "text": node.text,
      "collection": node.collection,
      "relations": node.relations,
      "live": semantics_live_code(node.live),
      "atomic": node.live_atomic,
      "actions": node.actions.map(semantics_action_kind_code),
      "focus_order": optional_int_json(node.focus_order),
      "frame": node.frame,
      "children": node.children,
    } : Json)
}

///|
fn agent_semantics_read_json(read : @agent.AgentSemanticsRead) -> Json {
  match read {
    @agent.AgentSemanticsRead::Full(snapshot) =>
      (
        {
          "kind": "full",
          "generation": snapshot.generation,
          "root": optional_node_id_json(snapshot.root),
          "focused": optional_node_id_json(snapshot.focused),
          "nodes": snapshot.nodes.map(semantics_node_json),
          "issues": snapshot.issues.map(agent_semantics_issue_json),
        } : Json)
    @agent.AgentSemanticsRead::Delta(delta) =>
      (
        {
          "kind": "delta",
          "from": delta.from,
          "to": delta.to,
          "root": optional_node_id_json(delta.root),
          "focused": optional_node_id_json(delta.focused),
          "upserted": delta.upserted.map(semantics_node_json),
          "removed": delta.removed,
          "issues": delta.issues.map(agent_semantics_issue_json),
          "announcements": delta.announcements.map(
            accessibility_announcement_json,
          ),
        } : Json)
    @agent.AgentSemanticsRead::Unchanged(generation) =>
      ({ "kind": "unchanged", "generation": generation } : Json)
  }
}

///|
fn decode_command_argument(
  arguments : Map[String, Json],
) -> @core.CommandIntent? {
  guard json_string_field(arguments, "intent") is Some(intent) else {
    return None
  }
  match intent {
    "Activate" => Some(@core.CommandIntent::Activate)
    "Submit" => Some(@core.CommandIntent::Submit)
    "Cancel" => Some(@core.CommandIntent::Cancel)
    "Copy" => Some(@core.CommandIntent::Copy)
    "Cut" => Some(@core.CommandIntent::Cut)
    "Paste" => Some(@core.CommandIntent::Paste)
    "Undo" => Some(@core.CommandIntent::Undo)
    "Redo" => Some(@core.CommandIntent::Redo)
    "SelectAll" => Some(@core.CommandIntent::SelectAll)
    "OpenContextMenu" => Some(@core.CommandIntent::OpenContextMenu)
    _ => None
  }
}

///|
fn decode_event_argument(arguments : Map[String, Json]) -> @core.AppEvent? {
  guard arguments.get("event") is Some(Json::Object(fields)) else {
    return None
  }
  guard json_string_field(fields, "kind") is Some("Pointer") else {
    return None
  }
  guard fields.get("position") is Some(Json::Object(position)) else {
    return None
  }
  guard position.get("x") is Some(Json::Number(x, repr=_)) else { return None }
  guard position.get("y") is Some(Json::Number(y, repr=_)) else { return None }
  guard json_string_field(fields, "phase") is Some(phase) else { return None }
  let pointer_phase = match phase {
    "Down" => @core.PointerPhase::Down
    "Up" => @core.PointerPhase::Up
    "Move" => @core.PointerPhase::Move
    "Cancel" => @core.PointerPhase::Cancel
    "Exit" => @core.PointerPhase::Exit
    _ => return None
  }
  Some(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase=pointer_phase,
      ),
    ),
  )
}
