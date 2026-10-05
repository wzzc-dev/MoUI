///|
/// 分段投影：把积木一行切成「字面段」与「插槽段」，供绘制层画洞、命中层
/// 认洞。这一层只产结构，不涉像素。

///|
/// **分段拼回去必须逐字等于 `BlockItem.text`**。
///
/// 这是整层的地基：洞的位置是「前面所有段的宽度之和」，所以只要有一段文本
/// 与真实渲染不一致，洞就会画错位置、命中也会偏——而两者会**一起**偏，
/// 于是测试若不比对真实 `text` 就发现不了。这里对每种语句形态都比一次。
test "statement segments reproduce the projected text exactly" {
  let cases : Array[@ir.Stmt] = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
    @ir.Declare("y", @ir.IntLit(5)),
    @ir.If(@ir.Var("c"), [], [], []),
    // 循环变量可空/非空是两种写法，都要对
    @ir.CountLoop(@ir.IntLit(3), None, []),
    @ir.CountLoop(@ir.IntLit(3), Some("i"), []),
    @ir.WhileLoop(@ir.Var("w"), []),
    @ir.Return(Some(@ir.IntLit(1))),
    @ir.Return(None),
    @ir.SetIndex("r", @ir.IntLit(0), @ir.StrLit("v")),
    @ir.Stmt::Call("set_text", [@ir.Var("a"), @ir.StrLit("b")]),
    @ir.Stmt::Call("noop", []),
    @ir.Break,
  ]
  for stmt in cases {
    let segments = @blocks.stmt_text_segments(stmt)
    let joined = segments.fold(init="", (acc, segment) => acc + segment.text)
    let chain = @blocks.block_chain([stmt])
    let projected = if chain.length() > 0 { chain[0].text } else { "" }
    assert_eq(joined, projected)
  }
}

///|
/// 插槽段带**可寻址的表达式路径**，且该路径真的能用 `expr_at` 取到东西。
///
/// 这是「点中某段 → 换掉那个子表达式」链路成立的前提：段里的路径与
/// `expr_path.mbt` 的寻址语法必须是同一套。
test "slot segments carry resolvable expression paths" {
  let stmt = @ir.Assign(
    "x",
    @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2)),
  )
  let body = [stmt]
  let segments = @blocks.stmt_text_segments(stmt)
  let mut slots = 0
  for segment in segments {
    match segment.expr_path {
      Some(path) => {
        assert_true(@blocks.expr_at(body, [0], path) is Some(_))
        slots = slots + 1
      }
      None => ()
    }
  }
  // `x = (1 + 2)` 只有一个洞（整个右值）；左右操作数是**嵌套**的，
  // 由后续下钻（`expr_child`）到达，不在这一层展开
  assert_eq(slots, 1)
}

///|
/// **叶子值不是洞**：字面量在 Scratch 里是可点击编辑的值，不是能再塞一块
/// 积木的凹槽。区分开才能让绘制层给它们不同视觉、命中层知道「点这里是改值」。
test "leaf values are marked as values rather than slots" {
  // 叶子：数字
  let leaf = @blocks.stmt_text_segments(@ir.Assign("x", @ir.IntLit(5)))
  assert_eq(@blocks.segments_slot_count(leaf), 0)
  // 非叶子（二元）：是洞
  let nested = @blocks.stmt_text_segments(
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  )
  assert_eq(@blocks.segments_slot_count(nested), 1)
  // 变量与调用也当值（不是洞）？——变量是**读取**，仍是值；调用才是洞。
  let var_seg = @blocks.stmt_text_segments(@ir.Assign("x", @ir.Var("y")))
  assert_eq(@blocks.segments_slot_count(var_seg), 0)
  let call_seg = @blocks.stmt_text_segments(
    @ir.Assign("x", @ir.Expr::Call("get_number", [@ir.Var("a")])),
  )
  assert_eq(@blocks.segments_slot_count(call_seg), 1)
}

///|
/// 调用的每个实参各是一段（洞的数量 = 实参个数）——Scratch 的 `说 (a) 和 (b)`
/// 每个凹槽都能塞块。
test "a call exposes one slot per argument" {
  let stmt = @ir.Stmt::Call(
    "set_text",
    [@ir.Var("a"), @ir.StrLit("b"), @ir.IntLit(7)],
  )
  let body = [stmt]
  let segments = @blocks.stmt_text_segments(stmt)
  // 7 段 = 4 个字面段（`set_text(` / `, ` / `, ` / `)`）+ 3 个实参段。
  // 三个实参都是**值**（变量、字符串、数字），所以洞数为 0。
  assert_eq(segments.length(), 7)
  assert_eq(@blocks.segments_slot_count(segments), 0)
  // 路径依次是 [0] [1] [2]，且都能解析
  let seen : Array[Int] = []
  for segment in segments {
    match segment.expr_path {
      Some(path) => seen.push(path[0])
      None => ()
    }
  }
  assert_eq(seen.length(), 3)
  assert_eq(seen[0], 0)
  assert_eq(seen[1], 1)
  assert_eq(seen[2], 2)
  // 每个实参路径都能解析到对应位置的表达式
  let mut index = 0
  while index < seen.length() {
    assert_true(@blocks.expr_at(body, [0], [seen[index]]) is Some(_))
    index = index + 1
  }
}

///|
/// 字段访问（M5-5c 前端③）：插槽文本走 canonical（`person.名字`），
/// 与字面段拼回逐字一致，路径仍可寻址。
test "field access projects as canonical slot text" {
  let stmt = @ir.Assign("y", @ir.FieldAccess(@ir.Var("person"), "名字"))
  let segments = @blocks.stmt_text_segments(stmt)
  let joined = segments.fold(init="", (acc, segment) => acc + segment.text)
  let chain = @blocks.block_chain([stmt])
  assert_eq(joined, chain[0].text)
  // 插槽段：非字面段文本即 canonical 表达式，路径可解析到同一表达式
  let slots = segments.filter(segment => segment.is_slot)
  assert_eq(slots.length(), 1)
  assert_eq(slots[0].text, "person.名字")
  assert_true(
    @blocks.expr_at([stmt], [0], slots[0].expr_path.unwrap()) is Some(_),
  )
}
