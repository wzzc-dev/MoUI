///|
/// 撤销/重做与「最近修改」留痕：编辑历史域。
///
/// 从 update.mbt 拆出来（原文件越过 1200 行的硬上限）：这里是一组围绕
/// UndoEntry 的纯函数，和消息分发没有耦合，拆开后两边都更好读。
///
/// 关键约定：**合并**（连续同类编辑共享还原点）与**留痕**（最近修改列表）
/// 是两件事。离散动作（插/删/复制/换模板）不合并，但同样要留痕——
/// 用同一个 key 表达两者会把离散动作粘成一步撤销。

///|
/// 编辑快照（撤销条目）：程序 + 选中态 + 代码草稿。
fn undo_entry_of(model : Model, key : String) -> UndoEntry {
  {
    program: model.program,
    selected_control: model.selected_control,
    selected_handler: model.selected_handler,
    code_draft: model.code_draft,
    coalesce_key: key,
  }
}

///|
/// 撤销栈追加（超 UNDO_DEPTH 丢弃最旧）。
fn undo_stack_push(
  stack : Array[UndoEntry],
  entry : UndoEntry,
) -> Array[UndoEntry] {
  let copy : Array[UndoEntry] = []
  for existing in stack {
    copy.push(existing)
  }
  copy.push(entry)
  if copy.length() > UNDO_DEPTH {
    let trimmed : Array[UndoEntry] = []
    let mut i = 1
    while i < copy.length() {
      trimmed.push(copy[i])
      i = i + 1
    }
    trimmed
  } else {
    copy
  }
}

///|
/// 撤销栈弹出（返回 (栈顶, 余栈)），空栈返回 None。
fn undo_stack_pop(stack : Array[UndoEntry]) -> (UndoEntry, Array[UndoEntry])? {
  if stack.length() == 0 {
    None
  } else {
    let rest : Array[UndoEntry] = []
    let mut i = 0
    while i < stack.length() - 1 {
      rest.push(stack[i])
      i = i + 1
    }
    Some((stack[stack.length() - 1], rest))
  }
}

///|
fn undo_stack_peek_key(stack : Array[UndoEntry]) -> String? {
  if stack.length() == 0 {
    None
  } else {
    Some(stack[stack.length() - 1].coalesce_key)
  }
}

///|
/// 把变更前快照压入 next 的撤销栈。合并规则：key 非空且与栈顶相同时
/// 跳过（连续同类编辑共享一个还原点）；空 key 永不合并。任何新还原点清空重做栈。
fn undo_commit(next : Model, entry : UndoEntry) -> Model {
  let top_key = match undo_stack_peek_key(next.undo_stack) {
    Some(key) => key
    None => ""
  }
  if entry.coalesce_key != "" && top_key == entry.coalesce_key {
    return next
  }
  {
    ..next,
    undo_stack: undo_stack_push(next.undo_stack, entry),
    redo_stack: [],
  }
}

///|
/// 带撤销点的变更：捕获变更前快照 → 应用变更 → 仅当程序签名真的变化时入栈。
/// no-op 变更（解析失败、非法输入、模板重选同一样例）不产生还原点。
///
/// 「最近修改」也挂在这里：这是**所有** IR 变更的唯一漏斗（拖拽/属性/
/// 文本/增删/模板/对齐都经过它），在各调用点分别记录必然漏掉几条。
/// 判定与撤销点同源——签名没变就是没改，不记。
fn with_undo_point(
  model : Model,
  key : String,
  mutate : (Model) -> Model,
) -> Model {
  with_undo_point_recent(model, key, None, mutate)
}

///|
/// **离散**编辑的撤销点：插控件/删控件/复制/换模板这类「一次点击一步」的
/// 动作。它们不合并（连插三个标签就是三步撤销），但同样要进「最近修改」。
/// 合并与留痕是两件事——用同一个 key 表达会把离散动作粘成一步。
fn with_recent_undo_point(
  model : Model,
  target : String,
  action_key : String,
  mutate : (Model) -> Model,
) -> Model {
  with_undo_point_recent(model, "", Some((target, action_key)), mutate)
}

