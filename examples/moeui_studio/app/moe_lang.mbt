///|
/// Mo易语言：中文 DSL 的词法/语法/解释器。
/// 纯 MoonBit，无 UI 依赖；UI 交互通过 HostContext 注入。
/// 语句粒度的步数预算防止死循环冻结 UI 线程。

///|
/// 全角标点/数字/字母 → 半角归一化（中文 IME 直接输入也能被解析）。
fn normalize_char(c : Char) -> Char {
  let code = c.to_int()
  if code >= 0xFF10 && code <= 0xFF19 {
    (code - 0xFF10 + 0x30).unsafe_to_char()
  } else if code >= 0xFF21 && code <= 0xFF3A {
    (code - 0xFF21 + 0x41).unsafe_to_char()
  } else if code >= 0xFF41 && code <= 0xFF5A {
    (code - 0xFF41 + 0x61).unsafe_to_char()
  } else {
    match code {
      0xFF08 => '(' // （
      0xFF09 => ')' // ）
      0xFF0C => ',' // ，
      0xFF0B => '+' // ＋
      0xFF0D => '-' // －
      0xFF0A => '*' // ＊
      0xFF0F => '/' // ／
      0xFF1D => '=' // ＝
      0xFF1C => '<' // ＜
      0xFF1E => '>' // ＞
      0x3002 => '.' // 。
      _ => c
    }
  }
}

///|
fn is_digit_char(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0x30 && code <= 0x39
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r'
}

///|
fn is_operator_char(c : Char) -> Bool {
  c == '(' ||
  c == ')' ||
  c == ',' ||
  c == '+' ||
  c == '-' ||
  c == '*' ||
  c == '/' ||
  c == '=' ||
  c == '<' ||
  c == '>' ||
  c == '"'
}

///|
priv enum TokenKind {
  Ident(String)
  Num(Double)
  Str(String)
  Newline
  LParen
  RParen
  Comma
  Plus
  Minus
  Star
  Slash
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
  Eof
}

///|
priv struct Token {
  kind : TokenKind
  line : Int
}

///|
/// 语法错误（可 raise 的错误类型）：信息 + 行号。
pub(all) suberror ParseError {
  ParseError(String, Int)
}

///|
pub fn ParseError::message(self : ParseError) -> String {
  match self {
    ParseError(message, _) => message
  }
}

///|
pub fn ParseError::line(self : ParseError) -> Int {
  match self {
    ParseError(_, line) => line
  }
}

