///|
/// 解析状态。
pub(all) enum ParseState {
  Ground
  Escape
  Csi
  Osc
  OscEscape
} derive(Eq, Debug)

///|
/// VT/ANSI 转义序列解析器(参考 xterm.js 状态机简化版)。
/// 输出直接作用到 TermScreen。
pub(all) struct VtParser {
  mut screen : TermScreen
  mut state : ParseState
  mut params : Array[Int]
  mut param_buf : String
  mut private_marker : Bool
  mut osc_buf : String
  mut utf8_buf : Array[Byte]
  mut utf8_need : Int
  mut ignore_next : Bool
}

///|
pub fn VtParser::new(screen : TermScreen) -> VtParser {
  {
    screen,
    state: ParseState::Ground,
    params: [],
    param_buf: "",
    private_marker: false,
    osc_buf: "",
    utf8_buf: [],
    utf8_need: 0,
    ignore_next: false,
  }
}

///|
pub fn VtParser::screen(self : VtParser) -> TermScreen {
  self.screen
}

///|
/// 喂入一段文本(可含转义序列)。
pub fn VtParser::feed(self : VtParser, s : String) -> Unit {
  self.feed_bytes(@utf8.encode(s))
}

///|
/// 喂入原始字节流(PTY 输出场景)。
pub fn VtParser::feed_bytes(self : VtParser, bytes : Bytes) -> Unit {
  for i in 0..<bytes.length() {
    self.advance(bytes[i])
  }
}

///|
fn VtParser::advance(self : VtParser, b : Byte) -> Unit {
  match self.state {
    ParseState::Ground => self.ground(b)
    ParseState::Escape => self.escape(b)
    ParseState::Csi => self.csi(b)
    ParseState::Osc => self.osc(b)
    ParseState::OscEscape =>
      if b.to_int() == 0x5C {
        self.osc_finish()
        self.state = ParseState::Ground
      } else {
        self.state = ParseState::Ground
      }
  }
}

///|
fn VtParser::ground(self : VtParser, b : Byte) -> Unit {
  if self.ignore_next {
    // 字符集选择等序列:消费一个后续字节
    self.ignore_next = false
    return
  }
  let v = b.to_int()
  if b.to_int() == 0x1B {
    // 丢弃未完成的 UTF-8 序列,避免与后续字节错误拼接
    self.discard_utf8()
    self.state = ParseState::Escape
  } else if v < 0x20 {
    // C0 控制字符;同样先丢弃未完成的 UTF-8 序列
    self.discard_utf8()
    match v {
      0x07 => () // BEL:忽略
      0x08 => self.screen.backspace()
      0x09 => self.screen.tab()
      0x0A | 0x0B | 0x0C => self.screen.linefeed()
      0x0D => self.screen.carriage_return()
      _ => ()
    }
  } else if v < 0x80 {
    // 可打印 ASCII
    self.screen.print_char(decode_utf8(Bytes::from_array([b])), 1)
  } else {
    // UTF-8 累积解码;序列中途收到新的首字节时,丢弃旧序列
    if !self.utf8_buf.is_empty() && utf8_seq_len(b) != 1 {
      self.discard_utf8()
    }
    self.utf8_push(b)
  }
}

///|
fn VtParser::discard_utf8(self : VtParser) -> Unit {
  if !self.utf8_buf.is_empty() {
    self.utf8_buf = []
    self.utf8_need = 0
  }
}

///|
/// UTF-8 首字节推断序列长度;非法首字节返回 1(调用方忽略)。
fn utf8_seq_len(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0xC2 && v <= 0xDF {
    2
  } else if v >= 0xE0 && v <= 0xEF {
    3
  } else if v >= 0xF0 && v <= 0xF4 {
    4
  } else {
    1
  }
}

///|
fn VtParser::utf8_push(self : VtParser, b : Byte) -> Unit {
  if self.utf8_buf.is_empty() {
    let need = utf8_seq_len(b)
    if need == 1 {
      // 非法首字节(孤立连续字节或超范围):忽略
      return
    }
    self.utf8_need = need
  }
  self.utf8_buf.push(b)
  if self.utf8_buf.length() == self.utf8_need {
    let ch = decode_utf8(Bytes::from_array(self.utf8_buf))
    self.utf8_buf = []
    self.utf8_need = 0
    if ch.length() > 0 {
      self.screen.print_char(ch, unicode_width(ch))
    }
  }
}

///|
fn VtParser::escape(self : VtParser, b : Byte) -> Unit {
  let v = b.to_int()
  match v {
    0x5B => {
      // '[' → CSI
      self.params = []
      self.param_buf = ""
      self.private_marker = false
      self.state = ParseState::Csi
    }
    0x5D => {
      // ']' → OSC
      self.osc_buf = ""
      self.state = ParseState::Osc
    }
    0x37 => self.screen.save_cursor() // ESC 7
    0x38 => self.screen.restore_cursor() // ESC 8
    0x63 => self.screen.reset() // ESC c RIS
    0x44 => self.screen.linefeed() // ESC D IND
    0x45 => {
      // ESC E NEL
      self.screen.carriage_return()
      self.screen.linefeed()
    }
    0x4D => self.screen.reverse_index() // ESC M RI
    0x3D | 0x3E => () // 键盘模式,忽略
    0x28 | 0x29 | 0x2A | 0x2B => self.ignore_next = true // 字符集选择:消费下一字节
    _ => ()
  }
  if v != 0x5B && v != 0x5D {
    self.state = ParseState::Ground
  }
}

