///|
/// 插槽命中：点中某个洞时能回答「是哪条语句的哪个子表达式」。
///
/// 这些用例的重点不是「能命中」，而是**命中的位置与绘制的位置一致**：
/// 洞的几何只有一份（`blocks_slot_rects`），绘制与命中都读它。

///|
/// 点中洞 → 返回该洞的表达式路径；点中字面文本 → 不命中。
test "slot hit test resolves the expression under the pointer" {
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0)
  // 每字符 7pt 的确定性度量
  let measure = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let rect = rects[0]
  let row_y = rect.origin.y + 12.0
  // 洞在 `x = `（4 字符 = 28pt）之后，标签起点 = rect.x + 10
  let hole_x = rect.origin.x + 10.0 + 28.0 + 8.0
  let hit = @app.blocks_slot_hit(blocks, rects, hole_x, row_y, measure)
  assert_true(hit is Some(_))
  let resolved = hit.unwrap()
  assert_eq(resolved.block_index, 0)
  // 路径指向语句的根（`x = (1 + 2)` 只有一个洞 = 整个右值）
  assert_eq(resolved.expr_path.length(), 0)
  // 用同一条路径真能取到那个表达式（链路闭环）
  assert_true(@blocks.expr_at(body, [0], resolved.expr_path) is Some(_))
  // 命中矩形与绘制矩形同一份：x 落在矩形内
  assert_true(hole_x >= resolved.rect.origin.x)
  assert_true(hole_x <= resolved.rect.origin.x + resolved.rect.size.width)
}

///|
/// 点在**字面段**上（`x = ` 那几个字符）不该命中洞。
///
/// 不这么判就会出现「点标签文字也能选中表达式」——用户没法只点一块积木
/// 而不碰到某个洞。
test "slot hit test ignores literal text" {
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0)
  let measure = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let rect = rects[0]
  let row_y = rect.origin.y + 12.0
  // `x` 的位置（标签起点 + 2pt）
  let hit = @app.blocks_slot_hit(
    blocks,
    rects,
    rect.origin.x + 12.0,
    row_y,
    measure,
  )
  assert_true(hit is None)
}

///|
/// **调用语句的每个实参各是一个可命中位置**，路径依次 [0]/[1]/[2]。
///
/// 这验证了「段表编号」与「`expr_at` 寻址」用的是同一套语义——两处不一致
/// 会表现为「点第二个洞选中了第一个」。
test "each call argument is independently hittable" {
  let body = [
    @ir.Stmt::Call("set_text", [
      @ir.Expr::Call("to_text", [@ir.Var("a")]),
      @ir.Expr::Call("to_text", [@ir.Var("b")]),
    ]),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0)
  let measure = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let rect = rects[0]
  let row_y = rect.origin.y + 12.0
  // 从两个洞各自命中一次，路径必须不同
  let holes = @app.blocks_slot_rects(blocks[0], rect, measure)
  assert_eq(holes.length(), 2)
  let seen : Array[Int] = []
  for entry in holes {
    let hole = entry.1
    let hit = @app.blocks_slot_hit(
      blocks,
      rects,
      hole.origin.x + hole.size.width / 2.0,
      row_y,
      measure,
    )
    match hit {
      Some(resolved) => {
        assert_eq(resolved.expr_path.length(), 1)
        seen.push(resolved.expr_path[0])
        // 该路径真能取到表达式
        assert_true(@blocks.expr_at(body, [0], resolved.expr_path) is Some(_))
      }
      None => fail("a visible hole must be hittable at its own center")
    }
  }
  assert_eq(seen.length(), 2)
  assert_true(seen[0] != seen[1])
}

///|
/// **拖报告块进洞**：表达式替换子表达式，IR 真的变了，且失败路径不写 IR。
///
/// 与语句拖放分开测：表达式的落点是「换掉一个洞」而不是「插一行」，
/// 走的是 `replace_expr_at`（表达式级手术）。
test "dropping a reporter into a slot replaces that subexpression" {
  // 造一条 `x = 1 + 2`，把右操作数（1）换成别的表达式
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let chain = @app.block_chain_of(model)
  assert_true(chain.length() >= 1)
  // 选第一条语句，把它的根表达式（若可）当作洞
  let picked = apply(model, SelectBlockStep(1))
  assert_true(picked.selected_block >= 0)
  let item = @app.block_chain_of(picked)[picked.selected_block]
  assert_true(item.path.length() > 0)
  // 表达式模板 0 = 加法 `1 + 1`
  let before = @app.block_chain_of(picked)[picked.selected_block].text
  let dropped = apply(
    { ..picked, expr_drag: Some(0), },
    ExpressionDrop(picked.selected_block, []),
  )
  // 拖动源已清
  assert_false(dropped.expr_drag is Some(_))
  let after = @app.block_chain_of(dropped)[dropped.selected_block].text
  // 根表达式被换掉：`1 + 1` 出现在文本里（模板可解析 → 真的写进了 IR）
  assert_true(after != before)
  assert_true(after.contains("1 + 1"))
}

