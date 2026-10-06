///|
/// Studio Markdown 显示投影（M4）：AI 回复的 markdown 子集 → 块模型的
/// **纯函数解析**。这是显示层的投影，不是编辑器——与 `moui_richtext` 的
/// 编辑级 Markdown 域（会话/增量解析/表格/引用全支持）刻意不同：本包只认
/// 一个显式子集，**子集外的语法一律按纯文本段落诚实降级**（不吞不猜），
/// 这样渲染层永远能对用户展示「模型到底说了什么」。
///
/// 子集：标题(1-3)/段落/无序列表/有序列表/围栏代码块/行内代码/粗体/斜体/
/// 分隔线。逐行解析（连续普通行合并为一个段落）；行内样式不嵌套（粗体内
/// 是纯文本）；斜体只认 `*…*`（`_…_` 会与标识符冲突，保持字面）。

///|
/// 行内片段：段落/列表项文本的着色单元。
pub(all) enum MarkdownInline {
  MiText(String)
  MiCode(String)
  MiBold(String)
  MiItalic(String)
}

///|
/// 块模型：解析产物（渲染层的唯一输入）。
pub(all) enum MarkdownBlock {
  /// 1-3 级标题 + 文本（去掉 # 前缀后的内容）
  MbHeading(Int, String)
  /// 段落（一段连续普通文本的行内片段序列）
  MbParagraph(Array[MarkdownInline])
  /// 无序列表：每项一组行内片段
  MbBulletList(Array[Array[MarkdownInline]])
  /// 有序列表：每项一组行内片段
  MbOrderedList(Array[Array[MarkdownInline]])
  /// 围栏代码块：语言标签（可空）+ 代码全文（含内部换行）
  MbCodeBlock(String, String)
  /// 水平分隔线（--- / *** / ___，三个以上同类字符）
  MbRule
}

///|
/// 解析入口：markdown 源 → 块序列。纯函数、确定性、双目标。
pub fn parse_markdown(source : String) -> Array[MarkdownBlock] {
  let blocks : Array[MarkdownBlock] = []
  let lines : Array[String] = split_lines(source)
  let paragraph : Array[Array[MarkdownInline]] = []
  let flush_paragraph = fn() {
    if paragraph.length() > 0 {
      // 连续行合并为一段；行间插软换行（CommonMark 口径——直接拼接会
      // 把英文换行词粘死，CJK 渲染层再把 \n 当普通留白处理）
      let flat : Array[MarkdownInline] = []
      let mut line_index = 0
      for piece in paragraph {
        if line_index > 0 {
          flat.push(MiText("\n"))
        }
        for inline in piece {
          flat.push(inline)
        }
        line_index = line_index + 1
      }
      blocks.push(MbParagraph(flat))
      paragraph.clear()
    }
  }
  let mut index = 0
  let count = lines.length()
  while index < count {
    let line = lines[index]
    // 围栏代码块优先（``` 或 ~~~ 起头，语言标签可选）
    let fence = fence_of(line)
    match fence {
      Some((marker, lang)) => {
        flush_paragraph()
        let code_lines : Array[String] = []
        index = index + 1
        // 未闭合围栏：吃到结尾（诚实——围栏意图明确，仍按代码块处理）
        while index < count {
          let inner = lines[index]
          if fence_of(inner) is Some((close_marker, _)) && close_marker == marker {
            break
          }
          code_lines.push(inner)
          index = index + 1
        }
        blocks.push(MbCodeBlock(lang, join_lines(code_lines)))
        index = index + 1
        continue
      }
      None => ()
    }
    // 空行 = 段落分隔
    if line.trim() == "" {
      flush_paragraph()
      index = index + 1
      continue
    }
    // 分隔线：--- / *** / ___（三个以上同类字符，允许空格）
    if is_rule(line) {
      flush_paragraph()
      blocks.push(MbRule)
      index = index + 1
      continue
    }
    // 标题：# 到 ###（#### 及更多 = 未支持，降级为普通段落行）
    if starts_with_hashes(line) is Some(level) {
      if level <= 3 {
        flush_paragraph()
        let text = strip_hashes(line, level)
        blocks.push(MbHeading(level, text))
        index = index + 1
        continue
      }
      // 降级：走普通段落
    }
    // 无序列表：- 或 * 起头 + 空格
    let bullet = bullet_item_text(line)
    match bullet {
      Some(text) => {
        flush_paragraph()
        let items : Array[Array[MarkdownInline]] = [parse_inline(text)]
        index = index + 1
        while index < count {
          match bullet_item_text(lines[index]) {
            Some(next_text) => {
              items.push(parse_inline(next_text))
              index = index + 1
            }
            None => break
          }
        }
        blocks.push(MbBulletList(items))
        continue
      }
      None => ()
    }
    // 有序列表：数字 + . + 空格
    let ordered = ordered_item_text(line)
    match ordered {
      Some(text) => {
        flush_paragraph()
        let items : Array[Array[MarkdownInline]] = [parse_inline(text)]
        index = index + 1
        while index < count {
          match ordered_item_text(lines[index]) {
            Some(next_text) => {
              items.push(parse_inline(next_text))
              index = index + 1
            }
            None => break
          }
        }
        blocks.push(MbOrderedList(items))
        continue
      }
      None => ()
    }
    // 普通行：进段落（连续行合并；表格/引用/HTML 等**未支持语法原样保留**，
    // 由行内解析降级为纯文本——诚实降级的落点）
    paragraph.push(parse_inline(line))
    index = index + 1
  }
  flush_paragraph()
  blocks
}

