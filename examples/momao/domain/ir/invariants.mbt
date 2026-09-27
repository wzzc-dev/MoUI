///|
/// IR 结构不变量与预算：decode / 编辑 / AI 提案 / 导出四处共用同一套。
/// 本包只管「结构对不对」；内置命令名、关键字、可读性政策在
/// `momao_lang` 与 `proposals`（它们不依赖本包，避免反向依赖）。

///|
pub const MAX_CONTROLS : Int = 128

///|
pub const MAX_VARIABLES : Int = 64

///|
pub const MAX_HANDLERS : Int = 64

///|
pub const MAX_STMTS_PER_HANDLER : Int = 512

///|
pub const MAX_TOTAL_STMTS : Int = 4096

///|
pub const MAX_LOOP_DEPTH : Int = 64

///|
pub const MAX_EXPR_DEPTH : Int = 32

///|
/// 结构错误（可读文案由界面层经 i18n catalog 本地化）。
pub(all) enum IrError {
  DuplicateControlName(String)
  InvalidControlName(String)
  DuplicateVariableName(String)
  DuplicateHandler(String)
  UnknownControlInHandler(String)
  UnsupportedEvent(String, String)
  TooManyControls
  TooManyVariables
  TooManyHandlers
  TooManyStatements(Int)
  LoopTooDeep(Int)
  ExprTooDeep(Int)
}

///|
/// 收集全部结构问题（不短路：一次报全，教学场景更友好）。
pub fn validate_program(program : MomaoProgram) -> Array[IrError] {
  let errors : Array[IrError] = []
  if program.controls.length() > MAX_CONTROLS {
    errors.push(TooManyControls)
  }
  if program.variables.length() > MAX_VARIABLES {
    errors.push(TooManyVariables)
  }
  if program.handlers.length() > MAX_HANDLERS {
    errors.push(TooManyHandlers)
  }
  let mut total_stmts = 0
  let names : Array[String] = []
  for control in program.controls {
    if !control_name_syntax_valid(control.name) {
      errors.push(InvalidControlName(control.name))
    }
    if names.contains(control.name) {
      errors.push(DuplicateControlName(control.name))
    } else {
      names.push(control.name)
    }
    total_stmts = total_stmts + stmts_in_control_events(program, control.name)
  }
  let var_names : Array[String] = []
  for variable in program.variables {
    if !variable_name_syntax_valid(variable.name) {
      errors.push(InvalidControlName(variable.name))
    }
    if var_names.contains(variable.name) {
      errors.push(DuplicateVariableName(variable.name))
    } else {
      var_names.push(variable.name)
    }
  }
  for handler in program.handlers {
    total_stmts = total_stmts + count_stmts(handler.body)
    if handler.body.length() > MAX_STMTS_PER_HANDLER {
      errors.push(TooManyStatements(handler.body.length()))
    }
    if stmt_loop_depth(handler.body) > MAX_LOOP_DEPTH {
      errors.push(LoopTooDeep(stmt_loop_depth(handler.body)))
    }
    if body_expr_depth(handler.body) > MAX_EXPR_DEPTH {
      errors.push(ExprTooDeep(body_expr_depth(handler.body)))
    }
    match find_control(program, handler.control_name) {
      Some(control) =>
        if !control.kind.supports_event(handler.event) {
          errors.push(
            UnsupportedEvent(handler.control_name, handler.event.tag()),
          )
        }
      None => errors.push(UnknownControlInHandler(handler.control_name))
    }
  }
  if total_stmts > MAX_TOTAL_STMTS {
    errors.push(TooManyStatements(total_stmts))
  }
  errors
}

///|
/// 控件事件子程序不单独存储；handler 只记（控件, 事件）。
/// 该函数统计挂在该控件上的全部 handler 语句数。
fn stmts_in_control_events(
  program : MomaoProgram,
  control_name : String,
) -> Int {
  let mut total = 0
  for handler in program.handlers {
    if handler.control_name == control_name {
      total = total + count_stmts(handler.body)
    }
  }
  total
}

///|
/// 语句总数（循环体按静态出现一次计，不展开）。
pub fn count_stmts(body : Array[Stmt]) -> Int {
  let mut total = 0
  for stmt in body {
    total = total + count_stmt(stmt)
  }
  total
}

