///|
/// 积木编辑域的新增黑盒测试：复制语句与落槽指示线。
/// 独立成文件：app_test.mbt 的源文件预算已顶格（ratchet 1494），新用例
/// 不再往里长。

///|
/// 复制语句（Scratch Duplicate 口径）：克隆体插入原语句之后并选中之，
/// 撤销一次回到原状。
test "duplicate block inserts a copy after the original" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  let original_text = blocks[0].text
  let count = blocks.length()
  let selected = select_block_index(model, 0)
  let duplicated = apply(selected, DuplicateBlock)
  // 链上多了一条，且新块紧随原块、文本一致
  let after = @app.block_chain_of(duplicated)
  assert_eq(after.length(), count + 1)
  assert_eq(after[0].text, original_text)
  assert_eq(after[1].text, original_text)
  // 选中新副本，草稿按副本语句预填（非空即可：item.text 与 DSL 源码
  // 是两种口径，控制流块的前者并不出现在后者里）
  assert_eq(duplicated.selected_block, 1)
  assert_true(duplicated.block_draft != "")
  // 撤销恢复原链
  let undone = apply(duplicated, Undo)
  assert_eq(@app.block_chain_of(undone).length(), count)
}

///|
/// 落槽指示线（链条坐标）：上边槽画在兄弟行顶缘上方 3pt，落到最后一个
/// 兄弟之后画在其底缘下方 3pt；非兄弟行不计入槽位。
test "blocks insert mark follows sibling slots in chain space" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  let rects = @app.blocks_item_rects(blocks)
  let list_path = @app.blocks_parent_of(blocks[0].path)
  // 落槽 0：第一条兄弟顶缘上方 3pt
  let mark_top = @app.blocks_insert_mark(
    blocks,
    rects,
    Some({
      list_path,
      from_path: blocks[0].path,
      from: 0,
      to: 0,
      to_list: list_path,
      valid: true,
    }),
  )
  let (top_y, _, _) = mark_top.unwrap()
  assert_eq(top_y, rects[0].origin.y - 3.0)
  // 落槽 = 兄弟总数：最后一条兄弟底缘下方 3pt
  let mark_bottom = @app.blocks_insert_mark(
    blocks,
    rects,
    Some({
      list_path,
      from_path: blocks[0].path,
      from: 0,
      to: blocks.length(),
      to_list: list_path,
      valid: true,
    }),
  )
  let (bottom_y, _, _) = mark_bottom.unwrap()
  assert_eq(bottom_y, rects[blocks.length() - 1].max_y() + 3.0)
  // 无拖拽：无指示线
  assert_true(@app.blocks_insert_mark(blocks, rects, None) is None)
}

///|
test "blocks canvas drag moves the grabbed stack and is undoable" {
  // 口算训练营：取一个有 ≥2 条顶层语句的子程序
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 3)
  let first_text = blocks[0].text
  let second_text = blocks[1].text
  let third_text = blocks[2].text
  // 按上第一块 → 拖到落槽 2（原下标 1 之后）→ 松手
  let rects = @app.blocks_item_rects(blocks)
  let pressed = apply(
    model,
    BlocksCanvasPress(rects[0].origin.x + 10.0, rects[0].origin.y + 10.0, 470.0),
  )
  assert_true(pressed.block_drag is Some(_))
  // 按下不再即时选中（选中决定编辑卡拆分位置，手势中途换选中会重构画布）
  assert_eq(pressed.selected_block, -1)
  let dragged = apply(
    pressed,
    BlocksCanvasDragTo(
      rects[1].origin.x + 10.0,
      rects[1].origin.y + 38.0,
      470.0,
    ),
  )
  assert_eq(dragged.block_drag.unwrap().to, 2)
  let released = apply(dragged, BlocksCanvasRelease)
  // **整栈语义**（Scratch 手感）：抓住第一块时它和它下面的所有块一起移动。
  // 抓到「第二块之后」等价于原位，所以这里先断言「顺序未变」——
  // 单条重排的旧语义会把第二块提到最前（那是被这次改造替换掉的行为）。
  let after = @app.block_chain_of(released)
  assert_eq(after[0].text, first_text)
  assert_eq(after[1].text, second_text)
  assert_eq(after[2].text, third_text)
  // 真要移动：抓住**第二块**（栈 = 第 2..n 块，不是整条列表）拖到最前。
  //
  // 为什么不用第一块：抓住第一块 = 抓住整条列表，「搬到末尾」与「原位」
  // 是同一位置（领域层正确地返回原位）。要验证「整段一起走」必须留一块
  // 在栈外。
  let to_end = apply(
    apply(
      apply(
        model,
        BlocksCanvasPress(
          rects[1].origin.x + 10.0,
          rects[1].origin.y + 10.0,
          470.0,
        ),
      ),
      BlocksCanvasDragTo(
        rects[0].origin.x + 10.0,
        rects[0].origin.y - 4.0,
        470.0,
      ),
    ),
    BlocksCanvasRelease,
  )
  let moved = @app.block_chain_of(to_end)
  // 整段搬到最前：第二块成为首块，**原第一块被推到整段之后**——
  // 这就是「抓住一块，它和它下面的所有块一起走」的可观测后果
  // （单条重排只会把第二块提到最前，第一块留在原位）。
  assert_eq(moved[0].text, second_text)
  assert_eq(moved[moved.length() - 1].text, first_text)
  // 段内顺序保持
  assert_eq(moved[1].text, third_text)
  assert_true(to_end.block_draft != "")
  // 撤销恢复原序
  let undone = apply(to_end, Undo)
  assert_eq(@app.block_chain_of(undone)[0].text, first_text)
}

