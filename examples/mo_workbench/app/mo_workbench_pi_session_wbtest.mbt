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
  inspect(model.transport.display_status_label(), content="运行中")
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
  let model = WorkbenchModel::new()
    .update(
      ReceiveTransport(
        JsonLineReceived(
          "moui-skia",
          (
            #|{"type":"response","command":"get_messages","success":true,"data":{"messages":[{"entryId":"entry-user-1","role":"user","content":"Inspect the Skia route","timestamp":1},{"entryId":"entry-assistant-1","role":"assistant","content":"Skia route inspected","timestamp":2}]}}
          ),
        ),
      ),
    )
    .update(
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
  assert_false(has_text(commands, "会话记录"))
  assert_true(has_text(commands, "Inspect the Skia route"))
  assert_true(has_text(commands, "Skia route inspected"))
  assert_true(has_text(commands, "分叉"))
  assert_false(has_text(commands, "跟进这条消息"))
  assert_false(has_text(commands, "可从此处分叉"))
  assert_false(has_text(commands, "分支"))
  assert_true(fork_affordance_follows_text(commands, "Skia route inspected"))
}

///|
test "workbench unmatched fork candidates stay hidden until refresh matches them" {
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
    ],
    fork_messages: [
      PiForkMessage::new(entry_id="missing-entry", text="Detached fork point"),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_false(has_text(commands, "未匹配分叉候选 · 1 条"))
  assert_false(has_text(commands, "Detached fork point"))
  assert_false(has_text(commands, "可从此处分叉"))
  assert_false(has_text(commands, "分叉"))
}

///|
test "workbench fork candidates anchor by matching text when ids differ" {
  let model = {
    ..WorkbenchModel::new(),
    transcript: [
      TranscriptItem::new(
        id="user-0",
        role="user",
        summary="Context: repo, examples  Task: 你好",
        detail="",
        tone="info",
      ),
      TranscriptItem::new(
        id="assistant-0",
        role="assistant",
        summary="你好，已检查上下文",
        detail="",
        tone="success",
      ),
    ],
    fork_messages: [
      PiForkMessage::new(
        entry_id="entry-user-1",
        text="Context: repo, examples  Task: 你好",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_false(has_text(commands, "可从此处分叉"))
  assert_true(has_text(commands, "分叉"))
  assert_true(
    fork_affordance_follows_text(commands, "你好，已检查上下文"),
  )
  assert_false(has_text(commands, "未匹配分叉候选 · 1 条"))
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
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "1 文件"))
  assert_true(has_text(commands, "/tmp/mo-workbench-export.html"))
  assert_true(has_text(commands, "Pi session HTML export"))
  assert_false(has_text(commands, "工作区证据"))
}
