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
  BkSetIndex
  BkReturn
  BkIf
  BkElseIf
  BkElse
  BkEnd
  BkCountLoop
  BkForEach
  BkWhile
  BkBreak
  BkCall
  BkMatch
  BkCase
  BkEnumDecl
  BkStructDecl
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
    @ir.SetIndex(_, _, _) => BkSetIndex
    @ir.Return(_) => BkReturn
    @ir.If(_, _, _, _) => BkIf
    @ir.CountLoop(_, _, _) => BkCountLoop
    @ir.ForEach(_, _, _) => BkForEach
    @ir.WhileLoop(_, _) => BkWhile
    @ir.Break => BkBreak
    @ir.Stmt::Call(_, _) => BkCall
    @ir.Match(_, _, _) => BkMatch
  }
}

///|
/// 语句积木的 label 键（i18n catalog：blocks.declare / blocks.assign …）。
pub fn block_label_key(kind : BlockKind) -> String {
  match kind {
    BkDeclare => "blocks.declare"
    BkAssign => "blocks.assign"
    BkSetIndex => "blocks.set_index"
    BkReturn => "blocks.return"
    BkIf => "blocks.if"
    BkElseIf => "blocks.else_if"
    BkElse => "blocks.else"
    BkEnd => "blocks.end"
    BkCountLoop => "blocks.count_loop"
    BkForEach => "blocks.for_each"
    BkWhile => "blocks.while"
    BkBreak => "blocks.break"
    BkCall => "blocks.call"
    BkMatch => "blocks.match"
    BkCase => "blocks.case"
    BkEnumDecl => "blocks.enum_decl"
    BkStructDecl => "blocks.struct_decl"
  }
}

///|
/// 控制流嵌套里的结束/否则块也要有归属（渲染层据此画帽沿）。
pub fn flow_companion_kinds(kind : BlockKind) -> Array[BlockKind] {
  match kind {
    BkIf => [BkElseIf, BkElse, BkEnd]
    BkCountLoop | BkForEach | BkWhile => [BkEnd]
    // 匹配：情况行 + 否则 + 结束都是匹配头的伴随块
    BkMatch => [BkCase, BkElse, BkEnd]
    _ => []
  }
}

///|
/// 内建积木 spec（命令/闸门/函数统一从语言目录派生）。
pub fn builtin_block_spec(id : String) -> BlockSpec? {
  match @studio_lang.find_builtin(id) {
    None => None
    Some(builtin) =>
      Some(BlockSpec::{
        id,
        category: match builtin.kind {
          @studio_lang.Function => CatExpression
          _ => CatCommand
        },
        value: builtin_result_type(id),
        label_key: "builtin.\{id}",
        arity: builtin.arity,
      })
  }
}

