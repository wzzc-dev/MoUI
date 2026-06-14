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
