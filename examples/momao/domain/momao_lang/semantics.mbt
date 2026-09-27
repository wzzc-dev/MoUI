///|
/// 语言级校验：break 作用域、内建名是否存在、命令不能出现在表达式位、
/// 参数个数。与 `ir` 的结构校验互补，提案/解码全链共用。

///|
/// 校验整个程序的语言层问题（IR 无行号，错误行号为 0）。
pub fn validate_program_language(program : MomaoProgram) -> Array[LangError] {
  let errors : Array[LangError] = []
  for handler in program.handlers {
    check_body(handler.body, errors, [])
  }
  errors
}

///|
fn check_body(
  body : Array[Stmt],
  errors : Array[LangError],
  in_loop : Array[Bool],
) -> Unit {
  for stmt in body {
    match stmt {
      @ir.Break =>
        if in_loop.length() == 0 {
          errors.push(LangError(BreakOutsideLoop, 0, "", ""))
        }
      @ir.Declare(_, expr) | @ir.Assign(_, expr) => check_expr(expr, errors)
      @ir.Call(name, args) => {
        check_call(name, args, errors, true)
        for arg in args {
          check_expr(arg, errors)
        }
      }
      @ir.If(cond, then_body, else_ifs, else_body) => {
        check_expr(cond, errors)
        check_body(then_body, errors, in_loop)
        for arm in else_ifs {
          check_expr(arm.0, errors)
          check_body(arm.1, errors, in_loop)
        }
        check_body(else_body, errors, in_loop)
      }
      @ir.CountLoop(times, _, loop_body) => {
        check_expr(times, errors)
        check_body(loop_body, errors, in_loop_plus(in_loop))
      }
      @ir.WhileLoop(cond, loop_body) => {
        check_expr(cond, errors)
        check_body(loop_body, errors, in_loop_plus(in_loop))
      }
    }
  }
}

///|
fn check_expr(expr : Expr, errors : Array[LangError]) -> Unit {
  match expr {
    @ir.NumLit(_) | @ir.StrLit(_) | @ir.BoolLit(_) | @ir.Var(_) => ()
    @ir.Not(inner) | @ir.Neg(inner) => check_expr(inner, errors)
    @ir.Binary(_, left, right) => {
      check_expr(left, errors)
      check_expr(right, errors)
    }
    @ir.Call(name, args) => {
      check_call(name, args, errors, false)
      for arg in args {
        check_expr(arg, errors)
      }
    }
  }
}

///|
/// 语句位（statement=true）允许命令；表达式位只允许函数与闸门。
fn check_call(
  name : String,
  args : Array[Expr],
  errors : Array[LangError],
  statement : Bool,
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
    }
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
