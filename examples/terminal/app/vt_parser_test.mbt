///|
test "plain text and newlines" {
  let p = VtParser::new(TermScreen::new(10, 3))
  p.feed("hello")
  p.feed("\r\nworld")
  debug_inspect(p.screen().line_at(0).text(), content="\"hello\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"world\"")
  debug_inspect(p.screen().cursor_row(), content="1")
  debug_inspect(p.screen().cursor_col(), content="5")
}

///|
test "utf8 wide chars" {
  let p = VtParser::new(TermScreen::new(10, 1))
  p.feed("中文ab")
  debug_inspect(p.screen().cursor_col(), content="6")
  debug_inspect(p.screen().line_at(0).text(), content="\"中文ab\"")
}

///|
test "sgr colors and reset" {
  let p = VtParser::new(TermScreen::new(20, 1))
  p.feed("\u{1b}[31mred\u{1b}[0mplain")
  let runs = p.screen().line_at(0).runs()
  debug_inspect(runs.length(), content="2")
  debug_inspect(runs[0].0, content="\"red\"")
  debug_inspect(runs[0].2.fg, content="Indexed(1)")
  debug_inspect(runs[1].0, content="\"plain\"")
  debug_inspect(runs[1].2.fg, content="Default")
}

///|
test "sgr 256 and rgb" {
  let p = VtParser::new(TermScreen::new(20, 1))
  p.feed("\u{1b}[38;5;196mA\u{1b}[48;2;10;20;30mB")
  let runs = p.screen().line_at(0).runs()
  debug_inspect(runs[0].2.fg, content="Indexed(196)")
  debug_inspect(runs[1].2.fg, content="Indexed(196)")
  debug_inspect(runs[1].2.bg, content="Rgb(10, 20, 30)")
}

///|
test "sgr styles" {
  let p = VtParser::new(TermScreen::new(20, 1))
  p.feed("\u{1b}[1;3;4mbold")
  debug_inspect(p.screen().current_attrs().bold, content="true")
  debug_inspect(p.screen().current_attrs().italic, content="true")
  debug_inspect(p.screen().current_attrs().underline, content="true")
  p.feed("\u{1b}[22;23;24moff")
  debug_inspect(p.screen().current_attrs().bold, content="false")
  debug_inspect(p.screen().current_attrs().italic, content="false")
  debug_inspect(p.screen().current_attrs().underline, content="false")
}

///|
test "cursor movement" {
  let p = VtParser::new(TermScreen::new(10, 5))
  p.feed("\u{1b}[3;4H")
  debug_inspect(p.screen().cursor_row(), content="2")
  debug_inspect(p.screen().cursor_col(), content="3")
  p.feed("\u{1b}[B")
  debug_inspect(p.screen().cursor_row(), content="3")
  p.feed("\u{1b}[C\u{1b}[C")
  debug_inspect(p.screen().cursor_col(), content="5")
  p.feed("\u{1b}[A\u{1b}[D")
  debug_inspect(p.screen().cursor_row(), content="2")
  debug_inspect(p.screen().cursor_col(), content="4")
  p.feed("\u{1b}[12G")
  debug_inspect(p.screen().cursor_col(), content="9")
}

///|
test "erase display and line" {
  let p = VtParser::new(TermScreen::new(4, 3))
  p.feed("abcd\r\nefgh\r\nijkl")
  p.feed("\u{1b}[2J")
  debug_inspect(p.screen().line_at(0).text(), content="\"\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"\"")
  debug_inspect(p.screen().line_at(2).text(), content="\"\"")
  p.feed("\u{1b}[3;1H")
  p.feed("xy")
  p.feed("\u{1b}[K")
  debug_inspect(p.screen().line_at(2).text(), content="\"xy\"")
}

///|
test "insert and delete lines" {
  let p = VtParser::new(TermScreen::new(4, 4))
  p.feed("a\r\nb\r\nc\r\nd")
  p.feed("\u{1b}[2;3r") // 滚动区域 2-3
  p.feed("\u{1b}[2;1H") // 光标到 (2,1)
  p.feed("\u{1b}[L") // 插入一行:底行 c 进入回看头部
  debug_inspect(p.screen().line_at(0).text(), content="\"c\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"a\"")
  debug_inspect(p.screen().line_at(2).text(), content="\"\"")
  debug_inspect(p.screen().line_at(3).text(), content="\"b\"")
  debug_inspect(p.screen().line_at(4).text(), content="\"d\"")
  p.feed("\u{1b}[M") // 删除一行:空行进入回看尾部
  debug_inspect(p.screen().line_at(0).text(), content="\"c\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"\"")
  debug_inspect(p.screen().line_at(2).text(), content="\"a\"")
  debug_inspect(p.screen().line_at(3).text(), content="\"b\"")
  debug_inspect(p.screen().line_at(4).text(), content="\"\"")
  debug_inspect(p.screen().line_at(5).text(), content="\"d\"")
}

