///|
test "workbench transport runtime effect dispatches prompt events" {
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, emit) => {
    captured.val = commands
    emit(ProcessStarted("fixture-pid"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"get_state\"}"))
    emit(JsonLineSent("moui-skia", "{\"type\":\"prompt\"}"))
    emit(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"prompt\",\"success\":true}",
      ),
    )
  })
  let update = WorkbenchModel::new()
    .update(PromptChanged("Summarize the staged diff"))
    .update_with_transport(DispatchPrompt, transport)
  inspect(captured.val.length(), content="0")
  inspect(update.model.pending_transport_count(), content="2")
  let summary = @runtime.effect_plan_summary(update.effect)
  inspect(summary.descriptors.length(), content="1")
  inspect(summary.descriptors[0].key(), content="pi-transport:dispatch")
  inspect(summary.descriptors[0].kind(), content="transport")
  inspect(summary.descriptors[0].label(), content="Pi transport dispatch")
  let accepted = run_workbench_effect(update)
  inspect(captured.val.length(), content="2")
  let refresh = accepted.update_with_transport(
    ReceiveTransport(
      JsonLineReceived(
        "moui-skia", "{\"type\":\"response\",\"command\":\"prompt\",\"success\":true}",
      ),
    ),
    transport,
  )
  let model = refresh.model
  inspect(model.pending_transport_count(), content="3")
  inspect(
    model.transport.last_json_line,
    content="{\"type\":\"response\",\"command\":\"prompt\",\"success\":true}",
  )
  inspect(model.last_status, content="Pi transcript refresh queued")
  assert_true(
    model.events.any(event => event.title == "Pi transcript refresh queued"),
  )
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
test "workbench transport effect interprets only pure update queue delta" {
  let seed = WorkbenchModel::new().update(QueueCommand("moon check"))
  inspect(seed.pending_transport_count(), content="2")
  let captured : Ref[Array[PiTransportCommand]] = Ref([])
  let transport = PiTransportRuntime::new(run=(commands, _emit) => {
    captured.val = commands
  })
  let update = seed.update_with_transport(
    QueueCommand("moon test examples/mo_workbench/app --target native"),
    transport,
  )
  inspect(update.model.pending_transport_count(), content="3")
  inspect(captured.val.length(), content="0")
  ignore(run_workbench_effect(update))
  inspect(captured.val.length(), content="1")
  match captured.val[0] {
    RunShellCommand(session, command) => {
      inspect(session, content="moui-skia")
      inspect(
        command,
        content="moon test examples/mo_workbench/app --target native",
      )
    }
    _ => fail("expected one newly queued shell command")
  }
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

  let fixture_steering = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(PromptChanged("Prefer the local route"))
    .update(DispatchSteering)
  inspect(
    fixture_steering.last_status,
    content="Agent backend does not support input modes",
  )
  inspect(fixture_steering.pending_transport_count(), content="0")
  inspect(fixture_steering.transcript.length(), content="0")
  assert_false(
    fixture_steering.events.any(event => event.title == "Steering input queued"),
  )

  let fixture_follow_up = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(PromptChanged("Follow up locally"))
    .update(DispatchFollowUp)
  inspect(
    fixture_follow_up.last_status,
    content="Agent backend does not support input modes",
  )
  inspect(fixture_follow_up.pending_transport_count(), content="0")
  inspect(fixture_follow_up.transcript.length(), content="0")
  assert_false(
    fixture_follow_up.events.any(event => {
      event.title == "Follow-up input queued"
    }),
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
  inspect(model.transport.display_status_label(), content="运行中")
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
  inspect(model.transport.display_status_label(), content="运行中")
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
  inspect(model.transport.display_status_label(), content="运行中")
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
  inspect(model.transport.display_status_label(), content="运行中")
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
  inspect(model.transport.display_status_label(), content="运行中")
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
  inspect(model.transport.display_status_label(), content="运行中")
}
