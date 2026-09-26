///|
/// 执行状态机测试：确认闸门（暂停/确认/拒绝）、有界重试、Tick 超时、取消、
/// 无 UI 确定性运行、绿旗时刻相关推进、AutoRun 阻塞点、摘要截断与审计导出，
/// 以及模型步骤的确定性回复摘要（M5）。
///

///|
fn find_step(
  steps : Array[@app.StepRecord],
  kind : String,
) -> @app.StepRecord raise {
  for step in steps {
    if step.kind == kind {
      return step
    }
  }
  fail("应含 \{kind} 步骤")
}

///|
test "M5：模型步骤时间线显示确定性回复内容" {
  let specs = @app.block_catalog()
  let started = @app.start_execution(chatbot_graph())
  let model_call = find_step(started.steps, "ModelCall")
  assert_true(model_call.output_summary.contains("【友好助手】"))
  assert_true(model_call.output_summary.contains("fake-gpt-mini"))
  assert_true(model_call.input_summary.contains("prompt ← 用户提问"))
  // 非模型步骤有输出摘要；重试/超时策略仍从上游积木推导
  let show = find_step(started.steps, "ShowMarkdown")
  assert_eq(show.output_summary, "已渲染 Markdown 到界面")
  // 跑到确认点 → 确认 → 摘要带前缀
  let mut state = @app.apply_exec_event(started, Start, specs)
  let mut ticks = 0
  while state.status is Running && ticks < 50 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  assert_true(state.status is WaitingConfirmation)
  let done = @app.apply_exec_event(state, Confirm, specs)
  let completed = find_step(done.steps, "ModelCall")
  assert_true(completed.status is Completed)
  assert_true(completed.summary.contains("已确认并执行"))
  assert_true(completed.summary.contains("【友好助手】"))
}

///|
test "执行状态机：外发前暂停等待确认，确认后走到完成" {
  let specs = @app.block_catalog()
  let started = @app.start_execution(chatbot_graph())
  assert_eq(started.steps.length(), 8)
  assert_eq(started.steps[0].kind, "AppStart")
  let running = @app.apply_exec_event(started, Start, specs)
  let mut state = running
  let mut ticks = 0
  while state.status is Running && ticks < 20 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  assert_true(state.status is WaitingConfirmation)
  match state.steps[state.cursor].kind {
    "ModelCall" => ()
    _ => fail("应在 ModelCall 处等待确认")
  }
  let mut confirmed = @app.apply_exec_event(state, Confirm, specs)
  assert_true(confirmed.status is Running)
  let mut ticks2 = 0
  while confirmed.status is Running && ticks2 < 20 {
    confirmed = @app.apply_exec_event(confirmed, StepOk, specs)
    ticks2 = ticks2 + 1
  }
  assert_true(confirmed.status is Completed)
  assert_eq(confirmed.steps.filter(fn(s) { s.status is Completed }).length(), 8)
}

///|
test "执行状态机：拒绝确认不产生副作用" {
  let specs = @app.block_catalog()
  let mut state = @app.apply_exec_event(
    @app.start_execution(chatbot_graph()),
    Start,
    specs,
  )
  let mut ticks = 0
  while state.status is Running && ticks < 20 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  assert_true(state.status is WaitingConfirmation)
  let rejected = @app.apply_exec_event(state, Reject, specs)
  match rejected.status {
    Failed(_) => ()
    _ => fail("拒绝后应进入失败态")
  }
  let current = rejected.steps[rejected.cursor]
  assert_true(current.status is Failed(_))
  assert_true(rejected.steps[rejected.cursor + 1].status is Skipped)
}

