///|
/// 选中与非控件对象（窗体 / 变量 / 数据）的消息处理。
///
/// 从 `update.mbt` 拆出：那里已 1014 行，逼近 1200 硬上限；而且这组消息
/// 的主题是「选中与左侧结构树的对象生命周期」，与外壳/设计/运行域并列，
/// 独立成域比继续堆在 shell 域里更清楚。
///
/// 所有选中变更都经 `update_selection.mbt` 的漏斗，本文件只负责
/// 「消息 → 漏斗 + 变量 CRUD」的翻译。

///|
/// 变量名自动去重：`变量1`、`变量2`…（与控件命名同一手法，避免用户
/// 新建两个变量时撞名——`validate_program` 会把重名当致命错误）。
fn fresh_variable_name(program : @ir.StudioProgram) -> String {
  let mut index = 1
  while index < 1000 {
    let candidate = "变量" + index.to_string()
    let mut taken = false
    for variable in program.variables {
      if variable.name == candidate {
        taken = true
      }
    }
    if !taken {
      return candidate
    }
    index = index + 1
  }
  "变量"
}

///|
/// 新建变量：名称自动去重、初值空串（与 `Declare` 的空文本初值同口径）。
/// 预算防呆与 `AddControl` 一致（超限经 with_notice 提示，不静默）。
fn add_variable(model : Model) -> Model {
  if model.program.variables.length() >= @ir.MAX_VARIABLES {
    return with_notice(
      model,
      text(translator(model), "app.status.variables_limit"),
      true,
    )
  }
  let name = fresh_variable_name(model.program)
  let variables = model.program.variables
  variables.push(@ir.Variable::{ name, init: "", })
  let next = { ..model, program: { ..model.program, variables, }, notice: "", }
  // 建完即选中：用户马上能在右栏改名字与初值（与「插入语句后选中该语句」
  // 同一节奏——新建对象必须立刻可编辑）。
  select_target(next, SideVariable(name))
}

///|
/// 新建一个**自定义积木**（Scratch 的「制作一个积木」）。
///
/// 语言层 / 解释器 / 编译运行时早就支持 `FuncDef`（`return`、`functions`
/// 参数、`lower_user_function` 都在），但只能从 JSON 进来——界面上没有
/// 创建入口，所以「定义自己的积木」在积木界面里做不到。这里补上入口，
/// 走 IR 手术（与 `AddVariable` 同一纪律：克隆后手术、建完即选中）。
///
/// 新函数带一个**空体**：先让用户看到积木头与参数位，再往里放语句。
/// 函数体里默认放一条 `return`，因为空体函数在语义层是合法的但运行起来
/// 什么都不发生——给一条 `return` 让「返回」这件事在界面上可见。
fn add_function(model : Model) -> Model {
  if model.program.functions.length() >= @ir.MAX_FUNCS {
    return with_notice(
      model,
      text(translator(model), "app.status.functions_limit"),
      true,
    )
  }
  let name = fresh_function_name(model.program)
  let functions = model.program.functions
  functions.push(@ir.FuncDef::{
    name,
    params: [],
    body: [@ir.Return(None)],
    note_zh: "",
    note_en: "",
  })
  let next = { ..model, program: { ..model.program, functions, }, notice: "", }
  // 建完即选中：右栏立刻能改名（与「新建变量后选中」同一节奏）
  select_target(next, SideFunction(name))
}

///|
/// 重命名自定义积木，并同步改写**所有调用点**。
///
/// 与变量重命名同一理由：调用点的函数名不是用户能逐个找到的东西（积木上
/// 显示的是渲染后的文本），不同步就会出现「改了名，旧调用还在调旧名字」
/// ——运行时报「函数不存在」，而用户以为自己改好了。
fn rename_function(model : Model, from : String, to : String) -> Model {
  let trimmed = to.trim().to_owned()
  if trimmed.length() == 0 || trimmed == from {
    return model
  }
  // 名字不能与别的函数撞（撞了会调用到错的那个）
  for func in model.program.functions {
    if func.name == trimmed && func.name != from {
      return with_notice(
        model,
        text(translator(model), "app.status.function_name_taken"),
        true,
      )
    }
  }
  let functions : Array[@ir.FuncDef] = []
  for func in model.program.functions {
    if func.name == from {
      functions.push(@ir.FuncDef::{ ..func, name: trimmed, })
    } else {
      functions.push(func)
    }
  }
  // 同步改写子程序体里对该函数的调用
  let handlers : Array[@ir.Handler] = []
  for handler in model.program.handlers {
    handlers.push(@ir.Handler::{
      ..handler,
      body: rename_calls_in_stmts(handler.body, from, trimmed),
    })
  }
  // 其他函数体里也可能调用它
  let renamed_funcs : Array[@ir.FuncDef] = []
  for func in functions {
    renamed_funcs.push(@ir.FuncDef::{
      ..func,
      body: rename_calls_in_stmts(func.body, from, trimmed),
    })
  }
  let next = {
    ..model,
    program: { ..model.program, functions: renamed_funcs, handlers, },
    notice: "",
  }
  // 选中槽跟着改名（否则槽指向一个已经不存在的名字）
  if model.side_target is Some(SideFunction(old)) && old == from {
    select_target(next, SideFunction(trimmed))
  } else {
    next
  }
}

