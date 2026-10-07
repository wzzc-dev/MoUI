///|
/// blocks 测试：spec 覆盖、积木链展开、聚光灯文本与审计细节同源。

///|
fn nested_body() -> Array[@ir.Stmt] {
  [
    @ir.Declare("人数", @ir.Call("row_count", [@ir.Var("名单")])),
    @ir.If(
      @ir.Binary(@ir.Gt, @ir.Var("人数"), @ir.IntLit(0)),
      [@ir.Call("message_box", [@ir.StrLit("有人")])],
      [],
      [@ir.Call("message_box", [@ir.StrLit("没人")])],
    ),
    @ir.CountLoop(@ir.IntLit(3), Some("i"), [
      @ir.Call("append_row", [@ir.Var("名单"), @ir.Var("i")]),
      @ir.Break,
    ]),
  ]
}

///|
test "every builtin has a block spec" {
  for spec in @studio_lang.builtin_catalog() {
    match @blocks.builtin_block_spec(spec.id) {
      Some(block) => {
        assert_eq(block.arity, spec.arity)
        assert_eq(@blocks.builtin_param_types(spec.id).length(), spec.arity)
      }
      None => fail("内建 \{spec.id} 缺少积木 spec")
    }
  }
  assert_true(@blocks.builtin_block_spec("不存在的内建") is None)
  assert_eq(@blocks.builtin_param_types("set_text").length(), 2)
  assert_true(@blocks.builtin_result_type("get_number") is @blocks.VtNumber)
  assert_true(@blocks.builtin_result_type("contains") is @blocks.VtBool)
  assert_true(@blocks.builtin_result_type("get_text") is @blocks.VtText)
  assert_true(@blocks.builtin_result_type("submit_data") is @blocks.VtAny)
}

///|
test "block chain expands control flow with depth" {
  let items = @blocks.block_chain(nested_body())
  // declare + if(then/else 各一命令 + end) + count(两命令 + end) = 10
  assert_eq(items.length(), 10)
  assert_true(items[0].kind is @blocks.BkDeclare)
  assert_eq(items[0].depth, 0)
  assert_true(items[1].kind is @blocks.BkIf)
  assert_eq(items[1].text, "(人数 > 0)")
  assert_true(items[2].kind is @blocks.BkCall)
  assert_eq(items[2].depth, 1)
  assert_true(items[3].kind is @blocks.BkElse)
  assert_eq(items[3].depth, 0)
  assert_true(items[4].kind is @blocks.BkCall)
  assert_eq(items[4].depth, 1)
  assert_true(items[5].kind is @blocks.BkEnd)
  assert_true(items[6].kind is @blocks.BkCountLoop)
  assert_true(items[7].kind is @blocks.BkCall)
  assert_true(items[8].kind is @blocks.BkBreak)
  assert_eq(items[8].depth, 1)
  assert_true(items[9].kind is @blocks.BkEnd)
}

///|
test "block text matches interpreter audit detail for spotlight" {
  // 聚光灯对暗号：积木链文本 == 审计细节（同一 canonical_call_text）
  let program : @ir.StudioProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
        props: @ir.ControlProps::default(),
        id: 1,
        kind: @ir.Button,
        name: "按钮",
        text: "go",
        x: 0,
        y: 0,
        width: 80,
        height: 30,
        items: [],
      },
      @ir.Control::{
        props: @ir.ControlProps::default(),
        id: 2,
        kind: @ir.ListBox,
        name: "名单",
        text: "",
        x: 0,
        y: 40,
        width: 80,
        height: 60,
        items: ["a", "b"],
      },
    ],
    variables: [],
    handlers: [
      @ir.Handler::{
        control_name: "按钮",
        event: @ir.OnClick,
        note_zh: "n",
        note_en: "n",
        body: [
          @ir.Declare("人数", @ir.Call("row_count", [@ir.Var("名单")])),
          @ir.Call("message_box", [@ir.Call("to_text", [@ir.Var("人数")])]),
        ],
      },
    ],
    functions: [],
    structs: [],
    enums: [],
  }
  let texts = @studio_lang.initial_texts(program)
  let rows = @studio_lang.initial_rows(program)
  let state = @studio_lang.start_run_stmts(
    program.handlers[0].body,
    texts,
    @studio_lang.initial_values(program),
    rows,
  )
  @studio_lang.run_to_end(state)
  assert_true(state.status is @studio_lang.Completed)
  let chain = @blocks.block_chain(program.handlers[0].body)
  let audit_texts : Array[String] = []
  for record in state.audit {
    audit_texts.push(record.detail)
  }
  assert_true(audit_texts.contains("人数 = row_count(名单)"))
  assert_true(audit_texts.contains("message_box(to_text(人数))"))
  let chain_texts : Array[String] = []
  for item in chain {
    if item.text != "" {
      chain_texts.push(item.text)
    }
  }
  assert_true(chain_texts.contains("人数 = row_count(名单)"))
  assert_true(chain_texts.contains("message_box(to_text(人数))"))
}

