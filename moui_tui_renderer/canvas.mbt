///|
/// 投影画布:在 S1 的 `TermScreen` 之上加一层"格子归属"。
///
/// 归属规则就是 S0 定下的 z-order 策略,它属于投影器而不是 cell buffer:
/// `@moui_tui` 必须保持与 VT 终端同构的纯缓冲区,不能认识语义树。
/// - 每个绘制动作分配一个 paint sequence,并带一个优先级
/// - 高优先级可以覆盖低优先级已占的格子,反之不行
/// - 同优先级先到先得,所以两个兄弟盒重叠时不会互相打断笔画
priv struct Canvas {
  screen : @tui.TermScreen
  mut cols : Int32
  mut rows : Int32
  /// 本帧每格的 paint sequence,0 表示未被占。
  mut owners : Array[Array[Int32]]
  /// 本帧每格首字符占用的 cell 数:1 单宽、2 宽字符左半、-1 宽字符右半。
  mut widths : Array[Array[Int32]]
  /// 上一帧的同一对掩码:这一帧没再画的格子要靠它擦掉。
  mut prev_owners : Array[Array[Int32]]
  mut prev_widths : Array[Array[Int32]]
  /// 本帧被样式带碰过的格子。样式带只改 attrs、故意不认领格子,
  /// 归属清扫永远轮不到它们,带的擦除只能凭这份掩码。
  mut bands : Array[Array[Int32]]
  /// 上一帧的带掩码:这一帧没再碰的带格子要靠它擦掉。
  mut prev_bands : Array[Array[Int32]]
  /// 上一次真正写给终端的栅格:增量的唯一依据。
  mut sent : Array[Array[@tui.Cell]]
  /// 尺寸变化后必须先整屏重建,否则缩窗留下的残字擦不掉。
  mut rebuild : Bool
  mut prio : Array[Int32]
}

///|
priv struct Cursor {
  mut row : Int32
  mut col : Int32
  c0 : Int32
  r1 : Int32
  c1 : Int32
  attrs : @tui.CellAttrs
  seq : Int32
}

///|
fn cell_mask(cols : Int32, rows : Int32, fill : Int32) -> Array[Array[Int32]] {
  // 每行要有自己的底层数组,嵌套 make 会让所有行共享同一份。
  let mask : Array[Array[Int32]] = []
  for _ in 0..<rows {
    mask.push(Array::make(cols, fill))
  }
  mask
}

///|
fn blank_grid(cols : Int32, rows : Int32) -> Array[Array[@tui.Cell]] {
  let blank = @tui.blank_cell(@tui.CellAttrs::default())
  let grid : Array[Array[@tui.Cell]] = []
  for _ in 0..<rows {
    // 每行要有自己的底层数组,嵌套 make 会让所有行共享同一份。
    grid.push(Array::make(cols, blank))
  }
  grid
}

///|
fn Canvas::new(cols : Int32, rows : Int32) -> Canvas {
  {
    screen: @tui.TermScreen::new(cols, rows),
    cols,
    rows,
    owners: cell_mask(cols, rows, 0),
    widths: cell_mask(cols, rows, 0),
    prev_owners: cell_mask(cols, rows, 0),
    prev_widths: cell_mask(cols, rows, 0),
    bands: cell_mask(cols, rows, 0),
    prev_bands: cell_mask(cols, rows, 0),
    sent: blank_grid(cols, rows),
    rebuild: false,
    prio: [],
  }
}

///|

///|
/// 换尺寸 = 换栅格,不是换终端窗口。
///
/// `TermScreen::resize` 走的是终端语义:保内容、缩窗时把顶部行推进回看缓冲。
/// 投影器两样都不能要 ——
/// - 全帧 `line_at(y)` 把 `y` 当可视行号用,回看缓冲一旦非空,整个 diff 就会
///   读到回看行,于是新帧里混进旧宽度的行(实测 60 列表头出现在 100 列帧的第 1 行);
/// - 残格在重建帧里照样被 `runs()` 编码出去,旧布局的字和新增量的字叠在同一行。
/// 所以这里显式清空而不是只标脏。放弃的方案:让 `rebuild` 分支先清屏再靠
/// `sweep_stale` 擦残格 —— 清屏由终端做了,但栅格里的残格仍会被逐行重画出去,
/// 而且 `prev_owners` 在换尺寸时无效可查,擦不到。
fn Canvas::resize(self : Canvas, cols : Int32, rows : Int32) -> Unit {
  if cols == self.cols && rows == self.rows {
    return
  }
  self.cols = cols
  self.rows = rows
  self.owners = cell_mask(cols, rows, 0)
  self.widths = cell_mask(cols, rows, 0)
  // 掩码按新尺寸重建:上一帧的归属在新栅格上没有可对应的格子。
  self.prev_owners = cell_mask(cols, rows, 0)
  self.prev_widths = cell_mask(cols, rows, 0)
  self.bands = cell_mask(cols, rows, 0)
  self.prev_bands = cell_mask(cols, rows, 0)
  self.sent = blank_grid(cols, rows)
  self.rebuild = true
  self.screen.resize(cols, rows)
  self.screen.clear_all()
}

