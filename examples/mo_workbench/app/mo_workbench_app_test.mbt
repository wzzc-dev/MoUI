///|
test "workbench dispatch queues prompt for selected session" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("Inspect the Skia renderer route"))
    .update(ToggleComposerControls)
    .update(DispatchPrompt)
  inspect(model.prompt, content="")
  inspect(model.composer_controls_expanded, content="false")
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
        content=context_task_payload("Inspect the Skia renderer route"),
      )
    }
    _ => fail("expected queued user input")
  }
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
test "workbench dispatch queues steering and follow-up inputs" {
  let steering = WorkbenchModel::new()
    .update(PromptChanged("Prefer the Skia route"))
    .update(ToggleComposerControls)
    .update(DispatchSteering)
  inspect(steering.prompt, content="")
  inspect(steering.composer_controls_expanded, content="false")
  inspect(steering.last_status, content="Queued steering input for Pi RPC")
  inspect(steering.pending_transport_count(), content="2")
  match steering.transport.command_queue[1] {
    SendSteeringInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content=context_task_payload("Prefer the Skia route"))
    }
    _ => fail("expected queued steering input")
  }
  assert_true(
    steering.events.any(event => event.title == "Steering input queued"),
  )
  let follow_up = WorkbenchModel::new()
    .update(PromptChanged("Run the focused checks next"))
    .update(ToggleComposerControls)
    .update(DispatchFollowUp)
  inspect(follow_up.prompt, content="")
  inspect(follow_up.composer_controls_expanded, content="false")
  inspect(follow_up.last_status, content="Queued follow-up input for Pi RPC")
  inspect(follow_up.pending_transport_count(), content="2")
  match follow_up.transport.command_queue[1] {
    SendFollowUpInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content=context_task_payload("Run the focused checks next"))
    }
    _ => fail("expected queued follow-up input")
  }
  assert_true(
    follow_up.events.any(event => event.title == "Follow-up input queued"),
  )
}

///|
test "workbench steering runtime effect dispatches steer RPC" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"steer\",\"message\":\"Prefer narrow edits\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"steer\",\"success\":true}",
      ),
    )
  })
  let update = WorkbenchModel::new()
    .update(PromptChanged("Prefer narrow edits"))
    .update_with_transport(DispatchSteering, transport)
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendSteeringInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content=context_task_payload("Prefer narrow edits"))
    }
    _ => fail("expected captured steering input")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="steer")
  inspect(model.last_status, content="Pi steering accepted")
  assert_true(model.events.any(event => event.title == "Pi steering accepted"))
}

///|
test "workbench follow-up runtime effect dispatches follow_up RPC" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"follow_up\",\"message\":\"Update docs\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"follow_up\",\"success\":true}",
      ),
    )
  })
  let update = WorkbenchModel::new()
    .update(PromptChanged("Update docs"))
    .update_with_transport(DispatchFollowUp, transport)
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendFollowUpInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content=context_task_payload("Update docs"))
    }
    _ => fail("expected captured follow-up input")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="follow_up")
  inspect(model.last_status, content="Pi follow-up accepted")
  assert_true(model.events.any(event => event.title == "Pi follow-up accepted"))
}

///|
test "workbench invokes Pi command catalog entries through prompt RPC" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("draft text"))
    .update(InvokeCommand("review"))
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued Pi command for RPC")
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
      inspect(text, content="/review")
    }
    _ => fail("expected queued command prompt")
  }
  assert_true(model.events.any(event => event.title == "Pi command queued"))
}

///|
test "workbench command catalog runtime effect dispatches slash prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent("moui-skia", "{\"type\":\"prompt\",\"message\":\"/review\"}"),
    )
    emit(JsonLineReceived("moui-skia", "{\"event\":\"done\"}"))
  })
  let update = WorkbenchModel::new().update_with_transport(
    InvokeCommand("review"),
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content="/review")
    }
    _ => fail("expected captured command prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
  inspect(model.transport.last_json_line, content="{\"event\":\"done\"}")
}

///|
test "workbench queues transcript follow-up through prompt RPC" {
  let model = WorkbenchModel::new().update(
    FollowTranscript("assistant", "Skia route inspected", "All checks pass"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued transcript follow-up for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content="Follow up on assistant transcript: Skia route inspected. Context: All checks pass",
      )
    }
    _ => fail("expected queued transcript follow-up prompt")
  }
  assert_true(
    model.events.any(event => event.title == "Transcript follow-up queued"),
  )
}

///|
test "workbench transcript follow-up runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Follow up on assistant transcript: Skia route inspected. Context: All checks pass\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    FollowTranscript("assistant", "Skia route inspected", "All checks pass"),
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
        content="Follow up on assistant transcript: Skia route inspected. Context: All checks pass",
      )
    }
    _ => fail("expected captured transcript follow-up prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench queues activity follow-up through prompt RPC" {
  let model = WorkbenchModel::new().update(
    FollowActivity("transport", "Pi RPC process started", "pid 4242"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued activity follow-up for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content="Follow up on transport activity: Pi RPC process started. Context: pid 4242",
      )
    }
    _ => fail("expected queued activity follow-up prompt")
  }
  assert_true(
    model.events.any(event => event.title == "Activity follow-up queued"),
  )
}

///|
test "workbench activity follow-up runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Follow up on transport activity: Pi RPC process started. Context: pid 4242\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    FollowActivity("transport", "Pi RPC process started", "pid 4242"),
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
        content="Follow up on transport activity: Pi RPC process started. Context: pid 4242",
      )
    }
    _ => fail("expected captured activity follow-up prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench queues file context inspection through prompt RPC" {
  let model = WorkbenchModel::new().update(
    InspectFile("examples/mo_workbench/app/app.mbt"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued file context for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Inspect examples/mo_workbench/app/app.mbt",
        ),
      )
    }
    _ => fail("expected queued file inspection prompt")
  }
  assert_true(model.events.any(event => event.title == "File context queued"))
}

