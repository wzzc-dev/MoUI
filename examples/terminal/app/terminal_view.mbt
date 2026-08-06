///|
/// 终端渲染:屏幕行 → 等宽文本行,按颜色 run 分段着色。
/// 不引入自定义 ViewNode,全部由现有 views(text/mono/foreground)组合。

///|
/// ANSI 16 色标准调色板(dark 变体)。
fn ansi_base16() -> Array[@graphics.Color] {
  [
    @graphics.Color::rgba(r=0.0, g=0.0, b=0.0), // 0 black
    @graphics.Color::rgba(r=0.80, g=0.0, b=0.0), // 1 red
    @graphics.Color::rgba(r=0.0, g=0.80, b=0.0), // 2 green
    @graphics.Color::rgba(r=0.80, g=0.80, b=0.0), // 3 yellow
    @graphics.Color::rgba(r=0.0, g=0.0, b=0.93), // 4 blue
    @graphics.Color::rgba(r=0.80, g=0.0, b=0.80), // 5 magenta
    @graphics.Color::rgba(r=0.0, g=0.80, b=0.80), // 6 cyan
    @graphics.Color::rgba(r=0.90, g=0.90, b=0.90), // 7 white
    @graphics.Color::rgba(r=0.50, g=0.50, b=0.50), // 8 bright black
    @graphics.Color::rgba(r=1.0, g=0.0, b=0.0), // 9
    @graphics.Color::rgba(r=0.0, g=1.0, b=0.0), // 10
    @graphics.Color::rgba(r=1.0, g=1.0, b=0.0), // 11
    @graphics.Color::rgba(r=0.36, g=0.36, b=1.0), // 12
    @graphics.Color::rgba(r=1.0, g=0.0, b=1.0), // 13
    @graphics.Color::rgba(r=0.0, g=1.0, b=1.0), // 14
    @graphics.Color::rgba(r=1.0, g=1.0, b=1.0), // 15
  ]
}

///|
/// 256 色索引 → 颜色:0-15 基础色,16-231 6×6×6 立方体,232-255 灰度。
fn ansi256_color(n : Int) -> @graphics.Color {
  if n < 16 {
    ansi_base16()[n]
  } else if n < 232 {
    let v = n - 16
    let r = v / 36
    let g = v / 6 % 6
    let b = v % 6
    let cube = fn(c : Int) -> Double {
      if c == 0 {
        0.0
      } else {
        (55.0 + 40.0 * c.to_double()) / 255.0
      }
    }
    @graphics.Color::rgba(r=cube(r), g=cube(g), b=cube(b))
  } else {
    let level = 8.0 + 10.0 * (n - 232).to_double()
    let v = level / 255.0
    @graphics.Color::rgba(r=v, g=v, b=v)
  }
}

///|
/// 终端面板背景:跟随主题(深色主题=黑底,浅色主题=白底)。
pub fn terminal_background(theme : @moui.Theme) -> @graphics.Color {
  theme.palette.background
}

///|
/// 终端默认前景:跟随主题前景色(与背景保持可读对比)。
fn terminal_foreground(theme : @moui.Theme) -> @graphics.Color {
  theme.palette.foreground
}

///|
/// TermColor → @graphics.Color。
/// 默认前景/背景跟随主题(与面板底色保持对比);ANSI 16 色与 RGB
/// 色板固定(与其它主流终端一致,深浅主题下保持一致)。
pub fn term_color_to_core(
  color : TermColor,
  theme : @moui.Theme,
) -> @graphics.Color {
  match color {
    TermColor::Default => terminal_foreground(theme)
    TermColor::Indexed(n) =>
      if n < 0 || n > 255 {
        terminal_foreground(theme)
      } else {
        ansi256_color(n)
      }
    TermColor::Rgb(r, g, b) =>
      @graphics.Color::rgba(
        r=r.clamp(min=0, max=255).to_double() / 255.0,
        g=g.clamp(min=0, max=255).to_double() / 255.0,
        b=b.clamp(min=0, max=255).to_double() / 255.0,
      )
  }
}

///|
/// 等宽单元格宽度:等宽字体 advance 为标准 0.6em,随主题字号推导。
///
/// 不能用固定像素常量:TextRole::Mono 字号取自 theme.typography.body.size
/// (默认 16px),实际字符宽 ≈ 0.6em = 9.6px;若像旧实现那样固定 8.4
/// (14px 字号的经验值),文本绘制宽度会大于节点 frame 宽度,渲染器按
/// frame 裁剪(clip_rect),表现为行尾字符——单词的最后一个字母丢失。
pub fn cell_width(theme : @moui.Theme) -> Double {
  theme.typography.body.size * 0.6
}

///|
/// 等宽单元格高度:行高按字号 1.25 倍(含行距)。
pub fn cell_height(theme : @moui.Theme) -> Double {
  theme.typography.body.size * 1.25
}

///|
/// 一行文本的渲染视图:按 run 分段,段间 spacing 0。
fn[Msg] terminal_row_view(
  row : TermRow,
  theme : @moui.Theme,
  cols : Int,
  selection_range : (Int, Int)?,
) -> @moui.View[Msg] {
  let sel_bg = theme.palette.primary_container
  let sel_fg = theme.palette.on_primary_container
  let segments : Array[@moui.View[Msg]] = []
  let mut col = 0
  for run in row.runs() {
    let (text, width, attrs) = run
    let run_start = col
    let run_end = col + width
    let selected = match selection_range {
      Some((s, e)) => run_end > s && run_start < e
      None => false
    }
    let fg = if selected { sel_fg } else { term_color_to_core(attrs.fg, theme) }
    let bg = if selected {
      sel_bg
    } else if attrs.bg == TermColor::Default {
      terminal_background(theme)
    } else {
      term_color_to_core(attrs.bg, theme)
    }
    segments.push(
      @views.text(
        text,
        role=@views.TextRole::Mono,
        width=width.to_double() * cell_width(theme),
        height=cell_height(theme),
        align=@text.TextAlign::TextStart,
      )
      .foreground(fg)
      .background(bg),
    )
    col = run_end
  }
  // 补齐剩余列,保持整行等宽(背景连续)
  let used = col
  if used < cols {
    let gap = cols - used
    let selected = match selection_range {
      Some((s, e)) => used < e && cols > s
      None => false
    }
    let gap_bg = if selected { sel_bg } else { terminal_background(theme) }
    segments.push(
      @views.text(
        "",
        role=@views.TextRole::Mono,
        width=gap.to_double() * cell_width(theme),
        height=cell_height(theme),
      ).background(gap_bg),
    )
  }
  @views.row(segments, spacing=0.0, align=@views.CrossAlign::Stretch)
}

///|
/// 终端主视图:显示从回看偏移处起的可视行。
pub fn[Msg] terminal_view(
  screen : TermScreen,
  theme : @moui.Theme,
  scroll_offset? : Int = 0,
  selection? : Selection? = None,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  let cols = screen.cols()
  let start = screen.total_lines() - screen.rows() - scroll_offset
  for r in 0..<screen.rows() {
    let row_idx = start + r
    let range = match selection {
      Some(sel) => sel.col_range_at(row_idx)
      None => None
    }
    rows.push(terminal_row_view(screen.line_at(row_idx), theme, cols, range))
  }
  @views.column(rows, spacing=0.0, align=@views.CrossAlign::Stretch)
}
