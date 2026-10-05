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
  /// **被 `停止全部` 主动停住**——与 `Failed` 分开：停止不是错误，
  /// 审计与界面都该读作「用户让它停」，而不是「出错了」。
  Stopped
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
  VInt(Int)
  VStr(String)
  VArr(Array[Value])
  VBool(Bool)
  VUnit
  VStruct(Map[String, Value])
  VEnum(String, String) // 枚举值：枚举名, 情况名（M5-5d）
}

///|
/// 数值归一：无小数部分（且在精确整数范围内）的数值一律落成 VInt——
/// 教学语义：计数器 `计数 = 计数 + 1` 保持整数身份；带小数才升级为
/// VNum。字面量求值、取数内建、初始值共用这一条规则（编译轨同款）。
pub fn int_value(n : Double) -> Value {
  if n == n.floor() && n.abs() < 1.0e15 {
    VInt(n.to_int())
  } else {
    VNum(n)
  }
}

///|
/// 运行指令。控制流指令用跳转目标下标；循环用隐藏计数器槽
/// （名字形如 `@i12`，与用户变量命名空间不冲突）。
pub(all) enum Instr {
  Declare(String, Expr)
  Assign(String, Expr)
  SetIndexVar(String, Expr, Expr)
  ReturnInstr(Expr?)
  ExprStmt(Expr)
  JumpIfFalse(Expr, Int)
  Jump(Int)
  LoopInit(Expr, String, Int) // 次数表达式, 计数器槽, 循环结束目标
  LoopCheck(String, String, Int) // 计数器槽, 循环变量(""=无), 循环结束目标
  LoopNext(String, Int) // 计数器槽, 循环开始目标
  CaseOf(Expr, Array[String], Array[Int], Int) // subject, 情况名, 各臂跳转目标, else 目标（M5-5d）
}

///|
pub(all) struct Plan {
  instrs : Array[Instr]
  lines : Array[Int]
}

///|
pub(all) struct RunState {
  mut plan : Plan
  mut pc : Int
  mut vars : Map[String, Value]
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
  /// `询问` 的**回答文本**（与 `gate_answers` 一一对应）。
  ///
  /// 为什么必须单独存文本：`询问` 在 Scratch 里的语义是「问一句，**把回答
  /// 当值用**」（`说 (回答)`）。此前只存了 `Bool`（确认/拒绝），于是回答内容
  /// 被丢掉——`ask` 只能当「是/否」用，而那不是它的语义。
  gate_answer_texts : Array[String]
  /// 最近一次 `询问` 的回答（Scratch 的 `回答` 报告块读取它）。
  mut last_answer : String
  mut declared : Array[String]
  mut gate_cursor : Int
  mut paused : Bool
  /// `等待 N 秒` 的**剩余 tick 数**（0 = 没在等）。
  ///
  /// 用 tick 计数而不是墙钟：解释器是**纯函数式状态机**（测试不碰 UI），
  /// 读真实时间会让同一程序两次运行结果不同。宿主每个 `RunTick` 调一次
  /// `tick_wait`，减到 0 才继续执行下一条语句。
  mut wait_ticks : Int
  // 广播总线（切片 G）：`广播(文案)` 入队，宿主事件收尾时排空——
  // 每个 on_broadcast 窗体级处理器依次收到一条
  mut broadcasts : Array[String]
  // 用户自定义函数（切片 F）：调用解析与帧执行
  functions : Array[@ir.FuncDef]
  mut call_depth : Int
  mut return_slot : Value?
}

///|
/// 默认步数预算：防死循环冻结 UI。
pub const DEFAULT_MAX_STEPS : Int = 100_000

///|
/// 用户函数调用深度上限（防失控递归；步数预算之外的第二道闸）。
pub const MAX_CALL_DEPTH : Int = 16

///|
/// 默认随机种子（两轨同口径：编译轨的 RANDOM_SEED 是同一个数）。
pub const DEFAULT_SEED : Int = 20260927