///|
test "workbench file context runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Context: repo, examples\\n\\nTask: Inspect examples/mo_workbench/app/app.mbt\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    InspectFile("examples/mo_workbench/app/app.mbt"),
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
          "Inspect examples/mo_workbench/app/app.mbt",
        ),
      )
    }
    _ => fail("expected captured file inspection prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench queues diff review through prompt RPC" {
  let model = model_with_reviewable_diff().update(ReviewDiff)
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued diff review for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Review diff: ready for review, 5 files, +160 -10",
        ),
      )
    }
    _ => fail("expected queued diff review prompt")
  }
  assert_true(model.events.any(event => event.title == "Diff review queued"))
}

///|
test "workbench file and diff evidence preserve selected agent focus" {
  let file_model = WorkbenchModel::new()
    .update(SelectAgent("coding"))
    .update(InspectFile("examples/mo_workbench/app/app.mbt"))
  match file_model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=agent_context_task_payload(
          "Inspect examples/mo_workbench/app/app.mbt",
        ),
      )
    }
    _ => fail("expected focused file inspection prompt")
  }
  let diff_model = model_with_reviewable_diff()
    .update(SelectAgent("coding"))
    .update(ReviewDiff)
  match diff_model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=agent_context_task_payload(
          "Review diff: ready for review, 5 files, +160 -10",
        ),
      )
    }
    _ => fail("expected focused diff review prompt")
  }
}

///|
test "workbench keeps empty diff review quiet" {
  let model = WorkbenchModel::new().update(ReviewDiff)
  inspect(model.last_status, content="Diff context is empty")
  inspect(model.pending_transport_count(), content="0")
  assert_false(model.events.any(event => event.title == "Diff review queued"))
}

///|
test "workbench diff review runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Context: repo, examples\\n\\nTask: Review diff: ready for review, 5 files, +160 -10\"}",
      ),
    )
  })
  let update = model_with_reviewable_diff().update_with_transport(
    ReviewDiff,
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
          "Review diff: ready for review, 5 files, +160 -10",
        ),
      )
    }
    _ => fail("expected captured diff review prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench queues diagnostic fix through prompt RPC" {
  let model = WorkbenchModel::new().update(
    FixDiagnostic("moon check", "error", "unused variable in app.mbt"),
  )
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued diagnostic fix for Pi RPC")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Fix error diagnostic from moon check: unused variable in app.mbt",
        ),
      )
    }
    _ => fail("expected queued diagnostic fix prompt")
  }
  assert_true(model.events.any(event => event.title == "Diagnostic fix queued"))
}

///|
test "workbench diagnostic fix preserves selected agent focus" {
  let model = WorkbenchModel::new()
    .update(SelectAgent("coding"))
    .update(FixDiagnostic("moon check", "error", "unused variable in app.mbt"))
  match model.transport.command_queue[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=agent_context_task_payload(
          "Fix error diagnostic from moon check: unused variable in app.mbt",
        ),
      )
    }
    _ => fail("expected focused diagnostic fix prompt")
  }
}

///|
test "workbench diagnostic fix runtime effect dispatches prompt" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"prompt\",\"message\":\"Context: repo, examples\\n\\nTask: Fix error diagnostic from moon check: unused variable in app.mbt\"}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    FixDiagnostic("moon check", "error", "unused variable in app.mbt"),
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
          "Fix error diagnostic from moon check: unused variable in app.mbt",
        ),
      )
    }
    _ => fail("expected captured diagnostic fix prompt")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench refreshes current Pi session through platform-neutral commands" {
  let model = WorkbenchModel::new().update(RefreshSession)
  inspect(model.last_status, content="Pi session refresh queued")
  inspect(model.pending_transport_count(), content="6")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued state refresh")
  }
  match model.transport.command_queue[1] {
    FetchRpcAvailableModels(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued model catalog refresh")
  }
  match model.transport.command_queue[2] {
    FetchRpcMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued messages refresh")
  }
  match model.transport.command_queue[3] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued fork messages refresh")
  }
  match model.transport.command_queue[4] {
    FetchRpcCommands(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued command catalog refresh")
  }
  match model.transport.command_queue[5] {
    FetchRpcSessionStats(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued session stats refresh")
  }
  assert_true(
    model.events.any(event => event.title == "Pi session refresh queued"),
  )
}

///|
test "workbench refresh runtime effect dispatches current session batch" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_available_models\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_messages\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_fork_messages\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_commands\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_session_stats\"}"))
  })
  let update = WorkbenchModel::new().update_with_transport(
    RefreshSession,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="6")
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="6")
  match captured.val[0] {
    StartRpc(session, _) => inspect(session, content="moui-skia")
    _ => fail("expected captured state refresh")
  }
  match captured.val[1] {
    FetchRpcAvailableModels(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured model catalog refresh")
  }
  match captured.val[2] {
    FetchRpcMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured messages refresh")
  }
  match captured.val[3] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured fork messages refresh")
  }
  match captured.val[4] {
    FetchRpcCommands(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured commands refresh")
  }
  match captured.val[5] {
    FetchRpcSessionStats(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured stats refresh")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.transport.status_label(), content="Running")
}

///|
test "workbench queues a new Pi session through platform-neutral commands" {
  let model = WorkbenchModel::new().update(NewSession)
  inspect(model.last_status, content="Pi new session queued")
  inspect(model.pending_transport_count(), content="1")
  match model.transport.command_queue[0] {
    NewRpcSession(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued new session request")
  }
  assert_true(model.events.any(event => event.title == "Pi new session queued"))
}

///|
test "workbench new session runtime effect binds refreshed Pi state" {
  let captured : Ref[Array[Array[PiTransportCommand]]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val.push(commands)
    emit(ProcessStarted("fixture-pid"))
    match commands[0] {
      NewRpcSession(_) => {
        emit(JsonLineSent("moui-skia", "{\"type\":\"new_session\"}"))
        emit(
          JsonLineReceived(
            "moui-skia", "{\"type\":\"response\",\"command\":\"new_session\",\"success\":true,\"data\":{\"cancelled\":false}}",
          ),
        )
      }
      StartRpc(_, _) => {
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_available_models\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_messages\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_fork_messages\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_commands\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_session_stats\"}"))
        emit(
          JsonLineReceived(
            "moui-skia",
            (
              #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e80f5","sessionFile":"/tmp/mo-workbench-new.jsonl","sessionName":"Mo Workbench new","messageCount":0,"pendingMessageCount":0}}
            ),
          ),
        )
      }
      _ => emit(TransportFailed("unexpected new session command batch"))
    }
  })
  let update = WorkbenchModel::new().update_with_transport(
    NewSession,
    transport,
  )
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="1")
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="2")
  inspect(captured.val[0].length(), content="1")
  match captured.val[0][0] {
    NewRpcSession(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured new session request")
  }
  inspect(captured.val[1].length(), content="6")
  match captured.val[1][0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected captured state refresh")
  }
  match captured.val[1][1] {
    FetchRpcAvailableModels(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured model catalog refresh")
  }
  match captured.val[1][2] {
    FetchRpcMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured message refresh")
  }
  match captured.val[1][3] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured fork messages refresh")
  }
  match captured.val[1][4] {
    FetchRpcCommands(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured command refresh")
  }
  match captured.val[1][5] {
    FetchRpcSessionStats(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured stats refresh")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.pi_rpc.command, content="get_state")
  let binding = model.active_pi_session_binding()
  inspect(binding.rpc_session_id, content="019e80f5")
  inspect(binding.session_file, content="/tmp/mo-workbench-new.jsonl")
  inspect(binding.session_name, content="Mo Workbench new")
  inspect(binding.status, content="bound")
  inspect(binding.last_command, content="get_state")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(
    model.events.any(event => event.title == "Pi new session accepted"),
  )
  assert_true(
    model.events.any(event => event.title == "Pi new session refresh queued"),
  )
  assert_true(
    model.events.any(event => event.title == "Pi RPC response: get_state"),
  )
}

///|
test "workbench new session cancellation does not refresh Pi state" {
  let captured : Ref[Array[Array[PiTransportCommand]]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val.push(commands)
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"new_session\"}"))
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"new_session\",\"success\":true,\"data\":{\"cancelled\":true}}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    NewSession,
    transport,
  )
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="1")
  inspect(captured.val[0].length(), content="1")
  inspect(model.pending_transport_count(), content="0")
  let binding = model.active_pi_session_binding()
  inspect(binding.status, content="cancelled")
  inspect(binding.last_command, content="new_session")
  inspect(model.last_status, content="Pi new session cancelled")
}

