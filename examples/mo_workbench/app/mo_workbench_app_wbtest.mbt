///|
test "workbench dispatch queues prompt for selected session" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("Inspect the Skia renderer route"))
    .update(ToggleComposerControls)
    .update(DispatchPrompt)
  inspect(model.prompt, content="")
  inspect(model.composer_controls_expanded, content="false")
  inspect(model.last_status, content="Queued prompt for Pi JSONL RPC")
  assert_true(model.main_scroll_offset_y > 1000000.0)
  inspect(model.pending_transport_count(), content="2")
  inspect(model.transcript.length(), content="1")
  inspect(model.transcript[0].role, content="user")
  inspect(
    model.transcript[0].summary,
    content=context_task_payload("Inspect the Skia renderer route"),
  )
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload("Inspect the Skia renderer route"),
      )
    }
    _ => fail("expected queued user input")
  }
}

///|
test "workbench keeps new conversation content pinned to latest message" {
  let pi_model = model_with_overflowing_transcript()
    .update(MainScrollTo(24.0))
    .update(PromptChanged("Continue at the bottom"))
    .update(DispatchPrompt)
  assert_true(pi_model.main_scroll_offset_y > 1000000.0)
  let fixture_model = model_with_overflowing_transcript()
    .update(SwitchAgentBackend("fixture"))
    .update(MainScrollTo(24.0))
    .update(PromptChanged("Keep local reply visible"))
    .update(DispatchPrompt)
  assert_true(fixture_model.main_scroll_offset_y > 1000000.0)
  inspect(fixture_model.transcript.length(), content="2")
}

///|
test "workbench creates a visible task history conversation" {
  let model = WorkbenchModel::new().update(CreateConversation)
  inspect(model.selected_session_id, content="conversation-1")
  inspect(model.sessions.length(), content="3")
  inspect(model.sessions[0].id, content="conversation-1")
  inspect(model.sessions[0].title, content="新对话 1")
  inspect(model.sessions[0].backend_id, content="pi")
  inspect(
    model.sessions[0].project_path,
    content="/Volumes/Data/Code/moon/MoUI",
  )
  inspect(model.prompt, content="")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transcript.length(), content="0")
  inspect(model.last_status, content="Workbench conversation created")
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "新对话"))
  assert_true(has_text(commands, "新对话 1"))
  assert_true(has_text(commands, "准备开始这个会话"))
}

///|
test "workbench new conversation keeps active backend profile" {
  let model = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(CreateConversation)
  inspect(model.selected_session_id, content="conversation-1")
  inspect(model.sessions[0].backend_id, content="fixture")
  inspect(model.active_agent_backend_profile().label, content="本地")
  inspect(model.pending_transport_count(), content="0")
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "新对话"))
  assert_true(has_text(commands, "新对话 1"))
  assert_true(has_text(commands, "Agent 本地"))
}

///|
test "workbench ignores empty composer dispatch" {
  let model = WorkbenchModel::new().update(DispatchPrompt)
  inspect(model.last_status, content="Prompt is empty")
  inspect(model.pending_transport_count(), content="0")
  assert_true(model.events.is_empty())
}

///|
test "workbench composer can send a prompt without selected context" {
  let model = WorkbenchModel::new()
    .update(ToggleContext("repo"))
    .update(ToggleContext("examples"))
    .update(PromptChanged("Inspect without context"))
    .update(DispatchPrompt)
  match model.transport.command_queue[1] {
    SendUserInput(_, text) => inspect(text, content="Inspect without context")
    _ => fail("expected queued user input")
  }
}

///|
test "workbench composer sends slash prompts without context wrapper" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("/review"))
    .update(DispatchPrompt)
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued prompt for Pi JSONL RPC")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content="/review")
    }
    _ => fail("expected queued slash prompt")
  }
}

///|
test "workbench agent focus routes prompt context without new transport command" {
  let model = WorkbenchModel::new()
    .update(SelectAgent("coding"))
    .update(PromptChanged("Implement the next focused slice"))
    .update(DispatchPrompt)
  inspect(model.selected_agent_id, content="coding")
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued prompt for Pi JSONL RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=agent_context_task_payload("Implement the next focused slice"),
      )
    }
    _ => fail("expected queued user input")
  }
}

