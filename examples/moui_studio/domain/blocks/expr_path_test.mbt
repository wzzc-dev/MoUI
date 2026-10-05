///|
/// 表达式路径寻址：积木插槽（reporter slot）的基础。
///
/// 此前积木投影把表达式**预渲染成字符串**，插槽在数据上不存在——用户只能
/// 改整行文本，不能把一块报告块拖进洞里。这一层补的是「寻址」。

///|
/// 按路径取子表达式：`x = 1 + 2` 的左右操作数。
test "expr_at addresses binary operands" {
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  // 根表达式 = 整个 1 + 2
  match @blocks.expr_at(body, [0], []) {
    Some(@ir.Binary(_, _, _)) => ()
    _ => fail("root expression is not the binary")
  }
  // [0] = 左操作数
  match @blocks.expr_at(body, [0], [0]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 1)
    _ => fail("left operand is not 1")
  }
  // [1] = 右操作数
  match @blocks.expr_at(body, [0], [1]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 2)
    _ => fail("right operand is not 2")
  }
}

///|
/// 嵌套路径：`x = (1 + 2) + 3` 的深层操作数。
test "expr_at descends nested expressions" {
  let body = [
    @ir.Assign(
      "x",
      @ir.Binary(
        @ir.Add,
        @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2)),
        @ir.IntLit(3),
      ),
    ),
  ]
  // [0,1] = 左边那个加法的右操作数 = 2
  match @blocks.expr_at(body, [0], [0, 1]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 2)
    _ => fail("nested right operand is not 2")
  }
  // 越界路径：None（不猜位置）
  assert_true(@blocks.expr_at(body, [0], [5]) is None)
  assert_true(@blocks.expr_at(body, [0], [0, 9]) is None)
  // 语句路径非法：None
  assert_true(@blocks.expr_at(body, [9], []) is None)
}

///|
/// 按路径替换子表达式：真的换掉那一个洞，其余不动。
test "replace_expr_at swaps one slot and leaves the rest intact" {
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  // 把右操作数换成 42
  let updated = @blocks.replace_expr_at(body, [0], [1], @ir.IntLit(42))
  assert_true(updated is Some(_))
  let after = updated.unwrap()
  // 结果文本：(1 + 42) —— 二元作为**右操作数**时按规范写法加括号
  // （`canonical_expr` 的既有规则，不是这次改动引入的）
  assert_eq(
    @studio_lang.canonical_expr(@blocks.expr_at(after, [0], []).unwrap()),
    "(1 + 42)",
  )
  // 左操作数没被动过
  match @blocks.expr_at(after, [0], [0]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 1)
    _ => fail("left operand changed unexpectedly")
  }
  // 原 body 不被改动（克隆后手术的纪律）
  assert_eq(
    @studio_lang.canonical_expr(@blocks.expr_at(body, [0], []).unwrap()),
    "(1 + 2)",
  )
}

///|
/// 空路径 = 换掉**根表达式**（整行的值）。
test "replace_expr_at with an empty path swaps the statement root" {
  let body = [@ir.Assign("x", @ir.IntLit(1))]
  let updated = @blocks.replace_expr_at(body, [0], [], @ir.IntLit(99))
  assert_true(updated is Some(_))
  let after = updated.unwrap()
  assert_eq(
    @studio_lang.canonical_expr(@blocks.expr_at(after, [0], []).unwrap()),
    "99",
  )
}

