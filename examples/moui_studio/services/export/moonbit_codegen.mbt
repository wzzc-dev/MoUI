///|
/// 编译轨代码生成：IR → 可编译、可读的 MoonBit 事件子程序源码。
///
/// 与 `domain/studio_lang/interp.mbt` 的指令机逐条对齐：
/// - 每个 handler 生成 `fn studio_..._<i>(rt : @compiled_runtime.Runtime) ->
///   Unit raise @compiled_runtime.ExecError`，函数体直接调用 compiled_runtime
///   的执行面，没有任何解释器（不含 `start_run_stmts` / `run_to_end`）。
/// - 审计 detail 在生成期烘死为字符串字面量，文本来自
///   `@studio_lang.canonical_expr` / `canonical_call_text`，两轨审计序列逐字节可比。
/// - `stmt_lines` 记录「IR 语句路径 → 生成源码行号」，供编译诊断把
///   `moon check/build` 的行列错误映射回积木/控件。
///
/// 这份文本既是预览视图的展示内容，也是导出 bundle 里实际参与编译的唯一源码。
/// 生成结果对同一 IR 逐字节确定。

///|
/// 一条语句的生成源码行号映射：IR 路径 → 生成源码行号（1-based）。
pub(all) struct StmtLine {
  path : Array[Int]
  line : Int
  // 审计行号：与解释轨一致，嵌套语句继承最近一层顶层语句的行号
  audit_line : Int
}

///|
/// 一个 handler 的生成产物。
pub(all) struct GeneratedHandler {
  index : Int
  function_name : String
  control_name : String
  event_tag : String
  source : String
  stmt_lines : Array[StmtLine]
  // 该 handler 在整份生成文件里的首行（1-based）
  start_line : Int
  // 函数体结束行（不含闭括号）；注入器在此行前放入循环控制辅助函数
  body_end_line : Int
}

///|
pub fn GeneratedHandler::line_for(
  self : GeneratedHandler,
  path : Array[Int],
) -> Int? {
  for entry in self.stmt_lines {
    if paths_equal(entry.path, path) {
      return Some(entry.line)
    }
  }
  None
}

///|
pub fn GeneratedHandler::audit_line_for(
  self : GeneratedHandler,
  path : Array[Int],
) -> Int? {
  for entry in self.stmt_lines {
    if paths_equal(entry.path, path) {
      return Some(entry.audit_line)
    }
  }
  None
}

///|
pub fn paths_equal(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let mut index = 0
  while index < left.length() {
    if left[index] != right[index] {
      return false
    }
    index = index + 1
  }
  true
}

///|
/// 整份生成文件的产物：源码 + 每个 handler 的元数据。
pub(all) struct GeneratedSource {
  source : String
  handlers : Array[GeneratedHandler]
}

///|
/// 生成 handler 函数（不含文件头）。`index` 从 1 开始，用于函数名。
pub fn generate_handler_source(
  handler : @ir.Handler,
  index : Int,
  functions? : Array[@ir.FuncDef] = [],
) -> GeneratedHandler {
  let ctx : GenCtx = {
    buf: StringBuilder(),
    lines: [],
    depth: 0,
    path: [],
    line: 1,
    audit_line: 1,
    audit_line_override: None,
    functions,
  }
  write_line(
    ctx,
    "fn \{function_name_for(handler, index)}(rt : @compiled_runtime.Runtime) -> Unit raise @compiled_runtime.ExecError {",
  )
  ctx.depth = 1
  write_body(ctx, handler.body, true)
  let body_end = ctx.line
  ctx.depth = 0
  write_line(ctx, "}")
  {
    index,
    function_name: function_name_for(handler, index),
    control_name: handler.control_name,
    event_tag: handler.event.tag(),
    source: ctx.buf.to_string(),
    stmt_lines: ctx.lines,
    start_line: 1,
    body_end_line: body_end,
  }
}

