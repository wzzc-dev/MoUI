///|
/// 编译轨预览测试：预览源码 = 导出 bundle 实际参与编译的唯一源码。
/// 覆盖：字节稳定、可编译形状（直接调 compiled_runtime，无解释器）、
/// 双语 note 与语句映射、空程序。

///|
fn preview_fixture() -> @ir.StudioProgram {
  {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Button,
        name: "确定",
        text: "算",
        x: 40,
        y: 100,
        width: 100,
        height: 32,
        items: [],
      },
    ],
    variables: [@ir.Variable::{ name: "总分", init: "0", }],
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "点击后统计得分",
        note_en: "tally the score on click",
        body: [
          @ir.Declare("总分", @ir.IntLit(0)),
          @ir.CountLoop(@ir.IntLit(3), Some("i"), [
            @ir.Assign(
              "总分",
              @ir.Binary(@ir.Add, @ir.Var("总分"), @ir.Var("i")),
            ),
          ]),
          @ir.WhileLoop(@ir.Var("没答完"), [@ir.Break]),
          @ir.If(
            @ir.Binary(@ir.Gt, @ir.Var("总分"), @ir.IntLit(60)),
            [@ir.Call("set_text", [@ir.StrLit("显示"), @ir.StrLit("你好")])],
            [],
            [@ir.Assign("总分", @ir.NumLit(60.5))],
          ),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
}

///|
test "moonbit preview is byte-stable and compiles through compiled_runtime" {
  let program = preview_fixture()
  let once = @export.moonbit_preview(program)
  // 逐字节确定
  assert_eq(@export.moonbit_preview(program), once)
  // 头部契约：明确这是真正参与编译的产物
  assert_true(once.contains("本文件由 MoUI Studio"))
  assert_true(once.contains("真正参与编译"))
  assert_false(once.contains("不是可编译产物"))
  // 编译轨执行面：直接调用 compiled_runtime，不含解释器入口
  assert_true(once.contains("@compiled_runtime.Runtime"))
  assert_true(once.contains("rt.audit_assign("))
  assert_true(once.contains("rt.count_loop("))
  assert_true(once.contains("rt.while_loop("))
  assert_true(once.contains("rt.break_loop()"))
  assert_true(once.contains("rt.set_text("))
  assert_false(once.contains("start_run_stmts"))
  assert_false(once.contains("run_to_end"))
  // 程序与控件信息在头注释里
  assert_true(once.contains("MoUI Studio 程序"))
}

///|
test "preview and bundle generated source are the same function output" {
  let program = preview_fixture()
  let preview = @export.moonbit_preview(program)
  let generated = @export.generate_source(program)
  assert_eq(preview, generated.source)
  assert_eq(generated.handlers.length(), 1)
  assert_eq(generated.handlers[0].control_name, "确定")
  assert_eq(generated.handlers[0].event_tag, "on_click")
}

///|
test "empty program still generates a stable, valid file" {
  let empty = @ir.empty_program()
  let once = @export.moonbit_preview(empty)
  assert_eq(@export.moonbit_preview(empty), once)
  assert_true(once.contains("（本程序还没有事件子程序）"))
  assert_eq(@export.generate_source(empty).handlers.length(), 0)
}
