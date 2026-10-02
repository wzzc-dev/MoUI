///|
/// 提案校验链与应用（纯函数）：schema → IR 不变量 → 语言层 →
/// 可读性 → 预算。任何一环失败，整单拒绝并给出全部原因。
/// apply 前先在副本上验证，验证通过才允许进入待采纳状态。

///|
/// 无语义命名 blocklist：AI 提案禁止 `a1`/`tmp`/`x` 式命名（可读性契约）。
fn junk_names() -> Array[String] {
  [
    "a", "b", "c", "x", "y", "z", "i", "j", "k", "n", "m", "tmp", "temp", "foo",
    "bar", "baz", "test", "data", "value", "obj", "a1", "a2", "b1", "x1", "y1", "var1",
    "var2", "t1", "t2", "s1",
  ]
}

///|
fn is_junk_name(name : String) -> Bool {
  junk_names().contains(name.to_lower())
}

///|
/// 可读性：双语 note 必填；命名必须自解释。
fn check_readability(proposal : ProposalV1) -> Array[ProposalError] {
  let errors : Array[ProposalError] = []
  for handler in proposal.handlers_add {
    if handler.note_zh.trim() == "" || handler.note_en.trim() == "" {
      errors.push(
        Readability(
          "handler.\{handler.control_name}.\{handler.event.tag()}.note",
        ),
      )
    }
  }
  for handler in proposal.handlers_update {
    if handler.note_zh.trim() == "" || handler.note_en.trim() == "" {
      errors.push(
        Readability(
          "handler.\{handler.control_name}.\{handler.event.tag()}.note",
        ),
      )
    }
  }
  for control in proposal.controls_add {
    if is_junk_name(control.name) {
      errors.push(Readability("control.\{control.name}"))
    }
  }
  for control in proposal.controls_update {
    if is_junk_name(control.name) {
      errors.push(Readability("control.\{control.name}"))
    }
  }
  for variable in proposal.variables_add {
    if is_junk_name(variable.name) {
      errors.push(Readability("variable.\{variable.name}"))
    }
  }
  for variable in proposal.variables_update {
    if is_junk_name(variable.name) {
      errors.push(Readability("variable.\{variable.name}"))
    }
  }
  errors
}

///|
/// 完整校验链：应用到副本后逐层检查。空数组 = 可采纳。
pub fn validate_proposal(
  program : @ir.StudioProgram,
  proposal : ProposalV1,
) -> Array[ProposalError] {
  let errors : Array[ProposalError] = []
  if proposal.version != PROPOSAL_VERSION {
    errors.push(BadVersion(proposal.version))
  }
  if proposal.summary_zh.trim() == "" || proposal.summary_en.trim() == "" {
    errors.push(Readability("summary"))
  }
  let next = apply_proposal(program, proposal)
  for issue in @ir.validate_program(next) {
    errors.push(Structural(issue))
  }
  for issue in @studio_lang.validate_program_language(next) {
    errors.push(LanguageIssue(issue.a()))
  }
  for issue in check_readability(proposal) {
    errors.push(issue)
  }
  errors
}

///|
/// 应用提案到程序（纯函数；调用方必须先过 validate_proposal）。
pub fn apply_proposal(
  program : @ir.StudioProgram,
  proposal : ProposalV1,
) -> @ir.StudioProgram {
  let controls : Array[@ir.Control] = []
  for control in program.controls {
    controls.push(control)
  }
  let variables : Array[@ir.Variable] = []
  for variable in program.variables {
    variables.push(variable)
  }
  let handlers : Array[@ir.Handler] = []
  for handler in program.handlers {
    handlers.push(handler)
  }
  let window = match proposal.window {
    Some(next_window) => next_window
    None => program.window
  }
  let mut next = @ir.StudioProgram::{
    version: program.version,
    window,
    controls,
    variables,
    handlers,
    functions: program.functions,
  }
  // 先删后改再增：remove → update → add
  for name in proposal.controls_remove {
    next = remove_control(next, name)
  }
  for control in proposal.controls_update {
    next = replace_control(next, control)
  }
  for control in proposal.controls_add {
    let assigned = if control.id > 0 &&
      !next.controls.any(existing => existing.id == control.id) {
      control
    } else {
      @ir.Control::{ ..control, id: @ir.next_control_id(next), }
    }
    next.controls.push(assigned)
  }
  for name in proposal.variables_remove {
    next = remove_variable(next, name)
  }
  for variable in proposal.variables_update {
    next = replace_variable(next, variable)
  }
  for variable in proposal.variables_add {
    if next.variables.any(existing => existing.name == variable.name) {
      continue
    }
    next.variables.push(variable)
  }
  for reference in proposal.handlers_remove {
    next = remove_handler(next, reference.control, reference.event)
  }
  for handler in proposal.handlers_update {
    next = replace_handler(next, handler)
  }
  for handler in proposal.handlers_add {
    next = replace_handler(next, handler)
  }
  next
}

