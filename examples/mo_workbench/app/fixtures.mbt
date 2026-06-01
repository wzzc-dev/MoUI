///|
fn sample_sessions() -> Array[WorkbenchSession] {
  [
    WorkbenchSession::new(
      id="moui-skia",
      title="MoUI Skia renderer",
      project_path="/Volumes/Data/Code/moon/MoUI",
      branch="codex/mo-workbench",
      status="active",
      summary="Native Skia dogfood slice for a Pi-backed coding workbench.",
      active_task="",
      unread_events=3,
    ),
    WorkbenchSession::new(
      id="pi-rpc",
      title="Pi RPC harness",
      project_path="/Volumes/Data/Code/moon/pi",
      pi_session_path="/tmp/mo-workbench-pi-rpc-session.jsonl",
      branch="main",
      status="idle",
      summary="JSONL stdin/stdout transport exercise for pi --mode rpc.",
      active_task="",
      unread_events=0,
    ),
  ]
}
