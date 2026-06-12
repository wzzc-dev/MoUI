///|
test "workbench selection with transport switches Pi session then refreshes state, models, fork points, commands, and stats" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new()
    .update(PromptChanged("stale Pi task"))
    .update(DispatchPrompt)
    .update(ReceiveTransport(ProcessStarted("4242")))
    .update_with_transport(SelectSession("pi-rpc"), transport)
  inspect(update.model.selected_session_id, content="pi-rpc")
  inspect(update.model.pending_transport_count(), content="7")
  inspect(update.model.prompt, content="")
  inspect(update.model.transcript.length(), content="0")
  inspect(update.model.events.length(), content="0")
  inspect(update.model.transport.last_json_line, content="")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="7")
  match captured.val[0] {
    SwitchRpcSession(session, path) => {
      inspect(session, content="pi-rpc")
      inspect(path, content="/tmp/mo-workbench-pi-rpc-session.jsonl")
    }
    _ => fail("expected queued Pi session switch")
  }
  match captured.val[1] {
    StartRpc(session, cwd) => {
      inspect(session, content="pi-rpc")
      inspect(cwd, content="/Volumes/Data/Code/moon/pi")
    }
    _ => fail("expected queued state refresh")
  }
  match captured.val[2] {
    FetchRpcAvailableModels(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued model catalog refresh")
  }
  match captured.val[3] {
    FetchRpcMessages(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued message refresh")
  }
  match captured.val[4] {
    FetchRpcForkMessages(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued fork messages refresh")
  }
  match captured.val[5] {
    FetchRpcCommands(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued command catalog refresh")
  }
  match captured.val[6] {
    FetchRpcSessionStats(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued session stats refresh")
  }
  inspect(model.selected_session_id, content="pi-rpc")
}

///|
test "workbench selecting fixture session clears stale Pi surface without transport" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let stale = {
      ..WorkbenchModel::new(),
      selected_session_id: "pi-live",
      sessions: [
        WorkbenchSession::new(
          id="pi-live",
          title="Pi live task",
          project_path="/repo/pi",
          branch="main",
          status="active",
          summary="Old Pi run",
          active_task="",
          unread_events=0,
        ),
        WorkbenchSession::new(
          id="local-clean",
          title="Local clean task",
          project_path="/repo/local",
          backend_id="fixture",
          branch="local",
          status="idle",
          summary="Quiet local session",
          active_task="",
          unread_events=0,
        ),
      ],
    }
    .update(PromptChanged("Old Pi prompt"))
    .update(DispatchPrompt)
    .update(ReceiveTransport(ProcessStarted("4242")))
    .update(QueueCommand("moon check"))
  let update = stale.update_with_transport(
    SelectSession("local-clean"),
    transport,
  )
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="0")
  inspect(model.selected_session_id, content="local-clean")
  inspect(model.active_agent_backend_profile().label, content="本地")
  inspect(model.last_status, content="Workbench session selected")
  inspect(model.prompt, content="")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Disconnected")
  inspect(model.transport.last_json_line, content="")
  inspect(model.transcript.length(), content="0")
  inspect(model.events.length(), content="0")
  inspect(model.commands.length(), content="0")
  inspect(model.diagnostics.length(), content="0")
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Agent 本地"))
  assert_true(has_text(commands, "Local clean task"))
  assert_false(has_text(commands, "Old Pi prompt"))
  assert_false(has_text(commands, "Pi RPC process started"))
  assert_false(has_text(commands, "moon check"))
  assert_false(has_text(commands, "当前证据"))
}

///|
test "workbench applies transport events to model timeline" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(ProcessStarted("4242")),
  )
  inspect(model.transport.status_label(), content="Running")
  inspect(model.transport.last_json_line, content="pid 4242")
  assert_true(
    model.events.any(event => event.title == "Pi RPC process started"),
  )
}

///|
test "workbench runtime keeps raw transport activity out of current evidence" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(ProcessStarted("4242")),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前任务"))
  assert_true(has_text(commands, "Agent：运行中"))
  assert_false(has_text(commands, "当前证据"))
  assert_false(has_text(commands, "Pi RPC process started"))
  assert_false(has_text(commands, "pid 4242"))
  assert_false(has_text(commands, "通道：运行中"))
  assert_false(has_text(commands, "跟进"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "工作区证据"))
}