///|
test "workbench queues Pi fork discovery through platform-neutral commands" {
  let model = WorkbenchModel::new().update(RefreshForkMessages)
  inspect(model.last_status, content="Pi fork discovery queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected queued fork discovery")
  }
  assert_true(
    model.events.any(event => event.title == "Pi fork discovery queued"),
  )
}

///|
test "workbench ingests Pi RPC fork candidates" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_fork_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","text":"Inspect the Skia route"},{"entryId":"entry-user-2","text":"Run renderer smoke"}]}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="get_fork_messages")
  inspect(model.fork_messages.length(), content="2")
  inspect(model.fork_messages[0].entry_id, content="entry-user-1")
  inspect(model.fork_messages[0].text, content="Inspect the Skia route")
  inspect(model.fork_messages[1].entry_id, content="entry-user-2")
  inspect(model.last_status, content="Pi fork messages refreshed")
  assert_true(
    model.events.any(event => event.title == "Pi fork messages refreshed"),
  )
}

///|
test "workbench runtime draws fork affordance after Pi fork candidates" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"get_fork_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","text":"Inspect the Skia route"}]}}
        ),
      ),
    ),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "1 分叉"))
  assert_true(has_text(commands, "可分叉消息"))
  assert_true(has_text(commands, "Inspect the Skia route"))
  assert_true(has_text(commands, "分支"))
}

///|
test "workbench queues Pi fork from selected message entry" {
  let model = WorkbenchModel::new().update(ForkFromMessage("entry-user-1"))
  inspect(model.last_status, content="Pi fork queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[1] {
    ForkRpcSession(session, entry_id) => {
      inspect(session, content="moui-skia")
      inspect(entry_id, content="entry-user-1")
    }
    _ => fail("expected queued fork command")
  }
  assert_true(model.events.any(event => event.title == "Pi fork queued"))
}

///|
test "workbench fork runtime effect refreshes Pi state after accepted fork" {
  let captured : Ref[Array[Array[PiTransportCommand]]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val.push(commands)
    emit(ProcessStarted("fixture-pid"))
    match commands[0] {
      ForkRpcSession(_, _) => {
        emit(
          JsonLineSent(
            "moui-skia", "{\"type\":\"fork\",\"entryId\":\"entry-user-1\"}",
          ),
        )
        emit(
          JsonLineReceived(
            "moui-skia", "{\"type\":\"response\",\"command\":\"fork\",\"success\":true,\"data\":{\"text\":\"Inspect the Skia route\",\"cancelled\":false}}",
          ),
        )
      }
      StartRpc(_, _) => {
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_available_models\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_messages\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_fork_messages\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_commands\"}"))
        emit(JsonLineSent("moui-skia", "{\"type\":\"get_session_stats\"}"))
        emit(
          JsonLineReceived(
            "moui-skia",
            (
              #|{"type":"response","command":"get_state","success":true,"data":{"model":{"id":"gpt-5","provider":"openai"},"sessionId":"019e81f0","sessionFile":"/tmp/mo-workbench-fork.jsonl","sessionName":"Mo Workbench fork","messageCount":1,"pendingMessageCount":0}}
            ),
          ),
        )
      }
      _ => emit(TransportFailed("unexpected fork command batch"))
    }
  })
  let update = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("fixture-pid")))
    .update_with_transport(ForkFromMessage("entry-user-1"), transport)
  inspect(update.model.pending_transport_count(), content="1")
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="2")
  match captured.val[0][0] {
    ForkRpcSession(session, entry_id) => {
      inspect(session, content="moui-skia")
      inspect(entry_id, content="entry-user-1")
    }
    _ => fail("expected captured fork request")
  }
  inspect(captured.val[1].length(), content="6")
  match captured.val[1][3] {
    FetchRpcForkMessages(session) => inspect(session, content="moui-skia")
    _ => fail("expected captured fork messages refresh")
  }
  inspect(model.pending_transport_count(), content="0")
  let binding = model.active_pi_session_binding()
  inspect(binding.rpc_session_id, content="019e81f0")
  inspect(binding.session_file, content="/tmp/mo-workbench-fork.jsonl")
  inspect(binding.session_name, content="Mo Workbench fork")
  inspect(binding.status, content="bound")
  inspect(binding.last_command, content="get_state")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(model.events.any(event => event.title == "Pi fork accepted"))
  assert_true(
    model.events.any(event => event.title == "Pi fork refresh queued"),
  )
}

