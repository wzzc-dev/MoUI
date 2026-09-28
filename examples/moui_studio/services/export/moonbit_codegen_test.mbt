///|
/// 编译轨代码生成测试：确定性、路径映射、两轨同源审计文本、
/// 「预览 = bundle 实际编译的源码」契约。

///|
test "generated source is byte stable across runs" {
  let program = @proposals.sample_drill()
  let once = @export.generate_source(program)
  let twice = @export.generate_source(program)
  assert_eq(once.source, twice.source)
  assert_eq(once.handlers.length(), program.handlers.length())
  // 每次生成的 handler 名称与行号映射同样确定
  let mut i = 0
  while i < once.handlers.length() {
    assert_eq(once.handlers[i].function_name, twice.handlers[i].function_name)
    assert_eq(once.handlers[i].start_line, twice.handlers[i].start_line)
    assert_eq(
      once.handlers[i].stmt_lines.length(),
      twice.handlers[i].stmt_lines.length(),
    )
    i = i + 1
  }
}

///|
test "preview is the very source that goes into the bundle" {
  let program = @proposals.sample_hello()
  let preview = @export.moonbit_preview(program)
  let generated = @export.generate_source(program)
  assert_eq(preview, generated.source)
  // 生成源码可编译：handler 直接调用 compiled_runtime 执行面，没有解释器
  assert_true(preview.contains("@compiled_runtime"))
  assert_false(preview.contains("start_run_stmts"))
  assert_false(preview.contains("run_to_end"))
  assert_false(preview.contains("不是可编译产物"))
  // 可读性契约：程序与控件信息在头注释里
  assert_true(preview.contains("问候"))
}

///|
test "handler names are stable and ASCII-folded" {
  let program = @proposals.sample_store()
  let generated = @export.generate_source(program)
  assert_eq(generated.handlers.length(), 2)
  assert_true(generated.handlers[0].function_name.has_prefix("studio_"))
  for handler in generated.handlers {
    for ch in handler.function_name {
      assert_true(
        (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '_' ||
        ch == '-' ||
        ch == '>',
      )
    }
    assert_true(handler.function_name.contains("on_click"))
  }
}

///|
test "stmt lines map IR paths to generated source lines" {
  let program = @proposals.sample_drill()
  let generated = @export.generate_source(program)
  let handler = generated.handlers[0]
  // 顶层语句路径 [0], [1], [2], [3]
  let mut index = 0
  while index < program.handlers[0].body.length() {
    let line = match handler.line_for([index]) {
      Some(value) => value
      None => fail("顶层语句 \{index} 必须有行号映射")
    }
    assert_true(line >= handler.start_line)
    assert_true(line <= handler.body_end_line)
    index = index + 1
  }
  // 第二条 handler 的行号在整个文件坐标里单调递增
  if generated.handlers.length() > 1 {
    assert_true(
      generated.handlers[1].start_line > generated.handlers[0].start_line,
    )
  }
}

///|
test "conditional bodies map their nested statement paths" {
  let program = @proposals.sample_drill()
  let generated = @export.generate_source(program)
  // 第二个 handler（批改按钮）的 body[0] 是 If，then 体路径 [0, 0]，
  // else 体路径 [0, 2] —— 与 domain/blocks 的路径口径一致。
  let handler = generated.handlers[1]
  assert_true(handler.line_for([0]) is Some(_))
  assert_true(handler.line_for([0, 0]) is Some(_))
  assert_true(handler.line_for([0, 2, 0]) is Some(_))
  assert_true(handler.line_for([9, 9]) is None)
}

///|
test "audit details use the interpreter canonical text" {
  let program = @proposals.sample_drill()
  let generated = @export.generate_source(program)
  // handler 0 的第一条是 第一个数 = 随机数(20)（canonical_call_text 口径）
  let first = match program.handlers[0].body[0] {
    @ir.Assign(name, expr) => "\{name} = \{@studio_lang.canonical_expr(expr)}"
    _ => fail("样例首句应为赋值")
  }
  assert_true(generated.source.contains(@export.mbt_quote(first)))
  // 命令调用：canonical_call_text 口径
  let call_text = @studio_lang.canonical_call_text(
    "set_text",
    match program.handlers[0].body[2] {
      @ir.Call(_, args) => args
      _ => fail("样例第三句应为调用")
    },
  )
  assert_true(generated.source.contains(@export.mbt_quote(call_text)))
}

///|
test "string literals are escaped for MoonBit source" {
  let text = "a\"b\\c\nd\te\rf"
  let quoted = @export.mbt_quote(text)
  assert_eq(quoted, "\"a\\\"b\\\\c\\nd\\te\\rf\"")
  // 生成器对含特殊字符的项目文本仍然产出确定源码
  let program : @ir.StudioProgram = {
    ..@proposals.sample_hello(),
    window: @ir.WindowSpec::{
      title: "引号\"与\\反斜杠",
      width: 640,
      height: 480,
    },
  }
  let source = @export.moonbit_preview(program)
  assert_true(source.contains("引号"))
  let again = @export.moonbit_preview(program)
  assert_eq(source, again)
}

///|
test "empty program still generates a valid file" {
  let empty = @ir.empty_program()
  let generated = @export.generate_source(empty)
  assert_true(
    generated.source.contains("（本程序还没有事件子程序）"),
  )
  assert_eq(generated.handlers.length(), 0)
  assert_eq(@export.moonbit_preview(empty), generated.source)
}