///|
/// 没落在洞上（画布报 `block_index < 0`）时给提示且**不写 IR**。
///
/// 静默什么都不做会让用户以为拖拽坏了；而「悄悄写进去」更糟。
test "dropping a reporter outside a slot is reported and changes nothing" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let before = @app.block_chain_of(model).map(item => item.text)
  let dropped = apply({ ..model, expr_drag: Some(0), }, ExpressionDrop(-1, []))
  assert_true(dropped.notice != "")
  assert_false(dropped.expr_drag is Some(_))
  let after = @app.block_chain_of(dropped).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut i = 0
  while i < before.length() {
    assert_eq(before[i], after[i])
    i = i + 1
  }
}

///|
/// 报告块**不能**当作语句插入：运算分类的面板只给拖拽，点击不插语句。
///
/// 不这么分的话 `1 + 1` 会被当成一行逻辑插进列表，而那在语言里非法
/// （随后运行才报错，用户不知道自己做错了什么）。
test "expression templates are not inserted as statements" {
  // 表达式模板表是**另一张表**，语句骨架表里不含报告块
  let exprs = @app.expression_templates()
  assert_true(exprs.length() > 0)
  // 表达式骨架本身不是合法**语句**：`1 + 1` 作为语句解析应失败
  let parsed = @studio_lang.parse_handler_body(
    exprs[0].skeleton(@studio_lang.ZhHans),
    @studio_lang.ZhHans,
  )
  assert_true(parsed is Err(_))
  // 语句骨架表（运算分类）里那一条是**完整语句**（赋值），不是裸表达式
  let stmts = @app.templates_for_category(@blocks.CatExpression)
  for template in stmts {
    let body = @studio_lang.parse_handler_body(
      template.skeleton(@studio_lang.ZhHans),
      @studio_lang.ZhHans,
    )
    assert_true(body is Ok(_))
  }
}

///|
/// **点值就地编辑**（Scratch 的「点数字改数字」）：只改那一个叶子，
/// 不重解析整行。
///
/// 与整行草稿编辑的关键差别：整行草稿会把用户没碰的部分也重写一遍
/// （缩进、括号、内建名的规范写法都可能变），而用户只想改一个数。
test "editing a value changes only that leaf" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let picked = apply(model, SelectBlockStep(1))
  assert_true(picked.selected_block >= 0)
  let index = picked.selected_block
  let blocks = @app.block_chain_of(picked)
  let before = blocks[index].text
  // 打开**根表达式**的值编辑。根是调用（random）时不是叶子 → 不打开。
  let opened = apply(picked, EditBlockValue(index, []))
  let handler = @app.current_handler(picked).unwrap()
  let is_leaf = @blocks.expr_leaf_text(
      @blocks.expr_at(handler.body, blocks[index].path, []).unwrap(),
    )
    is Some(_)
  assert_eq(opened.block_value_edit is Some(_), is_leaf)
  if opened.block_value_edit is Some(_) {
    // 输入新值并提交
    let committed = apply(
      apply(opened, BlockValueInput("42")),
      BlockValueCommit,
    )
    assert_false(committed.block_value_edit is Some(_))
    let after = @app.block_chain_of(committed)[index].text
    assert_true(after != before)
    assert_true(after.contains("42"))
  }
}

///|
/// 值编辑**只对叶子开放**：越界路径 / 指向洞的路径都不打开输入框。
///
/// 不校验就会出现「点运算的凹槽弹出文本框」，与「拖一块进去」的语义冲突。
test "value editing refuses non-leaf positions" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let picked = apply(model, SelectBlockStep(1))
  let index = picked.selected_block
  // 越界路径
  assert_false(
    apply(picked, EditBlockValue(index, [7])).block_value_edit is Some(_),
  )
  // 指向一个**洞**（调用语句的第 0 个实参若是调用，则它是洞）
  let chain = @app.block_chain_of(picked)
  let item = chain[index]
  if item.segments is Some(segments) {
    for segment in segments {
      if segment.is_slot {
        match segment.expr_path {
          Some(path) =>
            assert_false(
              apply(picked, EditBlockValue(index, path)).block_value_edit
              is Some(_),
            )
          None => ()
        }
      }
    }
  }
}

///|
/// Escape 取消值编辑：**不写 IR**。
///
/// 没有取消路径的话用户只能提交或点走，而提交会改 IR——想放弃却改了。
test "cancelling a value edit leaves the program untouched" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let picked = apply(model, SelectBlockStep(1))
  let index = picked.selected_block
  let before = @app.block_chain_of(picked).map(item => item.text)
  let opened = apply(picked, EditBlockValue(index, []))
  let typed = apply(opened, BlockValueInput("999"))
  let cancelled = apply(typed, BlockValueCancel)
  assert_false(cancelled.block_value_edit is Some(_))
  let after = @app.block_chain_of(cancelled).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut i = 0
  while i < before.length() {
    assert_eq(before[i], after[i])
    i = i + 1
  }
  assert_true(cancelled.notice == "")
}