///|
test "workbench fork cancellation does not refresh Pi state" {
  let captured : Ref[Array[Array[PiTransportCommand]]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val.push(commands)
    emit(ProcessStarted("fixture-pid"))
    emit(
      JsonLineSent(
        "moui-skia", "{\"type\":\"fork\",\"entryId\":\"entry-user-1\"}",
      ),
    )
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"fork\",\"success\":true,\"data\":{\"text\":\"Inspect the Skia route\",\"cancelled\":true}}",
      ),
    )
  })
  let update = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("fixture-pid")))
    .update_with_transport(ForkFromMessage("entry-user-1"), transport)
  let model = run_workbench_effect_with_transport(update, transport)
  inspect(captured.val.length(), content="1")
  inspect(captured.val[0].length(), content="1")
  inspect(model.pending_transport_count(), content="0")
  let binding = model.active_pi_session_binding()
  inspect(binding.status, content="cancelled")
  inspect(binding.last_command, content="fork")
  inspect(model.last_status, content="Pi fork cancelled")
}

///|
test "workbench queues Pi session HTML export through platform-neutral commands" {
  let model = WorkbenchModel::new().update(ExportSessionHtml)
  inspect(model.last_status, content="Pi HTML export queued")
  inspect(model.pending_transport_count(), content="2")
  match model.transport.command_queue[0] {
    StartRpc(session, cwd) => {
      inspect(session, content="moui-skia")
      inspect(cwd, content="/Volumes/Data/Code/moon/MoUI")
    }
    _ => fail("expected queued session start")
  }
  match model.transport.command_queue[1] {
    ExportRpcSessionHtml(session, path) => {
      inspect(session, content="moui-skia")
      inspect(path, content="")
    }
    _ => fail("expected queued HTML export")
  }
  assert_true(model.events.any(event => event.title == "Pi HTML export queued"))
}

///|
test "workbench HTML export runtime effect dispatches export command" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"export_html\"}"))
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"export_html\",\"success\":true,\"data\":{\"path\":\"/tmp/mo-workbench-export.html\"}}",
      ),
    )
  })
  let update = WorkbenchModel::new().update_with_transport(
    ExportSessionHtml,
    transport,
  )
  let model = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    ExportRpcSessionHtml(session, path) => {
      inspect(session, content="moui-skia")
      inspect(path, content="")
    }
    _ => fail("expected captured HTML export")
  }
  inspect(model.pending_transport_count(), content="0")
  inspect(model.files.length(), content="1")
  inspect(model.files[0].path, content="/tmp/mo-workbench-export.html")
  inspect(model.files[0].change_kind, content="export")
  inspect(model.last_status, content="Pi session exported")
}

