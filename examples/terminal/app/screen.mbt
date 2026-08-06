///|
/// 终端颜色:默认色、256 索引色、真彩色 RGB。
pub(all) enum TermColor {
  Default
  Indexed(Int)
  Rgb(Int, Int, Int)
} derive(Eq, Debug)

///|
/// 单元格属性(SGR 状态)。
pub(all) struct CellAttrs {
  fg : TermColor
  bg : TermColor
  bold : Bool
  dim : Bool
  italic : Bool
  underline : Bool
  reverse : Bool
} derive(Eq, Debug)

///|
pub fn CellAttrs::default() -> CellAttrs {
  {
    fg: TermColor::Default,
    bg: TermColor::Default,
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    reverse: false,
  }
}

///|
/// 复制属性并替换部分字段(解析器 SGR 用)。
pub fn attrs_with(
  attrs : CellAttrs,
  fg? : TermColor? = None,
  bg? : TermColor? = None,
  bold? : Bool? = None,
  dim? : Bool? = None,
  italic? : Bool? = None,
  underline? : Bool? = None,
  reverse? : Bool? = None,
) -> CellAttrs {
  {
    fg: match fg {
      Some(v) => v
      None => attrs.fg
    },
    bg: match bg {
      Some(v) => v
      None => attrs.bg
    },
    bold: match bold {
      Some(v) => v
      None => attrs.bold
    },
    dim: match dim {
      Some(v) => v
      None => attrs.dim
    },
    italic: match italic {
      Some(v) => v
      None => attrs.italic
    },
    underline: match underline {
      Some(v) => v
      None => attrs.underline
    },
    reverse: match reverse {
      Some(v) => v
      None => attrs.reverse
    },
  }
}

///|
/// 复制属性并替换前景色(测试与解析器辅助)。
pub fn attrs_with_fg(attrs : CellAttrs, fg : TermColor) -> CellAttrs {
  attrs_with(attrs, fg=Some(fg))
}

///|
/// 单元格:一个字符(宽字符占两格,第二格为 continuation,ch 为空)。
pub(all) struct Cell {
  ch : String
  width : Int
  attrs : CellAttrs
} derive(Eq, Debug)

///|
pub fn blank_cell(attrs : CellAttrs) -> Cell {
  { ch: " ", width: 1, attrs }
}

///|
/// 屏幕上一行。
pub(all) struct TermRow {
  mut cells : Array[Cell]
}

///|
pub fn TermRow::new(cols : Int, attrs : CellAttrs) -> TermRow {
  let cells : Array[Cell] = []
  for _ in 0..<cols {
    cells.push(blank_cell(attrs))
  }
  { cells, }
}

///|
/// 行内按连续相同属性合并的渲染 run:(文本, 占列数, 属性)。
/// continuation 单元格(width == 0)不产生文本。
pub fn TermRow::runs(self : TermRow) -> Array[(String, Int, CellAttrs)] {
  let out : Array[(String, Int, CellAttrs)] = []
  let mut current_attrs : CellAttrs? = None
  let mut width_sum = 0
  for cell in self.cells {
    if cell.width == 0 {
      continue
    }
    let merged = match current_attrs {
      Some(attrs) => attrs == cell.attrs
      None => false
    }
    if merged {
      let last = out.length() - 1
      out[last] = (out[last].0 + cell.ch, out[last].1 + cell.width, cell.attrs)
      width_sum = width_sum + cell.width
    } else {
      out.push((cell.ch, cell.width, cell.attrs))
      current_attrs = Some(cell.attrs)
      width_sum = cell.width
    }
  }
  // 裁剪尾部无背景 run 的空格后缀(渲染无意义)
  if out.length() > 0 {
    let (tail, tail_width, tail_attrs) = out[out.length() - 1]
    if tail_attrs.bg == TermColor::Default {
      let trimmed = trim_trailing_spaces(tail)
      if trimmed.length() == 0 {
        ignore(out.pop())
      } else if trimmed.length() != tail.length() {
        let w = tail_width - (tail.length() - trimmed.length())
        out[out.length() - 1] = (trimmed, w, tail_attrs)
      }
    }
  }
  out
}

///|
/// 去掉字符串尾部空格(终端行文本用)。
fn trim_trailing_spaces(s : String) -> String {
  let mut end = s.length()
  while end > 0 && s[end - 1] == ' ' {
    end = end - 1
  }
  if end == s.length() {
    s
  } else {
    s[0:end].to_owned()
  }
}

