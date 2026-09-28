///|
/// 语言级校验：break 作用域、内建名是否存在、命令不能出现在表达式位、
/// 参数个数。与 `ir` 的结构校验互补，提案/解码全链共用。

///|
/// 校验整个程序的语言层问题（IR 无行号，错误行号为 0）。
pub fn validate_program_language(program : StudioProgram) -> Array[LangError] {
  let errors : Array[LangError] = []
  for control in program.controls {
    if is_reserved(control.name) {
      errors.push(LangError(ReservedWord, 0, control.name, ""))
    }
  }
  for variable in program.variables {
    if is_reserved(variable.name) {
      errors.push(LangError(ReservedWord, 0, variable.name, ""))
    }
  }
  for handler in program.handlers {
    let declared : Array[String] = []
    for variable in program.variables {
      declared.push(variable.name)
    }
    check_body(handler.body, errors, [], declared)
    check_round_trip(handler.body, errors)
  }
  errors
}

///|
fn check_body(
  body : Array[Stmt],
  errors : Array[LangError],
  in_loop : Array[Bool],
  declared : Array[String],
) -> Unit {
  for stmt in body {
    match stmt {
      @ir.Break =>
        if in_loop.length() == 0 {
          errors.push(LangError(BreakOutsideLoop, 0, "", ""))
        }
      @ir.Declare(name, expr) => {
        check_name(name, errors)
        check_expr(expr, errors, declared)
        if !declared.contains(name) {
          declared.push(name)
        }
      }
      @ir.Assign(name, expr) => {
        if !declared.contains(name) {
          errors.push(LangError(NotDeclared, 0, name, ""))
        }
        check_expr(expr, errors, declared)
      }
      @ir.Call(name, args) => check_call(name, args, errors, true, declared)
      @ir.If(cond, then_body, else_ifs, else_body) => {
        check_expr(cond, errors, declared)
        check_body(then_body, errors, in_loop, declared)
        for arm in else_ifs {
          check_expr(arm.0, errors, declared)
          check_body(arm.1, errors, in_loop, declared)
        }
        check_body(else_body, errors, in_loop, declared)
      }
      @ir.CountLoop(times, loop_var, loop_body) => {
        check_expr(times, errors, declared)
        match loop_var {
          Some(name) => {
            check_name(name, errors)
            if !declared.contains(name) {
              declared.push(name)
            }
          }
          None => ()
        }
        check_body(loop_body, errors, in_loop_plus(in_loop), declared)
      }
      @ir.WhileLoop(cond, loop_body) => {
        check_expr(cond, errors, declared)
        check_body(loop_body, errors, in_loop_plus(in_loop), declared)
      }
    }
  }
}

///|
/// 标识符必须在两门 DSL 中都能作为普通名字使用。
fn check_name(name : String, errors : Array[LangError]) -> Unit {
  if is_reserved(name) {
    errors.push(LangError(ReservedWord, 0, name, ""))
  }
}

///|
/// codec/提案入口也必须守住双语渲染闭环，不能只依赖样例测试。
fn check_round_trip(body : Array[Stmt], errors : Array[LangError]) -> Unit {
  for language in [ZhHans, En] {
    let rendered = render_stmts(body, language)
    match parse_handler_body(rendered, language) {
      Ok(traced) => {
        let parsed = traced.map(item => item.stmt)
        if @ir.stmts_signature(parsed) != @ir.stmts_signature(body) {
          errors.push(LangError(UnexpectedToken, 0, "round-trip", ""))
        }
      }
      Err(error) => errors.push(error)
    }
  }
}

///|
fn check_expr(
  expr : Expr,
  errors : Array[LangError],
  declared : Array[String],
) -> Unit {
  match expr {
    @ir.NumLit(_) | @ir.StrLit(_) | @ir.BoolLit(_) => ()
    @ir.Var(name) =>
      if !declared.contains(name) {
        errors.push(LangError(NotDeclared, 0, name, ""))
      }
    @ir.Not(inner) | @ir.Neg(inner) => check_expr(inner, errors, declared)
    @ir.Binary(_, left, right) => {
      check_expr(left, errors, declared)
      check_expr(right, errors, declared)
    }
    @ir.Call(name, args) => check_call(name, args, errors, false, declared)
  }
}

///|
/// 语句位（statement=true）允许命令；表达式位只允许函数与闸门。
fn check_call(
  name : String,
  args : Array[Expr],
  errors : Array[LangError],
  statement : Bool,
  declared : Array[String],
) -> Unit {
  match find_builtin(name) {
    None => errors.push(LangError(UnknownBuiltin, 0, name, ""))
    Some(spec) => {
      if !statement && spec.kind is Command {
        errors.push(LangError(TypeMismatch, 0, spec.id, "expression"))
      }
      if args.length() != spec.arity {
        errors.push(
          LangError(ArityMismatch, 0, spec.id, "\{spec.arity}/\{args.length()}"),
        )
      }
      // A bare Var in a control-name slot is a control identifier by DSL
      // convention (for example `set_text(Result, value)`), not a variable
      // lookup. Dynamic expressions in that slot still undergo normal checks.
      let mut index = 0
      while index < args.length() {
        let arg = args[index]
        if !is_control_name_arg(spec.id, index, arg) {
          check_expr(arg, errors, declared)
        }
        index = index + 1
      }
    }
  }
}

///|
fn is_control_name_arg(name : String, index : Int, arg : Expr) -> Bool {
  let target_slot = index == 0 &&
    (
      name == "set_text" ||
      name == "append_row" ||
      name == "get_text" ||
      name == "get_number" ||
      name == "row_count" ||
      name == "row_at" ||
      name == "selected_row"
    )
  let submit_target_slot = name == "submit_data" && index == 1
  if !target_slot && !submit_target_slot {
    return false
  }
  match arg {
    @ir.Var(_) => true
    _ => false
  }
}

///|
/// 循环体内的 break 合法：压入一层循环标记（spread 语法不可用，显式拷贝）。
fn in_loop_plus(in_loop : Array[Bool]) -> Array[Bool] {
  let copied : Array[Bool] = []
  for flag in in_loop {
    copied.push(flag)
  }
  copied.push(true)
  copied
}