///|
test "workbench ingests Pi RPC export_html response into workspace evidence" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia",
        (
          #|{"type":"response","command":"export_html","success":true,"data":{"path":"/tmp/mo-workbench-export.html"}}
        ),
      ),
    ),
  )
  inspect(model.pi_rpc.command, content="export_html")
  inspect(model.pi_rpc.success, content="true")
  inspect(model.files.length(), content="1")
  inspect(model.files[0].id, content="pi-export-moui-skia")
  inspect(model.files[0].path, content="/tmp/mo-workbench-export.html")
  inspect(model.files[0].summary, content="Pi session HTML export")
  inspect(model.files[0].change_kind, content="export")
  inspect(model.last_status, content="Pi session exported")
  assert_true(model.events.any(event => event.title == "Pi session exported"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "1 文件"))
  assert_true(has_text(commands, "/tmp/mo-workbench-export.html"))
  assert_true(has_text(commands, "Pi session HTML export"))
}

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
  inspect(model.open_diagnostic_count(), content="1")
  let cleared = model.update(ClearDiagnostics)
  inspect(cleared.open_diagnostic_count(), content="0")
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
    content="MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native",
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
        content="MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native",
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
  inspect(model.transport.status_label(), content="Running")
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
  inspect(model.transport.status_label(), content="Running")
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
  match command.exit_code {
    Some(code) => inspect(code, content="0")
    None => fail("expected command exit code")
  }
  inspect(model.pi_rpc.command, content="bash")
  inspect(model.last_status, content="Pi bash response applied")
  assert_true(model.events.any(event => event.title == "Pi bash completed"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "输出 /tmp/mo-workbench-bash.log"))
  assert_true(has_text(commands, "分析"))
  assert_true(has_text(commands, "重跑"))
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
        "moui-skia", "{\"type\":\"bash\",\"command\":\"MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native\"}",
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
  inspect(
    model.commands[1].command,
    content="moon test examples/mo_workbench/app --target wasm-gc",
  )
  inspect(model.commands[1].status, content="failed")
  inspect(model.commands[1].output_path, content="/tmp/mo-workbench-wasm.log")
  inspect(
    model.commands[2].command,
    content="moon build examples/mo_workbench/macos_skia --target native",
  )
  inspect(model.commands[2].status, content="passed")
  inspect(model.commands[2].output_path, content="/tmp/mo-workbench-skia.log")
  inspect(
    model.commands[3].command,
    content="MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native",
  )
  inspect(model.commands[3].status, content="passed")
  inspect(
    model.commands[3].output_path,
    content="/tmp/mo-workbench-first-frame.log",
  )
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
  inspect(model.active_session().active_task, content="Pi thinking level: high")
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
test "workbench selection with transport switches Pi session then refreshes state, models, fork points, commands, and stats" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = WorkbenchModel::new().update_with_transport(
    SelectSession("pi-rpc"),
    transport,
  )
  inspect(update.model.selected_session_id, content="pi-rpc")
  inspect(update.model.pending_transport_count(), content="7")
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
test "workbench runtime draws latest activity event" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(ProcessStarted("4242")),
  )
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "1 事件"))
  assert_true(has_text(commands, "Pi RPC process started"))
  assert_true(has_text(commands, "pid 4242"))
  assert_true(has_text(commands, "跟进"))
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
  assert_true(has_text(commands, "1 文件"))
  assert_true(has_text(commands, "1 诊断"))
  assert_true(has_text(commands, "requires_review"))
  assert_true(has_text(commands, "6 文件 · +180 -12"))
  assert_true(has_text(commands, "聚焦"))
  assert_true(has_text(commands, "审核"))
  assert_true(has_text(commands, "清除"))
  assert_true(has_text(commands, "修复"))
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
  inspect(model.active_session().active_task, content="Pi plan: Fix Skia smoke")
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
  assert_true(has_text(commands, "1 诊断"))
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
  inspect(session.summary, content="Pi RPC session 019e7eb5 on openai/gpt-5")
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
  assert_true(has_text(commands, "2 条"))
  assert_true(has_text(commands, "Inspect the Skia route"))
  assert_true(has_text(commands, "Skia route inspected"))
  assert_true(has_text(commands, "跟进"))
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
  assert_false(has_text(commands, "上下文"))
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
    content="Pi model: GPT-5 (openai/gpt-5)",
  )
  inspect(
    model.active_session().summary,
    content="Pi model set to GPT-5 (openai/gpt-5)",
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
  inspect(model.active_session().active_task, content="Pi model: openai/gpt-5")
  inspect(
    model.active_session().summary,
    content="Pi model switched to openai/gpt-5",
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
  inspect(model.active_session().active_task, content="Pi context compacted")
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
    content="Pi stats: 10 messages, 4 tools, 1340 tokens",
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
  inspect(session.summary, content="Pi RPC session 019e7ed4 on openai/gpt-5")
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
test "workbench draws Pi session binding identity after get_state" {
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
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Pi 会话：已绑定 · Mo Workbench smoke"))
  assert_true(has_text(commands, "模型：openai/gpt-5"))
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
test "workbench activity draws recent command evidence" {
  let model = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="stale command",
        cwd="/repo",
        status="passed",
      ),
      CommandRun::new(
        id=2,
        command="native check",
        cwd="/repo",
        status="passed",
      ),
      CommandRun::new(
        id=3,
        command="wasm check",
        cwd="/repo",
        status="failed",
        exit_code=Some(2),
        output_path="/tmp/wasm-check.log",
      ),
      CommandRun::new(id=4, command="skia build", cwd="/repo", status="queued"),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "native check"))
  assert_true(has_text(commands, "wasm check"))
  assert_true(has_text(commands, "skia build"))
  assert_true(has_text(commands, "输出 /tmp/wasm-check.log"))
  assert_true(has_text(commands, "退出码 2"))
  assert_true(has_text(commands, "分析"))
  assert_true(has_text(commands, "修复"))
  assert_true(has_text(commands, "重跑"))
  assert_false(has_text(commands, "stale command"))
}

///|
test "workbench focused check batch stays visible in activity evidence" {
  let model = WorkbenchModel::new().update(QueueFocusedChecks)
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(
    has_text(commands, "moon test examples/mo_workbench/app --target native"),
  )
  assert_true(
    has_text(commands, "moon test examples/mo_workbench/app --target wasm-gc"),
  )
  assert_true(
    has_text(
      commands, "moon build examples/mo_workbench/macos_skia --target native",
    ),
  )
  assert_true(
    has_text(
      commands, "MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/mo_workbench/macos_skia --target native",
    ),
  )
}

///|
test "workbench current session draws diagnostic next action" {
  let model = {
    ..WorkbenchModel::new(),
    diagnostics: [
      DiagnosticItem::new(
        source="moon check",
        severity="error",
        message="unused variable in app.mbt",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "修复最新诊断"))
  assert_true(has_text(commands, "moon check: unused variable in app.mbt"))
  assert_true(has_text(commands, "修复"))
  assert_true(has_text(commands, "清除"))
}

///|
test "workbench current session prioritizes failed command next action" {
  let model = {
    ..model_with_reviewable_diff(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon test examples/mo_workbench/app --target native",
        cwd="/Volumes/Data/Code/moon/MoUI",
        status="failed",
        exit_code=Some(1),
        output_path="/tmp/mo-workbench-test.log",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "修复失败命令"))
  assert_true(has_text(commands, "修复"))
  assert_true(
    has_text(commands, "moon test examples/mo_workbench/app --target native"),
  )
  assert_true(draw_text_count_containing(commands, "退出码 1") >= 2)
  assert_true(
    draw_text_count_containing(commands, "输出 /tmp/mo-workbench-test.log") >=
    2,
  )
  assert_false(has_text(commands, "审核当前变更"))
}

///|
test "workbench failed command fix actions carry exit code evidence" {
  let failed = CommandRun::new(
    id=1,
    command="moon test examples/mo_workbench/app --target native",
    cwd="/Volumes/Data/Code/moon/MoUI",
    status="failed",
    exit_code=Some(1),
    output_path="/tmp/mo-workbench-test.log",
  )
  let model = { ..WorkbenchModel::new(), commands: [failed] }
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let runtime = model.runtime_with_transport(
    transport,
    width=1220.0,
    height=780.0,
  )
  click_text(runtime, "修复")
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Fix failed command moon test examples/mo_workbench/app --target native using output /tmp/mo-workbench-test.log (status failed, exit code 1, cwd /Volumes/Data/Code/moon/MoUI)",
        ),
      )
    }
    _ => fail("expected clicked command fix prompt")
  }
}

