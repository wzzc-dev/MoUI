///|
/// 积木规格：IR 语句 → Scratch 式积木的投影表。
/// 积木不是第二事实来源：编辑积木 = 编辑 IR 语句；本包只提供
/// 「哪条语句长成哪块积木、端口是什么类型、算什么分类」的 spec 数据。

///|
pub(all) enum BlockCategory {
  CatEvent
  CatVariable
  CatFlow
  CatCommand
  CatExpression
}

///|
pub(all) enum BlockValueType {
  VtText
  VtNumber
  VtBool
  VtAny
}

///|
pub(all) enum BlockKind {
  BkDeclare
  BkAssign
  BkIf
  BkElseIf
  BkElse
  BkEnd
  BkCountLoop
  BkWhile
  BkBreak
  BkCall
}

///|
/// 积木 spec：i18n 目录键 + 分类 + 值类型（渲染层本地化，本包保持中立）。
pub(all) struct BlockSpec {
  id : String
  category : BlockCategory
  value : BlockValueType
  label_key : String
  arity : Int
}

///|
/// 语句 → 积木种类。
pub fn stmt_block_kind(stmt : Stmt) -> BlockKind {
  match stmt {
    @ir.Declare(_, _) => BkDeclare
    @ir.Assign(_, _) => BkAssign
    @ir.If(_, _, _, _) => BkIf
    @ir.CountLoop(_, _, _) => BkCountLoop
    @ir.WhileLoop(_, _) => BkWhile
    @ir.Break => BkBreak
    @ir.Stmt::Call(_, _) => BkCall
  }
}

///|
/// 语句积木的 label 键（i18n catalog：blocks.declare / blocks.assign …）。
pub fn block_label_key(kind : BlockKind) -> String {
  match kind {
    BkDeclare => "blocks.declare"
    BkAssign => "blocks.assign"
    BkIf => "blocks.if"
    BkElseIf => "blocks.else_if"
    BkElse => "blocks.else"
    BkEnd => "blocks.end"
    BkCountLoop => "blocks.count_loop"
    BkWhile => "blocks.while"
    BkBreak => "blocks.break"
    BkCall => "blocks.call"
  }
}

///|
/// 控制流嵌套里的结束/否则块也要有归属（渲染层据此画帽沿）。
pub fn flow_companion_kinds(kind : BlockKind) -> Array[BlockKind] {
  match kind {
    BkIf => [BkElseIf, BkElse, BkEnd]
    BkCountLoop | BkWhile => [BkEnd]
    _ => []
  }
}

///|
/// 内建积木 spec（命令/闸门/函数统一从语言目录派生）。
pub fn builtin_block_spec(id : String) -> BlockSpec? {
  match @momao_lang.find_builtin(id) {
    None => None
    Some(builtin) =>
      Some(
        BlockSpec::{
          id,
          category: match builtin.kind {
            @momao_lang.Function => CatExpression
            _ => CatCommand
          },
          value: builtin_result_type(id),
          label_key: "builtin.\{id}",
          arity: builtin.arity,
        },
      )
  }
}

///|
/// 内建返回值类型（积木端口类型校验用）。
pub fn builtin_result_type(id : String) -> BlockValueType {
  match id {
    "get_text" | "row_at" | "selected_row" | "to_text" => VtText
    "get_number" | "text_length" | "random" | "row_count" => VtNumber
    "contains" | "ask" => VtBool
    _ => VtAny
  }
}

///|
/// 内建参数类型（积木端口校验用；Any = 控件名/任意值插槽）。
pub fn builtin_param_types(id : String) -> Array[BlockValueType] {
  match id {
    "message_box" => [VtText]
    "set_text" => [VtAny, VtText]
    "append_row" => [VtAny, VtText]
    "get_text" | "get_number" | "row_count" | "selected_row" => [VtAny]
    "to_text" => [VtAny]
    "text_length" => [VtText]
    "contains" => [VtText, VtText]
    "random" => [VtNumber]
    "row_at" => [VtAny, VtNumber]
    "ask" => [VtText]
    "submit_data" => [VtAny, VtAny]
    _ => []
  }
}

///|
/// 事件头积木（子程序在积木视图里的帽子）。
pub fn event_block(control_name : String, event_tag : String) -> BlockSpec {
  BlockSpec::{
    id: "event.\{control_name}.\{event_tag}",
    category: CatEvent,
    value: VtAny,
    label_key: "blocks.event",
    arity: 0,
  }
}

///|
/// 分类色键（主题查表用；具体颜色在 app 的 theme 里）。
pub fn category_color_key(category : BlockCategory) -> String {
  match category {
    CatEvent => "block.event"
    CatVariable => "block.variable"
    CatFlow => "block.flow"
    CatCommand => "block.command"
    CatExpression => "block.expression"
  }
}

