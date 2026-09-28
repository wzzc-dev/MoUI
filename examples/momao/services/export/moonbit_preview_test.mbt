///|
/// MoonBit 预览生成器测试：字节稳定、内容映射、可读性契约体现。

///|
fn preview_fixture() -> @ir.MomaoProgram {
  {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
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
          @ir.Declare("总分", @ir.NumLit(0.0)),
          @ir.CountLoop(@ir.NumLit(3.0), Some("i"), [
            @ir.Assign(
              "总分",
              @ir.Binary(@ir.Add, @ir.Var("总分"), @ir.Var("i")),
            ),
          ]),
          @ir.WhileLoop(@ir.Var("没答完"), [@ir.Break]),
          @ir.If(
            @ir.Binary(@ir.Gt, @ir.Var("总分"), @ir.NumLit(60.0)),
            [@ir.Call("set_text", [@ir.StrLit("显示"), @ir.StrLit("你好")])],
            [],
            [@ir.Assign("总分", @ir.NumLit(60.5))],
          ),
        ],
      },
    ],
  }
}

///|
test "moonbit preview is byte-stable and maps the program" {
  let program = preview_fixture()
  let once = @export.moonbit_preview(program)
  // 逐字节确定
  assert_eq(@export.moonbit_preview(program), once)
  // 头部契约
  assert_true(once.contains("由 MoMao（墨卯）自动生成"))
  assert_true(once.contains("不是可编译产物"))
  // 控件与变量清单
  assert_true(
    once.contains(
      "///   [1] button「确定」 @ (40, 100) 100x32 文本=\"算\"",
    ),
  )
  assert_true(once.contains("///   总分 = \"0\""))
  // 子程序头 + 双语意图说明
  assert_true(
    once.contains("/// ── 事件子程序：确定 . on_click ──"),
  )
  assert_true(once.contains("/// 意图：点击后统计得分"))
  assert_true(once.contains("/// 意图（EN）：tally the score on click"))
  assert_true(once.contains("fn handler_1_1_on_click() {"))
  // 语句映射
  assert_true(once.contains("let 总分 = 0"))
  assert_true(once.contains("for i in 0..<3 {"))
  assert_true(once.contains("while 没答完 {"))
  assert_true(once.contains("break"))
  assert_true(once.contains("if (总分 > 60) {"))
  assert_true(once.contains("set_text(\"显示\", \"你好\")"))
  assert_true(once.contains("总分 = 60.5"))
  assert_true(once.contains("} else {"))
}

///|
test "empty program and missing notes still render stably" {
  let empty = @ir.empty_program()
  let once = @export.moonbit_preview(empty)
  assert_eq(@export.moonbit_preview(empty), once)
  assert_true(once.contains("（无控件）"))
  assert_true(once.contains("（无变量）"))
  assert_true(once.contains("（本程序还没有事件子程序）"))
  // 无 note 的子程序有占位提示（可读性契约对 AI 提案必填）
  let bare : @ir.MomaoProgram = {
    ..preview_fixture(),
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [],
      },
    ],
  }
  let bare_preview = @export.moonbit_preview(bare)
  assert_true(bare_preview.contains("（未填写"))
  assert_true(bare_preview.contains("（空子程序"))
}