///|
test "workbench activity failed command fix carries exit code evidence" {
  let running = CommandRun::new(
    id=1,
    command="moon check",
    cwd="/Volumes/Data/Code/moon/MoUI",
    status="running",
  )
  let failed = CommandRun::new(
    id=2,
    command="moon test examples/mo_workbench/app --target wasm-gc",
    cwd="/Volumes/Data/Code/moon/MoUI",
    status="failed",
    exit_code=Some(2),
    output_path="/tmp/mo-workbench-wasm.log",
  )
  let model = { ..WorkbenchModel::new(), commands: [running, failed] }
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let runtime = model.runtime_with_transport(
    transport,
    width=1220.0,
    height=780.0,
  )
  click_text(runtime, "修复")
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Fix failed command moon test examples/mo_workbench/app --target wasm-gc using output /tmp/mo-workbench-wasm.log (status failed, exit code 2, cwd /Volumes/Data/Code/moon/MoUI)",
        ),
      )
    }
    _ => fail("expected clicked activity command fix prompt")
  }
}

///|
test "workbench command evidence analysis carries exit code evidence" {
  let command = CommandRun::new(
    id=1,
    command="moon test examples/mo_workbench/app --target native",
    cwd="/Volumes/Data/Code/moon/MoUI",
    status="passed",
    exit_code=Some(0),
    output_path="/tmp/mo-workbench-test.log",
  )
  let model = {
    ..WorkbenchModel::new(),
    commands: [command],
    plan: [
      PlanStep::new(
        id="active",
        title="Keep next action off command evidence",
        status="in_progress",
        owner="Pi",
        detail="Inspect activity row only",
      ),
    ],
  }
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let runtime = model.runtime_with_transport(
    transport,
    width=1220.0,
    height=780.0,
  )
  click_text(runtime, "分析")
  inspect(captured.val.length(), content="2")
  match captured.val[1] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(
        text,
        content=context_task_payload(
          "Inspect command output for moon test examples/mo_workbench/app --target native: /tmp/mo-workbench-test.log (status passed, exit code 0, cwd /Volumes/Data/Code/moon/MoUI)",
        ),
      )
    }
    _ => fail("expected clicked command evidence prompt")
  }
}

///|
test "workbench current session prioritizes failed command over bash diagnostic" {
  let model = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon test examples/mo_workbench/app --target native",
        cwd="/Volumes/Data/Code/moon/MoUI",
        status="failed",
        exit_code=Some(2),
        output_path="/tmp/mo-workbench-native.log",
      ),
    ],
    diagnostics: [
      DiagnosticItem::new(
        source="Pi bash",
        severity="error",
        message="bash exited with code 2",
      ),
    ],
  }
  inspect(model.diagnostics.length(), content="1")
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "修复失败命令"))
  assert_true(
    has_text(commands, "moon test examples/mo_workbench/app --target native"),
  )
  assert_true(draw_text_count_containing(commands, "退出码 2") >= 2)
  assert_true(
    draw_text_count_containing(commands, "输出 /tmp/mo-workbench-native.log") >=
    2,
  )
}

///|
test "workbench active command still prioritizes cancellation before failed evidence" {
  let model = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon test examples/mo_workbench/app --target native",
        cwd="/Volumes/Data/Code/moon/MoUI",
        status="running",
      ),
      CommandRun::new(
        id=2,
        command="moon test examples/mo_workbench/app --target wasm-gc",
        cwd="/Volumes/Data/Code/moon/MoUI",
        status="failed",
        exit_code=Some(2),
        output_path="/tmp/mo-workbench-wasm.log",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "等待 Pi 完成当前运行"))
  assert_false(has_text(commands, "修复失败命令"))
}

///|
test "workbench current session prioritizes active plan before diff next action" {
  let model = {
    ..model_with_reviewable_diff(),
    plan: [
      PlanStep::new(
        id="fix",
        title="Fix Skia smoke",
        status="in_progress",
        owner="Pi",
        detail="Run focused checks",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "继续当前计划"))
  assert_true(has_text(commands, "进行中 · Run focused checks"))
  assert_false(has_text(commands, "审核当前变更"))
}

///|
test "workbench current session draws diff next action" {
  let commands = model_with_reviewable_diff()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "下一步"))
  assert_true(has_text(commands, "审核当前变更"))
  assert_true(has_text(commands, "ready for review · 5 文件 · +160 -10"))
}