///|
/// 内建返回值类型（积木端口类型校验用）。
pub fn builtin_result_type(id : String) -> BlockValueType {
  match id {
    "get_text" | "row_at" | "selected_row" | "to_text" | "answer" => VtText
    "get_number"
    | "text_length"
    | "random"
    | "row_count"
    | "list_length"
    // 取余与四舍五入都是**数值**结果（`round` 返回整数，仍归数值端口）
    | "mod"
    | "round"
    | "abs"
    | "floor"
    | "ceiling"
    | "sqrt" => VtNumber
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
    "list_length" => [VtAny]
    "append_list" => [VtAny, VtAny]
    "broadcast" => [VtText]
    "row_at" => [VtAny, VtNumber]
    // 取余接两个数；四舍五入接一个数
    "stop_all" => []
    "wait" => [VtNumber]
    "answer" => []
    "mod" => [VtNumber, VtNumber]
    "round" | "abs" | "floor" | "ceiling" | "sqrt" => [VtNumber]
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
  // 行内**分段**（字面段 / 插槽段），供绘制层画洞、命中层认洞。
  //
  // 与 `text` **同一次投影产出**：两处各切一次就会分叉（文本改了而段表
  // 没改），而分叉的后果是洞画在错误位置且命中一起偏——两者会一起错，
  // 所以放同一个结构里由构造点保证一致。装饰块（else/end）为 `None`。
  segments : Array[TextSegment]?
}

///|
/// 语句体 → 积木链（If 展开为 if/elseIf/else/end 四件套；
/// CountLoop/WhileLoop 展开为头/end 两件套）。
pub fn block_chain(body : Array[Stmt]) -> Array[BlockItem] {
  let items : Array[BlockItem] = []
  emit_chain(items, body, 0, [])
  attach_segments(items, body)
  items
}

///|
/// 给每个链条目挂上**行内分段**。
///
/// 集中在投影出口做（而不是 14 个 `BlockItem` 构造点各写一遍）：段表与
/// `text` 必须同源，分散填就会漏填或错填，而漏填的表现是「某类积木画不出
/// 洞」、错填的表现是「洞画在字符之间」——都不容易一眼看出。
/// 装饰块（`else`/`end`，`path` 为空）没有对应语句，保持 `None`。
fn attach_segments(items : Array[BlockItem], body : Array[Stmt]) -> Unit {
  let mut index = 0
  for item in items {
    if item.path.length() > 0 {
      match stmt_at(body, item.path) {
        Some(stmt) => {
          let segments = stmt_text_segments(stmt)
          items[index] = { ..item, segments: Some(segments), }
        }
        None => ()
      }
    }
    index = index + 1
  }
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
        items.push(BlockItem::{
          kind: BkDeclare,
          depth,
          text: "\{name} = \{@studio_lang.canonical_expr(expr)}",
          builtin: "",
          path,
          segments: None,
        })
      @ir.Assign(name, expr) =>
        items.push(BlockItem::{
          kind: BkAssign,
          depth,
          text: "\{name} = \{@studio_lang.canonical_expr(expr)}",
          builtin: "",
          path,
          segments: None,
        })
      @ir.SetIndex(name, index, value) =>
        items.push(BlockItem::{
          kind: BkSetIndex,
          depth,
          text: "\{name}[\{@studio_lang.canonical_expr(index)}] = \{@studio_lang.canonical_expr(value)}",
          builtin: "",
          path,
          segments: None,
        })
      @ir.Return(expr) =>
        items.push(BlockItem::{
          kind: BkReturn,
          depth,
          text: match expr {
            Some(value) => @studio_lang.canonical_expr(value)
            None => ""
          },
          builtin: "",
          path,
          segments: None,
        })
      @ir.If(cond, then_body, else_ifs, else_body) => {
        items.push(BlockItem::{
          kind: BkIf,
          depth,
          text: @studio_lang.canonical_expr(cond),
          builtin: "",
          path,
          segments: None,
        })
        emit_chain(items, then_body, depth + 1, child_path(path, 0))
        let mut arm_index = 0
        for arm in else_ifs {
          items.push(BlockItem::{
            kind: BkElseIf,
            depth,
            text: @studio_lang.canonical_expr(arm.0),
            builtin: "",
            path,
            segments: None,
          })
          emit_chain(
            items,
            arm.1,
            depth + 1,
            child_path(child_path(path, 1), arm_index),
          )
          arm_index = arm_index + 1
        }
        if else_body.length() > 0 {
          items.push(BlockItem::{
            kind: BkElse,
            depth,
            text: "",
            builtin: "",
            path: [],
            segments: None,
          })
          emit_chain(items, else_body, depth + 1, child_path(path, 2))
        }
        items.push(BlockItem::{
          kind: BkEnd,
          depth,
          text: "",
          builtin: "",
          path: [],
          segments: None,
        })
      }
      @ir.CountLoop(times, loop_var, loop_body) => {
        let name = match loop_var {
          Some(name) => name
          None => ""
        }
        items.push(BlockItem::{
          kind: BkCountLoop,
          depth,
          text: "\{@studio_lang.canonical_expr(times)} / \{name}",
          builtin: "",
          path,
          segments: None,
        })
        emit_chain(items, loop_body, depth + 1, child_path(path, 2))
        items.push(BlockItem::{
          kind: BkEnd,
          depth,
          text: "",
          builtin: "",
          path: [],
          segments: None,
        })
      }
      @ir.ForEach(list_expr, loop_var, loop_body) => {
        items.push(BlockItem::{
          kind: BkForEach,
          depth,
          text: "\{@studio_lang.canonical_expr(list_expr)} / \{loop_var}",
          builtin: "",
          path,
          segments: None,
        })
        emit_chain(items, loop_body, depth + 1, child_path(path, 2))
        items.push(BlockItem::{
          kind: BkEnd,
          depth,
          text: "",
          builtin: "",
          path: [],
          segments: None,
        })
      }
      @ir.Match(subject, arms, else_body) => {
        items.push(BlockItem::{
          kind: BkMatch,
          depth,
          text: @studio_lang.canonical_expr(subject),
          builtin: "",
          path,
          segments: None,
        })
        // 路径方案（线性）：section i = 第 i 个 arm 体；section arms.length() = else
        let mut arm_index = 0
        for arm in arms {
          items.push(BlockItem::{
            kind: BkCase,
            depth,
            text: arm.case_name,
            builtin: "",
            path,
            segments: None,
          })
          emit_chain(items, arm.body, depth + 1, child_path(path, arm_index))
          arm_index = arm_index + 1
        }
        if else_body.length() > 0 {
          items.push(BlockItem::{
            kind: BkElse,
            depth,
            text: "",
            builtin: "",
            path: [],
            segments: None,
          })
          emit_chain(
            items,
            else_body,
            depth + 1,
            child_path(path, arms.length()),
          )
        }
        items.push(BlockItem::{
          kind: BkEnd,
          depth,
          text: "",
          builtin: "",
          path: [],
          segments: None,
        })
      }
      @ir.WhileLoop(cond, loop_body) => {
        items.push(BlockItem::{
          kind: BkWhile,
          depth,
          text: @studio_lang.canonical_expr(cond),
          builtin: "",
          path,
          segments: None,
        })
        emit_chain(items, loop_body, depth + 1, child_path(path, 2))
        items.push(BlockItem::{
          kind: BkEnd,
          depth,
          text: "",
          builtin: "",
          path: [],
          segments: None,
        })
      }
      @ir.Break =>
        items.push(BlockItem::{
          kind: BkBreak,
          depth,
          text: "",
          builtin: "",
          path,
          segments: None,
        })
      @ir.Stmt::Call(name, args) =>
        items.push(BlockItem::{
          kind: BkCall,
          depth,
          text: @studio_lang.canonical_call_text(name, args),
          builtin: name,
          path,
          segments: None,
        })
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
    @ir.ForEach(list_expr, loop_var, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = replace_stmt_at(loop_body, drop_first(rest), stmt)
      body[head] = @ir.ForEach(list_expr, loop_var, updated)
    }
    @ir.WhileLoop(cond, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = replace_stmt_at(loop_body, drop_first(rest), stmt)
      body[head] = @ir.WhileLoop(cond, updated)
    }
    @ir.Match(subject, arms, else_body) => {
      // section i = 第 i 个 arm 体；section arms.length() = else
      let rest = drop_first(path)
      let section = rest[0]
      if section >= 0 && section < arms.length() {
        let arm = arms[section]
        let updated = replace_stmt_at(arm.body, drop_first(rest), stmt)
        arms[section] = @ir.MatchArm::{
          case_name: arm.case_name,
          body: updated,
        }
      } else if section == arms.length() {
        let updated = replace_stmt_at(else_body, drop_first(rest), stmt)
        body[head] = @ir.Match(subject, arms, updated)
      }
    }
    _ => ()
  }
  body
}

