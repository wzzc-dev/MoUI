///|
/// 递归下降解析器：源码 → IR（带行号 Trace）。
/// 关键字分派全部过 keywords 表；任一语言解析出的 IR 完全相同。

///|
/// 语句与其首 token 行号：运行错误能报行号；从 JSON 加载的程序行号为 0。
pub(all) struct TracedStmt {
  stmt : Stmt
  line : Int
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
  keywords : Keywords
}

///|
/// Trace 剥离：IR 的行号只服务于错误定位，不进程序树。
fn traced_to_stmts(body : Array[TracedStmt]) -> Array[Stmt] {
  body.map(traced => traced.stmt)
}

///|
/// 内建名规范化：源码里写中文名或英文名，IR 一律存规范 id。
/// 非内建名原样保留（由语义校验报 UnknownBuiltin）。
fn canonical_call_name(name : String) -> String {
  match find_builtin(name) {
    Some(spec) => spec.id
    None => name
  }
}

///|
/// 解析一段事件子程序体（语句序列）。
pub fn parse_handler_body(
  source : String,
  language : Language,
) -> Result[Array[TracedStmt], LangError] {
  let tokens = match lex(source) {
    Ok(tokens) => tokens
    Err(error) => return Err(error)
  }
  let parser = Parser::{ tokens, pos: 0, keywords: keywords_for(language), }
  try {
    let stmts = parser.parse_stmts_until([])
    parser.skip_newlines()
    if parser.peek().kind is Eof {
      Ok(stmts)
    } else {
      parser.fail_unexpected()
    }
  } catch {
    error => Err(error)
  }
}

///|
/// 只解析不运行：编辑器实时语法检查。
///|
/// 解析单表达式文本（全局变量初始值用）：失败给结构化错误。
pub fn parse_expression_text(
  source : String,
  language : Language,
) -> Result[Expr, LangError] {
  let tokens = match lex(source) {
    Ok(tokens) => tokens
    Err(error) => return Err(error)
  }
  let parser = Parser::{ tokens, pos: 0, keywords: keywords_for(language), }
  try {
    let expr = parser.parse_expr()
    if parser.peek().kind is Eof {
      Ok(expr)
    } else {
      parser.fail(UnexpectedToken, "表达式后有多余内容", "")
    }
  } catch {
    error => Err(error)
  }
}

///|
/// 解析顶层 struct 声明（M5-5c 前端②）：一段源文本（可含多个声明、
/// 声明间允许空行）→ `@ir.StructDecl` 数组，调用方填入
/// `StudioProgram.structs`。字段类型存规范 id（text/number/int/bool）。
///
/// 形式：`结构 Person { 名字: 文本, 年龄: 数字 }`
///      `struct Person { name: text, age: number }`
pub fn parse_struct_declarations(
  source : String,
  language : Language,
) -> Result[Array[@ir.StructDecl], LangError] {
  let tokens = match lex(source) {
    Ok(tokens) => tokens
    Err(error) => return Err(error)
  }
  let parser = Parser::{ tokens, pos: 0, keywords: keywords_for(language), }
  try {
    let decls : Array[@ir.StructDecl] = []
    parser.skip_newlines()
    while !(parser.peek().kind is Eof) {
      decls.push(parser.parse_struct_decl())
      parser.skip_newlines()
    }
    Ok(decls)
  } catch {
    error => Err(error)
  }
}

