// Portable tests for the workbench shell routing + per-workspace sub-updates.
//
// Uses a fixture backend that replays scripted events without network access.
// The shell model holds workspaces as sub-models; chat assertions go through
// `model.code.*` and settings assertions through `model.settings.*`.

///|
/// Build a shell model with a fixture backend for testing. The script maps
/// each command to the events the backend should emit in response.
fn test_model(script~ : (AgentCommand) -> Array[AgentEvent]) -> WorkbenchModel {
  let fixture = AgentBackendFixture::new(script~)
  WorkbenchModel::new(backend=fixture.runtime())
}

///|
fn workbench_folder_dialog_services(
  paths : Array[String],
) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_dialogs=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(
          { kind: @host.HostFileDialogKind::PickDirectory, .. }
        ) => @host.HostServiceResponse::FileDialogSelection(paths)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn drain_workbench_effect(
  effect : @moui.Effect[WorkbenchMsg],
) -> Array[WorkbenchMsg] {
  let messages : Array[WorkbenchMsg] = []
  effect.runtime_visit(
    msg => messages.push(msg),
    run => run(msg => messages.push(msg)),
    (_descriptor, run) => run(msg => messages.push(msg)),
    (_descriptor, _start) => (),
  )
  messages
}

// ---------------------------------------------------------------------------
// Code workspace (migrated from the previous flat-model tests)
// ---------------------------------------------------------------------------

///|
test "backend user echo does not duplicate optimistic user message" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, code: { ..model.code, prompt: "hello" } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(UserMessageAdded("hello"))),
  )
  inspect(model.code.messages.length(), content="1")
}

///|
test "submit prompt appends user message and starts streaming" {
  let model = test_model(script=cmd => {
    match cmd {
      SendTask(task) =>
        [
          AssistantMessageAdded("reply to " + task, None),
          TurnTerminal(TurnStatus::Finished, "Done"),
        ]
      _ => []
    }
  })
  let model = { ..model, code: { ..model.code, prompt: "hello" } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  // The user message is appended optimistically.
  inspect(model.code.messages.length(), content="1")
  guard model.code.messages[0] is User(text) else {
    fail("expected user message")
  }
  inspect(text, content="hello")
  // Prompt is cleared and streaming flag is set.
  inspect(model.code.prompt, content="")
  assert_true(model.code.is_streaming)
}

///|
test "receive assistant event appends message and clears streaming on terminal" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, code: { ..model.code, is_streaming: true } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(AssistantMessageAdded("hi", None)),
    ),
  )
  inspect(model.code.messages.length(), content="1")
  guard model.code.messages[0] is Assistant(content, _) else {
    fail("expected assistant message")
  }
  inspect(content, content="hi")
  // Still streaming until terminal event.
  assert_true(model.code.is_streaming)
  // Now receive the terminal event.
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(TurnTerminal(TurnStatus::Finished, "Done")),
    ),
  )
  assert_false(model.code.is_streaming)
  inspect(model.code.messages.length(), content="2")
  guard model.code.messages[1] is Terminal(status, _) else {
    fail("expected terminal message")
  }
  inspect(status == TurnStatus::Finished, content="true")
}

///|
test "failed terminal sets error" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, code: { ..model.code, is_streaming: true } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(
        TurnTerminal(TurnStatus::Failed, "network error"),
      ),
    ),
  )
  assert_false(model.code.is_streaming)
  guard model.code.error is Some(err) else { fail("expected error to be set") }
  inspect(err, content="network error")
}

///|
test "tool result event projects to tool message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(
        ToolResultAdded("shell", "exit 0", false, Some("ran ls")),
      ),
    ),
  )
  inspect(model.code.messages.length(), content="1")
  guard model.code.messages[0] is ToolResult(name, _, is_error, brief) else {
    fail("expected tool result message")
  }
  inspect(name, content="shell")
  assert_false(is_error)
  guard brief is Some(b) else { fail("expected brief") }
  inspect(b, content="ran ls")
}

///|
test "session list event updates sessions" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
  ]
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(SessionListed(sessions))),
  )
  inspect(model.code.sessions.length(), content="2")
  inspect(model.code.sessions[0].id, content="s1")
}

