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
  inspect(model.pi_agent.display_status_label(), content="queue pending · 排队 3")
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
