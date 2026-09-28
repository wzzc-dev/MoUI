///|
/// 解释器：把子程序编译成扁平指令流后逐步执行。
/// 相比树遍历，指令机天然支持：运行聚光灯（cursor=pc）、`提交数据`/`询问`
/// 闸门暂停与恢复、单步执行、审计日志与确定性随机数。
/// 纯函数式状态机：RunState 进、RunState 出，测试不碰 UI。

///|
pub(all) enum RunStatus {
  Running
  WaitingGate
  Completed
  Failed
}

///|
pub(all) enum GateKind {
  Submit
  Ask
}

///|
/// 外发闸门：执行在这里停下等人，确认前零真实动作。
pub(all) struct Gate {
  kind : GateKind
  prompt : String
  payload : String
}

///|
pub(all) enum StepOp {
  OpAssign
  OpMessage
  OpGate
  OpCommand
  OpCondition
  OpLoop
}

///|
/// 审计记录：一行一句人话（detail 是语言中立的规范形式，界面层本地化）。
pub(all) struct StepRecord {
  line : Int
  op : StepOp
  detail : String
}

///|
pub(all) enum Value {
  VNum(Double)
  VStr(String)
  VBool(Bool)
  VUnit
}

///|
/// 运行指令。控制流指令用跳转目标下标；循环用隐藏计数器槽
/// （名字形如 `@i12`，与用户变量命名空间不冲突）。
pub(all) enum Instr {
  Declare(String, Expr)
  Assign(String, Expr)
  ExprStmt(Expr)
  JumpIfFalse(Expr, Int)
  Jump(Int)
  LoopInit(Expr, String, Int) // 次数表达式, 计数器槽, 循环结束目标
  LoopCheck(String, String, Int) // 计数器槽, 循环变量(""=无), 循环结束目标
  LoopNext(String, Int) // 计数器槽, 循环开始目标
}

///|
pub(all) struct Plan {
  instrs : Array[Instr]
  lines : Array[Int]
}

///|
pub(all) struct RunState {
  plan : Plan
  mut pc : Int
  vars : Map[String, Value]
  texts : Map[String, String]
  rows : Map[String, Array[String]]
  selections : Map[String, Int]
  messages : Array[String]
  audit : Array[StepRecord]
  mut status : RunStatus
  mut gate : Gate?
  mut error : LangError?
  mut steps : Int
  max_steps : Int
  mut rng : Int
  gate_answers : Array[Bool]
  mut declared : Array[String]
  mut gate_cursor : Int
  mut paused : Bool
}

///|
/// 默认步数预算：防死循环冻结 UI。
pub const DEFAULT_MAX_STEPS : Int = 100_000

///|
/// 从程序提取初始变量值（init 文本：像数字就按数字，否则按文本）。
pub fn initial_values(program : StudioProgram) -> Map[String, Value] {
  let values : Map[String, Value] = Map([], capacity=8)
  for variable in program.variables {
    match text_to_number(variable.init) {
      Some(n) => values[variable.name] = VNum(n)
      None => values[variable.name] = VStr(variable.init)
    }
  }
  values
}

///|
/// 从程序提取初始控件文本（label/button 的 text、text_field 初值）。
pub fn initial_texts(program : StudioProgram) -> Map[String, String] {
  let texts : Map[String, String] = Map([], capacity=8)
  for control in program.controls {
    texts[control.name] = control.text
  }
  texts
}

///|
/// 列表框/表格初始行。
pub fn initial_rows(program : StudioProgram) -> Map[String, Array[String]] {
  let rows : Map[String, Array[String]] = Map([], capacity=4)
  for control in program.controls {
    let copied : Array[String] = []
    for item in control.items {
      copied.push(item)
    }
    rows[control.name] = copied
  }
  rows
}

///|
/// 无 Trace 的语句（JSON 路径）：行号 0，界面显示语句序号。
pub fn traced_from_stmts(body : Array[Stmt]) -> Array[TracedStmt] {
  body.map(stmt => TracedStmt::{ stmt, line: 0, })
}

