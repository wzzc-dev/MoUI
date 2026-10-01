///|
/// 运行/编译两条轨的**可观察反应**回归。
///
/// 独立成文件（app_test.mbt 的源文件预算已顶格）：这里锁的是用户直接
/// 读到的那两个现象——「运行之后点按钮没反应」与「编译没编出产物」。
///
/// 两个现象的共同点是**都不在纯状态转移里**：状态机一直是对的，错的是
/// 「每次事件都从同一个随机种子起算」和「产物从不回传给界面」。所以
/// 用例必须断言**跨事件的差异**与**报告里的产物事实**，而不是单次调用
/// 的返回值。

///|
/// 去重计数：`next_seed` 接续正确时，六次点击的随机结果应出现多个不同值。
/// 用一个显式 helper 而不是在用例里手写双重循环——判据是「有几个不同的
/// 值」，写成一团下标运算会让人读不出意图。
fn distinct_count(values : Array[String]) -> Int {
  let mut count = 0
  let mut i = 0
  while i < values.length() {
    let mut seen_before = false
    let mut j = 0
    while j < i {
      if values[j] == values[i] {
        seen_before = true
      }
      j = j + 1
    }
    if !seen_before {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
/// 解释轨：同一按钮连点多次，随机结果必须变化。
///
/// 缺陷原状：`start_run_stmts` 每次都用默认 seed，点名册点十次都是
/// 「王五」——用户读到的是「运行之后点按钮没反应」。修法是种子跨事件
/// 推进（`runtime_seed` + `next_seed`）。
test "repeated stage clicks on the interpret track vary the random result" {
  let model = apply(@app.initial_model(), SelectTemplate(1))
  let started = apply(model, RunStart)
  assert_true(started.run is Some(_))
  let seen : Array[String] = []
  let mut current = started
  for _ in 0..<6 {
    current = drain(apply(current, ControlClicked("点名按钮")))
    let run = current.run.unwrap()
    assert_true(run.state.status is @studio_lang.Completed)
    seen.push(run.state.texts.get("结果").unwrap_or(""))
  }
  // 六次里至少出现两个不同结果（恒同即缺陷复发）。
  assert_true(distinct_count(seen) >= 2)
  // 每次结果都必须真的落在名单里（不是空串、不是越界）。
  for value in seen {
    assert_true(
      value == "张三" ||
      value == "李四" ||
      value == "王五" ||
      value == "赵六" ||
      value == "钱七",
    )
  }
}

///|
/// 编译轨：同一按钮连点多次，随机结果同样必须变化。
///
/// 编译轨的 Runtime 每次事件都重建，种子必须由 app 显式接续；漏掉这一步
/// 时两轨会**一起**退化成恒定值——本用例把这条并列锁住。
test "repeated stage clicks on the compile track vary the random result" {
  let model = apply(
    @app.initial_model(compile_track_available=true),
    SelectTemplate(1),
  )
  let switched = apply(model, SetRunTrack(@app.Compile))
  let started = drain_compiled(apply(switched, RunStart))
  assert_true(started.compiled_run is Some(_))
  let seen : Array[String] = []
  let mut current = started
  for _ in 0..<6 {
    current = drain_compiled(apply(current, ControlClicked("点名按钮")))
    let run = current.compiled_run.unwrap()
    seen.push(run.runtime.texts.get("结果").unwrap_or(""))
  }
  assert_true(distinct_count(seen) >= 2)
}

///|
/// 两轨在**同一串事件**后给出逐项相同的结果（种子接续口径一致）。
///
/// 两台独立的推进器只要有一边漏掉 `next_seed`，这里立刻分叉。
test "both tracks stay in lockstep across a sequence of clicks" {
  let base = apply(
    @app.initial_model(compile_track_available=true),
    SelectTemplate(1),
  )
  let mut interp = drain(apply(base, RunStart))
  let mut compiled = drain_compiled(
    apply(apply(base, SetRunTrack(@app.Compile)), RunStart),
  )
  for _ in 0..<4 {
    interp = drain(apply(interp, ControlClicked("点名按钮")))
    compiled = drain_compiled(apply(compiled, ControlClicked("点名按钮")))
    assert_eq(
      interp.run.unwrap().state.texts.get("结果").unwrap_or(""),
      compiled.compiled_run.unwrap().runtime.texts.get("结果").unwrap_or(""),
    )
  }
}

///|
/// 停止运行必须离开全屏运行页（回到可视化工作区）。
///
/// 缺陷原状：`RunStop` 只清 `run`/`compiled_run`，`mode` 仍停在 `ModeRun`
/// ——那是三个全屏页之一，运行态一空 `run_form` 就渲染成空视图，整个
/// 中心区（含两侧栏）变白。实测点「停止」后窗口只剩顶栏与状态栏。
test "stopping a run returns to the workspace instead of a blank page" {
  let model = apply(@app.initial_model(), RunStart)
  assert_true(model.mode is @app.ModeRun)
  let stopped = apply(model, RunStop)
  assert_true(stopped.run is None)
  assert_true(stopped.mode is @app.ModeDesign)
  assert_true(stopped.workspace is @app.WsVisual)
  assert_true(stopped.pane_live)
  // 编译轨同口径（两轨都走同一个停止动作）。
  let compiled = apply(
    apply(
      @app.initial_model(compile_track_available=true),
      SetRunTrack(@app.Compile),
    ),
    RunStart,
  )
  assert_true(compiled.mode is @app.ModeRun)
  let compiled_stopped = apply(compiled, RunStop)
  assert_true(compiled_stopped.compiled_run is None)
  assert_true(compiled_stopped.mode is @app.ModeDesign)
  assert_true(compiled_stopped.workspace is @app.WsVisual)
}
