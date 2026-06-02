///|
fn sample_sessions() -> Array[WorkbenchSession] {
  [
    WorkbenchSession::new(
      id="moui-skia",
      title="MoUI Skia renderer",
      project_path="/Volumes/Data/Code/moon/MoUI",
      branch="codex/mo-workbench",
      status="active",
      summary="Native Skia dogfood slice for an agent workbench.",
      active_task="",
      unread_events=3,
    ),
    WorkbenchSession::new(
      id="pi-rpc",
      title="Agent 路由整理",
      project_path="/Volumes/Data/Code/moon/pi",
      backend_id="pi",
      pi_session_path="/tmp/mo-workbench-pi-rpc-session.jsonl",
      branch="main",
      status="idle",
      summary="保持会话流转清晰。",
      active_task="",
      unread_events=0,
    ),
  ]
}