///|
fn remove_control(
  program : @ir.StudioProgram,
  name : String,
) -> @ir.StudioProgram {
  let kept : Array[@ir.Control] = []
  for control in program.controls {
    if control.name != name {
      kept.push(control)
    }
  }
  let handlers : Array[@ir.Handler] = []
  for handler in program.handlers {
    if handler.control_name != name {
      handlers.push(handler)
    }
  }
  @ir.StudioProgram::{ ..program, controls: kept, handlers, }
}

///|
fn replace_control(
  program : @ir.StudioProgram,
  incoming : @ir.Control,
) -> @ir.StudioProgram {
  let controls : Array[@ir.Control] = []
  let mut found = false
  for control in program.controls {
    if control.name == incoming.name {
      controls.push(incoming)
      found = true
    } else {
      controls.push(control)
    }
  }
  if !found {
    controls.push(incoming)
  }
  @ir.StudioProgram::{ ..program, controls, }
}

///|
fn remove_variable(
  program : @ir.StudioProgram,
  name : String,
) -> @ir.StudioProgram {
  let kept : Array[@ir.Variable] = []
  for variable in program.variables {
    if variable.name != name {
      kept.push(variable)
    }
  }
  @ir.StudioProgram::{ ..program, variables: kept, }
}

///|
fn replace_variable(
  program : @ir.StudioProgram,
  incoming : @ir.Variable,
) -> @ir.StudioProgram {
  let variables : Array[@ir.Variable] = []
  let mut found = false
  for variable in program.variables {
    if variable.name == incoming.name {
      variables.push(incoming)
      found = true
    } else {
      variables.push(variable)
    }
  }
  if !found {
    variables.push(incoming)
  }
  @ir.StudioProgram::{ ..program, variables, }
}

///|
fn remove_handler(
  program : @ir.StudioProgram,
  control : String,
  event : String,
) -> @ir.StudioProgram {
  let kept : Array[@ir.Handler] = []
  for handler in program.handlers {
    if handler.control_name == control && handler.event.tag() == event {
      continue
    }
    kept.push(handler)
  }
  @ir.StudioProgram::{ ..program, handlers: kept, }
}

///|
fn replace_handler(
  program : @ir.StudioProgram,
  incoming : @ir.Handler,
) -> @ir.StudioProgram {
  let handlers : Array[@ir.Handler] = []
  let mut found = false
  for handler in program.handlers {
    if handler.control_name == incoming.control_name &&
      handler.event.tag() == incoming.event.tag() {
      handlers.push(incoming)
      found = true
    } else {
      handlers.push(handler)
    }
  }
  if !found {
    handlers.push(incoming)
  }
  @ir.StudioProgram::{ ..program, handlers, }
}

///|
/// diff 操作（界面层本地化标签；path 是语言中立定位）。
pub(all) enum DiffOp {
  Added
  Changed
  Removed
}

///|
/// 字段级 diff 条目：采纳前用户逐项核对 AI 改了什么。
pub(all) struct DiffEntry {
  op : DiffOp
  path : String
  old_text : String
  new_text : String
}