///|
test "workbench agent focus selection toggles and rejects unknown ids" {
  let selected = WorkbenchModel::new().update(SelectAgent("verify"))
  inspect(selected.selected_agent_id, content="verify")
  inspect(selected.last_status, content="Agent focus selected: 校验")
  let cleared = selected.update(SelectAgent("verify"))
  inspect(cleared.selected_agent_id, content="")
  inspect(cleared.last_status, content="Agent focus cleared")
  let unknown = cleared.update(SelectAgent("unknown"))
  inspect(unknown.selected_agent_id, content="")
  inspect(unknown.last_status, content="Agent focus unavailable")
}

///|
test "workbench agent backend profiles expose Pi ACP and fixture capabilities" {
  let profiles = agent_backend_profiles()
  inspect(profiles.length(), content="3")
  inspect(profiles[0].id, content="pi")
  inspect(profiles[0].label, content="Pi")
  inspect(profiles[0].transport_kind.label(), content="pi jsonl rpc")
  inspect(profiles[0].uses_pi_transport(), content="true")
  inspect(profiles[0].capabilities.supports_fork, content="true")
  inspect(profiles[0].capabilities.supports_command_catalog, content="true")
  inspect(profiles[1].id, content="acp-demo")
  inspect(profiles[1].label, content="ACP Demo")
  inspect(profiles[1].transport_kind.label(), content="acp connector")
  inspect(profiles[1].uses_connector_transport(), content="true")
  inspect(profiles[1].capabilities.supports_session_refresh, content="true")
  inspect(profiles[1].capabilities.supports_command_catalog, content="true")
  inspect(profiles[2].id, content="fixture")
  inspect(profiles[2].label, content="本地")
  inspect(profiles[2].transport_kind.label(), content="fixture")
  inspect(profiles[2].uses_pi_transport(), content="false")
  inspect(profiles[2].capabilities.supports_fork, content="false")
  inspect(profiles[2].capabilities.supports_input_modes, content="false")
}

///|
test "workbench projects backend status through agent-neutral contract" {
  let idle = WorkbenchModel::new().active_agent_backend_status()
  inspect(idle.backend_id, content="pi")
  inspect(idle.label, content="Pi")
  inspect(idle.status_label, content="未连接")
  inspect(idle.pending_count, content="0")
  inspect(idle.failed, content="false")
  inspect(idle.has_sidebar_status(), content="false")
  inspect(idle.has_top_bar_chip(), content="false")

  let queued = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .active_agent_backend_status()
  inspect(queued.backend_id, content="pi")
  inspect(queued.status_label, content="启动中")
  inspect(queued.pending_count, content="2")
  inspect(queued.failed, content="false")
  inspect(queued.has_sidebar_status(), content="false")
  inspect(queued.has_top_bar_chip(), content="false")

  let failed = WorkbenchModel::new()
    .update(ReceiveTransport(TransportFailed("pi unavailable")))
    .active_agent_backend_status()
  inspect(failed.status_label, content="失败：pi unavailable")
  inspect(failed.failed, content="true")
  inspect(failed.has_sidebar_status(), content="true")
  inspect(failed.has_top_bar_chip(), content="true")

  let fixture = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .active_agent_backend_status()
  inspect(fixture.backend_id, content="fixture")
  inspect(fixture.label, content="本地")
  inspect(fixture.status_label, content="")
  inspect(fixture.has_sidebar_status(), content="false")
  inspect(fixture.has_top_bar_chip(), content="true")
}

///|
test "workbench exposes backend-neutral active agent session binding" {
  let pi_binding = WorkbenchModel::new().active_agent_session_binding()
  inspect(pi_binding.backend_id, content="pi")
  inspect(pi_binding.workbench_session_id, content="moui-skia")
  inspect(pi_binding.provider_session_id, content="")
  inspect(pi_binding.status, content="unbound")

  let fixture_binding = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .active_agent_session_binding()
  inspect(fixture_binding.backend_id, content="fixture")
  inspect(fixture_binding.workbench_session_id, content="moui-skia")
  inspect(fixture_binding.provider_session_id, content="")
  inspect(fixture_binding.session_file, content="")
  inspect(fixture_binding.status, content="unbound")
}

