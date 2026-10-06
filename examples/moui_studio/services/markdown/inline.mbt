///|
/// 行内解析：`代码`、**粗体**、*斜体*。顺序敏感：代码优先（反引号内
/// 的 `*` 不参与样式）；粗体先于斜体（`**` 不被切成两个斜体）；未闭合
/// 的标记**保持字面**（诚实降级——不吞字符也不猜闭合位置）。
pub fn parse_inline(text : String) -> Array[MarkdownInline] {
  let pieces : Array[MarkdownInline] = []
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let plain = fn(buf : StringBuilder) {
    if buf.to_string() != "" {
      pieces.push(MiText(buf.to_string()))
      buf.reset()
    }
  }
  let buf = StringBuilder()
  let mut index = 0
  let count = chars.length()
  while index < count {
    let c = chars[index]
    // 行内代码：`…`（内容原样，不解析内嵌样式）
    if c == '`' {
      plain(buf)
      let inner = scan_until(chars, index + 1, '`')
      match inner {
        Some((content, next)) => {
          pieces.push(MiCode(content))
          index = next
          continue
        }
        None => {
          // 未闭合：反引号保持字面
          buf.write_char(c)
          index = index + 1
          continue
        }
      }
    }
    // 粗体：**…**
    if c == '*' && index + 1 < count && chars[index + 1] == '*' {
      plain(buf)
      let inner = scan_until_double_star(chars, index + 2)
      match inner {
        Some((content, next)) => {
          pieces.push(MiBold(content))
          index = next
          continue
        }
        None => {
          // 未闭合：** 保持字面
          buf.write_char(c)
          buf.write_char('*')
          index = index + 2
          continue
        }
      }
    }
    // 斜体：*…*（不与粗体冲突——上面已消费 **）
    if c == '*' {
      plain(buf)
      let inner = scan_until(chars, index + 1, '*')
      match inner {
        Some((content, next)) => {
          pieces.push(MiItalic(content))
          index = next
          continue
        }
        None => {
          buf.write_char(c)
          index = index + 1
          continue
        }
      }
    }
    buf.write_char(c)
    index = index + 1
  }
  plain(buf)
  pieces
}

///|
/// 从 start 起扫描到 close 字符之前，返回（区间文本, close 后的下标）。
fn scan_until(
  chars : Array[Char],
  start : Int,
  close : Char,
) -> (String, Int)? {
  let buf = StringBuilder()
  let mut index = start
  while index < chars.length() {
    if chars[index] == close {
      return Some((buf.to_string(), index + 1))
    }
    buf.write_char(chars[index])
    index = index + 1
  }
  None
}

///|
/// 粗体扫描：找下一个 `**`。
fn scan_until_double_star(chars : Array[Char], start : Int) -> (String, Int)? {
  let buf = StringBuilder()
  let mut index = start
  while index < chars.length() {
    if chars[index] == '*' && index + 1 < chars.length() && chars[index + 1] == '*' {
      return Some((buf.to_string(), index + 2))
    }
    buf.write_char(chars[index])
    index = index + 1
  }
  None
}
