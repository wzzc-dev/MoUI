///|
/// 结构化语言错误：内核语言中立，可读文案由界面层经 i18n catalog 渲染。
/// a/b 是数据槽（词、名字、规范 id 等），不含成品句子。

///|
pub(all) enum LangErrorKind {
  UnterminatedString
  BadNumber
  ExpectKeyword // a=期望关键字, b=实际 token
  UnexpectedToken // a=实际 token
  ReservedWord // a=词
  MissingEnd // a=结束关键字
  UnknownName // a=名字
  NotDeclared // a=名字
  TypeMismatch // a=角色, b=期望/实际
  ArityMismatch // a=内建显示名, b=期望/实际
  StepBudget
  DivideByZero
  BadLoopCount
  UnknownBuiltin // a=名字
  BreakOutsideLoop
}

///|
pub(all) suberror LangError {
  LangError(LangErrorKind, Int, String, String)
}

///|
pub fn LangError::kind(self : LangError) -> LangErrorKind {
  match self {
    LangError(kind, _, _, _) => kind
  }
}

///|
pub fn LangError::line(self : LangError) -> Int {
  match self {
    LangError(_, line, _, _) => line
  }
}

///|
pub fn LangError::a(self : LangError) -> String {
  match self {
    LangError(_, _, a, _) => a
  }
}

///|
pub fn LangError::b(self : LangError) -> String {
  match self {
    LangError(_, _, _, b) => b
  }
}

///|
/// token 的中性标签（两种语言共用「」引用格式）。
fn token_label(kind : TokenKind) -> String {
  match kind {
    Ident(text) => "「\{text}」"
    Num(n) => "数字 \{n}"
    Int(n) => "数字 \{n}"
    LBracket => "["
    RBracket => "]"
    Str(_) => "字符串"
    Newline => "换行"
    LParen => "("
    RParen => ")"
    Comma => ","
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Eq => "="
    Ne => "<>"
    Lt => "<"
    Gt => ">"
    Le => "<="
    Ge => ">="
    Eof => "结尾"
  }
}
