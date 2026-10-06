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
      @ir.CountLoop(@ir.IntLit(3), Some("i"), [@ir.Assign("x", @ir.Var("i"))]),
    ]),
  ]
  assert_eq(@ir.count_stmts(deep_body), 3)
  assert_eq(@ir.stmt_loop_depth(deep_body), 2)
  let nested_expr = @ir.Binary(
    @ir.Add,
    @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2)),
    @ir.Binary(@ir.Add, @ir.IntLit(3), @ir.IntLit(4)),
  )
  assert_eq(@ir.expr_depth(nested_expr), 3)
  assert_eq(@ir.expr_depth(@ir.IntLit(1)), 1)
}

///|
test "budget checks count nested statements and independent branches" {
  let branch : Array[@ir.Stmt] = [
    @ir.If(
      @ir.BoolLit(true),
      [@ir.WhileLoop(@ir.BoolLit(true), [@ir.Break])],
      [],
      [@ir.CountLoop(@ir.IntLit(2), None, [@ir.Break])],
    ),
  ]
  assert_eq(@ir.count_stmts(branch), 5)
  assert_eq(@ir.stmt_loop_depth(branch), 1)

  let body : Array[@ir.Stmt] = []
  let mut i = 0
  while i < @ir.MAX_STMTS_PER_HANDLER + 1 {
    body.push(@ir.Call("message_box", [@ir.StrLit("x")]))
    i = i + 1
  }
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "",
        note_en: "",
        body,
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
  let expected = @ir.MAX_STMTS_PER_HANDLER + 1
  assert_true(
    @ir.validate_program(program).any(e => {
      e is @ir.TooManyStatements(n) && n == expected
    }),
  )
}

///|
test "invalid control rectangles are rejected at the input boundary" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 639,
    y: 0,
    width: 8,
    height: 8,
    items: [],
  }
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [{ ..control, width: 9, }],
    variables: [],
    handlers: [],
    functions: [],
    structs: [],
    enums: [],
  }
  assert_true(
    @ir.validate_program(program).any(e => e is @ir.InvalidControlRect("按钮")),
  )
}

///|
test "validate_program reports structural errors" {
  let program : @ir.StudioProgram = {
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
    functions: [],
    structs: [],
    enums: [],
  }
  let errors = @ir.validate_program(program)
  assert_true(errors.any(e => e is @ir.DuplicateControlName(_)))
  assert_true(errors.any(e => e is @ir.UnknownControlInHandler(_)))
  assert_true(errors.any(e => e is @ir.UnsupportedEvent(_, _)))
}

///|
test "program signature is deterministic" {
  let build = () => @ir.StudioProgram::{
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
            [@ir.Assign("x", @ir.IntLit(1))],
          ),
          @ir.CountLoop(@ir.IntLit(3), Some("i"), [@ir.Break]),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
  assert_eq(@ir.program_signature(build()), @ir.program_signature(build()))
  let a = build()
  let b = build()
  b.handlers[0].body[0] = @ir.Break
  assert_true(@ir.program_signature(a) != @ir.program_signature(b))
}

///|
test "find helpers and next id" {
  let program : @ir.StudioProgram = {
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
    functions: [],
    structs: [],
    enums: [],
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

///|
test "resize from SE corner keeps top-left fixed and clamps" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 600,
    y: 400,
    width: 30,
    height: 30,
    items: [],
  }
  // 正常生长：左上角不动
  let grown = control.resize_from_corner(@ir.CornerSE, 635, 470)
  assert_eq(grown.x, 600)
  assert_eq(grown.y, 400)
  assert_eq(grown.width, 35)
  assert_eq(grown.height, 70)
  // 拖出画布 → 夹回画布边界（左上角仍不动）
  let beyond = control.resize_from_corner(@ir.CornerSE, 9999, 9999)
  assert_eq(beyond.width, @ir.DESIGN_WIDTH - 600)
  assert_eq(beyond.height, @ir.DESIGN_HEIGHT - 400)
  // 收缩到最小边长
  let tiny = control.resize_from_corner(@ir.CornerSE, -100, -100)
  assert_eq(tiny.width, @ir.MIN_CONTROL_SIZE)
  assert_eq(tiny.height, @ir.MIN_CONTROL_SIZE)
  // 负向拽过头也不能越过左上角（保持最小）
  assert_true(tiny.x == 600 && tiny.y == 400)
}