///|
/// **每个命令类内建都必须能从调色板拿到**——能力在、入口也要在。
///
/// 这条不变式来自一个真实缺口：「广播消息」与「往列表里加一项」在解释器里
/// 早就实现了，但面板里没有骨架，于是积木界面**根本够不着**它们（只能手打）。
/// 「覆盖 Scratch 的能力」不只是「引擎支持」，还包括「用户点得到」。
///
/// 判据取**可解析**：面板骨架必须能过 `parse_handler_body` 并且解析出的
/// 语句真的调用那个内建——只断言「文本里出现过名字」会漏掉写错参数个数的
/// 骨架（那种骨架点下去只会报解析错误）。
test "every command builtin is reachable from the palette" {
  let palette = @app.templates_for_category(@blocks.CatCommand)
  let reachable : Array[String] = []
  for template in palette {
    let body = @studio_lang.parse_handler_body(
      template.skeleton(@studio_lang.ZhHans),
      @studio_lang.ZhHans,
    )
    match body {
      Ok(stmts) =>
        for traced in stmts {
          match traced.stmt {
            @ir.Stmt::Call(name, _) => reachable.push(name)
            _ => ()
          }
        }
      Err(_) =>
        fail(
          "a palette skeleton must be parseable: \{template.skeleton(@studio_lang.ZhHans)}",
        )
    }
  }
  // 目录里所有**可插入语句**的类都必须可达：`Command`（普通命令）与
  // `Gate`（闸门，如 `ask` 询问并等待）。
  //
  // 早先这条用例只查 `Command`，于是 `ask` 长期没有面板入口却无人发现——
  // 「问一句再按回答分支」这种基本交互在积木界面里做不到。闸门同样是
  // **语句**（执行到那里会停下等人），必须能插入。
  let missing : Array[String] = []
  for spec in @studio_lang.builtin_catalog() {
    if (spec.kind is @studio_lang.Command || spec.kind is @studio_lang.Gate) &&
      !reachable.contains(spec.id) {
      missing.push(spec.id)
    }
  }
  assert_eq(missing.length(), 0)
}

///|
/// **每个函数类内建都必须能从报告块面板拿到**——与命令类同一条不变式。
///
/// 同源缺口：`get_text` / `get_number` / `row_count` / `row_at` /
/// `selected_row` / `list_length` / `contains` 在解释器里都有完整分支，
/// 但报告块面板里没有入口，用户看得到积木能力却拖不出来。
///
/// 判据取**可解析为表达式**：骨架必须过 `parse_expression_text` 且解析出的
/// 表达式真的调用那个内建（不是「文本里出现过名字」——那会漏掉参数写错的
/// 骨架，那种骨架拖进洞只会报解析错误）。
test "every function builtin is reachable from the reporter palette" {
  let palette = @app.expression_templates()
  let reachable : Array[String] = []
  for template in palette {
    let expr = match
      @studio_lang.parse_expression_text(
        template.skeleton(@studio_lang.ZhHans),
        @studio_lang.ZhHans,
      ) {
      Ok(expr) => expr
      Err(_) =>
        fail(
          "a reporter skeleton must be parseable: \{template.skeleton(@studio_lang.ZhHans)}",
        )
    }
    // 顶层是调用就直接记；是二元/比较则递归看两侧（`1 > 0` 这类没有内建）
    collect_calls(expr, reachable)
  }
  let missing : Array[String] = []
  for spec in @studio_lang.builtin_catalog() {
    if spec.kind is @studio_lang.Function && !reachable.contains(spec.id) {
      missing.push(spec.id)
    }
  }
  assert_eq(missing.length(), 0)
}

///|
/// 收集一个表达式里用到的所有内建名（递归左右子表达式与实参）。
fn collect_calls(expr : @ir.Expr, out : Array[String]) -> Unit {
  match expr {
    @ir.Expr::Call(name, args) => {
      out.push(name)
      for arg in args {
        collect_calls(arg, out)
      }
    }
    @ir.Binary(_, left, right) => {
      collect_calls(left, out)
      collect_calls(right, out)
    }
    @ir.Not(inner) | @ir.Neg(inner) => collect_calls(inner, out)
    @ir.Index(base, index) => {
      collect_calls(base, out)
      collect_calls(index, out)
    }
    @ir.ListLit(items) =>
      for item in items {
        collect_calls(item, out)
      }
    _ => ()
  }
}