///|
test "session list auto-selects first session when none is active" {
  let fixture = AgentBackendFixture::new(script=cmd => {
    match cmd {
      SwitchSession(id) =>
        [
          ActiveSessionChanged(id),
          SessionRebuilt([
            UserMessageAdded("resume"),
            AssistantMessageAdded("ready", None),
          ]),
        ]
      _ => []
    }
  })
  let model = WorkbenchModel::new(backend=fixture.runtime())
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="resume"),
    SessionSummary::new(id="s2", first_prompt="next"),
  ]
  let (model, effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(SessionListed(sessions))),
  )
  guard model.code.active_session_id is Some(id) else {
    fail("expected active session id")
  }
  inspect(id, content="s1")
  inspect(fixture.dispatched_commands().length(), content="0")
  let messages = drain_workbench_effect(effect)
  let commands = fixture.dispatched_commands()
  inspect(commands.length(), content="1")
  guard commands[0] is SwitchSession(selected) else {
    fail("expected switch session command")
  }
  inspect(selected, content="s1")
  inspect(messages.length(), content="2")
  guard messages[0]
    is WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(ActiveSessionChanged("s1"))
    ) else {
    fail("expected active-session event")
  }
  guard messages[1]
    is WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(SessionRebuilt(items))) else {
    fail("expected rebuild event")
  }
  inspect(items.length(), content="2")
}

///|
test "session list preserves existing active session" {
  let fixture = AgentBackendFixture::new(script=_cmd => [])
  let model = WorkbenchModel::new(backend=fixture.runtime())
  let model = { ..model, code: { ..model.code, active_session_id: Some("s2") } }
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="current"),
  ]
  let (model, effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ReceiveAgentEvent(SessionListed(sessions))),
  )
  guard model.code.active_session_id is Some(id) else {
    fail("expected active session id")
  }
  inspect(id, content="s2")
  inspect(drain_workbench_effect(effect).length(), content="0")
  inspect(fixture.dispatched_commands().length(), content="0")
}

///|
test "task filter cycles all active running failed" {
  let model = test_model(script=_cmd => [])
  inspect(model.task_filter == TaskFilter::AllTasks, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::CycleTaskFilter)
  inspect(model.task_filter == TaskFilter::ActiveTask, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::CycleTaskFilter)
  inspect(model.task_filter == TaskFilter::RunningTasks, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::CycleTaskFilter)
  inspect(model.task_filter == TaskFilter::FailedTasks, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::CycleTaskFilter)
  inspect(model.task_filter == TaskFilter::AllTasks, content="true")
}

///|
test "task filter direct messages select concrete views" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(WorkbenchMsg::ShowRunningTasks)
  inspect(model.task_filter == TaskFilter::RunningTasks, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::ShowFailedTasks)
  inspect(model.task_filter == TaskFilter::FailedTasks, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::ShowAllTasks)
  inspect(model.task_filter == TaskFilter::AllTasks, content="true")
}

///|
test "active task filter keeps only active session in task tree" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
  ]
  let model = {
    ..model,
    task_filter: TaskFilter::ActiveTask,
    code: { ..model.code, sessions, active_session_id: Some("s2") },
  }
  let model = sync_task_tree(model)
  inspect(model.task_tree.length(), content="1")
  guard model.task_tree[0] is Folder(_, _, _, children, _) else {
    fail("expected folder")
  }
  inspect(children.length(), content="1")
  guard children[0] is Task(id, title, _, _, _) else { fail("expected task") }
  inspect(id, content="s2")
  inspect(title, content="second")
}

///|
test "running task filter hides completed sessions" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
  ]
  let model = {
    ..model,
    task_filter: TaskFilter::RunningTasks,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s1"),
      is_streaming: true,
    },
  }
  let model = sync_task_tree(model)
  inspect(model.task_tree.length(), content="1")
  guard model.task_tree[0] is Folder(_, _, _, children, _) else {
    fail("expected folder")
  }
  inspect(children.length(), content="1")
  guard children[0] is Task(id, _, _, status, _) else { fail("expected task") }
  inspect(id, content="s1")
  inspect(status == TaskStatus::Running, content="true")
}