///|
test "label keys and colors are stable" {
  assert_eq(@blocks.block_label_key(@blocks.BkCountLoop), "blocks.count_loop")
  assert_eq(@blocks.block_label_key(@blocks.BkElseIf), "blocks.else_if")
  assert_eq(@blocks.category_color_key(@blocks.CatFlow), "block.flow")
  let companions = @blocks.flow_companion_kinds(@blocks.BkIf)
  assert_eq(companions.length(), 3)
}

///|
test "block chain paths address nested statements" {
  let items = @blocks.block_chain(nested_body())
  // 顶层 declare [0]，if [1]，then 内 message [1,0,0]，else 内 [1,2,0]，
  // count [2]，循环体 append_row [2,2,0]，break [2,2,1]
  assert_eq(path_text(items[0].path), "0")
  assert_eq(path_text(items[1].path), "1")
  assert_eq(path_text(items[2].path), "1.0.0")
  assert_eq(path_text(items[4].path), "1.2.0")
  assert_eq(path_text(items[6].path), "2")
  assert_eq(path_text(items[7].path), "2.2.0")
  assert_eq(path_text(items[8].path), "2.2.1")
  // 装饰块无路径
  assert_eq(items[3].path.length(), 0)
  assert_eq(items[5].path.length(), 0)
  assert_eq(items[9].path.length(), 0)
}

///|
fn path_text(path : Array[Int]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for part in path {
    if !first {
      buf.write_string(".")
    }
    buf.write_string(part.to_string())
    first = false
  }
  buf.to_string()
}

///|
test "replace and delete by path keep siblings intact" {
  // 每次操作用新副本：路径手术是就地修改（数组引用语义）
  let replaced = @blocks.replace_stmt_at(
    nested_body(),
    [2, 2, 1],
    @ir.Stmt::Call("message_box", [@ir.StrLit("新")]),
  )
  assert_eq(@ir.count_stmts(replaced), @ir.count_stmts(nested_body()))
  let chain = @blocks.block_chain(replaced)
  assert_true(chain.any(item => item.text.contains("message_box(\"新\")")))
  // 删除 then 体里的信息框：总数 -1，else 体不受影响
  // （就地语义：删除后 replaced 背数组已变，先固定期望值）
  let before_delete = @ir.count_stmts(replaced)
  let deleted = @blocks.delete_stmt_at(replaced, [1, 0, 0])
  assert_eq(@ir.count_stmts(deleted), before_delete - 1)
  let deleted_chain = @blocks.block_chain(deleted)
  assert_true(
    deleted_chain.any(item => item.text.contains("message_box(\"没人\")")),
  )
  assert_true(
    !deleted_chain.any(item => item.text.contains("message_box(\"有人\")")),
  )
  // 非法路径原样返回
  let untouched = @blocks.delete_stmt_at(nested_body(), [9, 9])
  assert_eq(@ir.stmts_signature(untouched), @ir.stmts_signature(nested_body()))
}

///|
test "delete top level statement shifts chain" {
  let body = nested_body()
  let deleted = @blocks.delete_stmt_at(body, [0])
  assert_eq(deleted.length(), 2)
  assert_true(
    deleted[0] is @ir.If(_, _, _, _) || deleted[0] is @ir.CountLoop(_, _, _),
  )
}

