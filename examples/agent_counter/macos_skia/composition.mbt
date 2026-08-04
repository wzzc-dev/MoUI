///|
async fn run_agent_counter() -> Unit {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=240.0,
    height=260.0,
  )
  let host = @agent.RuntimeAgentHost::new(runtime)
  let window_task : async () -> Unit = async fn() -> Unit {
    @runtime.run_app("MoUI Agent Counter", runtime)
    .render_all(@render_skia.from_env())
    .backend(@macos_backend.entry())
    .run_async_pump(frame_interval_ms=16)
  }
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
  let _ = @async.all([window_task, mcp_task])
}