///|
/// 插槽编号按**规范书写顺序**：调用是实参顺序，索引是 [被索引, 下标]。
test "expr_at slot numbering follows canonical writing order" {
  // 用 Assign 包一层：`Call` 在 Expr 与 Stmt 里同名，裸写会被判歧义
  let call = [
    @ir.Assign(
      "z",
      @ir.Expr::Call(
        "set_text",
        [@ir.Var("a"), @ir.StrLit("b"), @ir.IntLit(7)],
      ),
    ),
  ]
  // 第 1 个实参
  match @blocks.expr_at(call, [0], [1]) {
    Some(@ir.StrLit(value)) => assert_eq(value, "b")
    _ => fail("second argument is not the string literal")
  }
  // 第 2 个实参
  match @blocks.expr_at(call, [0], [2]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 7)
    _ => fail("third argument is not 7")
  }
  // 索引：`rows[3]` 的 [0] = 被索引对象，[1] = 下标
  let idx = [@ir.Assign("y", @ir.Index(@ir.Var("rows"), @ir.IntLit(3)))]
  match @blocks.expr_at(idx, [0], [1]) {
    Some(@ir.IntLit(value)) => assert_eq(value, 3)
    _ => fail("index operand is not 3")
  }
}

///|
/// 无根表达式的语句（`Break` / 空 `Return`）：返回 `None` 而不是伪造一个。
test "statements without a root expression report none" {
  let body = [@ir.Break]
  assert_true(@blocks.expr_at(body, [0], []) is None)
  assert_true(@blocks.replace_expr_at(body, [0], [], @ir.IntLit(1)) is None)
}

///|
/// 叶子值识别：字面量与变量名是**可直接编辑的值**，其余是洞。
test "expr_leaf_text distinguishes values from slots" {
  assert_eq(@blocks.expr_leaf_text(@ir.IntLit(5)), Some("5"))
  assert_eq(@blocks.expr_leaf_text(@ir.NumLit(2.5)), Some("2.5"))
  assert_eq(@blocks.expr_leaf_text(@ir.StrLit("hi")), Some("hi"))
  assert_eq(@blocks.expr_leaf_text(@ir.BoolLit(true)), Some("true"))
  assert_eq(@blocks.expr_leaf_text(@ir.Var("score")), Some("score"))
  // 复合表达式不是叶子（它是洞）
  assert_true(
    @blocks.expr_leaf_text(
      @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2)),
    ) is None,
  )
  assert_true(
    @blocks.expr_leaf_text(@ir.Expr::Call("random", [@ir.IntLit(9)])) is None,
  )
}

///|
/// 值编辑的解析规则：**打什么都得存得下去**。
///
/// 这是值编辑与「手打整行」最大的语义差别：用户在数字格子里打 `abc`
/// 想要的是文本 `abc`，不是「解析失败」。报错会让用户觉得「改了没反应」。
test "parse_leaf_value accepts free text as a string" {
  // 界面语言影响**关键字**：中文的布尔是 `真`/`假`，英文是 `true`/`false`。
  // 用错语言会让 `true` 被当成普通文本——这正是第一次写这条用例时踩的坑。
  let lang = @studio_lang.En
  // 中文界面下布尔用中文关键字
  match @blocks.parse_leaf_value("真", @studio_lang.ZhHans) {
    @ir.BoolLit(flag) => assert_true(flag)
    _ => fail("CJK boolean keyword should parse in the Chinese UI")
  }
  // 数字 → 数字字面量（不是字符串 "5"）
  match @blocks.parse_leaf_value("5", lang) {
    @ir.IntLit(value) => assert_eq(value, 5)
    _ => fail("numeric input should parse as a number")
  }
  // 小数
  match @blocks.parse_leaf_value("2.5", lang) {
    @ir.NumLit(value) => assert_true(value > 2.4 && value < 2.6)
    _ => fail("decimal input should parse as a number")
  }
  // 布尔
  match @blocks.parse_leaf_value("true", lang) {
    @ir.BoolLit(flag) => assert_true(flag)
    _ => fail("boolean input should parse as a bool")
  }
  // 标识符 → 变量
  match @blocks.parse_leaf_value("score", lang) {
    @ir.Var(name) => assert_eq(name, "score")
    _ => fail("identifier input should parse as a variable")
  }
  // 任意文本（解析不了的）→ 字符串字面量，而不是失败
  match @blocks.parse_leaf_value("hello world", lang) {
    @ir.StrLit(text) => assert_eq(text, "hello world")
    _ => fail("free text should become a string literal")
  }
  // **带标点的中文是文本**，不带标点的中文才是变量名——词法器对标识符极
  // 宽松（任何非空白非运算符的连续字符都算 Ident），所以「你好」本来会被
  // 当成变量；形状检查拦住了带标点的情况。
  match @blocks.parse_leaf_value("你好，世界", lang) {
    @ir.StrLit(text) => assert_eq(text, "你好，世界")
    _ => fail("punctuated text should become a string literal")
  }
  match @blocks.parse_leaf_value("计数", lang) {
    @ir.Var(name) => assert_eq(name, "计数")
    _ => fail("a CJK identifier should stay a variable")
  }
  // 数字开头的不是标识符 → 当文本
  match @blocks.parse_leaf_value("1abc", lang) {
    @ir.StrLit(text) => assert_eq(text, "1abc")
    _ => fail("a name starting with a digit is literal text")
  }
  // 空输入 → 空字符串（不是报错也不是变量）
  match @blocks.parse_leaf_value("   ", lang) {
    @ir.StrLit(text) => assert_eq(text, "")
    _ => fail("blank input should become an empty string")
  }
  // 复合表达式**不**被接受为值（它是洞的内容，不是值）
  match @blocks.parse_leaf_value("1 + 2", lang) {
    @ir.StrLit(text) => assert_eq(text, "1 + 2")
    _ => fail("a compound expression typed into a value cell is literal text")
  }
}