///|
test "workbench wide shell renders workflow rail from live evidence" {
  let model = {
    ..WorkbenchModel::new(),
    plan: [
      PlanStep::new(
        id="draft",
        title="整理功能亮点",
        status="done",
        owner="通用",
        detail="收集 Pi RPC 证据",
      ),
      PlanStep::new(
        id="merge",
        title="合并最终输出",
        status="in_progress",
        owner="校验",
        detail="对齐 Skia native route",
      ),
    ],
    files: [
      FileContext::new(
        id="rail",
        path="examples/mo_workbench/app/view_helpers.mbt",
        summary="Workflow rail view composition",
        change_kind="modified",
        lines_changed=120,
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "进度"))
  assert_true(has_text(commands, "1/2 完成"))
  assert_true(has_text(commands, "整理功能亮点"))
  assert_true(has_text(commands, "合并最终输出"))
  assert_true(has_text(commands, "执行"))
  assert_false(has_text(commands, "Agents"))
  assert_true(has_text(commands, "计划所有者"))
  assert_true(has_text(commands, "通用"))
  assert_true(has_text(commands, "校验"))
  assert_true(has_text(commands, "工作文件夹"))
  assert_true(has_text(commands, "MoUI Skia renderer"))
  assert_true(has_text(commands, "examples/mo_workbench/app/view_helpers.mbt"))
  assert_true(has_text(commands, "Workflow rail view composition"))
  assert_true(has_text(commands, "聚焦"))
}

///|
test "workbench compact shell keeps workflow rail collapsed" {
  let commands = @app.runtime(width=960.0, height=640.0).draw_commands()
  assert_false(has_text(commands, "进度"))
  assert_false(has_text(commands, "工作文件夹"))
}

///|
test "workbench runtime draws agent desktop shell" {
  let commands = @app.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "Pi agent 桌面工作台"))
  assert_true(has_text(commands, "当前会话"))
  assert_true(has_text(commands, "MoUI"))
  assert_false(has_text(commands, "活跃"))
  assert_true(has_text(commands, "Pi RPC harness"))
  assert_false(has_text(commands, "排队"))
  assert_false(has_text(commands, "空闲"))
  assert_false(has_text(commands, "Agents"))
  assert_false(has_text(commands, "执行"))
  assert_false(has_text(commands, "Agent"))
  assert_false(has_text(commands, "焦点"))
  assert_false(has_text(commands, "通用"))
  assert_false(has_text(commands, "编码"))
  assert_false(has_text(commands, "校验"))
  assert_false(has_text(commands, "协调"))
  assert_false(has_text(commands, "实现"))
  assert_false(has_text(commands, "检查"))
  assert_true(has_text(commands, "新会话"))
  assert_true(has_text(commands, "刷新"))
  assert_false(has_text(commands, "Pi 运行状态"))
  assert_false(has_text(commands, "上下文"))
  assert_false(has_text(commands, "仓库"))
  assert_false(has_text(commands, "示例"))
  assert_false(has_text(commands, "证据"))
  assert_false(has_text(commands, "会话"))
  assert_false(has_text(commands, "发送"))
  assert_false(has_text(commands, "会话记录"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "Pi RPC"))
  assert_false(has_text(commands, "/Volumes/Data/Code/moon/MoUI"))
  assert_false(has_text(commands, "/Volumes/Data/Code/moon/pi"))
  assert_false(has_text(commands, "active"))
  assert_false(has_text(commands, "queued"))
  assert_false(has_text(commands, "未连接"))
  assert_false(has_text(commands, "进度"))
  assert_false(has_text(commands, "工作文件夹"))
  assert_false(has_text(commands, "等待 Pi 计划更新"))
  assert_false(has_text(commands, "等待活动"))
  assert_false(has_text(commands, "等待 Pi 文件证据"))
  assert_false(has_text(commands, "找分叉"))
  assert_false(has_text(commands, "导出"))
  assert_false(has_text(commands, "压缩"))
  assert_false(has_text(commands, "思考"))
  assert_false(has_text(commands, "同步名"))
  assert_false(has_text(commands, "引导 单条"))
  assert_false(has_text(commands, "跟进 单条"))
  assert_false(has_text(commands, "引导"))
  assert_false(has_text(commands, "跟进"))
  assert_false(has_text(commands, "仓库、示例"))
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "全部"))
  assert_false(has_text(commands, "Native"))
  assert_false(has_text(commands, "Wasm"))
  assert_false(has_text(commands, "构建"))
  assert_false(has_text(commands, "首帧"))
  assert_false(has_text(commands, "拆解请求、整理上下文"))
  assert_false(has_text(commands, "代码修改、测试、重构"))
  assert_false(has_text(commands, "诊断、diff、文档收口"))
  assert_false(has_text(commands, "下一步"))
  assert_false(has_text(commands, "当前计划"))
  assert_false(has_text(commands, "Session"))
  assert_false(has_text(commands, "Pi transcript"))
  assert_false(has_text(commands, "Activity"))
  assert_false(has_text(commands, "Workspace"))
  assert_false(has_text(commands, "消息 0"))
  assert_false(has_text(commands, "上下文 n/a"))
  assert_false(has_text(commands, "Queue 0"))
  assert_false(has_text(commands, "0 排队"))
  assert_false(has_text(commands, "Thinking: default"))
  assert_false(has_text(commands, "0 条"))
  assert_false(has_text(commands, "0 分叉"))
  assert_false(has_text(commands, "0 事件"))
  assert_false(has_text(commands, "0 诊断"))
  assert_false(has_text(commands, "0 文件"))
  assert_false(has_text(commands, "0 运行"))
  assert_false(has_text(commands, "0 命令"))
  assert_false(has_text(commands, "/review"))
  assert_false(has_text(commands, "分析"))
  assert_false(has_text(commands, "重跑"))
  assert_false(has_text(commands, "分支"))
  assert_false(has_text(commands, "输出 /tmp/mo-workbench-app-test.log"))
  assert_false(has_text(commands, "清除"))
  assert_false(has_text(commands, "聚焦"))
  assert_false(has_text(commands, "审核"))
  assert_false(has_text(commands, "运行"))
  assert_false(has_text(commands, "停止"))
  assert_false(has_text(commands, "Pi: unbound"))
  assert_false(has_text(commands, "RPC 通道：未连接"))
  assert_false(has_text(commands, "Pi 运行：空闲"))
  assert_false(has_text(commands, "Pi RPC + macOS Skia dogfood."))
  assert_false(has_text(commands, "要求继续推进 Mo Workbench"))
  assert_false(has_text(commands, "Product"))
  assert_false(has_text(commands, "No description"))
  assert_false(has_text(commands, "-"))
  assert_false(has_text(commands, "验证已通过："))
  assert_false(has_text(commands, "打开方式⌄"))
  assert_false(has_text(commands, "复制"))
  assert_false(has_text(commands, "修复"))
  assert_false(has_text(commands, "Research notebook"))
  assert_false(has_text(commands, "Skia native"))
}

///|
test "workbench session chrome shows only signal-bearing status" {
  let queued_model = {
    ..WorkbenchModel::new(),
    selected_session_id: "queued-slice",
    sessions: [
      WorkbenchSession::new(
        id="queued-slice",
        title="Queued validation",
        project_path="/Volumes/Data/Code/moon/MoUI",
        branch="codex/mo-workbench",
        status="queued",
        summary="Focused checks are waiting.",
        active_task="",
        unread_events=1,
      ),
    ],
  }
  let commands = queued_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "Queued validation"))
  assert_true(has_text(commands, "排队"))
}

