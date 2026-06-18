///|
test "workbench compact shell keeps workflow rail collapsed" {
  let commands = runtime(width=960.0, height=640.0).draw_commands()
  assert_false(has_text(commands, "进度"))
  assert_false(has_text(commands, "工作文件夹"))
}

///|
test "workbench runtime draws agent desktop shell" {
  let commands = runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "Agent 桌面工作台"))
  assert_false(has_text(commands, "Pi agent 桌面工作台"))
  assert_true(has_text(commands, "当前会话"))
  assert_true(draw_text_count_containing(commands, "MoUI") >= 1)
  assert_false(has_text(commands, "活跃"))
  assert_true(has_text(commands, "Agent 路由整理"))
  assert_false(has_text(commands, "Provider routing cleanup"))
  assert_false(has_text(commands, "Provider switching"))
  assert_false(has_text(commands, "Backend smoke session"))
  assert_false(has_text(commands, "Pi RPC harness"))
  assert_false(has_text(commands, "Agent Pi"))
  assert_true(has_text(commands, "准备开始这个会话"))
  assert_true(has_text(commands, "告诉 Agent 你想推进的任务。"))
  assert_false(has_text(commands, "本地"))
  assert_false(has_text(commands, "Fixture"))
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
  assert_true(has_text(commands, "新对话"))
  assert_false(has_text(commands, "新会话"))
  assert_false(has_text(commands, "刷新"))
  assert_false(has_text(commands, "Pi 运行状态"))
  assert_true(has_text(commands, "上下文"))
  assert_true(has_text(commands, "仓库"))
  assert_true(has_text(commands, "示例"))
  assert_true(has_text(commands, "证据"))
  assert_true(has_text(commands, "会话"))
  assert_false(has_text(commands, "发送"))
  assert_false(has_text(commands, "会话记录"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "工作区"))
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
  assert_false(has_text(commands, "等待证据"))
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
  assert_true(has_text(commands, "分支"))
  assert_false(has_text(commands, "输出 /tmp/mo-workbench-app-test.log"))
  assert_false(has_text(commands, "清除"))
  assert_false(has_text(commands, "聚焦"))
  assert_false(has_text(commands, "审核"))
  assert_true(has_text(commands, "运行"))
  assert_false(has_text(commands, "停止"))
  assert_false(has_text(commands, "Pi: unbound"))
  assert_false(has_text(commands, "RPC 通道：未连接"))
  assert_false(has_text(commands, "Pi 运行：空闲"))
  assert_false(has_text(commands, "Pi RPC + macOS Skia dogfood."))
  assert_false(
    has_text(
      commands, "JSONL stdin/stdout transport exercise for pi --mode rpc.",
    ),
  )
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
test "workbench runtime follows light and dark chrome surfaces" {
  let runtime = WorkbenchModel::new().runtime(width=1220.0, height=780.0)
  let commands = runtime.draw_commands()
  assert_true(
    draw_solid_fill_count(
      commands,
      test_workbench_app_background(@moui.ColorScheme::Light),
    ) >=
    1,
  )
  assert_true(
    draw_solid_fill_count(
      commands,
      test_workbench_sidebar_background(@moui.ColorScheme::Light),
    ) >=
    1,
  )
  assert_true(
    draw_solid_fill_count(
      commands,
      test_workbench_main_background(@moui.ColorScheme::Light),
    ) >=
    1,
  )
  assert_true(
    draw_solid_fill_count(
      commands,
      test_workbench_panel_background(@moui.ColorScheme::Light),
    ) >=
    3,
  )
  assert_true(
    draw_solid_fill_count(
      commands,
      test_workbench_status_bar_background(@moui.ColorScheme::Light),
    ) >=
    1,
  )

  runtime.set_environment(
    runtime.environment().with_color_scheme(@moui.ColorScheme::Dark),
  )
  let dark_commands = runtime.draw_commands()
  assert_true(
    draw_solid_fill_count(
      dark_commands,
      test_workbench_app_background(@moui.ColorScheme::Dark),
    ) >=
    1,
  )
  assert_true(
    draw_solid_fill_count(
      dark_commands,
      test_workbench_panel_background(@moui.ColorScheme::Dark),
    ) >=
    3,
  )
  assert_true(
    draw_solid_fill_count(
      dark_commands,
      test_workbench_status_bar_background(@moui.ColorScheme::Dark),
    ) >=
    1,
  )
}

