///|
test "workbench clears visible diagnostics" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"diagnostic","source":"moon check","severity":"warning","message":"check output changed"}
        ),
      ),
    ),
  )
  inspect(model.diagnostics.length(), content="1")
  let cleared = model.update(ClearDiagnostics)
  inspect(cleared.diagnostics.length(), content="0")
  inspect(
    cleared.last_status,
    content="Diagnostics cleared for current session",
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
test "workbench focused check preset routes through Pi RPC bash command" {
  let focused_check = "moon test examples/mo_workbench/app --target native"
  let model = WorkbenchModel::new().update(QueueCommand(focused_check))
  match model.transport.command_queue[1] {
    RunShellCommand(session, command) => {
      inspect(session, content="moui-skia")
      inspect(command, content=focused_check)
    }
    _ => fail("expected focused check to queue shell command")
  }
  let queued = model.commands[model.commands.length() - 1]
  inspect(queued.command, content=focused_check)
}

///|
test "workbench queues all focused checks through one Pi RPC bash batch" {
  let model = WorkbenchModel::new().update(QueueFocusedChecks)
  inspect(model.last_status, content="Focused checks queued for Pi RPC bash")
  inspect(model.pending_transport_count(), content="5")
  inspect(model.commands.length(), content="4")
  inspect(
    model.commands[0].command,
    content="moon test examples/mo_workbench/app --target native",
  )
  inspect(
    model.commands[1].command,
    content="moon test examples/mo_workbench/app --target wasm-gc",
  )
  inspect(
    model.commands[2].command,
    content="moon build examples/mo_workbench/macos_skia --target native",
  )
  inspect(
    model.commands[3].command,
    content="moon build moui_tester/macos_skia_first_frame_smoke --target native",
  )
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[4] {
    RunShellCommand(session, command) => {
      inspect(session, content="moui-skia")
      inspect(
        command,
        content="moon build moui_tester/macos_skia_first_frame_smoke --target native",
      )
    }
    _ => fail("expected queued final focused check")
  }
}

///|
test "workbench reruns command evidence through Pi RPC bash path" {
  let seed = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon test examples/mo_workbench/app --target native",
        cwd="/Volumes/Data/Code/moon/MoUI",
        status="ready",
        exit_code=None,
        output_path="/tmp/mo-workbench-app-test.log",
      ),
    ],
  }
  let command = seed.commands[0].command
  let model = seed.update(QueueCommand(command))
  inspect(model.last_status, content="Command queued for Pi RPC bash")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    RunShellCommand(session, rerun) => {
      inspect(session, content="moui-skia")
      inspect(
        rerun,
        content="moon test examples/mo_workbench/app --target native",
      )
    }
    _ => fail("expected queued rerun shell command")
  }
  let queued = model.commands[model.commands.length() - 1]
  inspect(
    queued.command,
    content="moon test examples/mo_workbench/app --target native",
  )
  inspect(queued.status, content="queued")
}

///|
test "workbench queues command evidence analysis through prompt RPC" {
  let model = WorkbenchModel::new().update(
    InspectCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued command evidence for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Inspect command output for moon check: /tmp/mo-check.log (status failed, cwd /repo)",
        ),
      )
    }
    _ => fail("expected queued command evidence prompt")
  }
  assert_true(
    model.events.any(event => event.title == "Command evidence queued"),
  )
}

///|
test "workbench command evidence runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Context: repo, examples\\n\\nTask: Inspect command output for moon check: /tmp/mo-check.log (status failed, cwd /repo)\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    InspectCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"),
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Inspect command output for moon check: /tmp/mo-check.log (status failed, cwd /repo)",
        ),
      )
    }
    _ => fail("expected captured command evidence prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.display_status_label(), content="运行中")
}

///|
test "workbench queues failed command fix through prompt RPC" {
  let model = WorkbenchModel::new().update(
    FixCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued command fix for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Fix failed command moon check using output /tmp/mo-check.log (status failed, cwd /repo)",
        ),
      )
    }
    _ => fail("expected queued command fix prompt")
  }
  assert_true(model.events.any(event => event.title == "Command fix queued"))
}

