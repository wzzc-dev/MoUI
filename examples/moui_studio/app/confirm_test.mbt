///|
/// 切片 D（破坏性操作确认）的行为验证：
/// 1. 删除控件/变量：先转确认请求，确认后续行，取消不动；
/// 2. 模板/新建：只拦「有未保存工作」的程序（出厂示例不挡路）；
/// 3. 确认续行在纯转移上下文内同步完成（不依赖 Effect 排空）。

///|
test "delete control requires confirmation and continues on accept" {
  let model = @app.initial_model()
  let asked = apply(model, @app.DeleteControl("按钮"))
  assert_true(asked.pending_confirm is Some(_))
  // 尚未删除
  assert_eq(asked.program.controls.length(), model.program.controls.length())
  // 取消：什么都不动，确认态清空
  let cancelled = apply(asked, @app.ConfirmDismissed)
  assert_true(cancelled.pending_confirm is None)
  assert_eq(
    cancelled.program.controls.length(),
    model.program.controls.length(),
  )
  // 确认：同步续行删除
  let confirmed = apply(asked, @app.ConfirmAccepted)
  assert_eq(
    confirmed.program.controls.length(),
    model.program.controls.length() - 1,
  )
  assert_true(confirmed.pending_confirm is None)
}

///|
test "template switch is guarded only when work exists" {
  // 出厂初始模型没有用户改动：直接放行
  let fresh = @app.initial_model()
  let applied = apply(fresh, @app.SelectTemplate(3))
  assert_true(applied.pending_confirm is None)
  // 用户改过（dirty）：先确认
  let dirty = apply(fresh, @app.EditCode("设置文本(\"标签\", \"改\")\n"))
  let committed = apply(dirty, @app.SetMode(@app.ModePreview))
  let asked = apply(committed, @app.SelectTemplate(0))
  assert_true(asked.pending_confirm is Some(_))
  let applied2 = apply(asked, @app.ConfirmAccepted)
  assert_true(applied2.pending_confirm is None)
  // 模板 0 已套用（按钮文案回到问候样例）
  assert_true(applied2.program.controls.length() > 0)
}