///|
test "workbench sidebar transport status appears only when useful" {
  let idle = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(idle, "Pi RPC"))
  assert_false(has_text(idle, "未连接"))
  let queued = WorkbenchModel::new()
    .update(QueueCommand("moon check"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(queued, "Pi RPC"))
  assert_true(has_text(queued, "启动中"))
  let running = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(running, "运行中"))
  let failed = WorkbenchModel::new()
    .update(ReceiveTransport(TransportFailed("pi unavailable")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(failed, "失败：pi unavailable"))
}

///|
test "workbench evidence panels mount only when content arrives" {
  let empty = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(empty, "会话记录"))
  assert_false(has_text(empty, "运行证据"))
  assert_false(has_text(empty, "工作区证据"))
  let transcript_model = {
    ..WorkbenchModel::new(),
    transcript: [
      TranscriptItem::new(
        id="assistant",
        role="assistant",
        summary="Pi summarized the fix",
        detail="Use the shared app state only.",
        tone="success",
      ),
    ],
  }
  let transcript = transcript_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(transcript, "会话记录"))
  assert_true(has_text(transcript, "Pi summarized the fix"))
  assert_false(has_text(transcript, "运行证据"))
  assert_false(has_text(transcript, "工作区证据"))
  let activity_model = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon test examples/mo_workbench/app --target native",
        cwd="/repo",
        status="passed",
      ),
    ],
  }
  let activity = activity_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(activity, "运行证据"))
  assert_true(
    has_text(activity, "moon test examples/mo_workbench/app --target native"),
  )
  assert_false(has_text(activity, "会话记录"))
  assert_false(has_text(activity, "工作区证据"))
  let workspace_model = model_with_reviewable_diff()
  let workspace = workspace_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(workspace, "工作区证据"))
  assert_true(has_text(workspace, "5 文件 · +160 -10"))
  assert_false(has_text(workspace, "会话记录"))
}

///|
test "workbench composer keeps ordinary prompts low noise" {
  let commands = WorkbenchModel::new()
    .update(PromptChanged("Run focused checks"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "选项"))
  assert_true(has_text(commands, "发送"))
  assert_false(has_text(commands, "上下文"))
  assert_false(has_text(commands, "焦点"))
  assert_false(has_text(commands, "引导 单条"))
  assert_false(has_text(commands, "跟进 单条"))
  assert_false(has_text(commands, "引导"))
  assert_false(has_text(commands, "跟进"))
}

///|
test "workbench composer reveals secondary actions after options expand" {
  let commands = WorkbenchModel::new()
    .update(PromptChanged("Run focused checks"))
    .update(ToggleComposerControls)
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "上下文"))
  assert_true(has_text(commands, "仓库"))
  assert_true(has_text(commands, "示例"))
  assert_true(has_text(commands, "证据"))
  assert_true(has_text(commands, "会话"))
  assert_true(has_text(commands, "引导 单条"))
  assert_true(has_text(commands, "跟进 单条"))
  assert_true(has_text(commands, "引导"))
  assert_true(has_text(commands, "跟进"))
  assert_true(has_text(commands, "收起"))
  assert_true(has_text(commands, "发送"))
}

///|
test "workbench composer reveals context chips for non-default context" {
  let commands = WorkbenchModel::new()
    .update(ToggleContext("evidence"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "上下文"))
  assert_true(has_text(commands, "仓库"))
  assert_true(has_text(commands, "示例"))
  assert_true(has_text(commands, "证据"))
  assert_true(has_text(commands, "会话"))
}

///|
test "workbench composer reveals agent focus controls in options" {
  let commands = WorkbenchModel::new()
    .update(PromptChanged("Implement the focused slice"))
    .update(ToggleComposerControls)
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "焦点"))
  assert_false(has_text(commands, "Agent"))
  assert_true(has_text(commands, "通用"))
  assert_true(has_text(commands, "编码"))
  assert_true(has_text(commands, "校验"))
  assert_false(has_text(commands, "协调"))
  assert_false(has_text(commands, "实现"))
  assert_false(has_text(commands, "检查"))
}

///|
test "workbench transcript renders long assistant replies as readable lines" {
  let detail = long_assistant_reply()
  let item = TranscriptItem::new(
    id="assistant-long",
    role="assistant",
    summary="Pi readable reply",
    detail~,
    tone="success",
  )
  let model = { ..WorkbenchModel::new(), transcript: [item] }
  let commands = model.runtime(width=960.0, height=640.0).draw_commands()
  assert_true(has_text(commands, "Pi readable reply"))
  assert_true(draw_text_count_containing(commands, "Pi reply block alpha") >= 2)
  assert_false(has_text(commands, detail))
}

///|
test "workbench main workflow shows and moves visible scrollbar" {
  let runtime = model_with_overflowing_transcript().runtime(
    width=960.0,
    height=640.0,
  )
  guard main_scrollbar_thumb_frame(runtime.draw_commands()) is Some(before) else {
    fail("expected visible main scrollbar before scroll")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=before.origin.x - 80.0,
          y=before.origin.y + 24.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-240.0),
      ),
    ),
  )
  guard main_scrollbar_thumb_frame(runtime.draw_commands()) is Some(after) else {
    fail("expected visible main scrollbar after scroll")
  }
  assert_true(after.origin.y > before.origin.y)
}

///|
test "workbench shell adapts to runtime viewport resize" {
  let runtime = @app.runtime(width=960.0, height=640.0)
  guard first_surface_frame(runtime.draw_commands()) is Some(compact_frame) else {
    fail("expected root surface frame before resize")
  }
  inspect(compact_frame.size.width, content="960")
  inspect(compact_frame.size.height, content="640")
  assert_true(has_text(runtime.draw_commands(), "当前会话"))
  runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width=1440.0, height=900.0)),
  )
  guard first_surface_frame(runtime.draw_commands()) is Some(expanded_frame) else {
    fail("expected root surface frame after resize")
  }
  inspect(expanded_frame.size.width, content="1440")
  inspect(expanded_frame.size.height, content="900")
  assert_true(has_text(runtime.draw_commands(), "当前会话"))
}

///|
test "workbench composer displays selected agent focus in context summary" {
  let model = WorkbenchModel::new().update(SelectAgent("coding"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "仓库、示例、焦点 编码"))
}

///|
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
  }
  model.get()
}
