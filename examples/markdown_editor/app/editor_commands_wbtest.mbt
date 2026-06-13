///|
test "markdown editor core applies typed commands" {
  inspect(markdown_editor_apply_command("", Heading(2)), content="## Section")
  inspect(
    markdown_editor_apply_command("", Heading(6)),
    content="###### Caption",
  )
  inspect(markdown_editor_apply_command("", HorizontalRule), content="---")
  inspect(
    markdown_editor_apply_command("Base", Bold),
    content="Base\n\n**bold text**",
  )
}

///|
test "markdown editor inline command wraps selected source range" {
  let result = markdown_editor_apply_command_at(
    "# Title",
    Bold,
    Some({ caret: 7, selection: Some(@core.TextRange::new(start=2, end=7)) }),
  )
  inspect(result.source, content="# **Title**")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected updated selection")
  }
  inspect(selection.start, content="4")
  inspect(selection.end, content="9")
}

///|
test "markdown editor typed inline marker wraps selected source range" {
  let bold = markdown_editor_transform_input(
    "Text bold tail",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "**",
  ).unwrap()
  inspect(bold.text, content="Text **bold** tail")
  inspect(bold.caret, content="11")
  guard bold.selection is Some(bold_selection) else {
    fail("expected bold selection")
  }
  inspect(bold_selection.start, content="7")
  inspect(bold_selection.end, content="11")
  let code = markdown_editor_transform_input(
    "Use code now",
    8,
    Some(@core.TextRange::new(start=4, end=8)),
    "`",
  ).unwrap()
  inspect(code.text, content="Use `code` now")
  let strike = markdown_editor_transform_input(
    "old text",
    3,
    Some(@core.TextRange::new(start=0, end=3)),
    "~~",
  ).unwrap()
  inspect(strike.text, content="~~old~~ text")
}

///|
test "markdown editor typed inline marker unwraps selected formatted range" {
  let result = markdown_editor_transform_input(
    "Text **bold** tail",
    11,
    Some(@core.TextRange::new(start=7, end=11)),
    "**",
  ).unwrap()
  inspect(result.text, content="Text bold tail")
  inspect(result.caret, content="9")
  guard result.selection is Some(selection) else {
    fail("expected unwrapped selection")
  }
  inspect(selection.start, content="5")
  inspect(selection.end, content="9")
}