///|
/// 生成整份「编译即验收」源码：文件头 + 全部 handler。
pub fn generate_source(program : @ir.StudioProgram) -> GeneratedSource {
  let buf = StringBuilder()
  buf.write_string(
    "/// 本文件由 MoUI Studio 从 .studio.json 程序 IR 生成，请勿手改。\n",
  )
  buf.write_string(
    "/// 程序：\{program.window.title} · \{program.window.width} x \{program.window.height}\n",
  )
  buf.write_string(
    "/// 这是导出 bundle 里真正参与编译的事件子程序源码；审计 detail 与解释轨同源。\n",
  )
  buf.write_string("\n")
  let handlers : Array[GeneratedHandler] = []
  let mut index = 0
  for handler in program.handlers {
    index = index + 1
    let generated = generate_handler_source(
      handler,
      index,
      functions=program.functions,
    )
    let offset = count_newlines(buf.to_string())
    buf.write_string(generated.source)
    buf.write_string("\n")
    let shifted : Array[StmtLine] = []
    for entry in generated.stmt_lines {
      shifted.push(StmtLine::{
        path: entry.path,
        line: entry.line + offset,
        audit_line: entry.audit_line + offset,
      })
    }
    handlers.push({
      ..generated,
      stmt_lines: shifted,
      start_line: generated.start_line + offset,
      body_end_line: generated.body_end_line + offset,
    })
  }
  if program.handlers.length() == 0 {
    buf.write_string("/// （本程序还没有事件子程序）\n")
  }
  // 用户函数（切片 F）：体审计行号统一 0（两轨同口径）；分派表与
  // handler 同构，生成期烘焙、无运行期反射。分派表无条件发射
  // （runner 模板按名字注册，无函数时恒 None）。
  if program.functions.length() > 0 {
    buf.write_string("\n///|\n")
    buf.write_string(
      "/// 用户自定义函数：参数按位绑定；Return 经 LoopReturn 传回。\n",
    )
    let mut fn_index = 0
    for func in program.functions {
      fn_index = fn_index + 1
      let fn_name = "studio_fn_\{fn_index}"
      buf.write_string(
        "pub fn \{fn_name}(rt : @compiled_runtime.Runtime, args : Array[@compiled_runtime.Value]) -> @compiled_runtime.Value raise @compiled_runtime.ExecError {\n",
      )
      buf.write_string("  ignore(args)\n")
      let mut param_index = 0
      for param in func.params {
        param_index = param_index + 1
        buf.write_string(
          "  rt.vars[\{mbt_quote(param)}] = args[\{param_index - 1}]\n",
        )
        buf.write_string("  if !rt.declared.contains(\{mbt_quote(param)}) {\n")
        buf.write_string("    rt.declared.push(\{mbt_quote(param)})\n")
        buf.write_string("  }\n")
      }
      buf.write_string("  try {\n")
      // 体：行号 0——函数体没有用户源码行号
      let ctx : GenCtx = {
        buf,
        lines: [],
        depth: 1,
        path: [],
        line: 1,
        audit_line: 1,
        audit_line_override: Some(0),
        functions: program.functions,
      }
      write_body(ctx, func.body, true)
      buf.write_string("    @compiled_runtime.VUnit\n")
      buf.write_string("  } catch {\n")
      buf.write_string("    @compiled_runtime.LoopReturn(value) => value\n")
      buf.write_string("    error => raise error\n")
      buf.write_string("  }\n")
      buf.write_string("}\n")
      buf.write_string("\n")
    }
  }
  buf.write_string("\n///|\n")
  buf.write_string(
    "/// 用户函数分派表：名称 → 注册闭包（无函数时恒 None）。\n",
  )
  buf.write_string(
    "pub fn studio_dispatch_function(name : String) -> @compiled_runtime.UserFunction? {\n",
  )
  if program.functions.length() == 0 {
    buf.write_string("  ignore(name)\n")
  }
  let mut fn_index2 = 0
  for func in program.functions {
    fn_index2 = fn_index2 + 1
    buf.write_string("  if name == \{mbt_quote(func.name)} {\n")
    buf.write_string("    return Some(studio_fn_\{fn_index2})\n")
    buf.write_string("  }\n")
  }
  buf.write_string("  None\n")
  buf.write_string("}\n")
  write_dispatch(buf, program, handlers)
  { source: buf.to_string(), handlers, }
}

