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
  VStr(String)
  VBool(Bool)
  VUnit
}

///|
/// 值 → 文本（数字形式复用领域内核的 number_to_text）。
pub fn value_to_text(value : Value) -> String {
  match value {
    VNum(n) => @studio_lang.number_to_text(n)
    VStr(text) => text
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
  mut error : ErrorDetails?
  mut steps : Int
  max_steps : Int
  mut rng : Int
  mut gate_answers : Array[Bool]
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
}

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
      Some(n) => vars[pair.0] = VNum(n)
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
    error: None,
    steps: 0,
    max_steps: MAX_STEPS,
    rng: seed_rng(RANDOM_SEED),
    gate_answers: [],
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
  if !(rt.status is WaitingGate) {
    return rt.status
  }
  rt.gate_answers.push(decision)
  rt.gate = None
  rt.status = Running
  attempt(rt)
  rt.status
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
pub fn runtime_for_program(program : @ir.StudioProgram) -> Runtime {
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
  new_runtime(texts, rows, variables)
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
    _ =>
      raise ExecError::RuntimeError(ErrorDetails::{
        kind: BadLoopCount,
        line,
        a: "",
        b: "",
      })
  }
  let mut index = 1.0
  while index <= count.to_double() {
    if loop_var != "" {
      self.set(loop_var, VNum(index))
    }
    self.record_iteration(index.to_int(), line)
    let mut stop = false
    drive(self, body) catch {
      LoopBreak => stop = true
      e => raise e
    }
    if stop {
      return
    }
    index = index + 1.0
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
    (VNum(a), VNum(b)) => VNum(a + b)
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
    (VNum(a), VNum(b)) => VNum(a - b)
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
    (VNum(a), VNum(b)) => VNum(a * b)
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
    Some(n) => VNum(n)
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
    VNum(1.0)
  } else {
    VNum((rt.rng % span).to_double() + 1.0)
  }
}

///|
pub fn row_count(rt : Runtime, control : String) -> Value {
  match rt.rows.get(control) {
    Some(items) => VNum(items.length().to_double())
    None => VNum(0.0)
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
    self.gate_cursor = self.gate_cursor + 1
    let outcome = if decision { "confirmed" } else { "rejected" }
    self.record(line, OpGate, "\{detail} -> \{outcome}")
    VBool(decision)
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
