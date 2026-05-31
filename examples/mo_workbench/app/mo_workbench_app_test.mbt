///|
test "workbench dispatch queues prompt for selected session" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("Inspect the Skia renderer route"))
    .update(DispatchPrompt)
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
      inspect(text, content="Inspect the Skia renderer route")
    }
    _ => fail("expected queued user input")
  }
}

///|
test "workbench transport runtime effect dispatches prompt events" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"prompt\"}"))
    emit(JsonLineReceived("moui-skia", "{\"event\":\"done\"}"))
  })
  let update = WorkbenchModel::new()
    .update(PromptChanged("Summarize the staged diff"))
    .update_with_transport(DispatchPrompt, transport)
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
  inspect(model.transport.last_json_line, content="{\"event\":\"done\"}")
  assert_true(
    model.events.any(event => event.title == "JSONL received: moui-skia"),
  )
}

///|
test "workbench command queue uses Pi RPC bash command" {
  let model = WorkbenchModel::new().update(QueueCommand("moon check"))
  inspect(model.last_status, content="Command queued for Pi RPC bash")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    RunShellCommand(session, command) => {
      inspect(session, content="moui-skia")
      inspect(command, content="moon check")
    }
    _ => fail("expected queued shell command")
  }
  let command = model.commands[model.commands.length() - 1]
  inspect(command.command, content="moon check")
  inspect(command.cwd, content="/Volumes/Data/Code/moon/MoUI")
  inspect(command.status, content="queued")
}

///|
test "workbench command runtime effect dispatches Pi RPC bash command" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"bash\",\"command\":\"moon check\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"bash","success":true,"data":{"output":"ok","exitCode":0,"cancelled":false,"truncated":false}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    QueueCommand("moon check"),
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    RunShellCommand(session, command) => {
      inspect(session, content="moui-skia")
      inspect(command, content="moon check")
    }
    _ => fail("expected captured shell command")
  }
  inspect(model.pending_transport_count(), content="0")
  let command = model.commands[model.commands.length() - 1]
  inspect(command.status, content="passed")
  match command.exit_code {
    Some(code) => inspect(code, content="0")
    None => fail("expected command exit code")
  }
  inspect(model.pi_rpc.command, content="bash")
  inspect(model.last_status, content="Pi bash response applied")
  assert_true(model.events.any(event => event.title == "Pi bash completed"))
}

///|
test "workbench syncs selected title to Pi session name" {
  let model = WorkbenchModel::new().update(SyncSessionName)
  inspect(model.last_status, content="Pi session name sync queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    SetRpcSessionName(session, name) => {
      inspect(session, content="moui-skia")
      inspect(name, content="MoUI Skia renderer")
    }
    _ => fail("expected queued session name sync")
  }
  assert_true(
    model.events.any(event => event.title == "Pi session name sync queued"),
  )
}

///|
test "workbench session name runtime effect updates Pi binding" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"set_session_name\",\"name\":\"MoUI Skia renderer\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"session_info_changed\",\"name\":\"MoUI Skia renderer\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"set_session_name\",\"success\":true}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    SyncSessionName,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SetRpcSessionName(session, name) => {
      inspect(session, content="moui-skia")
      inspect(name, content="MoUI Skia renderer")
    }
    _ => fail("expected captured session name sync")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="set_session_name")
  inspect(model.last_status, content="Pi session name synced")
  let binding = model.active_pi_session_binding()
  inspect(binding.session_name, content="MoUI Skia renderer")
  inspect(binding.status, content="named")
  inspect(binding.last_command, content="set_session_name")
  assert_true(
    model.events.any(event => event.title == "Pi session info changed"),
  )
  assert_true(
    model.events.any(event => event.title == "Pi session name synced"),
  )
}

///|
test "workbench cancel run targets active Pi RPC bash command" {
  let model = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .update(CancelRun)
  inspect(model.last_status, content="Shell command cancellation queued")
  inspect(model.pending_transport_count(), content="3")
  let command = model.commands[model.commands.length() - 1]
  inspect(command.status, content="cancelling")
  match model.transport.command_queue[2] {
    CancelShellCommand(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued shell cancellation")
  }
  assert_true(
    model.events.any(event => {
      event.title == "Shell command cancellation requested"
    }),
  )
}

///|
test "workbench cancel run falls back to agent abort without active shell command" {
  let model = WorkbenchModel::new().update(CancelRun)
  inspect(model.last_status, content="Cancellation queued")
  inspect(model.pending_transport_count(), content="1")
  match model.transport.command_queue[0] {
    CancelRpcRun(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued agent cancellation")
  }
}

///|
test "workbench cancel runtime effect dispatches Pi RPC abort_bash command" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .update_with_transport(CancelRun, transport)
  inspect(captured.val.length(), content="0")
  inspect(update.model.last_status, content="Shell command cancellation queued")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="1")
  match captured.val[0] {
    CancelShellCommand(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured shell cancellation")
  }
  inspect(
    model.commands[model.commands.length() - 1].status,
    content="cancelling",
  )
}

///|
test "workbench selection with transport switches Pi session then refreshes state and commands" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new().update_with_transport(
    SelectSession("pi-rpc"),
    transport,
  )
  inspect(update.model.selected_session_id, content="pi-rpc")
  inspect(update.model.pending_transport_count(), content="4")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="4")
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
    FetchRpcMessages(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued message refresh")
  }
  match captured.val[3] {
    FetchRpcCommands(session) => inspect(session, content="pi-rpc")
    _ => fail("expected queued command catalog refresh")
  }
  inspect(model.selected_session_id, content="pi-rpc")
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
}

