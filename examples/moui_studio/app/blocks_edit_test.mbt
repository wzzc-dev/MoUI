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
    Some({ list_path, from: 0, to: 0, }),
  )
  let (top_y, _) = mark_top.unwrap()
  assert_eq(top_y, rects[0].origin.y - 3.0)
  // 落槽 = 兄弟总数：最后一条兄弟底缘下方 3pt
  let mark_bottom = @app.blocks_insert_mark(
    blocks,
    rects,
    Some({ list_path, from: 0, to: blocks.length(), }),
  )
  let (bottom_y, _) = mark_bottom.unwrap()
  assert_eq(bottom_y, rects[blocks.length() - 1].max_y() + 3.0)
  // 无拖拽：无指示线
  assert_true(@app.blocks_insert_mark(blocks, rects, None) is None)
}
