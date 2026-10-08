///|
/// 双轨差分矩阵（硬门）。
///
/// 覆盖：
///   - 4 个内置样例的全部 handler（真实教学程序）
///   - 每类语句的合成 handler（Assign / If 含 elseif+else / 计次循环 /
///     当循环 / 跳出 / 命令调用 / 函数调用 / 闸门）
///   - 每种情形 × zh-Hans 与 en-US：渲染源码 → 解析回 Trace → 两轨各跑
///   - 失败注入情形（未声明赋值 / 除零 / 未知内建 / 非数值循环次数）
///
/// 断言是逐项的：控件文本、变量终态、完整审计序列 (line, op, detail)、
/// 闸门状态与应答结果、运行终态、错误类型与行号。任何一项不等
/// 就是失败——没有「已知差异清单」，不一致按 P0 处理。

///|
fn languages() -> Array[@studio_lang.Language] {
  [@studio_lang.ZhHans, @studio_lang.En]
}

///|
fn assert_no_mismatch(report : @diff.DiffReport) -> Unit raise {
  if report.mismatches.length() > 0 {
    let buf = StringBuilder()
    buf.write_string("双轨差分失败 [")
    buf.write_string(report.case_name)
    buf.write_string("]:\n")
    for item in report.mismatches {
      buf.write_string("  - ")
      buf.write_string(item)
      buf.write_string("\n")
    }
    fail(buf.to_string())
  }
}

///|
/// 全部内置样例。
fn samples() -> Array[@ir.StudioProgram] {
  [
    @proposals.sample_hello(),
    @proposals.sample_roll_call(),
    @proposals.sample_drill(),
    @proposals.sample_store(),
  ]
}

///|
/// 样例里第一个可用于写文本的控件名（label / button / text_field）。
fn writable_control(program : @ir.StudioProgram) -> String {
  for control in program.controls {
    match control.kind {
      @ir.Label | @ir.Button | @ir.TextField => return control.name
      _ => ()
    }
  }
  "???"
}

///|
/// 样例里第一个数值初值变量（用于循环次数与算术）。
fn numeric_variable(program : @ir.StudioProgram) -> String {
  for variable in program.variables {
    if @studio_lang.text_to_number(variable.init) is Some(_) {
      return variable.name
    }
  }
  "???"
}

///|
/// 合成一个针对给定样例程序可运行的 handler（控件名/变量名都取自样例）。
fn synthetic_handler(
  program : @ir.StudioProgram,
  body : Array[@ir.Stmt],
) -> @ir.Handler {
  @ir.Handler::{
    control_name: writable_control(program),
    event: @ir.OnClick,
    note_zh: "差分合成样例",
    note_en: "synthetic diff sample",
    body,
  }
}