///|
/// 生成 `(控件名, 事件) → Handler` 分派函数：导出 runner 的唯一入口，
/// 由生成源码自己在编译期绑定到各事件子程序（无运行期名字解析）。
fn write_dispatch(
  buf : StringBuilder,
  program : @ir.StudioProgram,
  handlers : Array[GeneratedHandler],
) -> Unit {
  buf.write_string("\n///|\n")
  buf.write_string(
    "/// (控件名, 事件) → 该控件事件子程序的分派表；生成期烘焙，无运行期反射。\n",
  )
  buf.write_string(
    "pub fn studio_dispatch_handler(control : String, event_tag : String) -> @compiled_runtime.Handler? {\n",
  )
  if handlers.length() == 0 {
    buf.write_string("  ignore(control)\n")
    buf.write_string("  ignore(event_tag)\n")
  }
  let mut index = 0
  for handler in program.handlers {
    let generated = handlers[index]
    buf.write_string(
      "  if control == \{mbt_quote(handler.control_name)} && event_tag == \{mbt_quote(handler.event.tag())} {\n",
    )
    buf.write_string(
      "    return Some(@compiled_runtime.Handler(\{generated.function_name}))\n",
    )
    buf.write_string("  }\n")
    index = index + 1
  }
  buf.write_string("  None\n")
  buf.write_string("}\n")
}

///|
/// 生成期上下文：输出缓冲、行号表、缩进深度、当前语句路径与审计行号。
priv struct GenCtx {
  buf : StringBuilder
  lines : Array[StmtLine]
  mut depth : Int
  mut path : Array[Int]
  mut line : Int
  mut audit_line : Int
  // 用户函数体：审计行号统一 0（与解释轨 call_user_function 的
  // compile_body(traced_from_stmts) 同口径；函数体没有用户源码行号）
  audit_line_override : Int?
  // 程序的用户函数表：调用解析「先内建、后自定义」用
  functions : Array[@ir.FuncDef]
}

///|
/// 是否为用户自定义函数（生成期解析；与解释轨 find_builtin→find_function
/// 的次序一致）。
fn is_user_function(ctx : GenCtx, name : String) -> Bool {
  let mut found = false
  for func in ctx.functions {
    if func.name == name {
      found = true
    }
  }
  found
}

///|
/// 用户函数调用实参的生成文本序列。
fn write_args(ctx : GenCtx, args : Array[@ir.Expr]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for arg in args {
    if !first {
      buf.write_string(", ")
    }
    buf.write_string(write_value(ctx, arg))
    first = false
  }
  buf.to_string()
}

///|
/// 事件子程序的 MoonBit 函数名（M6①：form.mbt 的 on_click 绑定
/// 与 handlers.mbt 的函数名必须同源，这里是对外唯一出口）。
pub fn handler_function_name(handler : @ir.Handler, index : Int) -> String {
  function_name_for(handler, index)
}

///|
fn function_name_for(handler : @ir.Handler, index : Int) -> String {
  "studio_" +
  sanitize_identifier(handler.control_name) +
  "_" +
  handler.event.tag() +
  "_" +
  index.to_string()
}

///|
/// CJK 标识符不能直接进 MoonBit 函数名，统一折叠为 `_`；
/// 序号来自 IR 顺序，保证确定性。
fn sanitize_identifier(name : String) -> String {
  let buf = StringBuilder()
  for ch in name {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' {
      buf.write_char(ch)
    } else {
      buf.write_char('_')
    }
  }
  let text = buf.to_string()
  if text == "" {
    "handler"
  } else {
    text
  }
}

///|
fn count_newlines(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count = count + 1
    }
  }
  count
}

///|
fn write_line(ctx : GenCtx, text : String) -> Unit {
  let mut i = 0
  while i < ctx.depth {
    ctx.buf.write_string("  ")
    i = i + 1
  }
  ctx.buf.write_string(text)
  ctx.buf.write_string("\n")
  ctx.line = ctx.line + 1
}