///|
/// 计算提案相对当前程序的字段级 diff（纯函数，可预览可审计）。
pub fn proposal_diff(
  program : @ir.StudioProgram,
  proposal : ProposalV1,
) -> Array[DiffEntry] {
  let entries : Array[DiffEntry] = []
  match proposal.window {
    Some(window) =>
      if window.title != program.window.title ||
        window.width != program.window.width ||
        window.height != program.window.height {
        entries.push(DiffEntry::{
          op: Changed,
          path: "window",
          old_text: program.window.title,
          new_text: window.title,
        })
      }
    None => ()
  }
  for name in proposal.controls_remove {
    entries.push(DiffEntry::{
      op: Removed,
      path: "control.\{name}",
      old_text: name,
      new_text: "",
    })
  }
  for control in proposal.controls_update {
    match @ir.find_control(program, control.name) {
      Some(old) => push_control_diff(entries, old, control)
      None =>
        entries.push(DiffEntry::{
          op: Added,
          path: "control.\{control.name}",
          old_text: "",
          new_text: control.name,
        })
    }
  }
  for control in proposal.controls_add {
    entries.push(DiffEntry::{
      op: Added,
      path: "control.\{control.name}",
      old_text: "",
      new_text: control.text,
    })
  }
  for name in proposal.variables_remove {
    entries.push(DiffEntry::{
      op: Removed,
      path: "variable.\{name}",
      old_text: name,
      new_text: "",
    })
  }
  for variable in proposal.variables_update {
    entries.push(DiffEntry::{
      op: Changed,
      path: "variable.\{variable.name}",
      old_text: match @ir.find_variable(program, variable.name) {
        Some(old) => old.init
        None => ""
      },
      new_text: variable.init,
    })
  }
  for variable in proposal.variables_add {
    entries.push(DiffEntry::{
      op: Added,
      path: "variable.\{variable.name}",
      old_text: "",
      new_text: variable.init,
    })
  }
  for reference in proposal.handlers_remove {
    entries.push(DiffEntry::{
      op: Removed,
      path: "handler.\{reference.control}.\{reference.event}",
      old_text: reference.control,
      new_text: "",
    })
  }
  for handler in proposal.handlers_update {
    match @ir.find_handler(program, handler.control_name, handler.event) {
      Some(old) => push_handler_diff(entries, old, handler)
      None =>
        entries.push(DiffEntry::{
          op: Added,
          path: "handler.\{handler.control_name}.\{handler.event.tag()}",
          old_text: "",
          new_text: handler.note_zh,
        })
    }
  }
  for handler in proposal.handlers_add {
    entries.push(DiffEntry::{
      op: Added,
      path: "handler.\{handler.control_name}.\{handler.event.tag()}",
      old_text: "",
      new_text: handler.note_zh,
    })
  }
  entries
}

///|
fn push_control_diff(
  entries : Array[DiffEntry],
  old : @ir.Control,
  next : @ir.Control,
) -> Unit {
  if old.text != next.text {
    entries.push(DiffEntry::{
      op: Changed,
      path: "control.\{next.name}.text",
      old_text: old.text,
      new_text: next.text,
    })
  }
  if old.x != next.x || old.y != next.y {
    entries.push(DiffEntry::{
      op: Changed,
      path: "control.\{next.name}.position",
      old_text: "\{old.x},\{old.y}",
      new_text: "\{next.x},\{next.y}",
    })
  }
  if old.width != next.width || old.height != next.height {
    entries.push(DiffEntry::{
      op: Changed,
      path: "control.\{next.name}.size",
      old_text: "\{old.width}x\{old.height}",
      new_text: "\{next.width}x\{next.height}",
    })
  }
  if old.items.length() != next.items.length() {
    entries.push(DiffEntry::{
      op: Changed,
      path: "control.\{next.name}.items",
      old_text: "\{old.items.length()} 行",
      new_text: "\{next.items.length()} 行",
    })
  }
}

///|
fn push_handler_diff(
  entries : Array[DiffEntry],
  old : @ir.Handler,
  next : @ir.Handler,
) -> Unit {
  if old.note_zh != next.note_zh {
    entries.push(DiffEntry::{
      op: Changed,
      path: "handler.\{next.control_name}.\{next.event.tag()}.note.zh",
      old_text: old.note_zh,
      new_text: next.note_zh,
    })
  }
  if old.note_en != next.note_en {
    entries.push(DiffEntry::{
      op: Changed,
      path: "handler.\{next.control_name}.\{next.event.tag()}.note.en",
      old_text: old.note_en,
      new_text: next.note_en,
    })
  }
  let old_signature = @ir.stmts_signature(old.body)
  let next_signature = @ir.stmts_signature(next.body)
  if old_signature != next_signature {
    entries.push(DiffEntry::{
      op: Changed,
      path: "handler.\{next.control_name}.\{next.event.tag()}.body",
      old_text: "\{old.body.length()} 条语句",
      new_text: "\{next.body.length()} 条语句",
    })
  }
}