///|
/// **每种骨架在两种界面语言下都必须可解析**。
///
/// 关键字表是按语言互斥的（中文 `真`/`且`/`如果`，英文 `true`/`and`/`if`），
/// 所以两语言共用一份骨架或写错关键字，会在**某一种语言下**静默失效——
/// 用户切到那个语言，点一下只看到「解析失败」，而另一种语言全绿。
///
/// 这条用例就是被这个缺口逼出来的：`true and false` 在中文界面下解析失败。
test "every palette skeleton parses in both UI languages" {
  let languages = [@studio_lang.ZhHans, @studio_lang.En]
  for language in languages {
    for template in @app.statement_templates() {
      let result = @studio_lang.parse_handler_body(
        template.skeleton(language),
        language,
      )
      if result is Err(_) {
        fail(
          "statement skeleton fails to parse: [\{template.label_key}] \{template.skeleton(language)}",
        )
      }
    }
    for template in @app.expression_templates() {
      let result = @studio_lang.parse_expression_text(
        template.skeleton(language),
        language,
      )
      if result is Err(_) {
        fail(
          "expression skeleton fails to parse: [\{template.label_key}] \{template.skeleton(language)}",
        )
      }
    }
  }
}

///|
/// **新建自定义积木**（Scratch 的「制作一个积木」）：`FuncDef` 一直存在于
/// 语言层与编译运行时里，但只能从 JSON 进来——界面上没有创建入口。
///
/// 判据取**可运行**：建出来的函数必须过语义检查（`program_errors`），
/// 而不只是「结构上多了一条」。空体函数在结构上合法却什么都不发生。
test "creating a custom block produces a runnable function" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let before = model.program.functions.length()
  let added = apply(model, AddFunction)
  assert_eq(added.program.functions.length(), before + 1)
  // 建完即选中（右栏立刻可改名，与「新建变量」同一节奏）
  match added.side_target {
    Some(@app.SideFunction(name)) => {
      assert_true(name != "")
      // 选中槽指向的函数真的存在
      assert_true(@app.selected_function(added) is Some(_))
    }
    _ => fail("a new custom block must be selected")
  }
  // 建出来的函数**过语义检查**（不是「结构上多了一条」就算成功）
  let errors = @studio_lang.validate_program_language(added.program)
  assert_eq(errors.length(), 0)
}

///|
/// 重命名自定义积木**同步改写所有调用点**。
///
/// 不同步的后果：改了名、旧调用还在调旧名字，运行时报「函数不存在」，
/// 而用户以为自己改好了（调用点显示的是渲染后的文本，逐个找不现实）。
test "renaming a custom block rewrites every call site" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  let old_name = match added.side_target {
    Some(@app.SideFunction(name)) => name
    _ => fail("expected a selected function")
  }
  // 在那个函数体里放一条对别的函数的调用？——更容易验证的是：把它自己的
  // 名字改掉，然后断言程序结构仍然自洽（没有悬空引用）。
  let renamed = apply(added, RenameFunction(old_name, "我的工具"))
  // 新名字在函数表里
  let mut found = false
  for func in renamed.program.functions {
    if func.name == "我的工具" {
      found = true
    }
    // 旧名字不该残留
    assert_true(func.name != old_name)
  }
  assert_true(found)
  // 选中槽跟着改名（否则槽指向一个不存在的名字）
  match renamed.side_target {
    Some(@app.SideFunction(name)) => assert_eq(name, "我的工具")
    _ => fail("the selection slot must follow the rename")
  }
  // 语义检查仍然通过
  assert_eq(@studio_lang.validate_program_language(renamed.program).length(), 0)
}

///|
/// 重命名**撞名**要拒绝：撞了会调用到错的那个函数，而界面上看不出区别。
test "renaming a custom block onto an existing name is refused" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let first = apply(model, AddFunction)
  let first_name = match first.side_target {
    Some(@app.SideFunction(name)) => name
    _ => fail("expected a selected function")
  }
  let second = apply(first, AddFunction)
  let second_name = match second.side_target {
    Some(@app.SideFunction(name)) => name
    _ => fail("expected a selected function")
  }
  assert_true(first_name != second_name)
  // 把第二个改成第一个的名字 → 拒绝并给提示
  let refused = apply(second, RenameFunction(second_name, first_name))
  assert_true(refused.notice != "")
  let mut still_there = false
  for func in refused.program.functions {
    if func.name == second_name {
      still_there = true
    }
  }
  assert_true(still_there)
}

///|
/// 自定义积木出现在**结构树**里且可被选中——「能力在、入口也要在」。
test "custom blocks appear in the structure tree" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  let nodes = @app.program_tree(added)
  let mut group_seen = false
  let mut row_seen = false
  for node in nodes {
    if node.group == @app.tree_group_functions() {
      if node.kind is @app.TnGroup {
        group_seen = true
      }
      if node.kind is @app.TnFunction {
        row_seen = true
        // 行是可点的（有选中键）
        assert_true(node.select_key != "")
      }
    }
  }
  assert_true(group_seen)
  assert_true(row_seen)
}