///|
test "workbench surfaces Pi stderr as diagnostics" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(ProcessStderr("moui-skia", "permission denied")),
  )
  inspect(model.transport.last_json_line, content="stderr: permission denied")
  inspect(model.last_status, content="Pi stderr received")
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="Pi stderr")
  inspect(diagnostic.severity, content="warning")
  inspect(diagnostic.message, content="moui-skia: permission denied")
  assert_true(model.events.any(event => event.title == "Pi stderr: moui-skia"))
}

///|
test "workbench ingests structured Pi command jsonl" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"command_started","id":9,"command":"moon check","cwd":"/repo","status":"running"}
        ),
      ),
    ),
  )
  let command = model.commands[model.commands.length() - 1]
  inspect(command.id, content="9")
  inspect(command.command, content="moon check")
  inspect(command.cwd, content="/repo")
  inspect(command.status, content="running")
  inspect(model.last_status, content="Pi command update applied")
  assert_true(
    model.events.any(event => event.title == "Command started: moon check"),
  )
}

///|
test "workbench ingests Pi diagnostics files and diff jsonl" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"diagnostic","source":"moon check","severity":"error","message":"unused variable in app.mbt"}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"file_context","id":"jsonl","path":"examples/mo_workbench/app/pi_jsonl_ingest.mbt","summary":"Structured Pi event ingestion","change_kind":"added","lines_changed":140}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"diff_summary","changed_files":6,"additions":180,"deletions":12,"status":"requires_review"}
          ),
        ),
      ),
    )
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="moon check")
  inspect(diagnostic.severity, content="error")
  inspect(diagnostic.message, content="unused variable in app.mbt")
  let file = model.files[model.files.length() - 1]
  inspect(file.path, content="examples/mo_workbench/app/pi_jsonl_ingest.mbt")
  inspect(file.change_kind, content="added")
  inspect(file.lines_changed, content="140")
  inspect(model.diff.changed_files, content="6")
  inspect(model.diff.additions, content="180")
  inspect(model.diff.deletions, content="12")
  inspect(model.last_status, content="Pi diff summary applied")
  assert_true(model.events.any(event => event.title == "Diff summary updated"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "清除"))
  assert_true(has_text(commands, "修复"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "unused variable in app.mbt"))
  assert_false(has_text(commands, "工作区证据"))
}

///|
test "workbench ingests Pi approval request as waiting intervention" {
  let seed = WorkbenchModel::new()
  let initial_unread = seed.active_session().unread_events
  let model = seed.update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"approval_required","reason":"Run shell command","command":"moon test examples/mo_workbench/app --target native"}
        ),
      ),
    ),
  )
  inspect(model.active_session().status, content="waiting")
  inspect(model.active_session().active_task, content="等待用户批准")
  inspect(
    model.active_session().summary,
    content="等待用户处理 Agent 请求",
  )
  inspect(model.active_session().unread_events - initial_unread, content="1")
  inspect(model.pi_agent.phase, content="waiting")
  inspect(
    model.pi_agent.message_preview,
    content="Run shell command · moon test examples/mo_workbench/app --target native",
  )
  inspect(model.last_status, content="Pi agent intervention required")
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="Agent approval")
  inspect(diagnostic.severity, content="warning")
  inspect(
    diagnostic.message,
    content="Run shell command · moon test examples/mo_workbench/app --target native",
  )
  assert_true(model.events.any(event => event.title == "Pi approval required"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "等待"))
  assert_true(has_text(commands, "等待用户批准"))
  assert_true(has_text(commands, "处理 Agent 请求"))
  assert_true(
    has_text(
      commands, "Agent approval: Run shell command · moon test examples/mo_workbench/app --target native",
    ),
  )
  assert_true(has_text(commands, "处理"))
  assert_true(has_text(commands, "清除"))

  let queued = model.update(
    FixDiagnostic(diagnostic.source, diagnostic.severity, diagnostic.message),
  )
  inspect(queued.last_status, content="Queued diagnostic fix for Pi RPC")
  match queued.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Resolve Agent approval request: Run shell command · moon test examples/mo_workbench/app --target native",
        ),
      )
    }
    _ => fail("expected queued intervention prompt")
  }
}

