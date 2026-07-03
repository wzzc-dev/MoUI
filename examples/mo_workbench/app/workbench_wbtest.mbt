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

// ---------------------------------------------------------------------------
// Code workspace (migrated from the previous flat-model tests)
// ---------------------------------------------------------------------------

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
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  inspect(model.code.messages.length(), content="0")
  assert_false(model.code.is_streaming)
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
  inspect(model.code.current_model == ModelChoice::V4Pro, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ModelChanged(ModelChoice::V4Flash)),
  )
  inspect(model.code.current_model == ModelChoice::V4Flash, content="true")
}

///|
test "thinking changed updates current thinking" {
  let model = test_model(script=_cmd => [])
  inspect(model.code.current_thinking == ThinkingChoice::Max, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::ThinkingChanged(ThinkingChoice::No)),
  )
  inspect(model.code.current_thinking == ThinkingChoice::No, content="true")
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
// Shell routing (new)
// ---------------------------------------------------------------------------

///|
test "shell starts on the Code workspace" {
  let model = test_model(script=_cmd => [])
  inspect(model.active_workspace == Workspace::Code, content="true")
}

///|
test "switch workspace updates active workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::Settings),
  )
  inspect(model.active_workspace == Workspace::Settings, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::Write),
  )
  inspect(model.active_workspace == Workspace::Write, content="true")
  // Reserved workspaces are switchable (they render a placeholder surface).
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::ConnectPhone),
  )
  inspect(model.active_workspace == Workspace::ConnectPhone, content="true")
}

///|
test "switching workspace does not disturb code workspace state" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    code: {
      ..model.code,
      messages: [ChatMessage::User("keep me")],
      prompt: "draft",
    },
  }
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::Settings),
  )
  // Code workspace state is preserved across workspace switches.
  inspect(model.code.messages.length(), content="1")
  inspect(model.code.prompt, content="draft")
}

///|
test "code msg routes to code workspace" {
  let model = test_model(script=cmd => {
    match cmd {
      SendTask(task) => [TurnTerminal(TurnStatus::Finished, "done: " + task)]
      _ => []
    }
  })
  let model = { ..model, code: { ..model.code, prompt: "route me" } }
  let (model, _effect) = model.update(
    WorkbenchMsg::CodeMsg(CodeMsg::SubmitPrompt),
  )
  inspect(model.code.is_streaming, content="true")
  inspect(model.code.messages.length(), content="1")
  // Now switch to Settings and back; code state persists.
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::Settings),
  )
  let (model, _effect) = model.update(
    WorkbenchMsg::SwitchWorkspace(Workspace::Code),
  )
  inspect(model.code.messages.length(), content="1")
}

// ---------------------------------------------------------------------------
// Settings workspace (new)
// ---------------------------------------------------------------------------

///|
test "settings api key change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(SettingsMsg::ApiKeyChanged("sk-xxx")),
  )
  inspect(model.settings.api_key, content="sk-xxx")
}

///|
test "settings base url change updates settings workspace" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::SettingsMsg(
      SettingsMsg::BaseUrlChanged("https://api.example.com"),
    ),
  )
  inspect(model.settings.base_url, content="https://api.example.com")
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

// ---------------------------------------------------------------------------
// UI helper coverage
// ---------------------------------------------------------------------------

///|
test "workbench layout uses reference desktop widths and hides inspector when narrow" {
  let desktop = workbench_layout(@core.Size::new(width=1440.0, height=900.0))
  inspect(desktop.sidebar_width == 280.0, content="true")
  inspect(desktop.inspector_width == 340.0, content="true")
  inspect(desktop.inspector_visible, content="true")
  inspect(desktop.center_width == 820.0, content="true")
  let tablet = workbench_layout(@core.Size::new(width=1024.0, height=768.0))
  inspect(tablet.sidebar_width == 248.0, content="true")
  inspect(tablet.inspector_visible, content="false")
  inspect(tablet.center_width == 776.0, content="true")
  let narrow = workbench_layout(@core.Size::new(width=700.0, height=680.0))
  inspect(narrow.sidebar_width == 200.0, content="true")
  inspect(narrow.inspector_visible, content="false")
}

///|
test "workspace labels and icons match shell navigation" {
  inspect(workspace_label(Workspace::Code), content="Code")
  inspect(workspace_label(Workspace::ConnectPhone), content="Connect Phone")
  inspect(workspace_label(Workspace::ScheduledTasks), content="Scheduled Tasks")
  inspect(
    workspace_icon(Workspace::Code) == @views.IconName::CodeInline,
    content="true",
  )
  inspect(
    workspace_icon(Workspace::Write) == @views.IconName::FileNew,
    content="true",
  )
  inspect(
    workspace_icon(Workspace::Plugins) == @views.IconName::Columns,
    content="true",
  )
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
test "model and thinking segmented ids map to stable enum values" {
  inspect(model_choice_id(ModelChoice::V4Pro), content="v4-pro")
  inspect(
    model_choice_from_id("v4-flash") == ModelChoice::V4Flash,
    content="true",
  )
  inspect(thinking_choice_id(ThinkingChoice::Max), content="max")
  inspect(
    thinking_choice_from_id("high") == ThinkingChoice::High,
    content="true",
  )
}
