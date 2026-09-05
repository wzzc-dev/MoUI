///|
struct RecordingHost {
  mut last_since : @core.SemanticsGeneration?
  mut last_action : @agent.AgentActionRequest?
  mut last_diagnostic : String?
  reject_action : Bool
  closed : Bool
}

///|
struct SemanticsWireHost {}

///|
pub impl @agent.AgentHost for SemanticsWireHost with fn read_semantics(
  _self,
  _since,
) {
  Ok(
    @agent.AgentSemanticsRead::Delta({
      from: @core.SemanticsGeneration::new(7UL),
      to: @core.SemanticsGeneration::new(8UL),
      root: None,
      focused: None,
      upserted: [],
      removed: [],
      issues: [
        @agent.AgentSemanticsIssue::MissingRelationTarget(
          @core.SemanticsNodeId::new(3UL),
          @core.SemanticsRelationKind::LabelledBy,
          @core.SemanticId::parse("missing.label").unwrap(),
        ),
      ],
      announcements: [
        {
          node_id: @core.SemanticsNodeId::new(4UL),
          generation: @core.SemanticsGeneration::new(8UL),
          live: @core.SemanticsLive::Assertive,
          is_atomic: true,
          text: "Validation failed",
        },
      ],
    }),
  )
}

///|
pub impl @agent.AgentHost for SemanticsWireHost with fn perform_action(
  _self,
  _request,
) {
  Err(@agent.AgentActionError::HostClosed)
}

