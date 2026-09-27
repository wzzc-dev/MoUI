///|
/// codec 测试：往返保真、版本门、错误分类、encode 稳定。

///|
fn sample_program() -> @ir.MomaoProgram {
  {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "确定",
        text: "好",
        x: 10,
        y: 10,
        width: 80,
        height: 28,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.TextField,
        name: "姓名框",
        text: "",
        x: 10,
        y: 50,
        width: 160,
        height: 28,
        items: [],
      },
      @ir.Control::{
        id: 3,
        kind: @ir.ListBox,
        name: "名单",
        text: "",
        x: 200,
        y: 10,
        width: 120,
        height: 90,
        items: ["张三", "李四"],
      },
    ],
    variables: [
      @ir.Variable::{ name: "次数", init: "0" },
      @ir.Variable::{ name: "问候", init: "" },
    ],
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "点击后打招呼",
        note_en: "greet on click",
        body: [
          @ir.Declare(
            "文本",
            @ir.Call("get_text", [@ir.Var("姓名框")]),
          ),
          @ir.If(
            @ir.Binary(@ir.Eq, @ir.Var("文本"), @ir.StrLit("")),
            [@ir.Call("message_box", [@ir.StrLit("先填写姓名")])],
            [(@ir.BoolLit(false), [@ir.Call("message_box", [@ir.Var("文本")])])],
            [@ir.Call("message_box", [@ir.StrLit("你好，")])],
          ),
          @ir.CountLoop(
            @ir.NumLit(3.0),
            Some("i"),
            [
              @ir.Assign(
                "次数",
                @ir.Binary(@ir.Add, @ir.Var("次数"), @ir.NumLit(1.0)),
              ),
            ],
          ),
        ],
      },
    ],
  }
}

test "encode decode round trip preserves signature" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  let before = @ir.program_signature(program)
  match @codec.decode_program(text) {
    Ok(decoded) => assert_eq(@ir.program_signature(decoded), before)
    Err(errors) => fail("往返失败: \{errors.length()} 个错误")
  }
}

test "encode output is stable" {
  let program = sample_program()
  assert_eq(@codec.encode_program(program), @codec.encode_program(program))
  let text = @codec.encode_program(program)
  assert_true(text.contains("\"format\":\"momao.project\""))
  assert_true(text.contains("\"version\":1"))
  assert_true(text.contains("\"op\":\"declare\""))
  assert_true(text.contains("\"kind\":\"list_box\""))
}

test "decode rejects wrong format and version" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  let bad_format = text.replace(old="momao.project", new="other.format")
  match @codec.decode_program(bad_format) {
    Err(errors) => assert_true(errors.any(e => e is @codec.BadFormat))
    Ok(_) => fail("错误 format 应拒绝")
  }
  let bad_version = text.replace(old="\"version\":1", new="\"version\":2")
  match @codec.decode_program(bad_version) {
    Err(errors) => assert_true(errors.any(e => e is @codec.UnsupportedVersion(2)))
    Ok(_) => fail("错误 version 应拒绝")
  }
  match @codec.decode_program("不是 json") {
    Err(errors) => assert_true(errors.any(e => e is @codec.InvalidJson))
    Ok(_) => fail("坏 json 应拒绝")
  }
}

test "decode reports structural and language errors" {
  // 结构错误：handler 指向不存在的控件
  let program = sample_program()
  let broken : @ir.MomaoProgram = {
    ..program,
    handlers: [
      @ir.Handler::{
        control_name: "不存在",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [],
      },
    ],
  }
  match @codec.decode_program(@codec.encode_program(broken)) {
    Err(errors) =>
      assert_true(
        errors.any(e => e is @codec.Structural(@ir.UnknownControlInHandler(_))),
      )
    Ok(_) => fail("未知控件应拒绝")
  }
  // 语言层错误：break 在循环外
  let stray_break : @ir.MomaoProgram = {
    ..program,
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [@ir.Break],
      },
    ],
  }
  match @codec.decode_program(@codec.encode_program(stray_break)) {
    Err(errors) => assert_true(errors.any(e => e is @codec.LanguageIssue(_, _)))
    Ok(_) => fail("循环外 break 应拒绝")
  }
}

test "decode fills control defaults" {
  let minimal = "{\"format\":\"momao.project\",\"version\":1,\"controls\":[{\"id\":1,\"kind\":\"label\",\"name\":\"标题\"}],\"handlers\":[]}"
  match @codec.decode_program(minimal) {
    Ok(program) => {
      let control = program.controls[0]
      assert_eq(control.x, 40)
      assert_eq(control.height, 36)
      assert_eq(program.window.title, "MoMao 程序")
    }
    Err(errors) => fail("最小合法项目应可解码: \{errors.length()} 个错误")
  }
}