///|
fn token_label(kind : TokenKind) -> String {
  match kind {
    Ident(text) => "「\{text}」"
    Num(n) => "数字 \{n}"
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

///|
/// 词法分析：产出含换行的 token 流；换行用于报错定位。
fn lex(source : String) -> Result[Array[Token], ParseError] {
  // 保存原始字符；归一化只在词法结构判断处做，字符串字面量内保留原文
  let chars : Array[Char] = []
  for c in source {
    chars.push(c)
  }
  let tokens : Array[Token] = []
  let n = chars.length()
  let mut i = 0
  let mut line = 1
  while i < n {
    let c = normalize_char(chars[i])
    if c == '\n' {
      tokens.push({ kind: Newline, line, })
      line = line + 1
      i = i + 1
    } else if is_space_char(c) {
      i = i + 1
    } else if chars[i] == '"' || c == '"' {
      // 字符串字面量：不支持转义与跨行；内容不做全角归一化
      let buf = StringBuilder()
      let mut j = i + 1
      let mut closed = false
      while j < n {
        let cj = chars[j]
        if cj == '"' {
          closed = true
          break
        }
        if cj == '\n' {
          break
        }
        buf.write_char(cj)
        j = j + 1
      }
      if !closed {
        return Err(ParseError("字符串缺少结束引号", line))
      }
      tokens.push({ kind: Str(buf.to_string()), line, })
      i = j + 1
    } else if is_digit_char(c) {
      let buf = StringBuilder()
      while i < n {
        let cn = normalize_char(chars[i])
        if is_digit_char(cn) || cn == '.' {
          buf.write_char(cn)
          i = i + 1
        } else {
          break
        }
      }
      let text = buf.to_string()
      match digits_to_double(text) {
        Some(v) => tokens.push({ kind: Num(v), line, })
        None => return Err(ParseError("无法识别的数字：\{text}", line))
      }
    } else if is_operator_char(c) {
      // 双字符比较运算符优先
      let next = if i + 1 < n { chars[i + 1] } else { ' ' }
      if c == '<' && next == '=' {
        tokens.push({ kind: Le, line, })
        i = i + 2
      } else if c == '<' && next == '>' {
        tokens.push({ kind: Ne, line, })
        i = i + 2
      } else if c == '>' && next == '=' {
        tokens.push({ kind: Ge, line, })
        i = i + 2
      } else {
        let kind = match c {
          '(' => LParen
          ')' => RParen
          ',' => Comma
          '+' => Plus
          '-' => Minus
          '*' => Star
          '/' => Slash
          '=' => Eq
          '<' => Lt
          _ => Gt
        }
        tokens.push({ kind, line, })
        i = i + 1
      }
    } else {
      // 标识符/关键字：非分隔符字符的最大 munch（中文、英文、混排均可）
      let buf = StringBuilder()
      while i < n {
        let c2 = normalize_char(chars[i])
        if c2 == '\n' || is_space_char(c2) || is_operator_char(c2) {
          break
        }
        buf.write_char(c2)
        i = i + 1
      }
      tokens.push({ kind: Ident(buf.to_string()), line, })
    }
  }
  tokens.push({ kind: Eof, line, })
  Ok(tokens)
}

///|
/// 手写的 [0-9.]+ 数字解析（不依赖 strconv；空串/多 dot 返回 None）。
fn digits_to_double(text : String) -> Double? {
  let mut value = 0.0
  let mut frac = false
  let mut scale = 0.1
  let mut seen_digit = false
  let mut seen_dot = false
  for c in text {
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
      frac = true
    } else {
      let d = c.to_int() - 0x30
      seen_digit = true
      if frac {
        value = value + d.to_double() * scale
        scale = scale / 10.0
      } else {
        value = value * 10.0 + d.to_double()
      }
    }
  }
  if seen_digit {
    Some(value)
  } else {
    None
  }
}

///|
/// IDE 属性面板与 `取数值` 共用的宽松文本转数字：容许正负号与全角数字。
pub fn text_to_number(text : String) -> Double? {
  let chars : Array[Char] = []
  for c in text {
    chars.push(normalize_char(c))
  }
  let n = chars.length()
  let mut i = 0
  let mut negative = false
  while i < n && is_space_char(chars[i]) {
    i = i + 1
  }
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    negative = chars[i] == '-'
    i = i + 1
  }
  let buf = StringBuilder()
  while i < n {
    let c = chars[i]
    if is_digit_char(c) || c == '.' {
      buf.write_char(c)
      i = i + 1
    } else if is_space_char(c) {
      i = i + 1
    } else {
      return None
    }
  }
  match digits_to_double(buf.to_string()) {
    Some(value) => Some(if negative { -value } else { value })
    None => None
  }
}

///|
/// 保留字（不允许作为变量名/命令名）。
pub fn is_reserved(text : String) -> Bool {
  text == "变量" ||
  text == "如果" ||
  text == "那么" ||
  text == "则" ||
  text == "否则" ||
  text == "否则如果" ||
  text == "结束" ||
  text == "计次循环" ||
  text == "次" ||
  text == "为" ||
  text == "当" ||
  text == "循环" ||
  text == "真" ||
  text == "假" ||
  text == "且" ||
  text == "或" ||
  text == "非"
}

///|
priv enum Expr {
  NumLit(Double)
  StrLit(String)
  BoolLit(Bool)
  Var(String)
  Call(String, Array[Expr])
  Not(Expr)
  Neg(Expr)
  Binary(String, Expr, Expr) // 运算符：+ - * / = <> < > <= >= 且 或
}

///|
priv enum Stmt {
  Declare(String, Expr) // 变量 x = expr
  Assign(String, Expr) // x = expr
  If(Expr, Array[TracedStmt], Array[TracedStmt])
  CountLoop(String?, Expr, Array[TracedStmt]) // 计次循环 n 次 [为 i] … 结束
  While(Expr, Array[TracedStmt]) // 当 cond 循环 … 结束
  ExprStmt(Expr)
}