///|
/// 单个 struct 声明：结构 名 { 字段: 类型, … }。字段名与类型都是
/// 标识符；类型经 struct_field_type_id 归一化为规范 id。
fn Parser::parse_struct_decl(self : Parser) -> @ir.StructDecl raise LangError {
  self.expect_keyword(self.keywords.struct_kw)
  let name = match self.peek().kind {
    Ident(text) =>
      if is_reserved(text) {
        return self.fail(ReservedWord, text, "")
      } else {
        ignore(self.advance())
        text
      }
    _ => self.fail_expect_keyword(self.keywords.struct_kw)
  }
  if self.peek().kind is LBrace {
    ignore(self.advance())
  } else {
    self.fail_expect_keyword("{")
  }
  let fields : Array[@ir.StructField] = []
  if self.peek().kind is RBrace {
    ignore(self.advance())
    return @ir.StructDecl::{ name, fields, }
  }
  while true {
    let field_name = match self.peek().kind {
      Ident(text) =>
        if is_reserved(text) {
          return self.fail(ReservedWord, text, "")
        } else {
          ignore(self.advance())
          text
        }
      _ => self.fail(UnexpectedToken, "字段名应为标识符", "")
    }
    if self.peek().kind is Colon {
      ignore(self.advance())
    } else {
      self.fail_expect_keyword(":")
    }
    let field_type = match self.peek().kind {
      Ident(text) => match struct_field_type_id(text) {
        Some(id) => {
          ignore(self.advance())
          id
        }
        None =>
          self.fail(
            TypeMismatch,
            "字段类型",
            "文本/数字/整数/真假，遇到 「\{text}」",
          )
      }
      _ =>
        self.fail(
          TypeMismatch,
          "字段类型",
          "文本/数字/整数/真假，遇到 \{token_label(self.peek().kind)}",
        )
    }
    fields.push(@ir.StructField::{ field_name, field_type, })
    match self.peek().kind {
      Comma => ignore(self.advance())
      RBrace => {
        ignore(self.advance())
        break
      }
      _ => self.fail_expect_keyword(", 或 }")
    }
  }
  @ir.StructDecl::{ name, fields, }
}

///|
pub fn check_syntax(source : String, language : Language) -> LangError? {
  match parse_handler_body(source, language) {
    Ok(_) => None
    Err(error) => Some(error)
  }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.tokens[self.pos]
  if self.pos + 1 < self.tokens.length() {
    self.pos = self.pos + 1
  }
  token
}

///|
fn Parser::at_keyword(self : Parser, keyword : String) -> Bool {
  match self.peek().kind {
    Ident(text) => text == keyword
    _ => false
  }
}

///|
fn[T] Parser::fail(
  self : Parser,
  kind : LangErrorKind,
  a : String,
  b : String,
) -> T raise LangError {
  raise LangError(kind, self.peek().line, a, b)
}

///|
fn[T] Parser::fail_unexpected(self : Parser) -> T raise LangError {
  self.fail(UnexpectedToken, token_label(self.peek().kind), "")
}

///|
fn[T] Parser::fail_expect_keyword(
  self : Parser,
  keyword : String,
) -> T raise LangError {
  self.fail(ExpectKeyword, keyword, token_label(self.peek().kind))
}

///|
fn Parser::expect_keyword(
  self : Parser,
  keyword : String,
) -> Unit raise LangError {
  if !self.at_keyword(keyword) {
    self.fail_expect_keyword(keyword)
  }
  ignore(self.advance())
}

///|
fn Parser::expect_eq(self : Parser) -> Unit raise LangError {
  if self.peek().kind is Eq {
    ignore(self.advance())
  } else {
    self.fail_expect_keyword("=")
  }
}

///|
fn Parser::skip_newlines(self : Parser) -> Unit {
  while self.peek().kind is Newline {
    ignore(self.advance())
  }
}

///|
/// 解析语句序列直到 stop 里的关键字或结尾（不消耗终止符）。
fn Parser::parse_stmts_until(
  self : Parser,
  stop : Array[String],
) -> Array[TracedStmt] raise LangError {
  let stmts : Array[TracedStmt] = []
  while true {
    self.skip_newlines()
    let token = self.peek()
    match token.kind {
      Eof => return stmts
      Ident(text) =>
        if stop.contains(text) {
          return stmts
        } else {
          let stmt = self.parse_statement()
          stmts.push({ stmt, line: token.line, })
        }
      _ => self.fail_unexpected()
    }
  }
  stmts
}