///|
/// 启动一次运行（语句路径，行号已知）。
pub fn start_run(
  body : Array[TracedStmt],
  texts : Map[String, String],
  values : Map[String, Value],
  rows : Map[String, Array[String]],
  max_steps? : Int = DEFAULT_MAX_STEPS,
  seed? : Int = 20260927,
) -> RunState {
  RunState::{
    plan: compile_body(body),
    pc: 0,
    vars: values,
    texts,
    rows,
    selections: Map([], capacity=4),
    messages: [],
    audit: [],
    status: Running,
    gate: None,
    error: None,
    steps: 0,
    max_steps,
    rng: if seed <= 0 {
      1
    } else {
      seed % 2147483647
    },
    gate_answers: [],
    declared: [],
    gate_cursor: 0,
    paused: false,
  }
}

///|
/// 启动一次运行（IR 语句路径，行号不可知）。
pub fn start_run_stmts(
  body : Array[Stmt],
  texts : Map[String, String],
  values : Map[String, Value],
  rows : Map[String, Array[String]],
  max_steps? : Int = DEFAULT_MAX_STEPS,
  seed? : Int = 20260927,
) -> RunState {
  start_run(traced_from_stmts(body), texts, values, rows, max_steps~, seed~)
}

///|
/// 执行到终止态（完成/闸门/失败）。
pub fn run_to_end(state : RunState) -> Unit {
  let mut budget = state.max_steps + 64
  while state.status is Running && budget > 0 {
    step_once(state)
    budget = budget - 1
  }
}

///|
/// 执行一条指令。闸门暂停时原指令不动，等待 answer_gate。
pub fn step_once(state : RunState) -> Unit {
  if !(state.status is Running) {
    return
  }
  state.paused = false
  state.steps = state.steps + 1
  if state.steps > state.max_steps {
    state.status = Failed
    state.error = Some(LangError(StepBudget, 0, "", ""))
    return
  }
  if state.pc >= state.plan.instrs.length() {
    state.status = Completed
    return
  }
  let line = state.plan.lines[state.pc]
  let instr = state.plan.instrs[state.pc]
  try {
    match instr {
      Declare(name, expr) => {
        let value = state.eval(expr, line)
        if state.paused || !(state.status is Running) {
          return
        }
        state.vars[name] = value
        if !state.declared.contains(name) {
          state.declared.push(name)
        }
        state.audit.push(StepRecord::{
          line,
          op: OpAssign,
          detail: "\{name} = \{canonical_expr(expr)}",
        })
        state.pc = state.pc + 1
      }
      Assign(name, expr) => {
        if !state.declared.contains(name) && state.vars.get(name) is None {
          raise LangError(NotDeclared, line, name, "use declare first")
        }
        let value = state.eval(expr, line)
        if state.paused || !(state.status is Running) {
          return
        }
        state.vars[name] = value
        state.audit.push(StepRecord::{
          line,
          op: OpAssign,
          detail: "\{name} = \{canonical_expr(expr)}",
        })
        state.pc = state.pc + 1
      }
      ExprStmt(expr) => {
        let _value = state.eval(expr, line)
        if state.paused || !(state.status is Running) {
          return
        }
        // 命令/闸门已在 eval_call 内记账；其余调用在此补一条
        let audited = match expr {
          @ir.Call(name, _) =>
            match builtin_kind(name) {
              Some(Command) | Some(Gate) => true
              _ => false
            }
          _ => true
        }
        if !audited {
          state.audit.push(StepRecord::{
            line,
            op: OpCommand,
            detail: canonical_expr(expr),
          })
        }
        state.pc = state.pc + 1
      }
      JumpIfFalse(expr, target) => {
        let value = state.eval(expr, line)
        if state.paused || !(state.status is Running) {
          return
        }
        let flag = state.as_bool(value, "condition", line)
        state.audit.push(StepRecord::{
          line,
          op: OpCondition,
          detail: "\{canonical_expr(expr)} -> \{flag}",
        })
        state.pc = if flag { state.pc + 1 } else { target }
      }
      Jump(target) => state.pc = target
      LoopInit(times, counter, end) => {
        let value = state.eval(times, line)
        if state.paused || !(state.status is Running) {
          return
        }
        let count = match value {
          VNum(n) => n.to_int()
          _ => raise LangError(BadLoopCount, line, "", "")
        }
        state.vars["\{counter}#n"] = VNum(count.to_double())
        state.vars[counter] = VNum(1.0)
        if count < 1 {
          state.pc = end
        } else {
          state.pc = state.pc + 1
        }
      }
      LoopCheck(counter, loop_var, end) => {
        let index = state.lookup_number(counter, line)
        let count = state.lookup_number("\{counter}#n", line)
        if index > count {
          state.pc = end
        } else {
          if loop_var != "" {
            state.vars[loop_var] = VNum(index)
            if !state.declared.contains(loop_var) {
              state.declared.push(loop_var)
            }
          }
          state.audit.push(StepRecord::{
            line,
            op: OpLoop,
            detail: "iteration \{index.to_int()}",
          })
          state.pc = state.pc + 1
        }
      }
      LoopNext(counter, start) => {
        let index = state.lookup_number(counter, line)
        state.vars[counter] = VNum(index + 1.0)
        state.pc = start
      }
    }
  } catch {
    LangError(kind, err_line, a, b) => {
      state.status = Failed
      state.error = Some(LangError(kind, err_line, a, b))
    }
  }
}

