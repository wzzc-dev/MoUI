///|
/// codec 测试：往返保真、版本门、错误分类、encode 稳定。

///|
fn sample_program() -> @ir.StudioProgram {
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
      @ir.Variable::{ name: "次数", init: "0", },
      @ir.Variable::{ name: "问候", init: "", },
    ],
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "点击后打招呼",
        note_en: "greet on click",
        body: [
          @ir.Declare("文本", @ir.Call("get_text", [@ir.Var("姓名框")])),
          @ir.If(
            @ir.Binary(@ir.Eq, @ir.Var("文本"), @ir.StrLit("")),
            [@ir.Call("message_box", [@ir.StrLit("先填写姓名")])],
            [
              (
                @ir.BoolLit(false),
                [@ir.Call("message_box", [@ir.Var("文本")])],
              ),
            ],
            [@ir.Call("message_box", [@ir.StrLit("你好，")])],
          ),
          @ir.CountLoop(@ir.IntLit(3), Some("i"), [
            @ir.Assign(
              "次数",
              @ir.Binary(@ir.Add, @ir.Var("次数"), @ir.IntLit(1)),
            ),
          ]),
        ],
      },
    ],
    functions: [],
    structs: [
      @ir.StructDecl::{
        name: "Person",
        fields: [
          @ir.StructField::{ field_name: "名字", field_type: "text" },
          @ir.StructField::{ field_name: "年龄", field_type: "number" },
        ],
      },
    ],
    enums: [@ir.EnumDecl::{ name: "花色", cases: ["红桃", "黑桃"] }],
  }
}

///|
test "encode decode round trip preserves signature" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  let before = @ir.program_signature(program)
  match @codec.decode_program(text) {
    Ok(decoded) => assert_eq(@ir.program_signature(decoded), before)
    Err(errors) => fail("往返失败: \{errors.length()} 个错误")
  }
}

///|
test "encode output is stable" {
  let program = sample_program()
  assert_eq(@codec.encode_program(program), @codec.encode_program(program))
  let text = @codec.encode_program(program)
  assert_true(text.contains("\"format\":\"moui.studio.project\""))
  assert_true(text.contains("\"version\":1"))
  assert_true(text.contains("\"op\":\"declare\""))
  assert_true(text.contains("\"kind\":\"list_box\""))
}

///|
test "decode rejects wrong format and version" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  let bad_format = text.replace(old="moui.studio.project", new="other.format")
  match @codec.decode_program(bad_format) {
    Err(errors) => assert_true(errors.any(e => e is @codec.BadFormat))
    Ok(_) => fail("错误 format 应拒绝")
  }
  let bad_version = text.replace(old="\"version\":1", new="\"version\":2")
  match @codec.decode_program(bad_version) {
    Err(errors) =>
      assert_true(errors.any(e => e is @codec.UnsupportedVersion(2)))
    Ok(_) => fail("错误 version 应拒绝")
  }
  match @codec.decode_program("不是 json") {
    Err(errors) => assert_true(errors.any(e => e is @codec.InvalidJson))
    Ok(_) => fail("坏 json 应拒绝")
  }
}

///|
test "decode reports structural and language errors" {
  // 结构错误：handler 指向不存在的控件
  let program = sample_program()
  let broken : @ir.StudioProgram = {
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
    functions: [],
  }
  match @codec.decode_program(@codec.encode_program(broken)) {
    Err(errors) =>
      assert_true(
        errors.any(e => e is @codec.Structural(@ir.UnknownControlInHandler(_))),
      )
    Ok(_) => fail("未知控件应拒绝")
  }
  // 语言层错误：break 在循环外
  let stray_break : @ir.StudioProgram = {
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
    functions: [],
  }
  match @codec.decode_program(@codec.encode_program(stray_break)) {
    Err(errors) => assert_true(errors.any(e => e is @codec.LanguageIssue(_, _)))
    Ok(_) => fail("循环外 break 应拒绝")
  }
}