///|
fn RecordingHost::new(
  reject_action? : Bool = false,
  closed? : Bool = false,
) -> RecordingHost {
  {
    last_since: None,
    last_action: None,
    last_diagnostic: None,
    reject_action,
    closed,
  }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn read_semantics(self, since) {
  self.last_since = since
  if self.closed {
    Err(@agent.AgentReadError::HostClosed)
  } else {
    Ok(
      @agent.AgentSemanticsRead::Full({
        generation: @core.SemanticsGeneration::new(7UL),
        root: None,
        focused: None,
        nodes: [],
        issues: [],
      }),
    )
  }
}

///|
pub impl @agent.AgentHost for RecordingHost with fn perform_action(
  self,
  request,
) {
  self.last_action = Some(request)
  if self.closed {
    Err(@agent.AgentActionError::HostClosed)
  } else if self.reject_action {
    Err(
      @agent.AgentActionError::StaleGeneration(
        @core.SemanticsGeneration::new(6UL),
        @core.SemanticsGeneration::new(7UL),
      ),
    )
  } else {
    Ok({
      before: @core.SemanticsGeneration::new(7UL),
      after: @core.SemanticsGeneration::new(8UL),
      pending_work: false,
    })
  }
}

///|
pub impl @agent.AgentDiagnosticsHost for RecordingHost with fn runtime_state(
  self,
) {
  self.last_diagnostic = Some("read_state")
  Ok({
    dispatched_count: 0,
    update_count: 0,
    pending_message_count: 0,
    active_subscription_count: 0,
    active_effect_task_count: 0,
  })
}

///|
pub impl @agent.AgentDiagnosticsHost for RecordingHost with fn paint_summary(
  self,
) {
  self.last_diagnostic = Some("read_paint")
  Ok({ texts: [], draw_command_count: 0 })
}

///|
pub impl @agent.AgentDiagnosticsHost for RecordingHost with fn dispatch_event(
  self,
  _event,
) {
  self.last_diagnostic = Some("dispatch_event")
  Ok({ accepted: true, reason: None })
}

///|
pub impl @agent.AgentDiagnosticsHost for RecordingHost with fn dispatch_command(
  self,
  _intent,
) {
  self.last_diagnostic = Some("dispatch_command")
  Ok({ accepted: true, reason: None })
}

///|
fn request(source : String) -> Json {
  @json.parse(source) catch {
    error => abort("invalid test request: \{error}")
  }
}

///|
fn tool_call(name : String, arguments : Json) -> Json {
  (
    {
      "jsonrpc": "2.0",
      "id": 99,
      "method": "tools/call",
      "params": { "name": name, "arguments": arguments },
    } : Json)
}

///|
fn listed_tool_count(response : Json) -> Int {
  guard response is Json::Object(root) &&
    root.get("result") is Some(Json::Object(result)) &&
    result.get("tools") is Some(Json::Array(tools)) else {
    abort("invalid tools/list response")
  }
  tools.length()
}

///|
fn listed_tool_descriptor(response : Json, name : String) -> Json {
  guard response is Json::Object(root) &&
    root.get("result") is Some(Json::Object(result)) &&
    result.get("tools") is Some(Json::Array(tools)) else {
    abort("invalid tools/list response")
  }
  for tool in tools {
    if tool is Json::Object(fields) &&
      fields.get("name") is Some(Json::String(found_name)) &&
      found_name == name {
      return tool
    }
  }
  abort("missing tool descriptor: \{name}")
}

///|
fn required_json_field(fields : Map[String, Json], name : String) -> Json {
  fields.get(name).unwrap_or_else(() => abort("missing JSON field: \{name}"))
}

///|
fn schema_property(schema : Json, name : String) -> Json {
  guard schema is Json::Object(schema_fields) &&
    schema_fields.get("properties") is Some(Json::Object(properties)) else {
    abort("schema has no properties")
  }
  required_json_field(properties, name)
}

///|
fn schema_variants(schema : Json) -> Array[Json] {
  guard schema is Json::Object(fields) &&
    fields.get("oneOf") is Some(Json::Array(variants)) else {
    abort("schema has no oneOf variants")
  }
  variants
}

///|
fn tagged_schema_variant(schema : Json, kind : String) -> Json {
  for variant in schema_variants(schema) {
    let kind_schema = schema_property(variant, "kind")
    if kind_schema is Json::Object(fields) &&
      fields.get("const") is Some(Json::String(found_kind)) &&
      found_kind == kind {
      return variant
    }
  }
  abort("missing tagged schema variant: \{kind}")
}

///|
fn array_item_schema(schema : Json) -> Json {
  guard schema is Json::Object(fields) else {
    abort("array schema is not an object")
  }
  required_json_field(fields, "items")
}

///|
fn semantic_action_arguments(target_kind : String, target_id : String) -> Json {
  (
    {
      "target": { "kind": target_kind, "id": target_id },
      "action": { "kind": "activate" },
      "precondition": { "kind": "latest" },
    } : Json)
}

///|
fn tool_error_details(response : Json) -> Map[String, Json] {
  guard response is Json::Object(root) &&
    root.get("result") is Some(Json::Object(result)) &&
    result.get("structuredContent") is Some(Json::Object(envelope)) &&
    envelope.get("error") is Some(Json::Object(error)) &&
    error.get("details") is Some(Json::Object(details)) else {
    abort("invalid structured tool error response")
  }
  details
}

///|
fn required_string_field(fields : Map[String, Json], name : String) -> String {
  match fields.get(name) {
    Some(Json::String(value)) => value
    _ => abort("missing string field: \{name}")
  }
}

///|
test "default tools list contains exactly the semantic surface" {
  let host = RecordingHost::new()
  let response = route(
    host,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  ).stringify()
  assert_eq(
    listed_tool_count(
      route(
        host,
        request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
      ),
    ),
    2,
  )
  assert_true(response.contains("read_semantics"))
  assert_true(response.contains("perform_action"))
  assert_true(response.contains("outputSchema"))
  assert_false(response.contains("diagnostics_"))
  assert_false(response.contains("dispatch_event"))
}

///|
test "diagnostics tools require the explicit diagnostics router" {
  let host = RecordingHost::new()
  let response = route_with_diagnostics(
    host,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  ).stringify()
  assert_eq(
    listed_tool_count(
      route_with_diagnostics(
        host,
        request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
      ),
    ),
    6,
  )
  assert_true(response.contains("read_semantics"))
  assert_true(response.contains("diagnostics_read_state"))
  assert_true(response.contains("diagnostics_dispatch_event"))
}

///|
test "diagnostics registry entry owns decoding and dispatch" {
  let host = RecordingHost::new()
  let response = route_with_diagnostics(
    host,
    tool_call("diagnostics_dispatch_command", ({ "intent": "Activate" } : Json)),
  ).stringify()
  assert_true(response.contains("\"isError\":false"))
  assert_true(host.last_diagnostic == Some("dispatch_command"))
}

///|
test "read_semantics returns structured content and text fallback" {
  let host = RecordingHost::new()
  let response = route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"read_semantics\",\"arguments\":{\"since\":\"5\"}}}",
    ),
  ).stringify()
  assert_true(response.contains("structuredContent"))
  assert_true(response.contains("\"isError\":false"))
  assert_true(response.contains("\\\"kind\\\":\\\"full\\\""))
  assert_true(host.last_since == Some(@core.SemanticsGeneration::new(5UL)))
}