///|
/// 推进一格 xorshift 种子（与 `random` 内建同一递推）。
///
/// **为什么需要它**：解释轨每次事件都新建一个 `RunState`，如果每次都从
/// 同一个 seed 起算，同一个按钮点十次会得到十个完全相同的「随机」结果
/// （实测点名册每次都是「王五」），用户读到的现象就是「运行之后点按钮
/// 没反应」。宿主把上次的种子推进一格再交给下一次事件，随机序列因此跨
/// 事件连续；事件内部的多次 `random` 照常各自推进。
pub fn next_seed(seed : Int) -> Int {
  let mut next = if seed <= 0 { DEFAULT_SEED } else { seed % 2147483647 }
  next = next ^ ((next << 13) & 2147483647)
  next = next ^ (next >> 17)
  next = next ^ ((next << 5) & 2147483647)
  if next <= 0 {
    1
  } else {
    next
  }
}

///|
/// 从程序提取初始变量值（init 文本：像数字就按数字，否则按文本）。
pub fn initial_values(program : StudioProgram) -> Map[String, Value] {
  let values : Map[String, Value] = Map([], capacity=8)
  for variable in program.variables {
    match text_to_number(variable.init) {
      Some(n) => values[variable.name] = int_value(n)
      None =>
        // 列表字面量初始值：`[]` / `[1, 2, 3]`（全局变量存列表）
        match constant_value(variable.init) {
          Some(value) => values[variable.name] = value
          None => values[variable.name] = VStr(variable.init)
        }
    }
  }
  values
}

///|
/// 文本 → 常量值：仅列表字面量与其中的字面量元素（无变量、无调用）。
/// 非列表文本返回 None（走原 number/str 路径）。
pub fn constant_value(text : String) -> Value? {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("[") || !trimmed.has_suffix("]") {
    return None
  }
  match parse_expression_text(trimmed, ZhHans) {
    Err(_) => None
    Ok(expr) => constant_of_expr(expr)
  }
}