///|
fn Parser::parse_statement(self : Parser) -> Stmt raise LangError {
  let token = self.peek()
  match token.kind {
    Ident(text) =>
      match classify_stmt_keyword(text, self.keywords) {
        KwDeclare => self.parse_declare()
        KwIf => self.parse_if()
        KwCountLoop => self.parse_count_loop()
        KwWhile => self.parse_while()
        KwBreak => {
          ignore(self.advance())
          @ir.Break
        }
        KwReturn => {
          ignore(self.advance())
          // 返回 [表达式]：换行/结尾 = 无返回值（返回 VUnit）
          match self.peek().kind {
            Newline | Eof => @ir.Return(None)
            _ => @ir.Return(Some(self.parse_expr()))
          }
        }
        KwMatch => self.parse_match()
        NoneKw =>
          if is_reserved(text) {
            self.fail(ReservedWord, text, "")
          } else {
            self.parse_assign_or_call()
          }
      }
    _ => self.fail_unexpected()
  }
}

///|
fn Parser::parse_declare(self : Parser) -> Stmt raise LangError {
  ignore(self.advance()) // 变量 / let
  let name = self.parse_name("变量声明缺少名称")
  self.expect_eq()
  let value = self.parse_expr()
  @ir.Declare(name, value)
}

///|
fn Parser::parse_name(
  self : Parser,
  missing_message : String,
) -> String raise LangError {
  match self.peek().kind {
    Ident(text) =>
      if is_reserved(text) {
        self.fail(ReservedWord, text, "")
      } else {
        ignore(self.advance())
        text
      }
    _ => self.fail(UnexpectedToken, missing_message, "")
  }
}

///|
/// 赋值 `x = expr`、括号调用 `命令(参数…)`、无括号单参调用 `信息框 "你好"`。
fn Parser::parse_assign_or_call(self : Parser) -> Stmt raise LangError {
  let name = match self.peek().kind {
    Ident(text) => text
    _ => self.fail_unexpected()
  }
  ignore(self.advance())
  // 名单[i] = 值：元素赋值（下标 1 起，与取行口径一致）
  if self.peek().kind is LBracket {
    ignore(self.advance())
    let index = self.parse_expr()
    match self.peek().kind {
      RBracket => ignore(self.advance())
      _ => self.fail(UnexpectedToken, "下标后应为 ]", "")
    }
    match self.peek().kind {
      Eq => ignore(self.advance())
      _ => self.fail(UnexpectedToken, "「]」后应为 =", "")
    }
    let value = self.parse_expr()
    return @ir.SetIndex(name, index, value)
  }
  if self.peek().kind is Eq {
    ignore(self.advance())
    let value = self.parse_expr()
    return @ir.Assign(name, value)
  }
  match self.peek().kind {
    LParen => {
      let args = self.parse_call_args()
      @ir.Call(canonical_call_name(name), args)
    }
    Ident(_) => {
      let arg = self.parse_primary()
      @ir.Call(canonical_call_name(name), [arg])
    }
    Newline | Eof => @ir.Call(canonical_call_name(name), [])
    _ =>
      self.fail(
        UnexpectedToken,
        "「\{name}」后应为 =、参数或换行",
        "",
      )
  }
}

///|
fn Parser::parse_call_args(self : Parser) -> Array[Expr] raise LangError {
  ignore(self.advance()) // (
  let args : Array[Expr] = []
  if self.peek().kind is RParen {
    ignore(self.advance())
    return args
  }
  while true {
    args.push(self.parse_expr())
    match self.peek().kind {
      Comma => ignore(self.advance())
      RParen => {
        ignore(self.advance())
        return args
      }
      _ => self.fail(UnexpectedToken, "参数列表缺少 , 或 )", "")
    }
  }
  args
}