///|
/// 帧起始:只换掩码,不整屏刷白。
///
/// 整屏刷白会让每个曾有过内容的行都变脏,增量退化成逐行全量重绘;
/// 保留旧掩码、在帧末只擦这一帧没再画的格子,内容不变的帧才能零字节。
fn Canvas::begin_frame(self : Canvas) -> Unit {
  self.prio = []
  self.prev_owners = self.owners
  self.prev_widths = self.widths
  self.prev_bands = self.bands
  self.owners = cell_mask(self.cols, self.rows, 0)
  self.widths = cell_mask(self.cols, self.rows, 0)
  self.bands = cell_mask(self.cols, self.rows, 0)
}

///|
/// 强制下一帧整屏重建(换调色板这类「内容没变但每一格的 attrs 都变了」)。
fn Canvas::force_rebuild(self : Canvas) -> Unit {
  self.rebuild = true
}

///|
/// 帧末清扫:上一帧画过、这一帧没认领的格子刷白。
/// 宽字符右半由左半一并清掉,否则会在行里留下吃不掉的一格。
fn Canvas::sweep_stale(self : Canvas) -> Unit {
  let blank = @tui.CellAttrs::default()
  for y in 0..<self.rows {
    for x in 0..<self.cols {
      if self.owners[y][x] != 0 || self.prev_owners[y][x] == 0 {
        continue
      }
      let previous_width = self.prev_widths[y][x]
      if previous_width == -1 {
        continue
      }
      self.erase_cell(y, x, blank)
      if previous_width == 2 && x + 1 < self.cols {
        self.erase_cell(y, x + 1, blank)
      }
    }
  }
}

///|
fn Canvas::erase_cell(
  self : Canvas,
  y : Int32,
  x : Int32,
  attrs : @tui.CellAttrs,
) -> Unit {
  self.widths[y][x] = 1
  ignore(self.screen.put(y, x, " ", 1, attrs))
}

///|
fn Canvas::new_seq(self : Canvas, prio : Int32) -> Int32 {
  let seq = self.prio.length() + 1
  self.prio.push(prio)
  seq
}

///|
/// 归属判定:空格与自己都可写,否则只有更高优先级才能抢占。
fn Canvas::can_claim(self : Canvas, y : Int32, x : Int32, seq : Int32) -> Bool {
  if y < 0 || y >= self.rows || x < 0 || x >= self.cols {
    return false
  }
  let other = self.owners[y][x]
  if other == 0 || other == seq {
    true
  } else {
    self.prio[seq - 1] > self.prio[other - 1]
  }
}

///|
fn Canvas::take_cell(self : Canvas, y : Int32, x : Int32, seq : Int32) -> Unit {
  self.owners[y][x] = seq
}

///|
/// 抢占别人的格子时,要把那一格的宽字符伴侣一起清掉:
/// 残留右半格 width==0 不产生文本,行会凭空少一格。
fn Canvas::drop_partner(
  self : Canvas,
  y : Int32,
  x : Int32,
  seq : Int32,
  attrs : @tui.CellAttrs,
) -> Unit {
  let previous = self.widths[y][x]
  let partner = if previous == 2 {
    x + 1
  } else if previous == -1 {
    x - 1
  } else {
    -1
  }
  if partner >= 0 && partner < self.cols {
    self.take_cell(y, partner, seq)
    self.erase_cell(y, partner, attrs)
  }
}

///|
/// 写入一个字符:先确认整个跨度都能归属本 seq,再落盘。
fn Canvas::put(
  self : Canvas,
  y : Int32,
  x : Int32,
  ch : String,
  attrs : @tui.CellAttrs,
  seq : Int32,
) -> Bool {
  if y < 0 || y >= self.rows || x < 0 || x >= self.cols {
    return false
  }
  let width = @tui.unicode_width(ch)
  let span = if width > 1 { 2 } else { 1 }
  if x + span > self.cols {
    return false
  }
  // 跨度必须整体可归属才落盘:半格被抢会让宽字符占掉别人的列。
  let mut i = x
  let mut claimable = true
  while i < x + span {
    if !self.can_claim(y, i, seq) {
      claimable = false
    }
    i = i + 1
  }
  if !claimable {
    return false
  }
  i = x
  while i < x + span {
    if self.owners[y][i] != seq && self.owners[y][i] != 0 {
      self.drop_partner(y, i, seq, attrs)
    }
    self.take_cell(y, i, seq)
    i = i + 1
  }
  let written = self.screen.put(y, x, ch, width, attrs)
  self.widths[y][x] = width
  if width > 1 {
    self.widths[y][x + 1] = -1
  }
  written
}