///|
test "workbench maps Pi permission and input intervention labels" {
  let seed = WorkbenchModel::new()
  let initial_unread = seed.active_session().unread_events
  let permission = seed.update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"permission_required","data":{"message":"Write access needs confirmation","path":"examples/mo_workbench/app/app.mbt"}}
        ),
      ),
    ),
  )
  inspect(permission.active_session().status, content="waiting")
  inspect(permission.active_session().active_task, content="等待权限确认")
  inspect(
    permission.active_session().unread_events - initial_unread,
    content="1",
  )
  let permission_diagnostic_index = permission.diagnostics.length() - 1
  let permission_diagnostic = permission.diagnostics[permission_diagnostic_index]
  inspect(permission_diagnostic.source, content="Agent permission")
  inspect(
    permission_diagnostic.message,
    content="Write access needs confirmation · examples/mo_workbench/app/app.mbt",
  )

  let input = permission.update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"input_required","prompt":"Choose a branch name"}
        ),
      ),
    ),
  )
  inspect(input.active_session().status, content="waiting")
  inspect(input.active_session().active_task, content="等待用户输入")
  inspect(input.active_session().unread_events - initial_unread, content="2")
  let input_diagnostic = input.diagnostics[input.diagnostics.length() - 1]
  inspect(input_diagnostic.source, content="Agent input")
  inspect(input_diagnostic.message, content="Choose a branch name")
}

///|
test "workbench ingests Pi plan update jsonl into session plan evidence" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"plan_update","steps":[{"id":"inspect","title":"Inspect renderer path","status":"done","owner":"Pi","detail":"Core route mapped"},{"id":"fix","title":"Fix Skia smoke","status":"in_progress","owner":"Pi","detail":"Run focused checks"}]}
        ),
      ),
    ),
  )
  inspect(model.plan.length(), content="2")
  inspect(model.plan[0].status, content="done")
  inspect(model.plan[1].title, content="Fix Skia smoke")
  inspect(model.plan[1].detail, content="Run focused checks")
  inspect(model.active_session().status, content="running")
  inspect(model.active_session().active_task, content="计划：Fix Skia smoke")
  inspect(model.active_session().unread_events, content="1")
  inspect(model.active_session().summary, content="1/2 plan steps complete")
  inspect(model.last_status, content="Pi plan updated")
  assert_true(model.events.any(event => event.title == "Pi plan updated"))
}

///|
test "workbench renders current plan and continuation action" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"plan_update","steps":[{"id":"fix","title":"Fix Skia smoke","status":"in_progress","owner":"Pi","detail":"Run focused checks"}]}
        ),
      ),
    ),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前计划"))
  assert_true(has_text(commands, "Fix Skia smoke"))
  assert_true(has_text(commands, "进行中 · Run focused checks"))
  assert_true(has_text(commands, "1 待办"))
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "继续当前计划"))
  assert_true(has_text(commands, "继续"))
}

///|
test "workbench runtime draws diagnostic fix action" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"diagnostic","source":"moon check","severity":"error","message":"unused variable in app.mbt"}
        ),
      ),
    ),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "unused variable in app.mbt"))
  assert_true(has_text(commands, "清除"))
  assert_true(has_text(commands, "修复"))
}

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

///|
test "workbench ingests Pi RPC get_session_stats response into session metrics" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_session_stats","success":true,"data":{"sessionFile":"/tmp/mo-workbench.jsonl","sessionId":"019e7f62","userMessages":2,"assistantMessages":3,"toolCalls":4,"toolResults":5,"totalMessages":10,"tokens":{"input":1000,"output":240,"cacheRead":80,"cacheWrite":20,"total":1340},"cost":0.0123,"contextUsage":{"tokens":1340,"contextWindow":200000,"percent":16}}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_session_stats")
  inspect(model.pi_rpc.success, content="true")
  inspect(model.pi_rpc.session_id, content="019e7f62")
  inspect(model.pi_rpc.session_file, content="/tmp/mo-workbench.jsonl")
  inspect(model.pi_rpc.message_count, content="10")
  inspect(model.pi_session_stats.session_id, content="019e7f62")
  inspect(
    model.pi_session_stats.session_file,
    content="/tmp/mo-workbench.jsonl",
  )
  inspect(model.pi_session_stats.user_messages, content="2")
  inspect(model.pi_session_stats.assistant_messages, content="3")
  inspect(model.pi_session_stats.tool_calls, content="4")
  inspect(model.pi_session_stats.tool_results, content="5")
  inspect(model.pi_session_stats.total_messages, content="10")
  inspect(model.pi_session_stats.token_input, content="1000")
  inspect(model.pi_session_stats.token_output, content="240")
  inspect(model.pi_session_stats.token_cache_read, content="80")
  inspect(model.pi_session_stats.token_cache_write, content="20")
  inspect(model.pi_session_stats.token_total, content="1340")
  match model.pi_session_stats.context_tokens {
    Some(tokens) => inspect(tokens, content="1340")
    None => fail("expected context token count")
  }
  inspect(model.pi_session_stats.context_window, content="200000")
  match model.pi_session_stats.context_percent {
    Some(percent) => inspect(percent.to_int(), content="16")
    None => fail("expected context percentage")
  }
  let binding = model.active_pi_session_binding()
  inspect(binding.rpc_session_id, content="019e7f62")
  inspect(binding.session_file, content="/tmp/mo-workbench.jsonl")
  inspect(binding.status, content="bound")
  inspect(binding.last_command, content="get_session_stats")
  inspect(
    model.active_session().summary,
    content="会话统计：10 消息，4 工具，1340 tokens",
  )
  inspect(model.last_status, content="Pi session stats refreshed")
  assert_true(
    model.events.any(event => event.title == "Pi session stats refreshed"),
  )
}

