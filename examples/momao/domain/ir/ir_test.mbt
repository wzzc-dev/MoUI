///|
/// IR 结构测试：标签往返、事件矩阵、命名语法、预算统计、签名确定性。
test "control kind tags round-trip" {
  let kinds : Array[@ir.ControlKind] = [
    @ir.Button,
    @ir.Label,
    @ir.TextField,
    @ir.CheckBox,
    @ir.ListBox,
    @ir.Table,
  ]
  for kind in kinds {
    match @ir.parse_control_kind(kind.tag()) {
      Some(parsed) => assert_true(parsed.tag() == kind.tag())
      None => fail("tag round-trip failed: \{kind.tag()}")
    }
  }
  assert_true(@ir.parse_control_kind("checkbox") is None)
}

///|
test "event kind tags round-trip" {
  match @ir.parse_event_kind(@ir.OnClick.tag()) {
    Some(parsed) => assert_true(parsed is @ir.OnClick)
    None => fail("on_click round-trip failed")
  }
  match @ir.parse_event_kind(@ir.OnChange.tag()) {
    Some(parsed) => assert_true(parsed is @ir.OnChange)
    None => fail("on_change round-trip failed")
  }
  assert_true(@ir.parse_event_kind("click") is None)
}

///|
test "control supports event matrix" {
  assert_true(@ir.Button.supports_event(@ir.OnClick))
  assert_true(!@ir.Button.supports_event(@ir.OnChange))
  assert_true(@ir.ListBox.supports_event(@ir.OnClick))
  assert_true(@ir.ListBox.supports_event(@ir.OnChange))
  assert_true(@ir.Table.supports_event(@ir.OnClick))
  assert_true(!@ir.Table.supports_event(@ir.OnChange))
  assert_true(@ir.TextField.supports_event(@ir.OnChange))
  assert_true(!@ir.TextField.supports_event(@ir.OnClick))
  assert_true(@ir.CheckBox.supports_event(@ir.OnChange))
  assert_true(!@ir.CheckBox.supports_event(@ir.OnClick))
  assert_true(!@ir.Label.supports_event(@ir.OnClick))
  assert_true(!@ir.Label.supports_event(@ir.OnChange))
}

///|
test "name syntax rules" {
  assert_true(@ir.control_name_syntax_valid("确定按钮"))
  assert_true(@ir.control_name_syntax_valid("score_field"))
  assert_true(@ir.control_name_syntax_valid("_hidden"))
  assert_true(!@ir.control_name_syntax_valid("1button"))
  assert_true(!@ir.control_name_syntax_valid(""))
  assert_true(!@ir.control_name_syntax_valid("has space"))
  assert_true(
    !@ir.control_name_syntax_valid(
      "一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十一二三四",
    ),
  )
  assert_true(@ir.variable_name_syntax_valid("姓名"))
  assert_true(@ir.variable_name_syntax_valid("total2"))
}

///|
test "budgets count statements and depth" {
  let deep_body : Array[@ir.Stmt] = [
    @ir.WhileLoop(@ir.Var("flag"), [
      @ir.CountLoop(@ir.NumLit(3.0), Some("i"), [@ir.Assign("x", @ir.Var("i"))]),
    ]),
  ]
  assert_eq(@ir.count_stmts(deep_body), 3)
  assert_eq(@ir.stmt_loop_depth(deep_body), 2)
  let nested_expr = @ir.Binary(
    @ir.Add,
    @ir.Binary(@ir.Add, @ir.NumLit(1.0), @ir.NumLit(2.0)),
    @ir.Binary(@ir.Add, @ir.NumLit(3.0), @ir.NumLit(4.0)),
  )
  assert_eq(@ir.expr_depth(nested_expr), 3)
  assert_eq(@ir.expr_depth(@ir.NumLit(1.0)), 1)
}

///|
test "validate_program reports structural errors" {
  let program : @ir.MomaoProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "确定",
        x: 10,
        y: 10,
        width: 80,
        height: 28,
        items: [],
      },
      @ir.Control::{
        id: 2,
        kind: @ir.Label,
        name: "按钮",
        text: "重复",
        x: 10,
        y: 50,
        width: 80,
        height: 28,
        items: [],
      },
    ],
    variables: [@ir.Variable::{ name: "x", init: "0", }],
    handlers: [
      @ir.Handler::{
        control_name: "不存在",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body: [],
      },
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnChange,
        note_zh: "",
        note_en: "",
        body: [],
      },
    ],
  }
  let errors = @ir.validate_program(program)
  assert_true(errors.any(e => e is @ir.DuplicateControlName(_)))
  assert_true(errors.any(e => e is @ir.UnknownControlInHandler(_)))
  assert_true(errors.any(e => e is @ir.UnsupportedEvent(_, _)))
}

///|
test "program signature is deterministic" {
  let build = () => @ir.MomaoProgram::{
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
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "确定",
        event: @ir.OnClick,
        note_zh: "点击后打招呼",
        note_en: "say hi on click",
        body: [
          @ir.If(
            @ir.Var("开"),
            [@ir.Call("message_box", [@ir.StrLit("你好")])],
            [],
            [@ir.Assign("x", @ir.NumLit(1.0))],
          ),
          @ir.CountLoop(@ir.NumLit(3.0), Some("i"), [@ir.Break]),
        ],
      },
    ],
  }
  assert_eq(@ir.program_signature(build()), @ir.program_signature(build()))
  let a = build()
  let b = build()
  b.handlers[0].body[0] = @ir.Break
  assert_true(@ir.program_signature(a) != @ir.program_signature(b))
}

///|
test "find helpers and next id" {
  let program : @ir.MomaoProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        id: 7,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        items: [],
      },
    ],
    variables: [],
    handlers: [],
  }
  match @ir.find_control(program, "按钮") {
    Some(control) => assert_eq(control.id, 7)
    None => fail("find_control failed")
  }
  assert_true(@ir.find_control(program, "没有") is None)
  assert_eq(@ir.next_control_id(program), 8)
  assert_eq(@ir.next_control_id(@ir.empty_program()), 1)
}

///|
test "rect field edits clamp into the design canvas" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 600,
    y: 400,
    width: 100,
    height: 32,
    items: [],
  }
  // 拖出右/下边界 → 夹回画布内
  let moved = control.with_rect_field(@ir.RectX, 900)
  assert_eq(moved.x, @ir.DESIGN_WIDTH - control.width)
  let dropped = control.with_rect_field(@ir.RectY, -40)
  assert_eq(dropped.y, 0)
  // 宽度收到最小；扩大到画布宽时 x 夹回 0
  let narrow = control.with_rect_field(@ir.RectWidth, 1)
  assert_eq(narrow.width, @ir.MIN_CONTROL_SIZE)
  let wide = control.with_rect_field(@ir.RectWidth, 9999)
  assert_eq(wide.width, @ir.DESIGN_WIDTH)
  assert_eq(wide.x, 0)
}