///|
fn cursor_advance(cur : Cursor) -> Bool {
  cur.row = cur.row + 1
  cur.col = cur.c0
  cur.row <= cur.r1
}

///|
/// 在量化盒内写一个词:超宽硬断(中日韩整段没有空格,必须能连续折行),
/// 词尾留一格空白。
fn Canvas::put_word(self : Canvas, cur : Cursor, word : String) -> Bool {
  let plain = @tui.CellAttrs::default()
  for ch in word {
    if cur.col > cur.c1 && !cursor_advance(cur) {
      return false
    }
    let text = ch.to_string()
    if @tui.unicode_width(text) > 1 && cur.col + 1 > cur.c1 {
      if !cursor_advance(cur) {
        return false
      }
    }
    ignore(self.put(cur.row, cur.col, text, cur.attrs, cur.seq))
    cur.col = cur.col + @tui.unicode_width(text)
  }
  // 词间空位只在能被本 seq 归属时才填空白:直接抢格会把兄弟节点
  // 的首字母擦成一个空格(实测 `Entry 0` 变成 ` ntry 0`)。
  if cur.col <= cur.c1 {
    ignore(self.put(cur.row, cur.col, " ", plain, cur.seq))
  }
  cur.col = cur.col + 1
  true
}

///|
/// 每帧绘制都裁剪到节点自己的量化盒并在盒内折行。
/// 像素渲染器靠 `clip_rect` 免费拿到这件事,cell 投影必须显式做,
/// 否则兄弟节点会互相插字。
fn Canvas::write_boxed(
  self : Canvas,
  r0 : Int32,
  c0 : Int32,
  r1 : Int32,
  c1 : Int32,
  text : String,
  attrs : @tui.CellAttrs,
  seq : Int32,
) -> Unit {
  let cur : Cursor = { row: r0, col: c0, c0, r1, c1, attrs, seq, }
  let mut word = ""
  for ch in text {
    if ch == '\n' {
      if word.length() > 0 && !self.put_word(cur, word) {
        return
      }
      word = ""
      if !cursor_advance(cur) {
        return
      }
    } else if ch == ' ' {
      if word.length() > 0 && !self.put_word(cur, word) {
        return
      }
      word = ""
    } else {
      word = word + ch.to_string()
    }
  }
  if word.length() > 0 {
    ignore(self.put_word(cur, word))
  }
}

///|
/// 区域边框。盒子小到画不出框时退化为一个标记格,保证区域不会被丢掉。
/// 框上不再写标题:标题是内容,归子节点画。
fn Canvas::draw_box(
  self : Canvas,
  r0 : Int32,
  c0 : Int32,
  r1 : Int32,
  c1 : Int32,
  attrs : @tui.CellAttrs,
  chrome : Int32,
) -> Unit {
  if r1 - r0 < 2 || c1 - c0 < 2 {
    ignore(self.put(r0, c0, "~", attrs, chrome))
    return
  }
  ignore(self.put(r0, c0, "╭", attrs, chrome))
  ignore(self.put(r0, c1, "╮", attrs, chrome))
  ignore(self.put(r1, c0, "╰", attrs, chrome))
  ignore(self.put(r1, c1, "╯", attrs, chrome))
  let mut c = c0 + 1
  while c < c1 {
    ignore(self.put(r0, c, "─", attrs, chrome))
    ignore(self.put(r1, c, "─", attrs, chrome))
    c = c + 1
  }
  let mut r = r0 + 1
  while r < r1 {
    ignore(self.put(r, c0, "│", attrs, chrome))
    ignore(self.put(r, c1, "│", attrs, chrome))
    r = r + 1
  }
}