///|
test "workbench command fix preserves selected agent focus" {
  let model = WorkbenchModel::new()
    .update(SelectAgent("coding"))
    .update(FixCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"))
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=agent_context_task_payload(
          "Fix failed command moon check using output /tmp/mo-check.log (status failed, cwd /repo)",
        ),
      )
    }
    _ => fail("expected focused command fix prompt")
  }
}

///|
test "workbench command fix runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Context: repo, examples\\n\\nTask: Fix failed command moon check using output /tmp/mo-check.log (status failed, cwd /repo)\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    FixCommandRun("moon check", "failed", "/repo", "/tmp/mo-check.log"),
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Fix failed command moon check using output /tmp/mo-check.log (status failed, cwd /repo)",
        ),
      )
    }
    _ => fail("expected captured command fix prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.display_status_label(), content="运行中")
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
          #|{"type":"response","command":"bash","success":true,"data":{"output":"ok","exitCode":0,"cancelled":false,"truncated":false,"fullOutputPath":"/tmp/mo-workbench-bash.log"}}
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
  inspect(command.output_path, content="/tmp/mo-workbench-bash.log")
  inspect(command.output, content="ok")
  assert_false(command.output_truncated)
  match command.exit_code {
    Some(code) => inspect(code, content="0")
    None => fail("expected command exit code")
  }
  inspect(model.pi_rpc.command, content="bash")
  inspect(model.last_status, content="Pi bash response applied")
  assert_true(model.events.any(event => event.title == "Pi bash completed"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(draw_text_count_containing(commands, "输出可用") >= 1)
  assert_false(has_text(commands, "/tmp/mo-workbench-bash.log"))
  assert_false(has_text(commands, "ok"))
  assert_true(has_text(commands, "展开"))
  assert_true(has_text(commands, "分析"))
  assert_true(has_text(commands, "重跑"))
  let expanded = model.update(ToggleCommandDetails(command.id))
  let expanded_commands = expanded
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(expanded_commands, "收起"))
  assert_true(has_text(expanded_commands, "日志 /tmp/mo-workbench-bash.log"))
  assert_true(has_text(expanded_commands, "stdout"))
  assert_true(has_text(expanded_commands, "ok"))
}

///|
test "workbench focused check bash responses complete queued commands in order" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"bash\",\"command\":\"moon test examples/mo_workbench/app --target native\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"bash","success":true,"data":{"output":"native ok","exitCode":0,"cancelled":false,"truncated":false,"fullOutputPath":"/tmp/mo-workbench-native.log"}}
        ),
      ),
    )
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"bash\",\"command\":\"moon test examples/mo_workbench/app --target wasm-gc\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"bash","success":true,"data":{"output":"wasm failed","exitCode":2,"cancelled":false,"truncated":false,"fullOutputPath":"/tmp/mo-workbench-wasm.log"}}
        ),
      ),
    )
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"bash\",\"command\":\"moon build examples/mo_workbench/macos_skia --target native\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"bash","success":true,"data":{"output":"skia ok","exitCode":0,"cancelled":false,"truncated":false,"fullOutputPath":"/tmp/mo-workbench-skia.log"}}
        ),
      ),
    )
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"bash\",\"command\":\"moon build moui_tester/macos_skia_first_frame_smoke --target native\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"bash","success":true,"data":{"output":"first frame ok","exitCode":0,"cancelled":false,"truncated":false,"fullOutputPath":"/tmp/mo-workbench-first-frame.log"}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    QueueFocusedChecks,
    transport,
  )
  inspect(update.model.commands.length(), content="4")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="5")
  inspect(model.pending_transport_count(), content="0")
  inspect(
    model.commands[0].command,
    content="moon test examples/mo_workbench/app --target native",
  )
  inspect(model.commands[0].status, content="passed")
  inspect(model.commands[0].output_path, content="/tmp/mo-workbench-native.log")
  inspect(model.commands[0].output, content="native ok")
  inspect(
    model.commands[1].command,
    content="moon test examples/mo_workbench/app --target wasm-gc",
  )
  inspect(model.commands[1].status, content="failed")
  inspect(model.commands[1].output_path, content="/tmp/mo-workbench-wasm.log")
  inspect(model.commands[1].output, content="wasm failed")
  inspect(
    model.commands[2].command,
    content="moon build examples/mo_workbench/macos_skia --target native",
  )
  inspect(model.commands[2].status, content="passed")
  inspect(model.commands[2].output_path, content="/tmp/mo-workbench-skia.log")
  inspect(model.commands[2].output, content="skia ok")
  inspect(
    model.commands[3].command,
    content="moon build moui_tester/macos_skia_first_frame_smoke --target native",
  )
  inspect(model.commands[3].status, content="passed")
  inspect(
    model.commands[3].output_path,
    content="/tmp/mo-workbench-first-frame.log",
  )
  inspect(model.commands[3].output, content="first frame ok")
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
test "workbench cycles Pi thinking level through platform-neutral transport" {
  let model = WorkbenchModel::new().update(CycleThinkingLevel)
  inspect(model.last_status, content="Pi thinking level cycle queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    CycleRpcThinkingLevel(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued thinking level cycle")
  }
  assert_true(
    model.events.any(event => event.title == "Pi thinking level cycle queued"),
  )
}

