///|
fn request(source : String) -> Json {
  @json.parse(source) catch {
    error => abort("invalid E2E request: \{error}")
  }
}

///|
fn structured_value(response : Json) -> Map[String, Json] {
  guard response is Json::Object(response_fields) else {
    abort("expected JSON-RPC response object")
  }
  guard response_fields.get("result") is Some(Json::Object(result_fields)) else {
    abort("expected JSON-RPC result object")
  }
  guard result_fields.get("structuredContent")
    is Some(Json::Object(structured_fields)) else {
    abort("expected structuredContent object")
  }
  guard structured_fields.get("value") is Some(Json::Object(value_fields)) else {
    abort("expected structured value object")
  }
  value_fields
}

///|
fn json_string_field(fields : Map[String, Json], name : String) -> String {
  guard fields.get(name) is Some(Json::String(value)) else {
    abort("expected string field \{name}")
  }
  value
}

///|
fn assert_semantics_wire_shape(value : Map[String, Json]) -> Unit {
  guard value.get("root") is Some(Json::String(_root)) else {
    abort("semantics root must be one decimal string")
  }
  guard value.get("focused") is Some(Json::Null) else {
    abort("absent semantics focus must be null")
  }
  guard value.get("nodes") is Some(Json::Array(nodes)) else {
    abort("semantics nodes must be an array")
  }
  for node in nodes {
    match node {
      Json::Object(fields) =>
        match fields.get("semantic_id") {
          Some(Json::String("counter.increment")) => {
            guard fields.get("role") is Some(Json::String("button")) else {
              abort("semantic role must use the stable lower-case wire code")
            }
            guard fields.get("actions") is Some(Json::Array(actions)) else {
              abort("semantic actions must be an array")
            }
            if !actions.any(action => action is Json::String("activate")) {
              abort("semantic action must use the stable lower-case wire code")
            }
            return ()
          }
          _ => ()
        }
      _ => ()
    }
  }
  abort("missing counter.increment semantics node")
}

///|
fn draw_frame_contains_text(
  runtime : @runtime.AppRuntime,
  expected : String,
) -> Bool {
  runtime
  .draw_commands()
  .any(command => {
    match command {
      @core.DrawCommand::DrawText(run) => run.text == expected
      _ => false
    }
  })
}

///|
fn perform_action_request(semantic_id : String, generation : String) -> Json {
  request(
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"perform_action\",\"arguments\":{\"target\":{\"kind\":\"semantic_id\",\"id\":\"\{semantic_id}\"},\"action\":{\"kind\":\"activate\"},\"precondition\":{\"kind\":\"exact\",\"generation\":\"\{generation}\"}}}}",
  )
}

///|
test "E2E default MCP surface is semantic only" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=240.0,
    height=260.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  let response = @mcp.route(
    host,
    request("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"),
  )
  guard response is Json::Object(fields) else { fail("expected response") }
  guard fields.get("result") is Some(Json::Object(result)) else {
    fail("expected result")
  }
  guard result.get("tools") is Some(Json::Array(tools)) else {
    fail("expected tools")
  }
  assert_eq(tools.length(), 2)
  let text = response.stringify()
  assert_true(text.contains("read_semantics"))
  assert_true(text.contains("perform_action"))
  assert_false(text.contains("dispatch_event"))
}

///|
test "E2E semantic action updates model semantics and draw output" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=240.0,
    height=260.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  let initial = @mcp.route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"read_semantics\",\"arguments\":{}}}",
    ),
  )
  let initial_text = initial.stringify()
  assert_true(initial_text.contains("counter.increment"))
  assert_true(initial_text.contains("Count: 0"))
  let initial_value = structured_value(initial)
  assert_semantics_wire_shape(initial_value)
  assert_false(initial_text.contains("\"Activate\""))
  assert_false(initial_text.contains("\"Button\""))
  let generation = json_string_field(initial_value, "generation")
  assert_true(draw_frame_contains_text(runtime, "Count: 0"))

  let action = @mcp.route(
    host,
    perform_action_request("counter.increment", generation),
  )
  let action_text = action.stringify()
  assert_true(action_text.contains("\"isError\":false"))
  let after = json_string_field(structured_value(action), "after")
  let updated = @mcp.route(
    host,
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"read_semantics\",\"arguments\":{}}}",
    ),
  )
  assert_true(updated.stringify().contains("Count: 1"))
  assert_true(draw_frame_contains_text(runtime, "Count: 1"))
  assert_true(runtime.program_runtime_snapshot().update_count() > 0)

  // The same semantic ID survives the TEA rebuild and receipt.after is a valid
  // precondition for the next synchronous action.
  let second = @mcp.route(
    host,
    perform_action_request("counter.increment", after),
  )
  assert_true(second.stringify().contains("\"isError\":false"))
  assert_true(draw_frame_contains_text(runtime, "Count: 2"))

  // The generation captured before the first action is now stale.
  let stale = @mcp.route(
    host,
    perform_action_request("counter.reset", generation),
  ).stringify()
  assert_true(stale.contains("\"isError\":true"))
  assert_true(stale.contains("stale_generation"))
  assert_true(draw_frame_contains_text(runtime, "Count: 2"))
}
