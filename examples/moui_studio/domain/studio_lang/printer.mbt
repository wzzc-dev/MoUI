///|
/// 打印器：IR → 当前语言源码。确定性格式（一行一语句、两空格缩进、
/// 关键字取当前语言表），同一 IR 的渲染结果逐字节稳定（快照测试锁定），
/// 且渲染产物重新解析必须得到同一 IR（往返硬门）。

///|
/// 渲染子程序体（不含 note 头）。
pub fn render_stmts(body : Array[Stmt], language : Language) -> String {
  let buf = StringBuilder()
  write_stmts(buf, body, 0, language)
  buf.to_string()
}

///|
/// 渲染整个事件子程序：note 作为注释头 + 换行 + 体。
pub fn render_handler(handler : Handler, language : Language) -> String {
  let note = match language {
    ZhHans =>
      if handler.note_zh == "" {
        handler.note_en
      } else {
        handler.note_zh
      }
    En => if handler.note_en == "" { handler.note_zh } else { handler.note_en }
  }
  let header = if note == "" { "" } else { "// \{note}\n" }
  header + render_stmts(handler.body, language)
}

///|
fn write_stmts(
  buf : StringBuilder,
  body : Array[Stmt],
  indent : Int,
  language : Language,
) -> Unit {
  let keywords = keywords_for(language)
  for stmt in body {
    write_indent(buf, indent)
    write_stmt(buf, stmt, indent, keywords, language)
    buf.write_string("\n")
  }
}

///|
fn write_indent(buf : StringBuilder, indent : Int) -> Unit {
  for _ in 0..<indent {
    buf.write_string("  ")
  }
}

///|
fn write_stmt(
  buf : StringBuilder,
  stmt : Stmt,
  indent : Int,
  keywords : Keywords,
  language : Language,
) -> Unit {
  match stmt {
    @ir.Declare(name, expr) => {
      buf.write_string("\{keywords.declare_kw} \{name} = ")
      write_expr(buf, expr, 0, false, keywords, language)
    }
    @ir.Assign(name, expr) => {
      buf.write_string("\{name} = ")
      write_expr(buf, expr, 0, false, keywords, language)
    }
    @ir.SetIndex(name, index, value) => {
      buf.write_string("\{name}[")
      write_expr(buf, index, 0, false, keywords, language)
      buf.write_string("] = ")
      write_expr(buf, value, 0, false, keywords, language)
    }
    @ir.Return(None) => buf.write_string(keywords.return_kw)
    @ir.Return(Some(expr)) => {
      buf.write_string("\{keywords.return_kw} ")
      write_expr(buf, expr, 0, false, keywords, language)
    }
    @ir.If(cond, then_body, else_ifs, else_body) => {
      buf.write_string("\{keywords.if_kw} ")
      write_expr(buf, cond, 0, false, keywords, language)
      buf.write_string(" \{keywords.then_kw}\n")
      write_stmts(buf, then_body, indent + 1, language)
      for arm in else_ifs {
        write_indent(buf, indent)
        buf.write_string("\{keywords.else_if_kw} ")
        write_expr(buf, arm.0, 0, false, keywords, language)
        buf.write_string(" \{keywords.then_kw}\n")
        write_stmts(buf, arm.1, indent + 1, language)
      }
      if else_body.length() > 0 {
        write_indent(buf, indent)
        buf.write_string("\{keywords.else_kw}\n")
        write_stmts(buf, else_body, indent + 1, language)
      }
      write_indent(buf, indent)
      buf.write_string(keywords.end_kw)
    }
    @ir.Match(subject, arms, else_body) => {
      buf.write_string("\{keywords.match_kw} ")
      write_expr(buf, subject, 0, false, keywords, language)
      buf.write_string("\n")
      for arm in arms {
        write_indent(buf, indent)
        buf.write_string("\{keywords.case_kw} \{arm.case_name}\n")
        write_stmts(buf, arm.body, indent + 1, language)
      }
      if else_body.length() > 0 {
        write_indent(buf, indent)
        buf.write_string("\{keywords.else_kw}\n")
        write_stmts(buf, else_body, indent + 1, language)
      }
      write_indent(buf, indent)
      buf.write_string(keywords.end_kw)
    }
    @ir.CountLoop(times, loop_var, body) => {
      buf.write_string("\{keywords.count_kw} ")
      write_expr(buf, times, 0, false, keywords, language)
      buf.write_string(" \{keywords.times_kw}")
      match loop_var {
        Some(name) => buf.write_string(" \{keywords.as_kw} \{name}")
        None => ()
      }
      buf.write_string("\n")
      write_stmts(buf, body, indent + 1, language)
      write_indent(buf, indent)
      buf.write_string(keywords.end_kw)
    }
    @ir.WhileLoop(cond, body) => {
      buf.write_string("\{keywords.while_kw} ")
      write_expr(buf, cond, 0, false, keywords, language)
      buf.write_string(" \{keywords.do_kw}\n")
      write_stmts(buf, body, indent + 1, language)
      write_indent(buf, indent)
      buf.write_string(keywords.end_kw)
    }
    @ir.Break => buf.write_string(keywords.break_kw)
    @ir.Call(name, args) => {
      let display = builtin_display(name, language)
      buf.write_string("\{display}(")
      let mut first = true
      for arg in args {
        if !first {
          buf.write_string(", ")
        }
        write_expr(buf, arg, 0, false, keywords, language)
        first = false
      }
      buf.write_string(")")
    }
  }
}

