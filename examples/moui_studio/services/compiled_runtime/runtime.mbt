///|
/// 编译轨运行时：导出的「真编译」产物里，生成源码唯一依赖的执行面。
///
/// 语义与 `domain/studio_lang/interp.mbt` 的指令机逐条对齐（值→文本、
/// 加法的数值/拼接分派、除零、短路逻辑、NotDeclared、计次循环的 1-based
/// 循环变量与隐藏计数槽、跳出循环、闸门 FIFO、审计规范文本、步数预算、
/// xorshift 随机数序列）。文本/数值转换直接复用领域内核，两轨不可能
/// 长成两个样子。控制流用 `Control` 错误在生成代码里传递：
/// `GateHalt` 表示停在闸门前等人，`LoopBreak` 表示跳出最近一层循环。

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
/// 审计记录：与解释轨同构（行号 + 类别 + 语言中立规范文本）。
pub(all) struct StepRecord {
  line : Int
  op : StepOp
  detail : String
}

///|
pub(all) enum GateKind {
  Submit
  Ask
}

///|
/// 外发闸门：程序在这里停下等人，确认前零真实动作。
pub(all) struct Gate {
  kind : GateKind
  prompt : String
  payload : String
}

///|
pub(all) enum RunStatus {
  Running
  WaitingGate
  Completed
  Failed
  /// **被 `停止全部` 主动停住**（与 `Failed` 分开：停止不是错误）。
  Stopped
}

///|
pub(all) enum ErrorKind {
  TypeMismatch
  NotDeclared
  DivideByZero
  BadLoopCount
  UnknownBuiltin
  StepBudget
}

///|
/// 运行期语言错误（数据槽 kind/line/a/b，可读文案由界面本地化）。
pub(all) struct ErrorDetails {
  kind : ErrorKind
  line : Int
  a : String
  b : String
}

///|
pub(all) suberror ExecError {
  RuntimeError(ErrorDetails)
  // 停在闸门前等人：本条指令作废，应答后由宿主重新推进子程序
  GateHalt
  // 跳出最近一层循环
  LoopBreak
  // 从用户函数返回（携带返回值；调用边界捕获成返回值）
  LoopReturn(Value)
}

///|
/// 默认步数预算：与解释轨同一常量。
pub const MAX_STEPS : Int = 100_000

///|
/// 默认随机种子：与解释轨同一常量（`随机数` 在两轨给出同一序列）。
pub const RANDOM_SEED : Int = 20260927

///|
/// 值：编译轨保持 DSL 的动态类型（数字/文本/逻辑三选一）。
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
/// 数值归一：与解释轨 `@studio_lang.int_value` 同一条规则——无小数部分
/// 的数值落成 VInt。字面量求值、取数内建、初始值共用。
pub fn int_value(n : Double) -> Value {
  if n == n.floor() && n.abs() < 1.0e15 {
    VInt(n.to_int())
  } else {
    VNum(n)
  }
}

