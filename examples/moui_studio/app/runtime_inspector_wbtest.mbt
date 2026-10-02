///|
/// 切片 C（运行时检查器）的行为验证：
/// 1. 采样到达写入报告 + 摘要历史（去重、封顶）；
/// 2. 打开 Runtime 页签 / RuntimeRefresh 走采样，其余消息零采样
///    （回调被调次数可证）；
/// 3. 未注入回调时打开页签 → runtime_missing 显式降级，不静默空白。

///|
test "runtime sample arrival records report and bounded dedup history" {
  let model = initial_model()
  let mut current = model
  for index in 0..<40 {
    let label = if index % 3 == 0 { "s-a" } else if index % 3 == 1 {
      "s-b"
    } else {
      "s-c"
    }
    current = runtime_sample_arrived(
      current,
      { summary: label, report: "report \{label}" },
    )
  }
  let report = current.runtime_report
  assert_true(report is Some(_))
  // 最后一次采样是 index 39（39 % 3 = 0）
  assert_eq(report.unwrap().summary, "s-a")
  // 去重后只有 3 种摘要
  assert_eq(current.runtime_history.length(), 3)
}

///|
test "runtime refresh samples only on tab open or explicit refresh" {
  let mut calls = 0
  let take : RuntimeSnapshotFn = fn() {
    calls = calls + 1
    Some({ summary: "sum", report: "[runtime]\nnodes" })
  }
  let model = initial_model()
  // 无关消息：不采样
  let _ = update_pure(model, ToggleBottom)
  assert_eq(calls, 0)
  // 打开别的页签：不采样
  let (other, _) = update_pure(model, SetContextTab(CtxProps))
  let _ = runtime_refresh_attached(other, SetContextTab(CtxProps), take)
  assert_eq(calls, 0)
  // 打开 Runtime 页签：采样一次
  let (opened, _) = update_pure(model, SetContextTab(CtxRuntime))
  let (sampled, _) = runtime_refresh_attached(opened, SetContextTab(CtxRuntime), take)
  assert_eq(calls, 1)
  assert_true(sampled.runtime_report is Some(_))
  assert_false(sampled.runtime_missing)
  // 显式刷新：再采样一次
  let (refreshed, _) = runtime_refresh_attached(sampled, RuntimeRefresh, take)
  assert_eq(calls, 2)
  assert_true(refreshed.runtime_report is Some(_))
}

///|
test "runtime tab without channel degrades explicitly" {
  let take : RuntimeSnapshotFn = fn() { None }
  let model = initial_model()
  let (opened, _) = update_pure(model, SetContextTab(CtxRuntime))
  let (degraded, _) = runtime_refresh_attached(opened, SetContextTab(CtxRuntime), take)
  assert_true(degraded.runtime_missing)
  assert_true(degraded.runtime_report is None)
}