///|
/// 如果 条件 则 … [否则如果 条件 则 …]* [否则 …] 结束
fn Parser::parse_if(self : Parser) -> Stmt raise LangError {
  ignore(self.advance()) // 如果 / if
  let condition = self.parse_expr()
  self.expect_keyword(self.keywords.then_kw)
  let then_body = self.parse_stmts_until([
    self.keywords.else_if_kw,
    self.keywords.else_kw,
    self.keywords.end_kw,
  ])
  let else_ifs : Array[(Expr, Array[TracedStmt])] = []
  while self.at_keyword(self.keywords.else_if_kw) {
    ignore(self.advance())
    let arm_cond = self.parse_expr()
    self.expect_keyword(self.keywords.then_kw)
    let arm_body = self.parse_stmts_until([
      self.keywords.else_if_kw,
      self.keywords.else_kw,
      self.keywords.end_kw,
    ])
    else_ifs.push((arm_cond, arm_body))
  }
  let else_body = if self.at_keyword(self.keywords.else_kw) {
    ignore(self.advance())
    self.parse_stmts_until([self.keywords.end_kw])
  } else {
    []
  }
  self.expect_keyword(self.keywords.end_kw)
  @ir.If(
    condition,
    traced_to_stmts(then_body),
    else_ifs.map(arm => (arm.0, traced_to_stmts(arm.1))),
    traced_to_stmts(else_body),
  )
}

///|
/// 匹配 表达式 [情况 标签 …]* [否则 …] 结束
/// / match expr [case tag …]* [else …] end（M5-5d）
fn Parser::parse_match(self : Parser) -> Stmt raise LangError {
  ignore(self.advance()) // 匹配 / match
  let subject = self.parse_expr()
  self.skip_newlines()
  let arms : Array[@ir.MatchArm] = []
  while self.at_keyword(self.keywords.case_kw) {
    ignore(self.advance())
    let case_name = self.parse_name("「\{self.keywords.case_kw}」后应跟情况名")
    let arm_body = self.parse_stmts_until([
      self.keywords.case_kw,
      self.keywords.else_kw,
      self.keywords.end_kw,
    ])
    arms.push(@ir.MatchArm::{ case_name, body: traced_to_stmts(arm_body), })
  }
  let else_body = if self.at_keyword(self.keywords.else_kw) {
    ignore(self.advance())
    self.parse_stmts_until([self.keywords.end_kw])
  } else {
    []
  }
  self.expect_keyword(self.keywords.end_kw)
  @ir.Match(subject, arms, traced_to_stmts(else_body))
}

///|
/// 计次循环 次数 次 [为 循环变量] … 结束 / repeat 次数 times [as i] … end
fn Parser::parse_count_loop(self : Parser) -> Stmt raise LangError {
  ignore(self.advance()) // 计次循环 / repeat
  let count = self.parse_expr()
  self.expect_keyword(self.keywords.times_kw)
  let loop_var : String? = if self.at_keyword(self.keywords.as_kw) {
    ignore(self.advance())
    Some(
      self.parse_name("「\{self.keywords.as_kw}」后应跟循环变量名"),
    )
  } else {
    None
  }
  let body = self.parse_stmts_until([self.keywords.end_kw])
  self.expect_keyword(self.keywords.end_kw)
  @ir.CountLoop(count, loop_var, traced_to_stmts(body))
}

