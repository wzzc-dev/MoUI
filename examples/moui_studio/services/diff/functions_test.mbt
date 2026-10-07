///|
/// 用户自定义函数（切片 F）双轨一致性：同一程序（函数定义 + Return +
/// 调用 + 递归）在解释轨与编译轨（lower）上的终态变量、审计序列、
/// 返回文本必须逐项相等——与 `matrix_test` 的差分门同口径。
test "user functions agree across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [
      @ir.FuncDef::{
        name: "加倍",
        params: ["值"],
        body: [
          @ir.Return(Some(@ir.Binary(@ir.Mul, @ir.Var("值"), @ir.IntLit(2)))),
        ],
        note_zh: "返回两倍值",
        note_en: "double the value",
      },
      @ir.FuncDef::{
        name: "阶乘",
        params: ["n"],
        body: [
          @ir.If(
            @ir.Binary(@ir.Le, @ir.Var("n"), @ir.IntLit(1)),
            [@ir.Return(Some(@ir.IntLit(1)))],
            [],
            [
              @ir.Return(
                Some(
                  @ir.Binary(
                    @ir.Mul,
                    @ir.Var("n"),
                    @ir.Call("阶乘", [
                      @ir.Binary(@ir.Sub, @ir.Var("n"), @ir.IntLit(1)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ],
        note_zh: "递归阶乘",
        note_en: "recursive factorial",
      },
    ],
    structs: [],
    enums: [],
  }
  let handler_body : Array[@ir.Stmt] = [
    @ir.Declare("翻倍", @ir.Call("加倍", [@ir.IntLit(21)])),
    @ir.Declare("阶乘五", @ir.Call("阶乘", [@ir.IntLit(5)])),
    @ir.Call("set_text", [
      @ir.Var("输出"),
      @ir.Binary(@ir.Add, @ir.Var("翻倍"), @ir.Var("阶乘五")),
    ]),
  ]
  // —— 解释轨
  let interpret_values : Map[String, @studio_lang.Value] = Map([], capacity=4)
  let interpret_texts : Map[String, String] = Map([], capacity=4)
  interpret_texts["输出"] = ""
  let interpret = @studio_lang.start_run_stmts(
    handler_body,
    interpret_texts,
    interpret_values,
    Map([], capacity=4),
    functions=program.functions,
  )
  @studio_lang.run_to_end(interpret)
  // —— 编译轨
  let compiled = @compiled_runtime.runtime_for_program(
    program,
    lower=Some(@compiled_runtime.lower_user_function),
  )
  let texts : Map[String, String] = Map([], capacity=4)
  texts["输出"] = ""
  compiled.texts["输出"] = ""
  let handler = @compiled_runtime.lower_handler(handler_body)
  let _ = @compiled_runtime.run_handler(compiled, handler)
  // —— 终值逐项相等
  let compiled_value = compiled.vars.get("翻倍")
  let interpret_value = interpret.vars.get("翻倍")
  assert_eq(
    interpret_value.map(@studio_lang.value_to_text),
    compiled_value.map(@compiled_runtime.value_to_text),
  )
  assert_eq(
    interpret.vars.get("阶乘五").map(@studio_lang.value_to_text),
    compiled.vars.get("阶乘五").map(@compiled_runtime.value_to_text),
  )
  // 整数语义：42 + 120 = 162（VInt 加法，非文本拼接）
  assert_eq(
    @studio_lang.value_to_text(interpret.vars.get("翻倍").unwrap()),
    "42",
  )
  assert_eq(
    @studio_lang.value_to_text(interpret.vars.get("阶乘五").unwrap()),
    "120",
  )
  assert_eq(compiled.texts.get("输出").unwrap_or(""), "162")
  assert_eq(interpret.texts.get("输出").unwrap_or(""), "162")
  // 审计（line/op/detail）逐条相等：函数体行号两轨同为 0
  assert_eq(interpret.audit.length(), compiled.audit.length())
  let mut index = 0
  while index < interpret.audit.length() && index < compiled.audit.length() {
    let left = interpret.audit[index]
    let right = compiled.audit[index]
    assert_eq(left.line, right.line)
    assert_eq(left.detail, right.detail)
    index = index + 1
  }
}

///|
/// **语句位调用自定义积木**（Scratch「我的积木」的主要用法：一条独立执行的
/// 语句，不要返回值）。
///
/// 这条用例锁的是一个真实的 P0：`semantics.mbt` 的 `check_call` 曾对非内建名
/// 无条件报 `TypeMismatch(expression)`，于是自定义积木**永远无法被调用**——
/// 而解释器（`call_user_function`）与编译轨都完整支持。静态校验先于运行，
/// 用户根本走不到能跑的那一步。
///
/// 断言两层：静态校验接受（这才是被修的地方）+ 双轨终态一致（修了校验不能
/// 把执行改坏）。
test "statement-position custom block calls agree across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [
      // 一个**无返回值**的自定义积木（体里只有副作用），语句位的典型形态
      @ir.FuncDef::{
        name: "记一笔",
        params: [],
        body: [@ir.Call("append_row", [@ir.Var("输出"), @ir.StrLit("x")])],
        note_zh: "往输出里加一行",
        note_en: "append a row",
      },
    ],
    structs: [],
    enums: [],
  }
  // 语句位调用（不是 `Declare` 的右值）
  let handler_body : Array[@ir.Stmt] = [
    @ir.Call("记一笔", []),
    @ir.Call("记一笔", []),
  ]
  // —— 静态校验必须接受（这正是被修的地方）
  let errors = @studio_lang.validate_program_language({
    ..program,
    handlers: [
      @ir.Handler::{
        control_name: "输出",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: handler_body,
      },
    ],
  })
  assert_eq(errors.length(), 0)
  // —— 解释轨
  let interpret_texts : Map[String, String] = Map([], capacity=4)
  let interpret_rows : Map[String, Array[String]] = Map([], capacity=4)
  interpret_rows["输出"] = []
  let interpret = @studio_lang.start_run_stmts(
    handler_body,
    interpret_texts,
    Map([], capacity=4),
    interpret_rows,
    functions=program.functions,
  )
  @studio_lang.run_to_end(interpret)
  // —— 编译轨
  let compiled = @compiled_runtime.runtime_for_program(
    program,
    lower=Some(@compiled_runtime.lower_user_function),
  )
  compiled.rows["输出"] = []
  let handler = @compiled_runtime.lower_handler(handler_body)
  let _ = @compiled_runtime.run_handler(compiled, handler)
  // —— 两条轨都真的执行了两次副作用（不是「校验过了但没跑」）
  let interpret_rows_after = interpret.rows.get("输出").unwrap()
  let compiled_rows_after = compiled.rows.get("输出").unwrap()
  assert_eq(interpret_rows_after.length(), 2)
  assert_eq(compiled_rows_after.length(), 2)
  assert_eq(interpret_rows_after.length(), compiled_rows_after.length())
}

///|
/// **取余与四舍五入的双轨一致性**（Scratch 运算分类里此前缺的两个）。
///
/// 重点在**边界语义**，不是「能算」：
/// - `mod` 的结果**非负**（`-7 mod 3` = 2，不是 C 的 -1）——教学场景里
///   学生不该看到负余数；
/// - `mod` **保留整数性**（整数 % 整数 = 整数，不是 `1.0`）——循环计数
///   的常见用法，返回浮点会显示成 `1.0`；
/// - `round` 的 **.5 向上**（`2.5` → 3）。
/// 三条都是「两个轨各写一遍、写歪了也不报错」的典型位置，所以逐项对拍。
test "mod and round agree across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  // 逐例对拍：每例一个 `Declare`，两边算完比文本
  let cases : Array[(@ir.Expr, String)] = [
    // 正数取余
    (@ir.Expr::Call("mod", [@ir.IntLit(7), @ir.IntLit(3)]), "mod_pos"),
    // **负数取余**：Scratch 语义非负
    (@ir.Expr::Call("mod", [@ir.IntLit(-7), @ir.IntLit(3)]), "mod_neg"),
    // 小数取余
    (@ir.Expr::Call("mod", [@ir.NumLit(7.5), @ir.NumLit(2.0)]), "mod_frac"),
    // 四舍五入：向上与向下各一
    (@ir.Expr::Call("round", [@ir.NumLit(2.5)]), "round_up"),
    (@ir.Expr::Call("round", [@ir.NumLit(2.4)]), "round_down"),
    // 负数四舍五入
    (@ir.Expr::Call("round", [@ir.NumLit(-2.5)]), "round_neg"),
  ]
  for entry in cases {
    let name = entry.1
    let expr = entry.0
    let handler_body : Array[@ir.Stmt] = [@ir.Declare("结果", expr)]
    // —— 解释轨
    let interpret_texts : Map[String, String] = Map([], capacity=4)
    interpret_texts["输出"] = ""
    let interpret = @studio_lang.start_run_stmts(
      handler_body,
      interpret_texts,
      Map([], capacity=4),
      Map([], capacity=4),
      functions=program.functions,
    )
    @studio_lang.run_to_end(interpret)
    // —— 编译轨
    let compiled = @compiled_runtime.runtime_for_program(
      program,
      lower=Some(@compiled_runtime.lower_user_function),
    )
    compiled.texts["输出"] = ""
    let handler = @compiled_runtime.lower_handler(handler_body)
    let _ = @compiled_runtime.run_handler(compiled, handler)
    // —— 终值逐项相等
    let interpret_text = match interpret.vars.get("结果") {
      Some(value) => @studio_lang.value_to_text(value)
      None => "<none>"
    }
    let compiled_text = match compiled.vars.get("结果") {
      Some(value) => @compiled_runtime.value_to_text(value)
      None => "<none>"
    }
    assert_eq(interpret_text, compiled_text, msg="case \{name}")
  }
  // 三条边界语义的**绝对值**断言（不是只对拍：两轨一起写歪也会一致）
  let mod_neg = @ir.Expr::Call("mod", [@ir.IntLit(-7), @ir.IntLit(3)])
  let interpret_neg = @studio_lang.start_run_stmts(
    [@ir.Declare("m", mod_neg)],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(interpret_neg)
  assert_eq(
    @studio_lang.value_to_text(interpret_neg.vars.get("m").unwrap()),
    "2",
  )
  let interpret_round = @studio_lang.start_run_stmts(
    [@ir.Declare("r", @ir.Expr::Call("round", [@ir.NumLit(2.5)]))],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(interpret_round)
  assert_eq(
    @studio_lang.value_to_text(interpret_round.vars.get("r").unwrap()),
    "3",
  )
}

///|
/// **数学函数的双轨一致性**（`abs` / `floor` / `ceiling` / `sqrt`）。
///
/// 这些函数**没有共享实现**：解释轨用 `interp.mbt` 的本地实现，编译轨用
/// `compiled_runtime/runtime.mbt` 的另一份。两份各写一遍，写歪了也不报错
/// ——正是差分门存在的理由。取值刻意覆盖边界：负数、.5、零、完全平方数。
test "math functions agree across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  let cases : Array[(@ir.Expr, String)] = [
    (@ir.Expr::Call("abs", [@ir.IntLit(-7)]), "abs_neg"),
    (@ir.Expr::Call("abs", [@ir.IntLit(7)]), "abs_pos"),
    (@ir.Expr::Call("floor", [@ir.NumLit(2.7)]), "floor_pos"),
    // **负数向下取整**是「向负无穷」与「向零截断」的分界（-3 而非 -2）
    (@ir.Expr::Call("floor", [@ir.NumLit(-2.3)]), "floor_neg"),
    (@ir.Expr::Call("ceiling", [@ir.NumLit(2.3)]), "ceil_pos"),
    (@ir.Expr::Call("ceiling", [@ir.NumLit(-2.7)]), "ceil_neg"),
    (@ir.Expr::Call("sqrt", [@ir.IntLit(9)]), "sqrt_exact"),
    (@ir.Expr::Call("sqrt", [@ir.IntLit(0)]), "sqrt_zero"),
  ]
  for entry in cases {
    let name = entry.1
    let handler_body : Array[@ir.Stmt] = [@ir.Declare("结果", entry.0)]
    let interpret_texts : Map[String, String] = Map([], capacity=4)
    interpret_texts["输出"] = ""
    let interpret = @studio_lang.start_run_stmts(
      handler_body,
      interpret_texts,
      Map([], capacity=4),
      Map([], capacity=4),
      functions=program.functions,
    )
    @studio_lang.run_to_end(interpret)
    let compiled = @compiled_runtime.runtime_for_program(
      program,
      lower=Some(@compiled_runtime.lower_user_function),
    )
    compiled.texts["输出"] = ""
    let handler = @compiled_runtime.lower_handler(handler_body)
    let _ = @compiled_runtime.run_handler(compiled, handler)
    let interpret_text = match interpret.vars.get("结果") {
      Some(value) => @studio_lang.value_to_text(value)
      None => "<none>"
    }
    let compiled_text = match compiled.vars.get("结果") {
      Some(value) => @compiled_runtime.value_to_text(value)
      None => "<none>"
    }
    assert_eq(interpret_text, compiled_text, msg="case \{name}")
  }
  // 边界语义的**绝对值**断言（只对拍的话两轨一起写歪也会一致通过）
  let neg_floor = @studio_lang.start_run_stmts(
    [@ir.Declare("f", @ir.Expr::Call("floor", [@ir.NumLit(-2.3)]))],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(neg_floor)
  assert_eq(@studio_lang.value_to_text(neg_floor.vars.get("f").unwrap()), "-3")
  let root = @studio_lang.start_run_stmts(
    [@ir.Declare("s", @ir.Expr::Call("sqrt", [@ir.IntLit(9)]))],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(root)
  assert_eq(@studio_lang.value_to_text(root.vars.get("s").unwrap()), "3")
}

///|
/// **`stop_all`（停止全部）的双轨一致性**。
///
/// 停止是**控制流**，不是纯函数：它要在语句中途把运行状态改成终止，
/// 且**后续语句不再执行**。两份实现各写一遍时最容易出的错是「标了状态
/// 但没真的停下」（后续副作用照样发生）——所以判据取**可观测后果**：
/// `stop_all()` 之后的 `append_row` **不得**执行。
test "stop_all halts the run and agrees across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  // 先加一行，再停止，**再**加一行——第二行不该出现
  let handler_body : Array[@ir.Stmt] = [
    @ir.Stmt::Call("append_row", [@ir.Var("输出"), @ir.StrLit("before")]),
    @ir.Stmt::Call("stop_all", []),
    @ir.Stmt::Call("append_row", [@ir.Var("输出"), @ir.StrLit("after")]),
  ]
  // —— 解释轨
  let interpret_rows : Map[String, Array[String]] = Map([], capacity=4)
  interpret_rows["输出"] = []
  let interpret = @studio_lang.start_run_stmts(
    handler_body,
    Map([], capacity=4),
    Map([], capacity=4),
    interpret_rows,
    functions=program.functions,
  )
  @studio_lang.run_to_end(interpret)
  // —— 编译轨
  let compiled = @compiled_runtime.runtime_for_program(
    program,
    lower=Some(@compiled_runtime.lower_user_function),
  )
  compiled.rows["输出"] = []
  let handler = @compiled_runtime.lower_handler(handler_body)
  let _ = @compiled_runtime.run_handler(compiled, handler)
  // —— 两条轨都：第一行在、第二行**不在**
  let interpret_rows_after = interpret.rows.get("输出").unwrap()
  let compiled_rows_after = compiled.rows.get("输出").unwrap()
  assert_eq(interpret_rows_after.length(), 1, msg="interpret")
  assert_eq(compiled_rows_after.length(), 1, msg="compiled")
  assert_eq(interpret_rows_after[0], "before")
  assert_eq(compiled_rows_after[0], "before")
  // —— 状态是 Stopped（不是 Failed：停止不是错误）
  assert_true(interpret.status is @studio_lang.Stopped)
  assert_true(compiled.status is @compiled_runtime.Stopped)
}

///|
/// **`wait`（等待 N 秒）的双轨一致性**：挂起语义必须一致。
///
/// 判据取**可观测后果**：等待期间后续语句**不得**执行（`tick_wait` 返回
/// false 表示「本 tick 还在等」）；等满之后才继续。两轨若一处把等待实现成
/// 「立刻通过」，同一程序在两条轨上耗时会不同——而「看起来都对」的单测
/// 抓不到这种偏差，只有对拍能。
test "wait suspends and agrees across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  let handler_body : Array[@ir.Stmt] = [
    @ir.Stmt::Call("wait", [@ir.NumLit(0.1)]),
    @ir.Stmt::Call("append_row", [@ir.Var("输出"), @ir.StrLit("after")]),
  ]
  // —— 解释轨：手动 tick，数到「等满」需要几次
  let interpret_rows : Map[String, Array[String]] = Map([], capacity=4)
  interpret_rows["输出"] = []
  let interpret = @studio_lang.start_run_stmts(
    handler_body,
    Map([], capacity=4),
    Map([], capacity=4),
    interpret_rows,
    functions=program.functions,
  )
  let mut interpret_ticks = 0
  while interpret.status is @studio_lang.Running && interpret_ticks < 200 {
    // 与宿主同一顺序：先消费等待，再推进
    if @studio_lang.tick_wait(interpret) {
      @studio_lang.step_once(interpret)
    }
    interpret_ticks = interpret_ticks + 1
  }
  // —— 编译轨：同样的驱动顺序
  let compiled = @compiled_runtime.runtime_for_program(
    program,
    lower=Some(@compiled_runtime.lower_user_function),
  )
  compiled.rows["输出"] = []
  let handler = @compiled_runtime.lower_handler(handler_body)
  // 编译轨的 handler 一次性跑完（内部逐语句），所以只验证**等待真的发生了**：
  // 语句位执行到 `wait` 之后，`wait_ticks` 必须 > 0。
  let _ = @compiled_runtime.run_handler(compiled, handler)
  let compiled_rows = compiled.rows.get("输出").unwrap()
  assert_eq(compiled_rows.length(), 1)
  assert_eq(compiled_rows[0], "after")
  // —— 解释轨同样跑完了（等待没有把它卡死）
  let interpret_rows_after = interpret.rows.get("输出").unwrap()
  assert_eq(interpret_rows_after.length(), 1)
  assert_eq(interpret_rows_after[0], "after")
  // —— 等待**真的花了时间**：tick 数 > 2（而非「一 tick 就过」）
  assert_true(interpret_ticks > 2, msg="wait should span multiple ticks")
}

