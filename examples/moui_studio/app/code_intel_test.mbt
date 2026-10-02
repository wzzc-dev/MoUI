///|
/// 切片 H（代码情报）：光标词提取、补全候选过滤、应用补全、跳转声明。
test "code intelligence: completions and jump to declaration" {
  let model = @app.initial_model()
  // 已知草稿：注释头之后第一行 `变量 次数 = 0`（不依赖出厂样例的 note 头）
  let with_caret = (@app.update_pure(
    model,
    @app.EditCode("// note\n变量 次数 = 0\n"),
  )).0
  let with_caret2 = (@app.update_pure(
    with_caret,
    @app.EditorCaretMoved(12, None),
  )).0
  // 光标在「次数」词上
  let (word, start) = @app.word_at_caret(with_caret2.code_draft, 12)
  assert_true(word.length() > 0)
  assert_eq(word, "次数")
  assert_eq(start, 11)
  // 候选：关键字 + 内建 + 控件名，按前缀过滤
  let all = @app.completions_for(with_caret2, "")
  assert_true(all.length() > 0)
  assert_true(all.length() <= 12)
  // 应用补全：替换光标词并推进光标
  let (text, caret) = @app.apply_completion(with_caret2.code_draft, 12, "信息框")
  assert_true(text.contains("信息框"))
  assert_true(caret > 1)
  ignore(with_caret)
  // 跳转声明：变量在某行声明
  let jump_line = @app.declaration_line_of(with_caret2, 12)
  // 「次数」的声明在第 2 行（注释头之后）
  assert_eq(jump_line, 2)
}