///|
/// 语句与其首 token 行号的配对：运行错误能报出真实行号。
priv struct TracedStmt {
  stmt : Stmt
  line : Int
}

///|
/// 递归下降解析器。内部用 typed raise 传播 ParseError。
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
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
/// 总是 raise 的报错辅助（语句位置可直接调用）。
fn[T] Parser::fail(self : Parser, message : String) -> T raise ParseError {
  raise ParseError(message, self.peek().line)
}

///|
fn Parser::expect_keyword(self : Parser, keyword : String) -> Unit raise {
  if !self.at_keyword(keyword) {
    self.fail(
      "此处应为「\{keyword}」，实际是 \{token_label(self.peek().kind)}",
    )
  }
  ignore(self.advance())
}

///|
/// 赋值号 = 是独立 token（不是保留字），单独校验。
fn Parser::expect_eq(self : Parser) -> Unit raise ParseError {
  if self.peek().kind is Eq {
    ignore(self.advance())
  } else {
    self.fail(
      "此处应为「=」，实际是 \{token_label(self.peek().kind)}",
    )
  }
}

///|
fn Parser::skip_newlines(self : Parser) -> Unit {
  while self.peek().kind is Newline {
    ignore(self.advance())
  }
}

///|
/// 解析语句序列，直到遇到 stop 中的保留字或结尾（不消耗终止符）。
fn Parser::parse_stmts_until(
  self : Parser,
  stop : Array[String],
) -> Array[TracedStmt] raise {
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
          stmts.push({ stmt: self.parse_statement(), line: token.line, })
        }
      _ => self.fail("无法识别的语句开头：\{token_label(token.kind)}")
    }
  }
  stmts
}

///|
fn Parser::parse_statement(self : Parser) -> Stmt raise {
  let token = self.peek()
  match token.kind {
    Ident(text) =>
      match text {
        "变量" => self.parse_declare()
        "如果" => self.parse_if(false)
        "计次循环" => self.parse_count_loop()
        "当" => self.parse_while()
        _ =>
          if is_reserved(text) {
            self.fail("「\{text}」不能作为语句开头")
          } else {
            self.parse_assign_or_call()
          }
      }
    _ => self.fail("无法识别的语句开头：\{token_label(token.kind)}")
  }
}

///|
fn Parser::parse_declare(self : Parser) -> Stmt raise {
  ignore(self.advance()) // 变量
  let name = match self.peek().kind {
    Ident(text) =>
      if is_reserved(text) {
        self.fail("「\{text}」是保留字，不能作为变量名")
      } else {
        text
      }
    _ => self.fail("变量声明缺少名称")
  }
  ignore(self.advance())
  self.expect_eq()
  let value = self.parse_expr()
  Declare(name, value)
}

///|
/// 赋值 `x = expr` 或命令调用 `命令(参数…)`（无括号调用仅限单参数语句）。
fn Parser::parse_assign_or_call(self : Parser) -> Stmt raise {
  let name = match self.peek().kind {
    Ident(text) => text
    _ => self.fail("此处应为变量名或命令名")
  }
  ignore(self.advance())
  if self.peek().kind is Eq {
    ignore(self.advance())
    let value = self.parse_expr()
    return Assign(name, value)
  }
  match self.peek().kind {
    LParen => {
      let args = self.parse_call_args()
      ExprStmt(Call(name, args))
    }
    Ident(_) => {
      // 无括号单参数调用：信息框 "你好"
      let arg = self.parse_primary()
      ExprStmt(Call(name, [arg]))
    }
    Newline | Eof => ExprStmt(Call(name, []))
    _ => self.fail("「\{name}」后应为 =、参数或换行")
  }
}

///|
fn Parser::parse_call_args(self : Parser) -> Array[Expr] raise {
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
      _ => self.fail("参数列表缺少 , 或 )")
    }
  }
  args
}