///|
/// 撤销点 + 最近修改的公共实现。`recent` 为 None 时按可合并 key 推导目标
/// 与动作（move:/resize:/text: 这类连续编辑）。
fn with_undo_point_recent(
  model : Model,
  key : String,
  recent : (String, String)?,
  mutate : (Model) -> Model,
) -> Model {
  let mark = undo_entry_of(model, key)
  let next = mutate(model)
  if @ir.program_signature(next.program) == @ir.program_signature(model.program) {
    next
  } else {
    let (target, action_key) = match recent {
      Some(pair) => pair
      None =>
        if key == "" {
          ("", "")
        } else {
          (recent_target_of(key), recent_action_key(undo_key_prefix(key)))
        }
    }
    let tracked = if target == "" {
      next
    } else {
      push_recent(next, target, text(translator(next), action_key), false)
    }
    undo_commit(tracked, mark)
  }
}

///|
/// 撤销点的 key → 「最近修改」的目标名（`move:按钮` → `按钮`）。
/// key 形如 `<动作>:<对象>`；没有冒号时整个 key 就是目标。
fn recent_target_of(key : String) -> String {
  match key.find(":") {
    // 用字符串视图切片（`substring` 已废弃）：key 是 `动作:对象`
    Some(index) => key[index + 1:].to_owned()
    None => key
  }
}

///|
/// 撤销点的 key → 最近修改的动作文案。前缀是有限的几种编辑动作，
/// 未登记的前缀统一落到「修改」——不静默丢事件，但也不假装认得出。
fn recent_action_key(prefix : String) -> String {
  match prefix {
    "move" => "app.recent.action.move"
    "resize" => "app.recent.action.resize"
    "text" => "app.recent.action.text"
    "items" => "app.recent.action.items"
    "rect" => "app.recent.action.rect"
    "insert" => "app.recent.action.insert"
    "delete" => "app.recent.action.delete"
    "duplicate" => "app.recent.action.duplicate"
    "align" => "app.recent.action.align"
    "rename" => "app.recent.action.rename"
    "handler" => "app.recent.action.handler"
    "template" => "app.recent.action.template"
    _ => "app.recent.action.edit"
  }
}

///|
/// 撤销点 key 的动作前缀（`move:按钮` → `move`）。
fn undo_key_prefix(key : String) -> String {
  match key.find(":") {
    Some(index) => key[:index].to_owned()
    None => key
  }
}

///|
/// 撤销：弹栈恢复快照；运行期活状态按恢复后的程序重置；积木选择态清空。
fn apply_undo(model : Model) -> Model {
  match undo_stack_pop(model.undo_stack) {
    None => model
    Some((entry, rest)) =>
      {
        ..model,
        program: entry.program,
        selected_control: entry.selected_control,
        selected_handler: entry.selected_handler,
        code_draft: entry.code_draft,
        code_error: "",
        drag: None,
        selected_block: -1,
        block_draft: "",
        runtime_values: @studio_lang.initial_values(entry.program),
        runtime_texts: @studio_lang.initial_texts(entry.program),
        runtime_rows: @studio_lang.initial_rows(entry.program),
        runtime_selections: Map([], capacity=4),
        undo_stack: rest,
        redo_stack: undo_stack_push(model.redo_stack, undo_entry_of(model, "")),
      }
  }
}

///|
/// 重做：弹重做栈恢复；撤销栈同步回填当前态。
fn apply_redo(model : Model) -> Model {
  match undo_stack_pop(model.redo_stack) {
    None => model
    Some((entry, rest)) =>
      {
        ..model,
        program: entry.program,
        selected_control: entry.selected_control,
        selected_handler: entry.selected_handler,
        code_draft: entry.code_draft,
        code_error: "",
        drag: None,
        selected_block: -1,
        block_draft: "",
        runtime_values: @studio_lang.initial_values(entry.program),
        runtime_texts: @studio_lang.initial_texts(entry.program),
        runtime_rows: @studio_lang.initial_rows(entry.program),
        runtime_selections: Map([], capacity=4),
        undo_stack: undo_stack_push(model.undo_stack, undo_entry_of(model, "")),
        redo_stack: rest,
      }
  }
}
