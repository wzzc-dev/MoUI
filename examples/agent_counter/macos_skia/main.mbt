///|
// Windowed macOS (Skia) MCP server for the agent counter demo.
//
// Opens a real on-screen window AND serves MCP JSON-RPC over stdio
// CONCURRENTLY (via @async.all), so an agent can drive the counter while the
// user watches the count change on screen in real time. This is the live
// "user sees the agent's actions" path: typed semantic action ->
// runtime.update -> repaint -> visible window update, all in one process.
async fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=240.0,
    height=260.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  // Task 1: the on-screen window pump (renders the counter; runs until close).
  let window_task : async () -> Unit = async fn() -> Unit {
    @macos_skia_backend.run_app_with_options_async_pump(
      "MoUI Agent Counter",
      runtime,
      options=@macos_skia_backend.MacosSkiaAppOptions::new(),
      frame_interval_ms=16,
    )
  }
  // Task 2: the MCP stdio server loop. Shares the host with the window, so an
  // typed actions repaint the live window the user is watching.
  let mcp_task : async () -> Unit = async fn() -> Unit {
    while true {
      match @stdio.stdin.read_until("\n") {
        None => return
        Some(line) => {
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
    }
  }
  // Run both concurrently. The window renders; the MCP loop drives the same
  // RuntimeAgentHost. An agent click visibly updates the window in real time.
  let _ = @async.all([window_task, mcp_task])
}
