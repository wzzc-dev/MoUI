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
test "workbench command detail expansion toggles per command" {
  let model = {
    ..WorkbenchModel::new(),
    commands: [
      CommandRun::new(
        id=1,
        command="moon check",
        cwd="/repo",
        status="passed",
        output="check ok",
      ),
      CommandRun::new(
        id=2,
        command="moon test",
        cwd="/repo",
        status="failed",
        exit_code=Some(2),
        output_path="/tmp/mo-test.log",
        output="test failed",
      ),
    ],
  }
  let expanded = model.update(ToggleCommandDetails(2))
  assert_false(expanded.commands[0].details_expanded)
  assert_true(expanded.commands[1].details_expanded)
  let collapsed = expanded.update(ToggleCommandDetails(2))
  assert_false(collapsed.commands[1].details_expanded)
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
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "wasm check"))
  assert_true(draw_text_count_containing(commands, "输出可用") >= 1)
  assert_false(has_text(commands, "输出 /tmp/wasm-check.log"))
  assert_true(has_text(commands, "退出码 2"))
  assert_true(has_text(commands, "展开"))
  assert_true(has_text(commands, "修复"))
  assert_true(has_text(commands, "重跑"))
  assert_false(has_text(commands, "stale command"))
  assert_false(has_text(commands, "native check"))
  assert_true(has_text(commands, "skia build"))
  assert_false(has_text(commands, "运行证据"))
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "全部"))
  assert_false(has_text(commands, "Native"))
  assert_false(has_text(commands, "Wasm"))
  let expanded = model.update(ToggleCommandDetails(3))
  let expanded_commands = expanded
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(expanded_commands, "收起"))
  assert_true(has_text(expanded_commands, "日志 /tmp/wasm-check.log"))
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
      commands, "moon build moui_tester/macos_skia_first_frame_smoke --target native",
    ),
  )
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "全部"))
  assert_false(has_text(commands, "Native"))
  assert_false(has_text(commands, "Wasm"))
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
  assert_true(has_text(commands, "常用检查"))
  assert_true(has_text(commands, "Native"))
  assert_true(has_text(commands, "Wasm"))
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
  assert_true(draw_text_count_containing(commands, "输出可用") >= 2)
  assert_false(has_text(commands, "输出 /tmp/mo-workbench-test.log"))
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
  assert_true(draw_text_count_containing(commands, "输出可用") >= 2)
  assert_false(has_text(commands, "输出 /tmp/mo-workbench-native.log"))
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "全部"))
  assert_false(has_text(commands, "Native"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "Pi bash"))
  assert_false(has_text(commands, "bash exited with code 2"))
}

///|
test "workbench workspace still shows structured diagnostics beside failed command" {
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
        source="moon check",
        severity="error",
        message="unused variable in app.mbt",
      ),
    ],
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "moon check"))
  assert_true(has_text(commands, "unused variable in app.mbt"))
  assert_true(has_text(commands, "修复失败命令"))
  assert_false(has_text(commands, "工作区证据"))
  assert_false(has_text(commands, "常用检查"))
  assert_false(has_text(commands, "全部"))
  assert_false(has_text(commands, "Native"))
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
  assert_true(has_text(commands, "等待 Agent 完成当前运行"))
  assert_false(has_text(commands, "等待 Pi 完成当前运行"))
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
test "workbench workspace diff details expand on demand" {
  let collapsed = model_with_reviewable_diff()
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(collapsed, "当前证据"))
  assert_true(has_text(collapsed, "展开"))
  assert_false(
    has_text(collapsed, "diff ready for review · 5 文件 · +160 -10"),
  )
  let expanded_model = model_with_reviewable_diff().update(
    ToggleWorkspaceDetails,
  )
  assert_true(expanded_model.workspace_details_expanded)
  let expanded = expanded_model
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(expanded, "收起"))
  assert_true(
    draw_text_count_containing(expanded, "diff ready for review") >= 1,
  )
}

///|
test "workbench wide shell renders inspector from live evidence" {
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
  assert_true(has_text(commands, "当前证据"))
  inspect(draw_text_count(commands, "下一步"), content="1")
  assert_true(has_text(commands, "继续当前计划"))
  assert_true(has_text(commands, "合并最终输出"))
  assert_false(has_text(commands, "Agents"))
  assert_false(has_text(commands, "进度"))
  assert_false(has_text(commands, "执行"))
  assert_false(has_text(commands, "计划所有者"))
  assert_false(has_text(commands, "工作文件夹"))
  assert_false(has_text(commands, "整理功能亮点"))
}

///|
test "workbench inspector renders independent tool evidence" {
  let model = {
    ..WorkbenchModel::new(),
    pi_agent: PiAgentSnapshot::new(phase="tool", active_tool_name="bash"),
  }
  let commands = model.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "当前证据"))
  assert_true(has_text(commands, "运行输出"))
  assert_true(draw_text_count_containing(commands, "工具 bash") >= 1)
}