///|
/// 行文本(去掉尾部空白),供测试与标题提取使用。
pub fn TermRow::text(self : TermRow) -> String {
  let mut s = ""
  for cell in self.cells {
    if cell.width == 0 {
      continue
    }
    s = s + cell.ch
  }
  trim_trailing_spaces(s)
}

///|
/// 终端屏幕模型:可视区 + 回看缓冲 + 光标 + 滚动区域。
pub(all) struct TermScreen {
  mut cols : Int
  mut rows : Int
  mut screen : Array[TermRow]
  mut scrollback : Array[TermRow]
  mut scrollback_limit : Int
  mut cursor_row : Int
  mut cursor_col : Int
  mut scroll_top : Int
  mut scroll_bottom : Int
  mut saved_cursor_row : Int
  mut saved_cursor_col : Int
  mut wrap_pending : Bool
  mut auto_wrap : Bool
  mut cursor_visible : Bool
  mut title : String
  mut attrs : CellAttrs
}

///|
pub fn TermScreen::new(cols : Int, rows : Int) -> TermScreen {
  let attrs = CellAttrs::default()
  let screen : Array[TermRow] = []
  for _ in 0..<rows {
    screen.push(TermRow::new(cols, attrs))
  }
  {
    cols,
    rows,
    screen,
    scrollback: [],
    scrollback_limit: 1000,
    cursor_row: 0,
    cursor_col: 0,
    scroll_top: 0,
    scroll_bottom: rows - 1,
    saved_cursor_row: 0,
    saved_cursor_col: 0,
    wrap_pending: false,
    auto_wrap: true,
    cursor_visible: true,
    title: "",
    attrs,
  }
}

///|
pub fn TermScreen::cols(self : TermScreen) -> Int {
  self.cols
}

///|
pub fn TermScreen::rows(self : TermScreen) -> Int {
  self.rows
}

///|
pub fn TermScreen::cursor_row(self : TermScreen) -> Int {
  self.cursor_row
}

///|
pub fn TermScreen::cursor_col(self : TermScreen) -> Int {
  self.cursor_col
}

///|
pub fn TermScreen::title(self : TermScreen) -> String {
  self.title
}

///|
pub fn TermScreen::current_attrs(self : TermScreen) -> CellAttrs {
  self.attrs
}

///|
pub fn TermScreen::cursor_visible(self : TermScreen) -> Bool {
  self.cursor_visible
}

///|
pub fn TermScreen::set_cursor_visible(self : TermScreen, v : Bool) -> Unit {
  self.cursor_visible = v
}

///|
/// 回看行数 + 可视行数。
pub fn TermScreen::total_lines(self : TermScreen) -> Int {
  self.scrollback.length() + self.rows
}

///|
/// 取第 idx 行(0 = 最早的回看行;total_lines - rows 起为可视区)。
pub fn TermScreen::line_at(self : TermScreen, idx : Int) -> TermRow {
  let sb = self.scrollback.length()
  if idx < sb {
    self.scrollback[idx]
  } else {
    self.screen[idx - sb]
  }
}

///|
pub fn TermScreen::set_scrollback_limit(self : TermScreen, limit : Int) -> Unit {
  self.scrollback_limit = limit
  while self.scrollback.length() > limit {
    ignore(self.scrollback.pop())
  }
}

///|
pub fn TermScreen::set_current_attrs(
  self : TermScreen,
  attrs : CellAttrs,
) -> Unit {
  self.attrs = attrs
}

///|
/// 重置到初始状态(保留尺寸)。
pub fn TermScreen::reset(self : TermScreen) -> Unit {
  self.clear_all()
  self.cursor_row = 0
  self.cursor_col = 0
  self.scroll_top = 0
  self.scroll_bottom = self.rows - 1
  self.saved_cursor_row = 0
  self.saved_cursor_col = 0
  self.wrap_pending = false
  self.auto_wrap = true
  self.cursor_visible = true
  self.attrs = CellAttrs::default()
  self.title = ""
}

///|
/// 清空屏幕与回看缓冲。
pub fn TermScreen::clear_all(self : TermScreen) -> Unit {
  for i in 0..<self.rows {
    self.screen[i] = TermRow::new(self.cols, self.attrs)
  }
  self.scrollback = []
}

///|
fn TermScreen::blank_row(self : TermScreen) -> TermRow {
  TermRow::new(self.cols, self.attrs)
}

