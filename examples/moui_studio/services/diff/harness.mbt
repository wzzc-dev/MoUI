///|
/// 双轨差分硬门：同一份源码、同一个程序，解释轨（`domain/studio_lang`
/// 指令机）与编译轨（`services/compiled_runtime` lower 面）必须给出
/// 完全相同的外部可观察结果。
///
/// 为什么存在：编译轨的语义来源不是第二套实现，而是与解释轨共享的
/// 语句级规范。任何一条语句的分支、行号、审计文本、闸门时序一旦分叉，
/// 本套件就在**逐项断言**上失败——没有「已知差异」白名单，不一致即 P0。
///
/// 比较面（全部逐项）：
///   1. 控件文本终态
///   2. 变量终态（排除解释轨内部的 `@iN` / `@iN#n` 计数槽）
///   3. 审计序列 `(line, op, detail)`——op 用同一张序号表比较
///   4. 闸门状态、闸门 (kind, prompt, payload)
///   5. 运行终态（完成 / 等待闸门 / 失败）
///   6. 失败时的错误类型（公共子集）与行号
///
/// 输入统一是「渲染后的源码文本」：两种语言各渲染一次，各自解析回
/// 带 Trace 的语句序列再分别喂给两条轨。这样差分同时覆盖
/// 语言关键字映射与执行语义。

///|
/// 一次运行的外部可观察快照（两轨归一化到同一形状后比较）。
pub(all) struct Observation {
  status : String
  gate_kind : String
  gate_prompt : String
  gate_payload : String
  error_kind : String
  error_line : Int
  texts : Array[(String, String)]
  vars : Array[(String, String)]
  audit : Array[String]
}

///|
/// 差分结果：逐项不等就记一条人类可读的失败原因。
pub(all) struct DiffReport {
  case_name : String
  mismatches : Array[String]
}

///|
/// 内部计数槽不算外部可观察状态（解释轨用它实现计次循环，编译轨用
/// 闭包计数器，二者实现不同但语义等价）。
fn is_internal_slot(name : String) -> Bool {
  name.has_prefix("@i")
}

///|
/// 值 → 规范文本（数字用领域内核的 number_to_text，两轨同口径）。
pub fn interp_value_text(value : @studio_lang.Value) -> String {
  @studio_lang.value_to_text(value)
}

///|
pub fn compiled_value_text(value : @compiled_runtime.Value) -> String {
  @compiled_runtime.value_to_text(value)
}

///|
/// 审计操作类型序号：两轨 StepOp 枚举同构，用同一张表归一化。
pub fn interp_op_rank(op : @studio_lang.StepOp) -> Int {
  match op {
    @studio_lang.OpAssign => 0
    @studio_lang.OpMessage => 1
    @studio_lang.OpGate => 2
    @studio_lang.OpCommand => 3
    @studio_lang.OpCondition => 4
    @studio_lang.OpLoop => 5
  }
}

///|
pub fn compiled_op_rank(op : @compiled_runtime.StepOp) -> Int {
  match op {
    @compiled_runtime.OpAssign => 0
    @compiled_runtime.OpMessage => 1
    @compiled_runtime.OpGate => 2
    @compiled_runtime.OpCommand => 3
    @compiled_runtime.OpCondition => 4
    @compiled_runtime.OpLoop => 5
  }
}

///|
/// 错误类型归一化：只有两边都存在的公共子集参与比较；解释轨独有
/// 的解析期错误不会出现在运行期观察里。
pub fn interp_error_kind(kind : @studio_lang.LangErrorKind) -> String {
  match kind {
    @studio_lang.TypeMismatch => "type_mismatch"
    @studio_lang.NotDeclared => "not_declared"
    @studio_lang.DivideByZero => "divide_by_zero"
    @studio_lang.BadLoopCount => "bad_loop_count"
    @studio_lang.UnknownBuiltin => "unknown_builtin"
    @studio_lang.StepBudget => "step_budget"
    other => "other:\{lang_error_kind_name(other)}"
  }
}

///|
/// 解释轨独有错误类型的中性名（不参与公共子集比较，只用于失败文案）。
fn lang_error_kind_name(kind : @studio_lang.LangErrorKind) -> String {
  match kind {
    @studio_lang.UnterminatedString => "unterminated_string"
    @studio_lang.BadNumber => "bad_number"
    @studio_lang.ExpectKeyword => "expect_keyword"
    @studio_lang.UnexpectedToken => "unexpected_token"
    @studio_lang.ReservedWord => "reserved_word"
    @studio_lang.MissingEnd => "missing_end"
    @studio_lang.UnknownName => "unknown_name"
    @studio_lang.ArityMismatch => "arity_mismatch"
    @studio_lang.BreakOutsideLoop => "break_outside_loop"
    @studio_lang.TypeMismatch => "type_mismatch"
    @studio_lang.NotDeclared => "not_declared"
    @studio_lang.DivideByZero => "divide_by_zero"
    @studio_lang.BadLoopCount => "bad_loop_count"
    @studio_lang.UnknownBuiltin => "unknown_builtin"
    @studio_lang.StepBudget => "step_budget"
  }
}