///|
fn with_depth(ctx : GenCtx, f : () -> Unit) -> Unit {
  ctx.depth = ctx.depth + 1
  f()
  ctx.depth = ctx.depth - 1
}

///|
fn push_path(ctx : GenCtx, index : Int) -> Unit {
  let next : Array[Int] = []
  for part in ctx.path {
    next.push(part)
  }
  next.push(index)
  ctx.path = next
}

///|
fn pop_path(ctx : GenCtx) -> Unit {
  let next : Array[Int] = []
  let mut i = 0
  while i + 1 < ctx.path.length() {
    next.push(ctx.path[i])
    i = i + 1
  }
  ctx.path = next
}

///|
fn record_stmt_line(ctx : GenCtx) -> Unit {
  let path : Array[Int] = []
  for part in ctx.path {
    path.push(part)
  }
  let audit_line = match ctx.audit_line_override {
    Some(fixed) => fixed
    None => ctx.audit_line
  }
  ctx.lines.push(StmtLine::{ path, line: ctx.line, audit_line, })
}

///|
/// 生成语句体。`top_level` 为真时，本层语句各自开启新的审计行号；
/// 为假（嵌套体）时继承外层审计行号——与解释轨 `emit_body` 同口径。
fn write_body(ctx : GenCtx, body : Array[@ir.Stmt], top_level : Bool) -> Unit {
  let mut index = 0
  for stmt in body {
    push_path(ctx, index)
    if top_level {
      ctx.audit_line = ctx.line
    }
    write_stmt(ctx, stmt)
    pop_path(ctx)
    index = index + 1
  }
}

