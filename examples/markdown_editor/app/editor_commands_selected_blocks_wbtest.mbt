///|
test "markdown editor block command transforms selected lines" {
  let bullet = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    BulletList,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(bullet.source, content="Intro\n- First\n- Second\nTail")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected transformed bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="22")
  let ordered = markdown_editor_apply_command_at(
    "Intro\n- First\n- Second\nTail",
    OrderedList,
    Some({ caret: 22, selection: Some(@core.TextRange::new(start=6, end=22)) }),
  )
  inspect(ordered.source, content="Intro\n1. First\n2. Second\nTail")
  let quote = markdown_editor_apply_command_at(
    "Intro\n1. First\n2. Second\nTail",
    Quote,
    Some({ caret: 24, selection: Some(@core.TextRange::new(start=6, end=24)) }),
  )
  inspect(quote.source, content="Intro\n> First\n> Second\nTail")
  let rule = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    HorizontalRule,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(rule.source, content="Intro\n---\nTail")
  guard rule.selection is Some(rule_selection) else {
    fail("expected rule selection")
  }
  inspect(rule_selection.start, content="6")
  inspect(rule_selection.end, content="9")
  let table = markdown_editor_apply_command_at(
    "Intro\nFirst\nSecond\nTail",
    Table,
    Some({ caret: 18, selection: Some(@core.TextRange::new(start=6, end=18)) }),
  )
  inspect(
    table.source,
    content="Intro\n| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\nTail",
  )
  inspect(table.caret, content="8")
}

///|
test "markdown editor selected list commands preserve blank separator lines" {
  let bullet = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    BulletList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(bullet.source, content="Intro\n- First\n\n- Second\nTail")
  inspect(bullet.caret, content="23")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="23")

  let task = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    TaskList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(task.source, content="Intro\n- [ ] First\n\n- [ ] Second\nTail")
  inspect(task.caret, content="31")

  let ordered = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    OrderedList,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(ordered.source, content="Intro\n1. First\n\n2. Second\nTail")
  inspect(ordered.caret, content="25")

  let quote = markdown_editor_apply_command_at(
    "Intro\nFirst\n\nSecond\nTail",
    Quote,
    Some({ caret: 19, selection: Some(@core.TextRange::new(start=6, end=19)) }),
  )
  inspect(quote.source, content="Intro\n> First\n> \n> Second\nTail")
}

///|
test "markdown editor selected list commands preserve nested indentation" {
  let source = "Intro\nParent\n  Child\n  More\nTail"
  let selection_end = markdown_editor_text_length(
    "Intro\nParent\n  Child\n  More",
  )
  let selected = Some({
    caret: selection_end,
    selection: Some(@core.TextRange::new(start=6, end=selection_end)),
  })
  let bullet = markdown_editor_apply_command_at(source, BulletList, selected)
  inspect(bullet.source, content="Intro\n- Parent\n  - Child\n  - More\nTail")
  let task = markdown_editor_apply_command_at(source, TaskList, selected)
  inspect(
    task.source,
    content="Intro\n- [ ] Parent\n  - [ ] Child\n  - [ ] More\nTail",
  )
  let ordered = markdown_editor_apply_command_at(source, OrderedList, selected)
  inspect(
    ordered.source,
    content="Intro\n1. Parent\n  1. Child\n  2. More\nTail",
  )
  let quote = markdown_editor_apply_command_at(source, Quote, selected)
  inspect(quote.source, content="Intro\n> Parent\n  > Child\n  > More\nTail")

  let marked_source = "Intro\n- Parent\n  - Child\nTail"
  let marked_end = markdown_editor_text_length("Intro\n- Parent\n  - Child")
  let marked = markdown_editor_apply_command_at(
    marked_source,
    TaskList,
    Some({
      caret: marked_end,
      selection: Some(@core.TextRange::new(start=6, end=marked_end)),
    }),
  )
  inspect(marked.source, content="Intro\n- [ ] Parent\n  - [ ] Child\nTail")
}

