///|
/// 规范签名：语言中立的确定性文本倾倒。
/// 没有 derive(Eq) 的 toolchain 现实下，签名是测试与 diff 的相等性判据：
/// 往返解析、代码↔IR 同步、导出 bundle 快照，全部比对签名。

///|
pub fn program_signature(program : MomaoProgram) -> String {
  let buf = StringBuilder()
  buf.write_string("program v\{program.version}\n")
  buf.write_string(
    "window «\{program.window.title}» \{program.window.width} \{program.window.height}\n",
  )
  for control in program.controls {
    buf.write_string(
      "control \{control.id} \{control.kind.tag()} «\{control.name}» «\{control.text}» \{control.x} \{control.y} \{control.width} \{control.height}",
    )
    if control.items.length() > 0 {
      buf.write_string(" items[")
      for item in control.items {
        buf.write_string("«\{item}» ")
      }
      buf.write_string("]")
    }
    buf.write_string("\n")
  }
  for variable in program.variables {
    buf.write_string("variable «\{variable.name}» = «\{variable.init}»\n")
  }
  for handler in program.handlers {
    buf.write_string(
      "handler «\{handler.control_name}» \{handler.event.tag()} note(«\{handler.note_zh}»|«\{handler.note_en}»)\n",
    )
    buf.write_string(handler_signature(handler))
  }
  buf.to_string()
}

///|
pub fn handler_signature(handler : Handler) -> String {
  stmts_signature(handler.body)
}

///|
pub fn stmts_signature(body : Array[Stmt]) -> String {
  let buf = StringBuilder()
  write_stmts(buf, body, 0)
  buf.to_string()
}

///|
fn write_stmts(buf : StringBuilder, body : Array[Stmt], indent : Int) -> Unit {
  for stmt in body {
    write_indent(buf, indent)
    write_stmt(buf, stmt, indent)
  }
}

///|
fn write_indent(buf : StringBuilder, indent : Int) -> Unit {
  buf.write_string("\n")
  for _ in 0..<indent {
    buf.write_string("  ")
  }
}

///|
fn write_stmt(buf : StringBuilder, stmt : Stmt, indent : Int) -> Unit {
  match stmt {
    Declare(name, expr) => {
      buf.write_string("declare \{name} = ")
      write_expr(buf, expr)
    }
    Assign(name, expr) => {
      buf.write_string("assign \{name} = ")
      write_expr(buf, expr)
    }
    If(cond, then_body, else_ifs, else_body) => {
      buf.write_string("if ")
      write_expr(buf, cond)
      write_stmts(buf, then_body, indent + 1)
      for arm in else_ifs {
        write_indent(buf, indent)
        buf.write_string("elseif ")
        write_expr(buf, arm.0)
        write_stmts(buf, arm.1, indent + 1)
      }
      if else_body.length() > 0 {
        write_indent(buf, indent)
        buf.write_string("else")
        write_stmts(buf, else_body, indent + 1)
      }
    }
    CountLoop(times, loop_var, body) => {
      buf.write_string("count ")
      write_expr(buf, times)
      buf.write_string(" as \{loop_var.unwrap_or("-")}")
      write_stmts(buf, body, indent + 1)
    }
    WhileLoop(cond, body) => {
      buf.write_string("while ")
      write_expr(buf, cond)
      write_stmts(buf, body, indent + 1)
    }
    Break => buf.write_string("break")
    Call(name, args) => {
      buf.write_string("call \{name}")
      for arg in args {
        buf.write_string(" ")
        write_expr(buf, arg)
      }
    }
  }
}

///|
fn write_expr(buf : StringBuilder, expr : Expr) -> Unit {
  match expr {
    NumLit(n) => buf.write_string("num(\{n})")
    StrLit(text) => buf.write_string("str(«\{text}»)")
    BoolLit(flag) => buf.write_string(if flag { "bool(true)" } else { "bool(false)" })
    Var(name) => buf.write_string("var(\{name})")
    Not(inner) => {
      buf.write_string("not ")
      write_expr(buf, inner)
    }
    Neg(inner) => {
      buf.write_string("neg ")
      write_expr(buf, inner)
    }
    Binary(op, left, right) => {
      buf.write_string("(")
      write_expr(buf, left)
      buf.write_string(" \{op.canonical()} ")
      write_expr(buf, right)
      buf.write_string(")")
    }
    Call(name, args) => {
      buf.write_string("fn(\{name}")
      for arg in args {
        buf.write_string(" ")
        write_expr(buf, arg)
      }
      buf.write_string(")")
    }
  }
}