///|
pub fn compiled_error_kind(kind : @compiled_runtime.ErrorKind) -> String {
  match kind {
    @compiled_runtime.TypeMismatch => "type_mismatch"
    @compiled_runtime.NotDeclared => "not_declared"
    @compiled_runtime.DivideByZero => "divide_by_zero"
    @compiled_runtime.BadLoopCount => "bad_loop_count"
    @compiled_runtime.UnknownBuiltin => "unknown_builtin"
    @compiled_runtime.StepBudget => "step_budget"
  }
}

///|
/// 闸门类型归一化。
fn interp_gate_kind(kind : @studio_lang.GateKind) -> String {
  match kind {
    @studio_lang.Submit => "submit"
    @studio_lang.Ask => "ask"
  }
}

///|
fn compiled_gate_kind(kind : @compiled_runtime.GateKind) -> String {
  match kind {
    @compiled_runtime.Submit => "submit"
    @compiled_runtime.Ask => "ask"
  }
}

///|
/// 运行状态归一化。
fn interp_status(status : @studio_lang.RunStatus) -> String {
  match status {
    @studio_lang.Running => "running"
    @studio_lang.WaitingGate => "waiting_gate"
    @studio_lang.Completed => "completed"
    @studio_lang.Failed => "failed"
  }
}

///|
fn compiled_status(status : @compiled_runtime.RunStatus) -> String {
  match status {
    @compiled_runtime.Running => "running"
    @compiled_runtime.WaitingGate => "waiting_gate"
    @compiled_runtime.Completed => "completed"
    @compiled_runtime.Failed => "failed"
  }
}

///|
/// 键值表归一化：按键排序，排除内部槽。
fn sorted_text_pairs(source : Map[String, String]) -> Array[(String, String)] {
  let sorted : Array[String] = []
  for key in source.keys() {
    if !is_internal_slot(key) {
      sorted.push(key)
    }
  }
  sorted.sort_by((left, right) => left.lexical_compare(right))
  let pairs : Array[(String, String)] = []
  for key in sorted {
    pairs.push((key, source.get(key).unwrap_or("")))
  }
  pairs
}

///|
fn sorted_interp_var_pairs(
  source : Map[String, @studio_lang.Value],
) -> Array[(String, String)] {
  let sorted : Array[String] = []
  for key in source.keys() {
    if !is_internal_slot(key) {
      sorted.push(key)
    }
  }
  sorted.sort_by((left, right) => left.lexical_compare(right))
  let pairs : Array[(String, String)] = []
  for key in sorted {
    let text = match source.get(key) {
      Some(value) => interp_value_text(value)
      None => "<missing>"
    }
    pairs.push((key, text))
  }
  pairs
}

///|
fn sorted_compiled_var_pairs(
  source : Map[String, @compiled_runtime.Value],
) -> Array[(String, String)] {
  let sorted : Array[String] = []
  for key in source.keys() {
    if !is_internal_slot(key) {
      sorted.push(key)
    }
  }
  sorted.sort_by((left, right) => left.lexical_compare(right))
  let pairs : Array[(String, String)] = []
  for key in sorted {
    let text = match source.get(key) {
      Some(value) => compiled_value_text(value)
      None => "<missing>"
    }
    pairs.push((key, text))
  }
  pairs
}

///|
/// 解释轨观察：跑到终止态；遇到闸门按给定决定逐次应答。
pub fn observe_interp(
  body : Array[@studio_lang.TracedStmt],
  program : @ir.StudioProgram,
  gate_answers : Array[Bool],
  seed? : Int = 20260927,
) -> Observation {
  let state = @studio_lang.start_run(
    body,
    @studio_lang.initial_texts(program),
    @studio_lang.initial_values(program),
    @studio_lang.initial_rows(program),
    seed~,
  )
  @studio_lang.run_to_end(state)
  let mut answer_index = 0
  while state.status is @studio_lang.WaitingGate &&
        answer_index < gate_answers.length() {
    @studio_lang.answer_gate(state, gate_answers[answer_index])
    @studio_lang.run_to_end(state)
    answer_index = answer_index + 1
  }
  let audit : Array[String] = []
  for record in state.audit {
    audit.push("\{record.line}|\{interp_op_rank(record.op)}|\{record.detail}")
  }
  let (gate_kind, gate_prompt, gate_payload) = match state.gate {
    Some(gate) => (interp_gate_kind(gate.kind), gate.prompt, gate.payload)
    None => ("", "", "")
  }
  let (error_kind, error_line) = match state.error {
    Some(error) => (interp_error_kind(error.kind()), error.line())
    None => ("", 0)
  }
  {
    status: interp_status(state.status),
    gate_kind,
    gate_prompt,
    gate_payload,
    error_kind,
    error_line,
    texts: sorted_text_pairs(state.texts),
    vars: sorted_interp_var_pairs(state.vars),
    audit,
  }
}