///|
test "path surgery on else-if arms and else branch" {
  // If 带一个 else-if 臂 + else 臂：三条路径分别替换/删除
  let body : Array[@ir.Stmt] = [
    @ir.If(
      @ir.Var("开"),
      [@ir.Assign("a", @ir.IntLit(1))],
      [
        (@ir.Var("中"), [@ir.Assign("b", @ir.IntLit(2))]),
        (@ir.Var("关"), [@ir.Assign("c", @ir.IntLit(3))]),
      ],
      [@ir.Assign("d", @ir.IntLit(4))],
    ),
  ]
  // then 臂 [0,0,0] / else-if 第二臂 [0,1,1,0] / else [0,2,0]
  let replaced = @blocks.replace_stmt_at(
    body,
    [0, 1, 1, 0],
    @ir.Assign("c2", @ir.IntLit(9)),
  )
  match @blocks.stmt_at(replaced, [0, 1, 1, 0]) {
    Some(stmt) => assert_true(stmt is @ir.Assign("c2", _))
    None => fail("else-if 臂内语句应可寻址")
  }
  // 注意：replace_stmt_at 是就地语义（同数组引用），原 body 同步可见变更
  // 删除 else 臂内语句，其余臂不受影响
  let deleted = @blocks.delete_stmt_at(body, [0, 2, 0])
  match @blocks.stmt_at(deleted, [0, 2, 0]) {
    Some(_) => fail("else 臂内语句应已删除")
    None => ()
  }
  match @blocks.stmt_at(deleted, [0, 0, 0]) {
    Some(_) => ()
    None => fail("then 臂不受删除影响")
  }
}

///|
test "out-of-bounds paths are safe no-ops" {
  let body : Array[@ir.Stmt] = [@ir.Assign("x", @ir.IntLit(1))]
  assert_true(@blocks.stmt_at(body, [5, 1, 2]) is None)
  assert_true(@blocks.stmt_at(body, []) is None)
  // 越界替换/删除返回等价结构（不崩溃、不改原数组长度）
  let same = @blocks.replace_stmt_at(body, [9], @ir.Break)
  assert_eq(@ir.count_stmts(same), 1)
  let same2 = @blocks.delete_stmt_at(body, [9])
  assert_eq(@ir.count_stmts(same2), 1)
}

///|
test "reorder_stmt moves within a list without mutating input" {
  let body : Array[@ir.Stmt] = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
  ]
  // 顶层：把下标 0 移到落槽 2（落在原下标 2 之前）
  let moved = @blocks.reorder_stmt(body, [], 0, 2).unwrap()
  match (@blocks.stmt_at(moved, [0]), @blocks.stmt_at(moved, [1])) {
    (Some(@ir.Assign("b", _)), Some(@ir.Assign("a", _))) => ()
    _ => fail("重排后顺序应为 b, a, c")
  }
  match @blocks.stmt_at(moved, [2]) {
    Some(@ir.Assign("c", _)) => ()
    _ => fail("c 应仍在末尾")
  }
  // 传入数组不被修改（克隆语义，撤销快照安全）
  match @blocks.stmt_at(body, [0]) {
    Some(@ir.Assign("a", _)) => ()
    _ => fail("原数组不应被就地修改")
  }
  // 落槽 == 原下标 → 无变化
  let same = @blocks.reorder_stmt(body, [], 1, 1).unwrap()
  match (@blocks.stmt_at(same, [0]), @blocks.stmt_at(same, [1])) {
    (Some(@ir.Assign("a", _)), Some(@ir.Assign("b", _))) => ()
    _ => fail("落槽等于原位应保持原序")
  }
}

///|
test "reorder_stmt addresses nested lists by list_path" {
  let body : Array[@ir.Stmt] = [
    @ir.If(
      @ir.Var("开"),
      [@ir.Assign("t1", @ir.IntLit(1)), @ir.Assign("t2", @ir.IntLit(2))],
      [],
      [@ir.Assign("e1", @ir.IntLit(3))],
    ),
  ]
  // then 列表 [0,0]：把 t2 移到最前
  let moved = @blocks.reorder_stmt(body, [0, 0], 1, 0).unwrap()
  match @blocks.stmt_at(moved, [0, 0, 0]) {
    Some(@ir.Assign("t2", _)) => ()
    _ => fail("then 内应重排为 t2, t1")
  }
  // else 列表 [0,2]：只有一条，移不动但应成功且等价
  let same = @blocks.reorder_stmt(moved, [0, 2], 0, 0).unwrap()
  match @blocks.stmt_at(same, [0, 2, 0]) {
    Some(@ir.Assign("e1", _)) => ()
    _ => fail("else 应保持原样")
  }
  // 循环体 [i,2] 同样寻址
  let looped : Array[@ir.Stmt] = [
    @ir.WhileLoop(@ir.Var("跑"), [@ir.Assign("x", @ir.IntLit(1)), @ir.Break]),
  ]
  let swapped = @blocks.reorder_stmt(looped, [0, 2], 1, 0).unwrap()
  match @blocks.stmt_at(swapped, [0, 2, 0]) {
    Some(@ir.Break) => ()
    _ => fail("循环体应重排为 Break 在前")
  }
}