///|
test "failed task filter keeps failed active session" {
  let model = test_model(script=_cmd => [])
  let sessions = [SessionSummary::new(id="s1", first_prompt="first")]
  let model = {
    ..model,
    task_filter: TaskFilter::FailedTasks,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s1"),
      messages: [ChatMessage::Terminal(TurnStatus::Failed, "failed")],
    },
  }
  let model = sync_task_tree(model)
  inspect(model.task_tree.length(), content="1")
  guard model.task_tree[0] is Folder(_, _, _, children, _) else {
    fail("expected folder")
  }
  inspect(children.length(), content="1")
  guard children[0] is Task(id, _, _, status, _) else { fail("expected task") }
  inspect(id, content="s1")
  inspect(status == TaskStatus::Failed, content="true")
}

///|
test "task search filters sessions by prompt text" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="Fix renderer crash"),
    SessionSummary::new(id="s2", first_prompt="Write release notes"),
  ]
  let model = { ..model, code: { ..model.code, sessions, } }
  let (model, _effect) = model.update(WorkbenchMsg::TaskSearchChanged("render"))
  inspect(model.task_search_query, content="render")
  inspect(model.task_tree.length(), content="1")
  guard model.task_tree[0] is Folder(_, _, _, children, _) else {
    fail("expected folder")
  }
  inspect(children.length(), content="1")
  guard children[0] is Task(id, title, _, _, _) else { fail("expected task") }
  inspect(id, content="s1")
  inspect(title, content="Fix renderer crash")
}

///|
test "task search matches session id case insensitively" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="ABC-123", first_prompt="Investigate app"),
    SessionSummary::new(id="def-456", first_prompt="Refactor tests"),
  ]
  let model = {
    ..model,
    task_search_query: "abc",
    code: { ..model.code, sessions, },
  }
  let model = sync_task_tree(model)
  inspect(model.task_tree.length(), content="1")
  guard model.task_tree[0] is Folder(_, _, _, children, _) else {
    fail("expected folder")
  }
  inspect(children.length(), content="1")
  guard children[0] is Task(id, _, _, _, _) else { fail("expected task") }
  inspect(id, content="ABC-123")
}

///|
test "work tab summary counts active running and completed tasks" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
    SessionSummary::new(id="s3", first_prompt="third"),
  ]
  let model = {
    ..model,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s2"),
      is_streaming: true,
    },
  }
  let summary = work_tab_summary(model)
  inspect(summary.total, content="3")
  inspect(summary.active, content="1")
  inspect(summary.running, content="1")
  inspect(summary.completed, content="2")
  inspect(summary.failed, content="0")
}

///|
test "work tab summary counts failed active task" {
  let model = test_model(script=_cmd => [])
  let sessions = [SessionSummary::new(id="s1", first_prompt="first")]
  let model = {
    ..model,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s1"),
      messages: [ChatMessage::Terminal(TurnStatus::Failed, "failed")],
    },
  }
  let summary = work_tab_summary(model)
  inspect(summary.total, content="1")
  inspect(summary.active, content="1")
  inspect(summary.running, content="0")
  inspect(summary.completed, content="0")
  inspect(summary.failed, content="1")
}

///|
test "work next actions start with failed work" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="s1", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
  ]
  let model = {
    ..model,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s1"),
      messages: [ChatMessage::Terminal(TurnStatus::Failed, "failed")],
    },
  }
  let actions = work_next_actions(model)
  inspect(actions.length(), content="5")
  inspect(actions[0].title, content="Review failed tasks")
  guard actions[0].action is WorkbenchMsg::ShowFailedTasks else {
    fail("expected failed action")
  }
  inspect(actions[1].title, content="Continue active task")
}

