///|
test "markdown editor command duplicates current block" {
  let source = "Alpha\n\nBeta\n\nGamma"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 8, selection: None }),
  )
  inspect(result.source, content="Alpha\n\nBeta\n\nBeta\n\nGamma")
  inspect(result.caret, content="14")
  let selected = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 10, selection: Some(@core.TextRange::new(start=7, end=11)) }),
  )
  inspect(selected.source, content="Alpha\n\nBeta\n\nBeta\n\nGamma")
  inspect(selected.caret, content="16")
  guard selected.selection is Some(selection) else {
    fail("expected duplicated selection")
  }
  inspect(selection.start, content="13")
  inspect(selection.end, content="17")
}

///|
test "markdown editor command duplicates multiline fenced block" {
  let source = "Intro\n```moonbit\nlet x = 1\n```\nTail"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 20, selection: None }),
  )
  inspect(
    result.source,
    content="Intro\n```moonbit\nlet x = 1\n```\n```moonbit\nlet x = 1\n```\nTail",
  )
  inspect(result.caret, content="45")
}

///|
test "markdown editor command duplicates selected block ranges" {
  let source = "Alpha\n\nBeta\n\nGamma"
  let result = markdown_editor_apply_command_at(
    source,
    DuplicateBlock,
    Some({ caret: 8, selection: Some(@core.TextRange::new(start=1, end=11)) }),
  )
  inspect(result.source, content="Alpha\n\nBeta\n\nAlpha\n\nBeta\n\nGamma")
  inspect(result.caret, content="21")
  guard result.selection is Some(selection) else {
    fail("expected duplicated block range selection")
  }
  inspect(selection.start, content="14")
  inspect(selection.end, content="24")
}

///|
test "markdown editor command moves current block up and down" {
  let source = "Alpha\n\nBeta\n\nGamma"
  let moved_up = markdown_editor_apply_command_at(
    source,
    MoveBlockUp,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_up.source, content="Beta\n\nAlpha\n\nGamma")
  inspect(moved_up.caret, content="1")
  let moved_down = markdown_editor_apply_command_at(
    source,
    MoveBlockDown,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_down.source, content="Alpha\n\nGamma\n\nBeta")
  inspect(moved_down.caret, content="15")
}

///|
test "markdown editor command moves selected block ranges as a group" {
  let down = markdown_editor_apply_command_at(
    "Alpha\n\nBeta\n\nGamma",
    MoveBlockDown,
    Some({ caret: 8, selection: Some(@core.TextRange::new(start=1, end=11)) }),
  )
  inspect(down.source, content="Gamma\n\nAlpha\n\nBeta")
  inspect(down.caret, content="15")
  guard down.selection is Some(down_selection) else {
    fail("expected moved block range selection")
  }
  inspect(down_selection.start, content="8")
  inspect(down_selection.end, content="18")

  let up = markdown_editor_apply_command_at(
    "Intro\n\nAlpha\n\nBeta\n\nGamma",
    MoveBlockUp,
    Some({ caret: 16, selection: Some(@core.TextRange::new(start=8, end=18)) }),
  )
  inspect(up.source, content="Alpha\n\nBeta\n\nIntro\n\nGamma")
  inspect(up.caret, content="9")
  guard up.selection is Some(up_selection) else {
    fail("expected moved block range selection")
  }
  inspect(up_selection.start, content="1")
  inspect(up_selection.end, content="11")
}

///|
test "markdown editor command moves blocks across blank separators" {
  let moved_up = markdown_editor_apply_command_at(
    "Alpha\n\nBeta",
    MoveBlockUp,
    Some({ caret: 8, selection: None }),
  )
  inspect(moved_up.source, content="Beta\n\nAlpha")
  inspect(moved_up.caret, content="1")
  let moved_down = markdown_editor_apply_command_at(
    "Alpha\n\nBeta",
    MoveBlockDown,
    Some({ caret: 1, selection: None }),
  )
  inspect(moved_down.source, content="Beta\n\nAlpha")
  inspect(moved_down.caret, content="7")
}

///|
test "markdown editor command moves selected block ranges across blank separators" {
  let moved_down = markdown_editor_apply_command_at(
    "Intro\n\nAlpha\n\nBeta\n\nTail",
    MoveBlockDown,
    Some({ caret: 16, selection: Some(@core.TextRange::new(start=8, end=18)) }),
  )
  inspect(moved_down.source, content="Intro\n\nTail\n\nAlpha\n\nBeta")
  inspect(moved_down.caret, content="22")
  guard moved_down.selection is Some(selection) else {
    fail("expected moved block range selection across blank separators")
  }
  inspect(selection.start, content="14")
  inspect(selection.end, content="24")
}

///|
test "markdown editor block move no-ops at document edges" {
  let source = "Alpha\nBeta"
  let first = markdown_editor_apply_command_at(
    source,
    MoveBlockUp,
    Some({ caret: 1, selection: None }),
  )
  inspect(first.source, content=source)
  inspect(first.caret, content="1")
  let last = markdown_editor_apply_command_at(
    source,
    MoveBlockDown,
    Some({ caret: 8, selection: None }),
  )
  inspect(last.source, content=source)
  inspect(last.caret, content="8")
}