///|
test "scroll region and su/sd" {
  let p = VtParser::new(TermScreen::new(4, 4))
  p.feed("a\r\nb\r\nc\r\nd")
  p.feed("\u{1b}[2;3r")
  p.feed("\u{1b}[S") // 区域内上滚:顶行 b 进入回看
  debug_inspect(p.screen().line_at(0).text(), content="\"b\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"a\"")
  debug_inspect(p.screen().line_at(2).text(), content="\"c\"")
  debug_inspect(p.screen().line_at(3).text(), content="\"\"")
  debug_inspect(p.screen().line_at(4).text(), content="\"d\"")
  p.feed("\u{1b}[T") // 区域内下滚:底行空进入回看头部
  debug_inspect(p.screen().line_at(0).text(), content="\"\"")
  debug_inspect(p.screen().line_at(1).text(), content="\"b\"")
  debug_inspect(p.screen().line_at(2).text(), content="\"a\"")
  debug_inspect(p.screen().line_at(3).text(), content="\"\"")
  debug_inspect(p.screen().line_at(4).text(), content="\"c\"")
  debug_inspect(p.screen().line_at(5).text(), content="\"d\"")
}

///|
test "osc title" {
  let p = VtParser::new(TermScreen::new(10, 2))
  p.feed("\u{1b}]0;My Shell\u{7}")
  debug_inspect(p.screen().title(), content="\"My Shell\"")
  p.feed("\u{1b}]2;Another:Title\u{1b}\\")
  debug_inspect(p.screen().title(), content="\"Another:Title\"")
}

///|
test "save restore cursor" {
  let p = VtParser::new(TermScreen::new(10, 5))
  p.feed("\u{1b}[3;4H\u{1b}[s")
  p.feed("\u{1b}[1;1H")
  p.feed("\u{1b}[u")
  debug_inspect(p.screen().cursor_row(), content="2")
  debug_inspect(p.screen().cursor_col(), content="3")
}

///|
test "wrap mode and cursor visibility" {
  let p = VtParser::new(TermScreen::new(3, 2))
  p.feed("\u{1b}[?7l") // 关闭自动换行
  p.feed("abcde")
  // 光标停在最后一列,后续字符覆盖
  debug_inspect(p.screen().line_at(0).text(), content="\"abe\"")
  p.feed("\u{1b}[?7h")
  p.feed("\u{1b}[?25l")
  debug_inspect(p.screen().cursor_visible(), content="false")
  p.feed("\u{1b}[?25h")
  debug_inspect(p.screen().cursor_visible(), content="true")
}

///|
test "ris reset" {
  let p = VtParser::new(TermScreen::new(10, 3))
  p.feed("\u{1b}[31mtext")
  p.feed("\u{1b}[2;2H")
  p.feed("\u{1b}c")
  debug_inspect(p.screen().current_attrs().fg, content="Default")
  debug_inspect(p.screen().cursor_row(), content="0")
  debug_inspect(p.screen().cursor_col(), content="0")
  debug_inspect(p.screen().line_at(0).text(), content="\"\"")
}

///|
test "csi params edge cases" {
  let p = VtParser::new(TermScreen::new(10, 5))
  p.feed("\u{1b}[H") // 无参数定位
  debug_inspect(p.screen().cursor_row(), content="0")
  debug_inspect(p.screen().cursor_col(), content="0")
  p.feed("\u{1b}[;3H") // 空第一参数
  debug_inspect(p.screen().cursor_row(), content="0")
  debug_inspect(p.screen().cursor_col(), content="2")
  p.feed("ab\u{1b}[2D") // 左移 2 列
  debug_inspect(p.screen().cursor_col(), content="2")
  p.feed("\u{1b}[99A") // 上移越界
  debug_inspect(p.screen().cursor_row(), content="0")
}