///|
fn write_stmt(ctx : GenCtx, stmt : @ir.Stmt) -> Unit {
  match stmt {
    @ir.Declare(name, expr) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      write_line(
        ctx,
        "rt.audit_assign(\{mbt_quote(name)}, \{write_value(ctx, expr)}, \{line}, \{mbt_quote("\{name} = \{@studio_lang.canonical_expr(expr)}")})",
      )
    }
    @ir.Assign(name, expr) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      write_line(ctx, "rt.require_declared(\{mbt_quote(name)}, \{line})")
      write_line(
        ctx,
        "rt.audit_assign(\{mbt_quote(name)}, \{write_value(ctx, expr)}, \{line}, \{mbt_quote("\{name} = \{@studio_lang.canonical_expr(expr)}")})",
      )
    }
    @ir.SetIndex(name, index, value) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      write_line(ctx, "rt.require_declared(\{mbt_quote(name)}, \{line})")
      write_line(
        ctx,
        "let existing_\{line} = rt.get(\{mbt_quote(name)}, \{line})",
      )
      write_line(
        ctx,
        "@compiled_runtime.set_index_values(existing_\{line}, \{write_value(ctx, index)}, \{write_value(ctx, value)}, \{line})",
      )
      write_line(
        ctx,
        "rt.record(\{line}, @compiled_runtime.OpCommand, \{mbt_quote("\{name}[\{@studio_lang.canonical_expr(index)}] = \{@studio_lang.canonical_expr(value)}")})",
      )
    }
    @ir.If(cond, then_body, else_ifs, else_body) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      let cond_name = "condition_\{(ctx.lines.length()).to_string()}"
      write_line(ctx, "if \{write_if_condition(ctx, cond_name, cond, line)} {")
      with_depth(ctx, fn() { write_body(ctx, then_body, false) })
      let mut arm_index = 0
      for arm in else_ifs {
        push_path(ctx, 1)
        ctx.audit_line = line
        let arm_name = "condition_\{(ctx.lines.length()).to_string()}_\{arm_index}"
        write_line(
          ctx,
          "} else if \{write_if_condition(ctx, arm_name, arm.0, line)} {",
        )
        with_depth(ctx, fn() {
          push_path(ctx, arm_index)
          write_body(ctx, arm.1, false)
          pop_path(ctx)
        })
        pop_path(ctx)
        arm_index = arm_index + 1
      }
      write_line(ctx, "} else {")
      with_depth(ctx, fn() {
        push_path(ctx, 2)
        write_body(ctx, else_body, false)
        pop_path(ctx)
      })
      write_line(ctx, "}")
    }
    @ir.Match(subject, arms, else_body) => {
      // 匹配分派（M5-5d）：单次求值 + 审计一行（与解释轨同格式）
      record_stmt_line(ctx)
      let line = ctx.audit_line
      let dispatch_name = "dispatch_\{(ctx.lines.length()).to_string()}"
      write_line(
        ctx,
        "let \{dispatch_name} = @compiled_runtime.enum_case(\{write_value(ctx, subject)}, \{line})",
      )
      write_line(
        ctx,
        "rt.record(\{line}, @compiled_runtime.OpCondition, \{mbt_quote("\{@studio_lang.canonical_expr(subject)} -> ")} + \{dispatch_name})",
      )
      write_line(ctx, "match \{dispatch_name} {")
      let mut arm_index = 0
      for arm in arms {
        write_line(ctx, "  \{mbt_quote(arm.case_name)} => {")
        with_depth(ctx, fn() {
          push_path(ctx, arm_index)
          write_body(ctx, arm.body, false)
          pop_path(ctx)
        })
        write_line(ctx, "}")
        arm_index = arm_index + 1
      }
      write_line(ctx, "  _ => {")
      with_depth(ctx, fn() {
        push_path(ctx, arms.length())
        write_body(ctx, else_body, false)
        pop_path(ctx)
      })
      write_line(ctx, "}")
      write_line(ctx, "}")
    }
    @ir.CountLoop(times, loop_var, body) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      let var_name = match loop_var {
        Some(name) => name
        None => ""
      }
      write_line(
        ctx,
        "rt.count_loop(\{write_value(ctx, times)}, \{mbt_quote(var_name)}, \{line}, fn(rt : @compiled_runtime.Runtime) -> Unit raise @compiled_runtime.ExecError {",
      )
      with_depth(ctx, fn() { write_body(ctx, body, false) })
      write_line(ctx, "})")
    }
    @ir.WhileLoop(cond, body) => {
      record_stmt_line(ctx)
      let line = ctx.audit_line
      write_line(
        ctx,
        "rt.while_loop(\{line}, fn(rt : @compiled_runtime.Runtime) -> @compiled_runtime.Value raise @compiled_runtime.ExecError {",
      )
      with_depth(ctx, fn() { write_line(ctx, write_value(ctx, cond)) })
      write_line(
        ctx, "}, fn(rt : @compiled_runtime.Runtime, flag : Bool) -> Unit raise @compiled_runtime.ExecError {",
      )
      with_depth(ctx, fn() {
        write_line(
          ctx,
          "rt.record_condition(flag, \{line}, \{mbt_quote(@studio_lang.canonical_expr(cond))})",
        )
      })
      write_line(
        ctx, "}, fn(rt : @compiled_runtime.Runtime) -> Unit raise @compiled_runtime.ExecError {",
      )
      with_depth(ctx, fn() { write_body(ctx, body, false) })
      write_line(ctx, "})")
    }
    @ir.Break => {
      record_stmt_line(ctx)
      write_line(ctx, "rt.break_loop()")
    }
    @ir.Return(expr) => {
      record_stmt_line(ctx)
      match expr {
        Some(value) =>
          write_line(
            ctx,
            "raise @compiled_runtime.LoopReturn(\{write_value(ctx, value)})",
          )
        None =>
          write_line(
            ctx, "raise @compiled_runtime.LoopReturn(@compiled_runtime.VUnit)",
          )
      }
    }
    @ir.Call(name, args) => {
      record_stmt_line(ctx)
      write_stmt_call(ctx, name, args)
    }
  }
}

///|
/// `if` 条件：先求值一次并记账，再作为条件使用（与解释轨
/// 「求值 → record_condition → 分支」同一顺序，杜绝重复求值副作用）。
fn write_if_condition(
  ctx : GenCtx,
  name : String,
  cond : @ir.Expr,
  line : Int,
) -> String {
  "{\n" +
  "    let \{name} = @compiled_runtime.bool_of(\{write_value(ctx, cond)}, \"condition\", \{line})\n" +
  "    rt.record_condition(\{name}, \{line}, \{mbt_quote(@studio_lang.canonical_expr(cond))})\n" +
  "    \{name}\n" +
  "  }"
}