///|
test "workbench binds switched Pi session after get_state refresh" {
  let model = WorkbenchModel::new()
    .update(SelectSession("pi-rpc"))
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "pi-rpc",
          (
            #|{"type":"response","command":"switch_session","success":true,"data":{"cancelled":false}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "pi-rpc",
          (
            #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e7ed4","sessionFile":"/tmp/mo-workbench-pi-rpc-session.jsonl","sessionName":"Mo Workbench smoke","messageCount":8,"pendingMessageCount":0}}
          ),
        ),
      ),
    )
  let binding = model.active_pi_session_binding()
  inspect(binding.workbench_session_id, content="pi-rpc")
  inspect(binding.rpc_session_id, content="019e7ed4")
  inspect(
    binding.session_file,
    content="/tmp/mo-workbench-pi-rpc-session.jsonl",
  )
  inspect(binding.session_name, content="Mo Workbench smoke")
  inspect(binding.model, content="openai/gpt-5")
  inspect(binding.status, content="bound")
  inspect(binding.last_command, content="get_state")
  inspect(binding.status_label(), content="bound · Mo Workbench smoke")
  let session = model.active_session()
  inspect(session.status, content="active")
  inspect(session.summary, content="Agent session 019e7ed4 on openai/gpt-5")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(
    model.events.any(event => event.title == "Pi session switch accepted"),
  )
}

///|
test "workbench active Pi binding keeps configured session path" {
  let model = WorkbenchModel::new().update(SelectSession("pi-rpc"))
  let binding = model.active_pi_session_binding()
  inspect(binding.workbench_session_id, content="pi-rpc")
  inspect(
    binding.session_file,
    content="/tmp/mo-workbench-pi-rpc-session.jsonl",
  )
  inspect(binding.status, content="unbound")
}

///|
test "workbench draws backend session binding identity after get_state" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e7eb5","sessionName":"Mo Workbench smoke","sessionFile":"/tmp/mo-workbench-smoke.jsonl","messageCount":4,"pendingMessageCount":0}}
          ),
        ),
      ),
    )
    .update(ToggleComposerControls)
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(
    has_text(commands, "后端会话：已绑定 · Mo Workbench smoke"),
  )
  assert_false(
    has_text(commands, "Pi 会话：已绑定 · Mo Workbench smoke"),
  )
  assert_true(has_text(commands, "模型：openai/gpt-5"))
}

///|
test "workbench expanded session details do not fan out unrelated advanced actions" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e7eb5","sessionName":"MoUI Skia renderer","sessionFile":"/tmp/mo-workbench-smoke.jsonl","messageCount":4,"pendingMessageCount":0}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_available_models","success":true,"data":{"models":[{"provider":"openai","id":"gpt-5","name":"GPT-5"}]}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_session_stats","success":true,"data":{"totalMessages":4,"toolCalls":1,"toolResults":1,"tokens":{"total":1200}}}
          ),
        ),
      ),
    )
    .update(ToggleComposerControls)
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(
    has_text(commands, "后端会话：已绑定 · MoUI Skia renderer"),
  )
  assert_true(has_text(commands, "模型 1"))
  assert_true(has_text(commands, "消息 4"))
  assert_false(has_text(commands, "分叉"))
  assert_false(has_text(commands, "导出"))
  assert_true(has_text(commands, "压缩"))
  assert_false(has_text(commands, "思考"))
  assert_false(has_text(commands, "同步名"))
}