///|
/// 当 条件 循环 … 结束 / while 条件 do … end
fn Parser::parse_while(self : Parser) -> Stmt raise LangError {
  ignore(self.advance()) // 当 / while
  let condition = self.parse_expr()
  self.expect_keyword(self.keywords.do_kw)
  let body = self.parse_stmts_until([self.keywords.end_kw])
  self.expect_keyword(self.keywords.end_kw)
  @ir.WhileLoop(condition, traced_to_stmts(body))
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise LangError {
  self.parse_or()
}

///|
fn Parser::parse_or(self : Parser) -> Expr raise LangError {
  let mut left = self.parse_and()
  while self.at_keyword(self.keywords.or_kw) {
    ignore(self.advance())
    let right = self.parse_and()
    left = @ir.Binary(@ir.Or, left, right)
  }
  left
}

///|
fn Parser::parse_and(self : Parser) -> Expr raise LangError {
  let mut left = self.parse_not()
  while self.at_keyword(self.keywords.and_kw) {
    ignore(self.advance())
    let right = self.parse_not()
    left = @ir.Binary(@ir.And, left, right)
  }
  left
}

///|
/// 非 绑定整个比较表达式：`非 x = 1` 等价于 `非 (x = 1)`。
fn Parser::parse_not(self : Parser) -> Expr raise LangError {
  if self.at_keyword(self.keywords.not_kw) {
    ignore(self.advance())
    @ir.Not(self.parse_not())
  } else {
    self.parse_comparison()
  }
}

///|
fn comparison_operator(kind : TokenKind) -> BinOp? {
  match kind {
    Eq => Some(@ir.Eq)
    Ne => Some(@ir.Ne)
    Lt => Some(@ir.Lt)
    Gt => Some(@ir.Gt)
    Le => Some(@ir.Le)
    Ge => Some(@ir.Ge)
    _ => None
  }
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise LangError {
  let left = self.parse_additive()
  match comparison_operator(self.peek().kind) {
    Some(op) => {
      ignore(self.advance())
      let right = self.parse_additive()
      @ir.Binary(op, left, right)
    }
    None => left
  }
}

///|
fn Parser::parse_additive(self : Parser) -> Expr raise LangError {
  let mut left = self.parse_term()
  while true {
    match self.peek().kind {
      Plus => {
        ignore(self.advance())
        left = @ir.Binary(@ir.Add, left, self.parse_term())
      }
      Minus => {
        ignore(self.advance())
        left = @ir.Binary(@ir.Sub, left, self.parse_term())
      }
      _ => return left
    }
  }
  left
}

///|
fn Parser::parse_term(self : Parser) -> Expr raise LangError {
  let mut left = self.parse_unary()
  while true {
    match self.peek().kind {
      Star => {
        ignore(self.advance())
        left = @ir.Binary(@ir.Mul, left, self.parse_unary())
      }
      Slash => {
        ignore(self.advance())
        left = @ir.Binary(@ir.Div, left, self.parse_unary())
      }
      _ => return left
    }
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise LangError {
  if self.peek().kind is Minus {
    ignore(self.advance())
    @ir.Neg(self.parse_unary())
  } else {
    self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise LangError {
  let token = self.peek()
  let atom : Expr = match token.kind {
    Num(v) => {
      ignore(self.advance())
      @ir.NumLit(v)
    }
    Int(v) => {
      ignore(self.advance())
      @ir.IntLit(v)
    }
    LBracket => {
      // 列表字面量：[元素, …]（元素可为任意表达式，含嵌套列表）
      ignore(self.advance())
      let items : Array[Expr] = []
      if self.peek().kind is RBracket {
        ignore(self.advance())
      } else {
        while true {
          items.push(self.parse_expr())
          match self.peek().kind {
            Comma => ignore(self.advance())
            RBracket => {
              ignore(self.advance())
              break
            }
            _ => self.fail(UnexpectedToken, "列表缺少 , 或 ]", "")
          }
        }
      }
      @ir.ListLit(items)
    }
    Str(s) => {
      ignore(self.advance())
      @ir.StrLit(s)
    }
    Ident(text) =>
      if text == self.keywords.true_kw {
        ignore(self.advance())
        @ir.BoolLit(true)
      } else if text == self.keywords.false_kw {
        ignore(self.advance())
        @ir.BoolLit(false)
      } else if is_reserved(text) {
        self.fail(ReservedWord, text, "")
      } else {
        ignore(self.advance())
        match self.peek().kind {
          LParen => {
            let args = self.parse_call_args()
            @ir.Call(canonical_call_name(text), args)
          }
          _ => @ir.Var(text)
        }
      }
    LParen => {
      ignore(self.advance())
      let inner = self.parse_expr()
      match self.peek().kind {
        RParen => ignore(self.advance())
        _ => self.fail(UnexpectedToken, "缺少右括号 )", "")
      }
      inner
    }
    _ => self.fail_unexpected()
  }
  // 后缀下标与字段访问：名单[2]、person.名字、名单[1].分数（下标 1 起，与取行一致）
  let mut result = atom
  while true {
    match self.peek().kind {
      LBracket => {
        ignore(self.advance())
        let index = self.parse_expr()
        match self.peek().kind {
          RBracket => ignore(self.advance())
          _ => self.fail(UnexpectedToken, "下标后应为 ]", "")
        }
        result = @ir.Index(result, index)
      }
      Dot => {
        ignore(self.advance())
        let field = match self.peek().kind {
          Ident(text) => {
            ignore(self.advance())
            text
          }
          _ => self.fail(UnexpectedToken, "字段访问 . 后应为字段名", "")
        }
        result = @ir.FieldAccess(result, field)
      }
      DoubleColon => {
        // 枚举值字面量：花色::红桃（基底必须是裸枚举名）
        ignore(self.advance())
        let case_name = match self.peek().kind {
          Ident(text) => {
            ignore(self.advance())
            text
          }
          _ => self.fail(UnexpectedToken, "枚举值 :: 后应为情况名", "")
        }
        let enum_name = match result {
          @ir.Var(name) => name
          _ => self.fail(UnexpectedToken, "枚举值 :: 前应为枚举名", "")
        }
        result = @ir.EnumTag(enum_name, case_name)
      }
      _ => break
    }
  }
  result
}

///|
/// 解析顶层枚举声明（M5-5d）：`枚举 花色 { 红桃, 黑桃 }` /
/// `enum Suit { hearts, spades }`。情况名拒绝保留字；调用方填入
/// `StudioProgram.enums`。
pub fn parse_enum_declarations(
  source : String,
  language : Language,
) -> Result[Array[@ir.EnumDecl], LangError] {
  let tokens = match lex(source) {
    Ok(tokens) => tokens
    Err(error) => return Err(error)
  }
  let parser = Parser::{ tokens, pos: 0, keywords: keywords_for(language), }
  try {
    let decls : Array[@ir.EnumDecl] = []
    parser.skip_newlines()
    while !(parser.peek().kind is Eof) {
      decls.push(parser.parse_enum_decl())
      parser.skip_newlines()
    }
    Ok(decls)
  } catch {
    error => Err(error)
  }
}

///|
fn Parser::parse_enum_decl(self : Parser) -> @ir.EnumDecl raise LangError {
  self.expect_keyword(self.keywords.enum_kw)
  let name = match self.peek().kind {
    Ident(text) =>
      if is_reserved(text) {
        return self.fail(ReservedWord, text, "")
      } else {
        ignore(self.advance())
        text
      }
    _ => self.fail_expect_keyword(self.keywords.enum_kw)
  }
  if self.peek().kind is LBrace {
    ignore(self.advance())
  } else {
    self.fail_expect_keyword("{")
  }
  let cases : Array[String] = []
  if self.peek().kind is RBrace {
    ignore(self.advance())
    return @ir.EnumDecl::{ name, cases, }
  }
  while true {
    match self.peek().kind {
      Ident(text) =>
        if is_reserved(text) {
          return self.fail(ReservedWord, text, "")
        } else {
          ignore(self.advance())
          cases.push(text)
        }
      _ => self.fail(UnexpectedToken, "情况名应为标识符", "")
    }
    match self.peek().kind {
      Comma => ignore(self.advance())
      RBrace => {
        ignore(self.advance())
        break
      }
      _ => self.fail_expect_keyword(", 或 }")
    }
  }
  @ir.EnumDecl::{ name, cases, }
}
