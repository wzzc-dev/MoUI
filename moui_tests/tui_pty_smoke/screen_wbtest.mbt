///|
/// 终端字节流 → cell 栅格的独立反解器(只服务 PTY 冒烟)。
///
/// 它刻意不复用 `moui_tui` 的编码器:冒烟要证明的是「真终端里的人看到什么」,
/// 用自己重放同一串 ANSI 的模型才是独立证据。编码器一旦改协议,这里必须同步改,
/// 那正是这道门想要的红。
///
/// 字符串处理全部手写(扫描字符、逐位累计整数):这一层每多依赖一个核心库 API,
/// 就多一处会因为标准库演进而不是因为终端行为变化而红的可能。
priv struct Style {
  mut bold : Bool
  mut dim : Bool
  mut italic : Bool
  mut underline : Bool
  mut reverse : Bool
  mut fg : String
  mut bg : String
}

///|
fn plain() -> Style {
  {
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    reverse: false,
    fg: "",
    bg: "",
  }
}

///|
/// 每个格存一份属性快照:后续 SGR 变化不能追溯改写已经落笔的格。
fn snapshot(style : Style) -> Style {
  let copy = plain()
  copy.bold = style.bold
  copy.dim = style.dim
  copy.italic = style.italic
  copy.underline = style.underline
  copy.reverse = style.reverse
  copy.fg = style.fg
  copy.bg = style.bg
  copy
}

///|
priv struct Cell {
  ch : Char
  style : Style
}

///|
fn blank_cell() -> Cell {
  { ch: ' ', style: plain(), }
}

///|
/// 固定尺寸的反解栅格。尺寸取会话开始时的行列:缩小窗口后再放大时,
/// 「有没有残影」要看的是超出当前行列的区域是否真的空了,所以模型不能跟着缩。
priv struct Screen {
  cols : Int32
  rows : Int32
  cells : Array[Cell]
  mut row : Int32
  mut col : Int32
  mut style : Style
  /// `ESC[2J` 次数:一次全屏重建。缩小窗口不重建就会留残影。
  mut rebuilds : Int32
  /// 最近一次全屏重建之后被逐行定位写过的行。
  painted : Array[Bool]
  /// `ESC[<row>;<col>H` 总数:增量通路的工作量。
  mut locates : Int32
}

///|
fn screen_new(cols : Int32, rows : Int32) -> Screen {
  {
    cols,
    rows,
    cells: Array::make(cols * rows, blank_cell()),
    row: 0,
    col: 0,
    style: plain(),
    rebuilds: 0,
    painted: Array::make(rows, false),
    locates: 0,
  }
}

///|
/// 双宽字形。表意文字与全角标点占两格,和编码器的 `char_width` 同一套判据;
/// 两条通路各自独立声明它,所以编码器改了判据而这里没跟上时,错位会立刻变红。
fn char_is_wide(ch : Char) -> Bool {
  let c = ch.to_int()
  (c >= 0x1100 && c <= 0x115f) ||
  (c >= 0x2e80 && c <= 0xa4cf) ||
  (c >= 0xac00 && c <= 0xd7a3) ||
  (c >= 0xf900 && c <= 0xfaff) ||
  (c >= 0xfe30 && c <= 0xfe6f) ||
  (c >= 0xff00 && c <= 0xff60) ||
  (c >= 0xffe0 && c <= 0xffe6) ||
  (c >= 0x20000 && c <= 0x3fffd)
}

///|
fn digit_value(ch : Char) -> Int32? {
  let c = ch.to_int()
  if c >= 0x30 && c <= 0x39 {
    Some(c - 0x30)
  } else {
    None
  }
}

///|
/// 逐位累计一个非负整数,返回消费的下标。SGR 参数与状态行里的数字都走这条,
/// 所以整个反解器没有一次 String→Int 转换。
fn scan_int(chars : Array[Char], start : Int32) -> (Int32, Int32) {
  let mut i = start
  let mut value = 0
  while i < chars.length() {
    match digit_value(chars[i]) {
      Some(digit) => {
        value = value * 10 + digit
        i = i + 1
      }
      None => return (value, i)
    }
  }
  (value, i)
}

///|
/// 按 `;` 拆参数串。空串算一个 `0`:编码器发 `ESC[0m` 复位,也允许省参数。
fn split_params(params : String) -> Array[String] {
  if params == "" {
    return ["0"]
  }
  let out : Array[String] = []
  let mut current = ""
  for ch in params.to_array() {
    if ch == ';' {
      out.push(current)
      current = ""
    } else {
      current = current + ch.to_string()
    }
  }
  out.push(current)
  out
}

///|
fn Screen::at(self : Screen, row : Int32, col : Int32) -> Cell {
  self.cells[row * self.cols + col]
}