///|
test "resize from NW corner keeps bottom-right fixed and clamps" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 100,
    y: 100,
    width: 60,
    height: 40,
    items: [],
  }
  // 正常生长：右下角 (160, 140) 不动，左上角随指针
  let grown = control.resize_from_corner(@ir.CornerNW, 80, 90)
  assert_eq(grown.x, 80)
  assert_eq(grown.y, 90)
  assert_eq(grown.width, 80)
  assert_eq(grown.height, 50)
  // 拽过右下角 → 夹到最小边长，对角仍固定
  let tiny = control.resize_from_corner(@ir.CornerNW, 5000, 5000)
  assert_eq(tiny.x, 160 - @ir.MIN_CONTROL_SIZE)
  assert_eq(tiny.y, 140 - @ir.MIN_CONTROL_SIZE)
  assert_eq(tiny.width, @ir.MIN_CONTROL_SIZE)
  assert_eq(tiny.height, @ir.MIN_CONTROL_SIZE)
  assert_eq(tiny.x + tiny.width, 160)
  assert_eq(tiny.y + tiny.height, 140)
  // 拽出画布左/上 → 夹回画布原点，右下角仍固定
  let beyond = control.resize_from_corner(@ir.CornerNW, -50, -50)
  assert_eq(beyond.x, 0)
  assert_eq(beyond.y, 0)
  assert_eq(beyond.x + beyond.width, 160)
  assert_eq(beyond.y + beyond.height, 140)
}

///|
test "resize from NE/SW corners keeps opposite edges fixed" {
  let control : @ir.Control = {
    id: 1,
    kind: @ir.Button,
    name: "按钮",
    text: "",
    x: 100,
    y: 100,
    width: 60,
    height: 40,
    items: [],
  }
  // NE：左缘与下缘固定，右缘/上缘随指针
  let ne = control.resize_from_corner(@ir.CornerNE, 200, 70)
  assert_eq(ne.x, 100)
  assert_eq(ne.y, 70)
  assert_eq(ne.width, 100)
  assert_eq(ne.height, 70)
  assert_eq(ne.y + ne.height, 140)
  // NE 拽出画布右缘 → 宽度夹到画布边界
  let ne_wide = control.resize_from_corner(@ir.CornerNE, 9999, 100)
  assert_eq(ne_wide.width, @ir.DESIGN_WIDTH - 100)
  // SW：右缘与上缘固定，左缘/下缘随指针
  let sw = control.resize_from_corner(@ir.CornerSW, 70, 200)
  assert_eq(sw.x, 70)
  assert_eq(sw.width, 90)
  assert_eq(sw.y, 100)
  assert_eq(sw.height, 100)
  assert_eq(sw.x + sw.width, 160)
  // SW 拽过右缘 → 夹到最小边长，右缘仍固定
  let sw_tiny = control.resize_from_corner(@ir.CornerSW, 5000, 200)
  assert_eq(sw_tiny.width, @ir.MIN_CONTROL_SIZE)
  assert_eq(sw_tiny.x + sw_tiny.width, 160)
}

///|
test "duplicate handler pair is rejected" {
  let handler : @ir.Handler = {
    control_name: "按钮",
    event: @ir.OnClick,
    note_zh: "点",
    note_en: "click",
    body: [],
  }
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "",
        x: 0,
        y: 0,
        width: 80,
        height: 28,
        items: [],
      },
    ],
    variables: [],
    handlers: [handler, { ..handler, note_zh: "重复", note_en: "dup", }],
    functions: [],
    structs: [],
    enums: [],
  }
  assert_true(
    @ir.validate_program(program).any(e => e is @ir.DuplicateHandler(_)),
  )
  // 同控件不同事件不冲突
  let ok : @ir.StudioProgram = {
    ..program,
    handlers: [handler, { ..handler, event: @ir.OnChange, }],
    functions: [],
    structs: [],
    enums: [],
  }
  assert_true(!@ir.validate_program(ok).any(e => e is @ir.DuplicateHandler(_)))
}