///|
/// 编译轨观察：同一份 Trace → 同一程序初值 → lower 执行面。
pub fn observe_compiled(
  body : Array[@studio_lang.TracedStmt],
  program : @ir.StudioProgram,
  gate_answers : Array[Bool],
  seed? : Int = 20260927,
) -> Observation {
  let runtime = @compiled_runtime.runtime_for_program(program)
  let handler = @compiled_runtime.lower_traced_handler(body)
  // 随机序列与解释轨共用同一 seed 口径；runtime_for_program 不可传 seed，
  // 这里显式对齐（两轨常量相同，见 compiled_runtime.RANDOM_SEED）。
  ignore(seed)
  ignore(@compiled_runtime.run_handler(runtime, handler))
  let mut answer_index = 0
  while runtime.status is @compiled_runtime.WaitingGate &&
        answer_index < gate_answers.length() {
    ignore(@compiled_runtime.answer_gate(runtime, gate_answers[answer_index]))
    answer_index = answer_index + 1
  }
  let audit : Array[String] = []
  for record in runtime.audit {
    audit.push("\{record.line}|\{compiled_op_rank(record.op)}|\{record.detail}")
  }
  let (gate_kind, gate_prompt, gate_payload) = match runtime.gate {
    Some(gate) => (compiled_gate_kind(gate.kind), gate.prompt, gate.payload)
    None => ("", "", "")
  }
  let (error_kind, error_line) = match runtime.error {
    Some(error) => (compiled_error_kind(error.kind), error.line)
    None => ("", 0)
  }
  {
    status: compiled_status(runtime.status),
    gate_kind,
    gate_prompt,
    gate_payload,
    error_kind,
    error_line,
    texts: sorted_text_pairs(runtime.texts),
    vars: sorted_compiled_var_pairs(runtime.vars),
    audit,
  }
}

///|
/// 逐项比较两次观察，返回全部差异（空数组 = 通过）。
pub fn compare(
  case_name : String,
  interp : Observation,
  compiled : Observation,
) -> DiffReport {
  let mismatches : Array[String] = []
  let check = fn(field : String, left : String, right : String) {
    if left != right {
      mismatches.push("\{field}: interpret=\{left} compiled=\{right}")
    }
  }
  check("status", interp.status, compiled.status)
  check("gate_kind", interp.gate_kind, compiled.gate_kind)
  check("gate_prompt", interp.gate_prompt, compiled.gate_prompt)
  check("gate_payload", interp.gate_payload, compiled.gate_payload)
  check("error_kind", interp.error_kind, compiled.error_kind)
  check(
    "error_line",
    interp.error_line.to_string(),
    compiled.error_line.to_string(),
  )
  check("texts", pairs_debug(interp.texts), pairs_debug(compiled.texts))
  check("vars", pairs_debug(interp.vars), pairs_debug(compiled.vars))
  check(
    "audit_length",
    interp.audit.length().to_string(),
    compiled.audit.length().to_string(),
  )
  let mut index = 0
  while index < interp.audit.length() && index < compiled.audit.length() {
    check("audit[\{index}]", interp.audit[index], compiled.audit[index])
    index = index + 1
  }
  DiffReport::{ case_name, mismatches, }
}

///|
/// 键值对的可读展开（失败信息里直接给出两侧完整状态）。
fn pairs_debug(pairs : Array[(String, String)]) -> String {
  let buf = StringBuilder()
  buf.write_string("{")
  let mut first = true
  for pair in pairs {
    if !first {
      buf.write_string(", ")
    }
    buf.write_string("\{pair.0}=\{pair.1}")
    first = false
  }
  buf.write_string("}")
  buf.to_string()
}

///|
/// 单例差分：渲染（该语言）→ 解析 → 两轨跑 → 比较。
pub fn diff_case(
  name : String,
  program : @ir.StudioProgram,
  handler : @ir.Handler,
  language : @studio_lang.Language,
  gate_answers : Array[Bool],
) -> DiffReport {
  let source = @studio_lang.render_handler(handler, language)
  let body = match @studio_lang.parse_handler_body(source, language) {
    Ok(body) => body
    Err(error) =>
      return DiffReport::{
        case_name: name,
        mismatches: [
          "parse failed on rendered source (" +
          language.tag() +
          "): line " +
          error.line().to_string(),
        ],
      }
  }
  compare(
    name,
    observe_interp(body, program, gate_answers),
    observe_compiled(body, program, gate_answers),
  )
}
