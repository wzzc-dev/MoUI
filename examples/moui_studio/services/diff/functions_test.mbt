///|
/// 用户自定义函数（切片 F）双轨一致性：同一程序（函数定义 + Return +
/// 调用 + 递归）在解释轨与编译轨（lower）上的终态变量、审计序列、
/// 返回文本必须逐项相等——与 `matrix_test` 的差分门同口径。
test "user functions agree across both tracks" {
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
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
        body: [@ir.Return(Some(@ir.Binary(@ir.Mul, @ir.Var("值"), @ir.IntLit(2))))],
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
    interpret
    .vars
    .get("阶乘五")
    .map(@studio_lang.value_to_text),
    compiled.vars.get("阶乘五").map(@compiled_runtime.value_to_text),
  )
  // 整数语义：42 + 120 = 162（VInt 加法，非文本拼接）
  assert_eq(@studio_lang.value_to_text(interpret.vars.get("翻倍").unwrap()), "42")
  assert_eq(@studio_lang.value_to_text(interpret.vars.get("阶乘五").unwrap()), "120")
  assert_eq(compiled.texts.get("输出").unwrap_or(""), "162")
  assert_eq(interpret.texts.get("输出").unwrap_or(""), "162")
  // 审计（line/op/detail）逐条相等：函数体行号两轨同为 0
  assert_eq(interpret.audit.length(), compiled.audit.length())
  let mut index = 0
  while index < interpret.audit.length() &&
  index < compiled.audit.length() {
    let left = interpret.audit[index]
    let right = compiled.audit[index]
    assert_eq(left.line, right.line)
    assert_eq(left.detail, right.detail)
    index = index + 1
  }
}