///|
test "workbench projects Pi session binding through agent-neutral contract" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e7eb5","sessionName":"Mo Workbench smoke","sessionFile":"/tmp/mo-workbench-smoke.jsonl","messageCount":4,"pendingMessageCount":0}}
        ),
      ),
    ),
  )
  let binding = model.active_agent_session_binding()
  inspect(binding.backend_id, content="pi")
  inspect(binding.workbench_session_id, content="moui-skia")
  inspect(binding.provider_session_id, content="019e7eb5")
  inspect(binding.session_name, content="Mo Workbench smoke")
  inspect(binding.model, content="openai/gpt-5")
  inspect(binding.status, content="bound")
}

///|
test "workbench projects Pi model catalog entries through agent-neutral contract" {
  let model = {
    ..WorkbenchModel::new(),
    model_catalog: [
      PiModelInfo::new(provider="openai", id="gpt-5", name="GPT-5"),
      PiModelInfo::new(
        provider="anthropic",
        id="claude-sonnet-4.5",
        name="Claude Sonnet 4.5",
      ),
    ],
  }
  let models = model.active_agent_model_catalog()
  inspect(models.length(), content="2")
  inspect(models[0].provider, content="openai")
  inspect(models[0].id, content="gpt-5")
  inspect(models[0].label, content="GPT-5 (openai/gpt-5)")
  inspect(
    models[1].label,
    content="Claude Sonnet 4.5 (anthropic/claude-sonnet-4.5)",
  )

  let fixture_models = model
    .update(SwitchAgentBackend("fixture"))
    .active_agent_model_catalog()
  inspect(fixture_models.length(), content="0")
}

///|
test "workbench projects Pi session stats through agent-neutral metrics" {
  let model = {
    ..WorkbenchModel::new(),
    pi_session_stats: PiSessionStatsSnapshot::new(
      session_id="019e7f62",
      total_messages=10,
      tool_calls=4,
      tool_results=5,
      token_total=1340,
      context_percent=Some(16.0),
    ),
  }
  let metrics = model.active_agent_session_metrics()
  inspect(metrics.backend_id, content="pi")
  inspect(metrics.workbench_session_id, content="moui-skia")
  inspect(metrics.total_messages, content="10")
  inspect(metrics.tool_calls, content="4")
  inspect(metrics.tool_results, content="5")
  inspect(metrics.token_total, content="1340")
  inspect(metrics.has_visible_metrics(), content="true")
  match metrics.context_percent {
    Some(percent) => inspect(percent.to_int(), content="16")
    None => fail("expected context percentage")
  }

  let fixture_metrics = model
    .update(SwitchAgentBackend("fixture"))
    .active_agent_session_metrics()
  inspect(fixture_metrics.backend_id, content="fixture")
  inspect(fixture_metrics.workbench_session_id, content="moui-skia")
  inspect(fixture_metrics.has_visible_metrics(), content="false")
}

///|
test "workbench projects Pi runtime state through agent-neutral signal" {
  let model = {
    ..WorkbenchModel::new(),
    pi_agent: PiAgentSnapshot::new(
      phase="tool",
      active_tool_name="read",
      message_preview="Inspecting renderer files",
      thinking_level="high",
    ),
  }
  let signal = model.active_agent_runtime_signal()
  inspect(signal.backend_id, content="pi")
  inspect(signal.status_label, content="工具中 · 工具 read")
  inspect(signal.active_tool_name, content="read")
  inspect(signal.message_preview, content="Inspecting renderer files")
  inspect(signal.thinking_level, content="high")
  inspect(signal.has_visible_signal(), content="true")
  inspect(signal.has_active_signal(), content="true")
}

///|
test "workbench fixture runtime signal ignores stale Pi provider state" {
  let model = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    transport: PiTransportState::new().enqueue(FetchRpcMessages("stale")),
    pi_agent: PiAgentSnapshot::new(
      phase="tool",
      active_tool_name="bash",
      message_preview="stale provider detail",
      thinking_level="high",
    ),
  }
  let signal = model.active_agent_runtime_signal()
  inspect(signal.backend_id, content="fixture")
  inspect(signal.status_label, content="")
  inspect(signal.active_tool_name, content="")
  inspect(signal.message_preview, content="")
  inspect(signal.thinking_level, content="")
  inspect(signal.has_visible_signal(), content="false")
  inspect(signal.has_active_signal(), content="false")
}