///|
/// 积木链条目：渲染层拿到的扁平投影（缩进深度 + 规范文本）。
pub(all) struct BlockItem {
  kind : BlockKind
  depth : Int
  text : String
  builtin : String
  // 语句路径：从 handler 根出发的下标链（如 [2] = 第三条顶层语句；
  // [1,0,0] = 第二条顶层 If 的 then 体第一条）。控制流装饰块
  // （else/end）没有对应语句，path 为空。
  path : Array[Int]
}

///|
/// 语句体 → 积木链（If 展开为 if/elseIf/else/end 四件套；
/// CountLoop/WhileLoop 展开为头/end 两件套）。
pub fn block_chain(body : Array[Stmt]) -> Array[BlockItem] {
  let items : Array[BlockItem] = []
  emit_chain(items, body, 0, [])
  items
}

///|
fn emit_chain(
  items : Array[BlockItem],
  body : Array[Stmt],
  depth : Int,
  prefix : Array[Int],
) -> Unit {
  let mut index = 0
  for stmt in body {
    let path = child_path(prefix, index)
    match stmt {
      @ir.Declare(name, expr) =>
        items.push(
          BlockItem::{
            kind: BkDeclare,
            depth,
            text: "\{name} = \{@momao_lang.canonical_expr(expr)}",
            builtin: "",
            path,
          },
        )
      @ir.Assign(name, expr) =>
        items.push(
          BlockItem::{
            kind: BkAssign,
            depth,
            text: "\{name} = \{@momao_lang.canonical_expr(expr)}",
            builtin: "",
            path,
          },
        )
      @ir.If(cond, then_body, else_ifs, else_body) => {
        items.push(
          BlockItem::{
            kind: BkIf,
            depth,
            text: @momao_lang.canonical_expr(cond),
            builtin: "",
            path,
          },
        )
        emit_chain(items, then_body, depth + 1, child_path(path, 0))
        let mut arm_index = 0
        for arm in else_ifs {
          items.push(
            BlockItem::{
              kind: BkElseIf,
              depth,
              text: @momao_lang.canonical_expr(arm.0),
              builtin: "",
              path,
            },
          )
          emit_chain(items, arm.1, depth + 1, child_path(child_path(path, 1), arm_index))
          arm_index = arm_index + 1
        }
        if else_body.length() > 0 {
          items.push(
            BlockItem::{ kind: BkElse, depth, text: "", builtin: "", path: [] },
          )
          emit_chain(items, else_body, depth + 1, child_path(path, 2))
        }
        items.push(
          BlockItem::{ kind: BkEnd, depth, text: "", builtin: "", path: [] },
        )
      }
      @ir.CountLoop(times, loop_var, loop_body) => {
        let name = match loop_var {
          Some(name) => name
          None => ""
        }
        items.push(
          BlockItem::{
            kind: BkCountLoop,
            depth,
            text: "\{@momao_lang.canonical_expr(times)} / \{name}",
            builtin: "",
            path,
          },
        )
        emit_chain(items, loop_body, depth + 1, child_path(path, 2))
        items.push(
          BlockItem::{ kind: BkEnd, depth, text: "", builtin: "", path: [] },
        )
      }
      @ir.WhileLoop(cond, loop_body) => {
        items.push(
          BlockItem::{
            kind: BkWhile,
            depth,
            text: @momao_lang.canonical_expr(cond),
            builtin: "",
            path,
          },
        )
        emit_chain(items, loop_body, depth + 1, child_path(path, 2))
        items.push(
          BlockItem::{ kind: BkEnd, depth, text: "", builtin: "", path: [] },
        )
      }
      @ir.Break =>
        items.push(
          BlockItem::{
            kind: BkBreak,
            depth,
            text: "",
            builtin: "",
            path,
          },
        )
      @ir.Stmt::Call(name, args) =>
        items.push(
          BlockItem::{
            kind: BkCall,
            depth,
            text: @momao_lang.canonical_call_text(name, args),
            builtin: name,
            path,
          },
        )
    }
    index = index + 1
  }
}

///|
/// 路径追加（显式拷贝；spread 不可用）。
fn child_path(prefix : Array[Int], index : Int) -> Array[Int] {
  let path : Array[Int] = []
  for part in prefix {
    path.push(part)
  }
  path.push(index)
  path
}