///|
/// 语句位的内建调用：命令/闸门直接调用；函数求值后补一条命令审计
/// （与解释轨 `ExprStmt` 的补记口径一致）。
fn write_stmt_call(ctx : GenCtx, name : String, args : Array[@ir.Expr]) -> Unit {
  let line = ctx.audit_line
  match @studio_lang.builtin_kind(name) {
    Some(@studio_lang.Command) => write_command_call(ctx, name, args, line)
    Some(@studio_lang.Gate) => write_gate_call(ctx, name, args, line)
    Some(@studio_lang.Function) => {
      let temp = "statement_\{(ctx.lines.length()).to_string()}"
      write_line(ctx, "let \{temp} = \{write_value(ctx, @ir.Call(name, args))}")
      ignore(temp)
      write_line(
        ctx,
        "rt.record(\{line}, @compiled_runtime.OpCommand, \{mbt_quote(@studio_lang.canonical_expr(@ir.Call(name, args)))})",
      )
    }
    // 内建没有 → 用户自定义函数：语句位调用 + 记账（与解释轨同口径）
    None =>
      if is_user_function(ctx, name) {
        write_line(
          ctx,
          "rt.call_user_function(\{mbt_quote(name)}, [\{write_args(ctx, args)}], \{line})",
        )
        write_line(
          ctx,
          "rt.record(\{line}, @compiled_runtime.OpCommand, \{mbt_quote(@studio_lang.canonical_expr(@ir.Call(name, args)))})",
        )
      } else {
        write_line(
          ctx,
          "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line}))",
        )
      }
  }
}

///|
fn write_command_call(
  ctx : GenCtx,
  name : String,
  args : Array[@ir.Expr],
  line : Int,
) -> Unit {
  let detail = mbt_quote(@studio_lang.canonical_call_text(name, args))
  match name {
    "message_box" =>
      write_line(
        ctx,
        "rt.message_box(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}, \{detail})",
      )
    "set_text" =>
      write_line(
        ctx,
        "rt.set_text(\{write_control_name(ctx, args[0])}, \{write_value(ctx, args[1])}, \{mbt_quote(name)}, \{line}, \{detail})",
      )
    "append_row" =>
      write_line(
        ctx,
        "rt.append_row(\{write_control_name(ctx, args[0])}, \{write_value(ctx, args[1])}, \{mbt_quote(name)}, \{line}, \{detail})",
      )
    "broadcast" =>
      write_line(ctx, "rt.broadcast(\{write_value(ctx, args[0])}, \{line})")
    "append_list" => {
      // 第一个参数是变量名（裸标识符直接取名字，同解释轨）
      let list_name = match args[0] {
        @ir.Var(list_name) => mbt_quote(list_name)
        _ =>
          "@compiled_runtime.as_text(\{write_value(ctx, args[0])}, \"append_list\", \{line})"
      }
      write_line(
        ctx,
        "rt.append_list(\{list_name}, \{write_value(ctx, args[1])}, \{mbt_quote(name)}, \{line}, \{detail})",
      )
    }
    _ =>
      write_line(
        ctx,
        "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line}))",
      )
  }
}

///|
fn write_gate_call(
  ctx : GenCtx,
  name : String,
  args : Array[@ir.Expr],
  line : Int,
) -> Unit {
  let detail = mbt_quote(@studio_lang.canonical_call_text(name, args))
  match name {
    "submit_data" =>
      write_line(
        ctx,
        "ignore(rt.submit_data(\{write_control_name(ctx, args[1])}, \{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}, \{detail}))",
      )
    "ask" =>
      write_line(
        ctx,
        "ignore(rt.ask(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}, \{detail}))",
      )
    _ =>
      write_line(
        ctx,
        "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line}))",
      )
  }
}