///|
test "reorder_stmt rejects bad paths and indices" {
  let body : Array[@ir.Stmt] = [@ir.Assign("a", @ir.IntLit(1))]
  assert_true(@blocks.reorder_stmt(body, [0, 1], 0, 0) is None)
  assert_true(@blocks.reorder_stmt(body, [], 5, 0) is None)
  assert_true(@blocks.reorder_stmt(body, [], -1, 0) is None)
}

///|
test "clone_stmts deep-copies nested structures" {
  let body : Array[@ir.Stmt] = [
    @ir.If(
      @ir.Binary(@ir.Add, @ir.Var("a"), @ir.IntLit(1)),
      [@ir.Assign("x", @ir.StrLit("hi"))],
      [],
      [],
    ),
  ]
  let copy = @blocks.clone_stmts(body)
  // 改副本不影响原件
  let _ = @blocks.replace_stmt_at(
    copy,
    [0, 0, 0],
    @ir.Assign("y", @ir.IntLit(2)),
  )
  match @blocks.stmt_at(body, [0, 0, 0]) {
    Some(@ir.Assign("x", _)) => ()
    _ => fail("克隆后原件不应被波及")
  }
}

///|
/// 跨列表移动：把一条语句从顶层拖进 If 的 then 体（Scratch 的核心手势
/// 「拖进 C 形块的洞里」）。
///
/// 这是 `reorder_stmt` 明确排除的能力（它只管同层重排），也是嵌套编辑
/// 从「只能靠面板插入」变成「可以拖」的关键手术。
test "move_stmt_at drags a statement into an if body" {
  // 顶层：if(cond){a=1} ; b = 2
  let body = [
    @ir.If(@ir.Var("c"), [@ir.Assign("a", @ir.IntLit(1))], [], []),
    @ir.Assign("b", @ir.IntLit(2)),
  ]
  // 把顶层第 1 条（b=2）移到 If@0 的 then 体末尾（list_path = [0,0]）
  let moved = @blocks.move_stmt_at(body, [1], [0, 0], 1)
  assert_true(moved is Some(_))
  let after = moved.unwrap()
  // 顶层只剩 if
  assert_eq(after.length(), 1)
  match after[0] {
    @ir.If(_, then_body, _, _) => {
      // then 体：a=1（原）+ b=2（移入）
      assert_eq(then_body.length(), 2)
      match then_body[1] {
        @ir.Assign(name, _) => assert_eq(name, "b")
        _ => fail("moved statement is not the expected assign")
      }
    }
    _ => fail("top-level statement is no longer an if")
  }
  // 原 body 不被改动（克隆后手术的纪律）
  assert_eq(body.length(), 2)
}

///|
/// 同列表内移动要**补偿下标**：先删会让目标位置左移一位。
///
/// 不补偿的后果是「往后挪一位」变成「原地不动」——拖了但块没动，
/// 用户以为拖拽坏了。
test "move_stmt_at compensates the index when moving forward in one list" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
  ]
  // 把 a（下标 0）移到「c 之后」= 位置 3；删掉 a 后 c 在下标 1，插到 2
  let moved = @blocks.move_stmt_at(body, [0], [], 3)
  assert_true(moved is Some(_))
  let after = moved.unwrap()
  assert_eq(after.length(), 3)
  // 结果顺序：b, c, a
  let names : Array[String] = []
  for stmt in after {
    match stmt {
      @ir.Assign(name, _) => names.push(name)
      _ => ()
    }
  }
  assert_eq(names[0], "b")
  assert_eq(names[1], "c")
  assert_eq(names[2], "a")
}

///|
/// 非法路径必须返回 `None`（调用方据此**拒绝**拖拽并给反馈），
/// 而不是静默原样返回——静默返回会让「拖失败」看起来像「拖成功但没动」。
test "move_stmt_at rejects invalid paths" {
  let body = [@ir.Assign("a", @ir.IntLit(1))]
  // 空源路径
  assert_true(@blocks.move_stmt_at(body, [], [], 0) is None)
  // 源越界
  assert_true(@blocks.move_stmt_at(body, [9], [], 0) is None)
  // 目标列表不存在
  assert_true(@blocks.move_stmt_at(body, [0], [7, 0], 0) is None)
  // 目标位置越界
  assert_true(@blocks.move_stmt_at(body, [0], [], 5) is None)
}