///|
test "workbench ingests Pi RPC get_state response jsonl" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e7eb5","messageCount":4,"pendingMessageCount":1}}
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
  inspect(model.pi_rpc.message_count, content="4")
  inspect(model.pi_rpc.pending_message_count, content="1")
  let session = model.active_session()
  inspect(session.status, content="running")
  inspect(session.unread_events, content="1")
  inspect(session.summary, content="Pi RPC session 019e7eb5 on openai/gpt-5")
  let binding = model.active_pi_session_binding()
  inspect(binding.workbench_session_id, content="moui-skia")
  inspect(binding.rpc_session_id, content="019e7eb5")
  inspect(binding.status, content="bound")
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
          #|{"type":"response","command":"get_messages","success":true,"data":{"messages":[{"role":"user","content":"Inspect the Skia route","timestamp":1},{"role":"assistant","content":[{"type":"text","text":"Skia route inspected"}],"model":"gpt-5","timestamp":2},{"role":"bashExecution","command":"moon check","output":"ok","exitCode":0,"cancelled":false,"truncated":false,"timestamp":3}]}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_messages")
  inspect(model.pi_rpc.message_count, content="3")
  inspect(model.transcript.length(), content="3")
  inspect(model.transcript[0].role, content="user")
  inspect(model.transcript[0].summary, content="Inspect the Skia route")
  inspect(model.transcript[1].role, content="assistant")
  inspect(model.transcript[1].detail, content="Skia route inspected")
  inspect(model.transcript[2].role, content="bashExecution")
  inspect(model.transcript[2].summary, content="moon check")
  inspect(model.transcript[2].detail, content="exit code 0 - ok")
  inspect(model.last_status, content="Pi messages refreshed")
  assert_true(model.events.any(event => event.title == "Pi messages refreshed"))
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
  inspect(session.summary, content="Pi RPC session 019e7ed4 on openai/gpt-5")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(
    model.events.any(event => event.title == "Pi session switch accepted"),
  )
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
    content="Pi session name: Mo Workbench smoke",
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
  let model = WorkbenchModel::new()
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
  let session = model.active_session()
  inspect(session.status, content="active")
  inspect(session.active_task, content="Pi agent run completed")
  inspect(model.last_status, content="Pi agent completion applied")
  assert_true(model.events.any(event => event.title == "Pi agent started"))
  assert_true(
    model.events.any(event => event.title == "Pi message update: assistant"),
  )
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
            #|{"type":"tool_execution_end","toolCallId":"call-bash-1","toolName":"bash","result":{"details":{"exitCode":0},"content":[{"type":"text","text":"ok"}]},"isError":false}
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

///|
test "workbench command completion updates command table state" {
  let model = WorkbenchModel::new().update(QueueCommand("moon check"))
  let command_id = model.commands.length()
  let completed = model.update(MarkCommandComplete(command_id, 1))
  assert_true(completed.commands.length() == command_id)
  inspect(completed.commands[command_id - 1].status, content="failed")
  match completed.commands[command_id - 1].exit_code {
    Some(code) => inspect(code, content="1")
    None => fail("expected command exit code")
  }
}

///|
test "workbench runtime draws agent desktop shell" {
  let commands = @app.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "A Pi agent desktop"))
  assert_true(has_text(commands, "Session status"))
  assert_true(has_text(commands, "Pi transcript"))
  assert_true(has_text(commands, "Pi commands"))
  assert_true(has_text(commands, "/review"))
  assert_true(has_text(commands, "Command evidence"))
  assert_true(has_text(commands, "Context files"))
  assert_true(has_text(commands, "同步标题"))
  assert_true(has_text(commands, "要求继续推进 Mo Workbench"))
  assert_true(has_text(commands, "Pi RPC"))
  assert_true(has_text(commands, "Diff summary · ready for review"))
  assert_false(has_text(commands, "验证已通过："))
  assert_false(has_text(commands, "打开方式⌄"))
  assert_false(has_text(commands, "复制"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}

///|
fn run_workbench_effect(update : WorkbenchUpdate) -> WorkbenchModel {
  let model = @core.State::new(update.model)
  let dispatch = message => model.set(model.get().update(message))
  match update.effect {
    @core.Effect::NoEffect => ()
    @core.Effect::Batch(effects) =>
      for effect in effects {
        let next = run_workbench_effect(
          WorkbenchUpdate::new(model.get(), effect~),
        )
        model.set(next)
      }
    @core.Effect::Send(message) => dispatch(message)
    @core.Effect::Dispatch(run) => run(dispatch)
  }
  model.get()
}