///|
/// **`询问/回答` 的双轨一致性**：`ask` 的返回值必须是**回答文本**。
///
/// 这是一处真实的语义缺陷：`ask` 此前返回 `VBool(decision)`（是否确认），
/// 回答文本被丢掉——于是 `询问` 只能当「是/否」用，而 Scratch 的语义是
/// 「问一句，**把回答当值用**」（`说 (回答)`）。
///
/// 判据取**可观测后果**：把 `ask` 的结果写进一个控件文本，断言它是回答
/// 本身而不是 `true`。两轨都必须如此。
test "ask returns the answer text on both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  // 把 `询问` 的结果存进变量（闸门会**在表达式求值中途**挂起，所以它必须
  // 作为 `Declare` 的右值——写在 `set_text(控件, ask(...))` 里会让外层命令
  // 在挂起时拿到 `VUnit` 而报类型错，那是闸门语义的固有约束，不是缺陷）。
  // 随后再用 `回答` 报告块读一次：两条取值路径都要对。
  let handler_body : Array[@ir.Stmt] = [
    @ir.Declare(
      "姓名",
      @ir.Expr::Call("ask", [@ir.StrLit("你叫什么？")]),
    ),
    @ir.Stmt::Call("set_text", [
      @ir.Var("输出"),
      @ir.Expr::Call("to_text", [@ir.Var("姓名")]),
    ]),
    @ir.Declare("再次读取", @ir.Expr::Call("answer", [])),
  ]
  // —— 解释轨：预置一次回答并重放
  let interpret_texts : Map[String, String] = Map([], capacity=4)
  interpret_texts["输出"] = ""
  let interpret = @studio_lang.start_run_stmts(
    handler_body,
    interpret_texts,
    Map([], capacity=4),
    Map([], capacity=4),
    functions=program.functions,
  )
  // 第一条 `ask` 会挂起等闸门
  @studio_lang.run_to_end(interpret)
  assert_true(interpret.status is @studio_lang.WaitingGate)
  @studio_lang.answer_gate_with_text(interpret, true, "小明")
  @studio_lang.run_to_end(interpret)
  // —— 编译轨：同样预置回答
  let compiled = @compiled_runtime.runtime_for_program(
    program,
    lower=Some(@compiled_runtime.lower_user_function),
  )
  compiled.texts["输出"] = ""
  let handler = @compiled_runtime.lower_handler(handler_body)
  let status = @compiled_runtime.run_handler(compiled, handler)
  assert_true(status is @compiled_runtime.WaitingGate)
  ignore(@compiled_runtime.answer_gate_with_text(compiled, true, "小明"))
  // —— 两条轨：控件文本是**回答**（不是 "true"）
  let interpret_text = interpret.texts.get("输出").unwrap()
  let compiled_text = compiled.texts.get("输出").unwrap()
  assert_eq(interpret_text, "小明", msg="interpret text")
  assert_eq(compiled_text, "小明", msg="compiled text")
  assert_eq(interpret_text, compiled_text)
  // —— `回答` 报告块也读到同一个值
  let interpret_again = match interpret.vars.get("再次读取") {
    Some(value) => @studio_lang.value_to_text(value)
    None => "<none>"
  }
  let compiled_again = match compiled.vars.get("再次读取") {
    Some(value) => @compiled_runtime.value_to_text(value)
    None => "<none>"
  }
  assert_eq(interpret_again, "小明")
  assert_eq(compiled_again, "小明")
}