///|
fn TermScreen::push_scrollback(self : TermScreen, row : TermRow) -> Unit {
  self.scrollback.push(row)
  while self.scrollback.length() > self.scrollback_limit {
    ignore(self.scrollback.remove(0))
  }
}

///|
fn TermScreen::prepend_scrollback(self : TermScreen, row : TermRow) -> Unit {
  self.scrollback.insert(0, row)
  while self.scrollback.length() > self.scrollback_limit {
    ignore(self.scrollback.pop())
  }
}

///|
/// 光标处写入字符;处理自动换行与宽字符。
pub fn TermScreen::print_char(
  self : TermScreen,
  ch : String,
  width : Int,
) -> Unit {
  if self.wrap_pending && self.auto_wrap {
    self.carriage_return()
    self.linefeed()
  }
  self.wrap_pending = false
  if width == 2 && self.cursor_col >= self.cols - 1 {
    // 宽字符放不下最后一格:丢弃(与 xterm 一致)
    return
  }
  self.screen[self.cursor_row].cells[self.cursor_col] = {
    ch,
    width,
    attrs: self.attrs,
  }
  if width == 2 {
    self.screen[self.cursor_row].cells[self.cursor_col + 1] = {
      ch: "",
      width: 0,
      attrs: self.attrs,
    }
  }
  if self.cursor_col + width >= self.cols {
    if self.auto_wrap {
      self.wrap_pending = true
    }
  } else {
    self.cursor_col = self.cursor_col + width
  }
}

///|
/// LF / VT / FF / IND:光标下移,在滚动区域底部时向上滚动。
pub fn TermScreen::linefeed(self : TermScreen) -> Unit {
  self.wrap_pending = false
  if self.cursor_row == self.scroll_bottom {
    self.scroll_up(1)
  } else if self.cursor_row < self.rows - 1 {
    self.cursor_row = self.cursor_row + 1
  }
}

///|
/// RI:光标上移,在滚动区域顶部时向下滚动。
pub fn TermScreen::reverse_index(self : TermScreen) -> Unit {
  self.wrap_pending = false
  if self.cursor_row == self.scroll_top {
    self.scroll_down(1)
  } else if self.cursor_row > 0 {
    self.cursor_row = self.cursor_row - 1
  }
}

///|
pub fn TermScreen::carriage_return(self : TermScreen) -> Unit {
  self.cursor_col = 0
  self.wrap_pending = false
}

///|
pub fn TermScreen::backspace(self : TermScreen) -> Unit {
  self.wrap_pending = false
  if self.cursor_col > 0 {
    self.cursor_col = self.cursor_col - 1
  }
}

///|
pub fn TermScreen::tab(self : TermScreen) -> Unit {
  self.wrap_pending = false
  let next = (self.cursor_col / 8 + 1) * 8
  self.cursor_col = if next < self.cols { next } else { self.cols - 1 }
}

///|
fn TermScreen::clamp_cursor(self : TermScreen) -> Unit {
  if self.cursor_col >= self.cols {
    self.cursor_col = self.cols - 1
  }
  if self.cursor_row >= self.rows {
    self.cursor_row = self.rows - 1
  }
  if self.cursor_col < 0 {
    self.cursor_col = 0
  }
  if self.cursor_row < 0 {
    self.cursor_row = 0
  }
}

///|
/// 把计数参数限制在 [0, limit](防溢出负值与超大值)。
fn clamp_count(n : Int, limit : Int) -> Int {
  if n <= 0 {
    0
  } else if n > limit {
    limit
  } else {
    n
  }
}

///|
/// 光标上移 n 行(不越过滚动区域顶部)。
pub fn TermScreen::cursor_up(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let n = clamp_count(n, self.rows)
  let target = self.cursor_row - n
  self.cursor_row = if target < self.scroll_top {
    self.scroll_top
  } else {
    target
  }
}

///|
/// 光标下移 n 行(不越过滚动区域底部)。
pub fn TermScreen::cursor_down(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let n = clamp_count(n, self.rows)
  let target = self.cursor_row + n
  self.cursor_row = if target > self.scroll_bottom {
    self.scroll_bottom
  } else {
    target
  }
}

///|
pub fn TermScreen::cursor_right(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let n = clamp_count(n, self.cols)
  let target = self.cursor_col + n
  self.cursor_col = if target >= self.cols { self.cols - 1 } else { target }
}

///|
pub fn TermScreen::cursor_left(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let n = clamp_count(n, self.cols)
  let target = self.cursor_col - n
  self.cursor_col = if target < 0 { 0 } else { target }
}

