///|
/// 毕业通道 v1.1：把程序 IR 渲染成「人可读的 MoonBit 源码预览」。
/// 只生成文本、不编译——用途是学习与审阅（学生做完之后能看到"真代码长什么样"）。
/// 生成结果必须逐字节确定（快照测试锁定）；程序唯一事实来源仍是 .studio.json IR。

///|
/// 程序 → 可读 MoonBit 预览源码。
pub fn moonbit_preview(program : @ir.StudioProgram) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "/// 本文件由 MoUI Studio自动生成 —— 程序「\{program.window.title}」的可读 MoonBit 预览。\n",
  )
  buf.write_string(
    "/// 用途：学习与审阅（毕业通道）。预览不是可编译产物；\n",
  )
  buf.write_string(
    "/// 程序的唯一事实来源是 .studio.json 程序 IR。\n",
  )
  buf.write_string("\n")
  buf.write_string(
    "/// 窗口：\{program.window.title} · \{program.window.width} x \{program.window.height}\n",
  )
  buf.write_string("\n")
  buf.write_string("/// 控件\n")
  for control in program.controls {
    buf.write_string(control_comment(control))
  }
  if program.controls.length() == 0 {
    buf.write_string("///   （无控件）\n")
  }
  buf.write_string("\n")
  buf.write_string("/// 变量\n")
  if program.variables.length() == 0 {
    buf.write_string("///   （无变量）\n")
  }
  for variable in program.variables {
    buf.write_string("///   \{variable.name} = \"\{variable.init}\"\n")
  }
  buf.write_string("\n")
  let mut index = 0
  for handler in program.handlers {
    index = index + 1
    buf.write_string(handler_preview(program, handler, index))
    buf.write_string("\n")
  }
  if program.handlers.length() == 0 {
    buf.write_string("/// （本程序还没有事件子程序）\n")
  }
  buf.to_string()
}

///|
fn control_comment(control : @ir.Control) -> String {
  let items_note = if control.items.length() > 0 {
    " 选项=\{control.items.length()}行"
  } else {
    ""
  }
  "///   [\{control.id}] \{control.kind.tag()}「\{control.name}」 @ (\{control.x}, \{control.y}) \{control.width}x\{control.height} 文本=\"\{control.text}\"\{items_note}\n"
}

///|
fn handler_preview(
  program : @ir.StudioProgram,
  handler : @ir.Handler,
  index : Int,
) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "/// ── 事件子程序：\{handler.control_name} . \{handler.event.tag()} ──\n",
  )
  if handler.note_zh != "" {
    buf.write_string("/// 意图：\{handler.note_zh}\n")
  }
  if handler.note_en != "" {
    buf.write_string("/// 意图（EN）：\{handler.note_en}\n")
  }
  if handler.note_zh == "" && handler.note_en == "" {
    buf.write_string(
      "/// 意图：（未填写——可读性契约要求 AI 提案必填，手工创建可补）\n",
    )
  }
  // 函数名用 ASCII 安全形式（fn 名 + 控件 id），人类语义在注释行里
  let control_id = match @ir.find_control(program, handler.control_name) {
    Some(control) => control.id.to_string()
    None => "0"
  }
  buf.write_string(
    "fn handler_\{index}_\{control_id}_\{handler.event.tag()}() {\n",
  )
  for stmt in handler.body {
    write_stmt(buf, stmt, 1)
  }
  if handler.body.length() == 0 {
    buf.write_string(
      "  // （空子程序——在积木或代码视图里给它加语句）\n",
    )
  }
  buf.write_string("}\n")
  buf.to_string()
}

///|
fn write_indent(buf : StringBuilder, depth : Int) -> Unit {
  let mut i = 0
  while i < depth {
    buf.write_string("  ")
    i = i + 1
  }
}

///|
fn write_stmt(buf : StringBuilder, stmt : @ir.Stmt, depth : Int) -> Unit {
  match stmt {
    @ir.Declare(name, expr) => {
      write_indent(buf, depth)
      buf.write_string("let \{name} = \{write_expr(expr)}\n")
    }
    @ir.Assign(name, expr) => {
      write_indent(buf, depth)
      buf.write_string("\{name} = \{write_expr(expr)}\n")
    }
    @ir.If(cond, then_body, else_ifs, else_body) => {
      write_indent(buf, depth)
      buf.write_string("if \{write_expr(cond)} {\n")
      for inner in then_body {
        write_stmt(buf, inner, depth + 1)
      }
      for arm in else_ifs {
        write_indent(buf, depth)
        buf.write_string("} else if \{write_expr(arm.0)} {\n")
        for inner in arm.1 {
          write_stmt(buf, inner, depth + 1)
        }
      }
      write_indent(buf, depth)
      buf.write_string("} else {\n")
      for inner in else_body {
        write_stmt(buf, inner, depth + 1)
      }
      write_indent(buf, depth)
      buf.write_string("}\n")
    }
    @ir.CountLoop(times, iter, body) => {
      write_indent(buf, depth)
      let loop_var = match iter {
        Some(name) => name
        None => "_"
      }
      buf.write_string("for \{loop_var} in 0..<\{write_expr(times)} {\n")
      for inner in body {
        write_stmt(buf, inner, depth + 1)
      }
      write_indent(buf, depth)
      buf.write_string("}\n")
    }
    @ir.WhileLoop(cond, body) => {
      write_indent(buf, depth)
      buf.write_string("while \{write_expr(cond)} {\n")
      for inner in body {
        write_stmt(buf, inner, depth + 1)
      }
      write_indent(buf, depth)
      buf.write_string("}\n")
    }
    @ir.Break => {
      write_indent(buf, depth)
      buf.write_string("break\n")
    }
    @ir.Call(name, args) => {
      write_indent(buf, depth)
      buf.write_string("\{name}(\{write_args(args)})\n")
    }
  }
}

///|
fn write_args(args : Array[@ir.Expr]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for arg in args {
    if !first {
      buf.write_string(", ")
    }
    buf.write_string(write_expr(arg))
    first = false
  }
  buf.to_string()
}

///|
fn write_expr(expr : @ir.Expr) -> String {
  match expr {
    @ir.NumLit(value) =>
      if value == value.to_int().to_double() {
        value.to_int().to_string()
      } else {
        value.to_string()
      }
    @ir.StrLit(text) => "\"\{escape_string(text)}\""
    @ir.BoolLit(value) => if value { "true" } else { "false" }
    @ir.Var(name) => name
    @ir.Not(inner) => "!(\{write_expr(inner)})"
    @ir.Neg(inner) => "-(\{write_expr(inner)})"
    @ir.Binary(op, left, right) =>
      "(\{write_expr(left)} \{op.canonical()} \{write_expr(right)})"
    @ir.Call(name, args) => "\{name}(\{write_args(args)})"
  }
}

///|
fn escape_string(text : String) -> String {
  let buf = StringBuilder()
  for ch in text {
    if ch == '\\' || ch == '"' {
      buf.write_char('\\')
    }
    if ch == '\n' {
      buf.write_string("\\n")
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}