///|
/// 按路径替换语句（积木视图编辑回写的 IR 原语）。
/// 路径非法（越界/指向装饰块/指向无子体的语句）时原样返回。
pub fn replace_stmt_at(
  body : Array[Stmt],
  path : Array[Int],
  stmt : Stmt,
) -> Array[Stmt] {
  if path.length() == 0 {
    return body
  }
  let head = path[0]
  if path.length() == 1 {
    if head < 0 || head >= body.length() {
      return body
    }
    body[head] = stmt
    return body
  }
  if head < 0 || head >= body.length() {
    return body
  }
  let target = body[head]
  match target {
    @ir.If(cond, then_body, arms, else_body) => {
      let rest = drop_first(path)
      let section = rest[0]
      if section == 0 {
        let updated = replace_stmt_at(then_body, drop_first(rest), stmt)
        body[head] = @ir.If(cond, updated, arms, else_body)
      } else if section == 1 {
        if rest.length() < 2 {
          return body
        }
        let arm_index = rest[1]
        if arm_index < 0 || arm_index >= arms.length() {
          return body
        }
        let arm = arms[arm_index]
        let updated = replace_stmt_at(arm.1, drop_second(rest), stmt)
        arms[arm_index] = (arm.0, updated)
      } else if section == 2 {
        let updated = replace_stmt_at(else_body, drop_first(rest), stmt)
        body[head] = @ir.If(cond, then_body, arms, updated)
      }
    }
    @ir.CountLoop(times, loop_var, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = replace_stmt_at(loop_body, drop_first(rest), stmt)
      body[head] = @ir.CountLoop(times, loop_var, updated)
    }
    @ir.WhileLoop(cond, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = replace_stmt_at(loop_body, drop_first(rest), stmt)
      body[head] = @ir.WhileLoop(cond, updated)
    }
    _ => ()
  }
  body
}

///|
/// 按路径删除语句（与 replace 同一套寻径规则）。
pub fn delete_stmt_at(
  body : Array[Stmt],
  path : Array[Int],
) -> Array[Stmt] {
  if path.length() == 0 {
    return body
  }
  let head = path[0]
  if path.length() == 1 {
    if head < 0 || head >= body.length() {
      return body
    }
    let kept : Array[Stmt] = []
    let mut i = 0
    for stmt in body {
      if i != head {
        kept.push(stmt)
      }
      i = i + 1
    }
    return kept
  }
  if head < 0 || head >= body.length() {
    return body
  }
  let target = body[head]
  match target {
    @ir.If(cond, then_body, arms, else_body) => {
      let rest = drop_first(path)
      let section = rest[0]
      if section == 0 {
        let updated = delete_stmt_at(then_body, drop_first(rest))
        body[head] = @ir.If(cond, updated, arms, else_body)
      } else if section == 1 {
        if rest.length() < 2 {
          return body
        }
        let arm_index = rest[1]
        if arm_index < 0 || arm_index >= arms.length() {
          return body
        }
        let arm = arms[arm_index]
        let updated = delete_stmt_at(arm.1, drop_second(rest))
        arms[arm_index] = (arm.0, updated)
      } else if section == 2 {
        let updated = delete_stmt_at(else_body, drop_first(rest))
        body[head] = @ir.If(cond, then_body, arms, updated)
      }
    }
    @ir.CountLoop(times, loop_var, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = delete_stmt_at(loop_body, drop_first(rest))
      body[head] = @ir.CountLoop(times, loop_var, updated)
    }
    @ir.WhileLoop(cond, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = delete_stmt_at(loop_body, drop_first(rest))
      body[head] = @ir.WhileLoop(cond, updated)
    }
    _ => ()
  }
  body
}

///|
fn drop_first(path : Array[Int]) -> Array[Int] {
  let rest : Array[Int] = []
  let mut i = 1
  while i < path.length() {
    rest.push(path[i])
    i = i + 1
  }
  rest
}

///|
fn drop_second(path : Array[Int]) -> Array[Int] {
  let rest : Array[Int] = []
  let mut i = 2
  while i < path.length() {
    rest.push(path[i])
    i = i + 1
  }
  rest
}

///|
/// 按路径取语句（编辑回放用；越界返回 None）。
pub fn stmt_at(body : Array[Stmt], path : Array[Int]) -> Stmt? {
  if path.length() == 0 {
    return None
  }
  let head = path[0]
  if head < 0 || head >= body.length() {
    return None
  }
  if path.length() == 1 {
    return Some(body[head])
  }
  let target = body[head]
  let rest = drop_first(path)
  match target {
    @ir.If(_, then_body, arms, else_body) => {
      let section = rest[0]
      if section == 0 {
        stmt_at(then_body, drop_first(rest))
      } else if section == 1 {
        if rest.length() < 2 {
          return None
        }
        let arm_index = rest[1]
        if arm_index < 0 || arm_index >= arms.length() {
          return None
        }
        stmt_at(arms[arm_index].1, drop_second(rest))
      } else if section == 2 {
        stmt_at(else_body, drop_first(rest))
      } else {
        None
      }
    }
    @ir.CountLoop(_, _, loop_body) =>
      if rest[0] == 2 {
        stmt_at(loop_body, drop_first(rest))
      } else {
        None
      }
    @ir.WhileLoop(_, loop_body) =>
      if rest[0] == 2 {
        stmt_at(loop_body, drop_first(rest))
      } else {
        None
      }
    _ => None
  }
}
