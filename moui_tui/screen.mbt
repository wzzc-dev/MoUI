///|
/// 终端屏幕模型:可视区 + 回看缓冲 + 光标 + 滚动区域 + 脏行增量。
/// 只有单元格内容变化才标脏;光标移动、SGR 属性与滚动区域设置不算画面变化,
/// 因此呈现器按 `take_damage` 输出即可覆盖残影,又不会重绘未变的行。
pub struct TermScreen {
  priv mut cols : Int
  priv mut rows : Int
  priv screen : Array[TermRow]
  priv mut scrollback : Array[TermRow]
  priv mut scrollback_limit : Int
  priv mut cursor_row : Int
  priv mut cursor_col : Int
  priv mut scroll_top : Int
  priv mut scroll_bottom : Int
  priv mut saved_cursor_row : Int
  priv mut saved_cursor_col : Int
  priv mut wrap_pending : Bool
  priv mut auto_wrap : Bool
  priv mut cursor_visible : Bool
  priv mut title : String
  priv mut attrs : CellAttrs
  priv mut dirty_rows : Array[Bool]
  priv mut dirty_all : Bool
  priv mut revision : Int
}

///|
fn dirty_mask(rows : Int) -> Array[Bool] {
  let mask : Array[Bool] = []
  for _ in 0..<rows {
    mask.push(false)
  }
  mask
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
    dirty_rows: dirty_mask(rows),
    dirty_all: false,
    revision: 0,
  }
}

///|
/// 标脏一行:首次变脏才推进 revision,合并同一帧内的多次写入。
fn TermScreen::mark_row(self : TermScreen, y : Int) -> Unit {
  if self.dirty_all || y < 0 || y >= self.dirty_rows.length() {
    return
  }
  if !self.dirty_rows[y] {
    self.dirty_rows[y] = true
    self.revision = self.revision + 1
  }
}

///|
/// 标脏 [from, to) 行。
fn TermScreen::mark_rows(self : TermScreen, from : Int, to : Int) -> Unit {
  for y in from..<to {
    self.mark_row(y)
  }
}

///|
fn TermScreen::mark_all(self : TermScreen) -> Unit {
  if !self.dirty_all {
    self.dirty_all = true
    self.revision = self.revision + 1
    self.dirty_rows = dirty_mask(self.rows)
  }
}

///|
/// 写入单个格:内容与属性都没变时不标脏。
/// 投影器每帧重画整棵语义树,若同内容写入也算变化,damage 通路就永远非空,
/// 增量呈现省下的重绘就不存在了。
fn TermScreen::write_cell(
  self : TermScreen,
  y : Int,
  x : Int,
  cell : Cell,
) -> Unit {
  let row = self.screen[y]
  if row.cells[x] == cell {
    return
  }
  self.mark_row(y)
  row.cells[x] = cell
}

///|
/// 缓冲区代数:任何内容变化都会递增,呈现器用它跳过无变化的帧。
pub fn TermScreen::revision(self : TermScreen) -> Int {
  self.revision
}

