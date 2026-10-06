///|
/// Studio 内核·高亮服务（M6①）：词法着色的类型化扩展点。
///
/// 设计：token 模型与词法器接口归内核（app 无关、双目标可测），具体
/// 词法器作为 provider 按语言 id 注册——MoonBit 词法器**随内核发布**
/// （本文件），Studio DSL 词法器在 app 侧注册（依赖 @studio_lang）。
/// 着色是渲染层事实：解析失败只降级纯文本，绝不改变语义。

///|
/// token 语义分类（渲染层取色）。
pub(all) enum HighlightKind {
  HlPlain
  HlKeyword
  HlString
  HlNumber
  HlComment
  HlBuiltin
} derive(Eq)

///|
pub extend HighlightKind with Eq::{not_equal, equal}

///|
/// 单个 token：全文绝对偏移 + 原文 + 分类（偏移供受控编辑器的
/// source_range 约定使用）。
pub(all) struct HighlightToken {
  start : Int
  text : String
  kind : HighlightKind
}

///|
/// 词法器 provider：语言 id + 全文分词（返回的 tokens 按 start 升序、
/// 覆盖全文不重叠；任何输入都不 panic——失败降级纯文本）。
pub(all) struct Highlighter {
  language : String
  run : (String) -> Array[HighlightToken]
}

///|
/// 高亮服务：provider 注册表（组合根注册；按语言 id 分派）。
pub(all) struct HighlightService {
  highlighters : Array[Highlighter]
}

///|
pub fn HighlightService::new() -> HighlightService {
  { highlighters: [], }
}

///|
/// 注册一个词法器（同 id 后注册者优先——组合根覆盖语义）。
pub fn HighlightService::register(
  self : HighlightService,
  highlighter : Highlighter,
) -> Unit {
  self.highlighters.push(highlighter)
}

///|
/// 按语言 id 分派（无注册 = None → 调用方降级纯文本）。
pub fn HighlightService::dispatch(
  self : HighlightService,
  language : String,
) -> Highlighter? {
  let mut found : Highlighter? = None
  for highlighter in self.highlighters {
    if highlighter.language == language {
      found = Some(highlighter)
    }
  }
  found
}

///|
/// MoonBit 关键字表（着色用词形分类，不参与任何语义判断）。
fn moonbit_keywords() -> Array[String] {
  [
    "fn", "let", "mut", "pub", "priv", "struct", "enum", "trait", "impl", "if", "else",
    "match", "while", "for", "loop", "in", "break", "continue", "return", "true",
    "false", "as", "is", "not", "and", "or", "type", "const", "import", "export",
    "extern", "derive", "test", "guard", "raise", "try", "catch", "async", "using",
    "typealias", "case",
  ]
}

///|
/// MoonBit 内建/惯例名（小写内建函数与大写类型首识别词）。
fn moonbit_builtins() -> Array[String] {
  ["println", "ignore", "abort", "Some", "None", "Ok", "Err", "Unit"]
}