///|
test "work next actions prefer running before continuing code" {
  let model = test_model(script=_cmd => [])
  let sessions = [SessionSummary::new(id="s1", first_prompt="first")]
  let model = {
    ..model,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("s1"),
      is_streaming: true,
    },
  }
  let actions = work_next_actions(model)
  inspect(actions[0].title, content="Watch running work")
  guard actions[0].action is WorkbenchMsg::ShowRunningTasks else {
    fail("expected running action")
  }
  inspect(actions[1].title, content="Continue active task")
}

///|
test "work next actions stay useful with no sessions" {
  let model = test_model(script=_cmd => [])
  let actions = work_next_actions(model)
  inspect(actions.length(), content="2")
  inspect(actions[0].title, content="Start a new task")
  guard actions[0].action is WorkbenchMsg::NewTask else {
    fail("expected new task action")
  }
  inspect(actions[1].title, content="Agent settings")
}

///|
test "design tab summary reflects tasks and settings" {
  let model = test_model(script=_cmd => [])
  let sessions = [
    SessionSummary::new(id="active-session-1234567890", first_prompt="first"),
    SessionSummary::new(id="s2", first_prompt="second"),
  ]
  let model = {
    ..model,
    code: {
      ..model.code,
      sessions,
      active_session_id: Some("active-session-1234567890"),
      current_model: "deepseek-v4-pro",
    },
    settings: {
      ..model.settings,
      approval_policy: ApprovalPolicy::AskOnCommand,
      sandbox_mode: SandboxMode::FullAccess,
      font_size: 18,
    },
  }
  let summary = design_tab_summary(model)
  inspect(summary.total_tasks, content="2")
  inspect(summary.active_session, content="active-session-123456789...")
  inspect(summary.model, content="deepseek-v4-pro")
  inspect(summary.approval, content="Command")
  inspect(summary.sandbox, content="Full access")
  inspect(summary.font_size, content="18 pt")
}

///|
test "statusbar labels keep runtime and session only on wide layouts" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: { ..model.code, active_session_id: Some("active-session-1234567890") },
  }
  let labels = statusbar_labels(model, 920.0)
  inspect(labels.length(), content="2")
  inspect(labels[0], content="Runtime: ready")
  inspect(labels[1], content="Session: active-session-123...")
}

///|
test "statusbar labels stay compact on narrow layouts" {
  let model = test_model(script=_cmd => [])
  let labels = statusbar_labels(model, 560.0)
  inspect(labels.length(), content="2")
  inspect(labels[0], content="Runtime: ready")
  inspect(labels[1], content="Session: draft")
}

///|
test "active session changed event updates active id" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(ActiveSessionChanged("abc-123")),
    ),
  )
  guard model.code.active_session_id is Some(id) else {
    fail("expected active session id")
  }
  inspect(id, content="abc-123")
}

///|
test "session rebuilt replaces message list" {
  let model = test_model(script=_cmd => [])
  // Start with some messages.
  let model = {
    ..model,
    code: {
      ..model.code,
      messages: [
        ChatMessage::User("old"),
        ChatMessage::Assistant("old reply", None),
      ],
    },
  }
  inspect(model.code.messages.length(), content="2")
  // Rebuild with a fresh set.
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(
        SessionRebuilt([
          UserMessageAdded("new"),
          AssistantMessageAdded("new reply", None),
        ]),
      ),
    ),
  )
  inspect(model.code.messages.length(), content="2")
  guard model.code.messages[0] is User(t) else { fail("expected user message") }
  inspect(t, content="new")
}

///|
test "new session clears messages and prompt" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: {
      ..model.code,
      messages: [ChatMessage::User("old")],
      prompt: "draft",
      is_streaming: true,
    },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::NewSession),
  )
  inspect(model.code.messages.length(), content="0")
  inspect(model.code.prompt, content="")
  assert_false(model.code.is_streaming)
}

///|
test "select session switches active id and clears messages" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: { ..model.code, messages: [ChatMessage::User("old")] },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SelectSession("target-id")),
  )
  guard model.code.active_session_id is Some(id) else {
    fail("expected active session id")
  }
  inspect(id, content="target-id")
  inspect(model.code.messages.length(), content="0")
}

