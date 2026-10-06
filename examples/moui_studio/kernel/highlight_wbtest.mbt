///|
/// MoonBit 词法器测试（M6①）：注释/字符串插值/数字/关键字/类型名，
/// 以及「失败只降级纯文本」口径。

///|
/// 助手：按分类聚合 token 文本。
fn kinds_of(tokens : Array[HighlightToken]) -> Array[HighlightKind] {
  tokens.map(token => token.kind)
}

///|
test "moonbit highlight line comment and keywords" {
  let tokens = moonbit_highlight("let x = 1 // 注释")
  let kinds = kinds_of(tokens)
  // let(关键字) plain(空格+x+空格=1) ... 注释
  assert_true(kinds.contains(HlKeyword))
  assert_true(kinds.contains(HlComment))
  // 注释 token 从 // 起
  let mut comment = ""
  for token in tokens {
    if token.kind is HlComment {
      comment = token.text
    }
  }
  assert_eq(comment, "// 注释")
}

///|
test "moonbit highlight string with interpolation" {
  // \{...} 插值：字符串不因内部引号断开，插值段与字符串段区分
  let tokens = moonbit_highlight("let s = \"a \\{name} b\"")
  let kinds = kinds_of(tokens)
  assert_true(kinds.contains(HlKeyword))
  assert_true(kinds.contains(HlString))
  assert_true(kinds.contains(HlPlain))
  // 全文无 NUL 丢单字符丢失：按 start 排序且连续覆盖
  let mut covered = 0
  for token in tokens {
    assert_eq(token.start, covered)
    covered = covered + token.text.length()
  }
  assert_eq(covered, "let s = \"a \\{name} b\"".length())
}

///|
test "moonbit highlight block comment and numbers and types" {
  let tokens = moonbit_highlight("/* 块注释 */ let n = 42 + Width")
  let kinds = kinds_of(tokens)
  assert_true(kinds.contains(HlComment))
  assert_true(kinds.contains(HlNumber))
  // 大写类型名 → HlBuiltin
  let mut has_builtin = false
  for token in tokens {
    if token.text == "Width" && token.kind is HlBuiltin {
      has_builtin = true
    }
  }
  assert_true(has_builtin)
}

///|
test "moonbit highlight unterminated constructs degrade to literal" {
  // 未闭合字符串/块注释：剩余文本按该 token 类收尾（不吞不崩）
  let tokens = moonbit_highlight("let s = \"未闭合")
  // 覆盖完整性：token 拼接 == 原文
  let buf = StringBuilder()
  for token in tokens {
    buf.write_string(token.text)
  }
  assert_eq(buf.to_string(), "let s = \"未闭合")
}

///|
test "moonbit highlighter service dispatches by language" {
  let service = HighlightService::new()
  service.register({ language: "moonbit", run: moonbit_highlight, })
  match service.dispatch("moonbit") {
    Some(highlighter) => {
      let tokens = (highlighter.run)("let x = 1")
      assert_true(kinds_of(tokens).contains(HlKeyword))
    }
    None => fail("moonbit highlighter should be registered")
  }
  assert_true(service.dispatch("unknown") is None)
}
