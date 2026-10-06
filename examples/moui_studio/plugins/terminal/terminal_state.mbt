///|
/// 终端插件·状态切片（M5）：模式 3 底栏真终端的会话状态。
///
/// 协作纪律（契约 4）：本切片不 import 任何插件；PTY 能力经内核
/// `PtyService` 键取（native provider 在组合根 vendor examples/terminal
/// 的 pty.c 宿主技术）；web/无头组合根给 unavailable——切片如实呈现
/// 「不可用」空态，不假装能开。
///
/// 屏状态 v1：**行缓冲屏**（非全量 VT 单元格网格）——PTY 原始输出经
/// `feed_output` 做最小 VT 处理（剥离 ANSI CSI/OSC 转义序列、处理
/// 回车/退格/换行），维护行数组。真机交互（回显命令、看输出）足够；
/// 全屏 TUI 程序（vim 等）不在 v1 承诺内，诚实降级为乱序文本行。

///|
pub(all) struct TerminalState {
  /// 本端 PTY 能力（由组合根注入的服务决定；web = false → 空态）
  available : Bool
  /// 会话句柄（组合根登记表 id；None = 未派生）
  mut handle : Int?
  /// 行缓冲屏（已应用最小 VT 处理的可见行；数组共享可变，audit_entries 同款）
  screen : Array[String]
  /// 用户正在键入的行（回车提交给 PTY）
  mut input_draft : String
  /// PTY 输出的列光标（\r 只移列不删内容——覆盖发生在后续可见字符写入时，
  /// 这是进度条回车覆盖与 \r\n 行终止得以共存的关键）
  mut col : Int
  cols : Int
  rows : Int
}

///|
/// 初始状态：available 由组合根按服务能力注入。
pub fn TerminalState::new(
  available? : Bool = false,
  cols? : Int = 80,
  rows? : Int = 24,
) -> TerminalState {
  { available, handle: None, screen: [], input_draft: "", col: 0, cols, rows, }
}

///|
/// 是否已派生会话。
pub fn TerminalState::running(self : TerminalState) -> Bool {
  self.handle is Some(_)
}

///|
/// 键入一个可见字符（底栏终端输入行）。
pub fn TerminalState::type_char(self : TerminalState, c : Char) -> Unit {
  let buf = StringBuilder()
  buf.write_string(self.input_draft)
  buf.write_char(c)
  self.input_draft = buf.to_string()
}

///|
/// 输入行内容变更（受控字段）：on_input 交付的是**字段完整新值**，
/// 直接替换草稿（此前实现按增量追加，导致 `ls` 变 `lls`）。
pub fn TerminalState::type_text(self : TerminalState, text : String) -> Unit {
  self.input_draft = text
}

///|
/// 退格：草稿去掉最后一个字符（无字符 no-op）。
pub fn TerminalState::backspace(self : TerminalState) -> Unit {
  if self.input_draft.length() > 0 {
    let chars : Array[Char] = []
    for c in self.input_draft {
      chars.push(c)
    }
    let buf = StringBuilder()
    for i in 0..<(chars.length() - 1) {
      buf.write_char(chars[i])
    }
    self.input_draft = buf.to_string()
  }
}

///|
/// 回车提交：返回待写入 PTY 的整行（含换行）并清空草稿。
pub fn TerminalState::take_input(self : TerminalState) -> String? {
  if self.input_draft == "" {
    // 空行也是有效输入（shell 里回车 = 提示符换行）
    return Some("\n")
  }
  let line = self.input_draft
  self.input_draft = ""
  Some(line + "\n")
}

///|
/// 喂 PTY 输出（最小 VT 处理）：剥离 ANSI 转义（CSI `ESC[...字母` 与
/// OSC `ESC]...BEL/ESC\\`），`\r` 回到行首覆盖、`\b` 退格删除、`\n` 换行。
/// 这是「行缓冲屏」的保真度口径——光标定位序列（CUP 等）只被剥离不被
/// 执行（v1 诚实边界：TUI 程序显示为剥离后的文本行）。
pub fn TerminalState::feed_output(self : TerminalState, text : String) -> Unit {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let mut index = 0
  let count = chars.length()
  while index < count {
    let c = chars[index]
    if c == '\u{1b}' {
      // 转义序列：CSI（ESC [ ... 0x40-0x7E）或 OSC（ESC ] ... BEL/ST）
      index = skip_escape(chars, index)
      continue
    }
    if c == '\n' {
      // 行终止：开新行，列归零（当前行内容保留）
      self.screen.push("")
      self.col = 0
      index = index + 1
      continue
    }
    if c == '\r' {
      // 回车：只回列首（进度条覆盖由后续写入按列覆写完成）
      self.col = 0
      index = index + 1
      continue
    }
    if c == '\b' {
      // 退格：光标左移一格（内容在后续写入时被覆写）
      if self.col > 0 {
        self.col = self.col - 1
      }
      index = index + 1
      continue
    }
    if c == '\t' {
      // 制表：列进到 4 的倍数（空格由写入时补）
      self.col = (self.col / 4 + 1) * 4
      index = index + 1
      continue
    }
    // 可见字符：按列写入当前行（越列补空格、居中覆写）
    self.write_at_col(c)
    index = index + 1
  }
  // 屏上限：丢最旧行（与卡片 AI_CARD_LIMIT 同款纪律）
  while self.screen.length() > 1000 {
    ignore(self.screen.remove(0))
  }
}

///|
/// 剥离一个转义序列，返回序列之后的下标。CSI：ESC [ 参数字节(0x30-0x3F)
/// 中间字节(0x20-0x2F) 终止字节(0x40-0x7E)；OSC：ESC ] 到 BEL 或 ESC \。
fn skip_escape(chars : Array[Char], start : Int) -> Int {
  let count = chars.length()
  // start = ESC 本身的下标；kind 取 ESC 后一字节
  if start + 1 >= count {
    return count
  }
  let kind = chars[start + 1]
  let mut index = start + 2
  if kind == '[' {
    while index < count {
      let c = chars[index]
      if c >= '\u{40}' && c <= '\u{7e}' {
        return index + 1
      }
      index = index + 1
    }
    return index
  }
  if kind == ']' {
    while index < count {
      if chars[index] == '\u{7}' {
        return index + 1
      }
      if chars[index] == '\u{1b}' &&
        index + 1 < count &&
        chars[index + 1] == '\\' {
        return index + 2
      }
      index = index + 1
    }
    return index
  }
  // 其余单字符转义（ESC ( B 等）：再吃掉一个后续字节
  if index < count {
    index = index + 1
  }
  index
}

///|
/// 按列写一个可见字符：行不存在则建；列超行尾补空格；列在行中则覆写。
fn TerminalState::write_at_col(self : TerminalState, c : Char) -> Unit {
  if self.screen.length() == 0 {
    self.screen.push("")
  }
  let last = self.screen.length() - 1
  let chars : Array[Char] = []
  for ch in self.screen[last] {
    chars.push(ch)
  }
  while chars.length() < self.col {
    chars.push(' ')
  }
  if self.col < chars.length() {
    chars[self.col] = c
  } else {
    chars.push(c)
  }
  let buf = StringBuilder()
  for ch in chars {
    buf.write_char(ch)
  }
  self.screen[last] = buf.to_string()
  self.col = self.col + 1
}

///|
/// 会话终止（PTY 退出或页签关闭）：句柄清空，屏内容保留供回看。
pub fn TerminalState::session_closed(self : TerminalState) -> Unit {
  self.handle = None
}
