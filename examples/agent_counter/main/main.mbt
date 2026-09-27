///|
// Headless stdio MCP server for the agent counter demo.
//
// Launches the counter Program in an AppRuntime, wraps it in a
// RuntimeAgentHost, and serves MCP JSON-RPC over stdio (NDJSON, one request
// per line) through the shared `wzzc-dev/moui_agent_mcp/stdio` transport. Any
// MCP client (Claude / Cursor / a custom client) can then:
//   - tools/call read_semantics -> read a committed semantics snapshot/delta
//   - tools/call perform_action -> dispatch a typed semantic action
//   - tools/list                 -> discover available tools
//
// The runtime here is headless (no window); pair with a windowed backend
// (see macos_skia) to also render the UI on screen while the agent drives it.
// The agent protocol is identical in both cases.
async fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=200.0,
    height=240.0,
  )
  @mcp_stdio.serve(@agent.RuntimeAgentHost::new(runtime))
}