///|
/// 如果 条件 则 … [否则 … | 否则如果 …] 结束；否则如果链共享一个 结束。
fn Parser::parse_if(self : Parser, in_chain : Bool) -> Stmt raise {
  if !in_chain {
    ignore(self.advance()) // 如果
  }
  let condition = self.parse_expr()
  if self.at_keyword("那么") {
    ignore(self.advance())
  } else {
    self.expect_keyword("则")
  }
  let then_body = self.parse_stmts_until(["否则", "否则如果", "结束"])
  let token = self.peek()
  match token.kind {
    Ident("否则如果") => {
      let chain_line = token.line
      ignore(self.advance())
      // 链式递归自己消费共享的那个 结束；外层不再 expect
      let else_body = [{ stmt: self.parse_if(true), line: chain_line, }]
      If(condition, then_body, else_body)
    }
    Ident("否则") => {
      ignore(self.advance())
      let else_body = self.parse_stmts_until(["结束"])
      self.expect_keyword("结束")
      If(condition, then_body, else_body)
    }
    Ident("结束") => {
      ignore(self.advance())
      If(condition, then_body, [])
    }
    _ => self.fail("如果语句缺少「结束」")
  }
}

///|
/// 计次循环 次数表达式 次 [为 循环变量] … 结束；循环变量取 1..次数。
fn Parser::parse_count_loop(self : Parser) -> Stmt raise {
  ignore(self.advance()) // 计次循环
  let count = self.parse_expr()
  self.expect_keyword("次")
  let loop_var : String? = if self.at_keyword("为") {
    ignore(self.advance())
    match self.peek().kind {
      Ident(text) =>
        if is_reserved(text) {
          self.fail("「\{text}」是保留字，不能作为循环变量")
        } else {
          ignore(self.advance())
          Some(text)
        }
      _ => self.fail("「为」后应跟循环变量名")
    }
  } else {
    None
  }
  let body = self.parse_stmts_until(["结束"])
  self.expect_keyword("结束")
  CountLoop(loop_var, count, body)
}