///|
test "workbench thinking cycle runtime effect updates Pi agent snapshot" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"cycle_thinking_level\"}"))
    emit(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"cycle_thinking_level","success":true,"data":{"level":"high"}}
        ),
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    CycleThinkingLevel,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    CycleRpcThinkingLevel(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured thinking level cycle")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="cycle_thinking_level")
  inspect(model.pi_agent.thinking_level, content="high")
  inspect(model.active_session().active_task, content="思考等级：high")
  inspect(model.last_status, content="Pi thinking level cycle acknowledged")
  assert_true(
    model.events.any(event => event.title == "Pi thinking level cycled"),
  )
}

///|
test "workbench toggles Pi input queue modes through platform-neutral transport" {
  let steering = WorkbenchModel::new().update(ToggleSteeringMode)
  inspect(steering.last_status, content="Pi steering mode queued")
  inspect(steering.pending_transport_count(), content="2")
  inspect(steering.pi_agent.steering_mode, content="all")
  match steering.transport.command_queue[1] {
    SetRpcSteeringMode(session, mode) => {
      inspect(session, content="moui-skia")
      inspect(mode, content="all")
    }
    _ => fail("expected queued steering mode")
  }
  let follow_up = WorkbenchModel::new().update(ToggleFollowUpMode)
  inspect(follow_up.last_status, content="Pi follow-up mode queued")
  inspect(follow_up.pending_transport_count(), content="2")
  inspect(follow_up.pi_agent.follow_up_mode, content="all")
  match follow_up.transport.command_queue[1] {
    SetRpcFollowUpMode(session, mode) => {
      inspect(session, content="moui-skia")
      inspect(mode, content="all")
    }
    _ => fail("expected queued follow-up mode")
  }
}

///|
test "workbench queue mode runtime effect acknowledges Pi steering mode" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"set_steering_mode\",\"mode\":\"all\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"set_steering_mode\",\"success\":true}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    ToggleSteeringMode,
    transport,
  )
  inspect(update.model.pi_agent.steering_mode, content="all")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SetRpcSteeringMode(session, mode) => {
      inspect(session, content="moui-skia")
      inspect(mode, content="all")
    }
    _ => fail("expected captured steering mode")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="set_steering_mode")
  inspect(model.pi_agent.steering_mode, content="all")
  inspect(model.last_status, content="Pi steering mode acknowledged")
  assert_true(
    model.events.any(event => event.title == "Pi steering mode applied"),
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
test "workbench cancel run marks first active focused check command" {
  let model = WorkbenchModel::new().update(QueueFocusedChecks).update(CancelRun)
  inspect(model.last_status, content="Shell command cancellation queued")
  inspect(model.commands.length(), content="4")
  inspect(model.commands[0].status, content="cancelling")
  inspect(model.commands[1].status, content="queued")
  inspect(model.commands[2].status, content="queued")
  inspect(model.commands[3].status, content="queued")
  match model.transport.command_queue[5] {
    CancelShellCommand(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued shell cancellation")
  }
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
test "workbench fixture backend rejects cancellation without Pi transport" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update_with_transport(CancelRun, transport)
  inspect(
    update.model.last_status,
    content="Agent backend does not support cancellation",
  )
  inspect(update.model.pending_transport_count(), content="0")
  inspect(captured.val.length(), content="0")
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
