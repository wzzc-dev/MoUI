///|
/// 插入位置：选中块之后（同层），不是末尾。这是「插入」与「追加」的分野。
test "insert statement lands right after the selected block" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let before = @app.block_chain_of(model)
  assert_true(before.length() >= 2)
  let original_second = before[1].text
  let selected = select_block_index(model, 0)
  let inserted = apply(selected, InsertStatement(3, @app.template_index_of(3, "app.stmt.tpl.message").unwrap()))
  let after = @app.block_chain_of(inserted)
  assert_eq(after.length(), before.length() + 1)
  // 新语句插在下标 1，原第二条被挤到下标 2
  assert_eq(after[2].text, original_second)
  assert_eq(inserted.selected_block, 1)
}

///|
/// 插入可撤销：与 commit/delete 同一口径（写回 IR 才产生还原点）。
test "inserted statement is undoable" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let count = @app.block_chain_of(model).length()
  let inserted = apply(model, InsertStatement(3, @app.template_index_of(3, "app.stmt.tpl.message").unwrap()))
  assert_eq(@app.block_chain_of(inserted).length(), count + 1)
  let undone = apply(inserted, Undo)
  assert_eq(@app.block_chain_of(undone).length(), count)
}

///|
/// 没有选中子程序时插入是安全的 no-op（给提示，不改 IR）。
test "insert statement without a handler is a safe no-op" {
  let model = apply(@app.initial_model(), ClearSelection)
  let before = model.program.handlers.length()
  let inserted = apply(model, InsertStatement(3, @app.template_index_of(3, "app.stmt.tpl.message").unwrap()))
  assert_eq(inserted.program.handlers.length(), before)
  assert_true(@app.block_chain_of(inserted).length() == 0)
}

///|
/// 越界的分类/模板下标是安全的 no-op（命令面板与旧配置都可能送进脏下标）。
test "insert statement ignores out-of-range indices" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let count = @app.block_chain_of(model).length()
  for bad in [(99, 0), (3, 99), (-1, 0)] {
    let (category, template) = bad
    let inserted = apply(model, InsertStatement(category, template))
    assert_eq(@app.block_chain_of(inserted).length(), count)
  }
}

///|
/// 再点同一个分类 = 收起（与图标栏「再点当前项」同一心智）；
/// 点另一个分类 = 直接切换（不要求先收起）。
test "statement palette toggles on the same category and switches on another" {
  let model = apply(@app.initial_model(), SelectTemplate(2))
  let opened = apply(model, ToggleStatementPalette(3))
  assert_true(opened.statement_palette_open)
  let closed = apply(opened, ToggleStatementPalette(3))
  assert_true(!closed.statement_palette_open)
  let switched = apply(opened, ToggleStatementPalette(2))
  assert_true(switched.statement_palette_open)
  assert_eq(switched.selected_category, 2)
}

///|
/// 每个分类的骨架都必须能被双语解析器接受——骨架表是数据，写错一条
/// 就会在运行时变成「点了没反应」。这条锁定整表。
test "every statement template parses in both languages" {
  for template in @app.statement_templates() {
    for language in [@studio_lang.ZhHans, @studio_lang.En] {
      let language_name = if language is @studio_lang.ZhHans {
        "zh-Hans"
      } else {
        "en"
      }
      let source = template.skeleton(language)
      match @studio_lang.parse_handler_body(source, language) {
        Ok(body) => assert_true(body.length() > 0)
        Err(_) =>
          fail(
            "template " +
            template.label_key +
            " does not parse as " +
            language_name +
            ": " +
            source,
          )
      }
    }
  }
}

///|
/// 分类下标 ↔ 分类的映射是唯一来源：分类轨与插入面板共用它，
/// 两处各写一份会出现「点第三个分类插入第二个分类的语句」。
test "category index mapping matches the rail order" {
  let expected = [
    @blocks.CatEvent,
    @blocks.CatVariable,
    @blocks.CatFlow,
    @blocks.CatCommand,
    @blocks.CatExpression,
  ]
  let mut index = 0
  for category in expected {
    match @app.category_at(index) {
      Some(actual) =>
        assert_true(
          @blocks.category_color_key(actual) ==
          @blocks.category_color_key(category),
        )
      None => fail("category_at(" + index.to_string() + ") is None")
    }
    index = index + 1
  }
  assert_true(@app.category_at(5) is None)
}