///|
test "unknown sequences ignored" {
  let p = VtParser::new(TermScreen::new(10, 2))
  p.feed("\u{1b}[?1000h\u{1b}(B\u{1b}=")
  p.feed("ok")
  debug_inspect(p.screen().line_at(0).text(), content="\"ok\"")
}

///|
test "out of range scroll region clamps" {
  let p = VtParser::new(TermScreen::new(10, 3))
  p.feed("\u{1b}[999;999r") // 越界滚动区域:必须 clamp 而非 panic
  p.feed("\u{1b}[B")
  p.feed("x")
  debug_inspect(p.screen().line_at(1).text(), content="\"x\"")
  p.feed("\u{1b}[r") // 恢复全屏区域
  p.feed("\u{1b}[3;1Hy")
  debug_inspect(p.screen().line_at(2).text(), content="\"y\"")
}

///|
test "truncated utf8 discarded on escape" {
  let p = VtParser::new(TermScreen::new(10, 2))
  // 中 = E4 B8 AD;E4 B8 后 ESC[31m 打断,再喂完整 "文"
  p.feed_bytes(Bytes::from_array([0xE4, 0xB8, 0x1B, 0x5B, 0x33, 0x31, 0x6D]))
  p.feed("文")
  debug_inspect(p.screen().line_at(0).text(), content="\"文\"")
  // C0 打断同理
  let p2 = VtParser::new(TermScreen::new(10, 2))
  p2.feed_bytes(Bytes::from_array([0xE4, 0xB8, 0x0D, 0x0A]))
  p2.feed("文")
  debug_inspect(p2.screen().line_at(1).text(), content="\"文\"")
}

///|
test "overflow csi params do not crash" {
  let p = VtParser::new(TermScreen::new(10, 4))
  // 19 位数字溢出 Int64 → 饱和;insert_chars/delete_chars/cursor 必须安全
  p.feed("\u{1b}[9999999999999999999@")
  p.feed("\u{1b}[9999999999999999999P")
  p.feed("\u{1b}[9999999999999999999A")
  p.feed("\u{1b}[9999999999999999999B")
  p.feed("\u{1b}[9999999999999999999C")
  p.feed("\u{1b}[9999999999999999999D")
  p.feed("x")
  // 光标必须始终落在屏幕内
  debug_inspect(
    p.screen().cursor_row() >= 0 && p.screen().cursor_row() < 4,
    content="true",
  )
  debug_inspect(
    p.screen().cursor_col() >= 0 && p.screen().cursor_col() < 10,
    content="true",
  )
  // 字符确实被写入
  let mut found = false
  for r in 0..<4 {
    if p.screen().line_at(r).text().contains("x") {
      found = true
    }
  }
  debug_inspect(found, content="true")
}

///|
test "huge positive counts clamp quickly" {
  let p = VtParser::new(TermScreen::new(10, 4))
  p.feed("a\r\nb\r\nc")
  // 10 位正数:若未 clamp 会冻结;clamp 到区域高度后立即完成
  p.feed("\u{1b}[9999999999S")
  p.feed("\u{1b}[9999999999T")
  p.feed("\u{1b}[9999999999L")
  p.feed("\u{1b}[9999999999M")
  p.feed("x")
  // 滚动/插入/删除全部 clamp 到区域高度,回看与屏幕尺寸保持合理
  debug_inspect(p.screen().total_lines() <= 64, content="true")
  debug_inspect(
    p.screen().cursor_row() >= 0 && p.screen().cursor_row() < 4,
    content="true",
  )
  debug_inspect(
    p.screen().cursor_col() >= 0 && p.screen().cursor_col() < 10,
    content="true",
  )
}

///|
test "unbounded osc and params are capped" {
  let p = VtParser::new(TermScreen::new(10, 2))
  // 超长 OSC(>8KB)不崩溃,标题取截断值
  let long_osc = "\u{1b}]0;" + "x".repeat(20000) + "\u{7}"
  p.feed(long_osc)
  debug_inspect(p.screen().title().length() <= 8200, content="true")
  // 超长参数序列(>64 个参数)不崩溃
  let many_params = "\u{1b}[0;" + "1;".repeat(200) + "m"
  p.feed(many_params)
  p.feed("ok")
  debug_inspect(p.screen().line_at(0).text(), content="\"ok\"")
}