///|
/// 闸门应答：推入决定并立即恢复执行。多条闸门按 FIFO 消费。
pub fn answer_gate(state : RunState, decision : Bool) -> Unit {
  if !(state.status is WaitingGate) {
    return
  }
  state.gate_answers.push(decision)
  state.gate = None
  state.paused = false
  state.status = Running
  step_once(state)
}

///|
/// 取消运行（停在原地，状态保留供检查）。
pub fn cancel(state : RunState) -> Unit {
  state.status = Failed
  state.error = Some(LangError(UnexpectedToken, 0, "cancelled", ""))
}

///|
fn RunState::lookup_number(
  self : RunState,
  name : String,
  line : Int,
) -> Double raise LangError {
  match self.vars.get(name) {
    Some(VNum(n)) => n
    Some(_) => raise LangError(TypeMismatch, line, name, "number")
    None => raise LangError(NotDeclared, line, name, "")
  }
}

///|
fn RunState::as_bool(
  self : RunState,
  value : Value,
  role : String,
  line : Int,
) -> Bool raise LangError {
  match value {
    VBool(flag) => flag
    _ => raise LangError(TypeMismatch, line, role, "bool")
  }
}

///|
/// 值 → 文本（属性面板/内建参数共用；逻辑值渲染为真/假由界面本地化）。
pub fn value_to_text(value : Value) -> String {
  match value {
    VNum(n) => number_to_text(n)
    VStr(text) => text
    VBool(true) => "true"
    VBool(false) => "false"
    VUnit => ""
  }
}

///|
fn RunState::value_as_text(
  self : RunState,
  value : Value,
  role : String,
  line : Int,
) -> String raise LangError {
  match value {
    VUnit => raise LangError(TypeMismatch, line, role, "text")
    other => value_to_text(other)
  }
}

///|
/// 控件名参数：源码里 `取文本(姓名框)` 的姓名框是控件名（裸标识符），
/// 不是变量。也允许字符串字面量与求值为文本的表达式（动态控件名）。
fn RunState::control_name(
  self : RunState,
  arg : Expr,
  line : Int,
) -> String raise LangError {
  match arg {
    @ir.Var(name) => name
    @ir.StrLit(text) => text
    other => self.value_as_text(self.eval(other, line), "control", line)
  }
}

///|
/// 表达式求值。闸门触发时置 paused 并返回 VUnit（本指令作废重来）。
fn RunState::eval(
  self : RunState,
  expr : Expr,
  line : Int,
) -> Value raise LangError {
  match expr {
    @ir.NumLit(n) => VNum(n)
    @ir.StrLit(text) => VStr(text)
    @ir.BoolLit(flag) => VBool(flag)
    @ir.Var(name) =>
      match self.vars.get(name) {
        Some(value) => value
        None => raise LangError(NotDeclared, line, name, "")
      }
    @ir.Not(inner) => {
      let flag = self.as_bool(self.eval(inner, line), "not operand", line)
      VBool(!flag)
    }
    @ir.Neg(inner) => {
      let n = self.eval_number(inner, "negation operand", line)
      VNum(-n)
    }
    @ir.Binary(op, left, right) => self.eval_binary(op, left, right, line)
    @ir.Call(name, args) => self.eval_call(name, args, line)
  }
}

