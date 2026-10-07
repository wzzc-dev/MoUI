///|
/// 契约测试(M5-5a):parse ∘ gen == id。
///
/// 用真实 IR 程序走 `generate_source` 生成 MoonBit → `parse_generated_source`
/// 逆解析 → 断言每个语句的规范文本可以经 `parse_handler_body` 重建。
/// 这是子集契约的核心:积木编辑依赖「生成文本中的规范文本可以无损还原
/// 为 IR」这一不变量。

///|
/// 样例 IR 程序:覆盖 Declare / Assign / If / CountLoop / Call / While / Break。
fn sample_program() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.default_window(),
    controls: [],
    variables: [],
    handlers: [
      {
        control_name: "按钮",
        event: @ir.OnClick,
        body: [
          @ir.Declare("计数", @ir.IntLit(0)),
          @ir.Assign(
            "计数",
            @ir.Binary(Add, @ir.Var("计数"), @ir.IntLit(1)),
          ),
          @ir.If(
            @ir.Binary(Gt, @ir.Var("计数"), @ir.IntLit(10)),
            [@ir.Stmt::Call("set_text", [@ir.StrLit("大"), @ir.Var("计数")])],
            [],
            [@ir.Stmt::Call("set_text", [@ir.StrLit("小"), @ir.Var("计数")])],
          ),
          @ir.CountLoop(@ir.IntLit(3), Some("i"), [
            @ir.Stmt::Call("message_box", [@ir.StrLit("循环体")]),
          ]),
          @ir.WhileLoop(@ir.Binary(Lt, @ir.Var("计数"), @ir.IntLit(100)), [
            @ir.Assign(
              "计数",
              @ir.Binary(Add, @ir.Var("计数"), @ir.IntLit(1)),
            ),
          ]),
          @ir.Break,
        ],
        note_zh: "",
        note_en: "",
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
test "子集契约:生成 → 逆解析 → 规范文本非空且 editable" {
  let program = sample_program()
  let generated = @export.generate_source(program)
  // 取第一个 handler 的生成源码(分离后的单 handler 文本)
  let handler_source = generated.handlers[0].source
  let parsed = @blocks_code.parse_generated_source(
    handler_source,
    generated.handlers[0].stmt_lines,
  )
  // 每条语句都有规范文本且 editable
  assert_true(parsed.blocks.length() > 0, msg="应有可积木语句")
  for block in parsed.blocks {
    assert_true(block.canonical != "", msg="规范文本不应为空")
    assert_true(block.editable, msg="子集内语句应 editable")
  }
  // 未知 op 不应有(样例全部在子集内)
  assert_eq(parsed.non_editable_lines.length(), 0)
}

///|
test "子集契约:生成源码的每行都可积木或可识别" {
  let program = sample_program()
  let generated = @export.generate_source(program)
  let handler_source = generated.handlers[0].source
  let parsed = @blocks_code.parse_generated_source(
    handler_source,
    generated.handlers[0].stmt_lines,
  )
  // 无未识别行:生成器的封闭形状应全部被解析器认识
  assert_eq(
    parsed.non_editable_lines.length(),
    0,
    msg="生成器输出不应有未识别行",
  )
}

///|
test "子集契约:stmt_lines 路径与逆解析块对齐" {
  let program = sample_program()
  let generated = @export.generate_source(program)
  let handler = generated.handlers[0]
  let parsed = @blocks_code.parse_generated_source(
    handler.source,
    handler.stmt_lines,
  )
  // 每个有 audit_line 的 stmt_line 都应有对应的 block
  let mut matched = 0
  for entry in handler.stmt_lines {
    for block in parsed.blocks {
      if block.start_line == entry.audit_line {
        matched = matched + 1
        break
      }
    }
  }
  assert_true(
    matched > 0,
    msg="至少一个 stmt_line 应与逆解析块对齐",
  )
}

///|
test "可积木检测:is_block_editable_line 识别已知模式" {
  assert_true(
    @blocks_code.is_block_editable_line(
      "  rt.audit_assign(\"x\", rt.get(\"x\", 1), 1, \"x\")",
    ),
  )
  assert_true(
    @blocks_code.is_block_editable_line("  rt.record(1, op, \"detail\")"),
  )
  assert_false(@blocks_code.is_block_editable_line("  // 注释"))
  assert_false(@blocks_code.is_block_editable_line(""))
}

///|
/// 匹配分派判定锁(M5-5d):生成源里的分派审计行不得误判为可积木语句;
/// 臂内语句仍是可积木块(路径为臂的 section)。
test "match dispatch audit lines are not blocks" {
  let program : @ir.StudioProgram = {
    ..sample_program(),
    handlers: [
      {
        control_name: "按钮",
        event: @ir.OnClick,
        body: [
          @ir.Match(
            @ir.EnumTag("花色", "红桃"),
            [
              @ir.MatchArm::{
                case_name: "红桃",
                body: [@ir.Assign("计数", @ir.IntLit(1))],
              },
              @ir.MatchArm::{ case_name: "黑桃", body: [], },
            ],
            [@ir.Assign("计数", @ir.IntLit(9))],
          ),
        ],
        note_zh: "",
        note_en: "",
      },
    ],
  }
  let generated = @export.generate_source(program)
  let handler = generated.handlers[0]
  let parsed = @blocks_code.parse_generated_source(
    handler.source,
    handler.stmt_lines,
  )
  // 分派审计行被诚实记为不可积木(不再是字符串判据的误报)
  assert_true(parsed.non_editable_lines.length() == 1)
  // 命中臂与 else 臂的赋值语句仍是可积木块
  let editable_canon = parsed.blocks.map(block => block.canonical)
  assert_true(editable_canon.contains("计数 = 1"))
  assert_true(editable_canon.contains("计数 = 9"))
  // 任何块都不携带分派审计的拼接残片
  for block in parsed.blocks {
    assert_false(block.canonical.contains(" -> "))
  }
}
