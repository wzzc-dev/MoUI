///|
test "markdown editor code block wraps current line and selected lines" {
  let current = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nTail",
    CodeBlock,
    Some({ caret: 8, selection: None }),
  )
  inspect(current.source, content="Intro\n```\nlet x = 1\n```\nTail")
  inspect(current.caret, content="12")
  let selected = markdown_editor_apply_command_at(
    "Intro\nlet x = 1\nlet y = 2\nTail",
    CodeBlock,
    Some({ caret: 25, selection: Some(@core.TextRange::new(start=6, end=25)) }),
  )
  inspect(
    selected.source,
    content="Intro\n```\nlet x = 1\nlet y = 2\n```\nTail",
  )
  guard selected.selection is Some(selection) else {
    fail("expected selected code content")
  }
  inspect(selection.start, content="10")
  inspect(selection.end, content="29")

  let quoted_current = markdown_editor_apply_command_at(
    "> let x = 1",
    CodeBlock,
    Some({ caret: 4, selection: None }),
  )
  inspect(quoted_current.source, content="> ```\n> let x = 1\n> ```")
  inspect(quoted_current.caret, content="10")

  let quoted_source = "Intro\n> let x = 1\n> let y = 2\nTail"
  let quoted_end = markdown_editor_text_length(
    "Intro\n> let x = 1\n> let y = 2",
  )
  let quoted_selected = markdown_editor_apply_command_at(
    quoted_source,
    CodeBlock,
    Some({
      caret: quoted_end,
      selection: Some(@core.TextRange::new(start=6, end=quoted_end)),
    }),
  )
  inspect(
    quoted_selected.source,
    content="Intro\n> ```\n> let x = 1\n> let y = 2\n> ```\nTail",
  )
  guard quoted_selected.selection is Some(quoted_selection) else {
    fail("expected selected quoted code content")
  }
  inspect(quoted_selection.start, content="12")
  inspect(quoted_selection.end, content="35")
}

///|
test "markdown editor code block unwraps containing fenced block" {
  let result = markdown_editor_apply_command_at(
    "Intro\n```\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 12, selection: None }),
  )
  inspect(result.source, content="Intro\nlet x = 1\nTail")
  inspect(result.caret, content="8")
  let tagged = markdown_editor_apply_command_at(
    "Intro\n```moonbit\nlet x = 1\n```\nTail",
    CodeBlock,
    Some({ caret: 20, selection: None }),
  )
  inspect(tagged.source, content="Intro\nlet x = 1\nTail")
  inspect(tagged.caret, content="9")
  let quoted = markdown_editor_apply_command_at(
    "> ```\n> let x = 1\n> ```",
    CodeBlock,
    Some({ caret: 10, selection: None }),
  )
  inspect(quoted.source, content="> let x = 1")
  inspect(quoted.caret, content="4")
  let quoted_selection_source = "Intro\n> ```\n> let x = 1\n> let y = 2\n> ```\nTail"
  let quoted_selection_end = markdown_editor_text_length(
    "Intro\n> ```\n> let x = 1\n> let y = 2",
  )
  let quoted_selected = markdown_editor_apply_command_at(
    quoted_selection_source,
    CodeBlock,
    Some({
      caret: quoted_selection_end,
      selection: Some(@core.TextRange::new(start=12, end=quoted_selection_end)),
    }),
  )
  inspect(
    quoted_selected.source,
    content="Intro\n> let x = 1\n> let y = 2\nTail",
  )
  inspect(quoted_selected.caret, content="29")
  guard quoted_selected.selection is Some(quoted_selection) else {
    fail("expected unwrapped quoted code selection")
  }
  inspect(quoted_selection.start, content="6")
  inspect(quoted_selection.end, content="29")
  let nested_quoted = markdown_editor_apply_command_at(
    "> > ```\n> > code\n> > ```",
    CodeBlock,
    Some({ caret: 12, selection: None }),
  )
  inspect(nested_quoted.source, content="> > code")
  inspect(nested_quoted.caret, content="4")
}