///|
/// 值 → 文本（数字形式复用领域内核的 number_to_text）。
pub fn value_to_text(value : Value) -> String {
  match value {
    VNum(n) => @studio_lang.number_to_text(n)
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
/// 生成代码里每个事件子程序的类型：读 Runtime、可抛控制错误。
pub(all) struct Handler((Runtime) -> Unit raise ExecError)

///|
/// 运行状态：控件文本、变量表、行、选中项、消息、审计、闸门、步数、随机数。
pub(all) struct Runtime {
  mut texts : Map[String, String]
  mut vars : Map[String, Value]
  mut rows : Map[String, Array[String]]
  mut selections : Map[String, Int]
  mut messages : Array[String]
  mut audit : Array[StepRecord]
  mut status : RunStatus
  mut gate : Gate?
  /// `等待 N 秒` 的剩余 tick 数（0 = 没在等）。与解释轨 `RunState::wait_ticks`
  /// 同一语义：用 tick 计数而非墙钟，保证两条轨在同一虚拟时钟下行为一致。
  mut wait_ticks : Int
  mut error : ErrorDetails?
  mut steps : Int
  max_steps : Int
  mut rng : Int
  mut gate_answers : Array[Bool]
  /// `询问` 的回答文本（与 `gate_answers` 一一对应）。
  gate_answer_texts : Array[String]
  /// 最近一次 `询问` 的回答（`回答` 报告块读取它）。
  mut last_answer : String
  mut gate_cursor : Int
  mut declared : Array[String]
  // 事务式重放：闸门应答后从头重放，但从运行前快照恢复全部可观察状态，
  // 因此对宿主而言与解释轨「停在指令处、从指令处继续」等价。
  mut active_handler : Handler?
  mut base_texts : Map[String, String]
  mut base_vars : Map[String, Value]
  mut base_rows : Map[String, Array[String]]
  mut base_selections : Map[String, Int]
  mut base_declared : Array[String]
  // 闸门重放要还原随机序列：不还原的话「确认一次」会把整段子程序里的
  // `随机数` 再抽一遍，同一个副作用算出两个结果。
  mut base_rng : Int
  // 用户自定义函数（切片 F）：生成代码/内置 lowering 注册，帧在
  // call_user_function 里整帧隔离。
  mut user_functions : Map[String, UserFunction]
  mut call_depth : Int
  // 广播总线（切片 G）：`广播(文案)` 入队，宿主事件收尾时排空
  mut broadcasts : Array[String]
}

///|
/// 用户函数闭包：运行时 + 已求值实参 → 返回值。Return 经 LoopReturn
/// 控制信号传回，边界处捕获。
pub type UserFunction = (Runtime, Array[Value]) -> Value raise ExecError

///|
/// 用户函数调用深度上限（与解释轨 MAX_CALL_DEPTH 同值）。
pub const MAX_USER_CALL_DEPTH : Int = 16

///|
/// 按项目播种运行时（初值文本像数字按数字，否则按文本；与解释轨
/// initial_values/initial_texts/initial_rows 同一规则）。
pub fn new_runtime(
  texts : Map[String, String],
  rows : Map[String, Array[String]],
  variables : Array[(String, String)],
) -> Runtime {
  let vars : Map[String, Value] = Map([], capacity=8)
  let declared : Array[String] = []
  for pair in variables {
    declared.push(pair.0)
    match @studio_lang.text_to_number(pair.1) {
      Some(n) => vars[pair.0] = int_value(n)
      None => vars[pair.0] = VStr(pair.1)
    }
  }
  {
    texts,
    vars,
    rows,
    selections: Map([], capacity=4),
    messages: [],
    audit: [],
    status: Running,
    gate: None,
    wait_ticks: 0,
    error: None,
    steps: 0,
    max_steps: MAX_STEPS,
    rng: seed_rng(RANDOM_SEED),
    user_functions: Map([], capacity=2),
    call_depth: 0,
    broadcasts: [],
    gate_answers: [],
    gate_answer_texts: [],
    last_answer: "",
    gate_cursor: 0,
    declared,
    active_handler: None,
    base_texts: Map([], capacity=8),
    base_vars: Map([], capacity=8),
    base_rows: Map([], capacity=4),
    base_selections: Map([], capacity=4),
    base_declared: [],
    base_rng: seed_rng(RANDOM_SEED),
  }
}

///|
fn seed_rng(seed : Int) -> Int {
  if seed <= 0 {
    1
  } else {
    seed % 2147483647
  }
}

///|
/// 推进一格 xorshift 种子（与 `random` 内建同一递推）。
///
/// 宿主在**每次事件前**调用它并把结果写回 `Runtime.rng` / 解释轨的
/// `start_run(seed=…)`：随机序列因此跨事件连续，同一个按钮点十次给出十个
/// 不同结果。事件的起点会被 `snapshot` 记下，闸门重放仍逐位可复现。
pub fn next_seed(rng : Int) -> Int {
  let mut next = if rng <= 0 { seed_rng(RANDOM_SEED) } else { rng }
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
/// 开始一次子程序运行：快照当前状态、清运行留痕，推进到终止态。
/// 快照让每次闸门应答后可以完整重放，避免 append_row/随机数等副作用翻倍。
///
/// **随机种子由调用方提供**（`rt.rng` 的当前值），本函数不自行重置：
/// 宿主在每次事件前把种子推进一格，两轨（解释轨 `start_run` 的 seed 参数、
/// 编译轨 `rt.rng`）因此从同一个种子起算，差分门逐位可比。反过来若在这里
/// 重置成 RANDOM_SEED，同一个按钮点十次会得到十个相同的「随机」结果——
/// 用户读到的现象就是「运行之后点按钮没反应」。
pub fn run_handler(rt : Runtime, handler : Handler) -> RunStatus {
  rt.active_handler = Some(handler)
  rt.gate_answers = []
  snapshot(rt)
  attempt(rt)
  rt.status
}

///|
/// 闸门应答（FIFO）：记下决定后重放到下一个终止态（完成/闸门/失败）。
pub fn answer_gate(rt : Runtime, decision : Bool) -> RunStatus {
  answer_gate_with_text(rt, decision, "")
}

///|
/// 带**回答文本**的闸门应答（`询问` 用这个）。与解释轨
/// `answer_gate_with_text` 同一语义：文本按序入队，并更新 `last_answer`。
pub fn answer_gate_with_text(
  rt : Runtime,
  decision : Bool,
  text : String,
) -> RunStatus {
  if !(rt.status is WaitingGate) {
    return rt.status
  }
  rt.gate_answers.push(decision)
  rt.gate_answer_texts.push(text)
  if text != "" {
    rt.last_answer = text
  }
  rt.gate = None
  rt.status = Running
  attempt(rt)
  rt.status
}

///|
/// `回答` 报告块：最近一次询问的回答文本。
pub fn last_answer(rt : Runtime) -> Value {
  VStr(rt.last_answer)
}

///|
fn snapshot(rt : Runtime) -> Unit {
  let texts : Map[String, String] = Map([], capacity=8)
  for key in rt.texts.keys() {
    texts[key] = rt.texts.get(key).unwrap_or("")
  }
  rt.base_texts = texts
  let vars : Map[String, Value] = Map([], capacity=8)
  for key in rt.vars.keys() {
    match rt.vars.get(key) {
      // 深拷贝列表：闸门回滚要还原元素修改，不能共享可变数组
      Some(VArr(items)) => {
        let copy : Array[Value] = []
        for item in items {
          copy.push(copy_value(item))
        }
        vars[key] = VArr(copy)
      }
      Some(value) => vars[key] = value
      None => ()
    }
  }
  rt.base_vars = vars
  rt.base_rows = copy_rows(rt.rows)
  rt.base_selections = copy_selections(rt.selections)
  let declared : Array[String] = []
  for name in rt.declared {
    declared.push(name)
  }
  rt.base_declared = declared
  rt.base_rng = rt.rng
}

///|
fn restore(rt : Runtime) -> Unit {
  rt.texts = copy_texts(rt.base_texts)
  rt.vars = copy_values(rt.base_vars)
  rt.rows = copy_rows(rt.base_rows)
  rt.selections = copy_selections(rt.base_selections)
  let declared : Array[String] = []
  for name in rt.base_declared {
    declared.push(name)
  }
  rt.declared = declared
  rt.rng = rt.base_rng
}

///|
fn copy_texts(source : Map[String, String]) -> Map[String, String] {
  let copied : Map[String, String] = Map([], capacity=8)
  for key in source.keys() {
    copied[key] = source.get(key).unwrap_or("")
  }
  copied
}

///|
fn copy_values(source : Map[String, Value]) -> Map[String, Value] {
  let copied : Map[String, Value] = Map([], capacity=8)
  for key in source.keys() {
    match source.get(key) {
      Some(value) => copied[key] = value
      None => ()
    }
  }
  copied
}

///|
fn copy_rows(source : Map[String, Array[String]]) -> Map[String, Array[String]] {
  let copied : Map[String, Array[String]] = Map([], capacity=4)
  for key in source.keys() {
    let items : Array[String] = []
    match source.get(key) {
      Some(existing) =>
        for item in existing {
          items.push(item)
        }
      None => ()
    }
    copied[key] = items
  }
  copied
}

///|
fn copy_selections(source : Map[String, Int]) -> Map[String, Int] {
  let copied : Map[String, Int] = Map([], capacity=4)
  for key in source.keys() {
    copied[key] = source.get(key).unwrap_or(0)
  }
  copied
}

///|
fn attempt(rt : Runtime) -> Unit {
  match rt.active_handler {
    None => rt.status = Failed
    Some(handler) => {
      restore(rt)
      rt.audit = []
      rt.messages = []
      rt.status = Running
      rt.gate = None
      rt.error = None
      rt.steps = 0
      rt.gate_cursor = 0
      try {
        drive(rt, handler)
        if rt.status is Running {
          rt.status = Completed
        }
      } catch {
        GateHalt => rt.status = WaitingGate
        LoopBreak => rt.status = Completed
        // Return 泄漏到顶层：语义校验拒绝它在函数体外出现在合法程序里；
        // 防御性处理为完成（返回值丢弃）。
        LoopReturn(_) => rt.status = Completed
        RuntimeError(error) => {
          rt.status = Failed
          rt.error = Some(error)
        }
      }
    }
  }
}

///|
fn drive(rt : Runtime, handler : Handler) -> Unit raise ExecError {
  (handler.0)(rt)
}

///|
/// 按程序初值播种运行时（初值文本像数字按数字，否则按文本；
/// 与解释轨 initial_values/initial_texts/initial_rows 同一规则）。
pub fn runtime_for_program(
  program : @ir.StudioProgram,
  lower? : ((@ir.FuncDef) -> UserFunction)? = None,
) -> Runtime {
  let texts : Map[String, String] = Map([], capacity=8)
  for control in program.controls {
    texts[control.name] = control.text
  }
  let rows : Map[String, Array[String]] = Map([], capacity=4)
  for control in program.controls {
    let items : Array[String] = []
    for item in control.items {
      items.push(item)
    }
    rows[control.name] = items
  }
  let variables : Array[(String, String)] = []
  for variable in program.variables {
    variables.push((variable.name, variable.init))
  }
  let runtime = new_runtime(texts, rows, variables)
  // 注册用户函数（切片 F）：lower 钩子由 IDE 内编译轨传入（lower.mbt 的
  // 闭包）；导出 bundle 的 kernel 副本没有 lower——生成代码经 runner 的
  // studio_dispatch_function 自行注册。
  match lower {
    Some(lower_function) =>
      for func in program.functions {
        runtime.register_user_function(func.name, lower_function(func))
      }
    None => ()
  }
  runtime
}

///|
/// 未知内建：生成期无法解析的调用在运行期报与解释轨相同的 UnknownBuiltin。
pub fn unknown_builtin(name : String, line : Int) -> Value raise ExecError {
  raise ExecError::RuntimeError(ErrorDetails::{
    kind: UnknownBuiltin,
    line,
    a: name,
    b: "",
  })
}

///|
/// 参数个数错误（生成期保险丝；合法程序不会走到这里）。
pub fn arity_error(
  name : String,
  expected : Int,
  actual : Int,
  line : Int,
) -> Value raise ExecError {
  raise ExecError::RuntimeError(ErrorDetails::{
    kind: TypeMismatch,
    line,
    a: name,
    b: "\{expected}/\{actual}",
  })
}

///|
/// 变量读写（未声明读回按 NotDeclared，与解释轨 lookup 同口径）。
pub fn Runtime::get(
  self : Runtime,
  name : String,
  line : Int,
) -> Value raise ExecError {
  match self.vars.get(name) {
    Some(value) => value
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: NotDeclared,
        line,
        a: name,
        b: "",
      })
  }
}

///|
pub fn Runtime::set(self : Runtime, name : String, value : Value) -> Unit {
  self.vars[name] = value
  if !self.declared.contains(name) {
    self.declared.push(name)
  }
}

///|
/// 赋值记账（Declare/Assign 共用；detail 是生成期烘死的规范表达式文本）。
pub fn Runtime::audit_assign(
  self : Runtime,
  name : String,
  value : Value,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  ignore(value)
  self.set(name, value)
  self.record(line, OpAssign, detail)
}

///|
pub fn Runtime::require_declared(
  self : Runtime,
  name : String,
  line : Int,
) -> Unit raise ExecError {
  if !self.declared.contains(name) && self.vars.get(name) is None {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: NotDeclared,
      line,
      a: name,
      b: "use declare first",
    })
  }
}

