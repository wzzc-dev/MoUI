///|
test "workbench ingests Pi RPC get_state response jsonl" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"thinkingLevel":"medium","steeringMode":"all","followUpMode":"one-at-a-time","sessionId":"019e7eb5","messageCount":4,"pendingMessageCount":1}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_state")
  inspect(model.pi_rpc.success, content="true")
  inspect(model.pi_rpc.session_id, content="019e7eb5")
  inspect(model.pi_rpc.session_file, content="")
  inspect(model.pi_rpc.session_name, content="")
  inspect(model.pi_rpc.model, content="openai/gpt-5")
  inspect(model.pi_rpc.thinking_level, content="medium")
  inspect(model.pi_rpc.steering_mode, content="all")
  inspect(model.pi_rpc.follow_up_mode, content="one-at-a-time")
  inspect(model.pi_rpc.message_count, content="4")
  inspect(model.pi_rpc.pending_message_count, content="1")
  let session = model.active_session()
  inspect(session.status, content="running")
  inspect(session.unread_events, content="1")
  inspect(session.summary, content="Agent session 019e7eb5 on openai/gpt-5")
  let binding = model.active_pi_session_binding()
  inspect(binding.workbench_session_id, content="moui-skia")
  inspect(binding.rpc_session_id, content="019e7eb5")
  inspect(binding.status, content="bound")
  inspect(model.pi_agent.thinking_level, content="medium")
  inspect(model.pi_agent.steering_mode, content="all")
  inspect(model.pi_agent.follow_up_mode, content="one-at-a-time")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(
    model.events.any(event => event.title == "Pi RPC response: get_state"),
  )
}

///|
test "workbench ingests Pi RPC get_messages response into transcript" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","role":"user","content":"Inspect the Skia route","timestamp":1},{"entryId":"entry-assistant-1","role":"assistant","content":[{"type":"text","text":"Skia route inspected"}],"model":"gpt-5","timestamp":2},{"entryId":"entry-bash-1","role":"bashExecution","command":"moon check","output":"ok","exitCode":0,"cancelled":false,"truncated":false,"timestamp":3}]}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_messages")
  inspect(model.pi_rpc.message_count, content="3")
  inspect(model.transcript.length(), content="3")
  inspect(model.transcript[0].id, content="entry-user-1")
  inspect(model.transcript[0].role, content="user")
  inspect(model.transcript[0].summary, content="Inspect the Skia route")
  inspect(model.transcript[1].id, content="entry-assistant-1")
  inspect(model.transcript[1].role, content="assistant")
  inspect(model.transcript[1].detail, content="Skia route inspected")
  inspect(model.transcript[2].role, content="bashExecution")
  inspect(model.transcript[2].summary, content="moon check")
  inspect(model.transcript[2].detail, content="exit code 0 - ok")
  inspect(model.last_status, content="Pi messages refreshed")
  assert_true(model.events.any(event => event.title == "Pi messages refreshed"))
}

///|
test "workbench runtime draws transcript follow-up action after Pi messages" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_messages","success":true,"data":{"messages":[{"role":"user","content":"Inspect the Skia route","timestamp":1},{"role":"assistant","content":[{"type":"text","text":"Skia route inspected"}],"model":"gpt-5","timestamp":2}]}}
        ),
      ),
    ),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_false(has_text(commands, "会话记录"))
  assert_true(has_text(commands, "Inspect the Skia route"))
  assert_true(has_text(commands, "Skia route inspected"))
  assert_false(has_text(commands, "跟进"))
}