///|
/// 字段访问（M5-5c 前端③）：唯一洞口是基底；字段名不可替换；
/// 路径寻址/替换与 canonical 插槽文本同源。
test "field access exposes the base as its only slot" {
  let body = [@ir.Assign("y", @ir.FieldAccess(@ir.Var("person"), "名字"))]
  // 根 = 整个字段访问；插槽文本与 canonical 同源
  match @blocks.expr_at(body, [0], []) {
    Some(@ir.FieldAccess(_, "名字")) => ()
    _ => fail("root is not the field access")
  }
  // [0] = 基底；越界槽位拒绝
  match @blocks.expr_at(body, [0], [0]) {
    Some(@ir.Var(name)) => assert_eq(name, "person")
    _ => fail("base slot is not person")
  }
  assert_true(@blocks.expr_at(body, [0], [1]) is None)
  // 换基底保字段名
  match @blocks.replace_expr_at(body, [0], [0], @ir.Var("学生")) {
    Some(next) =>
      assert_true(
        next[0] is @ir.Assign(_, @ir.FieldAccess(@ir.Var("学生"), "名字")),
      )
    None => fail("base replacement failed")
  }
  // 槽位 1（字段名位）不可写
  assert_true(
    @blocks.replace_expr_at(body, [0], [1], @ir.Var("x")) is None,
  )
}

///|
test "field access nests inside larger expressions" {
  // y = person.年龄 + 1：FieldAccess 占二元左槽 [0]，自身基底 [0,0]
  let body = [
    @ir.Assign(
      "y",
      @ir.Binary(
        @ir.Add,
        @ir.FieldAccess(@ir.Var("person"), "年龄"),
        @ir.IntLit(1),
      ),
    ),
  ]
  assert_eq(@blocks.expr_slot_count(@ir.FieldAccess(@ir.Var("p"), "f")), 1)
  match @blocks.expr_at(body, [0], [0, 0]) {
    Some(@ir.Var(name)) => assert_eq(name, "person")
    _ => fail("nested base is not person")
  }
  // 深层替换：person → 队员
  match @blocks.replace_expr_at(body, [0], [0, 0], @ir.Var("队员")) {
    Some(next) =>
      assert_true(
        next[0] is @ir.Assign(
          _,
          @ir.Binary(
            _,
            @ir.FieldAccess(@ir.Var("队员"), "年龄"),
            _,
          ),
        ),
      )
    None => fail("nested base replacement failed")
  }
}