///|
test "workbench projects Pi input settings through agent-neutral contract" {
  let model = {
    ..WorkbenchModel::new(),
    pi_agent: PiAgentSnapshot::new(
      thinking_level="high",
      steering_mode="all",
      follow_up_mode="one-at-a-time",
      queued_steering=2,
      queued_follow_up=1,
    ),
  }
  let settings = model.active_agent_input_settings()
  inspect(settings.backend_id, content="pi")
  inspect(settings.thinking_level, content="high")
  inspect(settings.steering_mode, content="all")
  inspect(settings.follow_up_mode, content="one-at-a-time")
  inspect(settings.queued_input_count(), content="3")
  inspect(settings.has_visible_thinking_level(), content="true")
  inspect(settings.has_visible_input_modes(), content="true")
}

///|
test "workbench fixture input settings ignore stale Pi modes" {
  let model = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    pi_agent: PiAgentSnapshot::new(
      thinking_level="high",
      steering_mode="all",
      follow_up_mode="all",
      queued_steering=1,
      queued_follow_up=1,
    ),
  }
  let settings = model.active_agent_input_settings()
  inspect(settings.backend_id, content="fixture")
  inspect(settings.thinking_level, content="")
  inspect(settings.steering_mode, content="one-at-a-time")
  inspect(settings.follow_up_mode, content="one-at-a-time")
  inspect(settings.queued_input_count(), content="0")
  inspect(settings.has_visible_thinking_level(), content="false")
  inspect(settings.has_visible_input_modes(), content="false")
}

///|
test "workbench projects Pi fork candidates through agent-neutral fork points" {
  let assistant = TranscriptItem::new(
    id="entry-assistant-1",
    role="assistant",
    summary="Skia route inspected",
    detail="",
    tone="success",
  )
  let model = {
    ..WorkbenchModel::new(),
    transcript: [
      TranscriptItem::new(
        id="entry-user-1",
        role="user",
        summary="Inspect the Skia route",
        detail="",
        tone="info",
      ),
      assistant,
    ],
    fork_messages: [
      PiForkMessage::new(entry_id="entry-user-1", text="Inspect the Skia route"),
    ],
  }
  let points = model.active_agent_fork_points_for_transcript_item(assistant)
  inspect(points.length(), content="1")
  inspect(points[0].entry_id, content="entry-user-1")
  inspect(points[0].text, content="Inspect the Skia route")

  let fixture_points = model
    .update(SwitchAgentBackend("fixture"))
    .active_agent_fork_points_for_transcript_item(assistant)
  inspect(fixture_points.length(), content="0")
}

///|
test "workbench switches current session backend and resets provider state" {
  let model = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .update(PromptChanged("stale prompt"))
    .update(SwitchAgentBackend("fixture"))
  inspect(model.active_session().backend_id, content="fixture")
  inspect(model.active_agent_backend_profile().label, content="本地")
  inspect(model.prompt, content="")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Disconnected")
  inspect(model.pi_session_bindings.length(), content="0")
  inspect(model.transcript.length(), content="0")
  inspect(model.last_status, content="Agent backend switched: 本地")
  assert_false(
    model.events.any(event => event.title == "Pi RPC process started"),
  )
  assert_true(
    model.events.any(event => event.title == "Agent backend switched"),
  )
  let unknown = model.update(SwitchAgentBackend("missing"))
  inspect(unknown.active_session().backend_id, content="fixture")
  inspect(unknown.last_status, content="Agent backend unavailable")
}

///|
test "workbench fixture backend ignores stale Pi transport events" {
  let model = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .update(SwitchAgentBackend("fixture"))
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"Stale Pi reply"}]}],"willRetry":false}
          ),
        ),
      ),
    )
    .update(ReceiveTransport(ProcessStderr("moui-skia", "stale stderr")))
  inspect(model.active_session().backend_id, content="fixture")
  inspect(model.last_status, content="Agent backend switched: 本地")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Disconnected")
  inspect(model.transport.last_json_line, content="")
  inspect(model.transcript.length(), content="0")
  inspect(model.diagnostics.length(), content="0")
  assert_false(model.events.any(event => event.detail.contains("Stale Pi")))
  assert_false(model.events.any(event => event.title.contains("Pi stderr")))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Agent 本地"))
  assert_false(has_text(commands, "Stale Pi reply"))
  assert_false(has_text(commands, "stale stderr"))
  assert_false(has_text(commands, "当前证据"))
}