///|
fn VtParser::push_param(self : VtParser) -> Unit {
  let p = if self.param_buf.is_empty() {
    0
  } else {
    parse_decimal(self.param_buf)
  }
  if self.params.length() < 64 {
    self.params.push(p)
  }
  self.param_buf = ""
}

///|
fn VtParser::param0(self : VtParser, default : Int) -> Int {
  if self.params.length() > 0 {
    let v = self.params[0]
    if v == 0 {
      default
    } else {
      v
    }
  } else {
    default
  }
}

///|
fn VtParser::csi(self : VtParser, b : Byte) -> Unit {
  let v = b.to_int()
  if v >= 0x30 && v <= 0x39 {
    // 数字参数(限长,防无界累积)
    if self.param_buf.length() < 32 {
      self.param_buf = self.param_buf + decode_utf8(Bytes::from_array([b]))
    }
  } else if b.to_int() == 0x3B {
    self.push_param()
  } else if b.to_int() == 0x3F {
    self.private_marker = true
  } else if v >= 0x40 && v <= 0x7E {
    // 最终字节
    self.push_param()
    self.dispatch(v)
    self.state = ParseState::Ground
    // 中间字节或非法字节:忽略
  } else if b.to_int() == 0x1B {
    self.state = ParseState::Escape
  } else {
    self.state = ParseState::Ground
  }
}

///|
fn VtParser::dispatch(self : VtParser, final_byte : Int) -> Unit {
  let s = self.screen
  match final_byte {
    0x41 => s.cursor_up(self.param0(1)) // A
    0x42 => s.cursor_down(self.param0(1)) // B
    0x43 => s.cursor_right(self.param0(1)) // C
    0x44 => s.cursor_left(self.param0(1)) // D
    0x45 => {
      // E CNL:下移 n 行到行首
      s.cursor_down(self.param0(1))
      s.carriage_return()
    }
    0x46 => {
      // F CPL:上移 n 行到行首
      s.cursor_up(self.param0(1))
      s.carriage_return()
    }
    0x47 => s.cursor_column(self.param0(1)) // G
    0x48 | 0x66 => {
      // H / f
      let row = self.param0(1)
      let col = if self.params.length() > 1 { self.params[1] } else { 1 }
      s.cursor_position(row, col)
    }
    0x64 => s.cursor_line(self.param0(1)) // d VPA
    0x4A => s.erase_in_display(self.param0(0)) // J
    0x4B => s.erase_in_line(self.param0(0)) // K
    0x4C => s.insert_lines(self.param0(1)) // L
    0x4D => s.delete_lines(self.param0(1)) // M
    0x50 => s.delete_chars(self.param0(1)) // P
    0x40 => s.insert_chars(self.param0(1)) // @
    0x58 => s.erase_chars(self.param0(1)) // X
    0x53 => s.scroll_up(self.param0(1)) // S
    0x54 => s.scroll_down(self.param0(1)) // T
    0x72 => {
      // r 设置滚动区域
      let top = self.param0(1)
      let bottom = if self.params.length() > 1 {
        let v = self.params[1]
        if v == 0 {
          s.rows()
        } else {
          v
        }
      } else {
        s.rows()
      }
      s.set_scroll_region(top, bottom)
    }
    0x6D => self.sgr() // m
    0x68 | 0x6C =>
      // h / l 模式设置
      if self.private_marker {
        let p = self.param0(0)
        if p == 7 {
          s.auto_wrap = final_byte == 0x68
        } else if p == 25 {
          s.set_cursor_visible(final_byte == 0x68)
        }
      }
    0x73 => s.save_cursor() // s
    0x75 => s.restore_cursor() // u
    0x63 | 0x6E => () // DA / DSR:忽略
    _ => ()
  }
}