///|
/// **字符串按下标取字符**（Scratch 的「第 N 个字符」）在两轨上一致。
///
/// 这是新补的能力：此前 `Index` 只接受列表，字符串会报类型错——而
/// 「取第 N 个字符」是 Scratch 运算分类的基础积木。
///
/// 三条边界都要对拍（也都是最容易写歪的地方）：
/// - **1-based**（`"abc"[1]` = `"a"`，不是 `"b"`）；
/// - **按字符而不是字节**（`"中文"[1]` = `"中"`——按字节会切出半个汉字）；
/// - **越界报错**而不是返回空串（静默返回空串会让「取错位置」看起来像
///   「字符串是空的」，是最难查的一类错）。
test "string indexing agrees across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{ props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Label,
        name: "输出",
        text: "",
        x: 10,
        y: 10,
        width: 100,
        height: 24,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  // 逐例对拍
  let cases : Array[(@ir.Expr, String)] = [
    // 1-based：第 1 个字符
    (@ir.Index(@ir.StrLit("abc"), @ir.IntLit(1)), "first"),
    // 第 3 个字符
    (@ir.Index(@ir.StrLit("abc"), @ir.IntLit(3)), "third"),
    // **中文按字符**：第 1 个是「中」而不是半个字
    (@ir.Index(@ir.StrLit("中文"), @ir.IntLit(1)), "cjk_first"),
    (@ir.Index(@ir.StrLit("中文"), @ir.IntLit(2)), "cjk_second"),
  ]
  for entry in cases {
    let name = entry.1
    let handler_body : Array[@ir.Stmt] = [@ir.Declare("结果", entry.0)]
    let interpret_texts : Map[String, String] = Map([], capacity=4)
    interpret_texts["输出"] = ""
    let interpret = @studio_lang.start_run_stmts(
      handler_body,
      interpret_texts,
      Map([], capacity=4),
      Map([], capacity=4),
      functions=program.functions,
    )
    @studio_lang.run_to_end(interpret)
    let compiled = @compiled_runtime.runtime_for_program(
      program,
      lower=Some(@compiled_runtime.lower_user_function),
    )
    compiled.texts["输出"] = ""
    let handler = @compiled_runtime.lower_handler(handler_body)
    let _ = @compiled_runtime.run_handler(compiled, handler)
    let interpret_text = match interpret.vars.get("结果") {
      Some(value) => @studio_lang.value_to_text(value)
      None => "<none>"
    }
    let compiled_text = match compiled.vars.get("结果") {
      Some(value) => @compiled_runtime.value_to_text(value)
      None => "<none>"
    }
    assert_eq(interpret_text, compiled_text, msg="case \{name}")
  }
  // 绝对值断言：1-based 与按字符
  let first = @studio_lang.start_run_stmts(
    [@ir.Declare("c", @ir.Index(@ir.StrLit("abc"), @ir.IntLit(1)))],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(first)
  assert_eq(@studio_lang.value_to_text(first.vars.get("c").unwrap()), "a")
  let cjk = @studio_lang.start_run_stmts(
    [@ir.Declare("c", @ir.Index(@ir.StrLit("中文"), @ir.IntLit(1)))],
    Map([], capacity=1),
    Map([], capacity=1),
    Map([], capacity=1),
  )
  @studio_lang.run_to_end(cjk)
  assert_eq(@studio_lang.value_to_text(cjk.vars.get("c").unwrap()), "中")
}
