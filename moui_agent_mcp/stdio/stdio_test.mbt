///|
struct ClosedHost {}

///|
pub impl @agent.AgentHost for ClosedHost with fn read_semantics(_self, _since) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentHost for ClosedHost with fn perform_action(
  _self,
  _request,
) {
  Err(HostClosed)
}

///|
struct DiagnosticsClosedHost {}

///|
pub impl @agent.AgentHost for DiagnosticsClosedHost with fn read_semantics(
  _self,
  _since,
) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentHost for DiagnosticsClosedHost with fn perform_action(
  _self,
  _request,
) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentDiagnosticsHost for DiagnosticsClosedHost with fn runtime_state(
  _self,
) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentDiagnosticsHost for DiagnosticsClosedHost with fn paint_summary(
  _self,
) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentDiagnosticsHost for DiagnosticsClosedHost with fn dispatch_event(
  _self,
  _event,
) {
  Err(HostClosed)
}

///|
pub impl @agent.AgentDiagnosticsHost for DiagnosticsClosedHost with fn dispatch_command(
  _self,
  _intent,
) {
  Err(HostClosed)
}

///|
fn route_default(host : ClosedHost, request : Json) -> Json {
  @mcp.route(host, request)
}

///|
fn route_diagnostics(host : DiagnosticsClosedHost, request : Json) -> Json {
  @mcp.route_with_diagnostics(host, request)
}

///|
test "respond skips blank lines" {
  let host : ClosedHost = ClosedHost::{ }
  guard respond(host, "", route_default) is None
  guard respond(host, "   \n", route_default) is None
}

///|
test "respond answers malformed JSON with a parse error" {
  let host : ClosedHost = ClosedHost::{ }
  guard respond(host, "not json", route_default) is Some(response)
  assert_eq!(response.contains("-32700"), true)
  assert_eq!(response.ends_with("\n"), true)
}

///|
test "respond routes well-formed requests and closes responses" {
  let host : ClosedHost = ClosedHost::{ }
  guard
    respond(
      host,
      "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"initialize\"}",
      route_default,
    ) is Some(initialize)
  assert_eq!(initialize.contains("moui-agent"), true)
  guard
    respond(
      host,
      "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"tools/list\"}",
      route_default,
    ) is Some(tools)
  assert_eq!(tools.contains("\"read_semantics\""), true)
  assert_eq!(tools.contains("\"perform_action\""), true)
  guard
    respond(
      host,
      "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"read_semantics\",\"arguments\":{}}}",
      route_default,
    ) is Some(read)
  assert_eq!(read.contains("\"ok\":false"), true)
  guard
    respond(
      host,
      "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"bogus\"}",
      route_default,
    ) is Some(unknown)
  assert_eq!(unknown.contains("-32601"), true)
}

///|
test "diagnostics routing stays available over stdio" {
  let host : DiagnosticsClosedHost = DiagnosticsClosedHost::{ }
  guard
    respond(
      host,
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}",
      route_diagnostics,
    ) is Some(tools)
  assert_eq!(tools.contains("\"diagnostics_read_state\""), true)
}
