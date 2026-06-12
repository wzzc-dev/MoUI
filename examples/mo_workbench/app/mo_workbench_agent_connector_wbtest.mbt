///|
test "workbench ACP connector backend queues prompt through connector runtime" {
  let connector = AgentConnectorRuntime::fixture(backend_id="acp-demo")
  let update = WorkbenchModel::new()
    .update(SwitchAgentBackend("acp-demo"))
    .update(PromptChanged("Check ACP connector shape"))
    .update_with_agent_connectors(
      DispatchPrompt,
      PiTransportRuntime::unavailable(),
      [connector],
    )
  inspect(update.model.active_session().backend_id, content="acp-demo")
  inspect(update.model.pending_transport_count(), content="2")
  inspect(update.model.transport.command_queue.length(), content="0")
  inspect(update.model.transcript.length(), content="1")
  inspect(update.model.transcript[0].role, content="user")
  inspect(update.model.last_status, content="Queued prompt for Agent connector")
  let summary = update.effect.plan_summary()
  inspect(summary.descriptors.length(), content="1")
  inspect(
    summary.descriptors[0].key,
    content="agent-connector:acp-demo:dispatch",
  )
  inspect(summary.descriptors[0].kind, content="agent-connector")
  let model = run_workbench_effect_with_agent_connectors(
    update,
    PiTransportRuntime::unavailable(),
    [connector],
  )
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transcript.length(), content="2")
  inspect(model.transcript[1].summary, content="ACP Demo 已接收任务")
  let binding = model.active_agent_session_binding()
  inspect(binding.backend_id, content="acp-demo")
  inspect(binding.provider_session_id, content="acp-fixture:moui-skia")
  inspect(binding.session_name, content="ACP Demo session")
  inspect(binding.model, content="acp-fixture")
  inspect(model.active_agent_session_metrics().total_messages, content="1")
}

///|
test "workbench ACP connector unavailable runtime reports failure without Pi queue" {
  let connector = AgentConnectorRuntime::unavailable(
    backend_id="acp-demo",
    reason="ACP runtime not configured",
  )
  let update = WorkbenchModel::new()
    .update(SwitchAgentBackend("acp-demo"))
    .update(PromptChanged("Try unavailable connector"))
    .update_with_agent_connectors(
      DispatchPrompt,
      PiTransportRuntime::unavailable(),
      [connector],
    )
  inspect(update.model.pending_transport_count(), content="2")
  inspect(update.model.transport.command_queue.length(), content="0")
  inspect(update.effect.plan_summary().descriptors.length(), content="1")
  let model = run_workbench_effect_with_agent_connectors(
    update,
    PiTransportRuntime::unavailable(),
    [connector],
  )
  inspect(model.pending_transport_count(), content="0")
  inspect(model.last_status, content="Agent connector failed")
  inspect(model.diagnostics.length(), content="1")
  inspect(model.diagnostics[0].source, content="Agent connector acp-demo")
  inspect(model.diagnostics[0].message, content="ACP runtime not configured")
  let status = model.active_agent_backend_status()
  inspect(status.failed, content="true")
  inspect(status.status_label, content="失败：ACP runtime not configured")
}

///|
test "workbench ACP connector exposes neutral provider and composer projections" {
  let model = WorkbenchModel::new()
    .update(SwitchAgentBackend("acp-demo"))
    .update(PromptChanged("Use connector context"))
  let registry = model.agent_provider_registry_items()
  inspect(registry.length(), content="3")
  inspect(registry[1].backend_id, content="acp-demo")
  inspect(registry[1].transport_label, content="acp connector")
  inspect(registry[1].active, content="true")
  inspect(model.agent_provider_switch_summary().backend_id, content="acp-demo")
  inspect(
    model.agent_provider_switch_summary().capability_label,
    content="session · commands",
  )
  let route = model.agent_composer_route_summary()
  inspect(route.backend_id, content="acp-demo")
  inspect(route.visible, content="true")
  assert_true(route.detail.contains("ACP Demo"))
  assert_true(route.detail.contains("仓库"))
  let commands = model.active_agent_command_catalog()
  inspect(commands.length(), content="3")
  inspect(commands[0].name, content="profile")
  inspect(commands[0].source_path, content="agentprofile.json")
  let status = model.agent_status_bar_summary()
  inspect(status.backend_id, content="acp-demo")
  inspect(status.context_label, content="")
}

