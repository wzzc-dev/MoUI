///|
/// 代码情报（切片 H）：补全与跳转声明。
///
/// 为什么不做 LSP：本视图编辑的是** DSL 源码**（IR 的渲染投影），不是
/// 自由 MoonBit——DSL 的「语言服务器」就是域包本身：关键字表、内建目录、
/// 草稿分词器与 IR 全部在进程内。Ctrl+Space 补全与「跳到声明」直接读
/// 这些结构，零网络零子进程。

///|
/// 光标处的词（标识符；中文/ASCII 同口径）：返回 (词, 词首偏移)。
pub fn word_at_caret(source : String, caret : Int) -> (String, Int) {
  let chars = source.to_array()
  let pos = caret.clamp(min=0, max=chars.length())
  let is_word = fn(c : Char) {
    let code = c.to_int()
    code >= 0x80 ||
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F
  }
  let mut start = pos
  while start > 0 && is_word(chars[start - 1]) {
    start = start - 1
  }
  let mut end = pos
  while end < chars.length() && is_word(chars[end]) {
    end = end + 1
  }
  (String::from_array(chars[start:end]), start)
}

///|
/// 补全候选：当前语言关键字 + 内建显示名 + 草稿里声明过的变量/控件名，
/// 按光标词前缀过滤（空词 = 全量，前 12 条）。
pub fn completions_for(model : Model, prefix : String) -> Array[String] {
  let candidates : Array[String] = []
  let language = model.language.dsl_language()
  let keywords = @studio_lang.keywords_for(language)
  for keyword in [
    keywords.declare_kw,
    keywords.if_kw,
    keywords.else_kw,
    keywords.else_if_kw,
    keywords.end_kw,
    keywords.count_kw,
    keywords.while_kw,
    keywords.break_kw,
    keywords.return_kw,
    keywords.true_kw,
    keywords.false_kw,
  ] {
    candidates.push(keyword)
  }
  for entry in @studio_lang.builtin_catalog() {
    candidates.push(
      match language {
        @studio_lang.ZhHans => entry.zh
        @studio_lang.En => entry.en
      },
    )
  }
  for control in model.program.controls {
    candidates.push(control.name)
  }
  // 草稿中的局部声明（变量 x / let x）
  for line_text in split_line_texts(model.code_draft) {
    let trimmed = line_text.trim().to_owned()
    let declare_kw_prefix = keywords.declare_kw + " "
    if trimmed.has_prefix(declare_kw_prefix) && trimmed.length() > declare_kw_prefix.length() {
      let rest = trimmed[declare_kw_prefix.length():].to_owned()
      let mut name = rest
      if rest.rev_find(" ") is Some(index) {
        name = rest[:index].to_owned()
      } else if rest.rev_find("=") is Some(index) {
        name = rest[:index].to_owned()
      }
      let name = name.trim().to_owned()
      if name != "" && !candidates.contains(name) {
        candidates.push(name)
      }
    }
  }
  let filtered : Array[String] = []
  for candidate in candidates {
    if prefix == "" || candidate.has_prefix(prefix) {
      filtered.push(candidate)
    }
    if filtered.length() >= 12 {
      break
    }
  }
  filtered
}

///|
/// 补全候选 → 插入文本与光标位置：替换光标处的完整词。
pub fn apply_completion(
  source : String,
  caret : Int,
  completion : String,
) -> (String, Int) {
  let (word, start) = word_at_caret(source, caret)
  let text = source[:start].to_owned() + completion + source[start + word.length():].to_owned()
  (text, start + completion.length())
}

///|
/// 跳到声明：光标词在草稿中的首次声明行（`变量 词` / `let 词`），
/// 找不到声明行时找首次出现行。返回 1 起行号（0 = 无处可跳）。
pub fn declaration_line_of(model : Model, caret : Int) -> Int {
  let (word, _) = word_at_caret(model.code_draft, caret)
  if word == "" {
    return 0
  }
  let lines = split_line_texts(model.code_draft)
  let keywords = @studio_lang.keywords_for(model.language.dsl_language())
  let declare_kw_prefix = keywords.declare_kw + " "
  let declare_en = "let "
  let mut first_use = 0
  let mut line_number = 1
  for line_text in lines {
    if line_text.contains(word) {
      let trimmed = line_text.trim().to_owned()
      let is_declare = trimmed.has_prefix(declare_kw_prefix + word) ||
        trimmed.has_prefix(declare_en + word)
      if is_declare {
        return line_number
      }
      if first_use == 0 {
        first_use = line_number
      }
    }
    line_number = line_number + 1
  }
  first_use
}
