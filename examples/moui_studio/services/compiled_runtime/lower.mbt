///|
/// 编译轨直跑面：把 IR 语句树 lower 成 `compiled_runtime.Handler` 闭包。
///
/// 为什么存在：导出 bundle 里真正被编译的是 `services/export/moonbit_codegen`
/// 生成的 MoonBit 源码；Studio 自身不能在每个事件里真跑一遍 `moon build`，
/// 所以 IDE 内编译轨执行的是同一套 `compiled_runtime` 执行面——由本文件按
/// `moonbit_codegen` 的**逐条调用序列**lower。两边的语义唯一来源都是
/// `domain/studio_lang/interp.mbt`，差分矩阵（services/diff）逐项锁死：
/// 任一 lowering 与 codegen 分叉，都会在编译轨与解释轨的审计/终态上大声失败。
///
/// 行号口径：源码路径（`lower_traced_handler`）逐语句携带解析行号；
/// 无 Trace 的 IR 路径（`lower_handler`）统一用 0 并由界面显示语句序号。
/// 两条路径都与解释轨 `emit_stmt` 的嵌套体行号规则一致：嵌套体继承外层行号。

///|
/// 语句块 → Handler（事件子程序入口）。无 Trace 的 IR 路径：行号统一 0。
pub fn lower_handler(body : Array[@ir.Stmt]) -> Handler {
  lower_traced_handler(@studio_lang.traced_from_stmts(body))
}

///|
/// 语句块 → Handler（源码路径）。语句行号来自解析器 Trace，审计/错误同行号。
pub fn lower_traced_handler(body : Array[@studio_lang.TracedStmt]) -> Handler {
  let stmts : Array[@studio_lang.TracedStmt] = []
  for traced in body {
    stmts.push(traced)
  }
  Handler(fn(rt : Runtime) -> Unit raise ExecError { exec_body(rt, stmts) })
}

///|
/// 用户函数 → 注册闭包：参数名来自 IR（闭包持有），Return 的
/// LoopReturn 控制信号在此边界捕获成返回值；体行号统一 0
/// （与解释轨 call_user_function 的 compile_body(traced_from_stmts) 同口径）。
pub fn lower_user_function(func : @ir.FuncDef) -> UserFunction {
  fn(rt : Runtime, arg_values : Array[Value]) -> Value raise ExecError {
    for index, param in func.params {
      if index < arg_values.length() {
        rt.vars[param] = arg_values[index]
        if !rt.declared.contains(param) {
          rt.declared.push(param)
        }
      }
    }
    try {
      exec_nested(rt, func.body, 0)
      VUnit
    } catch {
      LoopReturn(value) => value
      error => raise error
    }
  }
}

///|
/// (控件名, 事件) → Handler：与生成代码的 `studio_dispatch_handler` 同口径，
/// 找不到返回 None（Studio 不去猜、不静默兜底）。
pub fn handler_for(
  program : @ir.StudioProgram,
  control : String,
  event_tag : String,
) -> Handler? {
  for handler in program.handlers {
    if handler.control_name == control && handler.event.tag() == event_tag {
      return Some(lower_handler(handler.body))
    }
  }
  None
}

///|
/// 顶层语句块执行：逐条取语句自身行号（与解释轨 `emit_stmts` 同口径）。
fn exec_body(
  rt : Runtime,
  body : Array[@studio_lang.TracedStmt],
) -> Unit raise ExecError {
  for traced in body {
    // **语句之间检查运行状态**：`停止全部` 会把状态改成 `Stopped`，
    // 此后剩余语句一律不再执行。解释轨的 `step_once` 本来就有这道检查
    // （`if !(state.status is Running) { return }`），编译轨此前**没有**，
    // 于是同一个程序在两条轨上行为不同——正是差分门该抓的那类偏差。
    if !(rt.status is Running) {
      return
    }
    exec_stmt(rt, traced.stmt, traced.line)
  }
}

///|
/// 嵌套语句块执行：继承外层行号（与解释轨 `emit_body` 同口径）。
fn exec_nested(
  rt : Runtime,
  body : Array[@ir.Stmt],
  line : Int,
) -> Unit raise ExecError {
  for stmt in body {
    // 嵌套块（循环体 / if 体）同样要检查：`停止全部` 可能出现在循环内部，
    // 不检查会让循环继续跑完整轮。
    if !(rt.status is Running) {
      return
    }
    exec_stmt(rt, stmt, line)
  }
}

