///|
/// 终端文本选择:锚点与活动端点(单元格坐标,行为全局行索引,
/// 含回看区)。选择范围两端可任意顺序。
pub(all) struct Selection {
  anchor_row : Int
  anchor_col : Int
  active_row : Int
  active_col : Int
}

///|
pub fn Selection::new(
  anchor_row : Int,
  anchor_col : Int,
  active_row : Int,
  active_col : Int,
) -> Selection {
  { anchor_row, anchor_col, active_row, active_col }
}

///|
/// 归一化为 (top_row, left_col, bottom_row, right_col)。
pub fn Selection::normalized(self : Selection) -> (Int, Int, Int, Int) {
  let (top, bottom) = if self.anchor_row <= self.active_row {
    (self.anchor_row, self.active_row)
  } else {
    (self.active_row, self.anchor_row)
  }
  let left = if self.anchor_row < self.active_row {
    self.anchor_col
  } else if self.anchor_row > self.active_row {
    self.active_col
  } else {
    self.anchor_col.min(self.active_col)
  }
  let right = if self.anchor_row < self.active_row {
    self.active_col
  } else if self.anchor_row > self.active_row {
    self.anchor_col
  } else {
    self.anchor_col.max(self.active_col)
  }
  (top, left, bottom, right)
}

///|
/// 行是否在选中范围内。
pub fn Selection::contains_row(self : Selection, row : Int) -> Bool {
  let (top, _, bottom, _) = self.normalized()
  row >= top && row <= bottom
}

///|
/// 该行的选中列区间 [start, end);行不在范围内返回 None。
pub fn Selection::col_range_at(self : Selection, row : Int) -> (Int, Int)? {
  let (top, left, bottom, right) = self.normalized()
  if row < top || row > bottom {
    return None
  }
  let start = if row == top { left } else { 0 }
  let end = if row == bottom { right + 1 } else { 2147483647 }
  Some((start, end))
}

///|
/// 提取选中文本:每行截取选中列区间,行尾空白裁剪,行间以 \n 连接。
/// 宽字符(占 2 列)只取主格;continuation 格跳过。
pub fn selection_text(screen : TermScreen, selection : Selection?) -> String {
  match selection {
    None => ""
    Some(sel) => {
      let (top, _, bottom, _) = sel.normalized()
      let lines : Array[String] = []
      for row in top..<(bottom + 1) {
        if row < 0 || row >= screen.total_lines() {
          continue
        }
        let line = selection_line_text(screen.line_at(row), sel, row)
        lines.push(line)
      }
      let mut out = ""
      for i, line in lines {
        if i > 0 {
          out = out + "\n"
        }
        out = out + line
      }
      out
    }
  }
}

///|
fn selection_line_text(row : TermRow, sel : Selection, row_idx : Int) -> String {
  let (start, end) = match sel.col_range_at(row_idx) {
    Some(range) => range
    None => return ""
  }
  let mut text = ""
  let mut col = 0
  for cell in row.cells {
    if col >= end {
      break
    }
    if col >= start && cell.width > 0 {
      text = text + cell.ch
    }
    col = col + cell.width.max(1)
  }
  // 仅裁剪行尾空白(与终端显示一致);前导空格必须保留,
  // 否则选中带缩进的内容会丢失缩进
  trim_trailing_spaces(text)
}
