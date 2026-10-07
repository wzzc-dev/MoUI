///|
/// IR 结构不变量与预算：decode / 编辑 / AI 提案 / 导出四处共用同一套。
/// 本包只管「结构对不对」；内置命令名、关键字、可读性政策在
/// `studio_lang` 与 `proposals`（它们不依赖本包，避免反向依赖）。

///|
pub const MAX_CONTROLS : Int = 128

///|
pub const MAX_VARIABLES : Int = 64

///|
pub const MAX_HANDLERS : Int = 64

///|
pub const MAX_FUNCS : Int = 16

///|
pub const MAX_PARAMS : Int = 8

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
  InvalidVariableName(String)
  DuplicateVariableName(String)
  InvalidControlRect(String)
  DuplicateHandler(String)
  UnknownControlInHandler(String)
  UnsupportedEvent(String, String)
  TooManyControls
  TooManyVariables
  TooManyHandlers
  TooManyStatements(Int)
  LoopTooDeep(Int)
  ExprTooDeep(Int)
  DuplicateFunctionName(String)
  InvalidFunctionName(String)
  DuplicateParam(String, String)
}

///|
/// 收集全部结构问题（不短路：一次报全，教学场景更友好）。
pub fn validate_program(program : StudioProgram) -> Array[IrError] {
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
    if control.x < 0 ||
      control.y < 0 ||
      control.width < MIN_CONTROL_SIZE ||
      control.height < MIN_CONTROL_SIZE ||
      control.x + control.width > DESIGN_WIDTH ||
      control.y + control.height > DESIGN_HEIGHT {
      errors.push(InvalidControlRect(control.name))
    }
  }
  let var_names : Array[String] = []
  for variable in program.variables {
    if !variable_name_syntax_valid(variable.name) {
      errors.push(InvalidVariableName(variable.name))
    }
    if var_names.contains(variable.name) {
      errors.push(DuplicateVariableName(variable.name))
    } else {
      var_names.push(variable.name)
    }
  }
  // (控件, 事件) 对唯一（计划 §3 不变量）；重复对使 find_handler 语义不确定
  let handler_pairs : Array[String] = []
  for handler in program.handlers {
    let pair = "\{handler.control_name}@\{handler.event.tag()}"
    if handler_pairs.contains(pair) {
      errors.push(DuplicateHandler(handler.control_name))
    } else {
      handler_pairs.push(pair)
    }
  }
  for handler in program.handlers {
    let handler_stmts = count_stmts(handler.body)
    total_stmts = total_stmts + handler_stmts
    if handler_stmts > MAX_STMTS_PER_HANDLER {
      errors.push(TooManyStatements(handler_stmts))
    }
    if stmt_loop_depth(handler.body) > MAX_LOOP_DEPTH {
      errors.push(LoopTooDeep(stmt_loop_depth(handler.body)))
    }
    if body_expr_depth(handler.body) > MAX_EXPR_DEPTH {
      errors.push(ExprTooDeep(body_expr_depth(handler.body)))
    }
    // 窗体级事件（control_name = ""）：定时器/广播/启动——虚拟时钟、
    // 广播总线与启动语义不属于任何控件
    if handler.control_name == "" {
      if !(handler.event is OnTimer) &&
        !(handler.event is OnBroadcast) &&
        !(handler.event is OnStart) {
        errors.push(UnsupportedEvent("", handler.event.tag()))
      }
    } else {
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
  }
  // 用户函数：数量 / 命名 / 重名 / 参数重名 / 体预算
  if program.functions.length() > MAX_FUNCS {
    errors.push(TooManyStatements(program.functions.length()))
  }
  let func_names : Array[String] = []
  for func in program.functions {
    if !variable_name_syntax_valid(func.name) {
      errors.push(InvalidFunctionName(func.name))
    }
    if func_names.contains(func.name) {
      errors.push(DuplicateFunctionName(func.name))
    } else {
      func_names.push(func.name)
    }
    let param_names : Array[String] = []
    for param in func.params {
      if param_names.contains(param) {
        errors.push(DuplicateParam(func.name, param))
      } else {
        param_names.push(param)
      }
    }
    if func.params.length() > MAX_PARAMS {
      errors.push(DuplicateParam(func.name, "…"))
    }
    let func_stmts = count_stmts(func.body)
    total_stmts = total_stmts + func_stmts
    if stmt_loop_depth(func.body) > MAX_LOOP_DEPTH {
      errors.push(LoopTooDeep(stmt_loop_depth(func.body)))
    }
    if body_expr_depth(func.body) > MAX_EXPR_DEPTH {
      errors.push(ExprTooDeep(body_expr_depth(func.body)))
    }
  }
  if total_stmts > MAX_TOTAL_STMTS {
    errors.push(TooManyStatements(total_stmts))
  }
  errors
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
    Declare(_, _)
    | Assign(_, _)
    | Call(_, _)
    | Break
    | SetIndex(_, _, _)
    | Return(_) => 1
    If(_, then_body, else_ifs, else_body) =>
      1 +
      count_stmts(then_body) +
      count_stmts(else_body) +
      count_if_chain(else_ifs)
    CountLoop(_, _, body) | ForEach(_, _, body) | WhileLoop(_, body) =>
      1 + count_stmts(body)
    Match(_, arms, else_body) =>
      1 + count_stmts(else_body) + count_match_arms(arms)
  }
}