///|
test "workbench expanded session actions appear only with matching evidence" {
  let transcript_model = {
    ..WorkbenchModel::new(),
    transcript: [
      TranscriptItem::new(
        id="entry-user-1",
        role="user",
        summary="Inspect the renderer path",
        detail="",
        tone="info",
      ),
    ],
    composer_controls_expanded: true,
  }
  let transcript_commands = transcript_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(transcript_commands, "分叉"))
  assert_true(has_text(transcript_commands, "导出"))
  assert_false(has_text(transcript_commands, "压缩"))

  let thinking_model = {
    ..WorkbenchModel::new(),
    pi_agent: PiAgentSnapshot::new(thinking_level="high"),
    composer_controls_expanded: true,
  }
  let thinking_commands = thinking_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(thinking_commands, "思考：高"))
  assert_true(has_text(thinking_commands, "思考"))

  let sync_model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_state","success":true,"data":{"sessionId":"019e7eb5","sessionName":"Out of date","sessionFile":"/tmp/mo-workbench-smoke.jsonl","messageCount":1,"pendingMessageCount":0}}
          ),
        ),
      ),
    )
    .update(ToggleComposerControls)
  let sync_commands = sync_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(sync_commands, "同步名"))
}

///|
test "workbench ingests Pi session info changes into session binding" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"session_info_changed\",\"name\":\"Mo Workbench smoke\"}",
      ),
    ),
  )
  let binding = model.active_pi_session_binding()
  inspect(binding.workbench_session_id, content="moui-skia")
  inspect(binding.session_name, content="Mo Workbench smoke")
  inspect(binding.status, content="named")
  inspect(binding.last_command, content="session_info_changed")
  inspect(
    model.active_session().summary,
    content="会话名：Mo Workbench smoke",
  )
  inspect(model.last_status, content="Pi session info applied")
  assert_true(
    model.events.any(event => event.title == "Pi session info changed"),
  )
}

///|
test "workbench turns Pi RPC error responses into diagnostics" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"prompt","success":false,"error":"missing API key"}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="prompt")
  inspect(model.pi_rpc.success, content="false")
  inspect(model.pi_rpc.error, content="missing API key")
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="Pi RPC")
  inspect(diagnostic.severity, content="error")
  inspect(diagnostic.message, content="prompt: missing API key")
  inspect(model.last_status, content="Pi RPC failure applied")
  assert_true(model.events.any(event => event.title == "Pi RPC failed: prompt"))
}

///|
test "workbench ingests Pi streaming message lifecycle jsonl" {
  let running = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived("moui-skia", "{\"type\":\"agent_start\"}"),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia", "{\"type\":\"turn_start\",\"turnIndex\":2}",
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"message_update","message":{"role":"assistant","content":[{"type":"text","text":"Inspecting renderer route"}]},"assistantMessageEvent":{"type":"text_delta","delta":"Inspecting renderer route"}}
          ),
        ),
      ),
    )
  let running_commands = running
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(running_commands, "当前任务"))
  assert_true(has_text(running_commands, "Agent 回复中"))
  assert_false(has_text(running_commands, "Agent assistant message streaming"))
  assert_true(has_text(running_commands, "Pi assistant message streaming"))
  assert_true(
    draw_text_count_containing(running_commands, "Inspecting renderer route") >=
    1,
  )
  assert_false(has_text(running_commands, "已处理"))
  let model = running
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Renderer route inspected"}]}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"Renderer route inspected"}]}],"willRetry":false}
          ),
        ),
      ),
    )
  inspect(model.pi_agent.phase, content="idle")
  inspect(model.pi_agent.turn_index, content="2")
  inspect(model.pi_agent.message_role, content="assistant")
  inspect(model.pi_agent.message_preview, content="Renderer route inspected")
  inspect(model.transcript.length(), content="1")
  inspect(model.transcript[0].role, content="assistant")
  inspect(model.transcript[0].summary, content="Renderer route inspected")
  let session = model.active_session()
  inspect(session.status, content="active")
  inspect(session.active_task, content="Agent 运行完成")
  inspect(model.last_status, content="Pi agent completion applied")
  assert_true(model.events.any(event => event.title == "Pi agent started"))
  assert_true(
    model.events.any(event => event.title == "Pi message update: assistant"),
  )
}