///|
fn exec_stmt(rt : Runtime, stmt : @ir.Stmt, line : Int) -> Unit raise ExecError {
  match stmt {
    @ir.Declare(name, expr) =>
      rt.audit_assign(
        name,
        eval_expr(rt, expr, line),
        line,
        "\{name} = \{@studio_lang.canonical_expr(expr)}",
      )
    @ir.Assign(name, expr) => {
      rt.require_declared(name, line)
      rt.audit_assign(
        name,
        eval_expr(rt, expr, line),
        line,
        "\{name} = \{@studio_lang.canonical_expr(expr)}",
      )
    }
    @ir.SetIndex(name, index, value) => {
      let existing = rt.get(name, line)
      let index_value = eval_expr(rt, index, line)
      let value_value = eval_expr(rt, value, line)
      set_index_values(existing, index_value, value_value, line)
      rt.record(
        line,
        OpCommand,
        "\{name}[\{@studio_lang.canonical_expr(index)}] = \{@studio_lang.canonical_expr(value)}",
      )
    }
    @ir.If(cond, then_body, else_ifs, else_body) => {
      let flag = bool_of(eval_expr(rt, cond, line), "condition", line)
      rt.record_condition(flag, line, @studio_lang.canonical_expr(cond))
      if flag {
        exec_nested(rt, then_body, line)
      } else {
        let mut taken = false
        for arm in else_ifs {
          if !taken {
            let arm_flag = bool_of(
              eval_expr(rt, arm.0, line),
              "condition",
              line,
            )
            rt.record_condition(
              arm_flag,
              line,
              @studio_lang.canonical_expr(arm.0),
            )
            if arm_flag {
              exec_nested(rt, arm.1, line)
              taken = true
            }
          }
        }
        if !taken {
          exec_nested(rt, else_body, line)
        }
      }
    }
    @ir.CountLoop(times, loop_var, body) => {
      let var_name = match loop_var {
        Some(name) => name
        None => ""
      }
      rt.count_loop(eval_expr(rt, times, line), var_name, line, fn(
        inner : Runtime,
      ) -> Unit raise ExecError {
        exec_nested(inner, body, line)
      })
    }
    @ir.WhileLoop(cond, body) =>
      rt.while_loop(
        line,
        fn(inner : Runtime) -> Value raise ExecError {
          eval_expr(inner, cond, line)
        },
        fn(inner : Runtime, flag : Bool) -> Unit raise ExecError {
          inner.record_condition(flag, line, @studio_lang.canonical_expr(cond))
        },
        fn(inner : Runtime) -> Unit raise ExecError {
          exec_nested(inner, body, line)
        },
      )
    @ir.Break => rt.break_loop()
    @ir.Return(expr) => {
      // 返回 = LoopReturn 控制信号；函数调用边界（注册闭包）捕获
      match expr {
        Some(value) => raise LoopReturn(eval_expr(rt, value, line))
        None => raise LoopReturn(VUnit)
      }
    }
    @ir.Stmt::Call(name, args) =>
      match @studio_lang.builtin_kind(name) {
        Some(@studio_lang.Command) => exec_command(rt, name, args, line)
        Some(@studio_lang.Gate) => ignore(exec_gate(rt, name, args, line))
        Some(@studio_lang.Function) => {
          let call : @ir.Expr = @ir.Expr::Call(name, args)
          ignore(eval_expr(rt, call, line))
          rt.record(line, OpCommand, @studio_lang.canonical_expr(call))
        }
        // 用户自定义函数：语句位调用同样记账（与解释轨 ExprStmt 同口径）
        None => {
          let call : @ir.Expr = @ir.Expr::Call(name, args)
          ignore(eval_expr(rt, call, line))
          rt.record(line, OpCommand, @studio_lang.canonical_expr(call))
        }
      }
  }
}