///|
test "read_semantics explicitly encodes relation and announcement wire values" {
  let response = route(
    SemanticsWireHost::{  },
    tool_call("read_semantics", Json::empty_object()),
  ).stringify()
  assert_true(response.contains("\"relation\":\"labelled_by\""))
  assert_true(response.contains("\"live\":\"assertive\""))
  assert_true(response.contains("\"atomic\":true"))
  assert_false(response.contains("is_atomic"))
  assert_false(response.contains("LabelledBy"))
}

///|
test "perform_action decodes tagged typed action" {
  let host = RecordingHost::new()
  let response = route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"perform_action\",\"arguments\":{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter.increment\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"exact\",\"generation\":\"7\"}}}}",
    ),
  ).stringify()
  assert_true(response.contains("\"isError\":false"))
  guard host.last_action is Some(action) else {
    fail("host did not receive action")
  }
  assert_true(action.action == @core.SemanticsAction::Activate)
  assert_true(
    action.precondition ==
    @agent.AgentGenerationPrecondition::Exact(
      @core.SemanticsGeneration::new(7UL),
    ),
  )
}

///|
test "invalid action payload is a normal MCP tool error" {
  let host = RecordingHost::new()
  let response = route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"perform_action\",\"arguments\":{\"target\":{\"kind\":\"semantic_id\",\"id\":\"editor\"},\"action\":{\"kind\":\"set_text\"},\"precondition\":{\"kind\":\"latest\"}}}}",
    ),
  ).stringify()
  assert_true(response.contains("\"isError\":true"))
  assert_true(response.contains("invalid_arguments"))
  assert_false(response.contains("\"code\":-32602"))
  assert_true(host.last_action is None)
}

///|
test "business rejection is a structured tool error" {
  let host = RecordingHost::new(reject_action=true)
  let routed = route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"perform_action\",\"arguments\":{\"target\":{\"kind\":\"node_id\",\"id\":\"12\"},\"action\":{\"kind\":\"scroll\",\"direction\":\"down\"},\"precondition\":{\"kind\":\"latest\"}}}}",
    ),
  )
  let response = routed.stringify()
  assert_true(response.contains("\"isError\":true"))
  assert_true(response.contains("stale_generation"))
  assert_false(response.contains("StaleGeneration"))
  let details = tool_error_details(routed)
  assert_eq(required_string_field(details, "expected"), "6")
  assert_eq(required_string_field(details, "current"), "7")
  guard host.last_action is Some(action) else {
    fail("host did not receive action")
  }
  assert_true(
    action.action ==
    @core.SemanticsAction::Scroll(@core.SemanticsScrollDirection::Down),
  )
}

///|
test "malformed tools call envelope uses JSON-RPC invalid params" {
  let host = RecordingHost::new()
  let response = route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{}}",
    ),
  ).stringify()
  assert_true(response.contains("\"code\":-32602"))
  assert_false(response.contains("structuredContent"))
}

///|
test "malformed JSON-RPC version uses invalid request" {
  let host = RecordingHost::new()
  for
    source in [
      "{\"id\":1,\"method\":\"tools/list\"}", "{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"tools/list\"}",
    ] {
    let response = route(host, request(source)).stringify()
    assert_true(response.contains("\"code\":-32600"))
    assert_false(response.contains("structuredContent"))
  }
}

///|
test "typed registry rejects invalid targets actions payloads and generations" {
  let host = RecordingHost::new()
  let invalid_arguments : Array[Json] = [
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"bad id\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"unknown\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"set_text\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"scroll\",\"direction\":\"diagonal\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"exact\",\"generation\":\"18446744073709551616\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"exact\",\"generation\":\"01\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"node_id\",\"id\":\"0\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
    request(
      "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"activate\",\"value\":\"unexpected\"},\"precondition\":{\"kind\":\"latest\"}}",
    ),
  ]
  for arguments in invalid_arguments {
    let response = route(host, tool_call("perform_action", arguments)).stringify()
    assert_true(response.contains("\"isError\":true"))
    assert_true(response.contains("invalid_arguments"))
    assert_false(response.contains("\"code\":-32602"))
  }
  assert_true(host.last_action is None)
}