///|
test "toggle appearance cycles system light dark" {
  let model = test_model(script=_cmd => [])
  inspect(model.appearance == AppearanceMode::System, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::ToggleAppearance)
  inspect(model.appearance == AppearanceMode::Light, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::ToggleAppearance)
  inspect(model.appearance == AppearanceMode::Dark, content="true")
  let (model, _effect) = model.update(WorkbenchMsg::ToggleAppearance)
  inspect(model.appearance == AppearanceMode::System, content="true")
}

///|
test "clear error removes error" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, code: { ..model.code, error: Some("oops") } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ClearError),
  )
  guard model.code.error is None else { fail("expected error to be cleared") }
}

///|
test "empty prompt submit is a no-op" {
  let fixture = AgentBackendFixture::new(script=_cmd => [])
  let model = WorkbenchModel::new(backend=fixture.runtime())
  let model = { ..model, code: { ..model.code, prompt: "   \n  " } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  inspect(model.code.messages.length(), content="0")
  assert_false(model.code.is_streaming)
  inspect(fixture.dispatched_commands().length(), content="0")
}

///|
test "streaming prompt submit is ignored" {
  let fixture = AgentBackendFixture::new(script=_cmd => [])
  let model = WorkbenchModel::new(backend=fixture.runtime())
  let model = {
    ..model,
    code: {
      ..model.code,
      messages: [ChatMessage::User("first task")],
      prompt: "second task",
      is_streaming: true,
      progress_notice: Some("Running tool..."),
    },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  inspect(model.code.messages.length(), content="1")
  inspect(model.code.prompt, content="second task")
  assert_true(model.code.is_streaming)
  guard model.code.progress_notice is Some(notice) else {
    fail("expected existing progress notice")
  }
  inspect(notice, content="Running tool...")
  inspect(fixture.dispatched_commands().length(), content="0")
}

///|
test "program init fetches existing sessions" {
  let fixture = AgentBackendFixture::new(script=cmd => {
    match cmd {
      FetchSessionList =>
        [SessionListed([SessionSummary::new(id="s1", first_prompt="resume")])]
      _ => []
    }
  })
  let program = program_with_backend(backend=fixture.runtime())
  let (_model, effect) = program.runtime_init()
  inspect(fixture.dispatched_commands().length(), content="0")
  let messages = drain_workbench_effect(effect)
  let commands = fixture.dispatched_commands()
  inspect(commands.length(), content="1")
  guard commands[0] is FetchSessionList else {
    fail("expected startup session fetch")
  }
  inspect(messages.length(), content="1")
  guard messages[0]
    is WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(SessionListed(sessions))
    ) else {
    fail("expected session list event")
  }
  inspect(sessions.length(), content="1")
  inspect(sessions[0].id, content="s1")
}

///|
test "steer submit only works while streaming" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, code: { ..model.code, steer_text: "go left" } }
  // Not streaming -> no-op.
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitSteer),
  )
  inspect(model.code.steer_text, content="go left")
  // Now streaming -> clears steer text.
  let model = { ..model, code: { ..model.code, is_streaming: true } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitSteer),
  )
  inspect(model.code.steer_text, content="")
}

///|
test "model changed updates current model" {
  let model = test_model(script=_cmd => [])
  inspect(model.code.current_model == "deepseek-v4-flash", content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ModelChanged("deepseek", "deepseek-v4-pro")),
  )
  inspect(model.code.current_model == "deepseek-v4-pro", content="true")
}

///|
test "unsupported custom model change is ignored" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ModelChanged("openai", "gpt-4o")),
  )
  inspect(model.code.current_model, content="deepseek-v4-flash")
  guard model.code.current_provider_id is Some(provider_id) else {
    fail("expected current provider")
  }
  inspect(provider_id, content="deepseek")
}

///|
test "provider with only unsupported models stays inspectable but not selected" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: { ..model.code, model_picker_open: true },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SelectProvider("openai")),
  )
  guard model.settings.active_provider_id is Some(active_provider_id) else {
    fail("expected active provider")
  }
  inspect(active_provider_id, content="openai")
  inspect(model.code.current_model, content="deepseek-v4-flash")
  guard model.code.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider")
  }
  inspect(current_provider_id, content="deepseek")
  assert_true(model.code.model_picker_open)
}

