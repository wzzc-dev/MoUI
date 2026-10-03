///|
/// MoUI Studio 语言测试：双语解析、往返一致、确定性渲染、指令机执行、
/// 闸门语义、预算、随机数确定性与语言层校验。

///|
fn parse_ok(
  source : String,
  language : @studio_lang.Language,
) -> Array[@studio_lang.TracedStmt] {
  match @studio_lang.parse_handler_body(source, language) {
    Ok(body) => body
    Err(error) => abort("解析失败: \{error.a()} @\{error.line()}")
  }
}

///|
fn parse_body_ir(
  source : String,
  language : @studio_lang.Language,
) -> Array[@ir.Stmt] {
  parse_ok(source, language).map(traced => traced.stmt)
}

///|
fn parse_sig(source : String, language : @studio_lang.Language) -> String {
  @ir.stmts_signature(parse_body_ir(source, language))
}

///|
fn run_zh(
  source : String,
  texts : Map[String, String],
  values : Map[String, @studio_lang.Value],
  seed? : Int = 42,
) -> @studio_lang.RunState {
  let state = @studio_lang.start_run(
    parse_ok(source, @studio_lang.ZhHans),
    texts,
    values,
    Map([], capacity=4),
    seed~,
  )
  @studio_lang.run_to_end(state)
  state
}

///|
test "zh parses all statement forms" {
  let signature = parse_sig(
    "变量 x = 1\nx = x + 2\n如果 x > 2 则\n  信息框(\"大\")\n否则如果 x = 2 则\n  信息框(\"等\")\n否则\n  信息框(\"小\")\n结束\n计次循环 3 次 为 i\n  跳出循环\n结束\n当 x < 100 循环\n  x = x + 1\n结束\n",
    @studio_lang.ZhHans,
  )
  assert_true(signature.contains("declare x = int(1)"))
  assert_true(signature.contains("if (var(x) > int(2))"))
  assert_true(signature.contains("elseif (var(x) = int(2))"))
  assert_true(signature.contains("else"))
  assert_true(signature.contains("count int(3) as i"))
  assert_true(signature.contains("break"))
  assert_true(signature.contains("while (var(x) < int(100))"))
}

///|
test "en parses the identical program" {
  let zh = parse_sig(
    "变量 x = 1\n如果 x > 2 则\n  信息框(\"hi\")\n结束\n",
    @studio_lang.ZhHans,
  )
  let en = parse_sig(
    "let x = 1\nif x > 2 then\n  message_box(\"hi\")\nend\n",
    @studio_lang.En,
  )
  assert_eq(zh, en)
}

///|
test "full width punctuation and mixed identifiers parse" {
  let signature = parse_sig(
    "变量 得分 ＝ ８５\n变量 姓名 ＝ \"张三\"\n",
    @studio_lang.ZhHans,
  )
  assert_true(signature.contains("declare 得分 = int(85)"))
  assert_true(signature.contains("declare 姓名 = str(«张三»)"))
}

///|
test "syntax errors carry line numbers" {
  match
    @studio_lang.check_syntax(
      "变量 x = 1\n如果 x 变量\n",
      @studio_lang.ZhHans,
    ) {
    Some(error) => {
      assert_eq(error.line(), 2)
      assert_true(error.a() == "则")
    }
    None => fail("应报语法错误")
  }
  match
    @studio_lang.check_syntax(
      "变量 x = 1\n否则如果 x = 1 则\n",
      @studio_lang.ZhHans,
    ) {
    Some(error) => assert_eq(error.line(), 2)
    None => fail("保留字开头应报错")
  }
  match @studio_lang.check_syntax("let x = ", @studio_lang.En) {
    Some(error) => assert_eq(error.line(), 1)
    None => fail("应报语法错误")
  }
  assert_true(
    @studio_lang.check_syntax("变量 x = 1", @studio_lang.ZhHans) is None,
  )
}

///|
test "reserved words cannot be names" {
  for
    word in [
      "变量", "如果", "结束", "真", "且", "if", "then", "end", "true", "and",
    ] {
    assert_true(@studio_lang.is_reserved(word))
  }
  assert_true(!@studio_lang.is_reserved("得分"))
  assert_true(!@studio_lang.is_reserved("score"))
}