///|
fn count_stmt(stmt : Stmt) -> Int {
  match stmt {
    Declare(_, _) | Assign(_, _) | Call(_, _) | Break => 1
    If(_, then_body, else_ifs, else_body) =>
      1 +
      count_stmts(then_body) +
      count_stmts(else_body) +
      count_if_chain(else_ifs)
    CountLoop(_, _, body) | WhileLoop(_, body) => 1 + count_stmts(body)
  }
}

///|
fn count_if_chain(arms : Array[(Expr, Array[Stmt])]) -> Int {
  let mut total = 0
  for arm in arms {
    total = total + 1 + count_stmts(arm.1)
  }
  total
}

///|
/// 循环嵌套深度（If 不计入；循环内嵌循环才计）。
pub fn stmt_loop_depth(body : Array[Stmt]) -> Int {
  body_loop_depth(body, 0)
}

///|
fn body_loop_depth(body : Array[Stmt], current : Int) -> Int {
  let mut deepest = current
  for stmt in body {
    let depth = match stmt {
      Declare(_, _) | Assign(_, _) | Call(_, _) | Break => current
      If(_, then_body, else_ifs, else_body) => {
        let inner = body_loop_depth(then_body, current)
        let inner2 = body_loop_depth(else_body, inner)
        let mut arms = inner2
        for arm in else_ifs {
          let inner3 = body_loop_depth(arm.1, inner2)
          if inner3 > arms {
            arms = inner3
          }
        }
        arms
      }
      CountLoop(_, _, loop_body) | WhileLoop(_, loop_body) =>
        body_loop_depth(loop_body, current + 1)
    }
    if depth > deepest {
      deepest = depth
    }
  }
  deepest
}

///|
/// 表达式最大深度（防栈爆与不可读的巨型单行）。
pub fn expr_depth(expr : Expr) -> Int {
  match expr {
    NumLit(_) | StrLit(_) | BoolLit(_) | Var(_) => 1
    Not(inner) | Neg(inner) => 1 + expr_depth(inner)
    Binary(_, left, right) => {
      let l = expr_depth(left)
      let r = expr_depth(right)
      (if l > r { l } else { r }) + 1
    }
    Call(_, args) => {
      let mut deepest = 0
      for arg in args {
        let d = expr_depth(arg)
        if d > deepest {
          deepest = d
        }
      }
      deepest + 1
    }
  }
}

///|
fn body_expr_depth(body : Array[Stmt]) -> Int {
  let mut deepest = 0
  for stmt in body {
    let d = stmt_expr_depth(stmt)
    if d > deepest {
      deepest = d
    }
  }
  deepest
}

///|
fn stmt_expr_depth(stmt : Stmt) -> Int {
  match stmt {
    Declare(_, expr) | Assign(_, expr) => expr_depth(expr)
    Call(_, args) => {
      let mut deepest = 0
      for arg in args {
        let d = expr_depth(arg)
        if d > deepest {
          deepest = d
        }
      }
      deepest
    }
    Break => 0
    If(cond, then_body, else_ifs, else_body) => {
      let mut deepest = expr_depth(cond)
      let then_depth = body_expr_depth(then_body)
      let else_depth = body_expr_depth(else_body)
      if then_depth > deepest {
        deepest = then_depth
      }
      if else_depth > deepest {
        deepest = else_depth
      }
      for arm in else_ifs {
        let arm_depth = expr_depth(arm.0)
        if arm_depth > deepest {
          deepest = arm_depth
        }
        let arm_body = body_expr_depth(arm.1)
        if arm_body > deepest {
          deepest = arm_body
        }
      }
      deepest
    }
    CountLoop(times, _, body) => {
      let count_depth = expr_depth(times)
      let body_depth = body_expr_depth(body)
      if count_depth > body_depth {
        count_depth
      } else {
        body_depth
      }
    }
    WhileLoop(cond, body) => {
      let cond_depth = expr_depth(cond)
      let body_depth = body_expr_depth(body)
      if cond_depth > body_depth {
        cond_depth
      } else {
        body_depth
      }
    }
  }
}