///|
test "执行状态机：有界重试，上限 3 次后最终失败" {
  let specs = @app.block_catalog()
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("Retry", "重试", 0.0, 120.0)
  graph = graph.add_node("Sequence", "被重试步骤", 0.0, 240.0)
  graph = { ..graph, edges: [flow_edge(1, 2), flow_edge(2, 3)], }
  let mut state = @app.apply_exec_event(
    @app.start_execution(graph),
    Start,
    specs,
  )
  let mut ticks = 0
  while state.status is Running &&
        ticks < 10 &&
        state.steps[state.cursor].kind != "Sequence" {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  match state.steps[state.cursor].kind {
    "Sequence" => ()
    other => fail("应在 Sequence 步骤，实际 \{other}")
  }
  let mut fails = 0
  while state.status is Running && fails < 4 {
    state = @app.apply_exec_event(state, StepFail("模拟失败"), specs)
    fails = fails + 1
  }
  assert_eq(fails, 4)
  match state.status {
    Failed(_) => ()
    _ => fail("重试耗尽后应进入失败态")
  }
  assert_true(state.audit.any(fn(entry) { entry.contains("重试") }))
}

///|
test "执行状态机：Tick 超时将步骤转为失败" {
  let specs = @app.block_catalog()
  let mut graph = @app.BlockGraph::empty()
  graph = graph.add_node("AppStart", "启动", 0.0, 0.0)
  graph = graph.add_node("Timeout", "超时控制", 0.0, 120.0)
  graph = graph.add_node("ParseJson", "解析", 0.0, 240.0)
  graph = { ..graph, edges: [flow_edge(1, 2), flow_edge(2, 3)], }
  let started = @app.start_execution(graph)
  let running = @app.apply_exec_event(started, Start, specs)
  match running.steps[running.cursor].kind {
    "AppStart" => ()
    other => fail("首步应为 AppStart，实际 \{other}")
  }
  let mut state = @app.apply_exec_event(running, StepOk, specs)
  match state.steps[state.cursor].kind {
    "Timeout" => ()
    other => fail("第二步应为 Timeout，实际 \{other}")
  }
  state = @app.apply_exec_event(state, StepOk, specs)
  match state.steps[state.cursor].kind {
    "ParseJson" => ()
    other => fail("第三步应为 ParseJson，实际 \{other}")
  }
  let timed_out = @app.apply_exec_event(state, Tick(5000), specs)
  match timed_out.status {
    Failed(reason) => assert_eq(reason, "超时")
    _ => fail("超过预算应转为失败")
  }
}

///|
test "执行状态机：取消保留已完成记录" {
  let specs = @app.block_catalog()
  let mut state = @app.apply_exec_event(
    @app.start_execution(chatbot_graph()),
    Start,
    specs,
  )
  let mut ticks = 0
  while state.status is Running && ticks < 20 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  let cancelled = @app.apply_exec_event(state, Cancel, specs)
  assert_true(cancelled.status is Cancelled)
  let done_before = state.steps.filter(fn(s) { s.status is Completed }).length()
  assert_eq(
    cancelled.steps.filter(fn(s) { s.status is Completed }).length(),
    done_before,
  )
}

///|
test "无 UI 确定性运行样例图（探针 C）" {
  let specs = @app.block_catalog()
  let model = @app.Model::new()
  let mut state = @app.apply_exec_event(
    @app.start_execution(@app.GraphEditor::graph(model.editor)),
    Start,
    specs,
  )
  let mut ticks = 0
  while !(state.status is Completed) && ticks < 200 {
    state = match state.status {
      Running => @app.apply_exec_event(state, StepOk, specs)
      WaitingConfirmation => @app.apply_exec_event(state, Confirm, specs)
      _ => state
    }
    ticks = ticks + 1
  }
  assert_true(state.status is Completed)
  // 样例链含 4 个外发积木（ModelCall / StructuredModelCall × 2），全部完成
  assert_eq(state.steps.filter(fn(s) { s.status is Completed }).length(), 20)
}

///|
test "M3：AutoRun 自动推进到等待确认的阻塞点" {
  let specs = @app.block_catalog()
  let started = @app.start_execution(chatbot_graph())
  let model = step(@app.Model::new(), AutoRunExecution)
  // 样例链会一路上到第一个 WaitingConfirmation
  let mut state = @app.apply_exec_event(started, Start, specs)
  let mut ticks = 0
  while state.status is Running && ticks < 200 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  assert_true(state.status is WaitingConfirmation)
  assert_true(model.notice.contains("自动运行"))
  // 对话机器人图同样停在 ModelCall
  let mut chat = @app.apply_exec_event(
    @app.start_execution(chatbot_graph()),
    Start,
    specs,
  )
  let mut chat_ticks = 0
  while chat.status is Running && chat_ticks < 200 {
    chat = @app.apply_exec_event(chat, StepOk, specs)
    chat_ticks = chat_ticks + 1
  }
  match chat.steps[chat.cursor].kind {
    "ModelCall" => ()
    other => fail("应停在 ModelCall，实际 \{other}")
  }
}

///|
test "M3：结果截断与审计导出" {
  let long = "x".repeat(300)
  let short = @app.truncate_summary(long)
  assert_true(short.length() <= @app.summary_max_chars() + 10)
  assert_true(short.contains("…"))
  assert_eq(@app.truncate_summary("短"), "短")
  // 审计导出包含状态、步骤表与审计事件
  let specs = @app.block_catalog()
  let mut state = @app.apply_exec_event(
    @app.start_execution(chatbot_graph()),
    Start,
    specs,
  )
  let mut ticks = 0
  while state.status is Running && ticks < 200 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  let markdown = @app.export_audit_markdown(state)
  assert_true(markdown.contains("# MoBlocks Studio 运行审计"))
  assert_true(markdown.contains("等待人工确认"))
  assert_true(markdown.contains("审计事件"))
  assert_true(markdown.contains("开始执行"))
}