///|
test "markdown editor selected list commands preserve quote context" {
  let source = "Intro\n> First\n> Second\nTail"
  let selection_end = markdown_editor_text_length("Intro\n> First\n> Second")
  let selected = Some({
    caret: selection_end,
    selection: Some(@core.TextRange::new(start=6, end=selection_end)),
  })
  let bullet = markdown_editor_apply_command_at(source, BulletList, selected)
  inspect(bullet.source, content="Intro\n> - First\n> - Second\nTail")
  guard bullet.selection is Some(bullet_selection) else {
    fail("expected quoted bullet selection")
  }
  inspect(bullet_selection.start, content="6")
  inspect(bullet_selection.end, content="26")

  let task = markdown_editor_apply_command_at(source, TaskList, selected)
  inspect(task.source, content="Intro\n> - [ ] First\n> - [ ] Second\nTail")

  let ordered = markdown_editor_apply_command_at(source, OrderedList, selected)
  inspect(ordered.source, content="Intro\n> 1. First\n> 2. Second\nTail")

  let nested_source = "Intro\n> First\n> > Nested\n> Second\nTail"
  let nested_end = markdown_editor_text_length(
    "Intro\n> First\n> > Nested\n> Second",
  )
  let nested_ordered = markdown_editor_apply_command_at(
    nested_source,
    OrderedList,
    Some({
      caret: nested_end,
      selection: Some(@core.TextRange::new(start=6, end=nested_end)),
    }),
  )
  inspect(
    nested_ordered.source,
    content="Intro\n> 1. First\n> > 1. Nested\n> 2. Second\nTail",
  )

  let marked_source = "Intro\n> - First\n> 9. Second\nTail"
  let marked_end = markdown_editor_text_length("Intro\n> - First\n> 9. Second")
  let marked = markdown_editor_apply_command_at(
    marked_source,
    OrderedList,
    Some({
      caret: marked_end,
      selection: Some(@core.TextRange::new(start=6, end=marked_end)),
    }),
  )
  inspect(marked.source, content="Intro\n> 1. First\n> 2. Second\nTail")

  let blank_source = "Intro\n> First\n> \n> Second\nTail"
  let blank_end = markdown_editor_text_length("Intro\n> First\n> \n> Second")
  let blank = markdown_editor_apply_command_at(
    blank_source,
    BulletList,
    Some({
      caret: blank_end,
      selection: Some(@core.TextRange::new(start=6, end=blank_end)),
    }),
  )
  inspect(blank.source, content="Intro\n> - First\n> \n> - Second\nTail")

  let quote = markdown_editor_apply_command_at(source, Quote, selected)
  inspect(quote.source, content=source)
}

///|
test "markdown editor block commands renumber ordered list context" {
  let converted = markdown_editor_apply_command_at(
    "1. first\nsecond\n9. third",
    OrderedList,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=15)) }),
  )
  inspect(converted.source, content="1. first\n2. second\n3. third")
  guard converted.selection is Some(converted_selection) else {
    fail("expected converted ordered line selection")
  }
  inspect(converted_selection.start, content="10")
  inspect(converted_selection.end, content="18")
  let unlisted = markdown_editor_apply_command_at(
    "1. first\n2. second\n3. third",
    Paragraph,
    Some({ caret: 15, selection: Some(@core.TextRange::new(start=9, end=18)) }),
  )
  inspect(unlisted.source, content="1. first\nsecond\n3. third")
}

///|
test "markdown editor app block command uses tracked multi-line selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nFirst\nSecond")
  app.set_selection(18, Some(@core.TextRange::new(start=6, end=18)))
  app.apply_command_to_selection(TaskList)
  inspect(app.document(), content="Intro\n- [ ] First\n- [ ] Second")
}

///|
test "markdown editor app command renumbers ordered list context" {
  let app = MarkdownEditorApp::new()
  app.set_document("1. first\nsecond\n9. third")
  app.set_selection(15, Some(@core.TextRange::new(start=9, end=15)))
  app.apply_command_to_selection(OrderedList)
  inspect(app.document(), content="1. first\n2. second\n3. third")
}
