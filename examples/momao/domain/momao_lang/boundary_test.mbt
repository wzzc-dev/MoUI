///|
/// 词法/语法边界：全角归一化、比较符兼容、混合标识符、错误定位、深嵌套。

///|
fn parse_body(source : String) -> Result[Array[@ir.Stmt], @momao_lang.LangError] {
  match @momao_lang.parse_handler_body(source, @momao_lang.ZhHans) {
    Ok(traced) => Ok(traced.map(t => t.stmt))
    Err(error) => Err(error)
  }
}

///|
test "full-width punctuation and digits normalize" {
  // 全角括号/逗号/等号/数字/加号直接解析（中文 IME 输入友好）
  let with_fullwidth = parse_body("信息框（\"你好\"）\n变量 x ＝ １２ ＋ ３\n")
  match with_fullwidth {
    Ok(body) => {
      assert_eq(body.length(), 2)
      assert_true(body[0] is @ir.Call(_, _))
      assert_true(body[1] is @ir.Declare("x", _))
    }
    Err(error) => fail("全角应可解析: line \{@momao_lang.LangError::line(error)}")
  }
}

///|
test "compat comparison symbols ne/le/ge" {
  let source = "如果 1 ≠ 2 则\nx = 1\n结束\n如果 1 ≤ 2 则\nx = 2\n结束\n如果 1 ≥ 0 则\nx = 3\n结束\n"
  match parse_body(source) {
    Ok(body) => assert_eq(body.length(), 3)
    Err(error) => fail("≠ ≤ ≥ 应可解析: line \{@momao_lang.LangError::line(error)}")
  }
}

///|
test "mixed cjk/ascii identifiers with digits" {
  match parse_body("变量 姓名2 = \"张三\"\n姓名2 = \"李四\"\n") {
    Ok(body) => {
      assert_true(body[0] is @ir.Declare("姓名2", _))
      assert_true(body[1] is @ir.Assign("姓名2", _))
    }
    Err(error) => fail("混合标识符应可解析: line \{@momao_lang.LangError::line(error)}")
  }
}

///|
test "parse errors carry the line number" {
  match parse_body("变量 x = 1\n变量 y = \n") {
    Ok(_) => fail("残缺语句应报错")
    Err(error) => assert_eq(@momao_lang.LangError::line(error), 2)
  }
}

///|
test "deep loop nesting parses (within budget)" {
  let depth = 15
  let buf = StringBuilder()
  let mut i = 0
  while i < depth {
    buf.write_string("计次循环 2 次\n")
    i = i + 1
  }
  buf.write_string("x = 1\n")
  i = 0
  while i < depth {
    buf.write_string("结束\n")
    i = i + 1
  }
  match parse_body(buf.to_string()) {
    Ok(body) => assert_eq(@ir.stmt_loop_depth(body), depth)
    Err(error) => fail("15 层嵌套应可解析: line \{@momao_lang.LangError::line(error)}")
  }
}
