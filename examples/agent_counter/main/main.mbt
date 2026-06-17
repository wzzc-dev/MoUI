///|
// Headless stdio MCP server for the agent counter demo.
//
// Launches the counter Program in an AppRuntime, wraps it in a
// RuntimeAgentHost, and serves MCP JSON-RPC over stdio (NDJSON, one request
// per line). Any MCP client (Claude / Cursor / a custom client) can then:
//   - tools/call get_semantics   -> read the counter's UI tree
//   - tools/call dispatch_command -> fire Activate/Submit/... through update()
//   - tools/list                 -> discover available tools
//
// The runtime here is headless (no window); pair with a windowed backend
// (see examples/counter/macos_skia) to also render the UI on screen while the
// agent drives it. The agent protocol is identical in both cases.
async fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=200.0,
    height=240.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  // Buffered notifications: route_notify's sink is a plain (Json) -> Unit and
  // cannot call async stdio directly, so we buffer here and flush after.
  let pending : Array[Json] = []
  // NDJSON loop: read one JSON-RPC request per line, route it, write the
  // response followed by a newline. Malformed input yields nothing (skip).
  while @stdio.stdin.read_until("\n") is Some(line) {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let parsed = @json.parse(trimmed) catch {
      _ => {
        @stdio.stdout.write(
          ((@mcp.rpc_error_no_id(-32700, "Parse error") : Json).stringify() + "\n"),
        )
        continue
      }
    }
    pending.clear()
    let response = @mcp.route_notify(host, parsed, notification => {
      // Collect event notifications; flushed below in async context.
      pending.push(notification)
    })
    // Flush any notifications produced during this request, then the response.
    for notification in pending {
      @stdio.stdout.write(((notification : Json).stringify() + "\n"))
    }
    @stdio.stdout.write((response : Json).stringify() + "\n")
  }
}
