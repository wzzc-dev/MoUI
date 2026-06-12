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
test "markdown editor pairs inline markdown markers while typing" {
  let bold = markdown_editor_transform_input("Say ", 4, None, "**").unwrap()
  inspect(bold.text, content="Say ****")
  inspect(bold.caret, content="6")
  let underscore_bold = markdown_editor_transform_input("Say ", 4, None, "__").unwrap()
  inspect(underscore_bold.text, content="Say ____")
  inspect(underscore_bold.caret, content="6")
  let code = markdown_editor_transform_input("Use  now", 4, None, "`").unwrap()
  inspect(code.text, content="Use `` now")
  inspect(code.caret, content="5")
  let strike = markdown_editor_transform_input("old", 0, None, "~~").unwrap()
  inspect(strike.text, content="~~~~old")
  inspect(strike.caret, content="2")
  inspect(
    markdown_editor_transform_input("*", 1, None, "*") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("word", 4, None, "_") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\ncode\n```", 4, None, "**") is None,
    content="true",
  )
}

///|
test "markdown editor wraps selected text with inline markdown markers" {
  let italic = markdown_editor_transform_input(
    "Say old",
    7,
    Some(@core.TextRange::new(start=4, end=7)),
    "_",
  ).unwrap()
  inspect(italic.text, content="Say _old_")
  inspect(italic.caret, content="8")
  guard italic.selection is Some(selection) else {
    fail("expected italic selection")
  }
  inspect(selection.start, content="5")
  inspect(selection.end, content="8")
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

///|
test "markdown editor removes empty inline marker pairs at caret edges" {
  let backspace_middle = markdown_editor_transform_input(
    "Say ****",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_middle.text, content="Say ")
  inspect(backspace_middle.caret, content="4")
  let backspace_after = markdown_editor_transform_input(
    "Say ****",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_after.text, content="Say ")
  inspect(backspace_after.caret, content="4")
  let delete_before = markdown_editor_transform_input(
    "Say ____",
    4,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_before.text, content="Say ")
  inspect(delete_before.caret, content="4")
  let delete_middle = markdown_editor_transform_input(
    "Say ~~~~",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_middle.text, content="Say ")
  inspect(delete_middle.caret, content="4")
  let tick_backspace = markdown_editor_transform_input(
    "``",
    2,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(tick_backspace.text, content="")
  inspect(tick_backspace.caret, content="0")
  let tick_delete = markdown_editor_transform_input("``", 0, None, "\u{007f}").unwrap()
  inspect(tick_delete.text, content="")
  inspect(tick_delete.caret, content="0")
}

///|
test "markdown editor removes reference-style markers at caret edges" {
  let backspace_link = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_link.text, content="Visit MoUI today")
  inspect(backspace_link.caret, content="6")

  let delete_link = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_link.text, content="Visit MoUI today")
  inspect(delete_link.caret, content="6")

  let backspace_image = markdown_editor_transform_input(
    "Insert ![logo][asset] here",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_image.text, content="Insert logo here")
  inspect(backspace_image.caret, content="7")

  let delete_image = markdown_editor_transform_input(
    "Insert ![logo][asset] here",
    13,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_image.text, content="Insert logo here")
  inspect(delete_image.caret, content="7")

  let shortcut = markdown_editor_transform_input(
    "Visit [MoUI] today\n\n[MoUI]: https://moui.dev",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(shortcut.text, content="Visit MoUI today\n\n[MoUI]: https://moui.dev")
  inspect(shortcut.caret, content="6")

  inspect(
    markdown_editor_transform_input("Visit [MoUI] today", 7, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes reference markers at outside edges" {
  let link_backspace = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    30,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(link_backspace.text, content="Visit MoUI today")
  inspect(link_backspace.caret, content="6")

  let link_delete = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(link_delete.text, content="Visit MoUI today")
  inspect(link_delete.caret, content="6")

  let image_backspace = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    25,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(image_backspace.text, content="Insert logo here")
  inspect(image_backspace.caret, content="7")

  let image_delete = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(image_delete.text, content="Insert logo here")
  inspect(image_delete.caret, content="7")

  let reference_backspace = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    18,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(reference_backspace.text, content="Visit MoUI today")
  inspect(reference_backspace.caret, content="6")

  let reference_delete = markdown_editor_transform_input(
    "Visit [MoUI][site] today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(reference_delete.text, content="Visit MoUI today")
  inspect(reference_delete.caret, content="6")

  let shortcut_backspace = markdown_editor_transform_input(
    "Visit [MoUI] today\n\n[MoUI]: https://moui.dev",
    12,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(
    shortcut_backspace.text,
    content="Visit MoUI today\n\n[MoUI]: https://moui.dev",
  )
  inspect(shortcut_backspace.caret, content="6")

  inspect(
    markdown_editor_transform_input("Visit [MoUI] today", 12, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes footnote reference markers at caret edges" {
  let source = "See [^note] here\n\n[^note]: More"
  let backspace_open = markdown_editor_transform_input(
    source,
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_open.text, content="See note here\n\n[^note]: More")
  inspect(backspace_open.caret, content="4")

  let delete_close = markdown_editor_transform_input(
    source,
    10,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_close.text, content="See note here\n\n[^note]: More")
  inspect(delete_close.caret, content="4")

  let backspace_end = markdown_editor_transform_input(
    source,
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_end.text, content="See note here\n\n[^note]: More")
  inspect(backspace_end.caret, content="4")

  let delete_open = markdown_editor_transform_input(source, 4, None, "\u{007f}").unwrap()
  inspect(delete_open.text, content="See note here\n\n[^note]: More")
  inspect(delete_open.caret, content="4")

  inspect(
    markdown_editor_transform_input("See [^] here", 6, None, "\u{0008}") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("See [^note here", 6, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes autolink markers at caret edges" {
  let backspace_url = markdown_editor_transform_input(
    "Visit <https://moui.dev> today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_url.text, content="Visit https://moui.dev today")
  inspect(backspace_url.caret, content="6")

  let delete_url = markdown_editor_transform_input(
    "Visit <https://moui.dev> today",
    23,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_url.text, content="Visit https://moui.dev today")
  inspect(delete_url.caret, content="6")

  let backspace_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_email.text, content="Mail hello@example.dev now")
  inspect(backspace_email.caret, content="5")

  let delete_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    23,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_email.text, content="Mail hello@example.dev now")
  inspect(delete_email.caret, content="5")

  inspect(
    markdown_editor_transform_input("Visit <not a link>", 17, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes autolink markers at outside edges" {
  let backspace_url = markdown_editor_transform_input(
    "Visit <https://moui.dev> today",
    24,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_url.text, content="Visit https://moui.dev today")
  inspect(backspace_url.caret, content="6")

  let delete_url = markdown_editor_transform_input(
    "Visit <https://moui.dev> today",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_url.text, content="Visit https://moui.dev today")
  inspect(delete_url.caret, content="6")

  let backspace_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    24,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_email.text, content="Mail hello@example.dev now")
  inspect(backspace_email.caret, content="5")

  let delete_email = markdown_editor_transform_input(
    "Mail <hello@example.dev> now",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete_email.text, content="Mail hello@example.dev now")
  inspect(delete_email.caret, content="5")

  inspect(
    markdown_editor_transform_input("Visit <not a link>", 6, None, "\u{007f}")
    is None,
    content="true",
  )
}