///|
fn RunState::eval_number(
  self : RunState,
  expr : Expr,
  role : String,
  line : Int,
) -> Double raise LangError {
  match self.eval(expr, line) {
    VNum(n) => n
    _ => raise LangError(TypeMismatch, line, role, "number")
  }
}

///|
fn RunState::eval_binary(
  self : RunState,
  op : BinOp,
  left : Expr,
  right : Expr,
  line : Int,
) -> Value raise LangError {
  if op is @ir.And || op is @ir.Or {
    let l = self.as_bool(self.eval(left, line), "logic operand", line)
    // 短路：且已假不求右，或已真不求右（右表达式可能含闸门）
    if op is @ir.And && !l {
      return VBool(false)
    }
    if op is @ir.Or && l {
      return VBool(true)
    }
    let r = self.as_bool(self.eval(right, line), "logic operand", line)
    return VBool(r)
  }
  let l = self.eval(left, line)
  let r = self.eval(right, line)
  match op {
    @ir.Add =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a + b)
        (VStr(_), _) | (_, VStr(_)) => VStr(value_to_text(l) + value_to_text(r))
        _ => raise LangError(TypeMismatch, line, "+", "same types")
      }
    @ir.Sub =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a - b)
        _ => raise LangError(TypeMismatch, line, "-", "numbers")
      }
    @ir.Mul =>
      match (l, r) {
        (VNum(a), VNum(b)) => VNum(a * b)
        _ => raise LangError(TypeMismatch, line, "*", "numbers")
      }
    @ir.Div =>
      match (l, r) {
        (VNum(a), VNum(b)) =>
          if b == 0.0 {
            raise LangError(DivideByZero, line, "", "")
          } else {
            VNum(a / b)
          }
        _ => raise LangError(TypeMismatch, line, "/", "numbers")
      }
    @ir.Eq | @ir.Ne => {
      let same = self.values_equal(l, r, line)
      VBool(if op is @ir.Eq { same } else { !same })
    }
    @ir.Lt | @ir.Gt | @ir.Le | @ir.Ge =>
      match (l, r) {
        (VNum(a), VNum(b)) =>
          VBool(
            if op is @ir.Lt {
              a < b
            } else if op is @ir.Gt {
              a > b
            } else if op is @ir.Le {
              a <= b
            } else {
              a >= b
            },
          )
        (VStr(a), VStr(b)) =>
          VBool(
            if op is @ir.Lt {
              a < b
            } else if op is @ir.Gt {
              a > b
            } else if op is @ir.Le {
              a <= b
            } else {
              a >= b
            },
          )
        _ => raise LangError(TypeMismatch, line, "compare", "same types")
      }
    @ir.And | @ir.Or => VBool(false) // 上面已短路处理，不会到这里
  }
}

///|
fn RunState::values_equal(
  self : RunState,
  l : Value,
  r : Value,
  line : Int,
) -> Bool raise LangError {
  match (l, r) {
    (VNum(a), VNum(b)) => a == b
    (VStr(a), VStr(b)) => a == b
    (VBool(a), VBool(b)) => a == b
    (VUnit, VUnit) => true
    _ => raise LangError(TypeMismatch, line, "=", "same types")
  }
}

///|
/// 内建调用分发（命令/闸门有副作用与审计；函数只读）。
fn RunState::eval_call(
  self : RunState,
  name : String,
  args : Array[Expr],
  line : Int,
) -> Value raise LangError {
  match find_builtin(name) {
    None => raise LangError(UnknownBuiltin, line, name, "")
    Some(spec) => {
      if args.length() != spec.arity {
        raise LangError(
          ArityMismatch,
          line,
          spec.id,
          "\{spec.arity}/\{args.length()}",
        )
      }
      match spec.kind {
        Gate => self.eval_gate(spec, args, line)
        Command => self.eval_command(spec, args, line)
        Function => self.eval_function(spec, args, line)
      }
    }
  }
}