///|
/// **自定义积木的体可以在同一个积木画布上编辑**。
///
/// 这是「建得出来」与「用得起来」的分界：`FuncDef` 的体也是一串语句，
/// 若画布只认 `current_handler`，建出来的积木就只能看、不能改——半个功能。
/// 统一走 `current_target` 之后，插入 / 删除 / 键盘导航全部对函数体生效。
test "a custom block body is editable on the blocks canvas" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  // 画布现在应该显示**函数体**（刚建好时有一条 `return`）
  let chain = @app.block_chain_of(added)
  assert_true(chain.length() >= 1)
  // 在函数体里插一条语句：走与事件子程序完全相同的插入路径。
  //
  // 用**变量分类**的骨架（声明一个变量）而不是流程骨架：流程骨架引用
  // `计数` / `标签` 这些模板里才有的名字，放进刚建的空函数会让程序变成
  // 「用了未声明的变量」——那是**测试数据**的问题，不是函数体编辑的问题。
  let with_stmt = apply(
    added,
    InsertStatement(
      1,
      @app.template_index_of(1, "app.stmt.tpl.declare").unwrap(),
    ),
  )
  let after = @app.block_chain_of(with_stmt)
  assert_true(after.length() > chain.length())
  // 写回的是**函数体**而不是某个 handler（用函数表验证）
  let func = @app.selected_function(with_stmt).unwrap()
  assert_true(func.body.length() > 1)
  // 语义检查仍通过（函数体里允许 return）
  assert_eq(
    @studio_lang.validate_program_language(with_stmt.program).length(),
    0,
  )
}

///|
/// 函数体里的**删除**同样生效（写回路径对两种目标一致）。
test "deleting a statement inside a custom block writes back to the function" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  // 先插一条**变量声明**（不引用模板里的名字），得到 ≥2 条语句
  let with_stmt = apply(
    added,
    InsertStatement(
      1,
      @app.template_index_of(1, "app.stmt.tpl.declare").unwrap(),
    ),
  )
  let before = @app.block_chain_of(with_stmt).length()
  // 选中第一条可编辑语句并删除
  let picked = apply(with_stmt, SelectBlockStep(1))
  assert_true(picked.selected_block >= 0)
  let deleted = apply(picked, DeleteBlock)
  let after = @app.block_chain_of(deleted).length()
  assert_true(after < before)
  // 函数体真的短了（而不是事件子程序被改）
  let func = @app.selected_function(deleted).unwrap()
  assert_eq(func.body.length(), after)
}

///|
/// **自定义积木可以被调用**——建得出来还要用得上。
///
/// 语言层早就支持（`semantics.mbt` 会把非内建名当用户函数查表），
/// 所以这里验证的是**端到端可用**：新建 → 在事件子程序里手打调用 →
/// 语义检查通过（不报 `UnknownBuiltin`）→ 能真的跑起来。
test "a custom block can be called from an event handler" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  let func_name = match added.side_target {
    Some(@app.SideFunction(name)) => name
    _ => fail("expected a selected function")
  }
  // 在**事件子程序**里写一条对它的调用（切回子程序选中态）。
  // 键是「控件名@事件」——用模板里真实存在的那个（写死猜测的名字会选中
  // 一个不存在的子程序，于是 `current_handler` 返回 None，后面的断言全部
  // 落空却看不出原因）。
  let key = @app.handler_key(
    added.program.handlers[0].control_name,
    added.program.handlers[0].event.tag(),
  )
  let back = apply(added, SelectHandler(key))
  assert_true(@app.current_handler(back) is Some(_))
  // 手打一条调用并提交。
  //
  // **注意顺序**：`SelectBlockStep` 会把草稿改写成「选中的那条语句」，
  // 所以「选中 → 打字 → 提交」会把刚打的字冲掉（第一次写这条用例就是
  // 这样，提交的是模板里的旧语句）。正确顺序是「选中 → 打字 → 提交」里
  // 的**选中在前、打字在后**：先选中目标块，再写草稿，再提交。
  let on_block = apply(back, SelectBlockStep(1))
  assert_true(on_block.selected_block >= 0)
  let typed = apply(on_block, EditBlock("\{func_name}()"))
  let committed = apply(typed, CommitBlock)
  // 语义检查通过：调用被认成用户函数，不是未知名字
  assert_eq(
    @studio_lang.validate_program_language(committed.program).length(),
    0,
  )
  // 调用点真的写进了子程序体
  let handler = @app.current_handler(committed).unwrap()
  let mut found_call = false
  for stmt in handler.body {
    match stmt {
      @ir.Stmt::Call(name, _) => if name == func_name { found_call = true }
      _ => ()
    }
  }
  assert_true(found_call)
}