///|
/// 样式覆盖层:重刷 attrs,不改字符。
///
/// 焦点与选中挂在条目容器上,而条目自己不写字(内容归子节点),
/// 所以高亮不能走 `put` 的归属抢占 —— 那会为了"显眼"吃掉兄弟的文字。
/// 归属判定管「这一格归谁」,覆盖层管「这一格长什么样」。
///
/// 唯一例外是下划线:它是跟着字形走的装饰,画在没被任何节点认领的格子上
/// 就成了一条独立横线。量化盒比标签宽、还常有整空格行(实测 counter 焦点
/// 带 3 行 × 13 格而 `[-]` 只占 1 行 3 格),整段照抄 attrs 会在标签下方
/// 画出两根悬空的黄线。底色/反白在空格上是色带,仍然全幅铺开。
fn Canvas::style_range(
  self : Canvas,
  r0 : Int32,
  c0 : Int32,
  r1 : Int32,
  c1 : Int32,
  attrs : @tui.CellAttrs,
) -> Unit {
  let mut y = r0.clamp(min=0, max=self.rows - 1)
  let y1 = r1.clamp(min=0, max=self.rows - 1)
  let x0 = c0.clamp(min=0, max=self.cols - 1)
  let x1 = c1.clamp(min=0, max=self.cols - 1)
  let bare = @tui.attrs_with(attrs, underline=Some(false))
  while y <= y1 {
    let cells = self.screen.line_at(y).cells
    let mut x = x0
    while x <= x1 {
      // 宽字符右半由左半那笔一并重写(put 会连伴侣一起给 attrs)。
      if self.widths[y][x] != -1 && x < cells.length() {
        // 带不认领格子,这里留痕:带移走后靠 sweep_stale_bands 擦属性。
        self.bands[y][x] = 1
        ignore(
          self.screen.put(
            y,
            x,
            cells[x].ch,
            self.widths[y][x].clamp(min=1, max=2),
            if self.owners[y][x] == 0 {
              bare
            } else {
              attrs
            },
          ),
        )
      }
      x = x + 1
    }
    y = y + 1
  }
}

///|
/// 最终内容与上一次写给终端的栅格是否不同。逐格比而不比行文本:
/// 属性变了但字符没变(焦点态换前景色)也必须重画。
fn Canvas::row_changed(self : Canvas, y : Int32) -> Bool {
  let current = self.screen.line_at(y).cells
  let previous = self.sent[y]
  if current.length() != previous.length() {
    return true
  }
  let mut x = 0
  let mut changed = false
  while x < current.length() {
    if current[x] != previous[x] {
      changed = true
    }
    x = x + 1
  }
  changed
}

///|
/// 写入代脏 → 最终差异。
///
/// `@moui_tui` 的"写一笔就标脏一行"对 VT 缓冲区是对的,但投影器一帧内
/// 会把同一格写好几遍(先画边框、内容再抢占、帧末再清扫),瞬时中间态
/// 全都算变化的话增量通路永远非空,内容没变的帧也要重画整屏。
/// 所以这里只把 buffer 的脏行当成候选集,逐行用最终栅格对比上次输出。
fn Canvas::final_damage(self : Canvas, candidates : @tui.Damage) -> @tui.Damage {
  if candidates.full || self.rebuild {
    let rebuild : @tui.Damage = { full: true, rows: [], }
    self.rebuild = false
    self.sent = self.snapshot()
    rebuild
  } else {
    let rows : Array[Int32] = []
    for y in candidates.rows {
      if y >= 0 && y < self.rows && self.row_changed(y) {
        rows.push(y)
        self.sent[y] = self.screen.line_at(y).cells.copy()
      }
    }
    let partial : @tui.Damage = { full: false, rows, }
    partial
  }
}

///|
fn Canvas::snapshot(self : Canvas) -> Array[Array[@tui.Cell]] {
  let grid : Array[Array[@tui.Cell]] = []
  for y in 0..<self.rows {
    grid.push(self.screen.line_at(y).cells.copy())
  }
  grid
}

///|
/// 帧末清扫(带):上一帧被样式带碰过、这一帧没人认领也没再碰的格子,
/// 属性刷回默认。样式带故意不认领格子(避免抢兄弟的文字),所以
/// `sweep_stale` 的归属判据永远轮不到它们 —— 不清,带移走后空格子上的
/// 反白/加粗就永久留在屏上(实测 2026-10-15:「点过的区域留着一块
/// 没有字的青色」,初始选中行的第 2 行在选中移走后一步不动)。
/// 有字形的格子归各画笔与 `sweep_stale` 管,这里不碰。
fn Canvas::sweep_stale_bands(self : Canvas) -> Unit {
  let blank = @tui.CellAttrs::default()
  for y in 0..<self.rows {
    for x in 0..<self.cols {
      if self.bands[y][x] != 0 || self.prev_bands[y][x] == 0 {
        continue
      }
      if self.owners[y][x] != 0 || self.prev_owners[y][x] != 0 {
        continue
      }
      if self.widths[y][x] == -1 {
        continue
      }
      self.erase_cell(y, x, blank)
    }
  }
}

///|
/// 帧末:清扫旧格子与残留带,再按最终栅格与上次输出的差异编码 ANSI 增量。
fn Canvas::present_update(self : Canvas) -> String {
  self.sweep_stale()
  self.sweep_stale_bands()
  // 脏 mask 必须取走才能清零,否则下一帧会背上上一帧的脏行。
  let damage = self.final_damage(self.screen.take_damage())
  if damage.is_empty() {
    ""
  } else {
    frame_update(self.screen, damage)
  }
}