///|
test "workbench completed agent process collapses behind processed row" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived("moui-skia", "{\"type\":\"agent_start\"}"),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"tool_execution_start","toolCallId":"call-bash-1","toolName":"bash","args":{"command":"moon test examples/mo_workbench/app --target native","cwd":"/repo"}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"tool_execution_end","toolCallId":"call-bash-1","toolName":"bash","result":{"details":{"exitCode":0},"content":[{"type":"text","text":"ok"}]},"isError":false}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Renderer route inspected"}]}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"Renderer route inspected"}]}],"willRetry":false}
          ),
        ),
      ),
    )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Renderer route inspected"))
  assert_true(has_text(commands, "已处理"))
  assert_true(has_text(commands, "展开"))
  assert_false(has_text(commands, "当前证据"))
  assert_false(
    has_text(
      commands, "命令 通过 · moon test examples/mo_workbench/app --target native · 输出可用 · /repo",
    ),
  )
  let expanded = model.update(ToggleWorkspaceDetails)
  let expanded_commands = expanded
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(expanded_commands, "已处理"))
  assert_true(has_text(expanded_commands, "收起"))
  assert_true(
    draw_text_count_containing(
      expanded_commands, "moon test examples/mo_workbench/app --target native",
    ) >=
    1,
  )
  assert_true(draw_text_count_containing(expanded_commands, "Pi agent") >= 1)
}

///|
test "workbench keeps tool transcript entries inside processed details" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","role":"user","content":"查看 readme 文件","timestamp":1},{"entryId":"entry-assistant-tool","role":"assistant","content":[{"type":"thinking"},{"type":"toolCall","name":"read"}],"timestamp":2},{"entryId":"entry-tool-1","role":"toolResult","toolName":"read","content":"# MoUI README 摘要","timestamp":3},{"entryId":"entry-assistant-final","role":"assistant","content":[{"type":"thinking"},{"type":"text","text":"## MoUI README 摘要"}],"timestamp":4}]}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived("moui-skia", "{\"type\":\"agent_start\"}"),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"## MoUI README 摘要"}]}],"willRetry":false}
          ),
        ),
      ),
    )
  inspect(model.transcript.length(), content="5")
  inspect(model.transcript[1].role, content="assistantProcess")
  inspect(model.transcript[2].role, content="toolResult")
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "查看 readme 文件"))
  assert_true(has_text(commands, "## MoUI README 摘要"))
  assert_true(has_text(commands, "已处理"))
  assert_false(has_text(commands, "Tool result: read"))
  assert_false(has_text(commands, "thinkingtool call: read"))
  assert_false(has_text(commands, "# MoUI README 摘要"))
  let expanded = model.update(ToggleWorkspaceDetails)
  let expanded_commands = expanded
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(
    draw_text_count_containing(expanded_commands, "tool call: read") >= 1,
  )
  assert_true(
    draw_text_count_containing(expanded_commands, "Tool result: read") >= 1,
  )
  assert_true(
    draw_text_count_containing(expanded_commands, "# MoUI README 摘要") >= 1,
  )
}

///|
test "workbench Pi agent completion queues transcript refresh and shows reply" {
  let transport = PiTransportRuntime::new(run=(_commands, _emit) => ())
  let update = WorkbenchModel::new().update_with_transport(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"Renderer route inspected"}]}],"willRetry":false}
        ),
      ),
    ),
    transport,
  )
  let model = update.model
  inspect(model.last_status, content="Pi transcript refresh queued")
  inspect(model.pending_transport_count(), content="3")
  inspect(model.transcript.length(), content="1")
  inspect(model.transcript[0].role, content="assistant")
  inspect(model.transcript[0].summary, content="Renderer route inspected")
  match model.transport.command_queue[0] {
    FetchRpcMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued message refresh")
  }
  match model.transport.command_queue[1] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued fork refresh")
  }
  match model.transport.command_queue[2] {
    FetchRpcSessionStats(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued stats refresh")
  }
}