///|
test "workbench fixture backend ignores stale Pi refresh effects" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .update(SwitchAgentBackend("fixture"))
    .update_with_transport(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"prompt","success":true}
          ),
        ),
      ),
      transport,
    )
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="0")
  inspect(model.active_session().backend_id, content="fixture")
  inspect(model.last_status, content="Agent backend switched: 本地")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Disconnected")
  assert_false(
    model.events.any(event => event.title == "Pi transcript refresh queued"),
  )
}

///|
test "workbench backend switch event does not create evidence chrome" {
  let model = WorkbenchModel::new().update(SwitchAgentBackend("fixture"))
  assert_true(
    model.events.any(event => event.title == "Agent backend switched"),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Agent 本地"))
  assert_false(has_text(commands, "Agent backend switched"))
  assert_false(has_text(commands, "当前证据"))
}

///|
test "workbench fixture backend keeps prompt flow local" {
  let model = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(PromptChanged("Sketch the clean UI"))
    .update(DispatchPrompt)
  inspect(model.active_session().backend_id, content="fixture")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transcript.length(), content="2")
  inspect(model.transcript[0].role, content="user")
  inspect(model.transcript[1].role, content="assistant")
  inspect(model.transcript[1].summary, content="本地 已接收任务")
  inspect(
    model.transcript[1].detail,
    content="本地后端会保持会话流转，不启动外部传输。",
  )
  inspect(model.last_status, content="已交给本地后端")
}

fn model_with_reviewable_diff() -> WorkbenchModel {
  {
    ..WorkbenchModel::new(),
    diff: DiffOverview::new(
      changed_files=5,
      additions=160,
      deletions=10,
      status="ready for review",
    ),
  }
}

///|
fn model_with_overflowing_transcript() -> WorkbenchModel {
  let transcript : Array[TranscriptItem] = []
  for index in 0..<8 {
    transcript.push(
      TranscriptItem::new(
        id="overflow-" + index.to_string(),
        role=if index % 2 == 0 { "assistant" } else { "user" },
        summary="Overflow transcript " + index.to_string(),
        detail=long_assistant_reply(),
        tone=if index % 2 == 0 { "success" } else { "info" },
      ),
    )
  }
  { ..WorkbenchModel::new(), transcript, }
}

///|
fn long_assistant_reply() -> String {
  "Pi reply block alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau " +
  "Pi reply block alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau " +
  "Pi reply block alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
}

///|
fn context_task_payload(task : String) -> String {
  "Context: repo, examples\n\nTask: " + task
}

///|
fn agent_context_task_payload(task : String) -> String {
  "Context: repo, examples, agent focus: coding implementation, focused tests, and refactors\n\nTask: " +
  task
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}

///|
fn draw_text_count(commands : Array[@core.DrawCommand], text : String) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      DrawText({ text: value, .. }) => if value == text { count = count + 1 }
      _ => ()
    }
  }
  count
}

///|
fn draw_text_total(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      DrawText(_) => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn draw_solid_fill_count(
  commands : Array[@core.DrawCommand],
  color : @core.Color,
) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      Clear(value) | FillRect(_, value) | FillRoundedRect(_, value) =>
        if value == color {
          count = count + 1
        }
      FillRoundedRectBrush(_, @core.Brush::Solid(value)) =>
        if value == color {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn test_workbench_app_background(scheme : @core.ColorScheme) -> @core.Color {
  match scheme {
    @core.ColorScheme::Light => test_ui_color(0.965, 0.966, 0.958)
    @core.ColorScheme::Dark => test_ui_color(0.055, 0.060, 0.070)
  }
}

///|
fn test_workbench_sidebar_background(scheme : @core.ColorScheme) -> @core.Color {
  match scheme {
    @core.ColorScheme::Light => test_ui_color(0.905, 0.910, 0.905)
    @core.ColorScheme::Dark => test_ui_color(0.075, 0.080, 0.092)
  }
}

///|
fn test_workbench_main_background(scheme : @core.ColorScheme) -> @core.Color {
  match scheme {
    @core.ColorScheme::Light => test_ui_color(0.975, 0.976, 0.968)
    @core.ColorScheme::Dark => test_ui_color(0.062, 0.067, 0.078)
  }
}

///|
fn test_workbench_panel_background(scheme : @core.ColorScheme) -> @core.Color {
  match scheme {
    @core.ColorScheme::Light => test_ui_color(0.992, 0.993, 0.988)
    @core.ColorScheme::Dark => test_ui_color(0.105, 0.112, 0.128)
  }
}

///|
fn test_workbench_status_bar_background(
  scheme : @core.ColorScheme,
) -> @core.Color {
  match scheme {
    @core.ColorScheme::Light => test_ui_color(0.910, 0.918, 0.912)
    @core.ColorScheme::Dark => test_ui_color(0.083, 0.089, 0.102)
  }
}

///|
fn test_ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}

///|
fn draw_text_count_containing(
  commands : Array[@core.DrawCommand],
  needle : String,
) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      DrawText({ text, .. }) => if text.contains(needle) { count = count + 1 }
      _ => ()
    }
  }
  count
}