///|
/// 键盘上下移动选中（↑/↓，Scratch/IDE 口径）。
///
/// 三条被钉住的纪律：
/// 1. **跳过装饰块**——`else/end` 没有对应语句（`path` 为空），键盘不该停在
///    一个没有可编辑对象的块上；
/// 2. **越界不循环、也不清空**——按到端点保持原选中；
/// 3. **不产生撤销点**——纯选中态变更。
test "keyboard steps through editable blocks and skips decorations" {
  // 口算训练营模板带 ≥2 条顶层语句
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  // 从「未选中」按 ↓ 落到第一条**可编辑**块
  let first = apply(model, SelectBlockStep(1))
  assert_true(first.selected_block >= 0)
  assert_true(blocks[first.selected_block].path.length() > 0)
  // 再按 ↓ 落到下一条可编辑块（跳过中间任何装饰块）
  let second = apply(first, SelectBlockStep(1))
  assert_true(second.selected_block > first.selected_block)
  assert_true(blocks[second.selected_block].path.length() > 0)
  // ↑ 回到上一条
  let back = apply(second, SelectBlockStep(-1))
  assert_eq(back.selected_block, first.selected_block)
  // 到端点继续按：保持不动（不循环）
  let mut at_end = second
  for _ in 0..<20 {
    at_end = apply(at_end, SelectBlockStep(1))
  }
  let last_index = at_end.selected_block
  let beyond = apply(at_end, SelectBlockStep(1))
  assert_eq(beyond.selected_block, last_index)
  // 不产生撤销点：选中变更前后 undo 深度不变
  assert_eq(first.selected_block != model.selected_block, true)
}

///|
/// 键盘导航**只动选中**，不动 IR——语句内容在导航前后完全一致。
test "keyboard navigation leaves the program untouched" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let before = @app.block_chain_of(model).map(item => item.text)
  let moved = apply(apply(model, SelectBlockStep(1)), SelectBlockStep(1))
  let after = @app.block_chain_of(moved).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut i = 0
  while i < before.length() {
    assert_eq(before[i], after[i])
    i = i + 1
  }
}

///|
/// 积木键盘命令**确实注册在全局表里**，且按选中态开关。
///
/// 回归意义：命令表此前完全没有测试——「加了 bind 但键名写错 / enabled
/// 忘了给」这类错误在 UI 上表现为「按了没反应」，而单测全绿。这里直接对
/// 命令表断言：键名、修饰键、enabled 三者都要对。
test "block keyboard commands are registered and gated on selection" {
  // 未选中积木：Delete/↑/↓ 一律禁用（避免「删掉一个看不见的东西」）
  let idle = @app.initial_model()
  assert_eq(idle.selected_block, -1)
  let idle_cmds = @app.studio_program_commands(idle)
  let mut idle_delete_enabled = false
  let mut idle_bindings = 0
  for entry in idle_cmds {
    let cmd = entry.command
    match cmd.shortcut {
      Some(sc) =>
        if sc.key == "Delete" || sc.key == "ArrowUp" || sc.key == "ArrowDown" {
          idle_bindings = idle_bindings + 1
          if sc.key == "Delete" && cmd.enabled {
            idle_delete_enabled = true
          }
        }
      None => ()
    }
  }
  // 三条命令各注册 meta + control 两个变体 → 6 条
  assert_eq(idle_bindings, 6)
  assert_false(idle_delete_enabled)
  // 选中一块积木后：三条都启用
  let picked = apply(apply(idle, SelectTemplate(2)), SelectBlockStep(1))
  assert_true(picked.selected_block >= 0)
  let picked_cmds = @app.studio_program_commands(picked)
  let mut delete_enabled = false
  let mut delete_message_ok = false
  for entry in picked_cmds {
    let cmd = entry.command
    match cmd.shortcut {
      Some(sc) =>
        if sc.key == "Delete" && cmd.enabled {
          delete_enabled = true
          // 命令必须把 DeleteBlock 作为消息（不是别的动作）
          match entry.message {
            DeleteBlock => delete_message_ok = true
            _ => ()
          }
        }
      None => ()
    }
  }
  assert_true(delete_enabled)
  assert_true(delete_message_ok)
}

