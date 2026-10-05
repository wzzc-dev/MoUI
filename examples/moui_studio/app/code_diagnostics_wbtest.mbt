///|
/// 切片 B（诊断面板 + 行内标记）的行为验证：
/// 1. 编辑即校验——坏草稿立刻产出结构化诊断（行内标记 + 问题面板的数据源）；
/// 2. 问题面板的行能归因到子程序与行号；
/// 3. GotoProblem 跳转 = 选中 handler + 光标钉到目标行 + 滚动对齐。

///|
test "editing an invalid draft produces live structured diagnostics" {
  // 编辑诊断语义在 DSL 外观下验证（M5-5e：默认 MoonBit 外观不做 DSL 诊断）
  let model = apply_shell(initial_model(), CycleCodeAppearance)
  let broken = apply_shell(model, EditCode("x ="))
  assert_true(broken.code_error != "")
  assert_eq(broken.code_diagnostics.length(), 1)
  let diagnostic = broken.code_diagnostics[0]
  assert_true(diagnostic.severity is @code_editor.Error)
  // 行 1 的错误 → 区间落在第一行内
  assert_eq(diagnostic.range.start, 0)
  assert_true(diagnostic.range.end > diagnostic.range.start)
  // 修复后清空
  let good = apply_shell(
    broken,
    EditCode("设置文本(\"标签\", \"好\")\n"),
  )
  assert_eq(good.code_error, "")
  assert_eq(good.code_diagnostics.length(), 0)
}

///|
test "problems pane attributes rows to handlers and lines" {
  let model = apply_shell(
    apply_shell(initial_model(), CycleCodeAppearance),
    EditCode("x ="),
  )
  let rows = problem_rows(model, translator(model))
  assert_true(rows.length() > 0)
  let draft_rows = rows
    .iter()
    .filter(row => row.label == text(translator(model), "app.problems.draft"))
    .collect()
  assert_true(draft_rows.length() > 0)
  let row = draft_rows[0]
  // 草稿行可跳转：handler 归属 + 行号
  assert_eq(row.handler_key, model.selected_handler)
  assert_eq(row.line, 1)
}

///|
test "goto problem pins caret to the target line and syncs scroll" {
  let model = initial_model()
  let key = model.selected_handler
  let jumped = apply_shell(model, GotoProblem(key, 2))
  // 光标 = 第 2 行行首（第 1 行长度 + 1 个换行符）
  let lines = split_line_texts(jumped.code_draft)
  assert_true(lines.length() >= 2)
  assert_eq(jumped.code_caret, lines[0].length() + 1)
  assert_eq(jumped.code_selection, None)
  // 第 2 行的滚动偏移被夹在 0（(2-3)*20 → max(0)）
  assert_eq(jumped.code_scroll.y, 0.0)
}