///|
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder()
  for c in source {
    if c == '\n' {
      lines.push(buf.to_string())
      buf.reset()
    } else if c != '\r' {
      buf.write_char(c)
    }
  }
  lines.push(buf.to_string())
  // 结尾换行不产生空块
  if lines.length() > 1 && lines[lines.length() - 1] == "" {
    let _ = lines.remove(lines.length() - 1)
  }
  lines
}

///|
fn join_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for line in lines {
    if index > 0 {
      buf.write_char('\n')
    }
    buf.write_string(line)
    index = index + 1
  }
  buf.to_string()
}

///|
/// 围栏识别：返回（标记字符, 语言标签）。``` 与 ~~~ 均认；``` 后到行尾的
/// 首个词为语言标签。
fn fence_of(line : String) -> (String, String)? {
  let trimmed = line.trim().to_owned()
  if trimmed.has_prefix("```") {
    Some(("```", first_word(drop_chars(trimmed, 3))))
  } else if trimmed.has_prefix("~~~") {
    Some(("~~~", first_word(drop_chars(trimmed, 3))))
  } else {
    None
  }
}

///|
fn first_word(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    if c == ' ' || c == '\t' {
      break
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// 丢掉前 n 个字符后的剩余文本（无内建 substring 依赖，逐字符重建）。
fn drop_chars(text : String, n : Int) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for c in text {
    if index >= n {
      buf.write_char(c)
    }
    index = index + 1
  }
  buf.to_string()
}

///|
/// 分隔线：三个以上同类字符（- * _），允许中间空格。
fn is_rule(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if trimmed.length() < 3 {
    return false
  }
  let chars : Array[Char] = []
  for c in trimmed {
    chars.push(c)
  }
  let marker = chars[0]
  if marker != '-' && marker != '*' && marker != '_' {
    return false
  }
  let mut same = 0
  for c in chars {
    if c == marker {
      same = same + 1
    } else if c == ' ' {
      continue
    } else {
      return false
    }
  }
  same >= 3
}

///|
/// 标题前缀：返回 # 的个数（无 # 前缀返回 None）。
fn starts_with_hashes(line : String) -> Int? {
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix("#") {
    return None
  }
  let mut level = 0
  for c in trimmed {
    if c == '#' {
      level = level + 1
    } else {
      break
    }
  }
  Some(level)
}

///|
fn strip_hashes(line : String, level : Int) -> String {
  let trimmed = line.trim().to_owned()
  // 跳过 level 个 # 后再 trim 一层空格
  drop_chars(trimmed, level).trim().to_owned()
}

///|
/// 无序列表项：`- ` 或 `* ` 起头（单个符号 + 空格）；否则 None。
fn bullet_item_text(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  if trimmed.has_prefix("- ") {
    return Some(drop_chars(trimmed, 2).trim().to_owned())
  }
  // 单个 * 才是列表；** 粗体开头的行不是列表
  if trimmed.has_prefix("* ") {
    return Some(drop_chars(trimmed, 2).trim().to_owned())
  }
  None
}

///|
/// 有序列表项：数字 + `.` + 空格；否则 None。
fn ordered_item_text(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  let chars : Array[Char] = []
  for c in trimmed {
    chars.push(c)
  }
  let mut digits = 0
  for c in chars {
    if c >= '0' && c <= '9' {
      digits = digits + 1
    } else {
      break
    }
  }
  if digits == 0 || digits >= chars.length() {
    return None
  }
  // 点后必须有内容（允许无空格：1.列表 也认）
  if chars[digits] == '.' && digits + 1 < chars.length() {
    let rest_start = if chars[digits + 1] == ' ' { digits + 2 } else { digits + 1 }
    let buf = StringBuilder()
    let mut index = rest_start
    while index < chars.length() {
      buf.write_char(chars[index])
      index = index + 1
    }
    return Some(buf.to_string().trim().to_owned())
  }
  None
}