///|
/// 记账 = 审计留痕 + 步数预算（与解释轨同口径：每条留痕算一步）。
pub fn Runtime::record(
  self : Runtime,
  line : Int,
  op : StepOp,
  detail : String,
) -> Unit raise ExecError {
  self.steps = self.steps + 1
  if self.steps > self.max_steps {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: StepBudget,
      line: 0,
      a: "",
      b: "",
    })
  }
  self.audit.push(StepRecord::{ line, op, detail, })
}

///|
/// 条件记账：`规范条件 -> true|false`（解释轨同文本）。
pub fn bool_text(flag : Bool) -> String {
  if flag {
    "true"
  } else {
    "false"
  }
}

///|
pub fn Runtime::record_condition(
  self : Runtime,
  flag : Bool,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  self.record(line, OpCondition, "\{detail} -> \{bool_text(flag)}")
}

///|
/// 循环记账：`iteration N`（解释轨同文本）。
pub fn Runtime::record_iteration(
  self : Runtime,
  index : Int,
  line : Int,
) -> Unit raise ExecError {
  self.record(line, OpLoop, "iteration \{index}")
}

///|
/// 计次循环：1-based 循环变量、隐藏计数槽语义、每次迭代记一条审计，
/// `LoopBreak` 在这一层被吞掉（与解释轨的跳转回填等价）。
pub fn Runtime::count_loop(
  self : Runtime,
  times : Value,
  loop_var : String,
  line : Int,
  body : (Runtime) -> Unit raise ExecError,
) -> Unit raise ExecError {
  let count = match times {
    VNum(n) => n.to_int()
    VInt(n) => n
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: BadLoopCount,
        line,
        a: "",
        b: "",
      })
  }
  let mut index = 1
  while index <= count {
    if loop_var != "" {
      self.set(loop_var, VInt(index))
    }
    self.record_iteration(index, line)
    let mut stop = false
    drive(self, body) catch {
      LoopBreak => stop = true
      e => raise e
    }
    if stop {
      return
    }
    index = index + 1
  }
}

