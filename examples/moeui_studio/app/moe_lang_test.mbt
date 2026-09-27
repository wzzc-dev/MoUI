///|
/// 记录型宿主：把信息框/设置文本调用记下来；控件文本维护一张实时表
/// （初始值来自 initial，设置文本会覆盖），读文本从表里取。
priv struct RecordingHost {
  boxes : Array[String]
  texts : Array[(String, String)]
  values : Map[String, String]
}

///|
fn RecordingHost::make(initial : Array[(String, String)]) -> RecordingHost {
  let values : Map[String, String] = Map([], capacity=8)
  for pair in initial {
    values[pair.0] = pair.1
  }
  { boxes: [], texts: [], values, }
}

///|
fn RecordingHost::host(self : RecordingHost) -> HostContext {
  {
    message_box: fn(text) { self.boxes.push(text) },
    set_text: fn(name, text) {
      self.values[name] = text
      self.texts.push((name, text))
    },
    get_text: fn(name) {
      match self.values.get(name) {
        Some(value) => value
        None => ""
      }
    },
  }
}

///|
fn run_ok(source : String) -> RecordingHost {
  let host = RecordingHost::make([])
  match run_body(source, host.host()) {
    Ok(_) => host
    Err(error) =>
      abort("应运行成功：\{error.message()}（行 \{error.line()}）")
  }
}

///|
fn run_expect_error(source : String, message_part : String) -> Unit {
  let host = RecordingHost::make([])
  match run_body(source, host.host()) {
    Ok(_) => abort("应报错：\{message_part}")
    Err(error) =>
      if !error.message().contains(message_part) {
        abort(
          "错误信息应包含「\{message_part}」，实际：「\{error.message()}」",
        )
      }
  }
}

///|
test "赋值与算术" {
  let host = run_ok(
    "变量 总价 = 3 * 7 + 1\n总价 = 总价 - 2\n信息框(转文本(总价))",
  )
  assert_true(host.boxes == ["20"])
}

///|
test "字符串拼接与全角标点容错" {
  let host = run_ok(
    "变量 名字 = \"世界\"\n信息框（\"你好，\" + 名字 + \"！\"）",
  )
  assert_true(host.boxes == ["你好，世界！"])
}

///|
test "如果否则与比较" {
  let host = run_ok(
    "变量 分数 = 85\n如果 分数 >= 60 则\n信息框(\"及格\")\n否则\n信息框(\"不及格\")\n结束",
  )
  assert_true(host.boxes == ["及格"])
  let host2 = run_ok(
    "变量 分数 = 30\n如果 分数 >= 60 则\n信息框(\"及格\")\n否则\n信息框(\"不及格\")\n结束",
  )
  assert_true(host2.boxes == ["不及格"])
}

///|
test "否则如果链共享一个结束" {
  let host = run_ok(
    "变量 x = 2\n如果 x = 1 则\n信息框(\"一\")\n否则如果 x = 2 则\n信息框(\"二\")\n否则\n信息框(\"多\")\n结束",
  )
  assert_true(host.boxes == ["二"])
}

///|
test "计次循环与循环变量" {
  let host = run_ok(
    "变量 合计 = 0\n计次循环 4 次 为 i\n合计 = 合计 + i\n结束\n信息框(转文本(合计))",
  )
  assert_true(host.boxes == ["10"])
}

///|
test "当循环" {
  let host = run_ok(
    "变量 i = 1\n当 i <= 3 循环\n信息框(\"第\" + 转文本(i) + \"次\")\ni = i + 1\n结束",
  )
  assert_true(host.boxes.length() == 3)
}

///|
test "步数预算拦截死循环" {
  let host = RecordingHost::make([])
  match
    run_body(
      "变量 i = 0\n当 真 循环\ni = i + 1\n结束",
      host.host(),
      max_steps=1000,
    ) {
    Ok(_) => abort("死循环应被预算拦截")
    Err(error) => assert_true(error.message().contains("预算"))
  }
}

///|
test "设置文本与取文本、取数值" {
  let host = RecordingHost::make([("输入框1", "12"), ("输入框2", "30")])
  match
    run_body(
      "变量 和 = 取数值(\"输入框1\") + 取数值(\"输入框2\")\n设置文本(\"标签1\", \"和是\" + 转文本(和))\n信息框(取文本(\"标签1\"))",
      host.host(),
    ) {
    Ok(_) => ()
    Err(error) => abort("应运行成功：\{error.message()}")
  }
  assert_true(host.texts == [("标签1", "和是42")])
  assert_true(host.boxes == ["和是42"])
}

///|
test "运行期错误带可读信息" {
  run_expect_error("信息框(取数值(\"输入框1\"))", "不是有效数字")
  run_expect_error("变量 x = 1 / 0", "除数不能为零")
  run_expect_error("y = 5", "未声明")
  // 重复声明允许（覆盖），不报错
  run_expect_error("如果 1 + 1 则\n结束", "逻辑值")
  run_expect_error("信息框(1 = \"1\")", "不能比较")
  run_expect_error("神秘命令(1)", "未知的命令或函数")
  run_expect_error("如果 真 则\n信息框(\"缺结束\")", "结束")
}

///|
test "词法：全角数字与括号" {
  let host = run_ok("变量 x = （１２＋３）\n信息框(转文本(x))")
  assert_true(host.boxes == ["15"])
}

///|
test "实时语法检查" {
  assert_true(check_source("信息框(\"好\")") is None)
  match check_source("如果 真 则") {
    Some(error) => assert_true(error.message().contains("结束"))
    None => abort("缺结束应报语法错误")
  }
  match check_source("变量 = 3") {
    Some(error) => assert_true(error.message().contains("名称"))
    None => abort("缺变量名应报语法错误")
  }
}

///|
test "非与逻辑运算" {
  let host = run_ok(
    "如果 非 (1 = 2) 且 (真 或 假) 则\n信息框(\"对\")\n结束",
  )
  assert_true(host.boxes == ["对"])
}

///|
test "取长度与文本包含" {
  let host = run_ok(
    "变量 s = \"Mo易\"\n如果 取长度(s) = 3 且 文本包含(s, \"易\") 则\n信息框(\"通过\")\n结束",
  )
  assert_true(host.boxes == ["通过"])
}

///|
test "整数值不带小数点显示" {
  let host = run_ok(
    "信息框(转文本(10 / 2))\n信息框(转文本(10 / 4))",
  )
  assert_true(host.boxes == ["5", "2.5"])
}