///|
test "UInt64 codecs keep descriptor schemas and decoders canonical" {
  let list_response = route(
    RecordingHost::new(),
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  )
  let read_descriptor = listed_tool_descriptor(list_response, "read_semantics")
  guard read_descriptor is Json::Object(read_fields) else {
    fail("read descriptor is not an object")
  }
  let since_schema = schema_property(
    required_json_field(read_fields, "inputSchema"),
    "since",
  )
  guard since_schema is Json::Object(since_fields) else {
    fail("since schema is not an object")
  }
  assert_eq(required_string_field(since_fields, "type"), "string")
  assert_true(
    since_fields.get("maxLength") is Some(Json::Number(max_length, repr=_)) &&
    max_length == 20.0,
  )
  assert_true(
    required_string_field(since_fields, "pattern").contains(
      "1844674407370955161[0-5]",
    ),
  )

  let action_descriptor = listed_tool_descriptor(
    list_response, "perform_action",
  )
  guard action_descriptor is Json::Object(action_fields) else {
    fail("perform_action descriptor is not an object")
  }
  let action_input = required_json_field(action_fields, "inputSchema")
  let node_target = tagged_schema_variant(
    schema_property(action_input, "target"),
    "node_id",
  )
  guard schema_property(node_target, "id") is Json::Object(node_id_fields) else {
    fail("node id schema is not an object")
  }
  assert_true(
    required_string_field(node_id_fields, "pattern").has_prefix("^([1-9]"),
  )
  assert_true(
    node_id_fields.get("maxLength") is Some(Json::Number(max_length, repr=_)) &&
    max_length == 20.0,
  )
  let exact_precondition = tagged_schema_variant(
    schema_property(action_input, "precondition"),
    "exact",
  )
  guard schema_property(exact_precondition, "generation")
    is Json::Object(exact_generation_fields) else {
    fail("exact generation schema is not an object")
  }
  assert_eq(
    required_string_field(exact_generation_fields, "pattern"),
    required_string_field(since_fields, "pattern"),
  )

  for value in ["0", "18446744073709551615"] {
    let host = RecordingHost::new()
    let response = route(
      host,
      tool_call("read_semantics", ({ "since": value } : Json)),
    ).stringify()
    assert_true(response.contains("\"isError\":false"))
    assert_true(host.last_since is Some(_))
  }
  for value in ["", "00", "01", "-1", "18446744073709551616"] {
    let host = RecordingHost::new()
    let response = route(
      host,
      tool_call("read_semantics", ({ "since": value } : Json)),
    ).stringify()
    assert_true(response.contains("\"isError\":true"))
    assert_true(response.contains("invalid_arguments"))
    assert_true(host.last_since is None)
  }

  for value in ["1", "18446744073709551615"] {
    let host = RecordingHost::new()
    let response = route(
      host,
      tool_call("perform_action", semantic_action_arguments("node_id", value)),
    ).stringify()
    assert_true(response.contains("\"isError\":false"))
    guard host.last_action is Some(action) else {
      fail("valid node id was not dispatched")
    }
    guard action.target is @core.SemanticsTarget::ByNodeId(node_id) else {
      fail("valid node id decoded to the wrong target")
    }
    assert_eq(node_id.to_wire(), value)
  }
  for value in ["0", "00", "01", "18446744073709551616"] {
    let host = RecordingHost::new()
    let response = route(
      host,
      tool_call("perform_action", semantic_action_arguments("node_id", value)),
    ).stringify()
    assert_true(response.contains("\"isError\":true"))
    assert_true(host.last_action is None)
  }
}