///|
/// 每类语句的合成处理器（对每个样例都跑一遍，语言双跑）。
fn statement_kind_handlers(
  program : @ir.StudioProgram,
) -> Array[(String, @ir.Handler)] {
  let label = writable_control(program)
  let counter = numeric_variable(program)
  let results : Array[(String, @ir.Handler)] = []
  // Declare + Assign（声明后重赋值）
  results.push(
    (
      "declare+assign",
      synthetic_handler(program, [
        @ir.Declare("差分计数", @ir.IntLit(1)),
        @ir.Assign(
          "差分计数",
          @ir.Binary(@ir.Add, @ir.Var("差分计数"), @ir.IntLit(2)),
        ),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Call("to_text", [@ir.Var("差分计数")]),
        ]),
      ]),
    ),
  )
  // If：then / elseif / else 三条臂依次取值
  results.push(
    (
      "if-branches",
      synthetic_handler(program, [
        @ir.Declare("差分分支", @ir.IntLit(2)),
        @ir.If(
          @ir.Binary(@ir.Eq, @ir.Var("差分分支"), @ir.IntLit(1)),
          [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("一")])],
          [
            (
              @ir.Binary(@ir.Eq, @ir.Var("差分分支"), @ir.IntLit(2)),
              [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("二")])],
            ),
          ],
          [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("其他")])],
        ),
      ]),
    ),
  )
  // 计次循环（带循环变量）
  results.push(
    (
      "count-loop",
      synthetic_handler(program, [
        @ir.Declare("差分累加", @ir.IntLit(0)),
        @ir.CountLoop(@ir.IntLit(4), Some("差分序号"), [
          @ir.Assign(
            "差分累加",
            @ir.Binary(
              @ir.Add,
              @ir.Var("差分累加"),
              @ir.Var("差分序号"),
            ),
          ),
        ]),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Call("to_text", [@ir.Var("差分累加")]),
        ]),
      ]),
    ),
  )
  // 遍历循环（G7.1）:列表字面量逐元素绑定 + 文本累加,两轨审计逐位一致
  results.push(
    (
      "for-each",
      synthetic_handler(program, [
        @ir.Declare("差分点名", @ir.StrLit("")),
        @ir.ForEach(
          @ir.ListLit([@ir.StrLit("甲"), @ir.StrLit("乙"), @ir.StrLit("丙")]),
          "差分成员",
          [
            @ir.Assign(
              "差分点名",
              @ir.Binary(
                @ir.Add,
                @ir.Var("差分点名"),
                @ir.Var("差分成员"),
              ),
            ),
          ],
        ),
        @ir.Call("set_text", [@ir.Var(label), @ir.Var("差分点名")]),
      ]),
    ),
  )
  // G7.1 内建补全:字符串（连接/大写）+ 列表查找,两轨文本逐位一致
  results.push(
    (
      "builtins-g7",
      synthetic_handler(program, [
        @ir.Declare(
          "差分文本",
          @ir.Call("join", [
            @ir.StrLit("分数: "),
            @ir.Call("to_text", [@ir.IntLit(5)]),
          ]),
        ),
        @ir.Assign("差分文本", @ir.Call("upper", [@ir.Var("差分文本")])),
        @ir.Declare(
          "差分名单",
          @ir.ListLit([@ir.StrLit("甲"), @ir.StrLit("乙")]),
        ),
        @ir.Declare(
          "差分位置",
          @ir.Call("index_of_list", [@ir.Var("差分名单"), @ir.StrLit("乙")]),
        ),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Call("join", [
            @ir.Var("差分文本"),
            @ir.Call("to_text", [@ir.Var("差分位置")]),
          ]),
        ]),
      ]),
    ),
  )
  // 计次循环 + 跳出（第 2 轮跳出）
  results.push(
    (
      "count-loop+break",
      synthetic_handler(program, [
        @ir.Declare("差分中断", @ir.IntLit(0)),
        @ir.CountLoop(@ir.IntLit(5), None, [
          @ir.Assign(
            "差分中断",
            @ir.Binary(@ir.Add, @ir.Var("差分中断"), @ir.IntLit(1)),
          ),
          @ir.If(
            @ir.Binary(@ir.Ge, @ir.Var("差分中断"), @ir.IntLit(2)),
            [@ir.Break],
            [],
            [],
          ),
        ]),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Call("to_text", [@ir.Var("差分中断")]),
        ]),
      ]),
    ),
  )
  // 当循环（条件递减到 0）
  results.push(
    (
      "while-loop",
      synthetic_handler(program, [
        @ir.Declare("差分倒计时", @ir.IntLit(3)),
        @ir.WhileLoop(
          @ir.Binary(@ir.Gt, @ir.Var("差分倒计时"), @ir.IntLit(0)),
          [
            @ir.Assign(
              "差分倒计时",
              @ir.Binary(@ir.Sub, @ir.Var("差分倒计时"), @ir.IntLit(1)),
            ),
          ],
        ),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Call("to_text", [@ir.Var("差分倒计时")]),
        ]),
      ]),
    ),
  )
  // 匹配分派（M5-5d）：命中乙臂 / 落 else 两种路径
  results.push(
    (
      "match-dispatch",
      synthetic_handler(program, [
        @ir.Declare("差分分支", @ir.EnumTag("差分牌", "乙")),
        @ir.Match(
          @ir.Var("差分分支"),
          [
            @ir.MatchArm::{
              case_name: "甲",
              body: [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("甲")])],
            },
            @ir.MatchArm::{
              case_name: "乙",
              body: [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("乙")])],
            },
          ],
          [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("其他")])],
        ),
        @ir.Match(
          @ir.EnumTag("差分牌", "丙"),
          [
            @ir.MatchArm::{
              case_name: "甲",
              body: [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("甲")])],
            },
          ],
          [@ir.Call("set_text", [@ir.Var(label), @ir.StrLit("其他")])],
        ),
      ]),
    ),
  )
  // 命令调用（message_box + set_text）
  results.push(
    (
      "command-calls",
      synthetic_handler(program, [
        @ir.Call("message_box", [@ir.StrLit("差分消息")]),
        @ir.Call("set_text", [@ir.Var(label), @ir.StrLit("差分文本")]),
      ]),
    ),
  )
  // 函数调用（表达式位的 6 个只读内建）
  results.push(
    (
      "function-calls",
      synthetic_handler(program, [
        @ir.Declare("差分文本", @ir.Call("to_text", [@ir.IntLit(42)])),
        @ir.Declare(
          "差分长度",
          @ir.Call("text_length", [@ir.Var("差分文本")]),
        ),
        @ir.Declare(
          "差分包含",
          @ir.Call("contains", [@ir.Var("差分文本"), @ir.StrLit("4")]),
        ),
        @ir.Declare("差分上限", @ir.Call("random", [@ir.IntLit(9)])),
        @ir.Call("set_text", [
          @ir.Var(label),
          @ir.Binary(
            @ir.Add,
            @ir.Binary(
              @ir.Add,
              @ir.Call("to_text", [@ir.Var("差分长度")]),
              @ir.StrLit("/"),
            ),
            @ir.Call("to_text", [@ir.Var("差分包含")]),
          ),
        ]),
      ]),
    ),
  )
  // 闸门：submit_data 停下等人；确认后继续
  results.push(
    (
      "gate-submit-confirm",
      synthetic_handler(program, [
        @ir.Call("submit_data", [
          @ir.Call("to_text", [@ir.Var(counter)]),
          @ir.StrLit("差分账本"),
        ]),
        @ir.Call("message_box", [@ir.StrLit("已确认")]),
      ]),
    ),
  )
  // 闸门：ask 拒绝（返回 false 走 else）
  results.push(
    (
      "gate-ask-reject",
      synthetic_handler(program, [
        @ir.Declare(
          "差分决定",
          @ir.Call("ask", [@ir.StrLit("要提交吗")]),
        ),
        @ir.If(
          @ir.Var("差分决定"),
          [@ir.Call("message_box", [@ir.StrLit("已提交")])],
          [],
          [@ir.Call("message_box", [@ir.StrLit("已取消")])],
        ),
      ]),
    ),
  )
  // 追加行（副作用进 rows）
  results.push(
    (
      "append-row",
      synthetic_handler(program, [
        @ir.Declare("差分行", @ir.Call("to_text", [@ir.IntLit(7)])),
        @ir.Call("append_row", [@ir.Var(label), @ir.Var("差分行")]),
      ]),
    ),
  )
  // 失败注入：未声明赋值
  results.push(
    (
      "error-not-declared",
      synthetic_handler(program, [@ir.Assign("差分未声明", @ir.IntLit(1))]),
    ),
  )
  // 失败注入：除零
  results.push(
    (
      "error-divide-by-zero",
      synthetic_handler(program, [
        @ir.Declare(
          "差分除零",
          @ir.Binary(@ir.Div, @ir.IntLit(1), @ir.IntLit(0)),
        ),
      ]),
    ),
  )
  // 失败注入：未知内建（两轨同走 UnknownBuiltin）
  results.push(
    (
      "error-unknown-builtin",
      synthetic_handler(program, [
        @ir.Call("差分不存在的内建", [@ir.IntLit(1)]),
      ]),
    ),
  )
  // 失败注入：非数值循环次数
  results.push(
    (
      "error-bad-loop-count",
      synthetic_handler(program, [
        @ir.CountLoop(@ir.StrLit("三"), None, [
          @ir.Call("message_box", [@ir.StrLit("不会到达")]),
        ]),
      ]),
    ),
  )
  results
}