///|
test "thinking changed updates current thinking" {
  let model = test_model(script=_cmd => [])
  inspect(model.code.current_thinking == ThinkingChoice::Normal, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ThinkingChanged(ThinkingChoice::Normal)),
  )
  inspect(model.code.current_thinking == ThinkingChoice::Normal, content="true")
}

///|
test "compact picker cycles are stable" {
  inspect(
    next_thinking_choice(ThinkingChoice::Normal) == ThinkingChoice::High,
    content="true",
  )
  inspect(
    next_thinking_choice(ThinkingChoice::High) == ThinkingChoice::Max,
    content="true",
  )
  inspect(
    next_thinking_choice(ThinkingChoice::Max) == ThinkingChoice::Normal,
    content="true",
  )
}

///|
test "progress notice does not add a message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(ProgressNotice("thinking...")),
    ),
  )
  inspect(model.code.messages.length(), content="0")
  guard model.code.progress_notice is Some(text) else {
    fail("expected progress notice")
  }
  inspect(text, content="thinking...")
}

///|
test "terminal event clears transient progress notice" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: {
      ..model.code,
      is_streaming: true,
      progress_notice: Some("running tool"),
    },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(TurnTerminal(TurnStatus::Finished, "Done")),
    ),
  )
  assert_false(model.code.is_streaming)
  guard model.code.progress_notice is None else {
    fail("expected progress notice to clear")
  }
}

///|
test "runtime notice projects to runtime message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(
      CodeMsg::ReceiveAgentEvent(RuntimeNoticeAdded("compacted")),
    ),
  )
  inspect(model.code.messages.length(), content="1")
  guard model.code.messages[0] is RuntimeNotice(text) else {
    fail("expected runtime notice")
  }
  inspect(text, content="compacted")
}

///|
test "fixture backend records dispatched commands" {
  let fixture = AgentBackendFixture::new(script=_cmd => [])
  let runtime = fixture.runtime()
  // Drive the runtime directly: dispatch a SendTask command and collect events.
  let events : Array[AgentEvent] = []
  (runtime.run)([SendTask("do something")], event => events.push(event))
  let cmds = fixture.dispatched_commands()
  inspect(cmds.length(), content="1")
  guard cmds[0] is SendTask(task) else { fail("expected SendTask command") }
  inspect(task, content="do something")
}

// ---------------------------------------------------------------------------
// Settings workspace (new)
// ---------------------------------------------------------------------------

///|
test "settings api key change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(
      SettingsMsg::UpdateProviderField("deepseek", ApiKey, "sk-xxx"),
    ),
  )
  inspect(
    model.settings.find_provider("deepseek").unwrap().api_key,
    content="sk-xxx",
  )
}

///|
test "settings base url change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(
      SettingsMsg::UpdateProviderField(
        "deepseek",
        BaseUrl,
        "https://api.example.com",
      ),
    ),
  )
  inspect(
    model.settings.find_provider("deepseek").unwrap().base_url,
    content="https://api.example.com",
  )
}

///|
test "settings add provider creates selectable additional providers" {
  let model = test_model(script=_cmd => [])
  inspect(model.settings.providers.length(), content="2")
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::AddProvider),
  )
  inspect(model.settings.providers.length(), content="3")
  guard model.settings.active_provider_id is Some(active) else {
    fail("expected active provider")
  }
  inspect(active, content="provider-3")
  inspect(
    model.settings.find_provider("provider-3").unwrap().name,
    content="Provider 3",
  )
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::AddProvider),
  )
  inspect(model.settings.providers.length(), content="4")
  guard model.settings.active_provider_id is Some(active2) else {
    fail("expected active provider")
  }
  inspect(active2, content="provider-4")
}

///|
test "settings approval change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  inspect(
    model.settings.approval_policy == ApprovalPolicy::AskOnWrite,
    content="true",
  )
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(
      SettingsMsg::ApprovalChanged(ApprovalPolicy::NeverAsk),
    ),
  )
  inspect(
    model.settings.approval_policy == ApprovalPolicy::NeverAsk,
    content="true",
  )
}