///|
test "SemanticId codec exposes and enforces byte and whitespace constraints" {
  let list_response = route(
    RecordingHost::new(),
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  )
  let descriptor = listed_tool_descriptor(list_response, "perform_action")
  guard descriptor is Json::Object(descriptor_fields) else {
    fail("perform_action descriptor is not an object")
  }
  let target_schema = schema_property(
    required_json_field(descriptor_fields, "inputSchema"),
    "target",
  )
  let semantic_target = tagged_schema_variant(target_schema, "semantic_id")
  let semantic_id_schema = schema_property(semantic_target, "id")
  guard semantic_id_schema is Json::Object(id_fields) &&
    id_fields.get("x-moui-utf8ByteLength") is Some(Json::Object(byte_length)) else {
    fail("semantic id schema is missing its UTF-8 byte contract")
  }
  assert_true(
    byte_length.get("minimum") is Some(Json::Number(minimum, repr=_)) &&
    minimum == 1.0,
  )
  assert_true(
    byte_length.get("maximum") is Some(Json::Number(maximum, repr=_)) &&
    maximum == 255.0,
  )
  let pattern = required_string_field(id_fields, "pattern")
  assert_true(pattern.contains("\\u0000-\\u0020"))
  assert_true(pattern.contains("\\u3000"))

  let valid = "\u{754C}".repeat(85)
  let valid_host = RecordingHost::new()
  let valid_response = route(
    valid_host,
    tool_call("perform_action", semantic_action_arguments("semantic_id", valid)),
  ).stringify()
  assert_true(valid_response.contains("\"isError\":false"))
  assert_true(valid_host.last_action is Some(_))

  for
    value in [
      "\u{754C}".repeat(86),
      "bad id",
      "bad\nvalue",
      "bad\u{00A0}value",
      "bad\u{3000}value",
    ] {
    let host = RecordingHost::new()
    let response = route(
      host,
      tool_call(
        "perform_action",
        semantic_action_arguments("semantic_id", value),
      ),
    ).stringify()
    assert_true(response.contains("\"isError\":true"))
    assert_true(response.contains("invalid_arguments"))
    assert_true(host.last_action is None)
  }
}

///|
test "read_semantics output schema fully types node issue and delta arrays" {
  let list_response = route(
    RecordingHost::new(),
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  )
  let descriptor = listed_tool_descriptor(list_response, "read_semantics")
  guard descriptor is Json::Object(descriptor_fields) else {
    fail("read_semantics descriptor is not an object")
  }
  let output = required_json_field(descriptor_fields, "outputSchema")
  let success_envelope = schema_variants(output)[0]
  let value_schema = schema_property(success_envelope, "value")
  let full = tagged_schema_variant(value_schema, "full")
  let delta = tagged_schema_variant(value_schema, "delta")

  let node = array_item_schema(schema_property(full, "nodes"))
  ignore(schema_property(node, "node_id"))
  ignore(schema_property(node, "semantic_id"))
  ignore(schema_property(node, "state"))
  ignore(schema_property(node, "numeric"))
  ignore(schema_property(node, "relations"))
  ignore(schema_property(node, "live"))
  ignore(schema_property(node, "atomic"))
  ignore(schema_property(node, "frame"))
  ignore(array_item_schema(schema_property(node, "actions")))
  ignore(array_item_schema(schema_property(node, "children")))

  let issue = array_item_schema(schema_property(full, "issues"))
  let duplicate_issue = tagged_schema_variant(issue, "duplicate_semantic_id")
  ignore(schema_property(duplicate_issue, "semantic_id"))
  ignore(array_item_schema(schema_property(duplicate_issue, "nodes")))
  let missing_issue = tagged_schema_variant(issue, "missing_relation_target")
  ignore(schema_property(missing_issue, "source"))
  ignore(schema_property(missing_issue, "relation"))

  ignore(array_item_schema(schema_property(delta, "upserted")))
  ignore(array_item_schema(schema_property(delta, "removed")))
  ignore(array_item_schema(schema_property(delta, "issues")))
  let announcement = array_item_schema(schema_property(delta, "announcements"))
  ignore(schema_property(announcement, "node_id"))
  ignore(schema_property(announcement, "generation"))
  ignore(schema_property(announcement, "live"))
  ignore(schema_property(announcement, "atomic"))
  ignore(schema_property(announcement, "text"))
}

///|
test "host closure is a normal structured tool error" {
  let host = RecordingHost::new(closed=true)
  let read_response = route(
    host,
    tool_call("read_semantics", Json::empty_object()),
  ).stringify()
  assert_true(read_response.contains("\"isError\":true"))
  assert_true(read_response.contains("host_closed"))
  assert_false(read_response.contains("\"code\":-32602"))
  let action_arguments = request(
    "{\"target\":{\"kind\":\"semantic_id\",\"id\":\"counter\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"latest\"}}",
  )
  let action_response = route(
    host,
    tool_call("perform_action", action_arguments),
  ).stringify()
  assert_true(action_response.contains("\"isError\":true"))
  assert_true(action_response.contains("host_closed"))
}

///|
test "diagnostics tools stay unavailable on the default router" {
  let host = RecordingHost::new()
  let response = route(
    host,
    tool_call("diagnostics_read_state", Json::empty_object()),
  ).stringify()
  assert_true(response.contains("\"isError\":true"))
  assert_true(response.contains("unknown_tool"))
}