///|
/// MoonBit 词法器：`//` 行注释、`/* */` 块注释、字符串（`\"` 转义不
/// 结束字符串；`\{...}` 插值段按代码着色并容忍嵌套字符串）、数字、
/// 关键字、内建/大写类型名；其余纯文本。
pub fn moonbit_highlight(source : String) -> Array[HighlightToken] {
  let tokens : Array[HighlightToken] = []
  let chars : Array[Char] = []
  for c in source {
    chars.push(c)
  }
  let count = chars.length()
  let push = fn(start : Int, text : String, kind : HighlightKind) {
    if text != "" {
      tokens.push({ start, text, kind, })
    }
  }
  let is_word = fn(c : Char) {
    let code = c.to_int()
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F
  }
  // 插值深度：>0 时处于 \{...} 内（内部字符串仍按字符串着色）
  let mut depth = 0
  let plain = fn(start : Int, end : Int) {
    push(start, slice_chars(chars, start, end), HlPlain)
  }
  let mut index = 0
  while index < count {
    let c = chars[index]
    let c2 = if index + 1 < count { chars[index + 1] } else { '\u{0}' }
    // 行注释
    if c == '/' && c2 == '/' {
      let mut end = index
      while end < count && chars[end] != '\n' {
        end = end + 1
      }
      push(index, slice_chars(chars, index, end), HlComment)
      index = end
      continue
    }
    // 块注释（单层）
    if c == '/' && c2 == '*' {
      let mut end = index + 2
      while end + 1 < count && !(chars[end] == '*' && chars[end + 1] == '/') {
        end = end + 1
      }
      let stop = if end + 1 < count { end + 2 } else { count }
      push(index, slice_chars(chars, index, stop), HlComment)
      index = stop
      continue
    }
    // 字符串：\{ 打开插值段（插值内按普通代码着色，容忍嵌套字符串）
    if c == '"' {
      let str_start = index
      index = index + 1
      let mut seg_start = index
      let mut closed = false
      while index < count {
        let sc = chars[index]
        if sc == '\\' && index + 1 < count {
          let next = chars[index + 1]
          if next == '{' {
            // 插值开始：先收当前字符串段（含 \{ 两字符，避免覆盖缺口）
            push(str_start, slice_chars(chars, str_start, index + 2), HlString)
            depth = depth + 1
            index = index + 2
            seg_start = index
            // 插值内扫描：字符串/括号嵌套由主循环的字符串与深度逻辑处理
            let mut inner_end = -1
            let mut inner_index = index
            let mut inner_depth = 1
            while inner_index < count && inner_end < 0 {
              let ic = chars[inner_index]
              if ic == '"' {
                // 嵌套字符串：跳过（容忍 \" 转义）
                inner_index = inner_index + 1
                while inner_index < count {
                  if chars[inner_index] == '\\' {
                    inner_index = inner_index + 2
                    continue
                  }
                  if chars[inner_index] == '"' {
                    break
                  }
                  inner_index = inner_index + 1
                }
              } else if ic == '{' {
                inner_depth = inner_depth + 1
              } else if ic == '}' {
                inner_depth = inner_depth - 1
                if inner_depth == 0 {
                  inner_end = inner_index
                  break
                }
              }
              inner_index = inner_index + 1
            }
            let stop = if inner_end < 0 { count } else { inner_end }
            // 插值内容按纯文本着色（v1：不递归关键字）
            push(seg_start, slice_chars(chars, seg_start, stop), HlPlain)
            if inner_end >= 0 {
              push(inner_end, "}", HlString)
              index = inner_end + 1
              depth = depth - 1
              seg_start = index
              // 继续字符串剩余部分（含闭引号；未闭合到结尾同样收尾）
              while index < count {
                let tc = chars[index]
                if tc == '\\' && index + 1 < count {
                  index = index + 2
                  continue
                }
                if tc == '"' {
                  index = index + 1
                  break
                }
                index = index + 1
              }
              push(seg_start, slice_chars(chars, seg_start, index), HlString)
              // 插值路径自带完整收尾：不触发兜底
              closed = true
            } else {
              index = count
            }
            break
          }
          // 普通转义：跳过两字符
          index = index + 2
          continue
        }
        if sc == '"' {
          // 字符串结束（无插值路径）
          push(str_start, slice_chars(chars, str_start, index + 1), HlString)
          closed = true
          index = index + 1
          break
        }
        index = index + 1
      }
      // 未闭合（无插值）：尾段按字符串收尾（不吞不崩）
      if !closed && index >= count {
        push(str_start, slice_chars(chars, str_start, count), HlString)
      }
      continue
    }
    // 数字
    if c >= '0' && c <= '9' {
      let start = index
      while index < count {
        let nc = chars[index]
        if (nc >= '0' && nc <= '9') ||
          nc == '.' ||
          (nc >= 'a' && nc <= 'f') ||
          (nc >= 'A' && nc <= 'F') ||
          nc == 'x' ||
          nc == 'o' ||
          nc == 'L' ||
          nc == 'U' {
          index = index + 1
        } else {
          break
        }
      }
      push(start, slice_chars(chars, start, index), HlNumber)
      continue
    }
    // 标识符：关键字 / 内建 / 大写类型名
    if is_word(c) && !(c >= '0' && c <= '9') {
      let start = index
      let first = c
      while index < count && is_word(chars[index]) {
        index = index + 1
      }
      let word = slice_chars(chars, start, index)
      let head_code = first.to_int()
      let kind = if moonbit_keywords().contains(word) {
        HlKeyword
      } else if moonbit_builtins().contains(word) {
        HlBuiltin
      } else if head_code >= 0x41 && head_code <= 0x5A {
        HlBuiltin
      } else {
        HlPlain
      }
      push(start, word, kind)
      continue
    }
    // 其余：与相邻纯文本合并（按 start 连续段推送）
    let start = index
    while index < count {
      let nc = chars[index]
      let nc2 = if index + 1 < count { chars[index + 1] } else { '\u{0}' }
      if nc == '"' ||
        (nc == '/' && (nc2 == '/' || nc2 == '*')) ||
        (nc >= '0' && nc <= '9') ||
        (is_word(nc) && !(nc >= '0' && nc <= '9')) {
        break
      }
      index = index + 1
    }
    plain(start, index)
  }
  tokens
}

///|
fn slice_chars(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}