///|
/// 遍历循环（G7.1）：列表求值一次,1-based 元素变量绑定,每次迭代记一条
/// 审计（与解释轨 FeCheck 同口径）;`LoopBreak` 在这一层被吞掉。
pub fn Runtime::for_each(
  self : Runtime,
  list_value : Value,
  loop_var : String,
  line : Int,
  body : (Runtime) -> Unit raise ExecError,
) -> Unit raise ExecError {
  let items = match list_value {
    VArr(items) => items
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: BadLoopCount,
        line,
        a: "",
        b: "",
      })
  }
  let mut index = 1
  for item in items {
    if loop_var != "" {
      self.set(loop_var, item)
    }
    self.record_iteration(index, line)
    let mut stop = false
    drive(self, body) catch {
      LoopBreak => stop = true
      e => raise e
    }
    if stop {
      return
    }
    index = index + 1
  }
}

///|
/// 当循环：条件为真才进体；`LoopBreak` 在这一层被吞掉。
pub fn Runtime::while_loop(
  self : Runtime,
  line : Int,
  cond : (Runtime) -> Value raise ExecError,
  observe : (Runtime, Bool) -> Unit raise ExecError,
  body : (Runtime) -> Unit raise ExecError,
) -> Unit raise ExecError {
  let mut keep = true
  while keep {
    let value = cond(self)
    let flag = bool_of(value, "condition", line)
    observe(self, flag)
    keep = flag
    if keep {
      let mut stop = false
      drive(self, body) catch {
        LoopBreak => stop = true
        e => raise e
      }
      if stop {
        return
      }
    }
  }
}

///|
pub fn Runtime::break_loop(self : Runtime) -> Unit raise ExecError {
  ignore(self)
  raise ExecError::LoopBreak
}

///|
/// 逻辑取反（非逻辑操作数 → TypeMismatch，同解释轨）。

///|
/// 值深拷贝（闸门快照用）：只有列表是可变的，其余按值共享。
fn copy_value(value : Value) -> Value {
  match value {
    VArr(items) => {
      let copy : Array[Value] = []
      for item in items {
        copy.push(copy_value(item))
      }
      VArr(copy)
    }
    other => other
  }
}

///|
/// 下标取值：1 起（与解释轨 index_value / 取行 row_at 同口径）。
pub fn index_values(
  base : Value,
  index : Value,
  line : Int,
) -> Value raise ExecError {
  // **字符串也能按下标取字符**（Scratch 的「第 N 个字符」），与解释轨
  // `index_value` 同一语义：1-based，按**字符**而非字节，越界报错。
  let position = match index {
    VInt(n) => n
    VNum(n) => n.to_int()
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "index",
        b: "number",
      })
  }
  match base {
    VArr(items) => {
      if position < 1 || position > items.length() {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: TypeMismatch,
          line,
          a: "index",
          b: "1..\{items.length()}",
        })
      }
      items[position - 1]
    }
    VStr(text) => {
      let chars : Array[String] = []
      for c in text {
        chars.push(c.to_string())
      }
      if position < 1 || position > chars.length() {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: TypeMismatch,
          line,
          a: "index",
          b: "1..\{chars.length()}",
        })
      }
      VStr(chars[position - 1])
    }
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "index",
        b: "list or text",
      })
  }
}

///|
/// 元素赋值：变量须持有列表；1 起、越界报错（解释轨 set_index_value 同语义）。
pub fn set_index_values(
  base : Value,
  index : Value,
  value : Value,
  line : Int,
) -> Unit raise ExecError {
  let items = match base {
    VArr(items) => items
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "index",
        b: "list",
      })
  }
  let position = match index {
    VInt(n) => n
    VNum(n) => n.to_int()
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "index",
        b: "number",
      })
  }
  if position < 1 || position > items.length() {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: TypeMismatch,
      line,
      a: "index",
      b: "1..\{items.length()}",
    })
  }
  items[position - 1] = value
}

///|
/// 列表长度（函数内建）。
pub fn list_length(
  _rt : Runtime,
  value : Value,
  line : Int,
) -> Value raise ExecError {
  match value {
    VArr(items) => VInt(items.length())
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "list_length",
        b: "list",
      })
  }
}

///|
/// 加入列表（命令内建）：第一个参数是变量名，列表按引用修改。
/// 审计与 set_text 同型：成功修改后记一条 OpCommand。
pub fn Runtime::append_list(
  self : Runtime,
  name : String,
  value : Value,
  op_name : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  ignore(op_name)
  let items = match self.vars.get(name) {
    Some(VArr(items)) => items
    Some(_) =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: name,
        b: "list",
      })
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: NotDeclared,
        line,
        a: name,
        b: "use declare first",
      })
  }
  items.push(value)
  self.record(line, OpCommand, detail)
}

///|
/// 注册用户函数（生成代码在装配期调用；同名覆盖无害——同一程序只会
/// 注册一次）。
pub fn Runtime::register_user_function(
  self : Runtime,
  name : String,
  function : UserFunction,
) -> Unit {
  self.user_functions[name] = function
}

///|
/// 是否注册了该名字的用户函数（调用分派的先内建、后自定义次序用）。
pub fn Runtime::has_user_function(self : Runtime, name : String) -> Bool {
  self.user_functions.contains(name)
}