///|
fn constant_of_expr(expr : Expr) -> Value? {
  match expr {
    @ir.NumLit(n) => Some(VNum(n))
    @ir.IntLit(n) => Some(VInt(n))
    @ir.StrLit(text) => Some(VStr(text))
    @ir.BoolLit(flag) => Some(VBool(flag))
    @ir.ListLit(items) => {
      let values : Array[Value] = []
      for item in items {
        match constant_of_expr(item) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(VArr(values))
    }
    _ => None
  }
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
  seed? : Int = DEFAULT_SEED,
  functions? : Array[@ir.FuncDef] = [],
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
    gate_answer_texts: [],
    last_answer: "",
    declared: [],
    gate_cursor: 0,
    paused: false,
    wait_ticks: 0,
    broadcasts: [],
    functions: functions,
    call_depth: 0,
    return_slot: None,
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
  seed? : Int = DEFAULT_SEED,
  functions? : Array[@ir.FuncDef] = [],
) -> RunState {
  start_run(
    traced_from_stmts(body),
    texts,
    values,
    rows,
    max_steps~,
    seed~,
    functions~,
  )
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
      SetIndexVar(name, index, value) => {
        let existing = match state.vars.get(name) {
          Some(v) => v
          None => raise LangError(NotDeclared, line, name, "use declare first")
        }
        let index_value = state.eval(index, line)
        if state.paused || !(state.status is Running) {
          return
        }
        let value_value = state.eval(value, line)
        if state.paused || !(state.status is Running) {
          return
        }
        set_index_value(existing, index_value, value_value, line)
        state.audit.push(StepRecord::{
          line,
          op: OpAssign,
          detail: "\{name}[\{canonical_expr(index)}] = \{canonical_expr(value)}",
        })
        state.pc = state.pc + 1
      }
      ReturnInstr(expr) => {
        // 返回 = 跳到计划末尾；值暂存 return_slot 供 call_user_function 取
        match expr {
          Some(value) => {
            let result = state.eval(value, line)
            if state.paused || !(state.status is Running) {
              return
            }
            state.return_slot = Some(result)
          }
          None => state.return_slot = Some(VUnit)
        }
        state.pc = state.plan.instrs.length()
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
      CaseOf(subject, case_names, targets, else_target) => {
        // 匹配分派（M5-5d）：subject 单次求值，必须枚举值
        let value = state.eval(subject, line)
        if state.paused || !(state.status is Running) {
          return
        }
        let case_name = match value {
          VEnum(_enum_name, matched) => matched
          _ =>
            raise LangError(TypeMismatch, line, "匹配对象", "应为枚举值")
        }
        state.audit.push(StepRecord::{
          line,
          op: OpCondition,
          detail: "\{canonical_expr(subject)} -> \{case_name}",
        })
        let mut target = else_target
        let mut index = 0
        while index < case_names.length() {
          if case_names[index] == case_name {
            target = targets[index]
            break
          }
          index = index + 1
        }
        state.pc = target
      }
      Jump(target) => state.pc = target
      LoopInit(times, counter, end) => {
        let value = state.eval(times, line)
        if state.paused || !(state.status is Running) {
          return
        }
        let count = match value {
          VNum(n) => n.to_int()
          VInt(n) => n
          _ => raise LangError(BadLoopCount, line, "", "")
        }
        state.vars["\{counter}#n"] = VInt(count)
        state.vars[counter] = VInt(1)
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
            state.vars[loop_var] = VInt(index.to_int())
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
        state.vars[counter] = VInt(index.to_int() + 1)
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
  answer_gate_with_text(state, decision, "")
}

///|
/// 带**回答文本**的闸门应答（`询问` 用这个）。
///
/// 文本既进 `gate_answer_texts`（按序对应，供 `eval_gate` 取值），也写进
/// `last_answer`（Scratch 的 `回答` 报告块随时可读最近一次回答，不限于
/// `询问` 紧邻的下一句）。
pub fn answer_gate_with_text(
  state : RunState,
  decision : Bool,
  text : String,
) -> Unit {
  if !(state.status is WaitingGate) {
    return
  }
  state.gate_answers.push(decision)
  state.gate_answer_texts.push(text)
  if text != "" {
    state.last_answer = text
  }
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
    Some(VInt(n)) => n.to_double()
    Some(_) => raise LangError(TypeMismatch, line, name, "number")
    None => raise LangError(NotDeclared, line, name, "")
  }
}

///|
fn RunState::as_bool(
  _self : RunState,
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
/// 调用用户函数：整帧隔离（vars/declared 全量保存恢复），参数按位绑定；
/// 体以行号 0 编译（函数体没有用户源码行号，两轨审计口径一致）；
/// Return 落 return_slot，体跑完无 Return 即 VUnit。
/// 步数沿用全局预算（step_once 内累加），深度有独立上限。
fn RunState::call_user_function(
  self : RunState,
  func : @ir.FuncDef,
  arg_values : Array[Value],
  line : Int,
) -> Value raise LangError {
  if self.call_depth >= MAX_CALL_DEPTH {
    raise LangError(StepBudget, line, "call depth", "\{MAX_CALL_DEPTH}")
  }
  if arg_values.length() != func.params.length() {
    raise LangError(ArityMismatch, line, func.name, "\{func.params.length()}/\{arg_values.length()}")
  }
  // 帧：全量快照 vars/declared（教学规模下 Map 拷贝可忽略）
  let saved_vars : Map[String, Value] = Map([], capacity=16)
  for key in self.vars.keys() {
    match self.vars.get(key) {
      Some(value) => saved_vars[key] = value
      None => ()
    }
  }
  let saved_declared : Array[String] = []
  for name in self.declared {
    saved_declared.push(name)
  }
  let index : Array[Value] = arg_values
  for param_index, param in func.params {
    if param_index < index.length() {
      self.vars[param] = index[param_index]
      if !self.declared.contains(param) {
        self.declared.push(param)
      }
    }
  }
  self.call_depth = self.call_depth + 1
  self.return_slot = None
  // 子帧直接在主状态上执行：把 plan/pc 换成子计划，Return/体末还原。
  // 审计/步数/随机数/闸门全部沿用主状态——两轨口径天然一致。
  let saved_plan = self.plan
  let saved_pc = self.pc
  self.plan = compile_body(traced_from_stmts(func.body))
  self.pc = 0
  while self.status is Running && self.pc < self.plan.instrs.length() {
    step_once(self)
  }
  let result = match self.return_slot {
    Some(value) => value
    None => VUnit
  }
  self.return_slot = None
  self.plan = saved_plan
  self.pc = saved_pc
  self.call_depth = self.call_depth - 1
  // 恢复帧（vars/declared 已原地变动；status/gate/paused 的变化
  // 留在主状态上——闸门暂停语义与命令一致）
  self.vars = saved_vars
  self.declared = saved_declared
  result
}

///|
/// 值 → 文本（属性面板/内建参数共用；逻辑值渲染为真/假由界面本地化）。
pub fn value_to_text(value : Value) -> String {
  match value {
    VNum(n) => number_to_text(n)
    VInt(n) => n.to_string()
    VStr(text) => text
    VEnum(enum_name, case_name) => "\{enum_name}::\{case_name}"
    VStruct(fields) => {
      let buf = StringBuilder()
      buf.write_string("{")
      let mut first = true
      for key, val in fields {
        if !first {
          buf.write_string(", ")
        }
        buf.write_string("\{key}: \{value_to_text(val)}")
        first = false
      }
      buf.write_string("}")
      buf.to_string()
    }
    VArr(items) => {
      let buf = StringBuilder()
      buf.write_string("[")
      let mut first = true
      for item in items {
        if !first {
          buf.write_string(", ")
        }
        buf.write_string(value_to_text(item))
        first = false
      }
      buf.write_string("]")
      buf.to_string()
    }
    VBool(true) => "true"
    VBool(false) => "false"
    VUnit => ""
  }
}

///|
fn RunState::value_as_text(
  _self : RunState,
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
    @ir.IntLit(n) => VInt(n)
    @ir.StrLit(text) => VStr(text)
    @ir.BoolLit(flag) => VBool(flag)
    @ir.EnumTag(enum_name, case_name) => VEnum(enum_name, case_name)
    @ir.FieldAccess(base, field) => {
      let base_val = self.eval(base, line)
      match base_val {
        VStruct(fields) =>
          match fields.get(field) {
            Some(v) => v
            None => raise LangError(UnknownName, 0, field, "")
          }
        _ => raise LangError(UnknownName, 0, field, "")
      }
    }
    @ir.ListLit(items) => {
      let values : Array[Value] = []
      for item in items {
        values.push(self.eval(item, line))
        if self.paused || !(self.status is Running) {
          return VUnit
        }
      }
      VArr(values)
    }
    @ir.Index(base, index) => {
      let base_value = self.eval(base, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      let index_value = self.eval(index, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      self.index_value(base_value, index_value, line)
    }
    @ir.Var(name) =>
      match self.vars.get(name) {
        Some(value) => value
        None => raise LangError(NotDeclared, line, name, "")
      }
    @ir.Not(inner) => {
      let flag = self.as_bool(self.eval(inner, line), "not operand", line)
      VBool(!flag)
    }
    @ir.Neg(inner) =>
      match self.eval(inner, line) {
        VInt(n) => VInt(-n)
        VNum(n) => VNum(-n)
        other =>
          raise LangError(
            TypeMismatch,
            line,
            "negation operand",
            value_to_text(other),
          )
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
    VInt(n) => n.to_double()
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
        (VInt(a), VInt(b)) => VInt(a + b)
        (VNum(a), VNum(b)) => VNum(a + b)
        (VInt(a), VNum(b)) => VNum(a.to_double() + b)
        (VNum(a), VInt(b)) => VNum(a + b.to_double())
        (VStr(_), _) | (_, VStr(_)) => VStr(value_to_text(l) + value_to_text(r))
        _ => raise LangError(TypeMismatch, line, "+", "same types")
      }
    @ir.Sub =>
      match (l, r) {
        (VInt(a), VInt(b)) => VInt(a - b)
        (VNum(a), VNum(b)) => VNum(a - b)
        (VInt(a), VNum(b)) => VNum(a.to_double() - b)
        (VNum(a), VInt(b)) => VNum(a - b.to_double())
        _ => raise LangError(TypeMismatch, line, "-", "numbers")
      }
    @ir.Mul =>
      match (l, r) {
        (VInt(a), VInt(b)) => VInt(a * b)
        (VNum(a), VNum(b)) => VNum(a * b)
        (VInt(a), VNum(b)) => VNum(a.to_double() * b)
        (VNum(a), VInt(b)) => VNum(a * b.to_double())
        _ => raise LangError(TypeMismatch, line, "*", "numbers")
      }
    @ir.Div =>
      match (l, r) {
        // 整数 ÷ 整数 = 整数（向零截断）：教学语义，除零与浮点同报错
        (VInt(a), VInt(b)) =>
          if b == 0 {
            raise LangError(DivideByZero, line, "", "")
          } else {
            VInt(a / b)
          }
        (VNum(a), VNum(b)) =>
          if b == 0.0 {
            raise LangError(DivideByZero, line, "", "")
          } else {
            VNum(a / b)
          }
        (VInt(a), VNum(b)) =>
          if b == 0.0 {
            raise LangError(DivideByZero, line, "", "")
          } else {
            VNum(a.to_double() / b)
          }
        (VNum(a), VInt(b)) =>
          if b == 0 {
            raise LangError(DivideByZero, line, "", "")
          } else {
            VNum(a / b.to_double())
          }
        _ => raise LangError(TypeMismatch, line, "/", "numbers")
      }
    @ir.Eq | @ir.Ne => {
      let same = self.values_equal(l, r, line)
      VBool(if op is @ir.Eq { same } else { !same })
    }
    @ir.Lt | @ir.Gt | @ir.Le | @ir.Ge =>
      match (l, r) {
        (VInt(a), VInt(b)) =>
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
        (VInt(a), VNum(b)) =>
          VBool(compare_mixed(op, a.to_double(), b))
        (VNum(a), VInt(b)) => VBool(compare_mixed(op, a, b.to_double()))
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
/// 混合整型/浮点比较：统一升到 Double 再比（VInt 与 VNum 同为"数"，
/// 比较不因存储形态而异）。
fn compare_mixed(op : @ir.BinOp, a : Double, b : Double) -> Bool {
  if op is @ir.Lt {
    a < b
  } else if op is @ir.Gt {
    a > b
  } else if op is @ir.Le {
    a <= b
  } else {
    a >= b
  }
}

///|
/// 元素赋值：变量须持有列表；1 起、越界报错。列表按引用共享——
/// 两轨的 Map 里存的是同一个 Array 句柄，语义一致。
fn set_index_value(
  base : Value,
  index : Value,
  value : Value,
  line : Int,
) -> Unit raise LangError {
  let items = match base {
    VArr(items) => items
    _ => raise LangError(TypeMismatch, line, "index", "list")
  }
  let position = match index {
    VInt(n) => n
    VNum(n) => n.to_int()
    _ => raise LangError(TypeMismatch, line, "index", "number")
  }
  if position < 1 || position > items.length() {
    raise LangError(TypeMismatch, line, "index", "1..\{items.length()}")
  }
  items[position - 1] = value
}

///|
/// 下标取值：1 起（与取行 row_at 同口径）；越界/非列表报 TypeMismatch。
fn RunState::index_value(
  _self : RunState,
  base : Value,
  index : Value,
  line : Int,
) -> Value raise LangError {
  // **字符串也能按下标取字符**（Scratch 的「第 N 个字符」）。
  // 1-based，与列表一致：`"abc"[1]` = `"a"`。越界报错而不是返回空串
  // ——静默返回空串会让「取错位置」看起来像「字符串是空的」。
  match base {
    VArr(items) => {
      let position = match index {
        VInt(n) => n
        VNum(n) => n.to_int()
        _ => raise LangError(TypeMismatch, line, "index", "number")
      }
      if position < 1 || position > items.length() {
        raise LangError(TypeMismatch, line, "index", "1..\{items.length()}")
      }
      items[position - 1]
    }
    VStr(text) => {
      let position = match index {
        VInt(n) => n
        VNum(n) => n.to_int()
        _ => raise LangError(TypeMismatch, line, "index", "number")
      }
      // 按**字符**（而非字节）索引：中文一个字是一个字符，按字节会把
      // 一个汉字切成半个。`str_to_chars` 的语义与 `text_length` 一致。
      let chars : Array[String] = []
      for c in text {
        chars.push(c.to_string())
      }
      if position < 1 || position > chars.length() {
        raise LangError(TypeMismatch, line, "index", "1..\{chars.length()}")
      }
      VStr(chars[position - 1])
    }
    _ => raise LangError(TypeMismatch, line, "index", "list or text")
  }
}

///|
fn RunState::values_equal(
  _self : RunState,
  l : Value,
  r : Value,
  line : Int,
) -> Bool raise LangError {
  match (l, r) {
    (VNum(a), VNum(b)) => a == b
    (VInt(a), VInt(b)) => a == b
    (VInt(a), VNum(b)) => a.to_double() == b
    (VNum(a), VInt(b)) => a == b.to_double()
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
    None => {
      // 内建没有 → 用户自定义函数（调用解析：先内建、后自定义）
      let mut found : @ir.FuncDef? = None
      for func in self.functions {
        if func.name == name {
          found = Some(func)
        }
      }
      match found {
        None => raise LangError(UnknownBuiltin, line, name, "")
        Some(func) => {
          let arg_values : Array[Value] = []
          for arg in args {
            arg_values.push(self.eval(arg, line))
            if self.paused || !(self.status is Running) {
              return VUnit
            }
          }
          self.call_user_function(func, arg_values, line)
        }
      }
    }
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
      // **`询问` 的返回值是回答文本**（Scratch 语义），不是「是否确认」。
      // 回答为空时回退到最近一次回答：用户点了确认但没输入内容时，
      // 返回空串会让 `说 (回答)` 显示空白，而用户期望看到上一次的回答。
      let answer = if self.gate_cursor - 1 < self.gate_answer_texts.length() {
        self.gate_answer_texts[self.gate_cursor - 1]
      } else {
        ""
      }
      if answer == "" {
        VStr(self.last_answer)
      } else {
        VStr(answer)
      }
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
    "wait" => {
      // **等待 N 秒**：把秒数折算成 tick 数并挂起。折算在**宿主**那一侧
      // （`TICK_MS` 已知），这里只收秒数——解释器不关心帧率。
      let seconds = match self.eval(args[0], line) {
        VNum(n) => n
        VInt(n) => n.to_double()
        _ => raise LangError(TypeMismatch, line, spec.id, "number")
      }
      if seconds < 0.0 {
        raise LangError(TypeMismatch, line, spec.id, "non-negative number")
      }
      self.wait_ticks = wait_ticks_for_seconds(seconds)
      VUnit
    }
    "stop_all" => {
      // 停止全部：把自己标成 Stopped。`step_once` 只在 `Running` 时推进，
      // 所以这一条执行完循环自然结束；广播队列也不再排空。
      //
      // **必须放在 `eval_command`**（按 `BuiltinKind::Command` 分派）而不是
      // `eval_function`：目录里它是 Command，放错分支就永远走不到——症状是
      // 「未知内建」错误，而代码里明明写着实现。
      self.status = Stopped
      VUnit
    }
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
    "broadcast" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      self.broadcasts.push(text)
      self.audit.push(StepRecord::{
        line,
        op: OpCommand,
        detail: canonical_call_text(spec.id, args),
      })
      VUnit
    }
    "append_list" => {
      // 命令：第一个参数是**变量名**（裸标识符），列表按引用修改
      let name = match args[0] {
        @ir.Var(name) => name
        _ =>
          raise LangError(TypeMismatch, line, "append_list", "variable")
      }
      let items = match self.vars.get(name) {
        Some(VArr(items)) => items
        Some(_) =>
          raise LangError(TypeMismatch, line, name, "list")
        None =>
          raise LangError(NotDeclared, line, name, "use declare first")
      }
      let value = self.eval(args[1], line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      items.push(value)
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
        Some(n) => int_value(n)
        None => raise LangError(TypeMismatch, line, control, "number text")
      }
    }
    "to_text" => {
      let value = self.eval(args[0], line)
      VStr(value_to_text(value))
    }
    "mod" => {
      // 取余**保留整数性**（与 `Div` 的「整数 ÷ 整数 = 整数」同一纪律）：
      // 整数 % 整数 → 整数，掺入小数才是小数。Scratch 的 `mod` 也是如此，
      // 而且整数余数在循环计数里是常见用法，返回浮点会显示成 `1.0`。
      match (self.eval(args[0], line), self.eval(args[1], line)) {
        (VInt(a), VInt(b)) =>
          if b == 0 {
            raise LangError(DivideByZero, line, spec.id, "")
          } else {
            // MoonBit 的 `%` 与 C 同号（向零截断），Scratch 的 mod 取
            // **非负**余数；这里按 Scratch 语义修正，免得 `-7 mod 3`
            // 在教学场景里得到 -1。
            let raw = a % b
            VInt(if raw < 0 { raw + (if b < 0 { -b } else { b }) } else { raw })
          }
        (left, right) => {
          // 掺入小数：按浮点取余。`as_number` 与既有二元运算同一口径
          // （`VNum` 直取、`VInt` 提升，其余报类型错）。
          let a = match left {
            VNum(n) => n
            VInt(n) => n.to_double()
            _ => raise LangError(TypeMismatch, line, spec.id, "numbers")
          }
          let b = match right {
            VNum(n) => n
            VInt(n) => n.to_double()
            _ => raise LangError(TypeMismatch, line, spec.id, "numbers")
          }
          if b == 0.0 {
            raise LangError(DivideByZero, line, spec.id, "")
          } else {
            VNum(a - b * floor_of(a / b))
          }
        }
      }
    }
    "answer" => VStr(self.last_answer)
    "abs" => VNum(number_of_value(self.eval(args[0], line), spec.id, line).abs())
    "floor" =>
      VInt(floor_of(number_of_value(self.eval(args[0], line), spec.id, line)).to_int())
    "ceiling" =>
      VInt(
        (0.0 - floor_of(0.0 - number_of_value(self.eval(args[0], line), spec.id, line))).to_int(),
      )
    "sqrt" => {
      let value = number_of_value(self.eval(args[0], line), spec.id, line)
      if value < 0.0 {
        raise LangError(TypeMismatch, line, spec.id, "non-negative number")
      }
      VNum(sqrt_of(value))
    }
    "round" => {
      // 四舍五入到**整数**（Scratch 的 `round` 返回整数）：教学场景里
      // 学生要的是「3.6 → 4」，返回 4.0 会显示成 `4`（`number_to_text`
      // 会去掉 .0），但类型上仍是数——这里统一给 VInt 更贴合直觉。
      VInt(round_to_int(number_of_value(self.eval(args[0], line), spec.id, line)))
    }
    "text_length" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      VInt(text.length())
    }
    "contains" => {
      let text = self.value_as_text(self.eval(args[0], line), spec.id, line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      let sub = self.value_as_text(self.eval(args[1], line), spec.id, line)
      VBool(text.contains(sub))
    }
    "list_length" => {
      let value = self.eval(args[0], line)
      if self.paused || !(self.status is Running) {
        return VUnit
      }
      match value {
        VArr(items) => VInt(items.length())
        _ => raise LangError(TypeMismatch, line, "list_length", "list")
      }
    }
    "random" => {
      let max = self.eval_number(args[0], "random bound", line)
      self.rng = self.rng ^ ((self.rng << 13) & 2147483647)
      self.rng = self.rng ^ (self.rng >> 17)
      self.rng = self.rng ^ ((self.rng << 5) & 2147483647)
      let span = max.to_int()
      if span <= 1 {
        VInt(1)
      } else {
        VInt(self.rng % span + 1)
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
        Some(items) => VInt(items.length())
        None => VInt(0)
      }
    }
    "row_at" => {
      let control = self.control_name(args[0], line)
      let index_value = self.eval(args[1], line)
      let index = match index_value {
        VNum(n) => n.to_int()
        VInt(n) => n
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
    @ir.IntLit(n) => buf.write_string(n.to_string())
    @ir.StrLit(text) => buf.write_string("\"\{text}\"")
    @ir.BoolLit(flag) => buf.write_string(if flag { "true" } else { "false" })
    @ir.Var(name) => buf.write_string(name)
    @ir.FieldAccess(base, field) => {
      write_canonical_expr(buf, base)
      buf.write_string(".")
      buf.write_string(field)
    }
    @ir.EnumTag(enum_name, case_name) =>
      buf.write_string("\{enum_name}::\{case_name}")
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
    @ir.ListLit(items) => {
      buf.write_string("[")
      let mut first = true
      for item in items {
        if !first {
          buf.write_string(", ")
        }
        write_canonical_expr(buf, item)
        first = false
      }
      buf.write_string("]")
    }
    @ir.Index(base, index) => {
      write_canonical_expr(buf, base)
      buf.write_string("[")
      write_canonical_expr(buf, index)
      buf.write_string("]")
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
    @ir.SetIndex(name, index, value) => {
      instrs.push(SetIndexVar(name, index, value))
      lines.push(line)
    }
    @ir.Return(expr) => {
      instrs.push(ReturnInstr(expr))
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
    @ir.Match(subject, arms, else_body) => {
      // 单次求值：subject 只在分派指令里求值一次（M5-5d）
      let case_names : Array[String] = []
      let open_targets : Array[Int] = []
      for arm in arms {
        case_names.push(arm.case_name)
        open_targets.push(-1)
      }
      let dispatch_slot = instrs.length()
      instrs.push(CaseOf(subject, case_names, open_targets, -1))
      lines.push(line)
      let body_starts : Array[Int] = []
      let end_jumps : Array[Int] = []
      for arm in arms {
        body_starts.push(instrs.length())
        emit_body(instrs, lines, arm.body, line, break_patches)
        let jump = instrs.length()
        instrs.push(Jump(-1))
        lines.push(line)
        end_jumps.push(jump)
      }
      let else_start = instrs.length()
      emit_body(instrs, lines, else_body, line, break_patches)
      let end = instrs.length()
      match instrs[dispatch_slot] {
        CaseOf(subject2, names, _, _) =>
          instrs[dispatch_slot] = CaseOf(subject2, names, body_starts, else_start)
        _ => ()
      }
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

///|
/// 宿主每个 tick 调一次：等到了就返回 `true`（可以继续执行）。
///
/// 与闸门（`WaitingGate`）分开：闸门**等人的回答**，等待**等时间**。
/// 两者都不推进 `pc`——所以「等待中再 tick 一次」是安全的幂等操作。
pub fn tick_wait(state : RunState) -> Bool {
  if state.wait_ticks <= 0 {
    return true
  }
  state.wait_ticks = state.wait_ticks - 1
  state.wait_ticks <= 0
}

///|
/// 秒 → tick 数的折算（宿主调用，帧率由宿主决定）。
///
/// 向上取整并保底 1：`等待 0.01 秒` 在 30ms 帧率下也应该**至少等一帧**，
/// 否则「等待」会退化成「什么都不做」，用户看到的是「这句没生效」。
pub fn wait_ticks_for_seconds(seconds : Double) -> Int {
  let ticks = (seconds * 1000.0 / 30.0).ceil().to_int()
  if ticks < 1 { 1 } else { ticks }
}

///|
/// 数值强制（与二元运算同一口径）：`VNum` 直取、`VInt` 提升，其余报类型错。
fn number_of_value(value : Value, role : String, line : Int) -> Double raise LangError {
  match value {
    VNum(n) => n
    VInt(n) => n.to_double()
    _ => raise LangError(TypeMismatch, line, role, "number")
  }
}

///|
/// 平方根（牛顿迭代）。不依赖标准库命名：只需要「正数的平方根」这一条
/// 语义，自己写清楚比猜 API 名更稳。迭代 24 次对教学精度足够（双精度
/// 收敛约 6 次，多留余量不花钱）。
fn sqrt_of(value : Double) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let mut guess = value
  if guess < 1.0 {
    guess = 1.0
  }
  let mut i = 0
  while i < 24 {
    guess = (guess + value / guess) / 2.0
    i = i + 1
  }
  guess
}

///|
/// 向下取整（`floor` 的本地实现）。
///
/// 不依赖标准库的命名细节：这里只需要「向负无穷取整」这一条语义，
/// 自己写清楚比猜 API 名更稳（且与 `mod` 的非负余数约定配套）。
fn floor_of(value : Double) -> Double {
  // `Double::floor` 就是「向负无穷取整」（`number_to_text` 也用同一个，
  // 所以格式化与取整的口径一致）。
  value.floor()
}

///|
/// 四舍五入到整数（.5 向上，与 Scratch 一致）。
fn round_to_int(value : Double) -> Int {
  floor_of(value + 0.5).to_int()
}