///|
/// **整栈重排**：抓住第 2 块时，它**和它下面所有块**一起移动
/// （Scratch 的手感）。`reorder_stmt` 只搬一条，用它做栈拖拽会把一段逻辑
/// 拆散——用户以为丢块了。
test "reorder_stack moves the grabbed block together with everything below it" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
    @ir.Assign("d", @ir.IntLit(4)),
  ]
  // 抓住 b（下标 1），拖到最前（drop_before = 0）
  let moved = @blocks.reorder_stack(body, [], 1, 0)
  assert_true(moved is Some(_))
  let after = moved.unwrap()
  let names = stmt_names(after)
  // b、c、d 作为一整段搬到最前，段内顺序不变
  assert_eq(names[0], "b")
  assert_eq(names[1], "c")
  assert_eq(names[2], "d")
  assert_eq(names[3], "a")
  // 原 body 不被改动
  assert_eq(stmt_names(body)[0], "a")
}

///|
/// 栈拖到自己内部 = 原位，返回 `None`（调用方当无操作）。
///
/// 不这么判的话「抓起一块又放回它下面一格」会产生一次无意义的撤销点，
/// 而且 `drop_before` 落在栈内时段的插入位置在数学上无定义。
test "reorder_stack treats a drop inside the stack as no-op" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
  ]
  // 抓住 a（栈 = a,b,c，长度 3），落在栈内
  assert_true(@blocks.reorder_stack(body, [], 0, 1) is None)
  assert_true(@blocks.reorder_stack(body, [], 0, 2) is None)
  assert_true(@blocks.reorder_stack(body, [], 0, 3) is None)
  // 越界
  assert_true(@blocks.reorder_stack(body, [], 9, 0) is None)
  assert_true(@blocks.reorder_stack(body, [], -1, 0) is None)
}

///|
/// 栈拖拽**保留段内顺序**（这是「一起搬走」的定义）。
test "reorder_stack preserves the segment order" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
    @ir.Assign("d", @ir.IntLit(4)),
  ]
  // 抓 b（栈 = b,c,d），落到「a 之前」（drop_before = 0）
  let moved = @blocks.reorder_stack(body, [], 1, 0)
  assert_true(moved is Some(_))
  let names = stmt_names(moved.unwrap())
  assert_eq(names[0], "b")
  assert_eq(names[1], "c")
  assert_eq(names[2], "d")
  assert_eq(names[3], "a")
}

///|
/// 抓住**整条列表**时，任何落点都是原位 → `None`（无操作）。
///
/// 这条容易被当成 bug：栈占满列表时「搬到末尾」与「不动」是同一位置。
/// 返回 `Some` 会凭空产生一次撤销点，而画面上什么都没变。
test "reorder_stack rejects moving an entire list" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.Assign("b", @ir.IntLit(2)),
    @ir.Assign("c", @ir.IntLit(3)),
  ]
  assert_true(@blocks.reorder_stack(body, [], 0, 3) is None)
  assert_true(@blocks.reorder_stack(body, [], 0, 0) is None)
}

///|
/// 取一串语句里的赋值名，供顺序断言。
fn stmt_names(body : Array[@ir.Stmt]) -> Array[String] {
  let names : Array[String] = []
  for stmt in body {
    match stmt {
      @ir.Assign(name, _) => names.push(name)
      _ => ()
    }
  }
  names
}