///|
test "round trip zh and en are stable" {
  let ir = parse_body_ir(
    "变量 i = 0\n当 i < 3 循环\n  设置文本(标签, 转文本(i))\n  i = i + 1\n结束\n",
    @studio_lang.ZhHans,
  )
  let zh_text = @studio_lang.render_stmts(ir, @studio_lang.ZhHans)
  let en_text = @studio_lang.render_stmts(ir, @studio_lang.En)
  assert_eq(
    @ir.stmts_signature(parse_body_ir(zh_text, @studio_lang.ZhHans)),
    @ir.stmts_signature(ir),
  )
  assert_eq(
    @ir.stmts_signature(parse_body_ir(en_text, @studio_lang.En)),
    @ir.stmts_signature(ir),
  )
  assert_eq(@studio_lang.render_stmts(ir, @studio_lang.ZhHans), zh_text)
  assert_true(en_text.contains("while i < 3 do"))
  assert_true(en_text.contains("let i = 0"))
  assert_true(en_text.contains("\nend\n"))
}

///|
test "printer parenthesizes by precedence" {
  let ir = parse_body_ir(
    "变量 x = (a + b) * 2\n变量 y = a - (b - c)\n变量 z = 非 (a = b)",
    @studio_lang.ZhHans,
  )
  let text = @studio_lang.render_stmts(ir, @studio_lang.ZhHans)
  assert_true(text.contains("(a + b) * 2"))
  assert_true(text.contains("a - (b - c)"))
  assert_eq(
    @ir.stmts_signature(parse_body_ir(text, @studio_lang.ZhHans)),
    @ir.stmts_signature(ir),
  )
}

///|
test "keywords classify by table not literals" {
  let zh = @studio_lang.keywords_for(@studio_lang.ZhHans)
  let en = @studio_lang.keywords_for(@studio_lang.En)
  assert_true(
    @studio_lang.classify_stmt_keyword(zh.if_kw, zh) is @studio_lang.KwIf,
  )
  assert_true(
    @studio_lang.classify_stmt_keyword(en.if_kw, en) is @studio_lang.KwIf,
  )
  assert_true(
    @studio_lang.classify_stmt_keyword("得分", zh) is @studio_lang.NoneKw,
  )
  assert_true(
    @studio_lang.classify_stmt_keyword("let", en) is @studio_lang.KwDeclare,
  )
}

///|
test "builtin catalog is bilingual and canonical" {
  match @studio_lang.find_builtin("信息框") {
    Some(spec) => assert_eq(spec.id, "message_box")
    None => fail("中文名应命中")
  }
  match @studio_lang.find_builtin("message_box") {
    Some(spec) => assert_eq(spec.id, "message_box")
    None => fail("英文名应命中")
  }
  assert_eq(
    @studio_lang.builtin_display("message_box", @studio_lang.ZhHans),
    "信息框",
  )
  assert_eq(
    @studio_lang.builtin_display("message_box", @studio_lang.En),
    "message_box",
  )
  match @studio_lang.builtin_kind("submit_data") {
    Some(kind) => assert_true(kind is @studio_lang.Gate)
    None => fail("submit_data 应在目录中")
  }
  match @studio_lang.builtin_kind("get_text") {
    Some(kind) => assert_true(kind is @studio_lang.Function)
    None => fail("get_text 应在目录中")
  }
  assert_true(@studio_lang.find_builtin("不存在") is None)
}

///|
test "interpreter runs assignments and branches" {
  let texts : Map[String, String] = Map([], capacity=4)
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  let state = run_zh(
    "变量 x = 1\n如果 x = 1 则\n  x = 10\n否则如果 x = 2 则\n  x = 20\n否则\n  x = 30\n结束\n",
    texts, values,
  )
  assert_true(state.status is @studio_lang.Completed)
  match state.vars.get("x") {
    // 整数语义：整数字面量与整型算术保持 VInt 身份
    Some(@studio_lang.VInt(n)) => assert_eq(n, 10)
    Some(@studio_lang.VNum(n)) => assert_eq(n, 10.0)
    _unused => fail("x 应为 10")
  }
  let last = state.audit[state.audit.length() - 1]
  assert_true(last.op is @studio_lang.OpAssign)
  assert_eq(last.detail, "x = 10")
}