///|
/// 矩阵主体：样例 handler × 语言。
test "diff matrix: builtin samples in both languages" {
  for program in samples() {
    let sample_name = program.window.title
    for handler in program.handlers {
      let case_name = "\{sample_name}/\{handler.control_name}@\{handler.event.tag()}"
      for language in languages() {
        let report = @diff.diff_case(
          "\{case_name}[\{language.tag()}]",
          program,
          handler,
          language,
          [],
        )
        assert_no_mismatch(report)
      }
    }
  }
}

///|
/// 矩阵主体：每类语句 × 每个样例 × 两种语言。
test "diff matrix: every statement kind in both languages" {
  for program in samples() {
    let sample_name = program.window.title
    for entry in statement_kind_handlers(program) {
      let (kind, handler) = entry
      for language in languages() {
        let answers : Array[Bool] = match kind {
          "gate-submit-confirm" => [true]
          "gate-ask-reject" => [false]
          _ => []
        }
        let report = @diff.diff_case(
          "\{sample_name}/\{kind}[\{language.tag()}]",
          program,
          handler,
          language,
          answers,
        )
        assert_no_mismatch(report)
      }
    }
  }
}

///|
/// 闸门未应答时必须停在闸门前，且两轨的闸门形状（类型/提示/载荷）逐项一致；
/// 应答后也必须一致地走到同一终态。
test "diff matrix: unresolved gate shape matches before answering" {
  for program in samples() {
    let handler = synthetic_handler(program, [
      @ir.Call("submit_data", [@ir.StrLit("载荷"), @ir.StrLit("差分目标")]),
      @ir.Call("message_box", [@ir.StrLit("闸门之后")]),
    ])
    for language in languages() {
      let source = @studio_lang.render_handler(handler, language)
      let body = match @studio_lang.parse_handler_body(source, language) {
        Ok(body) => body
        Err(error) => fail("闸门合成样例无法解析: \{error.line()}")
      }
      for answers in [[], [true], [false]] {
        let report = @diff.compare(
          "gate-shape[\{language.tag()}]/\{answers.length()}",
          @diff.observe_interp(body, program, answers),
          @diff.observe_compiled(body, program, answers),
        )
        assert_no_mismatch(report)
      }
    }
  }
}

