///|
/// moon.mod / moon.pkg 共享的**容错语法原语**。
///
/// 两种清单都是「key = "value" 行 + `import { ... }` 块」的方言,观察到的
/// 实际文件(`examples/counter/moon.mod`、`examples/*/app/moon.pkg`)语法
/// 子集:key=value 行、多行/单行 import 块(尾部可带 `for "test"/"wbtest"`)、
/// `options(...)`(单行或多行)、`//` 注释。
///
/// 解析纪律:**宽容**——不认识的构造按行跳过;只有「我们需要的构造畸形」
/// 才报错(带文件与行号,结构化)。工程资源管理器宁可少读一个字段,也不
/// 因为一个未知语法拒绝整个工程。

///|
/// 单个导入条目的中间形态(模块级与包级共用;包级忽略 version)。
/// 条目形态:`"模块路径[@版本]" [@别名]?`。
priv struct ImportEntry {
  path : String
  version : String
  alias_name : String
}

///|
/// 去掉 `//` 行注释(首个 `//` 起截断)。
/// 已知局限:不识别字符串字面量内的 `//`(清单里没有 URL 类值,接受)。
fn strip_comment(text : String) -> String {
  let cut = index_of_double_slash(text)
  if cut < 0 {
    text
  } else {
    text[:cut].to_owned()
  }
}

///|
/// 找首个 `//` 的下标(无则 -1)。
fn index_of_double_slash(text : String) -> Int {
  let mut i = 0
  let mut prev = ' '
  let mut found = -1
  for c in text {
    if c == '/' && prev == '/' && found < 0 {
      found = i - 1
    }
    prev = c
    i = i + 1
  }
  found
}

///|
/// 字符下标查找(从 from 起,首个 target;无则 -1)。
fn index_of_char(text : String, target : Char, from : Int) -> Int {
  let chars = chars_of(text)
  let mut i = from
  let n = chars.length()
  while i < n {
    if chars[i] == target {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// 字符数组化:清单文件都很小,一次性展开换来可下标的扫描。
fn chars_of(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  chars
}

///|
/// 标识符字符(键名用):字母 / 数字 / 下划线 / 连字符。
fn is_ident_char(c : Char) -> Bool {
  let v = c.to_int()
  (v >= 65 && v <= 90) ||
  (v >= 97 && v <= 122) ||
  (v >= 48 && v <= 57) ||
  v == 95 ||
  v == 45
}

///|
/// 别名字符:标识符 + `/`——别名是包路径(`"moonbitlang/x/fs" @x/fs`,
/// 见 `services/compile_native/moon.pkg`),可以带斜杠。
fn is_alias_char(c : Char) -> Bool {
  is_ident_char(c) || c == '/'
}

///|
/// 从 `open`(开引号下标)读一个双引号字符串,返回 (内容, 结束引号下标)。
/// 支持 `\"` 转义(转义字符原样保留,清单值里不出现需要解转义的序列)。
/// 未闭合返回 None。
fn read_quoted(chars : Array[Char], open : Int) -> (String, Int)? {
  let n = chars.length()
  let mut out = ""
  let mut i = open + 1
  let mut escaped = false
  while i < n {
    let c = chars[i]
    if escaped {
      out = out + c.to_string()
      escaped = false
    } else if c == '\\' {
      escaped = true
    } else if c == '"' {
      return Some((out, i))
    } else {
      out = out + c.to_string()
    }
    i = i + 1
  }
  None
}

///|
/// 拆 `"wzzc-dev/moui@0.2.0"` → (wzzc-dev/moui, 0.2.0);无 @ 版本 → (原文, "")。
/// 只认**首个** @:模块路径不含 @。
fn split_path_version(raw : String) -> (String, String) {
  let chars = chars_of(raw)
  let mut at = -1
  let mut i = 0
  for c in chars {
    if c == '@' && at < 0 {
      at = i
    }
    i = i + 1
  }
  if at < 0 {
    (raw, "")
  } else {
    (raw[:at].to_owned(), raw[at + 1:].to_owned())
  }
}

///|
/// 解析一行 import 条目:`"a@1" @x, "b" @y` → 条目数组。
/// 只允许引号字符串、空白、逗号、@别名;别的字符是畸形。
fn parse_import_line(
  text : String,
  file : String,
  line_no : Int,
) -> Result[Array[ImportEntry], String] {
  let chars = chars_of(text)
  let n = chars.length()
  let entries : Array[ImportEntry] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c == ' ' || c == '\t' || c == ',' {
      i = i + 1
      continue
    }
    if c == '"' {
      match read_quoted(chars, i) {
        Some((raw, close)) => {
          let (path, version) = split_path_version(raw)
          if path == "" {
            return Err("\{file}:\{line_no}:空的导入路径")
          }
          let mut j = close + 1
          while j < n && (chars[j] == ' ' || chars[j] == '\t') {
            j = j + 1
          }
          let mut alias_name = ""
          if j < n && chars[j] == '@' {
            j = j + 1
            while j < n && is_alias_char(chars[j]) {
              alias_name = alias_name + chars[j].to_string()
              j = j + 1
            }
          }
          entries.push(ImportEntry::{ path, version, alias_name, })
          i = j
        }
        None => return Err("\{file}:\{line_no}:字符串未闭合")
      }
      continue
    }
    return Err(
      "\{file}:\{line_no}:导入条目里出现意外的字符「\{c}」",
    )
  }
  Ok(entries)
}

///|
/// 识别 `}` 之后的 `for "test" / "wbtest"` 子句;无则空串。
fn trailing_for_clause(text : String) -> String {
  let rest = text.trim(chars=" \t\r").to_owned()
  if !rest.has_prefix("for") {
    return ""
  }
  let quote = index_of_char(rest, '"', 3)
  if quote < 0 {
    return ""
  }
  let chars = chars_of(rest)
  match read_quoted(chars, quote) {
    Some((value, _)) => value
    None => ""
  }
}

///|
/// `key = "value"` 行解析:键必须紧贴行首(标识符),值必须是双引号字符串。
/// 不是这个形态返回 None(调用方按未知行跳过)。
fn parse_key_value(text : String) -> (String, String)? {
  let chars = chars_of(text)
  let n = chars.length()
  let mut i = 0
  while i < n && is_ident_char(chars[i]) {
    i = i + 1
  }
  if i == 0 || i >= n {
    return None
  }
  let key = text[:i].to_owned()
  // 键后到 = 之间只允许空白
  let mut j = i
  while j < n && (chars[j] == ' ' || chars[j] == '\t') {
    j = j + 1
  }
  if j >= n || chars[j] != '=' {
    return None
  }
  j = j + 1
  while j < n && (chars[j] == ' ' || chars[j] == '\t') {
    j = j + 1
  }
  if j >= n || chars[j] != '"' {
    return None
  }
  match read_quoted(chars, j) {
    Some((value, _)) => Some((key, value))
    None => None
  }
}

///|
/// 括号平衡增量(options(...) 的跨行跳过用):计数括号差。
fn paren_delta(text : String) -> Int {
  let mut depth = 0
  for c in text {
    if c == '(' {
      depth = depth + 1
    } else if c == ')' {
      depth = depth - 1
    }
  }
  depth
}