///|
/// 优先级（数字越大绑得越紧）：或 1 / 且 2 / 比较 3 / 加减 4 / 乘除 5 /
/// 一元 6 / 初等 7。右子节点同优先级要加括号（左结合）。
fn expr_precedence(expr : Expr) -> Int {
  match expr {
    @ir.Binary(@ir.Or, _, _) => 1
    @ir.Binary(@ir.And, _, _) => 2
    @ir.Binary(@ir.Eq, _, _)
    | @ir.Binary(@ir.Ne, _, _)
    | @ir.Binary(@ir.Lt, _, _)
    | @ir.Binary(@ir.Gt, _, _)
    | @ir.Binary(@ir.Le, _, _)
    | @ir.Binary(@ir.Ge, _, _) => 3
    @ir.Binary(@ir.Add, _, _) | @ir.Binary(@ir.Sub, _, _) => 4
    @ir.Binary(@ir.Mul, _, _) | @ir.Binary(@ir.Div, _, _) => 5
    @ir.Not(_) | @ir.Neg(_) => 6
    @ir.NumLit(_)
    | @ir.IntLit(_)
    | @ir.StrLit(_)
    | @ir.BoolLit(_)
    | @ir.Var(_)
    | @ir.ListLit(_)
    | @ir.Index(_, _)
    | @ir.Call(_, _)
    | @ir.FieldAccess(_, _)
    | @ir.EnumTag(_, _) => 7
  }
}

///|
fn needs_parens(expr : Expr, parent_prec : Int, is_right : Bool) -> Bool {
  let prec = expr_precedence(expr)
  if prec < parent_prec {
    true
  } else if prec == parent_prec && is_right {
    true
  } else {
    false
  }
}

///|
fn write_expr(
  buf : StringBuilder,
  expr : Expr,
  parent_prec : Int,
  is_right : Bool,
  keywords : Keywords,
  language : Language,
) -> Unit {
  if needs_parens(expr, parent_prec, is_right) {
    buf.write_string("(")
    write_expr_inner(buf, expr, keywords, language)
    buf.write_string(")")
  } else {
    write_expr_inner(buf, expr, keywords, language)
  }
}