///|
/// 当 条件 循环 … 结束
fn Parser::parse_while(self : Parser) -> Stmt raise {
  ignore(self.advance()) // 当
  let condition = self.parse_expr()
  self.expect_keyword("循环")
  let body = self.parse_stmts_until(["结束"])
  self.expect_keyword("结束")
  While(condition, body)
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise {
  self.parse_or()
}

///|
fn Parser::parse_or(self : Parser) -> Expr raise {
  let mut left = self.parse_and()
  while self.at_keyword("或") {
    ignore(self.advance())
    let right = self.parse_and()
    left = Binary("或", left, right)
  }
  left
}

///|
fn Parser::parse_and(self : Parser) -> Expr raise {
  let mut left = self.parse_not()
  while self.at_keyword("且") {
    ignore(self.advance())
    let right = self.parse_not()
    left = Binary("且", left, right)
  }
  left
}

///|
/// 非 绑定整个比较表达式：`非 x = 1` 等价于 `非 (x = 1)`。
fn Parser::parse_not(self : Parser) -> Expr raise {
  if self.at_keyword("非") {
    ignore(self.advance())
    Not(self.parse_not())
  } else {
    self.parse_comparison()
  }
}

///|
fn comparison_operator(kind : TokenKind) -> String? {
  match kind {
    Eq => Some("=")
    Ne => Some("<>")
    Lt => Some("<")
    Gt => Some(">")
    Le => Some("<=")
    Ge => Some(">=")
    _ => None
  }
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise {
  let left = self.parse_additive()
  match comparison_operator(self.peek().kind) {
    Some(op) => {
      ignore(self.advance())
      let right = self.parse_additive()
      Binary(op, left, right)
    }
    None => left
  }
}

///|
fn Parser::parse_additive(self : Parser) -> Expr raise {
  let mut left = self.parse_term()
  while true {
    match self.peek().kind {
      Plus => {
        ignore(self.advance())
        left = Binary("+", left, self.parse_term())
      }
      Minus => {
        ignore(self.advance())
        left = Binary("-", left, self.parse_term())
      }
      _ => return left
    }
  }
  left
}

///|
fn Parser::parse_term(self : Parser) -> Expr raise {
  let mut left = self.parse_unary()
  while true {
    match self.peek().kind {
      Star => {
        ignore(self.advance())
        left = Binary("*", left, self.parse_unary())
      }
      Slash => {
        ignore(self.advance())
        left = Binary("/", left, self.parse_unary())
      }
      _ => return left
    }
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise {
  if self.peek().kind is Minus {
    ignore(self.advance())
    Neg(self.parse_unary())
  } else {
    self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise {
  let token = self.peek()
  match token.kind {
    Num(v) => {
      ignore(self.advance())
      NumLit(v)
    }
    Str(s) => {
      ignore(self.advance())
      StrLit(s)
    }
    Ident(text) =>
      match text {
        "真" => {
          ignore(self.advance())
          BoolLit(true)
        }
        "假" => {
          ignore(self.advance())
          BoolLit(false)
        }
        _ =>
          if is_reserved(text) {
            self.fail("「\{text}」不能出现在表达式里")
          } else {
            ignore(self.advance())
            match self.peek().kind {
              LParen => {
                let args = self.parse_call_args()
                Call(text, args)
              }
              // 无括号调用仅在语句位置支持；表达式里必须带括号
              _ => Var(text)
            }
          }
      }
    LParen => {
      ignore(self.advance())
      let inner = self.parse_expr()
      match self.peek().kind {
        RParen => ignore(self.advance())
        _ => self.fail("缺少右括号 )")
      }
      inner
    }
    _ => self.fail("表达式不完整：\{token_label(token.kind)}")
  }
}

///|
/// 解析一段事件子程序体（语句序列）。
fn parse_body(source : String) -> Result[Array[TracedStmt], ParseError] {
  let tokens = match lex(source) {
    Ok(tokens) => tokens
    Err(error) => return Err(error)
  }
  let parser = Parser::{ tokens, pos: 0, }
  try {
    let stmts = parser.parse_stmts_until([])
    parser.skip_newlines()
    if parser.peek().kind is Eof {
      Ok(stmts)
    } else {
      parser.fail(
        "无法识别的语句开头：\{token_label(parser.peek().kind)}",
      )
    }
  } catch {
    ParseError(message, line) => Err(ParseError(message, line))
    error => Err(ParseError("解析失败：\{error}", 1))
  }
}

///|
priv enum Value {
  VNum(Double)
  VStr(String)
  VBool(Bool)
  VUnit
}

///|
/// 数值的文本形式：整数值不带小数点。
pub fn number_to_text(n : Double) -> String {
  if n == n.floor() && n.abs() < 1.0e15 {
    n.to_int().to_string()
  } else {
    n.to_string()
  }
}

///|
fn value_to_text(value : Value) -> String {
  match value {
    VNum(n) => number_to_text(n)
    VStr(s) => s
    VBool(true) => "真"
    VBool(false) => "假"
    VUnit => ""
  }
}

///|
fn value_label(value : Value) -> String {
  match value {
    VNum(_) => "数值"
    VStr(_) => "文本"
    VBool(_) => "逻辑值"
    VUnit => "空值"
  }
}

///|
/// 解释器宿主接口：UI 交互（信息框、控件文本读写）由调用方注入。
pub(all) struct HostContext {
  message_box : (String) -> Unit
  set_text : (String, String) -> Unit
  get_text : (String) -> String
}

///|

///|
/// 运行错误（可 raise 的错误类型）：信息 + 行号。
pub(all) suberror RunError {
  RunError(String, Int)
}

///|
pub fn RunError::message(self : RunError) -> String {
  match self {
    RunError(message, _) => message
  }
}

///|
pub fn RunError::line(self : RunError) -> Int {
  match self {
    RunError(_, line) => line
  }
}

///|
priv struct Interp {
  vars : Map[String, Value]
  host : HostContext
  mut steps : Int
  max_steps : Int
  mut line : Int
}

///|
fn[T] Interp::error(self : Interp, message : String) -> T raise RunError {
  raise RunError(message, self.line)
}

///|
fn Interp::count_step(self : Interp) -> Unit raise {
  self.steps = self.steps + 1
  if self.steps > self.max_steps {
    self.error("语句步数超出预算（可能是死循环）")
  }
}

///|
fn Interp::exec_block(self : Interp, stmts : Array[TracedStmt]) -> Unit raise {
  for traced in stmts {
    self.exec_stmt(traced)
  }
}

///|
fn Interp::exec_stmt(self : Interp, traced : TracedStmt) -> Unit raise {
  self.line = traced.line
  self.count_step()
  match traced.stmt {
    Declare(name, expr) => {
      let value = self.eval(expr)
      self.vars[name] = value
    }
    Assign(name, expr) => {
      if self.vars.get(name) is None {
        self.error(
          "变量「\{name}」未声明（请先写：变量 \{name} = …）",
        )
      }
      let value = self.eval(expr)
      self.vars[name] = value
    }
    If(condition, then_body, else_body) => {
      let flag = self.eval_bool(condition, "如果条件")
      if flag {
        self.exec_block(then_body)
      } else {
        self.exec_block(else_body)
      }
    }
    CountLoop(loop_var, count_expr, body) => {
      let count_value = self.eval(count_expr)
      let count = match count_value {
        VNum(n) => n.to_int()
        _ =>
          self.error(
            "计次循环次数应为数值，实际是 \{value_label(count_value)}",
          )
      }
      let mut i = 1
      while i <= count {
        self.count_step()
        match loop_var {
          Some(name) => self.vars[name] = VNum(i.to_double())
          None => ()
        }
        self.exec_block(body)
        i = i + 1
      }
    }
    While(condition, body) =>
      while true {
        self.count_step()
        let flag = self.eval_bool(condition, "当循环条件")
        if !flag {
          break
        }
        self.exec_block(body)
      }
    ExprStmt(expr) => {
      let value = self.eval(expr)
      ignore(value)
    }
  }
}

///|
fn Interp::eval_bool(self : Interp, expr : Expr, role : String) -> Bool raise {
  match self.eval(expr) {
    VBool(flag) => flag
    other =>
      self.error(
        "\{role}应为逻辑值（真/假），实际是 \{value_label(other)}",
      )
  }
}

///|
fn Interp::eval_number(
  self : Interp,
  expr : Expr,
  role : String,
) -> Double raise {
  match self.eval(expr) {
    VNum(n) => n
    other => self.error("\{role}应为数值，实际是 \{value_label(other)}")
  }
}

///|
fn Interp::eval(self : Interp, expr : Expr) -> Value raise {
  match expr {
    NumLit(n) => VNum(n)
    StrLit(s) => VStr(s)
    BoolLit(flag) => VBool(flag)
    Var(name) =>
      match self.vars.get(name) {
        Some(value) => value
        None => self.error("变量「\{name}」未声明")
      }
    Call(name, args) => self.eval_call(name, args)
    Not(inner) => {
      let flag = self.eval_bool(inner, "「非」的运算对象")
      VBool(!flag)
    }
    Neg(inner) => {
      let n = self.eval_number(inner, "负号的运算对象")
      VNum(-n)
    }
    Binary(op, left, right) => self.eval_binary(op, left, right)
  }
}

///|
fn Interp::eval_call(
  self : Interp,
  name : String,
  args : Array[Expr],
) -> Value raise {
  // 命令（返回空值）
  if name == "信息框" {
    let text = self.one_text_arg(name, args, "提示内容")
    (self.host.message_box)(text)
    return VUnit
  }
  if name == "设置文本" {
    if args.length() != 2 {
      self.error(
        "「设置文本」需要两个参数：设置文本(控件名, 新文本)",
      )
    }
    let control = self.value_as_text(self.eval(args[0]), "控件名")
    let new_text = self.value_as_text(self.eval(args[1]), "新文本")
    (self.host.set_text)(control, new_text)
    return VUnit
  }
  // 函数（返回值）
  if name == "取文本" {
    let control = self.one_text_arg(name, args, "控件名")
    return VStr((self.host.get_text)(control))
  }
  if name == "取数值" {
    let control = self.one_text_arg(name, args, "控件名")
    let text = (self.host.get_text)(control)
    match text_to_number(text) {
      Some(n) => return VNum(n)
      None =>
        self.error(
          "控件「\{control}」的文本「\{text}」不是有效数字",
        )
    }
  }
  if name == "转文本" {
    if args.length() != 1 {
      self.error("「转文本」需要一个参数")
    }
    return VStr(value_to_text(self.eval(args[0])))
  }
  if name == "取长度" {
    if args.length() != 1 {
      self.error("「取长度」需要一个参数")
    }
    let text = self.value_as_text(self.eval(args[0]), "字符串")
    return VNum(text.length().to_double())
  }
  if name == "文本包含" {
    if args.length() != 2 {
      self.error(
        "「文本包含」需要两个参数：文本包含(串, 子串)",
      )
    }
    let text = self.value_as_text(self.eval(args[0]), "字符串")
    let sub = self.value_as_text(self.eval(args[1]), "子串")
    return VBool(text.contains(sub))
  }
  self.error("未知的命令或函数：「\{name}」")
}

///|
fn Interp::one_text_arg(
  self : Interp,
  name : String,
  args : Array[Expr],
  role : String,
) -> String raise {
  if args.length() != 1 {
    self.error("「\{name}」需要一个参数")
  }
  self.value_as_text(self.eval(args[0]), role)
}

///|
fn Interp::value_as_text(
  self : Interp,
  value : Value,
  role : String,
) -> String raise {
  match value {
    VStr(s) => s
    VNum(_) | VBool(_) => value_to_text(value)
    VUnit => self.error("\{role}不能为空值")
  }
}

///|
fn Interp::eval_binary(
  self : Interp,
  op : String,
  left : Expr,
  right : Expr,
) -> Value raise {
  if op == "且" || op == "或" {
    let l = self.eval_bool(left, "「\{op}」的运算对象")
    let r = self.eval_bool(right, "「\{op}」的运算对象")
    return VBool(if op == "且" { l && r } else { l || r })
  }
  let l = self.eval(left)
  let r = self.eval(right)
  match op {
    "+" =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a + b)
        (VStr(_), _) | (_, VStr(_)) => VStr(value_to_text(l) + value_to_text(r))
        _ => self.type_error(op, l, r)
      }
    "-" =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a - b)
        _ => self.type_error(op, l, r)
      }
    "*" =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a * b)
        _ => self.type_error(op, l, r)
      }
    "/" =>
      match (l, r) {
        (VNum(a), VNum(b)) =>
          if b == 0.0 {
            self.error("除数不能为零")
          } else {
            VNum(a / b)
          }
        _ => self.type_error(op, l, r)
      }
    "=" | "<>" =>
      match values_equal(l, r) {
        Ok(same) => VBool(if op == "=" { same } else { !same })
        Err(message) => self.error(message)
      }
    "<" | ">" | "<=" | ">=" =>
      match (l, r) {
        (VNum(a), VNum(b)) =>
          VBool(
            match op {
              "<" => a < b
              ">" => a > b
              "<=" => a <= b
              _ => a >= b
            },
          )
        (VStr(a), VStr(b)) =>
          VBool(
            match op {
              "<" => a < b
              ">" => a > b
              "<=" => a <= b
              _ => a >= b
            },
          )
        _ => self.type_error(op, l, r)
      }
    _ => self.error("未知的运算符：\{op}")
  }
}

