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
      active_task="Pi RPC + macOS Skia dogfood.",
      unread_events=3,
    ),
    WorkbenchSession::new(
      id="pi-rpc",
      title="Pi RPC harness",
      project_path="/Volumes/Data/Code/moon/pi",
      pi_session_path="/tmp/mo-workbench-pi-rpc-session.jsonl",
      branch="main",
      status="queued",
      summary="JSONL stdin/stdout transport exercise for pi --mode rpc.",
      active_task="Validate Pi JSONL RPC.",
      unread_events=1,
    ),
  ]
}

///|
fn sample_plan() -> Array[PlanStep] {
  [
    PlanStep::new(
      id="survey",
      title="Read framework and example boundaries",
      status="done",
      owner="agent",
      detail="Stay inside examples/mo_workbench unless Skia or host gaps appear.",
    ),
    PlanStep::new(
      id="transport",
      title="Keep PiTransport platform-neutral",
      status="active",
      owner="agent",
      detail="Route Pi RPC commands, stdout, stderr, responses, and session events through app state.",
    ),
    PlanStep::new(
      id="skia",
      title="Prefer macOS Skia native entrypoint",
      status="next",
      owner="runtime",
      detail="Use backend/macos/skia provider and real-Skia smoke when link flags exist.",
    ),
    PlanStep::new(
      id="dogfood",
      title="Capture framework pressure",
      status="watch",
      owner="framework",
      detail="Promote missing Skia APIs through skia_mbt first.",
    ),
  ]
}

///|
fn sample_events() -> Array[AgentEvent] {
  [
    AgentEvent::new(
      phase="system",
      title="Mo Workbench initialized",
      detail="Pi agent desktop for coding workflows.",
      tone="success",
    ),
    AgentEvent::new(
      phase="agent",
      title="Repository context loaded",
      detail="MoUI app, host, and Skia paths indexed.",
      tone="info",
    ),
    AgentEvent::new(
      phase="tool",
      title="Focused checks selected",
      detail="moon test examples/mo_workbench/app --target native",
      tone="warning",
    ),
  ]
}

///|
fn sample_transcript() -> Array[TranscriptItem] {
  [
    TranscriptItem::new(
      id="sample-user-1",
      role="user",
      summary="要求继续推进 Mo Workbench",
      detail="保持 PiTransport 平台无关，并优先完善 macOS Skia native 路线。",
      tone="info",
    ),
    TranscriptItem::new(
      id="sample-assistant-1",
      role="assistant",
      summary="已接入 Pi RPC 状态、bash 执行、取消和命令目录",
      detail="下一步把命令目录接到 slash command invocation 与权限提示。",
      tone="success",
    ),
    TranscriptItem::new(
      id="sample-bash-1",
      role="bashExecution",
      summary="moon test examples/mo_workbench/app --target native",
      detail="exit code 0",
      tone="success",
    ),
  ]
}

///|
fn sample_pi_commands() -> Array[PiCommandInfo] {
  [
    PiCommandInfo::new(
      name="review",
      source="prompt",
      description="Review the current diff and call out risks.",
      source_scope="project",
      source_path=".pi/prompts/review.md",
    ),
    PiCommandInfo::new(
      name="skill:moonbit-agent-guide",
      source="skill",
      description="Use MoonBit package and validation conventions.",
      source_scope="user",
      source_path="skills/moonbit-agent-guide/SKILL.md",
    ),
    PiCommandInfo::new(
      name="release-notes",
      source="extension",
      description="Draft a concise release note from merged changes.",
      source_scope="project",
      source_path="extensions/release-notes.ts",
    ),
  ]
}

///|
fn sample_pi_session_stats() -> PiSessionStatsSnapshot {
  PiSessionStatsSnapshot::new(
    session_id="sample-moui-skia",
    user_messages=1,
    assistant_messages=1,
    tool_calls=1,
    tool_results=1,
    total_messages=3,
    token_input=18240,
    token_output=4120,
    token_cache_read=9600,
    token_cache_write=0,
    token_total=31960,
    cost=0.0,
    context_tokens=Some(31960),
    context_window=200000,
    context_percent=Some(16.0),
  )
}

///|
fn sample_files() -> Array[FileContext] {
  [
    FileContext::new(
      id="app",
      path="examples/mo_workbench/app/app.mbt",
      summary="Shared TEA model, reducer, and workbench shell.",
      change_kind="added",
      lines_changed=260,
    ),
    FileContext::new(
      id="transport",
      path="examples/mo_workbench/app/transport.mbt",
      summary="Platform-neutral Pi JSONL command and event model.",
      change_kind="added",
      lines_changed=86,
    ),
    FileContext::new(
      id="entry",
      path="examples/mo_workbench/macos_skia/main.mbt",
      summary="Thin native-first entrypoint selecting Skia and owned Pi transport.",
      change_kind="added",
      lines_changed=16,
    ),
    FileContext::new(
      id="native-transport",
      path="examples/mo_workbench/native_transport/owned_runtime.mbt",
      summary="moonbitlang/async owner for supervised Pi RPC JSONL sessions.",
      change_kind="added",
      lines_changed=180,
    ),
    FileContext::new(
      id="docs",
      path="docs/mo-workbench.md",
      summary="Product intent, architecture boundary, and validation notes.",
      change_kind="added",
      lines_changed=80,
    ),
  ]
}

///|
fn sample_diff_overview() -> DiffOverview {
  DiffOverview::new(
    changed_files=5,
    additions=160,
    deletions=10,
    status="ready for review",
  )
}

///|
fn sample_commands() -> Array[CommandRun] {
  [
    CommandRun::new(
      id=1,
      command="moon test examples/mo_workbench/app --target native",
      cwd="/Volumes/Data/Code/moon/MoUI",
      status="ready",
      exit_code=None,
      output_path="/tmp/mo-workbench-app-test.log",
    ),
    CommandRun::new(
      id=2,
      command="moon test examples/mo_workbench/native_transport --target native",
      cwd="/Volumes/Data/Code/moon/MoUI",
      status="ready",
      exit_code=None,
    ),
  ]
}

///|
fn sample_diagnostics() -> Array[DiagnosticItem] {
  [
    DiagnosticItem::new(
      source="PiTransport",
      severity="watch",
      message="Native owner speaks Pi RPC JSONL and keeps UI state platform-neutral.",
    ),
    DiagnosticItem::new(
      source="Skia",
      severity="watch",
      message="Real renderer smoke still depends on local skia_mbt link flags.",
    ),
    DiagnosticItem::new(
      source="Product",
      severity="note",
      message="Session model leaves room for non-code workflows.",
    ),
  ]
}