///|
test "count loop binds iteration variable" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  let state = run_zh(
    "变量 合计 = 0\n计次循环 5 次 为 i\n  合计 = 合计 + i\n结束\n",
    Map([], capacity=4),
    values,
  )
  match state.vars.get("合计") {
    Some(@studio_lang.VInt(n)) => assert_eq(n, 15)
    Some(@studio_lang.VNum(n)) => assert_eq(n, 15.0)
    _unused => fail("合计应为 15")
  }
}

///|
test "while loop with break stops early" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  let state = run_zh(
    "变量 i = 0\n当 i < 100 循环\n  i = i + 1\n  如果 i >= 4 则\n    跳出循环\n  结束\n结束\n",
    Map([], capacity=4),
    values,
  )
  match state.vars.get("i") {
    Some(@studio_lang.VInt(n)) => assert_eq(n, 4)
    Some(@studio_lang.VNum(n)) => assert_eq(n, 4.0)
    _unused => fail("i 应为 4")
  }
}

///|
test "message box and set text interplay" {
  let texts : Map[String, String] = Map([], capacity=4)
  texts["标签"] = "旧"
  let state = run_zh(
    "设置文本(标签, \"新\")\n信息框(取文本(标签))\n",
    texts,
    Map([], capacity=4),
  )
  assert_eq(state.messages.length(), 1)
  assert_eq(state.messages[0], "新")
  assert_eq(state.texts.get("标签").unwrap_or(""), "新")
  assert_true(state.audit.any(r => r.op is @studio_lang.OpMessage))
}

///|
test "submit_data gate pauses and confirm continues" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  values["成绩"] = @studio_lang.VNum(95.0)
  let state = @studio_lang.start_run_stmts(
    parse_body_ir(
      "提交数据(成绩, \"成绩单\")\n信息框(\"之后\")\n",
      @studio_lang.ZhHans,
    ),
    Map([], capacity=4),
    values,
    Map([], capacity=4),
  )
  // 起跑即停在闸门
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.WaitingGate)
  match state.gate {
    Some(gate) => {
      assert_true(gate.kind is @studio_lang.Submit)
      assert_eq(gate.payload, "95")
      assert_eq(gate.prompt, "成绩单")
    }
    None => fail("应停在闸门")
  }
  assert_eq(state.messages.length(), 0)
  @studio_lang.answer_gate(state, true)
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Completed)
  assert_eq(state.messages.length(), 1)
  assert_eq(state.messages[0], "之后")
  assert_true(state.audit.any(r => r.op is @studio_lang.OpGate))
}

///|
test "submit_data gate reject skips but completes" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  values["成绩"] = @studio_lang.VNum(95.0)
  let state = @studio_lang.start_run_stmts(
    parse_body_ir("提交数据(成绩, \"成绩单\")\n", @studio_lang.ZhHans),
    Map([], capacity=4),
    values,
    Map([], capacity=4),
  )
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.WaitingGate)
  @studio_lang.answer_gate(state, false)
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Completed)
  let mut gate_record : @studio_lang.StepRecord? = None
  for record in state.audit {
    if record.op is @studio_lang.OpGate {
      gate_record = Some(record)
    }
  }
  match gate_record {
    Some(record) => assert_true(record.detail.contains("rejected"))
    None => fail("应有闸门审计")
  }
}

///|
test "ask gate returns the answer text and short circuits" {
  let state = @studio_lang.start_run_stmts(
    parse_body_ir(
      "变量 回答 = 询问(\"继续?\")\n信息框(转文本(回答))\n",
      @studio_lang.ZhHans,
    ),
    Map([], capacity=4),
    Map([], capacity=4),
    Map([], capacity=4),
  )
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.WaitingGate)
  assert_true(state.gate.unwrap().kind is @studio_lang.Ask)
  // **`询问` 的返回值是回答文本**（Scratch 语义），不是「是否确认」。
  // 这条断言此前写的是 `"true"`——那正是把回答内容丢掉的旧行为。
  @studio_lang.answer_gate_with_text(state, true, "小明")
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Completed)
  assert_eq(state.messages[0], "小明")
}