///|
test "workbench ingests Pi tool execution jsonl into command evidence" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"tool_execution_start","toolCallId":"call-bash-1","toolName":"bash","args":{"command":"moon test examples/mo_workbench/app --target native","cwd":"/Volumes/Data/Code/moon/MoUI"}}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"tool_execution_end","toolCallId":"call-bash-1","toolName":"bash","result":{"details":{"exitCode":0,"fullOutputPath":"/tmp/pi-tool-bash.log","truncated":true},"content":[{"type":"text","text":"ok"}]},"isError":false}
          ),
        ),
      ),
    )
  let command = model.commands[model.commands.length() - 1]
  inspect(
    command.command,
    content="moon test examples/mo_workbench/app --target native",
  )
  inspect(command.cwd, content="/Volumes/Data/Code/moon/MoUI")
  inspect(command.status, content="passed")
  inspect(command.tool_call_id, content="call-bash-1")
  inspect(command.output, content="ok")
  inspect(command.output_path, content="/tmp/pi-tool-bash.log")
  assert_true(command.output_truncated)
  match command.exit_code {
    Some(code) => inspect(code, content="0")
    None => fail("expected Pi tool exit code")
  }
  inspect(model.pi_agent.phase, content="tool complete")
  inspect(model.pi_agent.active_tool_name, content="")
  inspect(model.last_status, content="Pi tool execution completed")
  assert_true(model.events.any(event => event.title == "Pi tool started: bash"))
  assert_true(model.events.any(event => event.title == "Pi tool ended: bash"))
}

///|
test "workbench ingests Pi RPC bash failure into command diagnostics" {
  let model = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"bash","success":true,"data":{"output":"failed","exitCode":2,"cancelled":false,"truncated":false}}
          ),
        ),
      ),
    )
  let command = model.commands[model.commands.length() - 1]
  inspect(command.command, content="moon check")
  inspect(command.status, content="failed")
  match command.exit_code {
    Some(code) => inspect(code, content="2")
    None => fail("expected command exit code")
  }
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="Pi bash")
  inspect(diagnostic.severity, content="error")
  inspect(diagnostic.message, content="bash exited with code 2")
  inspect(model.last_status, content="Pi bash response applied")
  assert_true(model.events.any(event => event.title == "Pi bash completed"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "退出码 2"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "Pi bash"))
  assert_false(has_text(commands, "bash exited with code 2"))
}

///|
test "workbench ingests Pi RPC bash cancellation into command diagnostics" {
  let model = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .update(CancelRun)
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"bash","success":true,"data":{"output":"","cancelled":true,"truncated":false}}
          ),
        ),
      ),
    )
  let command = model.commands[model.commands.length() - 1]
  inspect(command.command, content="moon check")
  inspect(command.status, content="cancelled")
  match command.exit_code {
    Some(_) => fail("expected cancelled bash without exit code")
    None => inspect("none", content="none")
  }
  let diagnostic = model.diagnostics[model.diagnostics.length() - 1]
  inspect(diagnostic.source, content="Pi bash")
  inspect(diagnostic.severity, content="warning")
  inspect(diagnostic.message, content="bash command was cancelled")
  inspect(model.last_status, content="Pi bash response applied")
  assert_true(model.events.any(event => event.title == "Pi bash cancelled"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "已取消"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "Pi bash"))
  assert_false(has_text(commands, "bash command was cancelled"))
}

///|
test "workbench ingests Pi queue and thinking session events" {
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"queue_update","steering":["stop"],"followUp":["run checks","update docs"]}
          ),
        ),
      ),
    )
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia", "{\"type\":\"thinking_level_changed\",\"level\":\"high\"}",
        ),
      ),
    )
  inspect(model.pi_agent.queued_steering, content="1")
  inspect(model.pi_agent.queued_follow_up, content="2")
  inspect(model.pi_agent.thinking_level, content="high")
  inspect(model.pi_agent.status_label(), content="queue pending · queued 3")
  let session = model.active_session()
  inspect(session.status, content="running")
  inspect(session.unread_events, content="3")
  inspect(model.last_status, content="Pi thinking level applied")
  assert_true(model.events.any(event => event.title == "Pi queue updated"))
  assert_true(
    model.events.any(event => event.title == "Pi thinking level changed"),
  )
}

///|
test "workbench ignores non-json Pi lines without losing raw transport state" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(JsonLineReceived("moui-skia", "not-json")),
  )
  inspect(model.transport.last_json_line, content="not-json")
  inspect(model.last_status, content="Pi transport event received")
}