///|
/// G7.1:启动事件——纯 OnStart 程序（零控件）两轨执行其体,审计逐位一致。
test "diff matrix: OnStart standalone program" {
  let program : @ir.StudioProgram = {
    ..@ir.empty_program(),
    window: {
      title: "OnStart门禁",
      width: 640,
      height: 480,
      timer_interval: 0,
      back_color: "",
    },
    variables: [{ name: "开机计数", init: "0", }],
    handlers: [
      {
        control_name: "",
        event: @ir.OnStart,
        note_zh: "开机即累加",
        note_en: "increment on start",
        body: [
          @ir.Assign(
            "开机计数",
            @ir.Binary(@ir.Add, @ir.Var("开机计数"), @ir.IntLit(1)),
          ),
        ],
      },
    ],
  }
  for language in languages() {
    let report = @diff.diff_case(
      "OnStart[\{language.tag()}]",
      program,
      program.handlers[0],
      language,
      [],
    )
    assert_no_mismatch(report)
  }
}

///|
/// G7.2:属性 v2 不影响双轨执行语义——带样式的控件与默认控件产生
/// 相同的审计序列（属性是纯展示数据，不进 IR 语义路径）。
test "diff matrix: props don't affect execution semantics" {
  let program : @ir.StudioProgram = {
    ..@ir.empty_program(),
    window: {
      title: "props-gate",
      width: 640,
      height: 480,
      timer_interval: 0,
      back_color: "",
    },
    variables: [{ name: "计数", init: "0", }],
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "btn",
        text: "点我",
        x: 20,
        y: 20,
        width: 100,
        height: 32,
        items: [],
        props: @ir.ControlProps::{
          font_size: 20,
          bold: true,
          text_color: "#FF0000",
          back_color: "#00FF00",
          align: "center",
          visible: true,
          disabled: false,
          multiline: false,
          placeholder: "",
          password: false,
        },
      },
    ],
    handlers: [
      {
        control_name: "btn",
        event: @ir.OnClick,
        note_zh: "累加",
        note_en: "increment",
        body: [
          @ir.Assign(
            "计数",
            @ir.Binary(@ir.Add, @ir.Var("计数"), @ir.IntLit(1)),
          ),
          @ir.Call("set_text", [
            @ir.Var("btn"),
            @ir.Call("to_text", [@ir.Var("计数")]),
          ]),
        ],
      },
    ],
  }
  for language in languages() {
    let report = @diff.diff_case(
      "props-gate[\{language.tag()}]",
      program,
      program.handlers[0],
      language,
      [],
    )
    assert_no_mismatch(report)
  }
}
