///|
/// 字符格物理尺寸(逻辑像素)。投影器的坐标系只有这一个原点:
/// 布局盒用像素表达,cell 栅格用它换算。
pub(all) struct CellBox {
  width : Double
  height : Double
}

///|
/// 宿主按自己终端的实际字宽构造。cell 尺寸是投影唯一的标定入口:
/// 它同时决定栅格量化和等宽文本系统的度量,标定错了分栏边界就会错格。
pub fn CellBox::new(width~ : Double, height~ : Double) -> CellBox {
  { width, height, }
}

///|
pub fn CellBox::default() -> CellBox {
  { width: 8.0, height: 16.0, }
}

///|
fn cell_count(px : Double, unit : Double) -> Int32 {
  if unit <= 0.0 {
    return 1
  }
  let n = (px / unit).floor().to_int()
  if n < 1 {
    1
  } else {
    n
  }
}

///|
/// 可视区列数:向下取整,至少 1 列。
pub fn CellBox::cols_of(
  self : CellBox,
  metrics : @core.SurfaceMetrics,
) -> Int32 {
  cell_count(metrics.logical_size.width, self.width)
}

///|
/// 可视区行数:向下取整,至少 1 行。
pub fn CellBox::rows_of(
  self : CellBox,
  metrics : @core.SurfaceMetrics,
) -> Int32 {
  cell_count(metrics.logical_size.height, self.height)
}

///|
/// 文本占用的 cell 数(换行符不占格,CJK/emoji 按双宽计)。
pub fn cell_units(text : String) -> Int32 {
  let mut units = 0
  for ch in text {
    if ch != '\n' {
      units = units + @tui.unicode_width(ch.to_string())
    }
  }
  units
}

///|
/// 按可用列数做贪心折行,返回占用行数。
fn wrapped_line_count(text : String, cols : Int32) -> Int32 {
  let cols = if cols < 1 { 1 } else { cols }
  let mut lines = 1
  let mut used = 0
  for ch in text {
    if ch == '\n' {
      lines = lines + 1
      used = 0
    } else {
      let w = @tui.unicode_width(ch.to_string())
      if used + w > cols {
        lines = lines + 1
        used = w
      } else {
        used = used + w
      }
    }
  }
  lines
}

///|
/// 逐字符的插入点横偏移(含原点那一项,所以空文本也有一格)。
///
/// 等宽网格上这件事是免费的:第 i 个插入点就是前缀占了几个格宽。不报它
/// (曾经报 `[]`)有两个后果 —— 文本框的绘制覆盖层按下标取几何会越界,
/// 而点击定位没有可依据的偏移,只能永远退回第 0 个插入点。
/// 超出可用宽度的那些点按同一规则钉在边界上,和 `moui/core` 的
/// `clamp_text_layout_result` 一致:折出视口的文本,其尾部插入点留在边缘,
/// 不跑到框外去。
fn cell_caret_positions(
  text : String,
  cell : CellBox,
  max_width : Double?,
) -> Array[Double] {
  let positions : Array[Double] = [0.0]
  let mut cursor = 0.0
  for ch in text {
    if ch != '\n' {
      cursor = cursor +
        @tui.unicode_width(ch.to_string()).to_double() * cell.width
    }
    let clamped = match max_width {
      Some(width) => if cursor > width { width } else { cursor }
      None => cursor
    }
    positions.push(clamped)
  }
  positions
}

///|
/// 等宽 cell 文本系统:让既有 `layout()` 在不接 GPU/字体栈时也能算出盒高。
/// 度量单位就是 `CellBox`,所以布局结果与投影栅格共用一套网格。
pub fn cell_text_system(cell : CellBox) -> @core.TextSystem {
  @core.TextSystem::new(id="tui-cell", measure=input => {
    let cols = match input.max_width {
      Some(width) => cell_count(width, cell.width)
      None => cell_units(input.text)
    }
    let used = cell_units(input.text)
    let wide = if used > cols { cols } else { used }
    {
      size: @core.Size::new(
        width=wide.to_double() * cell.width,
        height=wrapped_line_count(input.text, cols).to_double() * cell.height,
      ),
      baseline: cell.height,
      caret_positions: cell_caret_positions(input.text, cell, input.max_width),
    }
  })
}