///|
/// 控件名槽：裸变量按解释轨 `control_name` 语义直接取控件名，
/// 字符串字面量取文本，其余表达式运行期求值后转文本。
fn write_control_name(ctx : GenCtx, arg : @ir.Expr) -> String {
  match arg {
    @ir.Var(name) => mbt_quote(name)
    @ir.StrLit(text) => mbt_quote(text)
    other =>
      "@compiled_runtime.as_text(\{write_value(ctx, other)}, \"control\", \{ctx.audit_line})"
  }
}

///|
/// 表达式 → 生成源码表达式（类型恒为 `@compiled_runtime.Value`）。
fn write_value(ctx : GenCtx, expr : @ir.Expr) -> String {
  let line = ctx.audit_line
  match expr {
    @ir.NumLit(n) => "@compiled_runtime.VNum(\{number_literal(n)})"
    @ir.IntLit(n) => "@compiled_runtime.VInt(\{n})"
    @ir.StrLit(text) => "@compiled_runtime.VStr(\{mbt_quote(text)})"
    @ir.BoolLit(flag) =>
      "@compiled_runtime.VBool(\{if flag { "true" } else { "false" }})"
    @ir.Var(name) =>
      match @studio_lang.builtin_kind(name) {
        Some(_) =>
          "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line})); @compiled_runtime.VUnit"
        None => "rt.get(\{mbt_quote(name)}, \{line})"
      }
    @ir.Not(inner) =>
      "@compiled_runtime.not_value(\{write_value(ctx, inner)}, \{line})"
    @ir.Neg(inner) =>
      "@compiled_runtime.neg_value(\{write_value(ctx, inner)}, \{line})"
    @ir.ListLit(items) => {
      let buf = StringBuilder()
      buf.write_string("[")
      let mut first = true
      for item in items {
        if !first {
          buf.write_string(", ")
        }
        buf.write_string(write_value(ctx, item))
        first = false
      }
      buf.write_string("]")
      "@compiled_runtime.VArr(\{buf.to_string()})"
    }
    @ir.Index(base, index) =>
      "@compiled_runtime.index_values(\{write_value(ctx, base)}, \{write_value(ctx, index)}, \{line})"
    @ir.Binary(op, left, right) => write_binary(ctx, op, left, right)
    @ir.Call(name, args) => write_function_call(ctx, name, args)
    @ir.FieldAccess(base, field) =>
      "@compiled_runtime.get_field(\{write_value(ctx, base)}, \{mbt_quote(field)}, \{line})"
    @ir.EnumTag(enum_name, case_name) =>
      "@compiled_runtime.make_enum(\{mbt_quote(enum_name)}, \{mbt_quote(case_name)})"
  }
}

///|
fn write_binary(
  ctx : GenCtx,
  op : @ir.BinOp,
  left : @ir.Expr,
  right : @ir.Expr,
) -> String {
  let line = ctx.audit_line
  match op {
    @ir.Add =>
      "@compiled_runtime.add_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Sub =>
      "@compiled_runtime.sub_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Mul =>
      "@compiled_runtime.mul_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Div =>
      "@compiled_runtime.div_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Eq =>
      "@compiled_runtime.eq_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Ne =>
      "@compiled_runtime.neq_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \{line})"
    @ir.Lt =>
      "@compiled_runtime.compare_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \"<\", \{line})"
    @ir.Gt =>
      "@compiled_runtime.compare_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \">\", \{line})"
    @ir.Le =>
      "@compiled_runtime.compare_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \"<=\", \{line})"
    @ir.Ge =>
      "@compiled_runtime.compare_values(\{write_value(ctx, left)}, \{write_value(ctx, right)}, \">=\", \{line})"
    // 短路：右侧必须是 thunk；已假/已真时不求值（右侧可能含闸门）。
    @ir.And =>
      "@compiled_runtime.and_values(fn(rt : @compiled_runtime.Runtime) -> @compiled_runtime.Value raise @compiled_runtime.ExecError { \{write_value(ctx, left)} }, fn(rt : @compiled_runtime.Runtime) -> @compiled_runtime.Value raise @compiled_runtime.ExecError { \{write_value(ctx, right)} }, rt, \{line})"
    @ir.Or =>
      "@compiled_runtime.or_values(fn(rt : @compiled_runtime.Runtime) -> @compiled_runtime.Value raise @compiled_runtime.ExecError { \{write_value(ctx, left)} }, fn(rt : @compiled_runtime.Runtime) -> @compiled_runtime.Value raise @compiled_runtime.ExecError { \{write_value(ctx, right)} }, rt, \{line})"
  }
}