///|
test "random is deterministic per seed and in range" {
  let body = parse_body_ir(
    "变量 a = 随机数(100)\n变量 b = 随机数(100)\n",
    @studio_lang.ZhHans,
  )
  let s1 = @studio_lang.start_run_stmts(
    body,
    Map([], capacity=4),
    Map([], capacity=4),
    Map([], capacity=4),
    seed=7,
  )
  @studio_lang.run_to_end(s1)
  let s2 = @studio_lang.start_run_stmts(
    body,
    Map([], capacity=4),
    Map([], capacity=4),
    Map([], capacity=4),
    seed=7,
  )
  @studio_lang.run_to_end(s2)
  let a1 = s1.vars.get("a").unwrap_or(@studio_lang.VUnit)
  let a2 = s2.vars.get("a").unwrap_or(@studio_lang.VUnit)
  assert_eq(@studio_lang.value_to_text(a1), @studio_lang.value_to_text(a2))
  match a1 {
    // 随机结果现在是整数身份（范围语义不变）
    @studio_lang.VInt(n) => assert_true(n >= 1 && n <= 100)
    @studio_lang.VNum(n) => assert_true(n >= 1.0 && n <= 100.0)
    _unused => fail("a 应为数值")
  }
}

///|
test "runtime errors are structured" {
  let state = run_zh("变量 x = y\n", Map([], capacity=4), Map([], capacity=4))
  assert_true(state.status is @studio_lang.Failed)
  match state.error {
    Some(error) => {
      assert_true(error.kind() is @studio_lang.NotDeclared)
      assert_eq(error.a(), "y")
    }
    None => fail("应有错误")
  }
  let div = run_zh(
    "变量 x = 1 / 0\n",
    Map([], capacity=4),
    Map([], capacity=4),
  )
  assert_true(div.error.unwrap().kind() is @studio_lang.DivideByZero)
  let wrong = run_zh(
    "变量 x = 1 + \"a\" + 2\n",
    Map([], capacity=4),
    Map([], capacity=4),
  )
  assert_true(wrong.status is @studio_lang.Completed)
  assert_eq(
    @studio_lang.value_to_text(
      wrong.vars.get("x").unwrap_or(@studio_lang.VUnit),
    ),
    "1a2",
  )
  let boom = run_zh(
    "变量 x = 不存在的函数(1)\n",
    Map([], capacity=4),
    Map([], capacity=4),
  )
  assert_true(boom.error.unwrap().kind() is @studio_lang.UnknownBuiltin)
  let arity = run_zh(
    "信息框(\"a\", \"b\")\n",
    Map([], capacity=4),
    Map([], capacity=4),
  )
  assert_true(arity.error.unwrap().kind() is @studio_lang.ArityMismatch)
}

///|
test "step budget fails runaway loops" {
  let state = @studio_lang.start_run_stmts(
    parse_body_ir("当 真 循环\n结束\n", @studio_lang.ZhHans),
    Map([], capacity=4),
    Map([], capacity=4),
    Map([], capacity=4),
    max_steps=500,
  )
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Failed)
  assert_true(state.error.unwrap().kind() is @studio_lang.StepBudget)
}

///|
test "number text conversions" {
  match @studio_lang.text_to_number("  -12.5 ") {
    Some(n) => assert_eq(n, -12.5)
    None => fail("应解析 -12.5")
  }
  assert_true(@studio_lang.text_to_number("abc") is None)
  assert_eq(@studio_lang.number_to_text(3.0), "3")
  assert_eq(@studio_lang.number_to_text(3.5), "3.5")
}

///|
test "language validation catches break and command position" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [
          @ir.Break,
          @ir.Assign("x", @ir.Call("message_box", [@ir.StrLit("hi")])),
          @ir.Call("信息框", [@ir.StrLit("a"), @ir.StrLit("b")]),
        ],
      },
    ],
    functions: [],
  }
  let errors = @studio_lang.validate_program_language(program)
  assert_true(errors.any(e => e.kind() is @studio_lang.BreakOutsideLoop))
  assert_true(
    errors.any(e => {
      e.kind() is @studio_lang.TypeMismatch && e.a() == "message_box"
    }),
  )
  assert_true(
    errors.any(e => {
      e.kind() is @studio_lang.ArityMismatch && e.a() == "message_box"
    }),
  )
  let clean = @studio_lang.validate_program_language(@ir.StudioProgram::{
    version: 1,
    window: @ir.default_window(),
    controls: [],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [
          @ir.CountLoop(@ir.IntLit(2), None, [
            @ir.Call("message_box", [@ir.StrLit("hi")]),
          ]),
        ],
      },
    ],
    functions: [],
  })
  assert_true(clean.is_empty())
}