///|
fn count_match_arms(arms : Array[MatchArm]) -> Int {
  let mut total = 0
  for arm in arms {
    total = total + count_stmts(arm.body)
  }
  total
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
      Declare(_, _)
      | Assign(_, _)
      | Call(_, _)
      | Break
      | SetIndex(_, _, _)
      | Return(_) => current
      If(_, then_body, else_ifs, else_body) => {
        let then_depth = body_loop_depth(then_body, current)
        let else_depth = body_loop_depth(else_body, current)
        let mut arms = if then_depth > else_depth {
          then_depth
        } else {
          else_depth
        }
        for arm in else_ifs {
          let inner3 = body_loop_depth(arm.1, current)
          if inner3 > arms {
            arms = inner3
          }
        }
        arms
      }
      CountLoop(_, _, loop_body) | ForEach(_, _, loop_body) | WhileLoop(_, loop_body) =>
        body_loop_depth(loop_body, current + 1)
      Match(_, arms, else_body) => {
        let mut deepest_arm = body_loop_depth(else_body, current)
        for arm in arms {
          let inner = body_loop_depth(arm.body, current)
          if inner > deepest_arm {
            deepest_arm = inner
          }
        }
        deepest_arm
      }
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
    NumLit(_) | IntLit(_) | StrLit(_) | BoolLit(_) | Var(_) => 1
    Not(inner) | Neg(inner) => 1 + expr_depth(inner)
    Index(base, index) => {
      let b = expr_depth(base)
      let i = expr_depth(index)
      (if b > i { b } else { i }) + 1
    }
    FieldAccess(base, _) => 1 + expr_depth(base)
    EnumTag(_, _) => 1
    ListLit(items) => {
      let mut deepest = 0
      for item in items {
        let d = expr_depth(item)
        if d > deepest {
          deepest = d
        }
      }
      deepest + 1
    }
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
    Return(expr) =>
      match expr {
        Some(value) => expr_depth(value)
        None => 0
      }
    SetIndex(_, index, value) => {
      let i = expr_depth(index)
      let v = expr_depth(value)
      if i > v {
        i
      } else {
        v
      }
    }
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
    ForEach(list_expr, _, body) => {
      let list_depth = expr_depth(list_expr)
      let body_depth = body_expr_depth(body)
      if list_depth > body_depth {
        list_depth
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
    Match(subject, arms, else_body) => {
      let mut deepest = expr_depth(subject)
      let else_depth = body_expr_depth(else_body)
      if else_depth > deepest {
        deepest = else_depth
      }
      for arm in arms {
        let arm_body = body_expr_depth(arm.body)
        if arm_body > deepest {
          deepest = arm_body
        }
      }
      deepest
    }
  }
}
