///|
// Headless stdio MCP server for the agent counter demo.
//
// Launches the counter Program in an AppRuntime, wraps it in a
// RuntimeAgentHost, and serves MCP JSON-RPC over stdio (NDJSON, one request
// per line). Any MCP client (Claude / Cursor / a custom client) can then:
//   - tools/call read_semantics -> read a committed semantics snapshot/delta
//   - tools/call perform_action -> dispatch a typed semantic action
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
          (@mcp.rpc_error_no_id(-32700, "Parse error") : Json).stringify() +
          "\n",
        )
        continue
      }
    }
    let response = @mcp.route(host, parsed)
    @stdio.stdout.write((response : Json).stringify() + "\n")
  }
}