///|
/// 把语句树里所有 `Call(from, ...)` 改成 `Call(to, ...)`（递归进控制流体）。
fn rename_calls_in_stmts(
  body : Array[@ir.Stmt],
  from : String,
  to : String,
) -> Array[@ir.Stmt] {
  let result : Array[@ir.Stmt] = []
  for stmt in body {
    result.push(
      match stmt {
        @ir.Stmt::Call(name, args) =>
          if name == from {
            @ir.Stmt::Call(to, args)
          } else {
            stmt
          }
        @ir.If(cond, then_body, arms, else_body) => {
          let new_arms : Array[(@ir.Expr, Array[@ir.Stmt])] = []
          for arm in arms {
            new_arms.push((arm.0, rename_calls_in_stmts(arm.1, from, to)))
          }
          @ir.If(
            cond,
            rename_calls_in_stmts(then_body, from, to),
            new_arms,
            rename_calls_in_stmts(else_body, from, to),
          )
        }
        @ir.CountLoop(times, loop_var, loop_body) =>
          @ir.CountLoop(
            times,
            loop_var,
            rename_calls_in_stmts(loop_body, from, to),
          )
        @ir.WhileLoop(cond, loop_body) =>
          @ir.WhileLoop(cond, rename_calls_in_stmts(loop_body, from, to))
        _ => stmt
      },
    )
  }
  result
}

///|
/// 未占用的函数名（`我的积木1` / `我的积木2`…）。
fn fresh_function_name(program : @ir.StudioProgram) -> String {
  let mut index = 1
  while index < 1000 {
    let candidate = "我的积木" + index.to_string()
    let mut taken = false
    for func in program.functions {
      if func.name == candidate {
        taken = true
      }
    }
    if !taken {
      return candidate
    }
    index = index + 1
  }
  "我的积木"
}

///|
/// 重命名变量，并同步改写所有引用它的表达式（`Var(name)`）。
///
/// 为什么不留给用户自己改引用：变量的引用**没有图形化入口**（只有代码
/// 视图），改名不同步会让程序静默变成「引用了未声明变量」——那正是
/// `validate_program` 会拦下的错误，用户却不知道是自己改名造成的。
/// 控件的重命名早有同样的同步逻辑（`rename_control_in_expr` 一带），
/// 变量沿用同一纪律。
fn rename_variable(model : Model, from : String, to : String) -> Model {
  let target = to.trim().to_owned()
  // 语法非法或与其他变量重名 → 保持原名（不静默改成非法状态）
  if !@ir.variable_name_syntax_valid(target) {
    return model
  }
  for variable in model.program.variables {
    if variable.name == target && variable.name != from {
      return model
    }
  }
  let variables : Array[@ir.Variable] = []
  for variable in model.program.variables {
    if variable.name == from {
      variables.push(@ir.Variable::{ ..variable, name: target, })
    } else {
      variables.push(variable)
    }
  }
  let handlers : Array[@ir.Handler] = []
  for handler in model.program.handlers {
    handlers.push(@ir.Handler::{
      ..handler,
      body: rename_var_in_stmts(handler.body, from, target),
    })
  }
  let renamed = {
    ..model,
    program: { ..model.program, variables, handlers, },
    notice: "",
  }
  // 选中态跟着改名走（否则右栏会显示「什么都没选」）
  match model.side_target {
    Some(SideVariable(name)) if name == from =>
      select_target(renamed, SideVariable(target))
    _ => renamed
  }
}

