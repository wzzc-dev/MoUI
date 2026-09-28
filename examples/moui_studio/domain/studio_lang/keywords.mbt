///|
/// MoUI Studio 语言：中英双语关键字表与内建命令目录。
/// 关键字/内建名是 catalog 数据（解释器禁止按字面量硬编码分支）；
/// IR 只存规范 id（英文名），界面按当前语言渲染。

///|
pub(all) enum Language {
  ZhHans
  En
}

///|
pub fn Language::tag(self : Language) -> String {
  match self {
    ZhHans => "zh-Hans"
    En => "en"
  }
}

///|
pub fn parse_language(text : String) -> Language? {
  match text {
    "zh-Hans" | "zh" | "zh_CN" | "zh-CN" => Some(ZhHans)
    "en" | "en-US" | "en_US" => Some(En)
    _ => None
  }
}

///|
/// 一门语言的全部语句关键字。
pub(all) struct Keywords {
  declare_kw : String // 变量 / let
  if_kw : String // 如果 / if
  then_kw : String // 则 / then
  else_if_kw : String // 否则如果 / elseif
  else_kw : String // 否则 / else
  end_kw : String // 结束 / end
  count_kw : String // 计次循环 / repeat
  times_kw : String // 次 / times
  as_kw : String // 为 / as
  while_kw : String // 当 / while
  do_kw : String // 循环 / do
  break_kw : String // 跳出循环 / break
  true_kw : String // 真 / true
  false_kw : String // 假 / false
  and_kw : String // 且 / and
  or_kw : String // 或 / or
  not_kw : String // 非 / not
}

///|
pub fn keywords_for(language : Language) -> Keywords {
  match language {
    ZhHans =>
      Keywords::{
        declare_kw: "变量",
        if_kw: "如果",
        then_kw: "则",
        else_if_kw: "否则如果",
        else_kw: "否则",
        end_kw: "结束",
        count_kw: "计次循环",
        times_kw: "次",
        as_kw: "为",
        while_kw: "当",
        do_kw: "循环",
        break_kw: "跳出循环",
        true_kw: "真",
        false_kw: "假",
        and_kw: "且",
        or_kw: "或",
        not_kw: "非",
      }
    En =>
      Keywords::{
        declare_kw: "let",
        if_kw: "if",
        then_kw: "then",
        else_if_kw: "elseif",
        else_kw: "else",
        end_kw: "end",
        count_kw: "repeat",
        times_kw: "times",
        as_kw: "as",
        while_kw: "while",
        do_kw: "do",
        break_kw: "break",
        true_kw: "true",
        false_kw: "false",
        and_kw: "and",
        or_kw: "or",
        not_kw: "not",
      }
  }
}

///|
/// 内建种类：命令（语句位）、函数（表达式位）、闸门（暂停等人）。
pub(all) enum BuiltinKind {
  Command
  Function
  Gate
}

///|
/// 内建目录项。id 是规范名（IR 与导出 bundle 用它），zh/en 是两种语言的显示名。
pub(all) struct BuiltinSpec {
  id : String
  zh : String
  en : String
  kind : BuiltinKind
  arity : Int
}

///|
/// v1 内建目录：6 命令 + 2 闸门 + 4 函数 = 12 个。
pub fn builtin_catalog() -> Array[BuiltinSpec] {
  [
    BuiltinSpec::{
      id: "message_box",
      zh: "信息框",
      en: "message_box",
      kind: Command,
      arity: 1,
    },
    BuiltinSpec::{
      id: "set_text",
      zh: "设置文本",
      en: "set_text",
      kind: Command,
      arity: 2,
    },
    BuiltinSpec::{
      id: "append_row",
      zh: "追加行",
      en: "append_row",
      kind: Command,
      arity: 2,
    },
    BuiltinSpec::{
      id: "get_text",
      zh: "取文本",
      en: "get_text",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "get_number",
      zh: "取数值",
      en: "get_number",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "to_text",
      zh: "转文本",
      en: "to_text",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "text_length",
      zh: "取长度",
      en: "text_length",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "contains",
      zh: "文本包含",
      en: "contains",
      kind: Function,
      arity: 2,
    },
    BuiltinSpec::{
      id: "random",
      zh: "随机数",
      en: "random",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "row_count",
      zh: "取行数",
      en: "row_count",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "row_at",
      zh: "取行",
      en: "row_at",
      kind: Function,
      arity: 2,
    },
    BuiltinSpec::{ id: "ask", zh: "询问", en: "ask", kind: Gate, arity: 1, },
    BuiltinSpec::{
      id: "selected_row",
      zh: "取所选行",
      en: "selected_row",
      kind: Function,
      arity: 1,
    },
    BuiltinSpec::{
      id: "submit_data",
      zh: "提交数据",
      en: "submit_data",
      kind: Gate,
      arity: 2,
    },
  ]
}

///|
/// 中/英显示名 → 规范项（IR 存的总是 spec.id）。
pub fn find_builtin(name : String) -> BuiltinSpec? {
  for spec in builtin_catalog() {
    if spec.zh == name || spec.en == name || spec.id == name {
      return Some(spec)
    }
  }
  None
}

///|
/// 规范 id → 当前语言显示名。
pub fn builtin_display(id : String, language : Language) -> String {
  for spec in builtin_catalog() {
    if spec.id == id {
      return match language {
        ZhHans => spec.zh
        En => spec.en
      }
    }
  }
  id
}

///|
pub fn builtin_kind(id : String) -> BuiltinKind? {
  match find_builtin(id) {
    Some(spec) => Some(spec.kind)
    None => None
  }
}

///|
/// 保留字 = 两门语言全部关键字的并集（任一种语言里都不能当变量名）。
pub fn is_reserved(text : String) -> Bool {
  let zh = keywords_for(ZhHans)
  let en = keywords_for(En)
  text == zh.declare_kw ||
  text == zh.if_kw ||
  text == zh.then_kw ||
  text == zh.else_if_kw ||
  text == zh.else_kw ||
  text == zh.end_kw ||
  text == zh.count_kw ||
  text == zh.times_kw ||
  text == zh.as_kw ||
  text == zh.while_kw ||
  text == zh.do_kw ||
  text == zh.break_kw ||
  text == zh.true_kw ||
  text == zh.false_kw ||
  text == zh.and_kw ||
  text == zh.or_kw ||
  text == zh.not_kw ||
  text == en.declare_kw ||
  text == en.if_kw ||
  text == en.then_kw ||
  text == en.else_if_kw ||
  text == en.else_kw ||
  text == en.end_kw ||
  text == en.count_kw ||
  text == en.times_kw ||
  text == en.as_kw ||
  text == en.while_kw ||
  text == en.do_kw ||
  text == en.break_kw ||
  text == en.true_kw ||
  text == en.false_kw ||
  text == en.and_kw ||
  text == en.or_kw ||
  text == en.not_kw
}

///|
/// 语句关键字在某一门语言里的分类：解析器用它分派，避免字面量分支。
pub(all) enum StmtKeyword {
  KwDeclare
  KwIf
  KwCountLoop
  KwWhile
  KwBreak
  NoneKw
}

///|
pub fn classify_stmt_keyword(text : String, keywords : Keywords) -> StmtKeyword {
  if text == keywords.declare_kw {
    KwDeclare
  } else if text == keywords.if_kw {
    KwIf
  } else if text == keywords.count_kw {
    KwCountLoop
  } else if text == keywords.while_kw {
    KwWhile
  } else if text == keywords.break_kw {
    KwBreak
  } else {
    NoneKw
  }
}
