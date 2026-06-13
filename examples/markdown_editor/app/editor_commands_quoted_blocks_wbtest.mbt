///|
test "markdown editor current line block commands preserve quote context" {
  let bullet = markdown_editor_apply_command_at(
    "> First",
    BulletList,
    Some({ caret: 4, selection: None }),
  )
  inspect(bullet.source, content="> - First")
  inspect(bullet.caret, content="6")

  let task = markdown_editor_apply_command_at(
    "> First",
    TaskList,
    Some({ caret: 7, selection: None }),
  )
  inspect(task.source, content="> - [ ] First")
  inspect(task.caret, content="13")

  let ordered = markdown_editor_apply_command_at(
    "> First",
    OrderedList,
    Some({ caret: 7, selection: None }),
  )
  inspect(ordered.source, content="> 1. First")
  inspect(ordered.caret, content="10")

  let nested = markdown_editor_apply_command_at(
    "> > First",
    BulletList,
    Some({ caret: 9, selection: None }),
  )
  inspect(nested.source, content="> > - First")
  inspect(nested.caret, content="11")

  let toggled = markdown_editor_apply_command_at(
    "> - First",
    BulletList,
    Some({ caret: 9, selection: None }),
  )
  inspect(toggled.source, content="> First")
  inspect(toggled.caret, content="7")

  let replaced = markdown_editor_apply_command_at(
    "> - First",
    OrderedList,
    Some({ caret: 9, selection: None }),
  )
  inspect(replaced.source, content="> 1. First")
  inspect(replaced.caret, content="10")

  let heading = markdown_editor_apply_command_at(
    "> First",
    Heading(2),
    Some({ caret: 7, selection: None }),
  )
  inspect(heading.source, content="> ## First")
  inspect(heading.caret, content="10")

  let heading_toggle = markdown_editor_apply_command_at(
    "> ## First",
    Heading(2),
    Some({ caret: 10, selection: None }),
  )
  inspect(heading_toggle.source, content="> First")
  inspect(heading_toggle.caret, content="7")

  let heading_level = markdown_editor_apply_command_at(
    "> ## First",
    Heading(3),
    Some({ caret: 10, selection: None }),
  )
  inspect(heading_level.source, content="> ### First")
  inspect(heading_level.caret, content="11")

  let nested_heading = markdown_editor_apply_command_at(
    "> > First",
    Heading(1),
    Some({ caret: 9, selection: None }),
  )
  inspect(nested_heading.source, content="> > # First")
  inspect(nested_heading.caret, content="11")
}