///|
/// 按路径删除语句（与 replace 同一套寻径规则）。
pub fn delete_stmt_at(body : Array[Stmt], path : Array[Int]) -> Array[Stmt] {
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
    @ir.ForEach(list_expr, loop_var, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = delete_stmt_at(loop_body, drop_first(rest))
      body[head] = @ir.ForEach(list_expr, loop_var, updated)
    }
    @ir.WhileLoop(cond, loop_body) => {
      let rest = drop_first(path)
      if rest[0] != 2 {
        return body
      }
      let updated = delete_stmt_at(loop_body, drop_first(rest))
      body[head] = @ir.WhileLoop(cond, updated)
    }
    @ir.Match(subject, arms, else_body) => {
      let rest = drop_first(path)
      let section = rest[0]
      if section >= 0 && section < arms.length() {
        let arm = arms[section]
        let updated = delete_stmt_at(arm.body, drop_first(rest))
        arms[section] = @ir.MatchArm::{
          case_name: arm.case_name,
          body: updated,
        }
      } else if section == arms.length() {
        let updated = delete_stmt_at(else_body, drop_first(rest))
        body[head] = @ir.Match(subject, arms, updated)
      }
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
    @ir.ForEach(_, _, loop_body) =>
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
    @ir.Match(_, arms, else_body) => {
      let section = rest[0]
      if section >= 0 && section < arms.length() {
        stmt_at(arms[section].body, drop_first(rest))
      } else if section == arms.length() {
        stmt_at(else_body, drop_first(rest))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// 深拷贝语句数组（撤销快照安全：就地手术前先克隆，
/// 避免快照与活状态共享数组引用被就地修改污染）。
pub fn clone_stmts(body : Array[Stmt]) -> Array[Stmt] {
  let copy : Array[Stmt] = []
  for stmt in body {
    copy.push(clone_stmt(stmt))
  }
  copy
}

///|
pub fn clone_stmt(stmt : Stmt) -> Stmt {
  match stmt {
    @ir.Declare(name, expr) => @ir.Declare(name, clone_expr(expr))
    @ir.Assign(name, expr) => @ir.Assign(name, clone_expr(expr))
    @ir.SetIndex(name, index, value) =>
      @ir.SetIndex(name, clone_expr(index), clone_expr(value))
    @ir.Return(expr) =>
      @ir.Return(
        match expr {
          Some(value) => Some(clone_expr(value))
          None => None
        },
      )
    @ir.If(cond, then_body, else_ifs, else_body) => {
      let arms : Array[(Expr, Array[Stmt])] = []
      for arm in else_ifs {
        arms.push((clone_expr(arm.0), clone_stmts(arm.1)))
      }
      @ir.If(
        clone_expr(cond),
        clone_stmts(then_body),
        arms,
        clone_stmts(else_body),
      )
    }
    @ir.CountLoop(times, iter, loop_body) =>
      @ir.CountLoop(clone_expr(times), iter, clone_stmts(loop_body))
    @ir.ForEach(list_expr, iter, loop_body) =>
      @ir.ForEach(clone_expr(list_expr), iter, clone_stmts(loop_body))
    @ir.WhileLoop(cond, loop_body) =>
      @ir.WhileLoop(clone_expr(cond), clone_stmts(loop_body))
    @ir.Match(subject, arms, else_body) => {
      let arm_clones : Array[@ir.MatchArm] = []
      for arm in arms {
        arm_clones.push(@ir.MatchArm::{
          case_name: arm.case_name,
          body: clone_stmts(arm.body),
        })
      }
      @ir.Match(clone_expr(subject), arm_clones, clone_stmts(else_body))
    }
    @ir.Break => @ir.Break
    @ir.Stmt::Call(name, args) => {
      let copied : Array[Expr] = []
      for arg in args {
        copied.push(clone_expr(arg))
      }
      @ir.Stmt::Call(name, copied)
    }
  }
}

///|
pub fn clone_expr(expr : Expr) -> Expr {
  match expr {
    @ir.NumLit(v) => @ir.NumLit(v)
    @ir.IntLit(v) => @ir.IntLit(v)
    @ir.ListLit(items) => {
      let copy : Array[Expr] = []
      for item in items {
        copy.push(clone_expr(item))
      }
      @ir.ListLit(copy)
    }
    @ir.Index(base, index) => @ir.Index(clone_expr(base), clone_expr(index))
    @ir.StrLit(v) => @ir.StrLit(v)
    @ir.BoolLit(v) => @ir.BoolLit(v)
    @ir.Var(name) => @ir.Var(name)
    @ir.Not(inner) => @ir.Not(clone_expr(inner))
    @ir.Neg(inner) => @ir.Neg(clone_expr(inner))
    @ir.FieldAccess(base, field) => @ir.FieldAccess(clone_expr(base), field)
    @ir.EnumTag(enum_name, case_name) => @ir.EnumTag(enum_name, case_name)
    @ir.Binary(op, left, right) =>
      @ir.Binary(op, clone_expr(left), clone_expr(right))
    @ir.Call(name, args) => {
      let copied : Array[Expr] = []
      for arg in args {
        copied.push(clone_expr(arg))
      }
      @ir.Call(name, copied)
    }
  }
}

///|
/// 落点**是否接受**这条语句（拖拽的有效性判定 / Scratch 的「不能放进那里」）。
///
/// 这里的约束来自**语言本身的规则**，不是凭空的规则表——
/// `@studio_lang` 的 `check_body` 已经定义了哪些语句在哪些位置非法，
/// 这里只取其中与**容器位置**相关、且拖拽当场就能判定的那几条：
///
/// - **`break` 必须在循环体内**（`BreakOutsideLoop`）。语言层在整程序校验时
///   报这个错；拖拽时先判一次，用户就不必「拖进去 → 运行 → 看报错」。
/// - **`return` 必须在子程序里**。语句级拖拽不会改变所在子程序，所以恒定
///   成立，不需要在这里判。
///
/// 判据只看 `to_list_path` 的形状：它是否位于某个循环体内。路径语法见
/// `stmt_list_at`——`[i,2]` 是 `If@i` 的 else **或循环体**；所以要看
/// `to_list_path` 指向的容器**属于哪种父语句**，而不是只看长度。
///
/// 返回 `false` 表示这次落点应当被**拒绝**（调用方给视觉反馈并且不改 IR），
/// 而不是「静默丢弃」。
pub fn drop_accepts_stmt(
  body : Array[Stmt],
  to_list_path : Array[Int],
  stmt : Stmt,
) -> Bool {
  let needs_loop = match stmt {
    @ir.Break => true
    _ => false
  }
  if !needs_loop {
    return true
  }
  stmt_list_in_loop(body, to_list_path, false)
}

///|
/// `list_path` 指向的语句列表是否位于某个**循环体内**。
///
/// 逐段下降：每一段 `[i, slot, ...]` 描述「进入 `body[i]` 的某个子列表」。
/// `slot == 2` 时既可能是 `If` 的 else，也可能是 `CountLoop/WhileLoop` 的
/// 循环体——**必须看那一条语句的真实类型**，不能按 slot 猜（按 slot 猜会把
/// `if…else` 当成循环，于是 `break` 被错误放行）。
fn stmt_list_in_loop(
  body : Array[Stmt],
  list_path : Array[Int],
  inside : Bool,
) -> Bool {
  if list_path.length() == 0 {
    return inside
  }
  let head = list_path[0]
  if head < 0 || head >= body.length() {
    return inside
  }
  let target = body[head]
  return match target {
    @ir.CountLoop(_, _, loop_body) =>
      if list_path.length() == 2 && list_path[1] == 2 {
        // 正是循环体本身：已经在内
        true
      } else {
        stmt_list_in_loop(loop_body, [], true)
      }
    @ir.ForEach(_, _, loop_body) =>
      if list_path.length() == 2 && list_path[1] == 2 {
        true
      } else {
        stmt_list_in_loop(loop_body, [], true)
      }
    @ir.WhileLoop(_, loop_body) =>
      if list_path.length() == 2 && list_path[1] == 2 {
        true
      } else {
        stmt_list_in_loop(loop_body, [], true)
      }
    @ir.If(_, then_body, arms, else_body) =>
      // 继续下降：slot 0 = then / 1 = else-if 臂 / 2 = else
      if list_path.length() < 2 {
        inside
      } else {
        let rest : Array[Int] = []
        let mut k = 2
        while k < list_path.length() {
          rest.push(list_path[k])
          k = k + 1
        }
        match list_path[1] {
          0 => stmt_list_in_loop(then_body, rest, inside)
          1 => {
            let arm_index = if list_path.length() >= 3 {
              list_path[2]
            } else {
              -1
            }
            if arm_index >= 0 && arm_index < arms.length() {
              let arm_rest : Array[Int] = []
              let mut j = 3
              while j < list_path.length() {
                arm_rest.push(list_path[j])
                j = j + 1
              }
              stmt_list_in_loop(arms[arm_index].1, arm_rest, inside)
            } else {
              inside
            }
          }
          2 => stmt_list_in_loop(else_body, rest, inside)
          _ => inside
        }
      }
    _ => inside
  }
}

///|
/// **跨列表移动**：把 `from_path` 处的语句移到 `to_list_path` 的 `at` 位置。
///
/// 这是「把语句拖进 C 形块体内」的落地手术，也是 Scratch 编辑器的核心
/// 手势（拖进 if/循环的洞里）。此前的 `reorder_stmt` **只在同一个列表内**
/// 重排（其注释明确写了「跨层移动不在 v1 范围」），所以嵌套只能靠「先选中
/// 父块、再从面板插入」间接达成——拖拽进洞是不可能的。
///
/// 三步都复用既有原语，不新增寻径规则：`stmt_at` 取出 →（若是跨列表）
/// `delete_stmt_at` 删源 → `insert_stmt_at` 插目标。
///
/// **同列表内**的移动直接委托 `reorder_stmt`——它自己已经做了「先删再插时
/// 目标位置左移一位」的补偿（`insert_at > from` 时减 1）。这里**不要再补一次**
/// （双重补偿会把「往后挪一位」变成「往前挪一位」，实测把 a 移到 c 之后
/// 得到的是 a,c,b 而不是 b,c,a）。
///
/// 返回 `None` 表示路径非法或目标列表不存在。调用方据此**拒绝**这次拖拽，
/// 而不是静默丢弃——静默丢弃让用户以为拖成功但块没动。
pub fn move_stmt_at(
  body : Array[Stmt],
  from_path : Array[Int],
  to_list_path : Array[Int],
  at : Int,
) -> Array[Stmt]? {
  if from_path.length() == 0 {
    return None
  }
  // 源路径必须**真的**指向一条语句。`stmt_at` 对非法路径返回 None，
  // 但这里还要挡住「路径指向装饰块」这类没有对应语句的位置——它们
  // 本来就取不到 Stmt，所以同一条检查即可。
  let stmt = match stmt_at(body, from_path) {
    Some(value) => value
    None => return None
  }
  // 源语句所属的**列表路径** = 语句路径去掉最后一位
  let from_list : Array[Int] = []
  let mut i = 0
  while i < from_path.length() - 1 {
    from_list.push(from_path[i])
    i = i + 1
  }
  let same_list = if from_list.length() != to_list_path.length() {
    false
  } else {
    let mut equal = true
    let mut k = 0
    while k < from_list.length() {
      if from_list[k] != to_list_path[k] {
        equal = false
      }
      k = k + 1
    }
    equal
  }
  let from_index = from_path[from_path.length() - 1]
  // 目标列表必须存在，且 `at` 落在**原**范围内——两种移动都要先过这一关。
  //
  // 为什么在分支之前判：`reorder_stmt` 对越界的 `drop_before` 是**钳制**
  // （`insert_at > list.length()` 时夹到末尾），那是同层拖拽要的宽容
  // （拖到列表下方 = 追加到末尾）；但 `move_stmt_at` 是编程接口，越界应当
  // **拒绝**。若只在跨列表分支里判，同列表的越界会被 `reorder_stmt`
  // 悄悄钳住（实测顶层只有 1 条时 `at=5` 被接受）。
  let target_len = match stmt_list_at(body, to_list_path) {
    Some(list) => list.length()
    None => return None
  }
  if at < 0 || at > target_len {
    return None
  }
  if same_list {
    return reorder_stmt(body, to_list_path, from_index, at)
  }
  // 跨列表：顺序必须是「删源 → 插目标」——反过来插进去的会被随后的删除
  // 带走（同一条语句不可能同时在两处）。`insert_stmt_at` 内部会 clone。
  //
  // **但删除会让「排在源之后」的容器索引整体左移一位**，所以目标列表路径
  // 必须先补偿：源在顶层下标 `from_index`，而目标容器的顶层下标是
  // `to_list_path[0]`——后者更大时减一。
  //
  // 不补偿的后果是**拖拽静默失败**：实测把顶层第 0 条拖进顶层第 1 条的
  // if 体里，删掉第 0 条后那个 if 变成第 0 条，而目标路径仍指向 [1,0]，
  // `stmt_list_at` 越界返回 None，整次移动被丢弃（用户看到「拖了没反应」）。
  let adjusted : Array[Int] = []
  for part in to_list_path {
    adjusted.push(part)
  }
  if adjusted.length() > 0 &&
    from_list.length() == 0 &&
    adjusted[0] > from_index {
    adjusted[0] = adjusted[0] - 1
  }
  let without = delete_stmt_at(body, from_path)
  // 删源后要确认源真的少了（路径非法时 delete 会原样返回），
  // 否则「移动」会退化成「复制」。
  if without.length() == body.length() &&
    from_list.length() == 0 &&
    from_index < body.length() {
    return None
  }
  match insert_stmt_at(without, adjusted, at, stmt) {
    Some(result) => Some(result)
    None => None
  }
}

///|
/// 插入一条语句：在 `list_path` 列表的 `at` 位置插入 `stmt`（`at` 为
/// 列表长度时追加到末尾；`list_path` 为空数组时是顶层）。返回**新数组**
/// （克隆后手术，不改传入的 body——与 replace/delete/reorder 同一纪律：
/// 就地修改会污染撤销快照，它们共享同一份 body 引用）。
///
/// 这是「从零写程序」的落地手术：此前只有 replace/delete/reorder，三条都
/// 要求语句已存在，所以积木视图加不出一行逻辑（见 `statement_palette.mbt`）。
pub fn insert_stmt_at(
  body : Array[Stmt],
  list_path : Array[Int],
  at : Int,
  stmt : Stmt,
) -> Array[Stmt]? {
  let working = clone_stmts(body)
  let list = match stmt_list_at(working, list_path) {
    Some(list) => list
    None => return None
  }
  if at < 0 || at > list.length() {
    return None
  }
  list.insert(at, clone_stmt(stmt))
  Some(working)
}

///|
/// 语句列表寻址：list_path 指向一棵语句列表（[] = 顶层；
/// [i,0] = If@i 的 then；[i,1,k] = If@i 的第 k 个 else-if 臂；
/// [i,2] = If@i 的 else 或循环体）。返回活数组引用。
pub fn stmt_list_at(body : Array[Stmt], list_path : Array[Int]) -> Array[Stmt]? {
  if list_path.length() == 0 {
    return Some(body)
  }
  let head = list_path[0]
  if head < 0 || head >= body.length() {
    return None
  }
  let rest_len = list_path.length() - 1
  match body[head] {
    @ir.If(_, then_body, arms, else_body) =>
      if rest_len == 1 {
        match list_path[1] {
          0 => Some(then_body)
          2 => Some(else_body)
          _ => None
        }
      } else if rest_len == 2 {
        let arm_index = list_path[2]
        if list_path[1] != 1 || arm_index < 0 || arm_index >= arms.length() {
          None
        } else {
          Some(arms[arm_index].1)
        }
      } else {
        None
      }
    @ir.CountLoop(_, _, loop_body) =>
      if rest_len == 1 && list_path[1] == 2 {
        Some(loop_body)
      } else {
        None
      }
    @ir.ForEach(_, _, loop_body) =>
      if rest_len == 1 && list_path[1] == 2 {
        Some(loop_body)
      } else {
        None
      }
    @ir.WhileLoop(_, loop_body) =>
      if rest_len == 1 && list_path[1] == 2 {
        Some(loop_body)
      } else {
        None
      }
    @ir.Match(_, arms, else_body) =>
      // section i = 第 i 个 arm 体；section arms.length() = else
      if rest_len == 1 {
        let section = list_path[1]
        if section >= 0 && section < arms.length() {
          Some(arms[section].body)
        } else if section == arms.length() {
          Some(else_body)
        } else {
          None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// **整栈重排**：抓住 `from` 时，把从它起**到列表末尾**的整段一起搬到
/// `drop_before` 槽位。
///
/// 这是 Scratch 的手感：抓住栈中间一块，它和**它下面的所有块**一起移动
/// （「把这段逻辑整体挪走」）。`reorder_stmt` 只搬一条，用它做栈拖拽会把
/// 一段逻辑拆散——实测拖第 2 块时第 3、4 块留在原地，用户以为丢块了。
///
/// 语义与 `reorder_stmt` 一致（先摘除再插入，`drop_before > from` 时目标
/// 左移 `stack_len` 位），越界或列表不存在返回 `None`。
///
/// `drop_before` **落在栈内**（`from < drop_before <= from + stack_len`）
/// 视作原位——搬到自己内部没有意义，返回 `None` 让调用方当无操作处理。
pub fn reorder_stack(
  body : Array[Stmt],
  list_path : Array[Int],
  from : Int,
  drop_before : Int,
) -> Array[Stmt]? {
  let working = clone_stmts(body)
  let list = match stmt_list_at(working, list_path) {
    Some(list) => list
    None => return None
  }
  if from < 0 || from >= list.length() {
    return None
  }
  let stack_len = list.length() - from
  // 「原位」判定必须按**插入后的位置**算，不能按 `drop_before` 落在哪一段算：
  //
  //   插入位置 = drop_before −（drop_before > from 时减 stack_len），再钳到 [0, len]
  //   原位 ⟺ 插入位置 == from
  //
  // 两个反例说明为什么不能只看区间：
  // - `drop_before == from`（落在抓取块顶缘）→ 插入位置 == from，是原位；
  // - 抓的是**整条列表**（stack_len == list.length()）时，任何 `drop_before`
  //   算出来都回到 from —— 整条搬走等于没动。
  // 早先的区间写法把「抓整条列表」漏成 `Some`，会凭空产生一次撤销点而画面
  // 什么都没变。
  let mut probe_at = drop_before
  if probe_at > from {
    probe_at = probe_at - stack_len
  }
  if probe_at < 0 {
    probe_at = 0
  }
  if probe_at > list.length() {
    probe_at = list.length()
  }
  if probe_at == from {
    return None
  }
  // 摘出整段（保持段内顺序）
  let segment : Array[Stmt] = []
  let mut i = 0
  while i < stack_len {
    segment.push(list[from + i])
    i = i + 1
  }
  let mut removed = 0
  while removed < stack_len {
    let _ = list.remove(from)
    removed = removed + 1
  }
  let mut insert_at = drop_before
  if insert_at > from {
    insert_at = insert_at - stack_len
  }
  if insert_at < 0 {
    insert_at = 0
  }
  if insert_at > list.length() {
    insert_at = list.length()
  }
  let mut k = 0
  for stmt in segment {
    list.insert(insert_at + k, stmt)
    k = k + 1
  }
  Some(working)
}

///|
/// 同层重排：把 list_path 列表中下标 from 的语句移动到 drop_before 槽位
/// （槽位语义 = 落在原下标 drop_before 的语句之前；先摘除再插入，
/// drop_before > from 时自然左移一位）。克隆后手术，不改传入数组。
/// from/to 越界或目标列表不存在返回 None。
pub fn reorder_stmt(
  body : Array[Stmt],
  list_path : Array[Int],
  from : Int,
  drop_before : Int,
) -> Array[Stmt]? {
  let working = clone_stmts(body)
  let list = match stmt_list_at(working, list_path) {
    Some(list) => list
    None => return None
  }
  if from < 0 || from >= list.length() {
    return None
  }
  let stmt = list[from]
  let _ = list.remove(from)
  let mut insert_at = drop_before
  if insert_at > from {
    insert_at = insert_at - 1
  }
  if insert_at < 0 {
    insert_at = 0
  }
  if insert_at > list.length() {
    insert_at = list.length()
  }
  list.insert(insert_at, stmt)
  Some(working)
}

///|
/// 声明块投影（M7①）：程序级 enum/struct 声明 → 只读积木行。
/// path 为空（装饰块口径）：不参与命中/编辑/榫卯，画布据此把它们画成
/// 「数据声明区」。文本取规范写法（英文关键字 = 规范 id 口径，与
/// 表达式段的语言无关原则一致）。
pub fn declaration_chain(program : StudioProgram) -> Array[BlockItem] {
  let items : Array[BlockItem] = []
  for decl in program.enums {
    let cases = decl.cases.map(case_name => case_name).join(", ")
    items.push(BlockItem::{
      kind: BkEnumDecl,
      depth: 0,
      text: "enum \{decl.name} { \{cases} }",
      builtin: "",
      path: [],
      segments: None,
    })
  }
  for decl in program.structs {
    let fields = decl.fields
      .map(field => "\{field.field_name}: \{field.field_type}")
      .join(", ")
    items.push(BlockItem::{
      kind: BkStructDecl,
      depth: 0,
      text: "struct \{decl.name} { \{fields} }",
      builtin: "",
      path: [],
      segments: None,
    })
  }
  items
}
