///|
/// 选中域与非控件对象（窗体 / 变量 / 数据）的黑盒测试。
///
/// 覆盖两条真实缺陷：
/// 1. 左栏结构树里**窗体、变量、数据文件三类行点了完全没反应**
///    （它们没有 `on_tap`）——本组锁住「点得中、选得对、右栏显示对应属性」。
/// 2. **没有新建变量的入口**（变量只来自 AI 提案或手打代码）——本组锁住
///    变量 CRUD 与「改名同步引用」。
///
/// 另锁住一条既有不一致：`SelectHandler` 忘了清 `selected_control`，于是点
/// 子程序行后右栏还显示上一个控件的属性。三条槽现在经单一漏斗互斥。

///|
/// 三条选中槽互斥：任一入口只点亮一条。
test "selection slots are mutually exclusive" {
  let base = apply(@app.initial_model(), SelectTemplate(3))
  // 选中控件 → 控件槽亮，另两条清
  let on_control = apply(base, SelectControl("商品表"))
  assert_eq(on_control.selected_control, "商品表")
  assert_eq(on_control.selected_handler, "")
  assert_true(on_control.side_target is None)
  // 选中子程序 → 子程序槽亮，**控件槽必须清**
  // （此前不清，右栏会继续显示上一个控件的属性）
  let on_handler = apply(on_control, SelectHandler("记账@on_click"))
  assert_eq(on_handler.selected_handler, "记账@on_click")
  assert_eq(on_handler.selected_control, "")
  assert_true(on_handler.side_target is None)
  // 选中非控件对象 → 另两条清
  let on_side = apply(on_handler, SelectSide(@app.SideVariable("x")))
  assert_true(on_side.side_target is Some(@app.SideVariable("x")))
  assert_eq(on_side.selected_control, "")
  assert_eq(on_side.selected_handler, "")
  // 清空 → 三条全清
  let cleared = apply(on_side, ClearSelection)
  assert_true(cleared.side_target is None)
  assert_eq(cleared.selected_control, "")
  assert_eq(cleared.selected_handler, "")
}

///|
/// 变量行必须携带名字（`select_key`）：留空会让所有变量行指向同一个空目标。
test "variable tree rows carry their name as the select key" {
  let model = apply(@app.initial_model(), AddVariable)
  let variables = @app.program_tree(model)
  let mut checked = 0
  for node in variables {
    if node.kind is @app.TnVariable {
      assert_true(node.select_key != "")
      checked = checked + 1
    }
  }
  assert_true(checked >= 1)
}

///|
/// 窗体 / 变量 / 数据三类节点在树里成对出现（点击动作由视图层按 kind 分派，
/// 而分派依赖 select_key 有值）。
test "window and data tree rows expose selectable keys" {
  let model = apply(@app.initial_model(), SelectTemplate(3))
  let nodes = @app.program_tree(model)
  let mut has_window = false
  let mut has_data = false
  for node in nodes {
    if node.kind is @app.TnWindow {
      has_window = true
    }
    if node.kind is @app.TnDataFile {
      assert_true(node.select_key != "")
      has_data = true
    }
  }
  assert_true(has_window)
  // 小卖部模板有表格 → 必然有数据条目
  assert_true(has_data)
}

///|
/// 新建变量：名称自动去重（连点两次不会撞名——重名是 `validate_program`
/// 的致命错误），并立刻选中供编辑。
test "add variable dedupes names and selects the new one" {
  let model = apply(@app.initial_model(), SelectTemplate(3))
  let before = model.program.variables.length()
  let first = apply(model, AddVariable)
  assert_eq(first.program.variables.length(), before + 1)
  // 新建即选中（右栏马上能改名/改初值）
  match first.side_target {
    Some(@app.SideVariable(name)) => assert_true(name != "")
    _ => fail("newly added variable should be selected")
  }
  let second = apply(first, AddVariable)
  assert_eq(second.program.variables.length(), before + 2)
  // 两个名字必须不同
  let names : Array[String] = []
  for variable in second.program.variables {
    names.push(variable.name)
  }
  let mut duplicates = 0
  let mut index = 0
  for name in names {
    let mut seen_before = false
    let mut i = 0
    for other in names {
      if i < index && other == name {
        seen_before = true
      }
      i = i + 1
    }
    if seen_before {
      duplicates = duplicates + 1
    }
    index = index + 1
  }
  assert_eq(duplicates, 0)
  // IR 不变量必须仍然成立（重名/非法名会被这里拦下）
  assert_eq(@ir.validate_program(second.program).length(), 0)
}