///|
fn write_expr_inner(
  buf : StringBuilder,
  expr : Expr,
  keywords : Keywords,
  language : Language,
) -> Unit {
  match expr {
    @ir.NumLit(n) => buf.write_string(number_to_text(n))
    @ir.IntLit(n) => buf.write_string(n.to_string())
    @ir.ListLit(items) => {
      buf.write_string("[")
      let mut first = true
      for item in items {
        if !first {
          buf.write_string(", ")
        }
        write_expr(buf, item, 0, false, keywords, language)
        first = false
      }
      buf.write_string("]")
    }
    @ir.Index(base, index) => {
      // 基底非主级（二元/一元）时加括号：a + b[i] 与 (a + b)[i] 可区分
      if expr_precedence(base) < 7 {
        buf.write_string("(")
        write_expr(buf, base, 0, false, keywords, language)
        buf.write_string(")")
      } else {
        write_expr(buf, base, 7, false, keywords, language)
      }
      buf.write_string("[")
      write_expr(buf, index, 0, false, keywords, language)
      buf.write_string("]")
    }
    @ir.StrLit(text) => buf.write_string("\"\{text}\"")
    @ir.BoolLit(flag) =>
      buf.write_string(if flag { keywords.true_kw } else { keywords.false_kw })
    @ir.Var(name) => buf.write_string(name)
    @ir.FieldAccess(base, field) => {
      // 基底非主级（二元/一元）时加括号：(a + b).field 可区分
      if expr_precedence(base) < 7 {
        buf.write_string("(")
        write_expr(buf, base, 0, false, keywords, language)
        buf.write_string(")")
      } else {
        write_expr(buf, base, 7, false, keywords, language)
      }
      buf.write_string(".")
      buf.write_string(field)
    }
    @ir.EnumTag(enum_name, case_name) =>
      buf.write_string("\{enum_name}::\{case_name}")
    @ir.Not(inner) => {
      buf.write_string("\{keywords.not_kw} ")
      write_expr(buf, inner, 6, false, keywords, language)
    }
    @ir.Neg(inner) => {
      buf.write_string("-")
      write_expr(buf, inner, 6, false, keywords, language)
    }
    @ir.Binary(op, left, right) => {
      let prec = expr_precedence(expr)
      write_expr(buf, left, prec, false, keywords, language)
      buf.write_string(" \{binary_symbol(op, keywords)} ")
      write_expr(buf, right, prec, true, keywords, language)
    }
    @ir.Call(name, args) => {
      let display = builtin_display(name, language)
      buf.write_string("\{display}(")
      let mut first = true
      for arg in args {
        if !first {
          buf.write_string(", ")
        }
        write_expr(buf, arg, 0, false, keywords, language)
        first = false
      }
      buf.write_string(")")
    }
  }
}

///|
fn binary_symbol(op : BinOp, keywords : Keywords) -> String {
  match op {
    @ir.Add => "+"
    @ir.Sub => "-"
    @ir.Mul => "*"
    @ir.Div => "/"
    @ir.Eq => "="
    @ir.Ne => "<>"
    @ir.Lt => "<"
    @ir.Gt => ">"
    @ir.Le => "<="
    @ir.Ge => ">="
    @ir.And => keywords.and_kw
    @ir.Or => keywords.or_kw
  }
}

///|
/// 渲染 struct 声明（M5-5c 前端②）：一行一个声明、字段两空格后逗号
/// 分隔，与 parse_struct_declarations 构成往返硬门。字段名语言无关；
/// 类型词取当前语言表。
pub fn render_struct_declarations(
  decls : Array[@ir.StructDecl],
  language : Language,
) -> String {
  let buf = StringBuilder()
  for decl in decls {
    buf.write_string("\{keywords_for(language).struct_kw} \{decl.name} { ")
    for index, field in decl.fields {
      if index > 0 {
        buf.write_string(", ")
      }
      let display = struct_field_type_display(field.field_type, language)
      buf.write_string("\{field.field_name}: \{display}")
    }
    buf.write_string(" }\n")
  }
  buf.to_string()
}

///|
/// 渲染枚举声明（M5-5d）：一行一个声明、情况逗号分隔，与
/// parse_enum_declarations 构成往返硬门。
pub fn render_enum_declarations(
  decls : Array[@ir.EnumDecl],
  language : Language,
) -> String {
  let buf = StringBuilder()
  for decl in decls {
    buf.write_string("\{keywords_for(language).enum_kw} \{decl.name} { ")
    for index, case_name in decl.cases {
      if index > 0 {
        buf.write_string(", ")
      }
      buf.write_string(case_name)
    }
    buf.write_string(" }\n")
  }
  buf.to_string()
}