///|
test "workbench settings page switches appearance mode from sidebar" {
  let runtime = WorkbenchModel::new().runtime(width=1220.0, height=780.0)
  assert_true(has_text(runtime.draw_commands(), "设置"))
  assert_false(has_text(runtime.draw_commands(), "外观"))

  click_text(runtime, "设置")
  assert_true(has_text(runtime.draw_commands(), "外观"))
  assert_true(has_text(runtime.draw_commands(), "跟随系统"))
  assert_true(has_text(runtime.draw_commands(), "浅色"))
  assert_true(has_text(runtime.draw_commands(), "深色"))
  assert_true(has_text(runtime.draw_commands(), "返回"))

  click_text(runtime, "深色")
  assert_true(
    draw_solid_fill_count(
      runtime.draw_commands(),
      test_workbench_app_background(@moui.ColorScheme::Dark),
    ) >=
    1,
  )

  click_text(runtime, "浅色")
  assert_true(
    draw_solid_fill_count(
      runtime.draw_commands(),
      test_workbench_app_background(@moui.ColorScheme::Light),
    ) >=
    1,
  )

  click_text(runtime, "返回")
  assert_true(has_text(runtime.draw_commands(), "当前会话"))
  assert_false(has_text(runtime.draw_commands(), "外观"))
}

///|
test "workbench appearance mode validates setting values" {
  let dark = WorkbenchModel::new().update(SetAppearanceMode("dark"))
  inspect(dark.appearance_mode, content="dark")
  inspect(dark.last_status, content="Appearance mode changed")
  let light = dark.update(SetAppearanceMode("light"))
  inspect(light.appearance_mode, content="light")
  let system = light.update(SetAppearanceMode("system"))
  inspect(system.appearance_mode, content="system")
  let invalid = system.update(SetAppearanceMode("sepia"))
  inspect(invalid.appearance_mode, content="system")
  inspect(invalid.last_status, content="Appearance mode unavailable")
}

///|
test "workbench backend and session controls appear only in expanded composer options" {
  let collapsed = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(collapsed, "Agent Pi"))
  assert_false(has_text(collapsed, "后端"))
  assert_false(has_text(collapsed, "本地"))
  assert_false(has_text(collapsed, "Fixture"))
  assert_true(has_text(collapsed, "新对话"))
  assert_false(has_text(collapsed, "新会话"))
  assert_false(has_text(collapsed, "刷新"))
  let expanded = WorkbenchModel::new()
    .update(ToggleComposerControls)
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(expanded, "Agent"))
  assert_false(has_text(expanded, "后端"))
  assert_true(has_text(expanded, "Pi"))
  assert_true(has_text(expanded, "本地"))
  assert_false(has_text(expanded, "Fixture"))
  assert_false(has_text(expanded, "真实后端"))
  assert_false(has_text(expanded, "Pi RPC backend provider"))
  assert_false(has_text(expanded, "Local fixture backend"))
  assert_true(has_text(expanded, "新会话"))
  assert_true(has_text(expanded, "刷新"))
  assert_false(has_text(expanded, "按需同步当前 Agent 会话"))
  let fixture_expanded = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .update(ToggleComposerControls)
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(fixture_expanded, "新对话"))
  assert_false(has_text(fixture_expanded, "新会话"))
  assert_false(has_text(fixture_expanded, "本地演练"))
  assert_false(has_text(fixture_expanded, "真实 Agent 后端"))
}

///|
test "workbench default first screen stays within a quiet text budget" {
  let commands = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(draw_text_total(commands) <= 40)
  inspect(draw_text_count(commands, "新对话"), content="1")
  inspect(draw_text_count(commands, "当前会话"), content="1")
  inspect(draw_text_count(commands, "准备开始这个会话"), content="1")
  inspect(draw_text_count(commands, "给 Agent 一个任务"), content="1")
  assert_true(draw_text_count_containing(commands, "MoUI") <= 5)
  inspect(
    draw_text_count_containing(commands, "codex/mo-workbench"),
    content="2",
  )
  assert_true(draw_text_count_containing(commands, "Agent") <= 4)
  inspect(draw_text_count_containing(commands, "Pi"), content="0")
  inspect(draw_text_count_containing(commands, "RPC"), content="0")
  inspect(draw_text_count_containing(commands, "诊断"), content="1")
  assert_true(draw_text_count_containing(commands, "证据") <= 3)
  inspect(draw_text_count(commands, "工作区"), content="0")
}

