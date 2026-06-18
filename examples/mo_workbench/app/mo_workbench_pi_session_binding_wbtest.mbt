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
  inspect(binding.as_agent_session_binding().display_status_label(), content="后端会话：Mo Workbench smoke")
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