///|
fn Screen::put_cell(
  self : Screen,
  row : Int32,
  col : Int32,
  cell : Cell,
) -> Unit {
  if row >= 0 && row < self.rows && col >= 0 && col < self.cols {
    self.cells[row * self.cols + col] = cell
  }
}

///|
fn Screen::put(self : Screen, ch : Char) -> Unit {
  let wide = if char_is_wide(ch) { 2 } else { 1 }
  self.put_cell(self.row, self.col, { ch, style: snapshot(self.style), })
  if wide == 2 {
    // 宽字符右半格被编码器跳过(不再输出一个字符),模型也必须跳一格,
    // 否则后面的文字整体错位。
    self.put_cell(self.row, self.col + 1, blank_cell())
  }
  self.col = self.col + wide
}

///|
fn Screen::erase_line(self : Screen) -> Unit {
  for c in 0..<self.cols {
    self.put_cell(self.row, c, blank_cell())
  }
}

///|
fn Screen::clear(self : Screen) -> Unit {
  for i in 0..<self.cells.length() {
    self.cells[i] = blank_cell()
  }
  for i in 0..<self.painted.length() {
    self.painted[i] = false
  }
  self.row = 0
  self.col = 0
  self.rebuilds = self.rebuilds + 1
}

///|
fn Screen::move_to(self : Screen, row : Int32, col : Int32) -> Unit {
  self.row = row
  self.col = col
  if row >= 0 && row < self.rows {
    self.painted[row] = true
  }
  self.locates = self.locates + 1
}

///|
/// 一条 SGR 参数串 → 当前笔属性。`ESC[0;1;4;38;5;3m` 以 0 开头,
/// 所以先复位再叠加,和编码器一致。
fn Screen::sgr(self : Screen, params : String) -> Unit {
  let tokens = split_params(params)
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    if token == "" || token == "0" {
      self.style = plain()
    } else if token == "1" {
      self.style.bold = true
    } else if token == "2" {
      self.style.dim = true
    } else if token == "3" {
      self.style.italic = true
    } else if token == "4" {
      self.style.underline = true
    } else if token == "7" {
      self.style.reverse = true
    } else if token == "39" {
      self.style.fg = ""
    } else if token == "49" {
      self.style.bg = ""
    } else if token == "38" || token == "48" {
      let kind = if i + 1 < tokens.length() { tokens[i + 1] } else { "" }
      if kind == "5" && i + 2 < tokens.length() {
        let value = "idx:" + tokens[i + 2]
        if token == "38" {
          self.style.fg = value
        } else {
          self.style.bg = value
        }
        i = i + 2
      } else if kind == "2" && i + 4 < tokens.length() {
        let value = "rgb:" +
          tokens[i + 2] +
          ";" +
          tokens[i + 3] +
          ";" +
          tokens[i + 4]
        if token == "38" {
          self.style.fg = value
        } else {
          self.style.bg = value
        }
        i = i + 4
      }
    }
    i = i + 1
  }
}

///|
/// `ESC[<row>;<col>H` 的参数是 1 基,缺省都当 1。
fn parse_position(params : String) -> (Int32, Int32) {
  let chars = params.to_array()
  let (row, after) = scan_int(chars, 0)
  let col = if after < chars.length() && chars[after] == ';' {
    let (value, _) = scan_int(chars, after + 1)
    value
  } else {
    0
  }
  ((row - 1).max(0), (col - 1).max(0))
}

///|
/// 吃掉一个转义序列,返回它的最后一个下标(调用方再 +1)。
/// 只认渲染器与宿主真会发的形态:CSI 私有模式(`h`/`l`)、kitty(`u`)忽略,
/// `H`/`f` 定位、`J` 清屏、`K` 清行、`m` 属性。
fn Screen::escape(self : Screen, chars : Array[Char], start : Int32) -> Int32 {
  if start >= chars.length() {
    return start
  }
  if chars[start] != '[' {
    return start
  }
  let mut i = start + 1
  let mut params = ""
  while i < chars.length() {
    let c = chars[i].to_int()
    if c < 0x30 || c > 0x3f {
      break
    }
    params = params + chars[i].to_string()
    i = i + 1
  }
  if i >= chars.length() {
    return i - 1
  }
  let terminator = chars[i]
  if params.has_prefix("?") {
    // 大多数私有模式(`?25l` 藏光标、`?1000h` 开鼠标追踪)只改终端行为,不改栅格。
    // 1049 是例外:它切到备用屏的同时把备用屏清空,所以这一格之后终端上没有任何
    // 旧内容可依赖。渲染器刻意不在首帧发 `ESC[2J`(备用屏已经是空的),反解器
    // 不把 1049h 当空白起点,就会把「第一帧」数成 0 次重建。
    if terminator == 'h' || terminator == 'l' {
      if params == "?1049" {
        self.clear()
      }
    }
  } else if terminator == 'H' || terminator == 'f' {
    let (row, col) = parse_position(params)
    self.move_to(row, col)
  } else if terminator == 'J' {
    if params == "2" || params == "" {
      self.clear()
    }
  } else if terminator == 'K' {
    self.erase_line()
  } else if terminator == 'm' {
    self.sgr(params)
  }
  i
}