///|
test "settings sandbox change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(
      SettingsMsg::SandboxChanged(SandboxMode::ReadOnly),
    ),
  )
  inspect(model.settings.sandbox_mode == SandboxMode::ReadOnly, content="true")
}

///|
test "settings font size clamps to range" {
  let model = test_model(script=_cmd => [])
  // Below minimum (10).
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::FontSizeChanged(4)),
  )
  inspect(model.settings.font_size, content="10")
  // Above maximum (24).
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::FontSizeChanged(99)),
  )
  inspect(model.settings.font_size, content="24")
  // In range.
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::FontSizeChanged(16)),
  )
  inspect(model.settings.font_size, content="16")
}

///|
test "settings working dir change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::WorkingDirChanged("~/projects/x")),
  )
  inspect(model.settings.working_dir, content="~/projects/x")
}

///|
test "welcome folder label falls back until a workspace is selected" {
  inspect(workspace_folder_label(""), content="选择文件夹")
  inspect(workspace_folder_label("."), content="选择文件夹")
  inspect(workspace_folder_label("/tmp/MoUI"), content="MoUI")
  inspect(workspace_folder_label("/tmp/MoUI/"), content="MoUI")
}

///|
test "welcome folder picker stores selected workspace" {
  let fixture = AgentBackendFixture::new(script=_cmd => [])
  let persisted : Ref[MoWorkbenchSettingsFile?] = Ref(None)
  let services = workbench_folder_dialog_services(["/tmp/project"])
  let model = WorkbenchModel::new(
    backend=fixture.runtime(),
    settings_persist=Some(file => persisted.val = Some(file)),
    host_services=services,
  )
  let (model, effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::PickWorkspaceFolder),
  )
  inspect(model.settings.working_dir, content=".")
  let messages = drain_workbench_effect(effect)
  inspect(messages.length(), content="1")
  guard messages[0]
    is WorkbenchMsg::CodeMsg(
      CodeMsg::WorkspaceFolderSelected(Some("/tmp/project"))
    ) else {
    fail("expected selected folder message")
  }
  let (model, _effect) = model.update(messages[0])
  inspect(model.settings.working_dir, content="/tmp/project")
  guard persisted.val is Some(file) else {
    fail("expected folder selection to persist settings")
  }
  inspect(file.mo_workbench_workspace, content="/tmp/project")
}

///|
test "settings segmented ids map to stable enum values" {
  inspect(approval_policy_id(ApprovalPolicy::NeverAsk), content="never")
  inspect(approval_policy_id(ApprovalPolicy::AskOnWrite), content="write")
  inspect(
    approval_policy_from_id("command") == ApprovalPolicy::AskOnCommand,
    content="true",
  )
  inspect(sandbox_mode_id(SandboxMode::ReadOnly), content="read-only")
  inspect(sandbox_mode_id(SandboxMode::WorkspaceWritable), content="workspace")
  inspect(
    sandbox_mode_from_id("full") == SandboxMode::FullAccess,
    content="true",
  )
}

///|
test "workbench theme token helpers use neutral gray reference colors" {
  let light = @views.light_theme()
  inspect(
    workbench_app_background(light) ==
    @core.Color::rgba(r=243.0 / 255.0, g=245.0 / 255.0, b=252.0 / 255.0, a=1.0),
    content="true",
  )
  inspect(
    workbench_sidebar_background(light) ==
    @core.Color::rgba(r=238.0 / 255.0, g=242.0 / 255.0, b=250.0 / 255.0, a=1.0),
    content="true",
  )
  inspect(
    workbench_accent(light) ==
    @core.Color::rgba(r=100.0 / 255.0, g=100.0 / 255.0, b=100.0 / 255.0, a=1.0),
    content="true",
  )
  inspect(
    workbench_sidebar_active(light) ==
    @core.Color::rgba(r=200.0 / 255.0, g=200.0 / 255.0, b=200.0 / 255.0, a=0.50),
    content="true",
  )
}