///|
/// 光标定位(row/col 均为 1-based)。
pub fn TermScreen::cursor_position(
  self : TermScreen,
  row : Int,
  col : Int,
) -> Unit {
  self.wrap_pending = false
  let r = if row < 1 { 1 } else { row }
  let c = if col < 1 { 1 } else { col }
  self.cursor_row = if r > self.rows { self.rows - 1 } else { r - 1 }
  self.cursor_col = if c > self.cols { self.cols - 1 } else { c - 1 }
}

///|
/// 光标行定位(1-based)。
pub fn TermScreen::cursor_line(self : TermScreen, row : Int) -> Unit {
  self.cursor_position(row, self.cursor_col + 1)
}

///|
/// 光标列定位(1-based)。
pub fn TermScreen::cursor_column(self : TermScreen, col : Int) -> Unit {
  self.cursor_position(self.cursor_row + 1, col)
}

///|
/// 清除显示:0 = 光标到末尾,1 = 开头到光标,2 = 整屏,3 = 整屏 + 回看。
pub fn TermScreen::erase_in_display(self : TermScreen, mode : Int) -> Unit {
  self.wrap_pending = false
  match mode {
    0 => {
      for i in self.cursor_col..<self.cols {
        self.screen[self.cursor_row].cells[i] = blank_cell(self.attrs)
      }
      for r in (self.cursor_row + 1)..<self.rows {
        self.screen[r] = TermRow::new(self.cols, self.attrs)
      }
    }
    1 => {
      for i in 0..<=self.cursor_col {
        self.screen[self.cursor_row].cells[i] = blank_cell(self.attrs)
      }
      for r in 0..<self.cursor_row {
        self.screen[r] = TermRow::new(self.cols, self.attrs)
      }
    }
    2 =>
      for r in 0..<self.rows {
        self.screen[r] = TermRow::new(self.cols, self.attrs)
      }
    _ => self.clear_all()
  }
}

///|
/// 清除行:0 = 光标到行尾,1 = 行首到光标,2 = 整行。
pub fn TermScreen::erase_in_line(self : TermScreen, mode : Int) -> Unit {
  self.wrap_pending = false
  let row = self.screen[self.cursor_row]
  match mode {
    0 =>
      for i in self.cursor_col..<self.cols {
        row.cells[i] = blank_cell(self.attrs)
      }
    1 =>
      for i in 0..<=self.cursor_col {
        row.cells[i] = blank_cell(self.attrs)
      }
    _ =>
      for i in 0..<self.cols {
        row.cells[i] = blank_cell(self.attrs)
      }
  }
}

///|
/// 在光标行插入 n 个空行(区域内),底部行进入回看缓冲。
pub fn TermScreen::insert_lines(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  if self.cursor_row < self.scroll_top || self.cursor_row > self.scroll_bottom {
    return
  }
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  for _ in 0..<n {
    self.prepend_scrollback(self.screen[self.scroll_bottom])
    let mut i = self.scroll_bottom
    while i > self.cursor_row {
      self.screen[i] = self.screen[i - 1]
      i = i - 1
    }
    self.screen[self.cursor_row] = self.blank_row()
  }
}

///|
/// 删除光标行起的 n 行(区域内),顶部行进入回看缓冲。
pub fn TermScreen::delete_lines(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  if self.cursor_row < self.scroll_top || self.cursor_row > self.scroll_bottom {
    return
  }
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  for _ in 0..<n {
    self.push_scrollback(self.screen[self.cursor_row])
    for i in self.cursor_row..<self.scroll_bottom {
      self.screen[i] = self.screen[i + 1]
    }
    self.screen[self.scroll_bottom] = self.blank_row()
  }
}

///|
/// 光标处插入 n 个空白格(行内右移)。
pub fn TermScreen::insert_chars(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let row = self.screen[self.cursor_row]
  let count = clamp_count(n, self.cols - self.cursor_col)
  let mut i = self.cols - 1
  while i >= self.cursor_col + count {
    row.cells[i] = row.cells[i - count]
    i = i - 1
  }
  for i in self.cursor_col..<(self.cursor_col + count) {
    row.cells[i] = blank_cell(self.attrs)
  }
}

///|
/// 删除光标处起 n 个字符(行内左移)。
pub fn TermScreen::delete_chars(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let row = self.screen[self.cursor_row]
  let count = clamp_count(n, self.cols - self.cursor_col)
  for i in self.cursor_col..<(self.cols - count) {
    row.cells[i] = row.cells[i + count]
  }
  for i in (self.cols - count)..<self.cols {
    row.cells[i] = blank_cell(self.attrs)
  }
}