///|
struct TraceHost {}

///|
pub impl @agent.AgentHost for TraceHost with fn read_semantics(_self, _since) {
  Ok(
    @agent.AgentSemanticsRead::Full({
      generation: @core.SemanticsGeneration::new(2UL),
      root: None,
      focused: None,
      nodes: [],
      issues: [],
    }),
  )
}

///|
pub impl @agent.AgentHost for TraceHost with fn perform_action(_self, _request) {
  Ok({
    before: @core.SemanticsGeneration::new(2UL),
    after: @core.SemanticsGeneration::new(3UL),
    pending_work: false,
  })
}

///|
pub impl @agent.AgentTraceHost for TraceHost with fn read_trace(_self, cursor) {
  Ok(@agent.AgentTraceRead::new(cursor~, entries=[]))
}

///|
pub impl @agent.AgentTraceHost for TraceHost with fn replay_trace(
  _self,
  _request,
) {
  Ok({
    success: true,
    completed: 0,
    stopped_at: None,
    failure: None,
    receipts: [],
  })
}

///|
pub impl @agent.AgentTraceHost for TraceHost with fn read_policy_state(_self) {
  @agent.AgentPolicyState::new()
}

///|
test "agent tools require explicit opt-in route" {
  let host = TraceHost::{  }
  let default_response = route(
    host,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  ).stringify()
  assert_false(default_response.contains("agent_read_trace"))
  let response = route_with_agent_tools(
    host,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  ).stringify()
  assert_true(response.contains("agent_read_trace"))
  assert_true(response.contains("agent_replay_trace"))
  assert_true(response.contains("agent_read_policy_state"))
}

///|
test "agent trace calls return structured tool content" {
  let response = route_with_agent_tools(
    TraceHost::{  },
    tool_call("agent_read_trace", ({ "cursor": "0" } : Json)),
  )
  let text = response.stringify()
  assert_true(text.contains("structuredContent"))
  assert_true(text.contains("\"isError\":false"))
  assert_true(text.contains("\"cursor\":\"0\""))
}

///|
test "Skill tools are opt-in and preserve the default two-tool route" {
  let skill = @agent.AgentSkillManifest::new(
    id="workbench.search",
    version="1.0.0",
    description="Search records",
    input_schema=({ "type": "object" } : Json),
    steps=[@agent.AgentSkillStep::ReadSemantics],
  )
  let registry = @agent.AgentSkillRegistry::new()
  assert_true(registry.register(skill) is Ok(_))
  let host = TraceHost::{  }
  assert_eq(
    listed_tool_count(
      route(
        host,
        request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
      ),
    ),
    2,
  )
  let response = route_with_skills(
    host,
    registry,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  )
  assert_eq(listed_tool_count(response), 8)
  assert_true(response.stringify().contains("skills/list"))
  let call = route_with_skills(
    host,
    registry,
    tool_call("skills/call", ({ "skill_id": "workbench.search" } : Json)),
  )
  assert_true(call.stringify().contains("\"isError\":false"))
  assert_true(call.stringify().contains("workbench.search"))
}

///|
test "secure Skill route applies invocation scopes" {
  let skill = @agent.AgentSkillManifest::new(
    id="protected.read",
    version="1.0.0",
    description="Read protected semantics",
    input_schema=Json::empty_object(),
    required_scopes=["records.sensitive.read"],
    steps=[@agent.AgentSkillStep::ReadSemantics],
  )
  let registry = @agent.AgentSkillRegistry::new()
  assert_true(registry.register(skill) is Ok(_))
  let visibility = @agent.AgentVisibilityPolicy::new().protect(
    semantic_id="workbench.sensitive.contact",
    scope="records.sensitive.read",
  )
  let host = @agent.AgentSecureSession::new(TraceHost::{  }, visibility)
  let denied = route_with_secure_skills(
    host,
    registry,
    tool_call("skills/call", ({ "skill_id": "protected.read" } : Json)),
  )
  assert_true(denied.stringify().contains("missing_skill_scope"))
  let approved = route_with_secure_skills(
    host,
    registry,
    tool_call(
      "skills/call",
      (
        { "skill_id": "protected.read", "scopes": ["records.sensitive.read"] } :
        Json),
    ),
  )
  assert_true(approved.stringify().contains("\"isError\":false"))
}