///|
/// 调用用户函数：整帧隔离（vars/declared 快照恢复），参数按位绑定；
/// 深度上限与解释轨一致；Return 的 LoopReturn 控制信号在此边界捕获。
pub fn Runtime::call_user_function(
  self : Runtime,
  name : String,
  arg_values : Array[Value],
  line : Int,
) -> Value raise ExecError {
  let function = match self.user_functions.get(name) {
    Some(function) => function
    None => {
      ignore(unknown_builtin(name, line))
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: UnknownBuiltin,
        line,
        a: name,
        b: "function",
      })
    }
  }
  if self.call_depth >= MAX_USER_CALL_DEPTH {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: StepBudget,
      line,
      a: "call depth",
      b: "\{MAX_USER_CALL_DEPTH}",
    })
  }
  let saved_vars : Map[String, Value] = Map([], capacity=16)
  for key in self.vars.keys() {
    match self.vars.get(key) {
      Some(value) => saved_vars[key] = value
      None => ()
    }
  }
  let saved_declared : Array[String] = []
  for declared in self.declared {
    saved_declared.push(declared)
  }
  // 参数绑定由注册的闭包完成（只有它持有 IR 参数名）；帧隔离在这里。
  self.call_depth = self.call_depth + 1
  let result = function(self, arg_values)
  self.call_depth = self.call_depth - 1
  self.vars = saved_vars
  self.declared = saved_declared
  result
}

///|
/// 广播（命令内建）：文案入总线队列，宿主事件收尾时排空到
/// on_broadcast 处理器（与解释轨同口径）。
pub fn Runtime::broadcast(
  self : Runtime,
  value : Value,
  line : Int,
) -> Unit raise ExecError {
  let text = as_text(value, "broadcast", line)
  self.broadcasts.push(text)
}

///|
pub fn bool_of(
  value : Value,
  role : String,
  line : Int,
) -> Bool raise ExecError {
  match value {
    VBool(flag) => flag
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: role,
        b: "bool",
      })
  }
}

///|
/// 加法的两轨同语义：两个数字相加，任何一侧是文本就按文本拼接。
pub fn add_values(left : Value, right : Value, line : Int) -> Value {
  ignore(line)
  match (left, right) {
    (VInt(a), VInt(b)) => VInt(a + b)
    (VNum(a), VNum(b)) => VNum(a + b)
    (VInt(a), VNum(b)) => VNum(a.to_double() + b)
    (VNum(a), VInt(b)) => VNum(a + b.to_double())
    _ => VStr(value_to_text(left) + value_to_text(right))
  }
}

///|
pub fn sub_values(
  left : Value,
  right : Value,
  line : Int,
) -> Value raise ExecError {
  match (left, right) {
    (VInt(a), VInt(b)) => VInt(a - b)
    (VNum(a), VNum(b)) => VNum(a - b)
    (VInt(a), VNum(b)) => VNum(a.to_double() - b)
    (VNum(a), VInt(b)) => VNum(a - b.to_double())
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "-",
        b: "numbers",
      })
  }
}

///|
pub fn mul_values(
  left : Value,
  right : Value,
  line : Int,
) -> Value raise ExecError {
  match (left, right) {
    (VInt(a), VInt(b)) => VInt(a * b)
    (VNum(a), VNum(b)) => VNum(a * b)
    (VInt(a), VNum(b)) => VNum(a.to_double() * b)
    (VNum(a), VInt(b)) => VNum(a * b.to_double())
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "*",
        b: "numbers",
      })
  }
}

///|
pub fn div_values(
  left : Value,
  right : Value,
  line : Int,
) -> Value raise ExecError {
  match (left, right) {
    // 整数 ÷ 整数 = 整数（向零截断）——与解释轨同语义
    (VInt(a), VInt(b)) =>
      if b == 0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        VInt(a / b)
      }
    (VNum(a), VNum(b)) =>
      if b == 0.0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        VNum(a / b)
      }
    (VInt(a), VNum(b)) =>
      if b == 0.0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        VNum(a.to_double() / b)
      }
    (VNum(a), VInt(b)) =>
      if b == 0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        VNum(a / b.to_double())
      }
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "/",
        b: "numbers",
      })
  }
}

///|
/// 相等比较：类型不同即 TypeMismatch（解释轨 values_equal 同口径）。
pub fn eq_values(
  left : Value,
  right : Value,
  line : Int,
) -> Value raise ExecError {
  match (left, right) {
    (VNum(a), VNum(b)) => VBool(a == b)
    (VInt(a), VInt(b)) => VBool(a == b)
    (VInt(a), VNum(b)) => VBool(a.to_double() == b)
    (VNum(a), VInt(b)) => VBool(a == b.to_double())
    (VStr(a), VStr(b)) => VBool(a == b)
    (VBool(a), VBool(b)) => VBool(a == b)
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "=",
        b: "same types",
      })
  }
}

///|
pub fn compare_values(
  left : Value,
  right : Value,
  op : String,
  line : Int,
) -> Value raise ExecError {
  let is_lt = op == "<"
  let is_gt = op == ">"
  let is_le = op == "<="
  let flag = match (left, right) {
    (VInt(a), VInt(b)) =>
      if is_lt {
        a < b
      } else if is_gt {
        a > b
      } else if is_le {
        a <= b
      } else {
        a >= b
      }
    (VNum(a), VNum(b)) =>
      if is_lt {
        a < b
      } else if is_gt {
        a > b
      } else if is_le {
        a <= b
      } else {
        a >= b
      }
    (VInt(a), VNum(b)) =>
      if is_lt {
        a.to_double() < b
      } else if is_gt {
        a.to_double() > b
      } else if is_le {
        a.to_double() <= b
      } else {
        a.to_double() >= b
      }
    (VNum(a), VInt(b)) =>
      if is_lt {
        a < b.to_double()
      } else if is_gt {
        a > b.to_double()
      } else if is_le {
        a <= b.to_double()
      } else {
        a >= b.to_double()
      }
    (VStr(a), VStr(b)) =>
      if is_lt {
        a < b
      } else if is_gt {
        a > b
      } else if is_le {
        a <= b
      } else {
        a >= b
      }
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "compare",
        b: "same types",
      })
  }
  VBool(flag)
}

///|
/// 取文本：控件当前文本（未记录的控件为空文本，同解释轨）。
pub fn get_text(rt : Runtime, control : String) -> Value {
  VStr(rt.texts.get(control).unwrap_or(""))
}