///|
test "workbench ingests Pi RPC get_commands response into command catalog" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_commands","success":true,"data":{"commands":[{"name":"review","description":"Review current diff","source":"prompt","sourceInfo":{"path":".pi/prompts/review.md","source":"project","scope":"project","origin":"top-level"}},{"name":"skill:moonbit-agent-guide","description":"Use MoonBit conventions","source":"skill","sourceInfo":{"path":"skills/moonbit-agent-guide/SKILL.md","source":"user","scope":"user","origin":"top-level"}}]}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_commands")
  inspect(model.command_catalog.length(), content="2")
  inspect(model.command_catalog[0].name, content="review")
  inspect(model.command_catalog[0].source, content="prompt")
  inspect(model.command_catalog[0].description, content="Review current diff")
  inspect(model.command_catalog[0].source_scope, content="project")
  inspect(model.command_catalog[0].source_path, content=".pi/prompts/review.md")
  inspect(model.command_catalog[1].name, content="skill:moonbit-agent-guide")
  inspect(model.command_catalog[1].source, content="skill")
  inspect(model.command_catalog[1].source_scope, content="user")
  inspect(model.last_status, content="Pi commands refreshed")
  assert_true(model.events.any(event => event.title == "Pi commands refreshed"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_false(has_text(commands, "命令"))
  assert_false(has_text(commands, "/review"))
  assert_false(draw_text_count_containing(commands, "/skill:moonbit") > 0)
  assert_false(has_text(commands, "运行可用命令"))
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "首帧"))
  let slash_commands = model
    .update(PromptChanged("/"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(slash_commands, "命令"))
  assert_true(draw_text_count_containing(slash_commands, "/review") > 0)
  assert_true(draw_text_count_containing(slash_commands, "/skill:moonbit") > 0)
  let filtered_commands = model
    .update(PromptChanged("/skill"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(filtered_commands, "命令"))
  assert_true(
    draw_text_count_containing(filtered_commands, "/skill:moonbit") > 0,
  )
}

///|
test "workbench projects Pi command catalog entries through agent-neutral contract" {
  let pi_command = PiCommandInfo::new(
    name="review",
    source="prompt",
    description="Review current diff",
    source_scope="project",
    source_path=".pi/prompts/review.md",
  )
  let command = pi_command.as_agent_command_info()
  inspect(command.name, content="review")
  inspect(command.source, content="prompt")
  inspect(command.description, content="Review current diff")
  inspect(command.source_scope, content="project")
  inspect(command.source_path, content=".pi/prompts/review.md")
}

///|
test "workbench slash composer hides context and steering controls" {
  let model = {
    ..WorkbenchModel::new(),
    prompt: "/",
    command_catalog: [
      PiCommandInfo::new(
        name="review",
        source="prompt",
        description="Review current diff",
        source_scope="project",
        source_path=".pi/prompts/review.md",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "命令"))
  assert_true(draw_text_count_containing(commands, "/review") > 0)
  assert_true(has_text(commands, "发送"))
  assert_true(has_text(commands, "上下文"))
  assert_false(has_text(commands, "焦点"))
  assert_false(has_text(commands, "引导"))
  assert_false(has_text(commands, "跟进"))
}

///|
test "workbench ingests Pi RPC get_available_models response into model catalog" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_available_models","success":true,"data":{"models":[{"provider":"openai","id":"gpt-5","name":"GPT-5"},{"provider":"anthropic","id":"claude-sonnet-4.5","name":"Claude Sonnet 4.5"}]}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_available_models")
  inspect(model.model_catalog.length(), content="2")
  inspect(model.model_catalog[0].provider, content="openai")
  inspect(model.model_catalog[0].id, content="gpt-5")
  inspect(model.model_catalog[0].name, content="GPT-5")
  inspect(model.model_catalog[0].label, content="GPT-5 (openai/gpt-5)")
  inspect(
    model.model_catalog[1].label,
    content="Claude Sonnet 4.5 (anthropic/claude-sonnet-4.5)",
  )
  inspect(model.last_status, content="Pi models refreshed")
  assert_true(model.events.any(event => event.title == "Pi models refreshed"))
}

///|
test "workbench runtime draws Pi model catalog summary after refresh" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_available_models","success":true,"data":{"models":[{"provider":"openai","id":"gpt-5","name":"GPT-5"},{"provider":"anthropic","id":"claude-sonnet-4.5","name":"Claude Sonnet 4.5"}]}}
          ),
        ),
      ),
    )
    .update(ToggleComposerControls)
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "模型 2"))
  assert_true(has_text(commands, "GPT-5 (openai/gpt-5) +1"))
  assert_true(has_text(commands, "使用"))
  assert_true(has_text(commands, "切换"))
}

///|
test "workbench sets visible Pi model through platform-neutral transport" {
  let model = WorkbenchModel::new().update(
    SetModel("openai", "gpt-5", "GPT-5 (openai/gpt-5)"),
  )
  inspect(model.last_status, content="Pi model set queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    SetRpcModel(session, provider, id) => {
      inspect(session, content="moui-skia")
      inspect(provider, content="openai")
      inspect(id, content="gpt-5")
    }
    _ => fail("expected queued model set")
  }
  assert_true(model.events.any(event => event.title == "Pi model set queued"))
}