///|
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text to click: " + text)
  }
  let point = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn fork_affordance_follows_text(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  guard text_frame(commands, text) is Some(anchor) else { return false }
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == "分叉" && frame.origin.y > anchor.origin.y {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn main_scrollbar_thumb_frame(
  commands : Array[@core.DrawCommand],
) -> @core.Rect? {
  let mut thumb : @core.Rect? = None
  for command in commands {
    match command {
      FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width == 4.0 && rect.size.height >= 36.0 {
          match thumb {
            Some(current) =>
              if rect.size.height < current.size.height {
                thumb = Some(rect)
              }
            None => thumb = Some(rect)
          }
        }
      _ => ()
    }
  }
  thumb
}

///|
fn first_surface_frame(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      FillRoundedRectBrush({ rect, .. }, _) => return Some(rect)
      FillRoundedRect({ rect, .. }, _) => return Some(rect)
      FillRect(rect, _) => return Some(rect)
      _ => ()
    }
  }
  None
}

///|
fn run_workbench_effect(update : WorkbenchUpdate) -> WorkbenchModel {
  let model = @core.State::new(update.model)
  let dispatch = message => model.set(model.get().update(message))
  match update.effect {
    NoEffect => ()
    Batch(effects) =>
      for effect in effects {
        let next = run_workbench_effect(
          WorkbenchUpdate::new(model.get(), effect~),
        )
        model.set(next)
      }
    Send(message) => dispatch(message)
    Dispatch(run) => run(dispatch)
    Run(_descriptor, run) => run(dispatch)
    Task(_descriptor, start) => ignore(start(dispatch))
  }
  model.get()
}

///|
fn run_workbench_effect_with_transport(
  update : WorkbenchUpdate,
  transport : PiTransportRuntime,
) -> WorkbenchModel {
  let model = @core.State::new(update.model)
  fn dispatch(message : WorkbenchMsg) -> Unit {
    let next = model.get().update_with_transport(message, transport)
    model.set(next.model)
    let chained = run_workbench_effect_with_transport(
      WorkbenchUpdate::new(model.get(), effect=next.effect),
      transport,
    )
    model.set(chained)
  }
  match update.effect {
    NoEffect => ()
    Batch(effects) =>
      for effect in effects {
        let next = run_workbench_effect_with_transport(
          WorkbenchUpdate::new(model.get(), effect~),
          transport,
        )
        model.set(next)
      }
    Send(message) => dispatch(message)
    Dispatch(run) => run(dispatch)
    Run(_descriptor, run) => run(dispatch)
    Task(_descriptor, start) => ignore(start(dispatch))
  }
  model.get()
}

///|
fn run_workbench_effect_with_agent_connectors(
  update : WorkbenchUpdate,
  transport : PiTransportRuntime,
  connectors : Array[AgentConnectorRuntime],
) -> WorkbenchModel {
  let model = @core.State::new(update.model)
  fn dispatch(message : WorkbenchMsg) -> Unit {
    let next = model
      .get()
      .update_with_agent_connectors(message, transport, connectors)
    model.set(next.model)
    let chained = run_workbench_effect_with_agent_connectors(
      WorkbenchUpdate::new(model.get(), effect=next.effect),
      transport,
      connectors,
    )
    model.set(chained)
  }
  match update.effect {
    NoEffect => ()
    Batch(effects) =>
      for effect in effects {
        let next = run_workbench_effect_with_agent_connectors(
          WorkbenchUpdate::new(model.get(), effect~),
          transport,
          connectors,
        )
        model.set(next)
      }
    Send(message) => dispatch(message)
    Dispatch(run) => run(dispatch)
    Run(_descriptor, run) => run(dispatch)
    Task(_descriptor, start) => ignore(start(dispatch))
  }
  model.get()
}