///|
fn write_function_call(
  ctx : GenCtx,
  name : String,
  args : Array[@ir.Expr],
) -> String {
  let line = ctx.audit_line
  let detail = mbt_quote(@studio_lang.canonical_call_text(name, args))
  match name {
    "get_text" =>
      "@compiled_runtime.get_text(rt, \{write_control_name(ctx, args[0])})"
    "get_number" =>
      "@compiled_runtime.get_number(rt, \{write_control_name(ctx, args[0])}, \{line})"
    "to_text" => "@compiled_runtime.to_text(\{write_value(ctx, args[0])})"
    "text_length" =>
      "@compiled_runtime.text_length(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "mod" =>
      "@compiled_runtime.mod_value(\{write_value(ctx, args[0])}, \{write_value(ctx, args[1])}, \{mbt_quote(name)}, \{line})"
    "round" =>
      "@compiled_runtime.round_value(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "stop_all" => "@compiled_runtime.stop_all(rt)"
    "wait" =>
      "@compiled_runtime.wait_value(rt, @compiled_runtime.as_number(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}))"
    "answer" => "@compiled_runtime.last_answer(rt)"
    "abs" =>
      "@compiled_runtime.abs_value(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "floor" =>
      "@compiled_runtime.floor_value(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "ceiling" =>
      "@compiled_runtime.ceiling_value(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "sqrt" =>
      "@compiled_runtime.sqrt_value(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line})"
    "contains" =>
      "@compiled_runtime.contains(\{write_value(ctx, args[0])}, \{write_value(ctx, args[1])}, \{mbt_quote(name)}, \{line})"
    "random" =>
      "@compiled_runtime.random(rt, \{write_value(ctx, args[0])}, \{line})"
    "row_count" =>
      "@compiled_runtime.row_count(rt, \{write_control_name(ctx, args[0])})"
    "row_at" =>
      "@compiled_runtime.row_at(rt, \{write_control_name(ctx, args[0])}, \{write_value(ctx, args[1])}, \{line})"
    "selected_row" =>
      "@compiled_runtime.selected_row(rt, \{write_control_name(ctx, args[0])})"
    "ask" =>
      "rt.ask(\{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}, \{detail})"
    "submit_data" =>
      "rt.submit_data(\{write_control_name(ctx, args[1])}, \{write_value(ctx, args[0])}, \{mbt_quote(name)}, \{line}, \{detail})"
    "message_box" | "set_text" | "append_row" =>
      // 命令不能出现在表达式位（语义校验拒绝）；保留同款错误路径。
      "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line})); @compiled_runtime.VUnit"
    // 内建没有 → 用户自定义函数（表达式位；返回值直接参与运算）
    _ =>
      if is_user_function(ctx, name) {
        "rt.call_user_function(\{mbt_quote(name)}, [\{write_args(ctx, args)}], \{line})"
      } else {
        "ignore(@compiled_runtime.unknown_builtin(\{mbt_quote(name)}, \{line})); @compiled_runtime.VUnit"
      }
  }
}

///|
/// 数字字面量：整数写成 `12.0`（Double），其余用领域内核的规范文本。
fn number_literal(value : Double) -> String {
  let text = @studio_lang.number_to_text(value)
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    text + ".0"
  }
}

///|
/// MoonBit 字符串字面量转义（`\` `"` `\n` `\r` `\t`）。
pub fn mbt_quote(text : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for ch in text {
    if ch == '\\' {
      buf.write_string("\\\\")
    } else if ch == '"' {
      buf.write_string("\\\"")
    } else if ch == '\n' {
      buf.write_string("\\n")
    } else if ch == '\r' {
      buf.write_string("\\r")
    } else if ch == '\t' {
      buf.write_string("\\t")
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}
