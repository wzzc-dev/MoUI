///|
/// cell 调色板:语义角色 → 终端颜色的唯一入口。
///
/// 默认调色板就是 S2–S7 期间的颜色常量,零行为漂移;
/// `from_theme` 把 `@core.Theme` 的语义色量化进 xterm-256,让「同一个
/// `@moui.View[Msg]` 应用」在终端里也带着自己的主题身份。
///
/// 放弃的方案:
/// - 在 `SemanticsNode` 上加颜色字段(owner 已否决):颜色是渲染策略,
///   不是语义事实,而且会让每个像素渲染器和语义协议为一条输出路径付费。
/// - 直接走 truecolor(`38;2`):保真更高,但冒烟解码器与被测终端都按
///   xterm-256 假设在走,16/256 量化在视觉上也更接近终端应用的观感。
///   若未来要 truecolor,只需替换 `quantize` 的一个函数。
/// - 中亮度自动提亮:浅色主题在未知终端底色上的对比问题是
///   ready 晋升要带着证据解决的问题,不在这里猜。
pub(all) struct TuiPalette {
  /// Button 等主操作前景。
  primary : @tui.TermColor
  /// 编辑类控件(Text/TextField/ComboBox/Slider/Progress/Checkbox/Switch/Radio)。
  interactive : @tui.TermColor
  /// Text 正文。
  content : @tui.TermColor
  /// Status。
  status : @tui.TermColor
  /// Alert。
  alert : @tui.TermColor
  /// Heading 前景(加粗由样式层负责,与调色板无关)。
  heading : @tui.TermColor
  /// 默认色:chrome/区域边框、条目、没有语义色的结构。
  neutral : @tui.TermColor
  /// 焦点带前景(永远伴随 bold+underline,和选中的反白可区分)。
  focus : @tui.TermColor
}

///|
/// S2–S7 的固定颜色:这就是默认,任何改动都会撞两条 golden 帧。
pub fn TuiPalette::default() -> TuiPalette {
  {
    primary: @tui.Indexed(4),
    interactive: @tui.Indexed(5),
    content: @tui.Indexed(2),
    status: @tui.Indexed(2),
    alert: @tui.Indexed(2),
    heading: @tui.TermColor::Default,
    neutral: @tui.Indexed(6),
    focus: @tui.Indexed(3),
  }
}

///|
fn fg(color : @tui.TermColor) -> @tui.CellAttrs {
  @tui.attrs_with(@tui.CellAttrs::default(), fg=Some(color))
}

///|
/// 0..1 通道 → xterm 6x6x6 立方的一档(台阶 0/95/135/175/215/255)。
fn cube_step(v : Double) -> Int {
  let steps = [0, 95, 135, 175, 215, 255]
  let target = (v.clamp(min=0.0, max=1.0) * 255.0).round().to_int()
  let mut best = 0
  let mut best_distance = 1 << 60
  for i in 0..<steps.length() {
    let distance = (steps[i] - target).abs()
    if distance < best_distance {
      best_distance = distance
      best = i
    }
  }
  best
}

///|
/// 颜色 → xterm-256 索引:三通道接近的中性色走 24 级灰阶,其余走 216 色立方。
pub fn quantize_color(color : @core.Color) -> @tui.TermColor {
  let r = color.r.clamp(min=0.0, max=1.0)
  let g = color.g.clamp(min=0.0, max=1.0)
  let b = color.b.clamp(min=0.0, max=1.0)
  let mx = if r >= g {
    if r >= b {
      r
    } else {
      b
    }
  } else if g >= b {
    g
  } else {
    b
  }
  let mn = if r <= g {
    if r <= b {
      r
    } else {
      b
    }
  } else if g <= b {
    g
  } else {
    b
  }
  if mx - mn < 0.06 {
    // 232..255 灰阶:亮度 8 + 10i,取最近一级。
    let level = ((r + g + b) * 255.0 / 3.0 - 8.0) / 10.0
    let idx = level.round().to_int().clamp(min=0, max=23)
    @tui.Indexed(232 + idx)
  } else {
    @tui.Indexed(16 + 36 * cube_step(r) + 6 * cube_step(g) + cube_step(b))
  }
}

///|
/// 主题 → 调色板:`primary` 家族归按钮与焦点,`secondary` 归交互控件,
/// `on_surface` 系归文本与标题,`error` 归警示。
///
/// 语义角色和调色板角色不是双射:终端只有一层前景色通道,所以
/// `on_*_container` 这类「印在色块上的颜色」在这里没有对应物 —— 色块
/// 本身在 cell 投影里不存在。
pub fn TuiPalette::from_theme(theme : @core.Theme) -> TuiPalette {
  let palette = theme.palette
  {
    primary: quantize_color(palette.primary),
    interactive: quantize_color(palette.secondary),
    content: quantize_color(palette.on_surface),
    status: quantize_color(palette.on_surface_variant),
    alert: quantize_color(palette.error),
    heading: quantize_color(palette.on_surface),
    neutral: quantize_color(palette.on_surface_variant),
    focus: quantize_color(palette.primary),
  }
}

///|
/// 未聚焦角色 → 基础 attrs,全匹配 `SemanticsRole`:新增角色必须在这里
/// 表态(给色位或明说随默认色),样式层和 `role_tag`/`role_kind` 一样
/// 在编译期兜底,而不是运行时静默换色。
fn TuiPalette::base_attrs(
  self : TuiPalette,
  role : @core.SemanticsRole,
) -> @tui.CellAttrs {
  match role {
    @core.Button => @tui.attrs_with(fg(self.primary), bold=Some(true))
    @core.Heading => @tui.attrs_with(fg(self.heading), bold=Some(true))
    @core.Text => fg(self.content)
    @core.Status => fg(self.status)
    @core.Alert => fg(self.alert)
    @core.TextField
    | @core.ComboBox
    | @core.Slider
    | @core.Progress
    | @core.Checkbox
    | @core.Switch
    | @core.Radio => fg(self.interactive)
    @core.None
    | @core.Link
    | @core.Navigation
    | @core.Main
    | @core.List
    | @core.ListItem
    | @core.Grid
    | @core.ScrollView
    | @core.Tab
    | @core.Dialog
    | @core.Tooltip
    | @core.Menu
    | @core.ButtonGroup
    | @core.Form
    | @core.FormField
    | @core.Tree
    | @core.TreeItem
    | @core.Group
    | @core.WebView
    | @core.Image
    | @core.Option
    | @core.Table
    | @core.Row
    | @core.Cell
    | @core.Separator => fg(self.neutral)
  }
}

///|
/// 语义状态 + 角色 → SGR 属性。焦点与选中必须有可见差异,
/// 否则键盘导航在终端里无法辨认。
pub fn TuiPalette::attrs_for(
  self : TuiPalette,
  role : @core.SemanticsRole,
  state : @core.SemanticsState,
) -> @tui.CellAttrs {
  let base = if state.focused {
    @tui.attrs_with(fg(self.focus), bold=Some(true), underline=Some(true))
  } else {
    self.base_attrs(role)
  }
  let selected = if state.selected {
    @tui.attrs_with(base, reverse=Some(true))
  } else {
    base
  }
  if state.pressed && !selected.bold {
    @tui.attrs_with(selected, bold=Some(true))
  } else {
    selected
  }
}