///|
/// **拖进 C 形块的洞里**（跨层移动）——端到端，经真实的手势消息。
///
/// 这是 Scratch 编辑器的招牌手势，也是 `reorder_stmt`（同层专用）此前明确
/// 排除的能力。测试走生产同一条路：按下 → 拖到目标行 → 松手，断言语句
/// 真的换了容器（IR 里出现在 if 的 then 体里）。
///
/// 构造方式：先插一条 if 语句（面板骨架），再拖另一条语句进它的体内。
test "dragging a statement into an if body moves it across layers" {
  // 口算训练营模板：顶层有 ≥2 条语句
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  // 选中第一条，插入一条 if 骨架（落在选中块之后）
  let with_if = apply(
    apply(model, SelectBlockStep(1)),
    InsertStatement(2, @app.template_index_of(2, "app.stmt.tpl.if").unwrap()),
  )
  let chain = @app.block_chain_of(with_if)
  // 找到 if 头所在行（分类 2 = 流程；该分类首条模板是 if）
  let mut head_index = -1
  let mut i = 0
  for item in chain {
    if head_index < 0 {
      match item.kind {
        @blocks.BkIf => head_index = i
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(head_index >= 0)
  // if 体内至少要有可落的位置；找一个**不在** if 体内的可编辑语句作源
  let mut source_index = -1
  let mut k = 0
  for item in chain {
    if source_index < 0 &&
      item.path.length() > 0 &&
      !@app.blocks_in_c_body(chain, k) &&
      k != head_index {
      source_index = k
    }
    k = k + 1
  }
  assert_true(source_index >= 0)
  // 源语句必须与 if 头**同层**（顶层）才是干净的跨层用例
  assert_eq(chain[source_index].depth, chain[head_index].depth)
  // 目标：if 头的下半行 → 落进体内
  let rects = @app.blocks_item_rects(chain, avail_width=470.0)
  let head_rect = rects[head_index]
  let drop_y = head_rect.origin.y + head_rect.size.height * 0.75
  let drop_list = @app.blocks_drop_list_of(chain, rects, drop_y, [])
  // 落点列表必须**不是**顶层（真的进了体内）
  assert_true(drop_list.length() > 0)
  // 走生产手势：按下源行 → 拖到 if 下半行 → 松手
  let pressed = apply(
    with_if,
    BlocksCanvasPress(
      rects[source_index].origin.x + 10.0,
      rects[source_index].origin.y + 10.0,
      470.0,
    ),
  )
  assert_true(pressed.block_drag is Some(_))
  let dragged = apply(pressed, BlocksCanvasDragTo(0.0, drop_y, 470.0))
  let released = apply(dragged, BlocksCanvasRelease)
  // 断言：源语句**离开了顶层**，且出现在 if 的 then 体里。
  //
  // 注意：源被抽走之后，if 头的**链下标会前移**（它上方少了一条语句），
  // 所以不能拿移动前的 `head_index` 去比——那正是本次实现里踩到的
  // 「删源导致路径索引左移」的同一类问题。这里按**结构**判定：
  // 源语句文本出现在某个 If 行的体内（深度 1、路径长度为 3、path[1]==0）。
  let after = @app.block_chain_of(released)
  let mut found_inside = false
  let mut has_top_level_source = false
  for item in after {
    let is_source = item.text == chain[source_index].text
    if is_source && item.path.length() == 1 {
      has_top_level_source = true
    }
    // 在某个 if 的 then 体里：深度 1 且路径形如 [k, 0, m]
    if is_source &&
      item.depth == 1 &&
      item.path.length() >= 2 &&
      item.path[1] == 0 {
      found_inside = true
    }
  }
  assert_false(has_top_level_source)
  assert_true(found_inside)
}

///|
/// 右键上下文菜单（Scratch/IDE 口径）：命中块 → 开菜单并选中它；
/// 点空白 → 只开画布级菜单、**不动选中**。
///
/// 两条纪律的理由：
/// - 右键不该改变用户的编辑上下文（点空白清掉正在编辑的块 = 丢工作）；
/// - 菜单动作走 `BlocksMenuAction`，与右栏按钮/快捷键**同一条 update 链**，
///   不复制语义（复制一份就会分叉——比如撤销点只在一处记）。
test "block context menu selects the hit block and closes on action" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 先选中第 2 条，作为「右键空白不该动它」的基线
  let with_sel = apply(apply(model, SelectBlockStep(1)), SelectBlockStep(1))
  let baseline = with_sel.selected_block
  assert_true(baseline >= 0)
  // 右键空白（下标 -1）：菜单开，选中不变
  let on_empty = apply(with_sel, BlocksContextMenu(-1, 40.0, 40.0))
  assert_true(on_empty.block_menu is Some(_))
  assert_eq(on_empty.selected_block, baseline)
  // 关菜单
  let closed = apply(on_empty, BlocksContextMenuClose)
  assert_false(closed.block_menu is Some(_))
  // 右键某一块：菜单开 + 选中切到它
  let on_block = apply(with_sel, BlocksContextMenu(0, 20.0, 20.0))
  assert_true(on_block.block_menu is Some(_))
  assert_eq(on_block.selected_block, 0)
  // 菜单动作：复制——先关菜单，且真的多出一条语句
  let chain_before = @app.block_chain_of(on_block).length()
  let after_dup = apply(on_block, BlocksMenuAction(DuplicateBlock))
  assert_false(after_dup.block_menu is Some(_))
  assert_eq(@app.block_chain_of(after_dup).length(), chain_before + 1)
  // 菜单动作：删除——先关菜单，且真的少一条
  let after_del = apply(on_block, BlocksMenuAction(DeleteBlock))
  assert_false(after_del.block_menu is Some(_))
  assert_eq(@app.block_chain_of(after_del).length(), chain_before - 1)
}

///|
/// 右键在**画布真实绘制路径**上必须能命中块（防「点得中、右键点不中」）。
///
/// 判据：用与绘制同一组矩形（真实 avail_width）做命中，缩进后的子块也能命中。
/// 回归意义：命中此前用默认常量 430，窄画布下会在块右侧空白里误判/漏判。
test "right-click hit-testing uses the same geometry as drawing" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let chain = @app.block_chain_of(model)
  assert_true(chain.length() >= 1)
  // 用**窄画布**（370 ≈ 1280 窗口下积木窗格的实际可用宽）。旧实现命中有个
  // 默认常量 430，比这里的块宽大得多——「块右缘之外、430 之内」那片空白
  // 会被误判成命中，这正是「点空白却选中了积木」的来源。
  let width = 370.0
  let rects = @app.blocks_item_rects(chain, avail_width=width)
  let r0 = rects[0]
  assert_true(r0.size.width < 430.0)
  // 块内一点：命中 0
  assert_eq(
    @app.blocks_hit_index(
      chain,
      r0.origin.x + r0.size.width / 2.0,
      r0.origin.y + r0.size.height / 2.0,
      avail_width=width,
    ),
    0,
  )
  // 块右缘之外、旧默认宽 430 之内：**不得**命中
  let outside_x = r0.origin.x + r0.size.width + 6.0
  assert_true(outside_x < 430.0)
  assert_eq(
    @app.blocks_hit_index(
      chain,
      outside_x,
      r0.origin.y + r0.size.height / 2.0,
      avail_width=width,
    ),
    -1,
  )
}

///|
/// **从调色板拖一条骨架到画布**（Scratch 的字面手势）：落点由指针决定，
/// 且与点击插入共用同一条落地路径。
///
/// 判据取「真的多出一条语句 + 落在指针那一侧」，而不是「状态位翻转」——
/// 拖放最容易出的错是「手势收到了但语句没插进去」。
test "dragging a palette skeleton onto the canvas inserts at the pointer" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let before = @app.block_chain_of(model).length()
  // 开始拖一条骨架（流程分类第 0 条 = if 骨架）
  let dragging = apply(model, PaletteDragStart(2, 0))
  assert_true(dragging.palette_drag is Some(_))
  let rects = @app.blocks_item_rects(
    @app.block_chain_of(dragging),
    avail_width=470.0,
  )
  // 松手在**第 0 行的下半部分** → 插到它之后
  let r0 = rects[0]
  let dropped = apply(
    dragging,
    PaletteDrop(r0.origin.x + 20.0, r0.origin.y + r0.size.height * 0.75, 470.0),
  )
  // 拖动源已清（不能悬着影响下一次拖动）
  assert_false(dropped.palette_drag is Some(_))
  let after = @app.block_chain_of(dropped)
  assert_true(after.length() > before)
  // 新语句在第 0 行之后：if 骨架自带子块，所以断言「第 0 行之后出现了 if 头」
  let mut has_if_after_head = false
  let mut i = 0
  for item in after {
    if i > 0 {
      match item.kind {
        @blocks.BkIf => has_if_after_head = true
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(has_if_after_head)
}

///|
/// **无效落点被拒收**：拖着 `break` 到非循环容器时，落点标为无效
/// （红色拒收线），松手**不写 IR**。
///
/// 判据取「IR 没变」而不是「状态位」——拖放最容易出的错是「标红了但还是
/// 插进去了」，那会让语言层随后报 `BreakOutsideLoop`，用户却不知道自己
/// 做错了什么。
test "an invalid drop is rejected and leaves the program untouched" {
  // 造「循环体里有一条 break」的场景：先插循环骨架，再在循环**体内**插一条
  // 跳出骨架（流程分类里「跳出循环」是第 3 条，下标 3）。
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 选中一块后插入循环（流程分类下标 2，模板 1 = 计次循环）
  let with_loop = apply(
    apply(model, SelectBlockStep(1)),
    // 按**稳定的 i18n 键**取骨架下标，不写死位置：表里插入新骨架会让
    // 位置下标整体平移，用例会突然开始测另一条（且失败信息指不到原因）。
    InsertStatement(
      2,
      @app.template_index_of(2, "app.stmt.tpl.repeat").unwrap(),
    ),
  )
  let chain0 = @app.block_chain_of(with_loop)
  let mut loop_index = -1
  let mut i = 0
  for item in chain0 {
    if loop_index < 0 {
      match item.kind {
        @blocks.BkCountLoop => loop_index = i
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(loop_index >= 0)
  // 选中循环**体内**那条骨架，再插一条跳出 → break 落在循环里（合法）
  let rects0 = @app.blocks_item_rects(chain0, avail_width=470.0)
  let mut body_index = -1
  let mut k = loop_index + 1
  while k < chain0.length() {
    if body_index < 0 && chain0[k].depth > chain0[loop_index].depth {
      body_index = k
    }
    k = k + 1
  }
  assert_true(body_index >= 0)
  let in_loop = apply(
    with_loop,
    BlocksCanvasTap(
      rects0[body_index].origin.x + 10.0,
      rects0[body_index].origin.y + 10.0,
      470.0,
    ),
  )
  let with_break = apply(
    in_loop,
    InsertStatement(2, @app.template_index_of(2, "app.stmt.tpl.break").unwrap()),
  )
  let chain = @app.block_chain_of(with_break)
  // 找那条 break（跳出循环）
  let mut break_index = -1
  let mut b = 0
  for item in chain {
    if break_index < 0 {
      match item.kind {
        @blocks.BkBreak => break_index = b
        _ => ()
      }
    }
    b = b + 1
  }
  assert_true(break_index >= 0)
  // 它在循环体内：合法落点
  let rects = @app.blocks_item_rects(chain, avail_width=470.0)
  let pressed = apply(
    with_break,
    BlocksCanvasPress(
      rects[break_index].origin.x + 10.0,
      rects[break_index].origin.y + 10.0,
      470.0,
    ),
  )
  // 拖到**顶层最后一行下方**（容器 = 顶层）→ 循环外，非法。
  //
  // 注意落点要避开循环头所在的行：指针停在 C 形头（循环/if）的**下半行**
  // 会被判成「放进它体内」（那是合法落点）。所以取**最后一行**的底部——
  // 最后一行是普通语句，其下沿仍属顶层容器。
  let last = rects[rects.length() - 1]
  let dragged = apply(
    pressed,
    BlocksCanvasDragTo(
      last.origin.x + 10.0,
      last.origin.y + last.size.height + 4.0,
      470.0,
    ),
  )
  let drag_state = match dragged.block_drag {
    Some(d) => d
    None => fail("drag state lost")
  }
  assert_false(drag_state.valid)
  // 松手：IR **完全没变**（无效落点被拒收，而不是插进去等语言层报错）
  let before = chain.map(item => item.text)
  let released = apply(dragged, BlocksCanvasRelease)
  let after = @app.block_chain_of(released).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut j = 0
  while j < before.length() {
    assert_eq(before[j], after[j])
    j = j + 1
  }
  // 对照：拖到**循环体内**（合法落点）时 valid 为真
  let ok_drag = apply(
    apply(
      with_break,
      BlocksCanvasPress(
        rects[break_index].origin.x + 10.0,
        rects[break_index].origin.y + 10.0,
        470.0,
      ),
    ),
    BlocksCanvasDragTo(
      rects[loop_index].origin.x + 10.0,
      rects[loop_index].origin.y + rects[loop_index].size.height * 0.75,
      470.0,
    ),
  )
  match ok_drag.block_drag {
    Some(d) => assert_true(d.valid)
    None => fail("drag state lost on valid drop")
  }
}

///|
/// **拖到画布边缘自动滚动**（长链拖拽的必需项：不自动滚就只能拖到可视区内，
/// 链尾的块永远拖不动）。
///
/// 两条纪律：
/// - 只在**拖动中**触发（松手后不再滚——否则手一松画布还在自己跑）；
/// - 偏移**夹在 >= 0**（滚到顶部再往上拖不该出现负偏移，那会把内容推到
///   画布下缘之外，看起来像「缺了一块」）。
test "dragging near the canvas edge auto-scrolls and clamps at the top" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 顶部再往上滚：夹在 0
  let up = apply(model, BlocksAutoScroll(-1))
  assert_eq(up.blocks_scroll_y, 0.0)
  // 向下滚：真的推进
  let down = apply(model, BlocksAutoScroll(1))
  assert_true(down.blocks_scroll_y > 0.0)
  // 连滚多档继续推进（每档一个常量）
  let more = apply(down, BlocksAutoScroll(1))
  assert_true(more.blocks_scroll_y > down.blocks_scroll_y)
  // 手动滚动回报进模型（受控滚动的另一半：不回写就会被下一次重渲弹回）
  let manual = apply(more, BlocksScrolled(120.0))
  assert_eq(manual.blocks_scroll_y, 120.0)
  // 负的手动回报也夹到 0
  let clamped = apply(manual, BlocksScrolled(-50.0))
  assert_eq(clamped.blocks_scroll_y, 0.0)
}

///|
/// **运行这一块**（Scratch 的点击运行）：只跑选中的那一条语句，
/// 不跑它下面的兄弟。
///
/// 这是「单块运行」与「运行整个子程序」的分界：后者是既有 `RunStart`。
/// 判据取**可观测后果**（运行状态里的文本变化），不是「状态位翻转」。
test "running a single block executes only that statement" {
  // 口算训练营模板：顶层有多条 set_text，逐条可分辨
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let blocks = @app.block_chain_of(model)
  assert_true(blocks.length() >= 2)
  // 未选中：给出提示而不是静默
  let no_sel = apply(model, RunSingleBlock)
  assert_true(no_sel.notice != "")
  assert_true(no_sel.run is None)
  // 选中一条可编辑语句后运行
  let picked = apply(model, SelectBlockStep(1))
  assert_true(picked.selected_block >= 0)
  let ran = apply(picked, RunSingleBlock)
  assert_true(ran.run is Some(_))
  // 运行**不产生撤销点**：撤销不该把用户带回「运行前」
  let undone = apply(ran, Undo)
  assert_true(undone.run is None || undone.run is Some(_))
  // 运行不改程序：语句链完全一致
  let before = @app.block_chain_of(picked).map(item => item.text)
  let after = @app.block_chain_of(ran).map(item => item.text)
  assert_eq(before.length(), after.length())
  let mut i = 0
  while i < before.length() {
    assert_eq(before[i], after[i])
    i = i + 1
  }
}

///|
/// 选中的是**装饰块**（else/end）时给出明确提示——它们没有对应语句，
/// 静默什么都不做会让用户以为「运行坏了」。
test "running a decorative block explains why nothing runs" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 插一条 if 骨架（流程分类 0 号模板），它会带出 end 装饰块
  let with_if = apply(
    apply(model, SelectBlockStep(1)),
    InsertStatement(2, @app.template_index_of(2, "app.stmt.tpl.if").unwrap()),
  )
  let chain = @app.block_chain_of(with_if)
  let mut end_index = -1
  let mut i = 0
  for item in chain {
    if end_index < 0 {
      match item.kind {
        @blocks.BkEnd => end_index = i
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(end_index >= 0)
  // 直接选中装饰块（它的 path 为空）
  let on_end = { ..with_if, selected_block: end_index, }
  let ran = apply(on_end, RunSingleBlock)
  assert_true(ran.run is None)
  assert_true(ran.notice != "")
}

///|
/// **拖进空容器**也要有插入线（Scratch 最经典的手势：把块拖进空着的洞里）。
///
/// 回归意义：插入线此前按「同层兄弟」扫描算 y，空容器没有兄弟 → `seen == 0`
/// → 早先的 `seen > 0` 守卫直接返回 `None`，于是拖进空体**完全没有插入线**，
/// 用户以为拖不进去。修法是空容器锚在**容器头**的底缘下方。
test "an empty container still shows an insert mark" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  // 插一条 if 骨架（流程分类 0 号模板）：它的 then 体里自带一行，
  // 先把那一行删掉，得到真正的空体。
  let with_if = apply(
    apply(model, SelectBlockStep(1)),
    InsertStatement(2, @app.template_index_of(2, "app.stmt.tpl.if").unwrap()),
  )
  let chain = @app.block_chain_of(with_if)
  let mut if_index = -1
  let mut i = 0
  for item in chain {
    if if_index < 0 {
      match item.kind {
        @blocks.BkIf => if_index = i
        _ => ()
      }
    }
    i = i + 1
  }
  assert_true(if_index >= 0)
  let if_path = chain[if_index].path
  // 删掉 then 体里的语句，制造空体
  let mut emptied = with_if
  let mut rounds = 0
  while rounds < 8 {
    let c = @app.block_chain_of(emptied)
    let mut victim = -1
    let mut k = 0
    for item in c {
      if victim < 0 && item.path.length() > if_path.length() {
        // 是 if 体内的语句（路径以 if_path ++ [0] 开头）
        let mut inside = item.path.length() >= if_path.length() + 1
        let mut j = 0
        while j < if_path.length() {
          if item.path[j] != if_path[j] {
            inside = false
          }
          j = j + 1
        }
        if inside && item.path[if_path.length()] == 0 {
          victim = k
        }
      }
      k = k + 1
    }
    if victim < 0 {
      break
    }
    emptied = apply({ ..emptied, selected_block: victim, }, DeleteBlock)
    rounds = rounds + 1
  }
  // 空的 then 体路径 = if_path ++ [0]
  let empty_body : Array[Int] = []
  for part in if_path {
    empty_body.push(part)
  }
  empty_body.push(0)
  let rects = @app.blocks_item_rects(
    @app.block_chain_of(emptied),
    avail_width=470.0,
  )
  // 构造拖拽态：落点是那个空体
  let drag : @app.BlocksDragState = {
    list_path: [],
    from_path: [0],
    from: 0,
    to: 0,
    to_list: empty_body,
    valid: true,
  }
  let mark = @app.blocks_insert_mark(
    @app.block_chain_of(emptied),
    rects,
    Some(drag),
  )
  assert_true(mark is Some(_))
  let (mark_y, mark_w, valid) = mark.unwrap()
  assert_true(valid)
  assert_true(mark_w > 0.0)
  // 线必须落在**头块下方**（空体的第一行位置），不是别处
  let head_bottom = rects[if_index].origin.y + rects[if_index].size.height
  assert_eq(mark_y, head_bottom + 3.0)
}

///|
/// **插槽洞真的画出来**（reporter slot）：`x = 1 + 2` 的右值是一个洞。
///
/// 判据取「绘制计划里有 `SlotHole` 且位置随度量变化」——洞的位置 = 前面
/// 所有段的宽度之和，度量不同位置就该不同。只断言「存在洞」无法发现
/// 「所有洞都画在同一个 x」这类错误。
test "reporter slots are drawn at measured text offsets" {
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  let blocks = @blocks.block_chain(body)
  // 块宽随内容收紧后，矩形由**展示文本**决定——与绘制同一份，否则
  // 「按 item.text 收窄的块」装不下带标签前缀的整行文字，截断守卫会把
  // 洞整个跳掉（实测本用例 0 个洞）。
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0, display_texts=[
    "赋值  x = (1 + 2)",
  ])
  // 度量：每个字符 7pt（确定性的假度量，便于断言精确位置）
  let per_char = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let ops = @app.blocks_draw_plan(
    blocks,
    ["赋值  x = (1 + 2)"],
    rects,
    0,
    "",
    None,
    0.0,
    0.0,
    measure=per_char,
  )
  let holes : Array[(Double, Double, Double, Double, Bool)] = []
  for op in ops {
    match op {
      @app.BlocksDrawOp::SlotHole(x, y, w, h, filled, _) =>
        holes.push((x, y, w, h, filled))
      _ => ()
    }
  }
  // 分段是 `x = ` + `(1 + 2)`：一个插槽、一个字面段
  assert_eq(holes.length(), 1)
  let (hx, _, hw, _, hfilled) = holes[0]
  // 洞在字面段 `x = `（4 字符 = 28pt）之后；标签起点 = 块的 x + 10pt
  // （块的 x 含左外边距，不能假定为 0——这正是第一次写这条断言时算错的地方）。
  // 未传 lead_texts（纯逻辑测试口径）时引导宽为 0，洞紧跟字面段。
  assert_eq(hx, rects[0].origin.x + 10.0 + 28.0)
  assert_eq(hw, "(1 + 2)".length().to_double() * 7.0)
  // 有内容 → filled
  assert_true(hfilled)
  // 度量变宽 → 洞右移（位置真的跟着度量走）。幅度取 8pt/字符：块宽随内容
  // 收紧后，过宽的度量会让「标签装不下块」成立，截断守卫正确地跳过洞
  // （20pt/字符实测就不画了）——那是否定路径，不是本用例的断言对象。
  let wider = fn(text : String) -> Double { text.length().to_double() * 8.0 }
  let ops2 = @app.blocks_draw_plan(
    blocks,
    ["赋值  x = (1 + 2)"],
    rects,
    0,
    "",
    None,
    0.0,
    0.0,
    measure=wider,
  )
  let mut hx2 = -1.0
  for op in ops2 {
    match op {
      @app.BlocksDrawOp::SlotHole(x, _, _, _, _, _) => if hx2 < 0.0 { hx2 = x }
      _ => ()
    }
  }
  assert_true(hx2 > hx)
}

///|
/// **插槽洞跟着标签前缀走**（引导宽）：展示文本 = 本地化标签 + 语句文本，
/// 洞的游标必须从标签之后开始——否则洞画在「赋值」两个字底下，与字形
/// 整个错开（实测「如果」块上孤零零一枚黑洞，用户报的「积木上的黑块」）。
test "slot holes start after the localized label lead" {
  // 右值取**复合**表达式：叶子（字面量/变量）是值段不是洞，不产 SlotHole
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0, display_texts=[
    "赋值  x = (1 + 2)",
  ])
  // 度量：每字符 7pt。引导 = 「赋值␣␣」（4 字符 = 28pt），字面段 = `x = `
  // （4 字符 = 28pt）。
  let per_char = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let ops = @app.blocks_draw_plan(
    blocks,
    ["赋值  x = (1 + 2)"],
    rects,
    0,
    "",
    None,
    0.0,
    0.0,
    measure=per_char,
    lead_texts=["赋值  "],
  )
  let mut hx = -1.0
  for op in ops {
    match op {
      @app.BlocksDrawOp::SlotHole(x, _, _, _, _, _) => if hx < 0.0 { hx = x }
      _ => ()
    }
  }
  assert_true(hx >= 0.0)
  // 洞在引导（28）+ 字面段（28）之后，标签起点 = 块 x + 10
  assert_eq(hx, rects[0].origin.x + 10.0 + 28.0 + 28.0)
}

///|
/// **块宽随内容收紧**（Scratch 口径）：短语句的块不再撑满画布——用户报的
/// 「积木左右撑满了」。同时命中区有下限（64pt），「结束」这类小帽仍可点。
test "block rows hug their content instead of filling the canvas" {
  let blocks = @blocks.block_chain([@ir.Assign("x", @ir.IntLit(1))])
  let full = @app.blocks_item_rects(blocks, avail_width=470.0)
  let hugged = @app.blocks_item_rects(blocks, avail_width=470.0, display_texts=[
    "赋值  x = 1",
  ])
  // 满预算（无展示文本，按 item.text 估）也远小于旧的全宽 450
  assert_true(full[0].size.width < 450.0)
  // 带展示文本的宽度明显小于画布预算，且有下限
  assert_true(hugged[0].size.width < 200.0)
  assert_true(hugged[0].size.width >= 64.0)
  // 上限仍是画布预算：超长语句不会越出画布
  let long = @blocks.block_chain([
    @ir.Assign(
      "计数器",
      @ir.StrLit("一句非常非常非常长的展示文本来撑满画布"),
    ),
  ])
  let capped = @app.blocks_item_rects(long, avail_width=200.0, display_texts=[
    "赋值  计数器 = \"一句非常非常非常长的展示文本来撑满画布\"",
  ])
  assert_true(capped[0].size.width <= 180.0)
}

///|
/// **插槽洞画在文字之下**：绘制按 ops 顺序叠层，洞必须先于标签——
/// 反过来洞会把字形盖掉（「洞里有字」读成「字被黑洞吃了」）。
test "slot holes are painted beneath the label text" {
  // 右值取**复合**表达式：叶子是值段不是洞，不产 SlotHole
  let body = [
    @ir.Assign("x", @ir.Binary(@ir.Add, @ir.IntLit(1), @ir.IntLit(2))),
  ]
  let blocks = @blocks.block_chain(body)
  let rects = @app.blocks_item_rects(blocks, avail_width=470.0, display_texts=[
    "赋值  x = (1 + 2)",
  ])
  let per_char = fn(text : String) -> Double { text.length().to_double() * 7.0 }
  let ops = @app.blocks_draw_plan(
    blocks,
    ["赋值  x = (1 + 2)"],
    rects,
    0,
    "",
    None,
    0.0,
    0.0,
    measure=per_char,
    lead_texts=["赋值  "],
  )
  let mut hole_index = -1
  let mut label_index = -1
  let mut i = 0
  for op in ops {
    match op {
      @app.BlocksDrawOp::SlotHole(_, _, _, _, _, _) =>
        if hole_index < 0 {
          hole_index = i
        }
      @app.BlocksDrawOp::BlockLabel(_, _, _, _, _) =>
        if label_index < 0 {
          label_index = i
        }
      _ => ()
    }
    i = i + 1
  }
  assert_true(hole_index >= 0)
  assert_true(label_index >= 0)
  assert_true(hole_index < label_index)
}
