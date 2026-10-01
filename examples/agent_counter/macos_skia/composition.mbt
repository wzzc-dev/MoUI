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
  // The MCP loop never returns on its own, so it must be a *worker*: when the
  // window closes, `run_window_with_workers` cancels it and the process exits.
  // Plain `@async.all([window_task, mcp_task])` waits for every sibling, which
  // leaves the process alive after the window is gone ("close does nothing").
  @macos_backend.run_window_with_workers(window=window_task, workers=[mcp_task])
}