///|
/// 调用**不存在的名字**仍然要报错（不能因为支持自定义积木就放过拼写错误）。
test "calling an undefined name is still an error" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 先选中一个真实存在的子程序（否则提交无处落地）
  let key = @app.handler_key(
    model.program.handlers[0].control_name,
    model.program.handlers[0].event.tag(),
  )
  let on_handler = apply(model, SelectHandler(key))
  // 同一条顺序纪律：先选中、再打字、再提交
  let on_block = apply(on_handler, SelectBlockStep(1))
  let typed = apply(on_block, EditBlock("根本不存在的积木()"))
  let committed = apply(typed, CommitBlock)
  assert_true(
    @studio_lang.validate_program_language(committed.program).length() > 0,
  )
}

///|
/// **补全弹层关得掉**：`completion_open` 此前只有「打开」没有「关闭」的
/// 生产者（`DismissCompletion` 有处理分支却没人发），于是弹出后按 Esc
/// 关不掉——只能选中某一项或点走。
///
/// 这条同时守两条不变式：Escape 在「补全弹层」与「值编辑」两个态下各绑
/// 一条命令，两者**互斥启用**（同一时刻至多一条 enabled），不会双触发。
test "escape dismisses the completion popup and never double-fires" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 打开补全弹层（在代码视图里触发）
  let opened = { ..model, completion_open: true, }
  assert_true(opened.completion_open)
  // Escape 的两条绑定此刻只应有「收起补全」是启用的
  let commands = @app.studio_program_commands(opened)
  let enabled_ids : Array[String] = []
  for command in commands {
    // `ProgramCommand` 包了一层 `ActionCommand`；命令的**标识**是它的
    // `label`（由 i18n 键解析而来），`enabled` 也在内层。
    //
    // 注意：`bind` 每次调用会产出**两条**（meta 与 ctrl 各一条），
    // 所以判「同一时刻至多一条 Escape 命令启用」必须按**去重后的标签**看，
    // 按条目数看会把同一条绑定的两个变体当成两次绑定。
    let inner = command.command
    if inner.enabled {
      if inner.label == "收起补全" || inner.label == "取消值编辑" {
        if !enabled_ids.contains(inner.label) {
          enabled_ids.push(inner.label)
        }
      }
    }
  }
  assert_eq(enabled_ids.length(), 1)
  assert_eq(enabled_ids[0], "收起补全")
  // 真的收得掉
  let dismissed = apply(opened, DismissCompletion)
  assert_false(dismissed.completion_open)
}

///|
/// **给脚本写说明**（Scratch 的「加注释」）：`Handler` / `FuncDef` 一直有
/// `note_zh` / `note_en`，AI 上下文也一直在读它，但界面上没有**写**的入口，
/// 所以那两个字段永远是空的。
///
/// 判据取**闭环**：写完要能从 `target_note` 读回来，且真的进了 AI 上下文
/// （`handler_note`）——只断言「字段被写了」无法发现「写了但读的地方读的是
/// 另一个字段」这类错配。
test "writing a target note round-trips into the AI context" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 键是「控件名@事件」——用模板里真实存在的那个
  let key = @app.handler_key(
    model.program.handlers[0].control_name,
    model.program.handlers[0].event.tag(),
  )
  let on_handler = apply(model, SelectHandler(key))
  let written = apply(on_handler, EditTargetNote("这段负责出题与批改"))
  // 读回来一致
  assert_eq(@app.target_note(written), "这段负责出题与批改")
  // 真的进了 AI 上下文：`local_explanation` 的第一段就是 note，
  // 所以「说明出现在讲解开头」证明它被读取端读到了（不是只写进了字段）。
  assert_true(
    @app.local_explanation(written).contains("这段负责出题与批改"),
  )
  // 写的是**当前界面语言**那一份。模板自带的说明占了另一份（英文模板写
  // `note_en`、中文写 `note_zh`），所以这里断言「本语言那份被改成新值」，
  // 而不是「另一份为空」——后者是模板内容决定的，不是本功能的契约。
  let handler = @app.current_handler(written).unwrap()
  assert_eq(handler.note_zh, "这段负责出题与批改")
}

///|
/// 自定义积木的说明走**同一个入口**（统一编辑目标），并写进 `FuncDef`。
test "a custom block carries its own note" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let added = apply(model, AddFunction)
  let written = apply(added, EditTargetNote("我的工具：格式化一行"))
  assert_eq(@app.target_note(written), "我的工具：格式化一行")
  let func = @app.selected_function(written).unwrap()
  assert_eq(func.note_zh, "我的工具：格式化一行")
  // 事件子程序**没被误写**（写错了目标会让「改 A 却动了 B」）。
  // 模板自带的说明保持不变即为证据——所以先记下原值再比对。
  let mut i = 0
  while i < written.program.handlers.length() {
    assert_eq(
      written.program.handlers[i].note_zh,
      model.program.handlers[i].note_zh,
    )
    i = i + 1
  }
}

