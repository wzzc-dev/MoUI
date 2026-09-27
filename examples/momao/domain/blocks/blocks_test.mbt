///|
/// blocks 测试：spec 覆盖、积木链展开、聚光灯文本与审计细节同源。

///|
fn nested_body() -> Array[@ir.Stmt] {
  [
    @ir.Declare("人数", @ir.Call("row_count", [@ir.Var("名单")])),
    @ir.If(
      @ir.Binary(@ir.Gt, @ir.Var("人数"), @ir.NumLit(0.0)),
      [@ir.Call("message_box", [@ir.StrLit("有人")])],
      [],
      [@ir.Call("message_box", [@ir.StrLit("没人")])],
    ),
    @ir.CountLoop(
      @ir.NumLit(3.0),
      Some("i"),
      [
        @ir.Call("append_row", [@ir.Var("名单"), @ir.Var("i")]),
        @ir.Break,
      ],
    ),
  ]
}

test "every builtin has a block spec" {
  for spec in @momao_lang.builtin_catalog() {
    match @blocks.builtin_block_spec(spec.id) {
      Some(block) => {
        assert_eq(block.arity, spec.arity)
        assert_eq(
          @blocks.builtin_param_types(spec.id).length(),
          spec.arity,
        )
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

test "block text matches interpreter audit detail for spotlight" {
  // 聚光灯对暗号：积木链文本 == 审计细节（同一 canonical_call_text）
  let program : @ir.MomaoProgram = {
    version: 1,
    window: @ir.default_window(),
    controls: [
      @ir.Control::{
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
  }
  let texts = @momao_lang.initial_texts(program)
  let rows = @momao_lang.initial_rows(program)
  let state = @momao_lang.start_run_stmts(
    program.handlers[0].body,
    texts,
    @momao_lang.initial_values(program),
    rows,
  )
  @momao_lang.run_to_end(state)
  assert_true(state.status is @momao_lang.Completed)
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

test "label keys and colors are stable" {
  assert_eq(@blocks.block_label_key(@blocks.BkCountLoop), "blocks.count_loop")
  assert_eq(@blocks.block_label_key(@blocks.BkElseIf), "blocks.else_if")
  assert_eq(
    @blocks.category_color_key(@blocks.CatFlow),
    "block.flow",
  )
  let companions = @blocks.flow_companion_kinds(@blocks.BkIf)
  assert_eq(companions.length(), 3)
}

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
  assert_true(deleted_chain.any(item => item.text.contains("message_box(\"没人\")")))
  assert_true(!deleted_chain.any(item => item.text.contains("message_box(\"有人\")")))
  // 非法路径原样返回
  let untouched = @blocks.delete_stmt_at(nested_body(), [9, 9])
  assert_eq(@ir.stmts_signature(untouched), @ir.stmts_signature(nested_body()))
}

test "delete top level statement shifts chain" {
  let body = nested_body()
  let deleted = @blocks.delete_stmt_at(body, [0])
  assert_eq(deleted.length(), 2)
  assert_true(deleted[0] is @ir.If(_, _, _, _) || deleted[0] is @ir.CountLoop(_, _, _))
}

///|
test "path surgery on else-if arms and else branch" {
  // If 带一个 else-if 臂 + else 臂：三条路径分别替换/删除
  let body : Array[@ir.Stmt] = [
    @ir.If(
      @ir.Var("开"),
      [@ir.Assign("a", @ir.NumLit(1.0))],
      [
        (@ir.Var("中"), [@ir.Assign("b", @ir.NumLit(2.0))]),
        (@ir.Var("关"), [@ir.Assign("c", @ir.NumLit(3.0))]),
      ],
      [@ir.Assign("d", @ir.NumLit(4.0))],
    ),
  ]
  // then 臂 [0,0,0] / else-if 第二臂 [0,1,1,0] / else [0,2,0]
  let replaced = @blocks.replace_stmt_at(
    body,
    [0, 1, 1, 0],
    @ir.Assign("c2", @ir.NumLit(9.0)),
  )
  match @blocks.stmt_at(replaced, [0, 1, 1, 0]) {
    Some(stmt) =>
      assert_true(stmt is @ir.Assign("c2", _))
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
  let body : Array[@ir.Stmt] = [@ir.Assign("x", @ir.NumLit(1.0))]
  assert_true(@blocks.stmt_at(body, [5, 1, 2]) is None)
  assert_true(@blocks.stmt_at(body, []) is None)
  // 越界替换/删除返回等价结构（不崩溃、不改原数组长度）
  let same = @blocks.replace_stmt_at(body, [9], @ir.Break)
  assert_eq(@ir.count_stmts(same), 1)
  let same2 = @blocks.delete_stmt_at(body, [9])
  assert_eq(@ir.count_stmts(same2), 1)
}