///|
test "decode fills control defaults" {
  let minimal = "{\"format\":\"moui.studio.project\",\"version\":1,\"controls\":[{\"id\":1,\"kind\":\"label\",\"name\":\"标题\"}],\"handlers\":[]}"
  match @codec.decode_program(minimal) {
    Ok(program) => {
      let control = program.controls[0]
      assert_eq(control.x, 40)
      assert_eq(control.height, 36)
      assert_eq(program.window.title, "MoUI Studio 程序")
    }
    Err(errors) =>
      fail("最小合法项目应可解码: \{errors.length()} 个错误")
  }
}

///|
test "structs encode decode round trip" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  assert_true(text.contains("\"structs\""))
  match @codec.decode_program(text) {
    Ok(decoded) => {
      assert_eq(decoded.structs.length(), 1)
      assert_eq(decoded.structs[0].name, "Person")
      assert_eq(decoded.structs[0].fields.length(), 2)
      assert_eq(decoded.structs[0].fields[0].field_name, "名字")
      assert_eq(decoded.structs[0].fields[0].field_type, "text")
      assert_eq(decoded.structs[0].fields[1].field_name, "年龄")
      assert_eq(decoded.structs[0].fields[1].field_type, "number")
    }
    Err(errors) => fail("structs 往返失败: \{errors.length()} 个错误")
  }
}

///|
test "structs segment is optional for old files" {
  let program = sample_program()
  let bare : @ir.StudioProgram = { ..program, structs: [] }
  let text = @codec.encode_program(bare)
  // 空 structs 不落盘（与 functions 同一口径），旧文件无此字段照常解码
  assert_false(text.contains("\"structs\""))
  match @codec.decode_program(text) {
    Ok(decoded) => assert_eq(decoded.structs.length(), 0)
    Err(errors) => fail("无 structs 段解码失败: \{errors.length()}")
  }
}

///|
test "structs with unknown type word surface as language errors" {
  let program = sample_program()
  let broken : @ir.StudioProgram = {
    ..program,
    structs: [
      @ir.StructDecl::{
        name: "Weird",
        fields: [@ir.StructField::{ field_name: "x", field_type: "布尔" }],
      },
    ],
  }
  match @codec.decode_program(@codec.encode_program(broken)) {
    Err(errors) =>
      assert_true(
        errors.any(e => e is @codec.LanguageIssue("字段类型", 0)),
      )
    Ok(_) => fail("未知字段类型应被语言级校验拦截")
  }
}

///|
test "enums and match statements encode decode round trip" {
  let program = sample_program()
  let text = @codec.encode_program(program)
  assert_true(text.contains("\"enums\""))
  match @codec.decode_program(text) {
    Ok(decoded) => {
      assert_eq(decoded.enums.length(), 1)
      assert_eq(decoded.enums[0].name, "花色")
      assert_eq(decoded.enums[0].cases[1], "黑桃")
    }
    Err(errors) => fail("enums 往返失败: \{errors.length()} 个错误")
  }
  // Match 语句与 EnumTag 表达式经 handler 体往返
  let with_match : @ir.StudioProgram = {
    ..program,
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [
          @ir.Match(
            @ir.EnumTag("花色", "红桃"),
            [
              @ir.MatchArm::{
                case_name: "红桃",
                body: [@ir.Assign("次数", @ir.IntLit(1))],
              },
            ],
            [],
          ),
        ],
      },
    ],
  }
  let match_text = @codec.encode_program(with_match)
  assert_true(match_text.contains("\"op\":\"match\""))
  assert_true(match_text.contains("\"t\":\"enum_tag\""))
  match @codec.decode_program(match_text) {
    Ok(decoded) =>
      match decoded.handlers[0].body[0] {
        @ir.Match(@ir.EnumTag(e, c), arms, _) => {
          assert_eq(e, "花色")
          assert_eq(c, "红桃")
          assert_eq(arms[0].case_name, "红桃")
        }
        _ => fail("match 往返后语句形状不符")
      }
    Err(errors) => fail("match 往返失败: \{errors.length()} 个错误")
  }
}