///|
/// 闸门：已有应答就消费并落审计；否则暂停等人。
/// submit_data(数据, 目标)：prompt=目标标识，payload=数据文本；
/// ask(问题)：prompt=问题文本。
fn RunState::eval_gate(
  self : RunState,
  spec : BuiltinSpec,
  args : Array[Expr],
  line : Int,
) -> Value raise LangError {
  let prompt = if spec.id == "submit_data" {
    self.control_name(args[1], line)
  } else {
    self.value_as_text(self.eval(args[0], line), spec.id, line)
  }
  if self.paused || !(self.status is Running) {
    return VUnit
  }
  let payload = if spec.id == "submit_data" {
    let value = self.eval(args[0], line)
    if self.paused || !(self.status is Running) {
      return VUnit
    }
    self.value_as_text(value, spec.id, line)
  } else {
    ""
  }
  if self.gate_cursor < self.gate_answers.length() {
    let decision = self.gate_answers[self.gate_cursor]
    self.gate_cursor = self.gate_cursor + 1
    let outcome = if decision { "confirmed" } else { "rejected" }
    self.audit.push(StepRecord::{
      line,
      op: OpGate,
      detail: "\{canonical_call_text(spec.id, args)} -> \{outcome}",
    })
    if spec.id == "ask" {
      VBool(decision)
    } else {
      VUnit
    }
  } else {
    self.status = WaitingGate
    self.paused = true
    self.gate = Some(Gate::{
      kind: if spec.id == "ask" {
        Ask
      } else {
        Submit
      },
      prompt,
      payload,
    })
    VUnit
  }
}