///|
test "workbench ACP connector events project activity request and timeline state" {
  let model = WorkbenchModel::new()
    .update(SwitchAgentBackend("acp-demo"))
    .update(
      ReceiveConnector(
        ConnectorProfileLoaded("acp-demo", AgentConnectorProfile::acp_demo()),
      ),
    )
    .update(
      ReceiveConnector(
        ConnectorAssistantMessage(
          "acp-demo", "ACP fixture reply", "Connector message detail",
        ),
      ),
    )
  inspect(model.transcript.length(), content="1")
  inspect(model.transcript[0].summary, content="ACP fixture reply")
  let signal = model.active_agent_runtime_signal()
  inspect(signal.backend_id, content="acp-demo")
  inspect(signal.status_label, content="运行中")
  inspect(signal.message_preview, content="ACP fixture reply")
  let activity = model.agent_activity_queue()
  inspect(activity.length(), content="1")
  assert_true(activity[0].kind is RuntimeActivity)
  let timeline = model.agent_timeline_items()
  assert_true(
    timeline.any(item => item.title.contains("Agent connector profile loaded")),
  )
  assert_true(timeline.any(item => item.title == "ACP fixture reply"))
}

///|
test "workbench fixture backend keeps evidence prompts local" {
  let transcript = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(FollowTranscript("assistant", "Clean UI", "Use quiet chrome"))
  assert_fixture_prompt_action_stays_local(
    transcript,
    event_title="Transcript follow-up queued",
  )

  let activity = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(FollowActivity("assistant", "Plan ready", "Keep the shell calm"))
  assert_fixture_prompt_action_stays_local(
    activity,
    event_title="Activity follow-up queued",
  )

  let file = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(InspectFile("examples/mo_workbench/app/app.mbt"))
  assert_fixture_prompt_action_stays_local(
    file,
    event_title="File context queued",
  )

  let diff = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    diff: DiffOverview::new(
      changed_files=5,
      additions=160,
      deletions=10,
      status="ready for review",
    ),
  }.update(ReviewDiff)
  assert_fixture_prompt_action_stays_local(
    diff,
    event_title="Diff review queued",
  )

  let diagnostic = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(FixDiagnostic("moon check", "error", "unused variable"))
  assert_fixture_prompt_action_stays_local(
    diagnostic,
    event_title="Diagnostic fix queued",
  )

  let command_evidence = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(
      InspectCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"),
    )
  assert_fixture_prompt_action_stays_local(
    command_evidence,
    event_title="Command evidence queued",
  )

  let command_fix = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(FixCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"))
  assert_fixture_prompt_action_stays_local(
    command_fix,
    event_title="Command fix queued",
  )
}

///|
test "workbench fixture backend rejects Pi-only direct actions" {
  let model = WorkbenchModel::new().update(SwitchAgentBackend("fixture"))
  let command = model.update(InvokeCommand("review"))
  inspect(command.pending_transport_count(), content="0")
  inspect(
    command.last_status,
    content="Agent backend does not support commands",
  )
  let shell = model.update(QueueCommand("moon check"))
  inspect(shell.commands.length(), content="0")
  inspect(shell.pending_transport_count(), content="0")
  inspect(
    shell.last_status,
    content="Agent backend does not support shell commands",
  )
  let model_select = model.update(SetModel("openai", "gpt-5", "GPT-5"))
  inspect(model_select.pending_transport_count(), content="0")
  inspect(
    model_select.last_status,
    content="Agent backend does not support model selection",
  )
  let thinking = model.update(CycleThinkingLevel)
  inspect(thinking.pending_transport_count(), content="0")
  inspect(
    thinking.last_status,
    content="Agent backend does not support thinking level",
  )
}

///|
fn assert_fixture_prompt_action_stays_local(
  model : WorkbenchModel,
  event_title~ : String,
) -> Unit raise {
  inspect(model.active_session().backend_id, content="fixture")
  inspect(model.last_status, content="已交给本地后端")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transcript.length(), content="2")
  inspect(model.transcript[0].role, content="user")
  inspect(model.transcript[1].role, content="assistant")
  inspect(model.transcript[1].summary, content="本地 已接收任务")
  assert_true(model.events.any(event => event.title == event_title))
}
