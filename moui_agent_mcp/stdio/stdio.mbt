///|
/// Handle one stdio NDJSON line against a router function and return the wire
/// response including the trailing newline. Blank lines produce nothing to
/// write; malformed JSON is answered with a parse error instead of aborting
/// the loop.
fn[Host] respond(
  host : Host,
  line : String,
  route_request : (Host, Json) -> Json,
) -> String? {
  let trimmed = line.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let parsed = @json.parse(trimmed) catch {
    _ =>
      return Some(
        (@mcp.rpc_error_no_id(-32700, "Parse error") : Json).stringify() + "\n",
      )
  }
  Some(route_request(host, parsed).stringify() + "\n")
}

///|
/// Serve MCP JSON-RPC over stdio (NDJSON: one request per line, one response
/// per line) until stdin closes. Requests route through the default semantic
/// tool registry. The call parks the current task on stdin, so composition
/// roots run it alongside window or worker tasks with `@async.all`; with no
/// agent attached, stdin is already closed and the call returns immediately.
pub async fn[Host : @agent.AgentHost] serve(host : Host) -> Unit {
  while @async_stdio.stdin.read_until("\n") is Some(line) {
    match respond(host, line, fn(host, request) { @mcp.route(host, request) }) {
      Some(response) => @async_stdio.stdout.write(response)
      None => ()
    }
  }
}

///|
/// Diagnostics opt-in variant of `serve`: requests additionally route through
/// the diagnostics tool registry.
pub async fn[
  Host : @agent.AgentHost + @agent.AgentDiagnosticsHost,
] serve_with_diagnostics(host : Host) -> Unit {
  while @async_stdio.stdin.read_until("\n") is Some(line) {
    match
      respond(host, line, fn(host, request) {
        @mcp.route_with_diagnostics(host, request)
      }) {
      Some(response) => @async_stdio.stdout.write(response)
      None => ()
    }
  }
}