///|
/// 取数值：控件文本必须是数字文本，否则 TypeMismatch。
pub fn get_number(
  rt : Runtime,
  control : String,
  line : Int,
) -> Value raise ExecError {
  let text = rt.texts.get(control).unwrap_or("")
  match @studio_lang.text_to_number(text) {
    Some(n) => int_value(n)
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: control,
        b: "number text",
      })
  }
}

///|
pub fn to_text(value : Value) -> Value {
  VStr(value_to_text(value))
}

///|
pub fn as_text(
  value : Value,
  role : String,
  line : Int,
) -> String raise ExecError {
  match value {
    VUnit =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: role,
        b: "text",
      })
    other => value_to_text(other)
  }
}

///|
pub fn text_length(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VNum(as_text(value, role, line).length().to_double())
}

///|
/// 数值强制（与解释轨的二元运算同一口径）：`VNum` 直取、`VInt` 提升，
/// 其余报类型错。
pub fn as_number(
  value : Value,
  role : String,
  line : Int,
) -> Double raise ExecError {
  match value {
    VNum(n) => n
    VInt(n) => n.to_double()
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: role,
        b: "number",
      })
  }
}

///|
/// 取余（Scratch 语义：结果**非负**，且整数 % 整数 仍是整数）。
pub fn mod_value(
  left : Value,
  right : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  match (left, right) {
    (VInt(a), VInt(b)) =>
      if b == 0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        let raw = a % b
        VInt(if raw < 0 { raw + (if b < 0 { -b } else { b }) } else { raw })
      }
    (left, right) => {
      let a = as_number(left, role, line)
      let b = as_number(right, role, line)
      if b == 0.0 {
        raise ExecError::RuntimeError(ErrorDetails::{
          kind: DivideByZero,
          line,
          a: "",
          b: "",
        })
      } else {
        VNum(a - b * (a / b).floor())
      }
    }
  }
}

///|
/// 等待 N 秒：折算成 tick 数挂起（与解释轨同一语义，折算函数同源）。
pub fn wait_value(rt : Runtime, seconds : Double) -> Value {
  rt.wait_ticks = if seconds < 0.0 {
    1
  } else {
    let ticks = (seconds * 1000.0 / 30.0).ceil().to_int()
    if ticks < 1 {
      1
    } else {
      ticks
    }
  }
  VUnit
}

///|
/// 宿主每个 tick 调一次：等到了返回 `true`（可以继续）。
pub fn tick_wait(rt : Runtime) -> Bool {
  if rt.wait_ticks <= 0 {
    return true
  }
  rt.wait_ticks = rt.wait_ticks - 1
  rt.wait_ticks <= 0
}

///|
/// 停止全部：把运行时标成 `Stopped`。与解释轨同一语义（停止不是错误）。
pub fn stop_all(rt : Runtime) -> Value {
  rt.status = Stopped
  VUnit
}

///|
/// 平方根（牛顿迭代，与解释轨同一实现）。
pub fn sqrt_of(value : Double) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let mut guess = if value < 1.0 { 1.0 } else { value }
  let mut i = 0
  while i < 24 {
    guess = (guess + value / guess) / 2.0
    i = i + 1
  }
  guess
}

///|
/// 绝对值 / 向下取整 / 向上取整 / 平方根：都是**纯数值函数**，走同一个
/// 强制入口（`as_number`），与解释轨逐项对齐。
pub fn abs_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VNum(as_number(value, role, line).abs())
}

///|
pub fn floor_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VInt(as_number(value, role, line).floor().to_int())
}

///|
pub fn ceiling_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VInt((0.0 - (0.0 - as_number(value, role, line)).floor()).to_int())
}

///|
pub fn sqrt_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  let n = as_number(value, role, line)
  if n < 0.0 {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: TypeMismatch,
      line,
      a: role,
      b: "non-negative number",
    })
  }
  VNum(sqrt_of(n))
}

///|
/// 四舍五入到整数（.5 向上）。
pub fn round_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VInt((as_number(value, role, line) + 0.5).floor().to_int())
}

///|
pub fn contains(
  haystack : Value,
  needle : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VBool(as_text(haystack, role, line).contains(as_text(needle, role, line)))
}

///|
/// 随机数：xorshift 序列与解释轨逐位相同；上界 <=1 时恒为 1。
pub fn random(rt : Runtime, max : Value, line : Int) -> Value raise ExecError {
  let bound = match max {
    VNum(n) => n
    VInt(n) => n.to_double()
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "random bound",
        b: "number",
      })
  }
  rt.rng = rt.rng ^ ((rt.rng << 13) & 2147483647)
  rt.rng = rt.rng ^ (rt.rng >> 17)
  rt.rng = rt.rng ^ ((rt.rng << 5) & 2147483647)
  let span = bound.to_int()
  if span <= 1 {
    VInt(1)
  } else {
    VInt(rt.rng % span + 1)
  }
}

///|
pub fn row_count(rt : Runtime, control : String) -> Value {
  match rt.rows.get(control) {
    Some(items) => VInt(items.length())
    None => VInt(0)
  }
}

///|
/// 取行：1-based；越界/无控件返回空文本（同解释轨）。
pub fn row_at(
  rt : Runtime,
  control : String,
  index : Value,
  line : Int,
) -> Value raise ExecError {
  let position = match index {
    VNum(n) => n.to_int()
    VInt(n) => n
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "row_at index",
        b: "number",
      })
  }
  match rt.rows.get(control) {
    Some(items) =>
      if position >= 1 && position <= items.length() {
        VStr(items[position - 1])
      } else {
        VStr("")
      }
    None => VStr("")
  }
}

///|
/// 取所选行：0-based 选中下标；越界返回空文本。
pub fn selected_row(rt : Runtime, control : String) -> Value {
  let position = rt.selections.get(control).unwrap_or(0)
  match rt.rows.get(control) {
    Some(items) =>
      if position >= 0 && position < items.length() {
        VStr(items[position])
      } else {
        VStr("")
      }
    None => VStr("")
  }
}