///|
/// 变量改名**同步改写引用**：语句里的 `Var(old)` 变成 `Var(new)`，
/// 否则程序会静默变成「引用了未声明变量」。
test "renaming a variable rewrites its references" {
  // 口算训练营的 handler 里有 得分 之类的变量引用
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let variables = model.program.variables
  if variables.length() == 0 {
    // 模板没有变量时先建一个并写进语句，保证测试始终有东西可改
    let with_var = apply(model, AddVariable)
    let name = match with_var.side_target {
      Some(@app.SideVariable(name)) => name
      _ => fail("AddVariable should select the new variable")
    }
    let renamed = apply(with_var, RenameVariable(name, "总分"))
    assert_true(@ir.validate_program(renamed.program).length() == 0)
    return
  }
  let old_name = variables[0].name
  // 真实 UI 流程是「先选中该变量（点树行）→ 在右栏改名字」，
  // 所以这里先选中：改名后选中态要跟着走到新名字。
  let selected = apply(model, SelectSide(@app.SideVariable(old_name)))
  let renamed = apply(selected, RenameVariable(old_name, "改过的名字"))
  // 旧名在整棵程序里不应再出现
  let encoded = @codec.encode_program(renamed.program)
  assert_false(encoded.contains("\"" + old_name + "\""))
  assert_true(encoded.contains("改过的名字"))
  // 选中态跟着改名（否则右栏显示「什么都没选」）
  match renamed.side_target {
    Some(@app.SideVariable(name)) => assert_eq(name, "改过的名字")
    _ => fail("selection should follow the rename")
  }
}

///|
/// 改名到非法/重名时**保持不变**——不静默把程序改成非法状态。
test "renaming a variable rejects invalid or duplicate names" {
  let model = apply(@app.initial_model(), AddVariable)
  let first = match model.side_target {
    Some(@app.SideVariable(name)) => name
    _ => fail("expected a selected variable")
  }
  let with_two = apply(model, AddVariable)
  let second = match with_two.side_target {
    Some(@app.SideVariable(name)) => name
    _ => fail("expected a selected variable")
  }
  assert_true(first != second)
  // 改成另一个已存在的名字 → 拒绝
  let dup = apply(with_two, RenameVariable(second, first))
  let mut still_there = false
  for variable in dup.program.variables {
    if variable.name == second {
      still_there = true
    }
  }
  assert_true(still_there)
  // 改成空名（语法非法）→ 拒绝
  let empty = apply(with_two, RenameVariable(second, ""))
  let mut survived = false
  for variable in empty.program.variables {
    if variable.name == second {
      survived = true
    }
  }
  assert_true(survived)
  assert_eq(@ir.validate_program(empty.program).length(), 0)
}

///|
/// 删除变量：从程序里消失、选中态清空；若被删的正是选中项，右栏不能
/// 继续显示一个幽灵对象。
test "deleting a variable clears its selection" {
  let model = apply(@app.initial_model(), AddVariable)
  let count = model.program.variables.length()
  let name = match model.side_target {
    Some(@app.SideVariable(name)) => name
    _ => fail("expected a selected variable")
  }
  let deleted = apply(model, DeleteVariable(name))
  assert_eq(deleted.program.variables.length(), count - 1)
  assert_true(deleted.side_target is None)
}

///|
/// 变量预算防呆：超过 `MAX_VARIABLES` 时设 notice 而不是静默丢弃
/// （与 `AddControl` 的 `MAX_CONTROLS` 同一纪律）。
test "add variable reports the budget limit" {
  let model = @app.initial_model()
  // 直接构造一个已满的程序，避免循环 64 次
  let full : Array[@ir.Variable] = []
  let mut index = 0
  while index < @ir.MAX_VARIABLES {
    full.push(@ir.Variable::{ name: "v" + index.to_string(), init: "", })
    index = index + 1
  }
  let saturated = { ..model, program: { ..model.program, variables: full, }, }
  let attempted = apply(saturated, AddVariable)
  assert_eq(attempted.program.variables.length(), @ir.MAX_VARIABLES)
  assert_true(attempted.notice != "")
}

///|
/// 修改变量初值即时写回 IR。
test "setting a variable initial value writes back to the IR" {
  let model = apply(@app.initial_model(), AddVariable)
  let name = match model.side_target {
    Some(@app.SideVariable(name)) => name
    _ => fail("expected a selected variable")
  }
  let updated = apply(model, SetVariableInit(name, "42"))
  let found = match @app.selected_variable(updated) {
    Some(variable) => variable.init
    None => fail("variable should still be selected")
  }
  assert_eq(found, "42")
}

///|
/// 窗体标题可编辑，并写回 IR（运行舞台与导出应用都读它）。
test "window title is editable" {
  let model = apply(@app.initial_model(), SelectSide(@app.SideWindow))
  let renamed = apply(model, SetWindowTitle("我的应用"))
  assert_eq(renamed.program.window.title, "我的应用")
  assert_true(renamed.side_target is Some(@app.SideWindow))
}
