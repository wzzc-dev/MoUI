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
  inspect(model.pi_rpc.model, content="openai/gpt-5")
  inspect(model.pi_rpc.message_count, content="4")
  inspect(model.pi_rpc.pending_message_count, content="1")
  let session = model.active_session()
  inspect(session.status, content="running")
  inspect(session.unread_events, content="1")
  inspect(session.summary, content="Pi RPC session 019e7eb5 on openai/gpt-5")
  inspect(model.last_status, content="Pi RPC response applied")
  assert_true(
    model.events.any(event => event.title == "Pi RPC response: get_state"),
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
  assert_true(has_text(commands, "新对话"))
  assert_true(has_text(commands, "置顶"))
  assert_true(
    has_text(
      commands, "在 MoUI 仓库 examples/mo_workbench，交付 Mo Workbench",
    ),
  )
  assert_true(has_text(commands, "验证已通过："))
  assert_true(has_text(commands, "examples.md"))
  assert_true(has_text(commands, "已编辑 5 个文件"))
  assert_true(has_text(commands, "要求后续变更"))
  assert_true(has_text(commands, "自动审查"))
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