///|
pub fn Runtime::set_text(
  self : Runtime,
  control : String,
  value : Value,
  role : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  self.texts[control] = as_text(value, role, line)
  self.record(line, OpCommand, detail)
}

///|
pub fn Runtime::append_row(
  self : Runtime,
  control : String,
  value : Value,
  role : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  let text = as_text(value, role, line)
  let copied : Array[String] = []
  match self.rows.get(control) {
    Some(existing) =>
      for item in existing {
        copied.push(item)
      }
    None => ()
  }
  copied.push(text)
  self.rows[control] = copied
  self.record(line, OpCommand, detail)
}

///|
pub fn Runtime::message_box(
  self : Runtime,
  value : Value,
  role : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  self.messages.push(as_text(value, role, line))
  self.record(line, OpMessage, detail)
}

///|
/// 提交数据闸门：确认前零真实动作；有应答就按 FIFO 消费并落审计。
pub fn Runtime::submit_data(
  self : Runtime,
  target : String,
  payload : Value,
  role : String,
  line : Int,
  detail : String,
) -> Value raise ExecError {
  let text = as_text(payload, role, line)
  if self.gate_cursor < self.gate_answers.length() {
    let decision = self.gate_answers[self.gate_cursor]
    self.gate_cursor = self.gate_cursor + 1
    let outcome = if decision { "confirmed" } else { "rejected" }
    self.record(line, OpGate, "\{detail} -> \{outcome}")
    VUnit
  } else {
    self.gate = Some(Gate::{ kind: Submit, prompt: target, payload: text, })
    raise ExecError::GateHalt
  }
}

///|
/// 询问闸门：返回人的决定；未应答时先停在闸门前。
pub fn Runtime::ask(
  self : Runtime,
  question : Value,
  role : String,
  line : Int,
  detail : String,
) -> Value raise ExecError {
  let prompt = as_text(question, role, line)
  if self.gate_cursor < self.gate_answers.length() {
    let decision = self.gate_answers[self.gate_cursor]
    // **`询问` 的返回值是回答文本**（Scratch 语义），与解释轨 `eval_gate`
    // 完全一致：取同一游标位置的文本；空则回退最近一次回答。
    let answer = if self.gate_cursor < self.gate_answer_texts.length() {
      self.gate_answer_texts[self.gate_cursor]
    } else {
      ""
    }
    self.gate_cursor = self.gate_cursor + 1
    let outcome = if decision { "confirmed" } else { "rejected" }
    self.record(line, OpGate, "\{detail} -> \{outcome}")
    if answer == "" {
      VStr(self.last_answer)
    } else {
      VStr(answer)
    }
  } else {
    self.gate = Some(Gate::{ kind: Ask, prompt, payload: "", })
    raise ExecError::GateHalt
  }
}

///|
/// 两轨共用的审计视图（导出 runner 与 Studio 都按同一顺序读取）。
pub fn audit_lines(rt : Runtime) -> Array[String] {
  rt.audit.map(r => "\{r.line}| \{r.detail}")
}

///|
/// 不等比较：值相等语义要求类型相同，再取反。
pub fn neq_values(
  left : Value,
  right : Value,
  line : Int,
) -> Value raise ExecError {
  match eq_values(left, right, line) {
    VBool(flag) => VBool(!flag)
    other => other
  }
}

///|
/// 逻辑取反（解释轨 `not` 语义）。
pub fn not_value(value : Value, line : Int) -> Value raise ExecError {
  VBool(!bool_of(value, "not operand", line))
}

///|
/// 数值取负（解释轨 `-x` 语义）。
pub fn neg_value(value : Value, line : Int) -> Value raise ExecError {
  match value {
    VNum(n) => VNum(-n)
    VInt(n) => VInt(-n)
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: "negation operand",
        b: "number",
      })
  }
}

///|
/// 短路 `and`：左侧必须逻辑值；已假则不求右侧（右侧可能是闸门）。
pub fn and_values(
  left : (Runtime) -> Value raise ExecError,
  right : (Runtime) -> Value raise ExecError,
  rt : Runtime,
  line : Int,
) -> Value raise ExecError {
  let l = bool_of(left(rt), "logic operand", line)
  if !l {
    return VBool(false)
  }
  VBool(bool_of(right(rt), "logic operand", line))
}

///|
/// 短路 `or`：左侧必须逻辑值；已真则不求右侧。
pub fn or_values(
  left : (Runtime) -> Value raise ExecError,
  right : (Runtime) -> Value raise ExecError,
  rt : Runtime,
  line : Int,
) -> Value raise ExecError {
  let l = bool_of(left(rt), "logic operand", line)
  if l {
    return VBool(true)
  }
  VBool(bool_of(right(rt), "logic operand", line))
}

///|

///|
/// 构造枚举值（M5-5d）。
pub fn make_enum(enum_name : String, case_name : String) -> Value {
  VEnum(enum_name, case_name)
}

///|
/// 读取枚举值的情况名（M5-5d）：匹配分派用；非枚举值报运行时错误。
pub fn enum_case(value : Value, line : Int) -> String raise ExecError {
  match value {
    VEnum(_enum_name, case_name) => case_name
    _ =>
      raise RuntimeError({
        kind: UnknownBuiltin,
        line,
        a: "匹配对象",
        b: "应为枚举值",
      })
  }
}

///|
/// 读取 struct 值的字段(M5-5c)。纯值级查找，不需要运行时状态。
pub fn get_field(
  value : Value,
  field : String,
  line : Int,
) -> Value raise ExecError {
  match value {
    VStruct(fields) =>
      match fields.get(field) {
        Some(v) => v
        None =>
          raise RuntimeError({ kind: UnknownBuiltin, line, a: field, b: "", })
      }
    _ =>
      raise RuntimeError({
        kind: UnknownBuiltin,
        line,
        a: field,
        b: "not a struct value",
      })
  }
}