///|
/// 擦除光标处起 n 个字符(置空白,不移动)。
pub fn TermScreen::erase_chars(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  let row = self.screen[self.cursor_row]
  let count = clamp_count(n, self.cols - self.cursor_col)
  for i in self.cursor_col..<(self.cursor_col + count) {
    row.cells[i] = blank_cell(self.attrs)
  }
}

///|
/// 滚动区域内向上滚动 n 行,顶部行进入回看缓冲。
pub fn TermScreen::scroll_up(self : TermScreen, n : Int) -> Unit {
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  for _ in 0..<n {
    self.push_scrollback(self.screen[self.scroll_top])
    for i in self.scroll_top..<self.scroll_bottom {
      self.screen[i] = self.screen[i + 1]
    }
    self.screen[self.scroll_bottom] = self.blank_row()
  }
}

///|
/// 滚动区域内向下滚动 n 行,底部行进入回看缓冲头部。
pub fn TermScreen::scroll_down(self : TermScreen, n : Int) -> Unit {
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  for _ in 0..<n {
    self.prepend_scrollback(self.screen[self.scroll_bottom])
    let mut i = self.scroll_bottom
    while i > self.scroll_top {
      self.screen[i] = self.screen[i - 1]
      i = i - 1
    }
    self.screen[self.scroll_top] = self.blank_row()
  }
}

///|
/// 设置滚动区域(top/bottom 为 1-based)。
pub fn TermScreen::set_scroll_region(
  self : TermScreen,
  top : Int,
  bottom : Int,
) -> Unit {
  self.wrap_pending = false
  let t = if top < 1 { 1 } else { top }
  let b = if bottom > self.rows { self.rows } else { bottom }
  // 0-based 索引必须落在 [0, rows-1]
  self.scroll_top = if t > self.rows { self.rows - 1 } else { t - 1 }
  self.scroll_bottom = if b < 1 { 1 } else { b - 1 }
  if self.scroll_bottom >= self.rows {
    self.scroll_bottom = self.rows - 1
  }
  if self.scroll_bottom < self.scroll_top {
    self.scroll_bottom = self.scroll_top
  }
  self.cursor_position(1, 1)
}

///|
pub fn TermScreen::save_cursor(self : TermScreen) -> Unit {
  self.saved_cursor_row = self.cursor_row
  self.saved_cursor_col = self.cursor_col
}

///|
pub fn TermScreen::restore_cursor(self : TermScreen) -> Unit {
  self.cursor_row = self.saved_cursor_row
  self.cursor_col = self.saved_cursor_col
  self.wrap_pending = false
  self.clamp_cursor()
}

///|
pub fn TermScreen::set_title(self : TermScreen, title : String) -> Unit {
  self.title = title
}

///|
/// 调整尺寸;行/列变化尽量保留内容,缩小后的行进入回看缓冲。
pub fn TermScreen::resize(
  self : TermScreen,
  new_cols : Int,
  new_rows : Int,
) -> Unit {
  let cols = if new_cols < 1 { 1 } else { new_cols }
  let rows = if new_rows < 1 { 1 } else { new_rows }
  // 列调整
  if cols != self.cols {
    for row in self.screen {
      let cells = row.cells
      if cols > self.cols {
        while cells.length() < cols {
          cells.push(blank_cell(self.attrs))
        }
      } else if cols < self.cols {
        while cells.length() > cols {
          ignore(cells.pop())
        }
      }
    }
    self.cols = cols
    if self.cursor_col >= cols {
      self.cursor_col = cols - 1
    }
    if self.saved_cursor_col >= cols {
      self.saved_cursor_col = cols - 1
    }
  }
  // 行调整
  if rows != self.rows {
    if rows > self.rows {
      while self.screen.length() < rows {
        self.screen.push(self.blank_row())
      }
    } else if rows < self.rows {
      while self.screen.length() > rows {
        self.push_scrollback(self.screen[0])
        ignore(self.screen.remove(0))
      }
    }
    self.rows = rows
    if self.cursor_row >= rows {
      self.cursor_row = rows - 1
    }
    if self.saved_cursor_row >= rows {
      self.saved_cursor_row = rows - 1
    }
    self.scroll_top = 0
    self.scroll_bottom = rows - 1
  }
}