///|
/// 语句位的命令：与 codegen `write_command_call` 同一分派。
fn exec_command(
  rt : Runtime,
  name : String,
  args : Array[@ir.Expr],
  line : Int,
) -> Unit raise ExecError {
  let detail = @studio_lang.canonical_call_text(name, args)
  match name {
    "message_box" =>
      rt.message_box(eval_expr(rt, args[0], line), name, line, detail)
    "set_text" =>
      rt.set_text(
        control_name_of(rt, args[0], line),
        eval_expr(rt, args[1], line),
        name,
        line,
        detail,
      )
    "append_row" =>
      rt.append_row(
        control_name_of(rt, args[0], line),
        eval_expr(rt, args[1], line),
        name,
        line,
        detail,
      )
    "broadcast" =>
      rt.broadcast(eval_expr(rt, args[0], line), line)
    "wait" => {
      // **语句位的 `等待 N 秒`**：与 `stop_all` 同样是**语句**，所以必须
      // 进 `exec_command`（语句位分派器），只进 `eval_call` 会报未知内建。
      let seconds = match eval_expr(rt, args[0], line) {
        VNum(n) => n
        VInt(n) => n.to_double()
        _ =>
          raise ExecError::RuntimeError(ErrorDetails::{
            kind: TypeMismatch,
            line,
            a: name,
            b: "number",
          })
      }
      ignore(wait_value(rt, seconds))
      rt.record(line, OpCommand, detail)
    }
    "stop_all" => {
      // **语句位的 `停止全部`**：`exec_command` 是语句位分派器，与
      // 表达式位的 `eval_call` 是**两张表**——只往 `eval_call` 加就会
      // 「表达式位能用、语句位报未知内建」，而 `stop_all` 恰恰是语句。
      ignore(stop_all(rt))
      rt.record(line, OpCommand, detail)
    }
    "append_list" => {
      let list_name = match args[0] {
        @ir.Var(name) => name
        _ =>
          raise ExecError::RuntimeError(ErrorDetails::{
            kind: TypeMismatch,
            line,
            a: "append_list",
            b: "variable",
          })
      }
      rt.append_list(
        list_name,
        eval_expr(rt, args[1], line),
        name,
        line,
        detail,
      )
    }
    _ => ignore(unknown_builtin(name, line))
  }
}

///|
/// 语句位的闸门：与 codegen `write_gate_call` 同一分派。
fn exec_gate(
  rt : Runtime,
  name : String,
  args : Array[@ir.Expr],
  line : Int,
) -> Value raise ExecError {
  let detail = @studio_lang.canonical_call_text(name, args)
  match name {
    "submit_data" =>
      rt.submit_data(
        control_name_of(rt, args[1], line),
        eval_expr(rt, args[0], line),
        name,
        line,
        detail,
      )
    "ask" => rt.ask(eval_expr(rt, args[0], line), name, line, detail)
    _ => {
      // 内建没有 → 用户自定义函数（先内建、后自定义，与解释轨同口径）
      if rt.has_user_function(name) {
        let arg_values : Array[Value] = []
        for arg in args {
          arg_values.push(eval_expr(rt, arg, line))
        }
        rt.call_user_function(name, arg_values, line)
      } else {
        unknown_builtin(name, line)
      }
    }
  }
}

///|
/// 控件名槽：裸变量按解释轨 `control_name` 语义直接取控件名，
/// 字符串字面量取文本，其余表达式求值后转文本（与 codegen 一致）。
fn control_name_of(
  rt : Runtime,
  arg : @ir.Expr,
  line : Int,
) -> String raise ExecError {
  match arg {
    @ir.Var(name) => name
    @ir.StrLit(text) => text
    other => as_text(eval_expr(rt, other, line), "control", line)
  }
}

///|
/// 表达式求值：与 codegen `write_value` 同一张映射表。
fn eval_expr(
  rt : Runtime,
  expr : @ir.Expr,
  line : Int,
) -> Value raise ExecError {
  match expr {
    @ir.NumLit(n) => VNum(n)
    @ir.IntLit(n) => VInt(n)
    @ir.StrLit(text) => VStr(text)
    @ir.BoolLit(flag) => VBool(flag)
    @ir.Var(name) =>
      match @studio_lang.builtin_kind(name) {
        Some(_) => {
          ignore(unknown_builtin(name, line))
          VUnit
        }
        None => rt.get(name, line)
      }
    @ir.Not(inner) => not_value(eval_expr(rt, inner, line), line)
    @ir.Neg(inner) => neg_value(eval_expr(rt, inner, line), line)
    @ir.ListLit(items) => {
      let values : Array[Value] = []
      for item in items {
        values.push(eval_expr(rt, item, line))
      }
      VArr(values)
    }
    @ir.Index(base, index) =>
      index_values(
        eval_expr(rt, base, line),
        eval_expr(rt, index, line),
        line,
      )
    @ir.Binary(op, left, right) => eval_binary(rt, op, left, right, line)
    @ir.Expr::Call(name, args) => eval_call(rt, name, args, line)
  }
}