///|
test "selected row and append row work on rows map" {
  let rows : Map[String, Array[String]] = Map([], capacity=4)
  rows["列表"] = ["a", "b", "c"]
  let state = @studio_lang.start_run_stmts(
    parse_body_ir(
      "信息框(取所选行(列表))\n追加行(列表, \"d\")\n",
      @studio_lang.ZhHans,
    ),
    Map([], capacity=4),
    Map([], capacity=4),
    rows,
  )
  @studio_lang.run_to_end(state)
  match state.error {
    Some(error) => fail("运行报错: \{error.a()} @\{error.line()}")
    None => ()
  }
  assert_true(state.status is @studio_lang.Completed)
  assert_eq(state.messages.length(), 1)
  assert_eq(state.messages[0], "a")
  assert_eq(state.rows.get("列表").unwrap_or([]).length(), 4)
}

///|
test "cancel stops the run" {
  let state = @studio_lang.start_run_stmts(
    parse_body_ir(
      "计次循环 10 次\n  信息框(\"x\")\n结束\n",
      @studio_lang.ZhHans,
    ),
    Map([], capacity=4),
    Map([], capacity=4),
    Map([], capacity=4),
  )
  @studio_lang.step_once(state)
  @studio_lang.cancel(state)
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Failed)
  assert_true(state.messages.length() == 0)
}

///|
test "audit records loop iterations and conditions" {
  let state = run_zh(
    "计次循环 2 次\n  信息框(\"第\")\n结束\n当 假 循环\n结束\n",
    Map([], capacity=4),
    Map([], capacity=4),
  )
  assert_true(
    state.audit.any(r => {
      r.op is @studio_lang.OpLoop && r.detail == "iteration 1"
    }),
  )
  assert_true(
    state.audit.any(r => {
      r.op is @studio_lang.OpLoop && r.detail == "iteration 2"
    }),
  )
  assert_true(state.audit.any(r => r.op is @studio_lang.OpCondition))
  assert_eq(state.messages.length(), 2)
}

///|
test "declare form renders per language and guards assignment" {
  let ir = parse_body_ir(
    "变量 得分 = 60\n如果 得分 >= 60 则\n  信息框(\"过\")\n结束\n",
    @studio_lang.ZhHans,
  )
  let zh_text = @studio_lang.render_stmts(ir, @studio_lang.ZhHans)
  let en_text = @studio_lang.render_stmts(ir, @studio_lang.En)
  assert_true(zh_text.contains("变量 得分 = 60"))
  assert_true(en_text.contains("let 得分 = 60"))
  assert_eq(
    @ir.stmts_signature(parse_body_ir(zh_text, @studio_lang.ZhHans)),
    @ir.stmts_signature(ir),
  )
  assert_eq(
    @ir.stmts_signature(parse_body_ir(en_text, @studio_lang.En)),
    @ir.stmts_signature(ir),
  )
  let bad = run_zh("得分 = 60\n", Map([], capacity=4), Map([], capacity=4))
  assert_true(bad.status is @studio_lang.Failed)
  match bad.error {
    Some(error) => {
      assert_true(error.kind() is @studio_lang.NotDeclared)
      assert_eq(error.a(), "得分")
    }
    None => fail("未声明赋值应报错")
  }
}