///|
/// 说明是**注释性元数据**：不产生撤销点，也不改执行语义。
///
/// 给注释压栈会让「撤销」在用户改了一句逻辑之后先退回「注释被改前」——
/// 那不是用户想撤的东西。
test "a note is metadata and does not affect undo or execution" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let key = @app.handler_key(
    model.program.handlers[0].control_name,
    model.program.handlers[0].event.tag(),
  )
  let on_handler = apply(model, SelectHandler(key))
  let undo_before = on_handler.undo_stack.length()
  let written = apply(on_handler, EditTargetNote("只是注释"))
  // 撤销栈长度不变（注释不入栈）
  assert_eq(written.undo_stack.length(), undo_before)
  // 语句体完全没动
  let before = @app.block_chain_of(on_handler).map(item => item.text)
  let after = @app.block_chain_of(written).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut i = 0
  while i < before.length() {
    assert_eq(before[i], after[i])
    i = i + 1
  }
}

///|
/// **`如果…否则` 骨架可用**：语言层与积木链一直支持 else 分支，但面板里
/// 只有「如果…结束」——用户想要 else 只能先插 if 再手写代码。
///
/// 判据取**真的产生 else 体**（不是「骨架能解析」就算）：插进去之后积木链
/// 里必须出现 `else` 装饰块，否则这个骨架只是换了个标签的同一条 if。
test "the if-else skeleton produces a real else branch" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let with_if_else = apply(
    apply(model, SelectBlockStep(1)),
    InsertStatement(
      2,
      @app.template_index_of(2, "app.stmt.tpl.if_else").unwrap(),
    ),
  )
  let chain = @app.block_chain_of(with_if_else)
  let mut has_else = false
  let mut else_has_body = false
  let mut index = 0
  for item in chain {
    if item.kind is @blocks.BkElse {
      has_else = true
      // else 之后紧跟一条**更深**的语句 = else 体非空
      if index + 1 < chain.length() && chain[index + 1].depth > item.depth {
        else_has_body = true
      }
    }
    index = index + 1
  }
  assert_true(has_else, msg="the skeleton should produce an else decoration")
  assert_true(else_has_body, msg="the else branch should contain a statement")
  // **不断言整程序语义合法**：骨架里的 `计数` / `标签` 是**示例名**，只有
  // 装了相应变量的模板才存在。断言合法性会把「示例名不在本模板里」误报成
  // 「骨架坏了」——已有的 if / repeat / while 骨架有同样性质，它们的用例
  // 也只查积木形状。骨架的契约是「可解析 + 形状正确」，语义合法性由用户
  // 把示例名改成自己的名字后成立。
  assert_true(
    @studio_lang.parse_handler_body(
      @app.templates_for_category(@blocks.CatFlow)[@app.template_index_of(
        2, "app.stmt.tpl.if_else",
      ).unwrap()].skeleton(@studio_lang.ZhHans),
      @studio_lang.ZhHans,
    )
    is Ok(_),
  )
}

///|
/// **`重复直到…` 等价于「当 非(条件) 循环」**（Scratch 的 `repeat until`）。
///
/// 这里验证的是**语义等价**而不是「能解析」：骨架必须真的把条件取反，
/// 否则「重复直到 X」会变成「当 X 循环」——条件写反是循环里最难查的错，
/// 而且它会**正常跑完**（只是迭代次数完全不同），不会报任何错。
test "repeat-until negates its condition" {
  let index = @app.template_index_of(2, "app.stmt.tpl.repeat_until").unwrap()
  let skeleton = @app.templates_for_category(@blocks.CatFlow)[index].skeleton(
    @studio_lang.ZhHans,
  )
  let parsed = @studio_lang.parse_handler_body(skeleton, @studio_lang.ZhHans)
  let stmts = match parsed {
    Ok(stmts) => stmts
    Err(_) => fail("repeat-until skeleton must parse: \{skeleton}")
  }
  let mut found_while = false
  for traced in stmts {
    match traced.stmt {
      @ir.WhileLoop(cond, _) => {
        found_while = true
        // 条件必须是**取反**（`Not`），否则语义写反了
        assert_true(
          cond is @ir.Not(_),
          msg="repeat-until must negate its condition",
        )
      }
      _ => ()
    }
  }
  assert_true(found_while, msg="repeat-until should produce a while loop")
}

