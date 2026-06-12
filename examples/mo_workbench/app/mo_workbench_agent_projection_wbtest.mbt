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