///|
/// SGR:设置/重置属性。
fn VtParser::sgr(self : VtParser) -> Unit {
  let s = self.screen
  let mut attrs = s.current_attrs()
  let mut i = 0
  while i < self.params.length() {
    let p = self.params[i]
    match p {
      0 => attrs = CellAttrs::default()
      1 => attrs = attrs_with(attrs, bold=Some(true))
      2 => attrs = attrs_with(attrs, dim=Some(true))
      3 => attrs = attrs_with(attrs, italic=Some(true))
      4 => attrs = attrs_with(attrs, underline=Some(true))
      7 => attrs = attrs_with(attrs, reverse=Some(true))
      21 | 22 => attrs = attrs_with(attrs, bold=Some(false), dim=Some(false))
      23 => attrs = attrs_with(attrs, italic=Some(false))
      24 => attrs = attrs_with(attrs, underline=Some(false))
      27 => attrs = attrs_with(attrs, reverse=Some(false))
      30..=37 => attrs = attrs_with(attrs, fg=Some(TermColor::Indexed(p - 30)))
      38 =>
        if i + 1 < self.params.length() &&
          self.params[i + 1] == 5 &&
          i + 2 < self.params.length() {
          attrs = attrs_with(
            attrs,
            fg=Some(TermColor::Indexed(self.params[i + 2])),
          )
          i = i + 2
        } else if i + 1 < self.params.length() &&
          self.params[i + 1] == 2 &&
          i + 4 < self.params.length() {
          attrs = attrs_with(
            attrs,
            fg=Some(
              TermColor::Rgb(
                self.params[i + 2],
                self.params[i + 3],
                self.params[i + 4],
              ),
            ),
          )
          i = i + 4
        }
      39 => attrs = attrs_with(attrs, fg=Some(TermColor::Default))
      40..=47 => attrs = attrs_with(attrs, bg=Some(TermColor::Indexed(p - 40)))
      48 =>
        if i + 1 < self.params.length() &&
          self.params[i + 1] == 5 &&
          i + 2 < self.params.length() {
          attrs = attrs_with(
            attrs,
            bg=Some(TermColor::Indexed(self.params[i + 2])),
          )
          i = i + 2
        } else if i + 1 < self.params.length() &&
          self.params[i + 1] == 2 &&
          i + 4 < self.params.length() {
          attrs = attrs_with(
            attrs,
            bg=Some(
              TermColor::Rgb(
                self.params[i + 2],
                self.params[i + 3],
                self.params[i + 4],
              ),
            ),
          )
          i = i + 4
        }
      49 => attrs = attrs_with(attrs, bg=Some(TermColor::Default))
      90..=97 =>
        attrs = attrs_with(attrs, fg=Some(TermColor::Indexed(p - 90 + 8)))
      100..=107 =>
        attrs = attrs_with(attrs, bg=Some(TermColor::Indexed(p - 100 + 8)))
      _ => ()
    }
    i = i + 1
  }
  s.set_current_attrs(attrs)
}

///|
fn VtParser::osc(self : VtParser, b : Byte) -> Unit {
  if b.to_int() == 0x07 {
    // BEL 结束 OSC
    self.osc_finish()
    self.state = ParseState::Ground
  } else if b.to_int() == 0x1B {
    self.state = ParseState::OscEscape
    // OSC 文本限长,防无界累积
  } else if self.osc_buf.length() < 8192 {
    self.osc_buf = self.osc_buf + decode_utf8(Bytes::from_array([b]))
  }
}

///|
fn VtParser::osc_finish(self : VtParser) -> Unit {
  let s = self.osc_buf
  let parts = s.split(";").to_array()
  if parts.length() >= 2 && (parts[0] == "0" || parts[0] == "2") {
    // 标题可能包含分号:重新拼接
    let mut title = parts[1].to_owned()
    for i in 2..<parts.length() {
      title = title + ";" + parts[i].to_owned()
    }
    self.screen.set_title(title)
  }
  self.osc_buf = ""
}

///|
/// Bytes → UTF-8 字符串(无效字节替换为 U+FFFD,不抛错)。
fn decode_utf8(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes.view())
}

///|
/// 解析十进制字符串为 Int(非法字符处截断;饱和防溢出与超长参数)。
fn parse_decimal(s : String) -> Int {
  let mut n = 0
  for i in 0..<s.length() {
    let d = s[i].to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return n
    }
    if n > 1000000 {
      // 饱和:远超屏幕尺寸的参数在调用侧会被 clamp_count 收敛
      return n
    }
    n = n * 10 + d
  }
  n
}

///|
/// 提取字符串首字符的 Unicode 码点(String::at 返回 UTF-16 code unit)。
fn utf8_codepoint(s : String) -> Int {
  let u = s[0].to_int()
  if u >= 0xD800 && u <= 0xDBFF && s.length() >= 2 {
    let lo = s[1].to_int()
    0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
  } else {
    u
  }
}

///|
/// 简化 wcwidth:ASCII 1,常见宽字符区间 2,其余 1。
pub fn unicode_width(ch : String) -> Int {
  let cp = utf8_codepoint(ch)
  if cp >= 0x20 && cp <= 0x7E {
    return 1
  }
  if (cp >= 0x1100 && cp <= 0x115F) ||
    (cp >= 0x2E80 && cp <= 0xA4CF) ||
    (cp >= 0xAC00 && cp <= 0xD7A3) ||
    (cp >= 0xF900 && cp <= 0xFAFF) ||
    (cp >= 0xFE30 && cp <= 0xFE4F) ||
    (cp >= 0xFF00 && cp <= 0xFF60) ||
    (cp >= 0xFFE0 && cp <= 0xFFE6) ||
    (cp >= 0x1F300 && cp <= 0x1FAFF) ||
    (cp >= 0x20000 && cp <= 0x3FFFD) {
    return 2
  }
  1
}