///|
fn[T] Interp::type_error(
  self : Interp,
  op : String,
  l : Value,
  r : Value,
) -> T raise RunError {
  self.error(
    "运算符 \{op} 不支持 \{value_label(l)} 与 \{value_label(r)} 的组合",
  )
}

///|
/// 同类型相等比较；跨类型报错（帮助初学者发现取错控件/类型）。
fn values_equal(l : Value, r : Value) -> Result[Bool, String] {
  match (l, r) {
    (VNum(a), VNum(b)) => Ok(a == b)
    (VStr(a), VStr(b)) => Ok(a == b)
    (VBool(a), VBool(b)) => Ok(a == b)
    (VUnit, VUnit) => Ok(true)
    _ =>
      Err(
        "不能比较 \{value_label(l)} 与 \{value_label(r)}（检查取值函数用对了没有）",
      )
  }
}

///|
/// 运行一段事件子程序体。解析错误与运行错误统一为 RunError（带行号）。
pub fn run_body(
  source : String,
  host : HostContext,
  max_steps? : Int = 100_000,
) -> Result[Unit, RunError] {
  let stmts = match parse_body(source) {
    Ok(stmts) => stmts
    Err(error) => return Err(RunError(error.message(), error.line()))
  }
  let interp = Interp::{
    vars: Map([], capacity=16),
    host,
    steps: 0,
    max_steps,
    line: 1,
  }
  try {
    interp.exec_block(stmts)
    Ok(())
  } catch {
    RunError(message, line) => Err(RunError(message, line))
    error => Err(RunError("运行失败：\{error}", 1))
  }
}

///|
/// 只解析不运行：代码编辑器的实时语法检查。
pub fn check_source(source : String) -> ParseError? {
  match parse_body(source) {
    Ok(_) => None
    Err(error) => Some(error)
  }
}
