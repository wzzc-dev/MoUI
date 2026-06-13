///|
test "markdown editor pairs delimiters while typing" {
  let parens = markdown_editor_transform_input("Call ", 5, None, "(").unwrap()
  inspect(parens.text, content="Call ()")
  inspect(parens.caret, content="6")
  let brackets = markdown_editor_transform_input(
    "Link text",
    9,
    Some(@core.TextRange::new(start=5, end=9)),
    "[",
  ).unwrap()
  inspect(brackets.text, content="Link [text]")
  inspect(brackets.caret, content="10")
  guard brackets.selection is Some(selection) else {
    fail("expected bracketed selection")
  }
  inspect(selection.start, content="6")
  inspect(selection.end, content="10")
  let quote = markdown_editor_transform_input("say", 0, None, "\"").unwrap()
  inspect(quote.text, content="\"\"say")
  inspect(quote.caret, content="1")
}

///|
test "markdown editor skips existing closing delimiters" {
  let parens = markdown_editor_transform_input("Call ()", 6, None, ")").unwrap()
  inspect(parens.text, content="Call ()")
  inspect(parens.caret, content="7")
  let brackets = markdown_editor_transform_input("[link]", 5, None, "]").unwrap()
  inspect(brackets.text, content="[link]")
  inspect(brackets.caret, content="6")
  let quote = markdown_editor_transform_input("\"word\"", 5, None, "\"").unwrap()
  inspect(quote.text, content="\"word\"")
  inspect(quote.caret, content="6")
  let tick = markdown_editor_transform_input("`code`", 5, None, "`").unwrap()
  inspect(tick.text, content="`code`")
  inspect(tick.caret, content="6")
  let bold = markdown_editor_transform_input("**bold**", 6, None, "**").unwrap()
  inspect(bold.text, content="**bold**")
  inspect(bold.caret, content="8")
  let underscore_bold = markdown_editor_transform_input(
    "__bold__",
    6,
    None,
    "__",
  ).unwrap()
  inspect(underscore_bold.text, content="__bold__")
  inspect(underscore_bold.caret, content="8")
  let strike = markdown_editor_transform_input("~~old~~", 5, None, "~~").unwrap()
  inspect(strike.text, content="~~old~~")
  inspect(strike.caret, content="7")
  let italic = markdown_editor_transform_input("_old_", 4, None, "_").unwrap()
  inspect(italic.text, content="_old_")
  inspect(italic.caret, content="5")
  inspect(
    markdown_editor_transform_input("Call (x", 7, None, ")") is None,
    content="true",
  )
}

///|
test "markdown editor treats apostrophes inside words as text" {
  inspect(
    markdown_editor_transform_input("dont", 3, None, "'") is None,
    content="true",
  )
  let quoted = markdown_editor_transform_input("say ", 4, None, "'").unwrap()
  inspect(quoted.text, content="say ''")
  inspect(quoted.caret, content="5")
}

///|
test "markdown editor backspace removes empty paired delimiters" {
  let parens = markdown_editor_transform_input("Call ()", 6, None, "\u{0008}").unwrap()
  inspect(parens.text, content="Call ")
  inspect(parens.caret, content="5")
  let brackets = markdown_editor_transform_input(
    "Link [] tail",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(brackets.text, content="Link  tail")
  inspect(brackets.caret, content="5")
  let quotes = markdown_editor_transform_input("\"\"", 1, None, "\u{0008}").unwrap()
  inspect(quotes.text, content="")
  inspect(quotes.caret, content="0")
  let ticks = markdown_editor_transform_input("``", 1, None, "\u{0008}").unwrap()
  inspect(ticks.text, content="")
  inspect(ticks.caret, content="0")
  inspect(
    markdown_editor_transform_input("(x)", 1, None, "\u{0008}") is None,
    content="true",
  )
}

///|
test "markdown editor delete removes empty paired delimiters" {
  let parens = markdown_editor_transform_input("Call ()", 5, None, "\u{007f}").unwrap()
  inspect(parens.text, content="Call ")
  inspect(parens.caret, content="5")
  let brackets = markdown_editor_transform_input(
    "Link [] tail",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(brackets.text, content="Link  tail")
  inspect(brackets.caret, content="5")
  let quotes = markdown_editor_transform_input("\"\"", 0, None, "\u{007f}").unwrap()
  inspect(quotes.text, content="")
  inspect(quotes.caret, content="0")
  let ticks = markdown_editor_transform_input("``", 0, None, "\u{007f}").unwrap()
  inspect(ticks.text, content="")
  inspect(ticks.caret, content="0")
  inspect(
    markdown_editor_transform_input("(x)", 0, None, "\u{007f}") is None,
    content="true",
  )
}
