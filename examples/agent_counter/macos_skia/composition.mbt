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
    .render_all(
      @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
    )
    .backend(@macos_backend.entry())
    .run_async_pump(frame_interval_ms=16)
  }
  // The stdio MCP loop shares this runtime with the window; the agent
  // protocol is identical with or without a window on screen.
  let mcp_task : async () -> Unit = async fn() -> Unit {
    @mcp_stdio.serve(host)
  }
  let _ = @async.all([window_task, mcp_task])
}