///|
/// 插入列表（G7.1）：1-based,1..=长度+1；按变量引用原位修改。
pub fn Runtime::insert_list(
  self : Runtime,
  name : String,
  index_value : Value,
  value : Value,
  op_name : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  ignore(op_name)
  ignore(detail)
  let items = match self.vars.get(name) {
    Some(VArr(items)) => items
    Some(_) =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: name,
        b: "list",
      })
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: NotDeclared,
        line,
        a: name,
        b: "use declare first",
      })
  }
  let index = as_number(index_value, "insert_list", line).to_int()
  if index < 1 || index > items.length() + 1 {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: TypeMismatch,
      line,
      a: "insert_list",
      b: "1..=length+1",
    })
  }
  items.insert(index - 1, value)
}

///|
/// 删除列表（G7.1）：1-based。
pub fn Runtime::remove_list(
  self : Runtime,
  name : String,
  index_value : Value,
  op_name : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  ignore(op_name)
  ignore(detail)
  let items = match self.vars.get(name) {
    Some(VArr(items)) => items
    Some(_) =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: name,
        b: "list",
      })
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: NotDeclared,
        line,
        a: name,
        b: "use declare first",
      })
  }
  let index = as_number(index_value, "remove_list", line).to_int()
  if index < 1 || index > items.length() {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: TypeMismatch,
      line,
      a: "remove_list",
      b: "1..=length",
    })
  }
  let tail : Array[Value] = []
  for i, item in items {
    if i != index - 1 {
      tail.push(item)
    }
  }
  items.clear()
  for item in tail {
    items.push(item)
  }
}

///|
/// 替换列表（G7.1）：1-based。
pub fn Runtime::replace_list(
  self : Runtime,
  name : String,
  index_value : Value,
  value : Value,
  op_name : String,
  line : Int,
  detail : String,
) -> Unit raise ExecError {
  ignore(op_name)
  ignore(detail)
  let items = match self.vars.get(name) {
    Some(VArr(items)) => items
    Some(_) =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: TypeMismatch,
        line,
        a: name,
        b: "list",
      })
    None =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: NotDeclared,
        line,
        a: name,
        b: "use declare first",
      })
  }
  let index = as_number(index_value, "replace_list", line).to_int()
  if index < 1 || index > items.length() {
    raise ExecError::RuntimeError(ErrorDetails::{
      kind: TypeMismatch,
      line,
      a: "replace_list",
      b: "1..=length",
    })
  }
  items[index - 1] = value
}

///|
/// 查找列表（G7.1）：按规范文本逐项比对,返回 1-based 下标,未命中 0。
pub fn index_of_list(
  rt : Runtime,
  list_value : Value,
  wanted : Value,
  role : String,
  line : Int,
) -> Value {
  ignore(role)
  ignore(line)
  let wanted_text = value_to_text(wanted)
  let items = match list_value {
    VArr(items) => items
    _ => []
  }
  let mut found = 0
  let mut i = 0
  for item in items {
    i = i + 1
    if value_to_text(item) == wanted_text {
      found = i
      break
    }
  }
  rt.last_index_result(found)
}

///|
fn Runtime::last_index_result(_self : Runtime, found : Int) -> Value {
  VInt(found)
}

///|
/// 连接（G7.1）：两侧按 value_to_text 规范转文本后拼接。
pub fn join_value(
  left : Value,
  right : Value,
  role : String,
  line : Int,
) -> Value {
  ignore(role)
  ignore(line)
  VStr(value_to_text(left) + value_to_text(right))
}

///|
/// 取字符（G7.1）：1-based 字符索引（与 取长度 按字符计同口径），
/// 越界返回空文本。
pub fn letter_value(
  value : Value,
  index_value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  ignore(role)
  let text = value_to_text(value)
  let index = as_number(index_value, "letter", line).to_int()
  let mut seen = 0
  let mut found = ""
  if index >= 1 {
    for ch in text {
      seen = seen + 1
      if seen == index {
        found = ch.to_string()
        break
      }
    }
  }
  VStr(found)
}

///|
/// 大写（G7.1）。
pub fn upper_value(
  value : Value,
  role : String,
  line : Int,
) -> Value {
  ignore(role)
  ignore(line)
  VStr(value_to_text(value).to_upper())
}

///|
/// 小写（G7.1）。
pub fn lower_value(
  value : Value,
  role : String,
  line : Int,
) -> Value {
  ignore(role)
  ignore(line)
  VStr(value_to_text(value).to_lower())
}

///|
/// 正弦（G7.1）：与解释轨 sin_of 逐字同实现——两轨同一位型才过差分门。
fn sin_value_inner(value : Double) -> Double {
  let pi2 = 6.283185307179586
  let mut x = value - (value / pi2).floor() * pi2
  if x > 3.141592653589793 {
    x = x - pi2
  }
  let mut sum = 0.0
  let mut term = x
  let mut k = 1
  while k <= 25 {
    sum = sum + term
    term = -term * x * x / ((k + 1).to_double() * (k + 2).to_double())
    k = k + 2
  }
  sum
}

///|
pub fn sin_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VNum(sin_value_inner(as_number(value, role, line)))
}

///|
pub fn cos_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VNum(sin_value_inner(as_number(value, role, line) + 1.5707963267948966))
}

///|
/// 自然对数（G7.1）：区间归约到 [1,2) 后用 atanh 级数。与解释轨逐字同实现。
fn ln_inner(value : Double) -> Double {
  if value <= 0.0 {
    return 0.0
  }
  let ln2 = 0.6931471805599453
  let mut m = value
  let mut k = 0
  while m >= 2.0 {
    m = m / 2.0
    k = k + 1
  }
  while m < 1.0 {
    m = m * 2.0
    k = k - 1
  }
  let z = (m - 1.0) / (m + 1.0)
  let z2 = z * z
  let mut sum = 0.0
  let mut term = z
  let mut n = 1
  while n <= 17 {
    sum = sum + term / n.to_double()
    term = term * z2
    n = n + 2
  }
  2.0 * sum + k.to_double() * ln2
}

///|
pub fn ln_value(
  value : Value,
  role : String,
  line : Int,
) -> Value raise ExecError {
  VNum(ln_inner(as_number(value, role, line)))
}
