///|
/// 终端插件测试（M5）：**假通道驱动状态机**——无头全量测试绝不真起 PTY
/// （已知 pty_host 无头挂起的坑；真冒烟路径另行触发）。

///|
test "terminal state starts unavailable and idle" {
  let state = TerminalState::new()
  assert_false(state.available)
  assert_false(state.running())
  assert_eq(state.screen.length(), 0)
  assert_eq(state.input_draft, "")
}

///|
test "terminal feed output handles echo newline and backspace" {
  let state = TerminalState::new(available=true)
  // shell 回显：提示符 + 用户键入 + \r\n（末尾 \n 开出新空行 = 等待输入）
  state.feed_output("\u{1b}[32muser@host\u{1b}[0m ~/demo % ls\r\n")
  assert_eq(state.screen.length(), 2)
  assert_eq(state.screen[0], "user@host ~/demo % ls")
  assert_eq(state.screen[1], "")
  // 回显用户键入 + 结果：写入从上一行的空行（screen[1]）继续
  state.feed_output("README.md\r\ndocs\r\n")
  assert_eq(state.screen[1], "README.md")
  assert_eq(state.screen[2], "docs")
  assert_eq(state.screen[3], "")
}

///|
test "terminal feed output handles carriage return overwrite" {
  let state = TerminalState::new(available=true)
  // 进度条式回车覆盖：\r 回列首，后续写入按列覆写
  state.feed_output("progress 30%\r")
  // \r 只移列：内容保留到被覆写
  assert_eq(state.screen[0], "progress 30%")
  state.feed_output("progress 60%")
  assert_eq(state.screen[0], "progress 60%")
  assert_eq(state.screen.length(), 1)
  // 退格移列 + 按列覆写：col 12 → 8，"70%" 落在 8/9/10
  // （"progress 60%" 的 8=' ' 9='6' 10='0'，末位 '%' 未动）
  state.feed_output("\b\b\b\b")
  state.feed_output("70%")
  assert_eq(state.screen[0], "progress70%%")
}

///|
test "terminal feed output strips csi and osc escapes" {
  let state = TerminalState::new(available=true)
  // CSI 光标定位（CUP）只剥离不执行（v1 行缓冲屏口径）
  state.feed_output("\u{1b}[2J\u{1b}[Hclear+home")
  assert_eq(state.screen[0], "clear+home")
  // OSC 标题（BEL 结尾）与 ST 结尾（先换行再断言第二行）
  state.feed_output("\n\u{1b}]0;my title\u{7}next \u{1b}]2;t\u{1b}\\line")
  assert_eq(state.screen[1], "next line")
}

///|
test "terminal input draft and submit" {
  let state = TerminalState::new(available=true)
  for c in "ls -la" {
    state.type_char(c)
  }
  assert_eq(state.input_draft, "ls -la")
  state.backspace()
  assert_eq(state.input_draft, "ls -l")
  // 回车提交：整行 + 换行，草稿清空
  match state.take_input() {
    Some(line) => assert_eq(line, "ls -l\n")
    None => fail("应有待写入输入")
  }
  assert_eq(state.input_draft, "")
  // 空行回车也是有效输入
  match state.take_input() {
    Some(line) => assert_eq(line, "\n")
    None => fail("空行回车应为有效输入")
  }
}

///|
test "terminal session lifecycle keeps screen for review" {
  let state = TerminalState::new(available=true)
  state.feed_output("hello\n")
  state.handle = Some(0)
  assert_true(state.running())
  // 退出：句柄清空，屏保留回看
  state.session_closed()
  assert_false(state.running())
  assert_eq(state.screen[0], "hello")
}