///|
/// 修改变量初值。
fn set_variable_init(model : Model, name : String, init : String) -> Model {
  let variables : Array[@ir.Variable] = []
  for variable in model.program.variables {
    if variable.name == name {
      variables.push(@ir.Variable::{ ..variable, init, })
    } else {
      variables.push(variable)
    }
  }
  { ..model, program: { ..model.program, variables, }, }
}

///|
/// 删除变量。**不**自动清理引用它的语句——静默改写程序语义比留下一个
/// 显式错误更糟。引用仍在时编译/导出会如实报「未声明变量」，用户看得见。
fn delete_variable(model : Model, name : String) -> Model {
  let variables : Array[@ir.Variable] = []
  for variable in model.program.variables {
    if variable.name != name {
      variables.push(variable)
    }
  }
  let next = {
    ..model,
    program: { ..model.program, variables, },
    runtime_values: @studio_lang.initial_values({ ..model.program, variables, }),
  }
  match model.side_target {
    Some(SideVariable(selected)) if selected == name => clear_selection(next)
    _ => next
  }
}

// ============================================================================
// 变量改名在语句树里的同步（纯函数，递归覆盖 If / 循环体）
// ============================================================================

///|
fn rename_var_in_stmts(
  body : Array[@ir.Stmt],
  from : String,
  to : String,
) -> Array[@ir.Stmt] {
  let out : Array[@ir.Stmt] = []
  for stmt in body {
    out.push(rename_var_in_stmt(stmt, from, to))
  }
  out
}

///|
fn rename_var_in_stmt(stmt : @ir.Stmt, from : String, to : String) -> @ir.Stmt {
  match stmt {
    @ir.Declare(name, expr) =>
      @ir.Declare(
        if name == from {
          to
        } else {
          name
        },
        rename_var_in_expr(expr, from, to),
      )
    @ir.Assign(name, expr) =>
      @ir.Assign(
        if name == from {
          to
        } else {
          name
        },
        rename_var_in_expr(expr, from, to),
      )
    @ir.SetIndex(name, index, value) =>
      @ir.SetIndex(
        if name == from {
          to
        } else {
          name
        },
        rename_var_in_expr(index, from, to),
        rename_var_in_expr(value, from, to),
      )
    @ir.Return(expr) =>
      @ir.Return(
        match expr {
          Some(value) => Some(rename_var_in_expr(value, from, to))
          None => None
        },
      )
    @ir.If(cond, then_body, arms, else_body) => {
      let new_arms : Array[(@ir.Expr, Array[@ir.Stmt])] = []
      for arm in arms {
        new_arms.push(
          (
            rename_var_in_expr(arm.0, from, to),
            rename_var_in_stmts(arm.1, from, to),
          ),
        )
      }
      @ir.If(
        rename_var_in_expr(cond, from, to),
        rename_var_in_stmts(then_body, from, to),
        new_arms,
        rename_var_in_stmts(else_body, from, to),
      )
    }
    @ir.ForEach(list_expr, iter, loop_body) =>
      @ir.ForEach(
        rename_var_in_expr(list_expr, from, to),
        if iter == from {
          to
        } else {
          iter
        },
        rename_var_in_stmts(loop_body, from, to),
      )
    @ir.CountLoop(times, iter, loop_body) =>
      @ir.CountLoop(
        rename_var_in_expr(times, from, to),
        match iter {
          Some(name) => Some(if name == from { to } else { name })
          None => None
        },
        rename_var_in_stmts(loop_body, from, to),
      )
    @ir.WhileLoop(cond, loop_body) =>
      @ir.WhileLoop(
        rename_var_in_expr(cond, from, to),
        rename_var_in_stmts(loop_body, from, to),
      )
    @ir.Break => @ir.Break
    @ir.Stmt::Call(name, args) => {
      let renamed : Array[@ir.Expr] = []
      for arg in args {
        renamed.push(rename_var_in_expr(arg, from, to))
      }
      @ir.Stmt::Call(name, renamed)
    }
    @ir.Match(subject, arms, else_body) =>
      @ir.Match(
        rename_var_in_expr(subject, from, to),
        arms.map(arm => @ir.MatchArm::{
          case_name: arm.case_name,
          body: rename_var_in_stmts(arm.body, from, to),
        }),
        rename_var_in_stmts(else_body, from, to),
      )
  }
}