///|
fn eval_binary(
  rt : Runtime,
  op : @ir.BinOp,
  left : @ir.Expr,
  right : @ir.Expr,
  line : Int,
) -> Value raise ExecError {
  match op {
    @ir.Add =>
      add_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Sub =>
      sub_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Mul =>
      mul_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Div =>
      div_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Eq =>
      eq_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Ne =>
      neq_values(eval_expr(rt, left, line), eval_expr(rt, right, line), line)
    @ir.Lt =>
      compare_values(
        eval_expr(rt, left, line),
        eval_expr(rt, right, line),
        "<",
        line,
      )
    @ir.Gt =>
      compare_values(
        eval_expr(rt, left, line),
        eval_expr(rt, right, line),
        ">",
        line,
      )
    @ir.Le =>
      compare_values(
        eval_expr(rt, left, line),
        eval_expr(rt, right, line),
        "<=",
        line,
      )
    @ir.Ge =>
      compare_values(
        eval_expr(rt, left, line),
        eval_expr(rt, right, line),
        ">=",
        line,
      )
    @ir.And =>
      and_values(
        fn(inner : Runtime) -> Value raise ExecError {
          eval_expr(inner, left, line)
        },
        fn(inner : Runtime) -> Value raise ExecError {
          eval_expr(inner, right, line)
        },
        rt,
        line,
      )
    @ir.Or =>
      or_values(
        fn(inner : Runtime) -> Value raise ExecError {
          eval_expr(inner, left, line)
        },
        fn(inner : Runtime) -> Value raise ExecError {
          eval_expr(inner, right, line)
        },
        rt,
        line,
      )
  }
}

///|
/// 表达式位的内建：与 codegen `write_function_call` 同一分派
/// （`ask`/`submit_data` 返回值；命令出现在表达式位是非法程序，
/// 两轨同走 unknown_builtin 错误）。
fn eval_call(
  rt : Runtime,
  name : String,
  args : Array[@ir.Expr],
  line : Int,
) -> Value raise ExecError {
  match name {
    "get_text" => get_text(rt, control_name_of(rt, args[0], line))
    "get_number" => get_number(rt, control_name_of(rt, args[0], line), line)
    "to_text" => to_text(eval_expr(rt, args[0], line))
    "text_length" => text_length(eval_expr(rt, args[0], line), name, line)
    "mod" =>
      mod_value(
        eval_expr(rt, args[0], line),
        eval_expr(rt, args[1], line),
        name,
        line,
      )
    "round" => round_value(eval_expr(rt, args[0], line), name, line)
    "stop_all" => stop_all(rt)
    "answer" => last_answer(rt)
    "abs" => abs_value(eval_expr(rt, args[0], line), name, line)
    "floor" => floor_value(eval_expr(rt, args[0], line), name, line)
    "ceiling" => ceiling_value(eval_expr(rt, args[0], line), name, line)
    "sqrt" => sqrt_value(eval_expr(rt, args[0], line), name, line)
    "contains" =>
      contains(
        eval_expr(rt, args[0], line),
        eval_expr(rt, args[1], line),
        name,
        line,
      )
    "list_length" =>
      list_length(rt, eval_expr(rt, args[0], line), line)
    "random" => random(rt, eval_expr(rt, args[0], line), line)
    "row_count" => row_count(rt, control_name_of(rt, args[0], line))
    "row_at" =>
      row_at(
        rt,
        control_name_of(rt, args[0], line),
        eval_expr(rt, args[1], line),
        line,
      )
    "selected_row" => selected_row(rt, control_name_of(rt, args[0], line))
    "ask" =>
      rt.ask(
        eval_expr(rt, args[0], line),
        name,
        line,
        @studio_lang.canonical_call_text(name, args),
      )
    "submit_data" =>
      rt.submit_data(
        control_name_of(rt, args[1], line),
        eval_expr(rt, args[0], line),
        name,
        line,
        @studio_lang.canonical_call_text(name, args),
      )
    // 内建没有 → 用户自定义函数（先内建、后自定义，与解释轨同口径）
    _ => {
      if rt.has_user_function(name) {
        let arg_values : Array[Value] = []
        for arg in args {
          arg_values.push(eval_expr(rt, arg, line))
        }
        rt.call_user_function(name, arg_values, line)
      } else {
        unknown_builtin(name, line)
      }
    }
  }
}