///|
/// 取出并清零脏区:整屏重建,或升序去重的脏行。
pub fn TermScreen::take_damage(self : TermScreen) -> Damage {
  let rows : Array[Int] = []
  if !self.dirty_all {
    for y, dirty in self.dirty_rows {
      if dirty {
        rows.push(y)
      }
    }
  }
  let damage : Damage = { full: self.dirty_all, rows, }
  self.dirty_all = false
  self.dirty_rows = dirty_mask(self.rows)
  damage
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
/// DECAWM:关闭自动换行后,超宽字符停在最后一列而不是滚到新行。
pub fn TermScreen::set_auto_wrap(self : TermScreen, v : Bool) -> Unit {
  self.auto_wrap = v
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
  self.mark_all()
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
/// 光标处写入字符;处理自动换行与宽字符(右半格填 continuation)。
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
  self.write_cell(self.cursor_row, self.cursor_col, {
    ch,
    width,
    attrs: self.attrs,
  })
  if width == 2 {
    self.write_cell(
      self.cursor_row,
      self.cursor_col + 1,
      continuation_cell(self.attrs),
    )
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
/// 直接写入第 y 行第 x 列,不移动光标 —— 投影器按量化盒定位单元格。
/// 越界或宽字符放不下时返回 false,调用方据此记降级诊断。
pub fn TermScreen::put(
  self : TermScreen,
  y : Int,
  x : Int,
  ch : String,
  width : Int,
  attrs : CellAttrs,
) -> Bool {
  if y < 0 || y >= self.rows || x < 0 || x >= self.cols {
    return false
  }
  if width == 2 && x >= self.cols - 1 {
    return false
  }
  self.write_cell(y, x, { ch, width, attrs, })
  if width == 2 {
    self.write_cell(y, x + 1, continuation_cell(attrs))
  }
  true
}

///|
/// 把第 y 行的 [from, to) 列擦成空白(越界裁剪),保持 attrs 的底色。
pub fn TermScreen::erase_cells(
  self : TermScreen,
  y : Int,
  from : Int,
  to : Int,
  attrs : CellAttrs,
) -> Unit {
  if y < 0 || y >= self.rows {
    return
  }
  let start = from.clamp(min=0, max=self.cols)
  let end = to.clamp(min=0, max=self.cols)
  if end <= start {
    return
  }
  for i in start..<end {
    self.write_cell(y, i, blank_cell(attrs))
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
      self.erase_cells(self.cursor_row, self.cursor_col, self.cols, self.attrs)
      for r in (self.cursor_row + 1)..<self.rows {
        self.erase_cells(r, 0, self.cols, self.attrs)
      }
    }
    1 => {
      self.erase_cells(self.cursor_row, 0, self.cursor_col + 1, self.attrs)
      for r in 0..<self.cursor_row {
        self.erase_cells(r, 0, self.cols, self.attrs)
      }
    }
    2 => {
      self.mark_all()
      for r in 0..<self.rows {
        self.screen[r] = TermRow::new(self.cols, self.attrs)
      }
    }
    _ => self.clear_all()
  }
}

///|
/// 清除行:0 = 光标到行尾,1 = 行首到光标,2 = 整行。
pub fn TermScreen::erase_in_line(self : TermScreen, mode : Int) -> Unit {
  self.wrap_pending = false
  match mode {
    0 =>
      self.erase_cells(self.cursor_row, self.cursor_col, self.cols, self.attrs)
    1 => self.erase_cells(self.cursor_row, 0, self.cursor_col + 1, self.attrs)
    _ => self.erase_cells(self.cursor_row, 0, self.cols, self.attrs)
  }
}

///|
/// 光标行插入 n 个空行(区域内),底部行进入回看缓冲。
pub fn TermScreen::insert_lines(self : TermScreen, n : Int) -> Unit {
  self.wrap_pending = false
  if self.cursor_row < self.scroll_top || self.cursor_row > self.scroll_bottom {
    return
  }
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  self.mark_rows(self.cursor_row, self.scroll_bottom + 1)
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
  self.mark_rows(self.cursor_row, self.scroll_bottom + 1)
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
  if count == 0 {
    return
  }
  self.mark_row(self.cursor_row)
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
  if count == 0 {
    return
  }
  self.mark_row(self.cursor_row)
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
  let count = clamp_count(n, self.cols - self.cursor_col)
  self.erase_cells(
    self.cursor_row,
    self.cursor_col,
    self.cursor_col + count,
    self.attrs,
  )
}

///|
/// 滚动区域内向上滚动 n 行,顶部行进入回看缓冲。
pub fn TermScreen::scroll_up(self : TermScreen, n : Int) -> Unit {
  let n = clamp_count(n, self.scroll_bottom - self.scroll_top + 1)
  if n == 0 {
    return
  }
  self.mark_rows(self.scroll_top, self.scroll_bottom + 1)
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
  if n == 0 {
    return
  }
  self.mark_rows(self.scroll_top, self.scroll_bottom + 1)
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
/// 尺寸变化会让所有行的列位置失效,因此整屏标脏。
pub fn TermScreen::resize(
  self : TermScreen,
  new_cols : Int,
  new_rows : Int,
) -> Unit {
  let cols = if new_cols < 1 { 1 } else { new_cols }
  let rows = if new_rows < 1 { 1 } else { new_rows }
  let size_changed = cols != self.cols || rows != self.rows
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
  if size_changed {
    self.dirty_rows = dirty_mask(rows)
    self.mark_all()
  } else if self.dirty_rows.length() != rows {
    self.dirty_rows = dirty_mask(rows)
  }
}
