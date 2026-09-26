///|
/// M4 闭环回归：Studio 导出的 bundle 里，内嵌项目能被「导出引擎」跑到完成。
/// 这条链路 = export_bundle → 内嵌 project JSON → decode → validate →
/// start_execution → 推进到确认闸门 → Confirm → 完成。浏览器侧的点击实测见
/// README 的导出验证一节；这里固定同一 engines 的语义（内核与 Studio 同源，
/// 由 services/export 的 sync 检查保证不漂移）。

///|
/// 从 project_data.mbt 源码里取出转义后的 JSON 字面量并反转义。
fn embedded_project_json(source : String) -> String raise {
  // project_data.mbt 结构：...\n  "<escaped json>"\n}\n
  let mut start = -1
  let mut i = 0
  while i < source.length() && start < 0 {
    if source[i] == '{' && i + 1 < source.length() && source[i + 1] == '\\' {
      start = i
    }
    i = i + 1
  }
  if start < 0 {
    fail("project_data.mbt 应包含转义 JSON 字面量")
  }
  let inner = source.exact_view(start~).to_owned()
  // 去掉尾部 4 个字符（"\n}\n 的外壳部分）
  let escaped = inner.exact_view(start=0, end=inner.length() - 4).to_owned()
  let mut out = ""
  let mut pending = false
  for c in escaped {
    if pending {
      out = out + c.to_string()
      pending = false
    } else if c == '\\' {
      pending = true
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
test "M4：导出 bundle 的内嵌项目可被导出引擎跑到完成" {
  let project = @app.Project::new("导出运行检查", chatbot_graph())
  let files = @export.export_bundle(
    @app.encode_project(project),
    "导出运行检查",
  )
  // bundle 必须带上领域内核与可执行 runner
  for
    name in [
      "block_graph", "block_catalog", "graph_validation", "execution_reducer", "project_codec",
    ] {
    let found = files.any(fn(pair) { pair.0.has_suffix("/app/\{name}.mbt") })
    assert_true(found)
  }
  let data = files.filter(fn(pair) {
    pair.0.has_suffix("/app/project_data.mbt")
  })
  assert_eq(data.length(), 1)
  let json = embedded_project_json(data[0].1)
  let specs = @app.block_catalog()
  let decoded = match @app.decode_project(json, specs) {
    Ok(project) => project
    Err(errors) =>
      fail("内嵌项目应可解码：\{errors.length()} 个错误")
  }
  assert_true(@app.validate_graph(decoded.graph, specs).is_empty())
  // 与导出引擎相同的驱动：推进到闸门 → 确认 → 完成
  let started = @app.apply_exec_event(
    @app.start_execution(decoded.graph),
    Start,
    specs,
  )
  let mut state = started
  let mut ticks = 0
  while state.status is Running && ticks < 200 {
    state = @app.apply_exec_event(state, StepOk, specs)
    ticks = ticks + 1
  }
  assert_true(state.status is WaitingConfirmation)
  let mut finished = @app.apply_exec_event(state, Confirm, specs)
  let mut more = 0
  while finished.status is Running && more < 200 {
    finished = @app.apply_exec_event(finished, StepOk, specs)
    more = more + 1
  }
  assert_true(finished.status is Completed)
  assert_true(finished.audit.length() > 0)
}
