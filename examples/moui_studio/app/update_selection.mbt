///|
/// 选中态的唯一漏斗：控件 / 子程序 / 非控件对象（窗体·变量·数据文件）
/// 三条槽互斥。
///
/// 为什么要有这个文件：选中在 v4 壳里是**三条并存的槽**
/// （`selected_control`、`selected_handler`、`side_target`），而此前每个
/// 入口各写各的字段。直接后果是一个真实缺陷：`SelectHandler` 忘了清
/// `selected_control`，于是点左栏的子程序行之后，右栏仍然显示上一个**控件**
/// 的属性（`context_head` 优先读控件）——用户读到的是「点了没反应」。
///
/// 纪律：**任何改变选中的代码都必须经这里**。新增入口时不会再漏清字段，
/// 因为清字段的动作只写了一遍。

///|
/// 选中一个控件（按名字）。清掉子程序与非控件槽。
///
/// 清子程序槽是刻意的：积木窗格是否在场由 `blocks_pane_wanted` 按
/// 「有没有选中的子程序」判定，两者若同时保留，点了一个控件之后积木窗格
/// 还会挂着（用户已经离开那段子程序了）。设计稿的树也是单选。
pub fn select_control_by_name(model : Model, name : String) -> Model {
  {
    ..model,
    selected_control: name,
    selected_handler: "",
    side_target: None,
    selected_block: -1,
    block_draft: "",
  }
}

///|
/// 选中一个事件子程序（按 `控件@事件` 键）。清掉控件与非控件槽。
///
/// 必须同时清 `selected_control`——否则右栏 `context_head` 优先读控件，
/// 面板会继续显示上一个控件而不是刚点的子程序。
pub fn select_handler_key(model : Model, key : String) -> Model {
  { ..model, selected_control: "", selected_handler: key, side_target: None, }
}

///|
/// 选中一个非控件对象（窗体 / 变量 / 数据文件）。清掉控件与子程序槽。
pub fn select_target(model : Model, target : SideTarget) -> Model {
  {
    ..model,
    selected_control: "",
    selected_handler: "",
    side_target: Some(target),
    selected_block: -1,
    block_draft: "",
  }
}

///|
/// 清空全部三条槽（右栏 `#clearSel`）。
pub fn clear_selection(model : Model) -> Model {
  {
    ..model,
    selected_control: "",
    selected_handler: "",
    side_target: None,
    selected_block: -1,
    block_draft: "",
  }
}

// ============================================================================
// 非控件对象的读取面（右栏属性 + 树行选中态共用）
// ============================================================================

///|
/// 当前选中的变量（None = 没选中变量，或该变量已被删除）。
pub fn selected_variable(model : Model) -> @ir.Variable? {
  match model.side_target {
    Some(SideVariable(name)) => {
      let mut found : @ir.Variable? = None
      for variable in model.program.variables {
        if variable.name == name {
          found = Some(variable)
        }
      }
      found
    }
    _ => None
  }
}

///|
/// 当前选中的数据条目（None = 没选中，或该条目已不存在）。
/// 数据条目是从程序**派生**的（列表/表格控件的行 + 变量集合），
/// 所以判存在要重新派生一次——控件被删掉后条目会消失。
pub fn selected_data_file(model : Model) -> DataFileEntry? {
  match model.side_target {
    Some(SideData(name)) => {
      let mut found : DataFileEntry? = None
      for entry in data_file_entries(model) {
        if entry.name == name {
          found = Some(entry)
        }
      }
      found
    }
    _ => None
  }
}

///|
/// 树行是否处于选中态（三类节点各有各的判据，集中在这里避免视图层
/// 各写一份而漂移）。
pub fn tree_node_selected(
  model : Model,
  kind : TreeNodeKind,
  key : String,
) -> Bool {
  match kind {
    TnControl => model.selected_control == key && key != ""
    TnHandler => model.selected_handler == key && key != ""
    TnWindow =>
      match model.side_target {
        Some(SideWindow) => true
        _ => false
      }
    TnVariable =>
      match model.side_target {
        Some(SideVariable(name)) => name == key
        _ => false
      }
    TnDataFile =>
      match model.side_target {
        Some(SideData(name)) => name == key
        _ => false
      }
    TnGroup => false
  }
}