///|
/// 落点有效性：`break` **只能在循环体内**（语言规则 `BreakOutsideLoop`）。
///
/// 语言层在整程序校验时报这个错；拖拽当场先判一次，用户就不必
/// 「拖进去 → 运行 → 看报错」。判据必须看**容器的真实父语句类型**，
/// 不能按路径 slot 猜：`[i,2]` 既可能是 `If` 的 else，也可能是循环体。
test "drop_accepts_stmt rejects break outside a loop" {
  let body = [
    @ir.Assign("a", @ir.IntLit(1)),
    @ir.If(@ir.Var("c"), [], [], []),
    @ir.CountLoop(@ir.IntLit(3), None, []),
  ]
  // 顶层（路径 []）不接受 break
  assert_false(@blocks.drop_accepts_stmt(body, [], @ir.Break))
  // If 的 then（[1,0]）不在循环里 → 不接受
  assert_false(@blocks.drop_accepts_stmt(body, [1, 0], @ir.Break))
  // If 的 else（[1,2]）也不在循环里 → 不接受（按 slot 猜会误判成循环体）
  assert_false(@blocks.drop_accepts_stmt(body, [1, 2], @ir.Break))
  // 循环体（[2,2]）→ 接受
  assert_true(@blocks.drop_accepts_stmt(body, [2, 2], @ir.Break))
  // 非 break 语句任何位置都接受
  assert_true(
    @blocks.drop_accepts_stmt(body, [], @ir.Assign("b", @ir.IntLit(1))),
  )
}

///|
/// 嵌套：`If` 在循环体内时，`If` 的 then 也**在循环里**，`break` 合法
/// （语言语义按嵌套判定，不是只看直接父层）。
test "drop_accepts_stmt accepts break inside a loop nested under an if" {
  let body = [
    @ir.CountLoop(@ir.IntLit(3), None, [@ir.If(@ir.Var("c"), [], [], [])]),
  ]
  // 循环体 → if.then：路径 = 循环体 [0] 段 + If 的 then 段
  // [0,2] = CountLoop@0 的循环体；再进 If 的 then → [0,2] 后接 [0,0]
  // stmt_list_at 的语法是「下标链」：先 0 进循环体，再 0 进那个 If，再 0 进 then
  assert_true(@blocks.drop_accepts_stmt(body, [0, 2, 0, 0], @ir.Break))
}

///|
/// 匹配语句投影（M5-5d）：头 + 情况行 + 否则 + 结束；臂内路径寻址线性
/// （section i = 第 i 个臂，section arms.length() = else）。
test "match projects to a block chain with linear arm sections" {
  let body : Array[@ir.Stmt] = [
    @ir.Match(
      @ir.EnumTag("花色", "红桃"),
      [
        @ir.MatchArm::{
          case_name: "红桃",
          body: [@ir.Assign("x", @ir.IntLit(1))],
        },
        @ir.MatchArm::{
          case_name: "黑桃",
          body: [@ir.Assign("x", @ir.IntLit(2))],
        },
      ],
      [@ir.Assign("x", @ir.IntLit(9))],
    ),
  ]
  let chain = @blocks.block_chain(body)
  let kinds = chain.map(item => item.kind)
  // 头 + 情况0 + 体 + 情况1 + 体 + 否则 + 体 + 结束
  assert_true(kinds.any(k => k is @blocks.BkMatch))
  let mut case_count = 0
  for k in kinds {
    if k is @blocks.BkCase {
      case_count = case_count + 1
    }
  }
  assert_eq(case_count, 2)
  assert_true(kinds.any(k => k is @blocks.BkElse))
  assert_true(kinds.any(k => k is @blocks.BkEnd))
  // 头文本 = canonical subject；情况行文本 = 情况名
  assert_eq(chain[0].text, "花色::红桃")
  assert_eq(chain[1].text, "红桃")
  assert_eq(chain[2].text, "x = 1")
  // 臂内语句可寻址：section 0 = 红桃臂；section 2 = else
  assert_true(@blocks.stmt_at(body, [0, 0, 0]) is Some(_))
  match @blocks.stmt_at(body, [0, 2, 0]) {
    Some(@ir.Assign(name, _)) => assert_eq(name, "x")
    _ => fail("else 臂内语句应可寻址")
  }
  // stmt_list_at：臂体列表可取（拖拽插入的前提）
  assert_true(@blocks.stmt_list_at(body, [0, 0]) is Some(_))
  assert_true(@blocks.stmt_list_at(body, [0, 2]) is Some(_))
  assert_true(@blocks.stmt_list_at(body, [0, 5]) is None)
  // 臂内替换
  let replaced = @blocks.replace_stmt_at(
    body,
    [0, 1, 0],
    @ir.Assign("x", @ir.IntLit(22)),
  )
  match @blocks.stmt_at(replaced, [0, 1, 0]) {
    Some(@ir.Assign(_, @ir.IntLit(n))) => assert_eq(n, 22)
    _ => fail("黑桃臂替换失败")
  }
}
