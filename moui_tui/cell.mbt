///|
/// 终端颜色:默认色、256 索引色、真彩色 RGB。
pub(all) enum TermColor {
  Default
  Indexed(Int32)
  Rgb(Int32, Int32, Int32)
} derive(Eq, Debug)

///|
pub extend TermColor with Debug::{to_repr}

///|
pub extend TermColor with Eq::{not_equal, equal}

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
pub extend CellAttrs with Debug::{to_repr}

///|
pub extend CellAttrs with Eq::{not_equal, equal}

///|
pub fn CellAttrs::default() -> CellAttrs {
  {
    fg: Default,
    bg: Default,
    bold: false,
    dim: false,
    italic: false,
    underline: false,
    reverse: false,
  }
}

///|
/// 复制属性并替换部分字段(SGR 序列用)。
pub fn attrs_with(
  attrs : CellAttrs,
  fg~ : TermColor? = None,
  bg~ : TermColor? = None,
  bold~ : Bool? = None,
  dim~ : Bool? = None,
  italic~ : Bool? = None,
  underline~ : Bool? = None,
  reverse~ : Bool? = None,
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
/// 复制属性并替换前景色。
pub fn attrs_with_fg(attrs : CellAttrs, fg : TermColor) -> CellAttrs {
  attrs_with(attrs, fg=Some(fg))
}

///|
/// 单元格:一个字符(宽字符占两格,第二格为 continuation,ch 为空)。
pub(all) struct Cell {
  ch : String
  width : Int32
  attrs : CellAttrs
} derive(Eq, Debug)

///|
pub extend Cell with Debug::{to_repr}

///|
pub extend Cell with Eq::{not_equal, equal}

///|
pub fn blank_cell(attrs : CellAttrs) -> Cell {
  { ch: " ", width: 1, attrs, }
}

///|
/// 宽字符右半格:`width == 0` 让它不产生文本,只继承底色。
pub fn continuation_cell(attrs : CellAttrs) -> Cell {
  { ch: "", width: 0, attrs, }
}

///|
/// 提取字符串首字符的 Unicode 码点(String::at 返回 UTF-16 code unit)。
fn utf8_codepoint(s : String) -> Int32 {
  let u = s[0].to_int()
  if u >= 0xD800 && u <= 0xDBFF && s.length() >= 2 {
    let lo = s[1].to_int()
    0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)
  } else {
    u
  }
}

///|
/// 简化 wcwidth:ASCII 1,常见宽字符区间 2,其余 1。
/// 组合符未合并进基字符格,按 1 计(投影器不区分带符与基符)。
pub fn unicode_width(ch : String) -> Int32 {
  let cp = utf8_codepoint(ch)
  if cp >= 0x20 && cp <= 0x7E {
    return 1
  }
  if (cp >= 0x1100 && cp <= 0x115F) ||
    (cp >= 0x2E80 && cp <= 0xA4CF) ||
    (cp >= 0xAC00 && cp <= 0xD7A3) ||
    (cp >= 0xF900 && cp <= 0xFAFF) ||
    (cp >= 0xFE30 && cp <= 0xFE4F) ||
    (cp >= 0xFF00 && cp <= 0xFF60) ||
    (cp >= 0xFFE0 && cp <= 0xFFE6) ||
    (cp >= 0x1F300 && cp <= 0x1FAFF) ||
    (cp >= 0x20000 && cp <= 0x3FFFD) {
    return 2
  }
  1
}