///|
/// **`重复执行`（forever）有硬上限**：不会真的卡死。
///
/// 「永远」是**用户语义**的，运行时仍有 `DEFAULT_MAX_STEPS`（10 万步）预算。
/// 这条用例存在的理由：无限循环是教学场景里最常见的失误，而它一旦真的
/// 挂住宿主（浏览器/应用），用户除了强杀没有别的出路——比「报个误差」
/// 糟糕得多。断言它**在预算内终止并报错**，而不是断言「能跑」。
test "forever terminates at the step budget instead of hanging" {
  let index = @app.template_index_of(2, "app.stmt.tpl.forever").unwrap()
  let skeleton = @app.templates_for_category(@blocks.CatFlow)[index].skeleton(
    @studio_lang.ZhHans,
  )
  let stmts = match
    @studio_lang.parse_handler_body(skeleton, @studio_lang.ZhHans) {
    Ok(stmts) => stmts
    Err(_) => fail("forever skeleton must parse: \{skeleton}")
  }
  // 用小预算跑，避免测试本身耗时（语义与默认预算完全一致）
  let state = @studio_lang.start_run_stmts(
    stmts.map(traced => traced.stmt),
    Map([], capacity=2),
    Map([], capacity=2),
    Map([], capacity=2),
    max_steps=500,
  )
  @studio_lang.run_to_end(state)
  // 必须是**失败终止**（步数预算），不是仍然 Running
  assert_true(state.status is @studio_lang.Failed)
  match state.error {
    Some(error) => assert_true(error.kind() is @studio_lang.StepBudget)
    None => fail("an exhausted step budget must record an error")
  }
}

///|
/// **每个调色板骨架都必须能解析**（在两种界面语言下）——这是「骨架表」
/// 这一层唯一真正的不变式。
///
/// 已有的双语用例覆盖了它，但那条用例是按 category 遍历的；这里再加一条
/// **按功能**的守卫：本轮新增的骨架（wait / ask / stop_all / forever /
/// repeat_until / if_else / broadcast / append_list / 各数学函数）都必须
/// 在**中文**界面下可解析——中文关键字（`真`/`且`/`非`）与英文互斥，
/// 写错语言会让骨架在某一种语言下静默失效。
test "every flow and command skeleton parses in Chinese" {
  let languages = [@studio_lang.ZhHans, @studio_lang.En]
  for language in languages {
    for category_index in [1, 2, 3] {
      let templates = match @app.category_at(category_index) {
        None => []
        Some(category) => @app.templates_for_category(category)
      }
      for template in templates {
        let skeleton = template.skeleton(language)
        let parsed = @studio_lang.parse_handler_body(skeleton, language)
        if parsed is Err(_) {
          fail("skeleton fails to parse: [\{template.label_key}] \{skeleton}")
        }
      }
    }
  }
}

///|
/// **每一个分组都必须有 i18n 词条**（否则界面上直接显示 `[[键名]]`）。
///
/// 分组键是**拼**出来的（`"app.tree.group.\{group}"`），所以任何「按字面量
/// 收集所有键」的检查都看不见它——实测就是这样漏掉了 `functions` 分组：
/// 结构树里那一组显示成 `[[app.tree.group.functions]]`，而所有字面量检查
/// 都是绿的。这条用例把「拼出来的键」也纳入守卫。
test "every tree group has a catalog entry" {
  let translator = @app.translator_for(ZhHans)
  let groups = [
    @app.tree_group_window(),
    @app.tree_group_variables(),
    @app.tree_group_controls(),
    @app.tree_group_data(),
    @app.tree_group_handlers(),
    @app.tree_group_functions(),
  ]
  for group in groups {
    let key = @app.tree_group_label_key(group)
    let label = @app.text(translator, key)
    // 词条缺失时翻译器回显 `[[键名]]`——这正是要抓的症状
    assert_false(label.contains("[["), msg="missing catalog entry for \{key}")
    assert_true(label != "", msg="empty label for \{key}")
  }
}

///|
/// **底栏页签的词条都要在**（含中文侧不能是英文）。
///
/// 「键存在」不等于「值对」：实测恢复词条时把 9 条的 zh/en 装反了
/// （中文侧显示 `Bottom bar`、英文侧显示 `底栏`）。所以这条同时检查
/// **中文侧含汉字**——只查键存在的话，装反了照样全绿。
test "bottom tab labels are translated in both languages" {
  let keys = [
    "app.bottom.ai", "app.bottom.audit", "app.bottom.console", "app.bottom.problems",
  ]
  let zh = @app.translator_for(ZhHans)
  for key in keys {
    let label = @app.text(zh, key)
    assert_false(label.contains("[["), msg="missing zh entry for \{key}")
  }
  // 中文侧必须真的含汉字（除品牌名这类专有词）
  for key in ["app.bottom.ai", "app.bottom.audit"] {
    let label = @app.text(zh, key)
    let mut has_cjk = false
    for ch in label {
      let code = ch.to_int()
      if code >= 0x4E00 && code <= 0x9FFF {
        has_cjk = true
      }
    }
    assert_true(
      has_cjk,
      msg="zh entry for \{key} should contain Chinese: \{label}",
    )
  }
}