///|
test "workbench top bar uses freed space for session identity" {
  let title = "Mo Workbench routing cleanup keeps the top bar title readable without reserved hidden chips"
  let model = {
    ..WorkbenchModel::new(),
    selected_session_id: "topbar-readable",
    sessions: [
      WorkbenchSession::new(
        id="topbar-readable",
        title~,
        project_path="/Volumes/Data/Code/moon/MoUI",
        branch="codex/mo-workbench",
        status="active",
        summary="Readable title smoke",
        active_task="",
        unread_events=0,
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(
    draw_text_count_containing(commands, "Mo Workbench routing cleanup") >= 1,
  )
  assert_false(has_text(commands, "Agent Pi"))
  assert_false(has_text(commands, "新会话"))
  assert_false(has_text(commands, "刷新"))
}

///|
test "workbench top bar backend chip stays quiet for default Pi runs" {
  let default_commands = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(default_commands, "Agent Pi"))

  let fixture_commands = WorkbenchModel::new()
    .update(SwitchAgentBackend("fixture"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(fixture_commands, "Agent 本地"))
  assert_false(has_text(fixture_commands, "Agent Fixture"))

  let active_pi_commands = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(active_pi_commands, "Agent Pi"))
  assert_true(has_text(active_pi_commands, "Agent：运行中"))

  let failed_pi_commands = WorkbenchModel::new()
    .update(ReceiveTransport(TransportFailed("pi unavailable")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(failed_pi_commands, "Agent Pi"))
}

///|
test "workbench top bar shortens long session identity" {
  let long_title = "Mo Workbench Skia renderer top bar should not clip session identity while Pi is busy"
  let long_path = "/Volumes/Data/Code/moon/MoUI/examples/mo_workbench/very/deep/workspace"
  let long_branch = "codex/mo-workbench/top-bar-shell-layout-cleanup-with-extra-long-name"
  let model = {
    ..WorkbenchModel::new(),
    selected_session_id: "long-session",
    sessions: [
      WorkbenchSession::new(
        id="long-session",
        title=long_title,
        project_path=long_path,
        branch=long_branch,
        status="running",
        summary="Long identity smoke",
        active_task="",
        unread_events=0,
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前会话"))
  assert_true(has_text(commands, "运行中"))
  assert_true(
    draw_text_count_containing(commands, "Mo Workbench Skia renderer") >= 1,
  )
  assert_false(has_text(commands, long_branch))
  assert_false(has_text(commands, long_path))
  assert_true(draw_text_count_containing(commands, "...") >= 1)
  assert_true(draw_text_count_containing(commands, "long-name") >= 1)
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
  assert_false(has_text(queued, "Pi"))
  assert_false(has_text(queued, "启动中"))
  assert_true(has_text(queued, "Agent：准备中"))
  assert_false(has_text(queued, "通道：启动中"))
  let running = WorkbenchModel::new()
    .update(ReceiveTransport(ProcessStarted("4242")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(running, "Agent：运行中"))
  assert_false(has_text(running, "通道：运行中"))
  assert_false(has_text(running, "Pi：空闲"))
  assert_false(has_text(running, "Agent Pi"))
  assert_false(has_text(running, "Pi RPC process started"))
  let failed = WorkbenchModel::new()
    .update(ReceiveTransport(TransportFailed("pi unavailable")))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(failed, "失败：pi unavailable"))
}

///|
test "workbench runtime signal keeps useful agent detail in one row" {
  let model = {
    ..WorkbenchModel::new(),
    pi_agent: PiAgentSnapshot::new(phase="tool", active_tool_name="read"),
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Agent：工具中 · 工具 read"))
  assert_false(has_text(commands, "Pi：工具中"))
  assert_false(has_text(commands, "通道："))
}

///|
test "workbench fixture backend hides Pi-only controls" {
  let model = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    composer_controls_expanded: true,
    model_catalog: [PiModelInfo::new(provider="openai", id="gpt-5")],
    fork_messages: [PiForkMessage::new(entry_id="entry-1", text="Fork me")],
    pi_agent: PiAgentSnapshot::new(
      thinking_level="high",
      steering_mode="all",
      follow_up_mode="all",
    ),
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "本地"))
  assert_false(has_text(commands, "Fixture"))
  assert_false(has_text(commands, "模型 1"))
  assert_false(has_text(commands, "分叉"))
  assert_false(has_text(commands, "导出"))
  assert_false(has_text(commands, "压缩"))
  assert_false(has_text(commands, "思考"))
  assert_false(has_text(commands, "同步名"))
  assert_false(has_text(commands, "引导"))
  assert_false(has_text(commands, "跟进"))
  assert_false(has_text(commands, "Pi 会话"))
}

///|
test "workbench conversation labels stay agent neutral on fixture backend" {
  let transcript_model = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    events: [],
    transcript: [
      TranscriptItem::new(
        id="assistant-neutral",
        role="assistant",
        summary="Ready to inspect the worktree",
        detail="I will keep the session focused.",
        tone="success",
      ),
    ],
  }
  let transcript = transcript_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(transcript, "Agent"))
  assert_true(has_text(transcript, "Ready to inspect the worktree"))
  assert_false(has_text(transcript, "Pi"))

  let event_model = {
    ..WorkbenchModel::new().update(SwitchAgentBackend("fixture")),
    events: [
      AgentEvent::new(
        phase="assistant",
        title="Planning next step",
        detail="Keep the default shell quiet.",
        tone="info",
      ),
    ],
  }
  let event_commands = event_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(event_commands, "Agent"))
  assert_true(has_text(event_commands, "Planning next step"))
  assert_false(has_text(event_commands, "Pi"))
}

///|
test "workbench Codex evidence flow mounts only when content arrives" {
  let empty = WorkbenchModel::new()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_false(has_text(empty, "会话记录"))
  assert_false(has_text(empty, "运行证据"))
  assert_false(has_text(empty, "工作区证据"))
  assert_false(has_text(empty, "当前证据"))
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
  assert_false(has_text(transcript, "当前任务"))
  assert_false(has_text(transcript, "下一步"))
  assert_false(has_text(transcript, "状态"))
  assert_true(has_text(transcript, "Pi summarized the fix"))
  assert_false(has_text(transcript, "会话记录"))
  assert_false(has_text(transcript, "运行证据"))
  assert_false(has_text(transcript, "工作区证据"))
  assert_false(has_text(transcript, "当前证据"))
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
  assert_true(has_text(activity, "当前证据"))
  assert_true(
    has_text(activity, "moon test examples/mo_workbench/app --target native"),
  )
  assert_false(has_text(activity, "会话记录"))
  assert_false(has_text(activity, "运行证据"))
  assert_false(has_text(activity, "工作区证据"))
  let workspace_model = model_with_reviewable_diff()
  let workspace = workspace_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(workspace, "当前证据"))
  assert_true(has_text(workspace, "5 文件 · +160 -10"))
  assert_true(has_text(workspace, "审核"))
  assert_false(has_text(workspace, "会话记录"))
  assert_false(has_text(workspace, "运行证据"))
  assert_false(has_text(workspace, "工作区证据"))
}

///|
test "workbench composer keeps ordinary prompts low noise" {
  let commands = WorkbenchModel::new()
    .update(PromptChanged("Run focused checks"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(commands, "选项"))
  assert_true(has_text(commands, "发送"))
  assert_false(has_text(commands, "范围"))
  assert_true(has_text(commands, "上下文"))
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
  assert_true(has_text(commands, "范围"))
  assert_true(has_text(commands, "上下文"))
  assert_false(has_text(commands, "焦点"))
  assert_true(has_text(commands, "仓库"))
  assert_true(has_text(commands, "示例"))
  assert_true(has_text(commands, "证据"))
  assert_true(has_text(commands, "会话"))
  assert_true(has_text(commands, "通用"))
  assert_true(has_text(commands, "编码"))
  assert_true(has_text(commands, "校验"))
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
  assert_true(has_text(commands, "范围"))
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
  assert_true(has_text(commands, "范围"))
  assert_false(has_text(commands, "焦点"))
  assert_true(has_text(commands, "Agent"))
  assert_false(has_text(commands, "真实 Agent 后端"))
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
test "workbench transcript and fork rows stay compact and actionable" {
  let long_fork_text = "Branchable payload alpha beta gamma delta epsilon zeta eta theta iota kappa lambda"
  let model = {
    ..WorkbenchModel::new(),
    transcript: [
      TranscriptItem::new(
        id="fork-1",
        role="assistant",
        summary="Pi compact transcript row",
        detail="Use one dense row with the follow-up affordance.",
        tone="success",
      ),
    ],
    fork_messages: [PiForkMessage::new(entry_id="fork-1", text=long_fork_text)],
  }
  let commands = model.runtime(width=960.0, height=640.0).draw_commands()
  assert_true(has_text(commands, "Pi compact transcript row"))
  assert_true(has_text(commands, "分叉"))
  assert_false(has_text(commands, "跟进这条消息"))
  assert_false(has_text(commands, "可从此处分叉"))
  assert_false(has_text(commands, "分支"))
  assert_false(has_text(commands, long_fork_text))
  assert_true(draw_text_count_containing(commands, "Branchable payload") >= 1)
  assert_true(
    fork_affordance_follows_text(commands, "Pi compact transcript row"),
  )
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
        position=@moui.Point::new(
          x=before.origin.x - 80.0,
          y=before.origin.y + 24.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@moui.Point::new(x=0.0, y=-240.0),
      ),
    ),
  )
  guard main_scrollbar_thumb_frame(runtime.draw_commands()) is Some(after) else {
    fail("expected visible main scrollbar after scroll")
  }
  assert_true(after.origin.y > before.origin.y)
}

///|
test "workbench composer remains visible after scroll and resize" {
  let runtime = model_with_overflowing_transcript().runtime(
    width=960.0,
    height=640.0,
  )
  guard text_frame(runtime.draw_commands(), "给 Agent 一个任务")
    is Some(before) else {
    fail("expected composer placeholder before scroll")
  }
  guard main_scrollbar_thumb_frame(runtime.draw_commands()) is Some(thumb) else {
    fail("expected visible main scrollbar")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@moui.Point::new(
          x=thumb.origin.x - 80.0,
          y=thumb.origin.y + 24.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@moui.Point::new(x=0.0, y=-240.0),
      ),
    ),
  )
  guard text_frame(runtime.draw_commands(), "给 Agent 一个任务")
    is Some(after) else {
    fail("expected composer placeholder after scroll")
  }
  assert_true(after.origin.y == before.origin.y)
  runtime.dispatch_event(
    @core.AppEvent::Resize(@moui.Size::new(width=1440.0, height=900.0)),
  )
  guard text_frame(runtime.draw_commands(), "给 Agent 一个任务")
    is Some(resized) else {
    fail("expected composer placeholder after resize")
  }
  assert_true(resized.origin.y > after.origin.y)
}

///|
test "workbench shell adapts to runtime viewport resize" {
  let runtime = runtime(width=960.0, height=640.0)
  guard first_surface_frame(runtime.draw_commands()) is Some(compact_frame) else {
    fail("expected root surface frame before resize")
  }
  inspect(compact_frame.size.width, content="960")
  inspect(compact_frame.size.height, content="640")
  assert_true(has_text(runtime.draw_commands(), "当前会话"))
  runtime.dispatch_event(
    @core.AppEvent::Resize(@moui.Size::new(width=1440.0, height=900.0)),
  )
  guard first_surface_frame(runtime.draw_commands()) is Some(expanded_frame) else {
    fail("expected root surface frame after resize")
  }
  inspect(expanded_frame.size.width, content="1440")
  inspect(expanded_frame.size.height, content="900")
  assert_true(has_text(runtime.draw_commands(), "当前会话"))
}

///|
test "workbench composer displays selected agent focus in scope row" {
  let model = WorkbenchModel::new().update(SelectAgent("coding"))
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "范围"))
  assert_true(has_text(commands, "编码"))
  assert_false(has_text(commands, "仓库、示例、焦点 编码"))
}