///|
/// 命令：立即生效（写 texts/rows/messages）并记账。
fn RunState::eval_command(
  self : RunState,
  spec : BuiltinSpec,
  args : Array[Expr],
  line : Int,
) -> Value raise LangError {
  match spec.id {
    "message_box" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      self.messages.push(text)
      self.audit.push(StepRecord::{
        line,
        op: OpMessage,
        detail: canonical_call_text(spec.id, args),
      })
      VUnit
    }
    "set_text" => {
      let control = self.control_name(args[0], line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      let text = self.value_as_text(self.eval(args[1], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      self.texts[control] = text
      self.audit.push(StepRecord::{
        line,
        op: OpCommand,
        detail: canonical_call_text(spec.id, args),
      })
      VUnit
    }
    "append_row" => {
      let control = self.control_name(args[0], line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      let text = self.value_as_text(self.eval(args[1], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      match self.rows.get(control) {
        Some(existing) => existing.push(text)
        None => self.rows[control] = [text]
      }
      self.audit.push(StepRecord::{
        line,
        op: OpCommand,
        detail: canonical_call_text(spec.id, args),
      })
      VUnit
    }
    _ => raise LangError(UnknownBuiltin, line, spec.id, "")
  }
}

///|
/// 函数：只读 texts/rows/selections；随机数推进确定性 RNG。
fn RunState::eval_function(
  self : RunState,
  spec : BuiltinSpec,
  args : Array[Expr],
  line : Int,
) -> Value raise LangError {
  match spec.id {
    "get_text" => {
      let control = self.control_name(args[0], line)
      VStr(self.texts.get(control).unwrap_or(""))
    }
    "get_number" => {
      let control = self.control_name(args[0], line)
      let text = self.texts.get(control).unwrap_or("")
      match text_to_number(text) {
        Some(n) => VNum(n)
        None => raise LangError(TypeMismatch, line, control, "number text")
      }
    }
    "to_text" => {
      let value = self.eval(args[0], line)
      VStr(value_to_text(value))
    }
    "text_length" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      VNum(text.length().to_double())
    }
    "contains" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      let sub = self.value_as_text(self.eval(args[1], line), spec.id, line)
      VBool(text.contains(sub))
    }
    "random" => {
      let max = self.eval_number(args[0], "random bound", line)
      self.rng = self.rng ^ ((self.rng << 13) & 2147483647)
      self.rng = self.rng ^ (self.rng >> 17)
      self.rng = self.rng ^ ((self.rng << 5) & 2147483647)
      let span = max.to_int()
      if span <= 1 {
        VNum(1.0)
      } else {
        VNum((self.rng % span).to_double() + 1.0)
      }
    }
    "selected_row" => {
      let control = self.control_name(args[0], line)
      let index = self.selections.get(control).unwrap_or(0)
      match self.rows.get(control) {
        Some(items) =>
          if index >= 0 && index < items.length() {
            VStr(items[index])
          } else {
            VStr("")
          }
        None => VStr("")
      }
    }
    "row_count" => {
      let control = self.control_name(args[0], line)
      match self.rows.get(control) {
        Some(items) => VNum(items.length().to_double())
        None => VNum(0.0)
      }
    }
    "row_at" => {
      let control = self.control_name(args[0], line)
      let index_value = self.eval(args[1], line)
      let index = match index_value {
        VNum(n) => n.to_int()
        _ => raise LangError(TypeMismatch, line, "row_at index", "number")
      }
      match self.rows.get(control) {
        Some(items) =>
          if index >= 1 && index <= items.length() {
            VStr(items[index - 1])
          } else {
            VStr("")
          }
        None => VStr("")
      }
    }
    _ => raise LangError(UnknownBuiltin, line, spec.id, "")
  }
}

///|
/// 语言中立的规范表达式渲染（审计/diff 用；内建用规范 id）。
pub fn canonical_expr(expr : Expr) -> String {
  let buf = StringBuilder()
  write_canonical_expr(buf, expr)
  buf.to_string()
}

///|
/// 规范调用文本：`name(arg, arg)`。审计细节与积木聚光灯共用它，
/// 保证「运行到哪一句」在积木视图里能精确对回那块积木。
pub fn canonical_call_text(name : String, args : Array[Expr]) -> String {
  let buf = StringBuilder()
  buf.write_string("\{name}(")
  let mut first = true
  for arg in args {
    if !first {
      buf.write_string(", ")
    }
    write_canonical_expr(buf, arg)
    first = false
  }
  buf.write_string(")")
  buf.to_string()
}

///|
fn write_canonical_expr(buf : StringBuilder, expr : Expr) -> Unit {
  match expr {
    @ir.NumLit(n) => buf.write_string(number_to_text(n))
    @ir.StrLit(text) => buf.write_string("\"\{text}\"")
    @ir.BoolLit(flag) => buf.write_string(if flag { "true" } else { "false" })
    @ir.Var(name) => buf.write_string(name)
    @ir.Not(inner) => {
      buf.write_string("not ")
      write_canonical_expr(buf, inner)
    }
    @ir.Neg(inner) => {
      buf.write_string("-")
      write_canonical_expr(buf, inner)
    }
    @ir.Binary(op, left, right) => {
      buf.write_string("(")
      write_canonical_expr(buf, left)
      buf.write_string(" \{op.canonical()} ")
      write_canonical_expr(buf, right)
      buf.write_string(")")
    }
    @ir.Call(name, args) => buf.write_string(canonical_call_text(name, args))
  }
}

///|

///|
/// 编译：语句 → 指令流（含跳转目标回填）。
/// 嵌套语句沿用外层 Trace 行号（IR 树本身不存行号）。
fn compile_body(body : Array[TracedStmt]) -> Plan {
  let instrs : Array[Instr] = []
  let lines : Array[Int] = []
  emit_stmts(instrs, lines, body, [])
  Plan::{ instrs, lines, }
}

///|
fn emit_stmts(
  instrs : Array[Instr],
  lines : Array[Int],
  body : Array[TracedStmt],
  break_patches : Array[Array[Int]],
) -> Unit {
  for traced in body {
    emit_stmt(instrs, lines, traced.stmt, traced.line, break_patches)
  }
}

///|
/// 无 Trace 的语句块（IR 内嵌体）：统一用外层行号。
fn emit_body(
  instrs : Array[Instr],
  lines : Array[Int],
  body : Array[Stmt],
  line : Int,
  break_patches : Array[Array[Int]],
) -> Unit {
  for stmt in body {
    emit_stmt(instrs, lines, stmt, line, break_patches)
  }
}

///|
fn emit_stmt(
  instrs : Array[Instr],
  lines : Array[Int],
  stmt : Stmt,
  line : Int,
  break_patches : Array[Array[Int]],
) -> Unit {
  match stmt {
    @ir.Declare(name, expr) => {
      instrs.push(Declare(name, expr))
      lines.push(line)
    }
    @ir.Assign(name, expr) => {
      instrs.push(Assign(name, expr))
      lines.push(line)
    }
    @ir.Call(name, args) => {
      instrs.push(ExprStmt(@ir.Call(name, args)))
      lines.push(line)
    }
    @ir.Break => {
      let slot = instrs.length()
      instrs.push(Jump(-1))
      lines.push(line)
      if break_patches.length() > 0 {
        break_patches[break_patches.length() - 1].push(slot)
      }
    }
    @ir.If(cond, then_body, else_ifs, else_body) => {
      let cond_slot = instrs.length()
      instrs.push(JumpIfFalse(cond, -1))
      lines.push(line)
      emit_body(instrs, lines, then_body, line, break_patches)
      let end_jumps : Array[Int] = []
      let then_jump = instrs.length()
      instrs.push(Jump(-1))
      lines.push(line)
      end_jumps.push(then_jump)
      let arm_cond_slots : Array[Int] = []
      for arm in else_ifs {
        let slot = instrs.length()
        instrs.push(JumpIfFalse(arm.0, -1))
        lines.push(line)
        arm_cond_slots.push(slot)
        emit_body(instrs, lines, arm.1, line, break_patches)
        let jump = instrs.length()
        instrs.push(Jump(-1))
        lines.push(line)
        end_jumps.push(jump)
      }
      emit_body(instrs, lines, else_body, line, break_patches)
      let else_start = then_jump + 1
      match instrs[cond_slot] {
        JumpIfFalse(expr, _) =>
          instrs[cond_slot] = JumpIfFalse(expr, else_start)
        _ => ()
      }
      let mut index = 0
      while index < arm_cond_slots.length() {
        let next = if index + 1 < arm_cond_slots.length() {
          arm_cond_slots[index + 1]
        } else {
          else_start
        }
        let slot = arm_cond_slots[index]
        match instrs[slot] {
          JumpIfFalse(expr, _) => instrs[slot] = JumpIfFalse(expr, next)
          _ => ()
        }
        index = index + 1
      }
      let end = instrs.length()
      for slot in end_jumps {
        match instrs[slot] {
          Jump(_) => instrs[slot] = Jump(end)
          _ => ()
        }
      }
    }
    @ir.CountLoop(times, loop_var, loop_body) => {
      let counter = "@i\{instrs.length()}"
      let init_slot = instrs.length()
      instrs.push(LoopInit(times, counter, -1))
      lines.push(line)
      let start = instrs.length()
      let check_slot = start
      let loop_var_name = match loop_var {
        Some(name) => name
        None => ""
      }
      instrs.push(LoopCheck(counter, loop_var_name, -1))
      lines.push(line)
      let patches : Array[Array[Int]] = []
      for existing in break_patches {
        patches.push(existing)
      }
      patches.push([])
      emit_body(instrs, lines, loop_body, line, patches)
      instrs.push(LoopNext(counter, start))
      lines.push(line)
      let end = instrs.length()
      match instrs[init_slot] {
        LoopInit(expr, slot, _) => instrs[init_slot] = LoopInit(expr, slot, end)
        _ => ()
      }
      match instrs[check_slot] {
        LoopCheck(counter_slot, loop_var_name, _) =>
          instrs[check_slot] = LoopCheck(counter_slot, loop_var_name, end)
        _ => ()
      }
      let inner = patches[patches.length() - 1]
      for slot in inner {
        match instrs[slot] {
          Jump(_) => instrs[slot] = Jump(end)
          _ => ()
        }
      }
    }
    @ir.WhileLoop(cond, loop_body) => {
      let start = instrs.length()
      let cond_slot = start
      instrs.push(JumpIfFalse(cond, -1))
      lines.push(line)
      let patches : Array[Array[Int]] = []
      for existing in break_patches {
        patches.push(existing)
      }
      patches.push([])
      emit_body(instrs, lines, loop_body, line, patches)
      instrs.push(Jump(start))
      lines.push(line)
      let end = instrs.length()
      match instrs[cond_slot] {
        JumpIfFalse(expr, _) => instrs[cond_slot] = JumpIfFalse(expr, end)
        _ => ()
      }
      let inner = patches[patches.length() - 1]
      for slot in inner {
        match instrs[slot] {
          Jump(_) => instrs[slot] = Jump(end)
          _ => ()
        }
      }
    }
  }
}
