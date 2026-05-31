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
      active_task="Wire the first session-first workbench UI and transport boundary.",
      unread_events=3,
    ),
    WorkbenchSession::new(
      id="pi-rpc",
      title="Pi RPC harness",
      project_path="/Volumes/Data/Code/moon/pi",
      branch="main",
      status="queued",
      summary="JSONL stdin/stdout transport exercise for pi --mode rpc.",
      active_task="Align get_state, prompt, abort, and EOF shutdown with Pi RPC.",
      unread_events=1,
    ),
    WorkbenchSession::new(
      id="docs-research",
      title="Research notebook",
      project_path="/Users/example/Research",
      branch="notes",
      status="idle",
      summary="Future non-code workflow proving the app is not only an IDE.",
      active_task="Collect citations and reusable summaries.",
      unread_events=0,
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
      detail="Route commands, stdout, stderr, and process failures through app-level events.",
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
      detail="Promote missing text, image, path, or surface APIs through skia_mbt first.",
    ),
  ]
}

///|
fn sample_events() -> Array[AgentEvent] {
  [
    AgentEvent::new(
      phase="system",
      title="Mo Workbench initialized",
      detail="Session-first Pi agent desktop for coding workflows.",
      tone="success",
    ),
    AgentEvent::new(
      phase="agent",
      title="Repository context loaded",
      detail="core, views, backend, render/skia, and examples indexed.",
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
      summary="moonbitlang/async owner for long-lived Pi JSONL sessions.",
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
    ),
    CommandRun::new(
      id=2,
      command="moon test examples/mo_workbench/native_transport --target native",
      cwd="/Volumes/Data/Code/moon/MoUI",
      status="ready",
      exit_code=None,
    ),
    CommandRun::new(
      id=3,
      command="moon build examples/mo_workbench/macos_skia --target native",
      cwd="/Volumes/Data/Code/moon/MoUI",
      status="pending skia link",
      exit_code=None,
    ),
    CommandRun::new(
      id=4,
      command="scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke",
      cwd="/Volumes/Data/Code/moon/MoUI",
      status="manual",
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
      message="Native owner speaks Pi RPC JSONL, reports stderr/nonzero exits, and restarts on the next command batch.",
    ),
    DiagnosticItem::new(
      source="Skia",
      severity="watch",
      message="Real renderer smoke still depends on local skia_mbt link flags.",
    ),
    DiagnosticItem::new(
      source="Product",
      severity="note",
      message="Session model leaves room for docs, research, and automation workflows.",
    ),
  ]
}
