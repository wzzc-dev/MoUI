// Portable tests for the workbench update loop and view projections.
// Uses a fixture backend that replays scripted events without network access.

///|
/// Build a model with a fixture backend for testing. The script maps each
/// command to the events the backend should emit in response.
fn test_model(script~ : (AgentCommand) -> Array[AgentEvent]) -> WorkbenchModel {
  let fixture = AgentBackendFixture::new(script~)
  WorkbenchModel::new(backend=fixture.runtime())
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
  let model = { ..model, prompt: "hello" }
  let (model, _effect) = model.update(WorkbenchMsg::SubmitPrompt)
  // The user message is appended optimistically.
  inspect(model.messages.length(), content="1")
  guard model.messages[0] is User(text) else { fail("expected user message") }
  inspect(text, content="hello")
  // Prompt is cleared and streaming flag is set.
  inspect(model.prompt, content="")
  assert_true(model.is_streaming)
}

///|
test "receive assistant event appends message and clears streaming on terminal" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, is_streaming: true }
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(AssistantMessageAdded("hi", None)),
  )
  inspect(model.messages.length(), content="1")
  guard model.messages[0] is Assistant(content, _) else {
    fail("expected assistant message")
  }
  inspect(content, content="hi")
  // Still streaming until terminal event.
  assert_true(model.is_streaming)
  // Now receive the terminal event.
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(TurnTerminal(TurnStatus::Finished, "Done")),
  )
  assert_false(model.is_streaming)
  inspect(model.messages.length(), content="2")
  guard model.messages[1] is Terminal(status, _) else {
    fail("expected terminal message")
  }
  inspect(status == TurnStatus::Finished, content="true")
}

///|
test "failed terminal sets error" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, is_streaming: true }
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(
      TurnTerminal(TurnStatus::Failed, "network error"),
    ),
  )
  assert_false(model.is_streaming)
  guard model.error is Some(err) else { fail("expected error to be set") }
  inspect(err, content="network error")
}

///|
test "tool result event projects to tool message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(
      ToolResultAdded("shell", "exit 0", false, Some("ran ls")),
    ),
  )
  inspect(model.messages.length(), content="1")
  guard model.messages[0] is ToolResult(name, _, is_error, brief) else {
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
    WorkbenchMsg::ReceiveAgentEvent(SessionListed(sessions)),
  )
  inspect(model.sessions.length(), content="2")
  inspect(model.sessions[0].id, content="s1")
}

///|
test "active session changed event updates active id" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(ActiveSessionChanged("abc-123")),
  )
  guard model.active_session_id is Some(id) else {
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
    messages: [
      ChatMessage::User("old"),
      ChatMessage::Assistant("old reply", None),
    ],
  }
  inspect(model.messages.length(), content="2")
  // Rebuild with a fresh set.
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(
      SessionRebuilt([
        UserMessageAdded("new"),
        AssistantMessageAdded("new reply", None),
      ]),
    ),
  )
  inspect(model.messages.length(), content="2")
  guard model.messages[0] is User(t) else { fail("expected user message") }
  inspect(t, content="new")
}

///|
test "new session clears messages and prompt" {
  let model = test_model(script=_cmd => [])
  let model = {
    ..model,
    messages: [ChatMessage::User("old")],
    prompt: "draft",
    is_streaming: true,
  }
  let (model, _effect) = model.update(WorkbenchMsg::NewSession)
  inspect(model.messages.length(), content="0")
  inspect(model.prompt, content="")
  assert_false(model.is_streaming)
}

///|
test "select session switches active id and clears messages" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, messages: [ChatMessage::User("old")] }
  let (model, _effect) = model.update(WorkbenchMsg::SelectSession("target-id"))
  guard model.active_session_id is Some(id) else {
    fail("expected active session id")
  }
  inspect(id, content="target-id")
  inspect(model.messages.length(), content="0")
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
  let model = { ..model, error: Some("oops") }
  let (model, _effect) = model.update(WorkbenchMsg::ClearError)
  guard model.error is None else { fail("expected error to be cleared") }
}

///|
test "empty prompt submit is a no-op" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(WorkbenchMsg::SubmitPrompt)
  inspect(model.messages.length(), content="0")
  assert_false(model.is_streaming)
}

///|
test "steer submit only works while streaming" {
  let model = test_model(script=_cmd => [])
  let model = { ..model, steer_text: "go left" }
  // Not streaming -> no-op.
  let (model, _effect) = model.update(WorkbenchMsg::SubmitSteer)
  inspect(model.steer_text, content="go left")
  // Now streaming -> clears steer text.
  let model = { ..model, is_streaming: true }
  let (model, _effect) = model.update(WorkbenchMsg::SubmitSteer)
  inspect(model.steer_text, content="")
}

///|
test "model changed updates current model" {
  let model = test_model(script=_cmd => [])
  inspect(model.current_model == ModelChoice::V4Pro, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::ModelChanged(ModelChoice::V4Flash),
  )
  inspect(model.current_model == ModelChoice::V4Flash, content="true")
}

///|
test "thinking changed updates current thinking" {
  let model = test_model(script=_cmd => [])
  inspect(model.current_thinking == ThinkingChoice::Max, content="true")
  let (model, _effect) = model.update(
    WorkbenchMsg::ThinkingChanged(ThinkingChoice::No),
  )
  inspect(model.current_thinking == ThinkingChoice::No, content="true")
}

///|
test "progress notice does not add a message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(ProgressNotice("thinking...")),
  )
  inspect(model.messages.length(), content="0")
}

///|
test "runtime notice projects to runtime message" {
  let model = test_model(script=_cmd => [])
  let (model, _effect) = model.update(
    WorkbenchMsg::ReceiveAgentEvent(RuntimeNoticeAdded("compacted")),
  )
  inspect(model.messages.length(), content="1")
  guard model.messages[0] is RuntimeNotice(text) else {
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