///|
test "workbench set model runtime effect updates active Pi binding" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"set_model\",\"provider\":\"openai\",\"modelId\":\"gpt-5\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"set_model","success":true,"data":{"id":"gpt-5","provider":"openai","name":"GPT-5"}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    SetModel("openai", "gpt-5", "GPT-5 (openai/gpt-5)"),
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SetRpcModel(session, provider, id) => {
      inspect(session, content="moui-skia")
      inspect(provider, content="openai")
      inspect(id, content="gpt-5")
    }
    _ => fail("expected captured model set")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="set_model")
  inspect(model.pi_rpc.model, content="GPT-5 (openai/gpt-5)")
  let binding = model.active_pi_session_binding()
  inspect(binding.model, content="GPT-5 (openai/gpt-5)")
  inspect(binding.last_command, content="set_model")
  inspect(
    model.active_session().active_task,
    content="模型：GPT-5 (openai/gpt-5)",
  )
  inspect(
    model.active_session().summary,
    content="模型已设为 GPT-5 (openai/gpt-5)",
  )
  inspect(model.last_status, content="Pi model set")
  assert_true(model.events.any(event => event.title == "Pi model set"))
}

///|
test "workbench queues Pi model cycle through platform-neutral transport" {
  let model = WorkbenchModel::new().update(CycleModel)
  inspect(model.last_status, content="Pi model cycle queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    CycleRpcModel(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued model cycle")
  }
  assert_true(model.events.any(event => event.title == "Pi model cycle queued"))
}

///|
test "workbench model cycle runtime effect updates active Pi binding" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"cycle_model\"}"))
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"cycle_model","success":true,"data":{"model":{"id":"gpt-5","provider":"openai","name":"GPT-5"},"thinkingLevel":"high","isScoped":true}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    CycleModel,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    CycleRpcModel(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured model cycle")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="cycle_model")
  inspect(model.pi_rpc.model, content="openai/gpt-5")
  inspect(model.pi_agent.thinking_level, content="high")
  let binding = model.active_pi_session_binding()
  inspect(binding.model, content="openai/gpt-5")
  inspect(binding.last_command, content="cycle_model")
  inspect(model.active_session().active_task, content="模型：openai/gpt-5")
  inspect(
    model.active_session().summary,
    content="模型已切换为 openai/gpt-5",
  )
  inspect(model.last_status, content="Pi model changed")
  assert_true(model.events.any(event => event.title == "Pi model cycled"))
}

///|
test "workbench model cycle acknowledges unavailable alternate model" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"cycle_model","success":true,"data":null}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="cycle_model")
  inspect(model.active_pi_session_binding().model, content="")
  inspect(model.last_status, content="Pi model cycle acknowledged")
  assert_true(model.events.any(event => event.title == "Pi model cycled"))
}

///|
test "workbench compacts Pi context through platform-neutral transport" {
  let model = WorkbenchModel::new().update(CompactSession)
  inspect(model.last_status, content="Pi compact queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    CompactRpcSession(session, instructions) => {
      inspect(session, content="moui-skia")
      inspect(instructions, content="")
    }
    _ => fail("expected queued compact")
  }
  assert_true(model.events.any(event => event.title == "Pi compact queued"))
}

///|
test "workbench compact runtime effect records compaction summary" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"compact\"}"))
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"compact","success":true,"data":{"summary":"Renderer route summarized","firstKeptEntryId":"entry-7","tokensBefore":42000}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    CompactSession,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    CompactRpcSession(session, instructions) => {
      inspect(session, content="moui-skia")
      inspect(instructions, content="")
    }
    _ => fail("expected captured compact")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="compact")
  inspect(model.active_session().active_task, content="上下文已压缩")
  inspect(
    model.active_session().summary,
    content="Pi compacted context from 42000 tokens",
  )
  inspect(model.transcript.length(), content="1")
  inspect(model.transcript[0].id, content="pi-compact-entry-7")
  inspect(model.transcript[0].role, content="compactionSummary")
  inspect(model.transcript[0].detail, content="Renderer route summarized")
  inspect(model.active_pi_session_binding().last_command, content="compact")
  inspect(model.last_status, content="Pi context compacted")
  assert_true(model.events.any(event => event.title == "Pi context compacted"))
}