///|
/// 反解一段已解码文本。整段重放(而不是增量维护)是刻意的:
/// 分块边界把多字节字符切开时不必再猜半字符的状态。
fn Screen::feed(self : Screen, text : String) -> Unit {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\u{1b}' {
      i = self.escape(chars, i + 1)
    } else if ch == '\r' {
      self.col = 0
    } else if ch == '\n' {
      self.row = if self.row + 1 < self.rows {
        self.row + 1
      } else {
        self.rows - 1
      }
    } else if ch.to_int() >= 0x20 {
      self.put(ch)
    }
    i = i + 1
  }
}

///|
fn Screen::line_text(self : Screen, row : Int32) -> String {
  if row < 0 || row >= self.rows {
    return ""
  }
  let mut last = -1
  for c in 0..<self.cols {
    if self.at(row, c).ch != ' ' {
      last = c
    }
  }
  if last < 0 {
    return ""
  }
  let mut out = ""
  for c in 0..<=last {
    out = out + self.at(row, c).ch.to_string()
  }
  out
}

///|
fn Screen::text(self : Screen) -> String {
  let lines : Array[String] = []
  for r in 0..<self.rows {
    lines.push(self.line_text(r))
  }
  lines.join("\n")
}

///|
fn Screen::has(self : Screen, needle : String) -> Bool {
  self.find_row(needle) is Some(_)
}

///|
fn Screen::find_row(self : Screen, needle : String) -> Int32? {
  for r in 0..<self.rows {
    if self.line_text(r).contains(needle) {
      return Some(r)
    }
  }
  None
}

///|
fn Screen::styled_count(self : Screen, matches : (Style) -> Bool) -> Int32 {
  let mut count = 0
  for cell in self.cells {
    if matches(cell.style) {
      count = count + 1
    }
  }
  count
}

///|
/// 全屏重建之后被写过的行数。缩小窗口时它必须等于新行数,
/// 放大回来时必须等于总行数,否则就有从没被覆盖的旧格。
fn Screen::painted_count(self : Screen) -> Int32 {
  let mut count = 0
  for flag in self.painted {
    if flag {
      count = count + 1
    }
  }
  count
}

///|
/// 第 `row` 行是否在重建之后一个字节都没写过(残影的唯一来源)。
fn Screen::row_untouched(self : Screen, row : Int32) -> Bool {
  row < self.painted.length() && !self.painted[row]
}

///|
/// 手写 `search`:反解器不依赖核心库的字符串查找,少一处会变的依赖。
fn index_of(hay : Array[Char], pat : Array[Char]) -> Int32? {
  if pat.length() == 0 || pat.length() > hay.length() {
    None
  } else {
    let mut i = 0
    while i + pat.length() <= hay.length() {
      let mut j = 0
      while j < pat.length() && hay[i + j] == pat[j] {
        j = j + 1
      }
      if j == pat.length() {
        return Some(i)
      }
      i = i + 1
    }
    None
  }
}

///|
/// 第一处含 `needle` 的文本里,`needle` 之后的第一个整数(允许负号)。
/// demo 的状态行 `sel=` / `list=` / `tree=` 与 `Entries N` / `Files N`
/// 就是给断言用的可读目标,不需要去数字符格。
fn Screen::int_after(self : Screen, needle : String) -> Int32? {
  match self.find_row(needle) {
    None => None
    Some(row) => {
      let chars = self.line_text(row).to_array()
      match index_of(chars, needle.to_array()) {
        None => None
        Some(at) => {
          let mut i = at + needle.to_array().length()
          while i < chars.length() &&
                !(chars[i] == '-' || digit_value(chars[i]) is Some(_)) {
            i = i + 1
          }
          let negative = i < chars.length() && chars[i] == '-'
          if negative {
            i = i + 1
          }
          let (value, after) = scan_int(chars, i)
          if after == i {
            None
          } else {
            Some(if negative { -value } else { value })
          }
        }
      }
    }
  }
}

///|
/// 状态行里的一个整数,拿不到就是冒烟自己的问题(状态行没了),直接红。
fn Screen::int_or_fail(self : Screen, needle : String) -> Int32 {
  match self.int_after(needle) {
    Some(value) => value
    None => {
      println("status text for '\{needle}' is not on the grid")
      abort("TUI PTY smoke cannot read the app status line")
    }
  }
}
