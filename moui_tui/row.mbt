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
    } else {
      out.push((cell.ch, cell.width, cell.attrs))
      current_attrs = Some(cell.attrs)
    }
  }
  // 裁剪尾部无背景 run 的空格后缀(渲染无意义)
  if out.length() > 0 {
    let (tail, tail_width, tail_attrs) = out[out.length() - 1]
    if tail_attrs.bg == Default {
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
/// 去掉字符串尾部空格(终端行文本用)。
pub fn trim_trailing_spaces(s : String) -> String {
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