///|
/// 整数类型（切片 F）：
/// - 整数 ÷ 整数向零截断，除零报错
/// - 混合运算提升为浮点
/// - 整数身份跨赋值保留（计数器不再有 3.0000001 类漂移的观感）
/// - 显示与审计文本：VInt 与等值 VNum 同串（两轨差分门依赖这一点）
test "integer semantics: truncation, promotion, identity" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=8)
  let state = run_zh(
    "变量 整除 = 7 / 2\n变量 浮除 = 7.0 / 2\n变量 提升 = 7 / 2.0\n变量 计数 = 0\n计数 = 计数 + 1\n",
    Map([], capacity=4),
    values,
  )
  assert_true(state.status is @studio_lang.Completed)
  match state.vars.get("整除") {
    Some(@studio_lang.VInt(n)) => assert_eq(n, 3)
    _other => fail("7 / 2 应为整数 3")
  }
  match state.vars.get("浮除") {
    Some(@studio_lang.VNum(n)) => assert_true(n > 3.4 && n < 3.6)
    _other => fail("7.0 / 2 应为浮点 3.5")
  }
  match state.vars.get("提升") {
    Some(@studio_lang.VNum(n)) => assert_true(n > 3.4 && n < 3.6)
    Some(@studio_lang.VInt(_)) => fail("混合运算不应保持整数身份")
    _other => fail("7 / 2.0 应为浮点 3.5")
  }
  match state.vars.get("计数") {
    Some(@studio_lang.VInt(n)) => assert_eq(n, 1)
    _other => fail("计数应为整数 1")
  }
  // 审计文本与等值浮点同串（value_to_text 口径）
  assert_eq(@studio_lang.value_to_text(@studio_lang.VInt(3)), "3")
  assert_eq(
    @studio_lang.value_to_text(@studio_lang.VInt(3)),
    @studio_lang.value_to_text(@studio_lang.VNum(3.0)),
  )
}

///|
/// 数组（切片 F）：字面量、下标读写（1 起）、越界报错、列表内建、
/// 双语往返与两轨一致。
test "arrays: literal, index, append, length" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=8)
  let state = run_zh(
    "变量 名单 = [\"张三\", \"李四\"]\n名单[2] = \"王五\"\n变量 第二 = 名单[2]\n加入列表(名单, \"赵六\")\n变量 数量 = 列表长度(名单)\n",
    Map([], capacity=4),
    values,
  )
  assert_true(state.status is @studio_lang.Completed)
  match state.vars.get("第二") {
    Some(@studio_lang.VStr(text)) => assert_eq(text, "王五")
    _other => fail("名单[2] 应为 王五")
  }
  match state.vars.get("数量") {
    Some(@studio_lang.VInt(n)) => assert_eq(n, 3)
    _other => fail("列表长度应为 3")
  }
  match state.vars.get("名单") {
    Some(@studio_lang.VArr(items)) => {
      assert_eq(items.length(), 3)
      assert_eq(@studio_lang.value_to_text(items[0]), "张三")
      assert_eq(@studio_lang.value_to_text(items[2]), "赵六")
    }
    _other => fail("名单应为列表")
  }
  // 越界：结构化错误
  let bad = run_zh("变量 表 = [1, 2]\n变量 爆 = 表[5]\n", Map([], capacity=4), Map([], capacity=4))
  assert_true(bad.status is @studio_lang.Failed)
  assert_true(bad.error is Some(_))
  // 双语往返
  let zh_source = "变量 表 = [1, 2]\n表[1] = 9\n"
  match @studio_lang.parse_handler_body(zh_source, @studio_lang.ZhHans) {
    Err(_) => fail("数组语句应可解析")
    Ok(body) => {
      let rendered = @studio_lang.render_stmts(
        body.map(t => t.stmt),
        @studio_lang.En,
      )
      match @studio_lang.parse_handler_body(rendered, @studio_lang.En) {
        Err(_) => fail("英文渲染应可回析")
        Ok(round) =>
          assert_eq(
            @ir.stmts_signature(body.map(t => t.stmt)),
            @ir.stmts_signature(round.map(t => t.stmt)),
          )
      }
    }
  }
}

///|
/// 广播消息（切片 G）：`广播(文案)` 入总线队列，宿主排空后投递给
/// @广播消息 窗体级处理器（文案经伪变量 `消息文本` 传递）。
test "broadcast queues text for window handlers" {
  let values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  let state = run_zh(
    "广播(\"下课了\")\n广播(\"集合\")\n",
    Map([], capacity=4),
    values,
  )
  assert_true(state.status is @studio_lang.Completed)
  assert_eq(state.broadcasts.length(), 2)
  assert_eq(state.broadcasts[0], "下课了")
  assert_eq(state.broadcasts[1], "集合")
}