///|
/// 表达式里的变量引用改名。
///
/// **只改 `Var`**：控件名在 IR 里同样以 `Var` 形态出现在命令实参位
/// （如 `取文本(姓名框)`），所以变量与控件同名时会一起被改。这是既有
/// 表示的固有歧义（控件重命名走的是「命令实参位」的专用规则），此处与
/// 之保持一致的保守做法：变量改名只动 `Var`，不做位置语义推断——
/// 推断错了会静默改写程序行为。
fn rename_var_in_expr(expr : @ir.Expr, from : String, to : String) -> @ir.Expr {
  match expr {
    @ir.Var(name) => @ir.Var(if name == from { to } else { name })
    @ir.Not(inner) => @ir.Not(rename_var_in_expr(inner, from, to))
    @ir.Neg(inner) => @ir.Neg(rename_var_in_expr(inner, from, to))
    @ir.ListLit(items) => {
      let copy : Array[@ir.Expr] = []
      for item in items {
        copy.push(rename_var_in_expr(item, from, to))
      }
      @ir.ListLit(copy)
    }
    @ir.Index(base, index) =>
      @ir.Index(
        rename_var_in_expr(base, from, to),
        rename_var_in_expr(index, from, to),
      )
    @ir.Binary(op, left, right) =>
      @ir.Binary(
        op,
        rename_var_in_expr(left, from, to),
        rename_var_in_expr(right, from, to),
      )
    @ir.Call(name, args) => {
      let renamed : Array[@ir.Expr] = []
      for arg in args {
        renamed.push(rename_var_in_expr(arg, from, to))
      }
      @ir.Call(name, renamed)
    }
    other => other
  }
}

// ============================================================================
// 消息分发
// ============================================================================

///|
/// 选中与非控件对象消息：未命中返回 None 交还链式分发。
pub fn update_selection_msgs(
  model : Model,
  msg : Msg,
) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SelectSide(target) =>
      Some((select_target(model, target), @moui.Effect::none()))
    ToggleTreeCreate(group) =>
      // 同一组再点 = 收起（与图标栏「再点当前项」同一心智）
      Some(
        (
          {
            ..model,
            tree_create_group: if model.tree_create_group == group {
              ""
            } else {
              group
            },
          },
          @moui.Effect::none(),
        ),
      )
    SetWindowTitle(title) =>
      Some(
        (
          with_undo_point(model, "window:title", m => {
            ..m,
            program: { ..m.program, window: { ..m.program.window, title, }, },
          }),
          @moui.Effect::none(),
        ),
      )
    SetTimerInterval(raw) =>
      // 0..=3600 秒；非法输入回落 0（关闭定时器）——属性框整数解析同口径
      Some(
        (
          with_undo_point(model, "window:timer", m => {
            ..m,
            program: {
              ..m.program,
              window: {
                ..m.program.window,
                timer_interval: parse_window_timer(raw),
              },
            },
          }),
          @moui.Effect::none(),
        ),
      )
    AddFunction =>
      Some(
        (
          with_recent_undo_point(
            model,
            text(translator(model), "app.function.new"),
            "app.recent.action.function",
            m => add_function(m),
          ),
          @moui.Effect::none(),
        ),
      )
    RenameFunction(from, to) =>
      Some(
        (
          with_undo_point(model, "func:\{from}", m => {
            rename_function(m, from, to)
          }),
          @moui.Effect::none(),
        ),
      )
    AddVariable =>
      Some(
        (
          with_recent_undo_point(
            model,
            text(translator(model), "app.variable.new"),
            "app.recent.action.variable",
            m => add_variable(m),
          ),
          @moui.Effect::none(),
        ),
      )
    RenameVariable(from, to) =>
      Some(
        (
          with_undo_point(model, "var:\{from}", m => {
            rename_variable(m, from, to)
          }),
          @moui.Effect::none(),
        ),
      )
    SetVariableInit(name, init) =>
      Some(
        (
          with_undo_point(model, "varinit:\{name}", m => {
            set_variable_init(m, name, init)
          }),
          @moui.Effect::none(),
        ),
      )
    DeleteVariable(name) =>
      Some(
        (
          with_recent_undo_point(
            model,
            name,
            "app.recent.action.variable_delete",
            m => delete_variable(m, name),
          ),
          @moui.Effect::none(),
        ),
      )
    _ => None
  }
}

///|
/// 窗体定时器间隔解析：纯数字秒（0..=3600）；其余回落 0（关闭）。
fn parse_window_timer(raw : String) -> Int {
  if raw.length() == 0 || raw.length() > 4 {
    return 0
  }
  let mut value = 0
  for c in raw {
    let code = c.to_int()
    if code < 0x30 || code > 0x39 {
      return 0
    }
    value = value * 10 + (code - 0x30)
  }
  value.min(3600)
}
