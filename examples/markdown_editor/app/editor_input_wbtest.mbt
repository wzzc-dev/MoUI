///|
test "markdown editor enter continues list task quote and ordered markers" {
  let bullet = markdown_editor_transform_input("- item", 6, None, "\n").unwrap()
  inspect(bullet.text, content="- item\n- ")
  inspect(bullet.caret, content="9")
  let task = markdown_editor_transform_input("- [x] done", 10, None, "\n").unwrap()
  inspect(task.text, content="- [x] done\n- [ ] ")
  let quote = markdown_editor_transform_input("> quote", 7, None, "\n").unwrap()
  inspect(quote.text, content="> quote\n> ")
  let ordered = markdown_editor_transform_input("3. item", 7, None, "\n").unwrap()
  inspect(ordered.text, content="3. item\n4. ")
  let nested = markdown_editor_transform_input(
    "- parent\n  - child",
    18,
    None,
    "\n",
  ).unwrap()
  inspect(nested.text, content="- parent\n  - child\n  - ")
  let quoted_bullet = markdown_editor_transform_input("> - item", 8, None, "\n").unwrap()
  inspect(quoted_bullet.text, content="> - item\n> - ")
  inspect(quoted_bullet.caret, content="13")
  let quoted_task = markdown_editor_transform_input(
    "> - [x] done",
    12,
    None,
    "\n",
  ).unwrap()
  inspect(quoted_task.text, content="> - [x] done\n> - [ ] ")
  let quoted_ordered = markdown_editor_transform_input(
    "> 3. item",
    9,
    None,
    "\n",
  ).unwrap()
  inspect(quoted_ordered.text, content="> 3. item\n> 4. ")
}

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

///|
test "markdown editor enter exits empty continuation markers" {
  let bullet = markdown_editor_transform_input("- ", 2, None, "\n").unwrap()
  inspect(bullet.text, content="")
  inspect(bullet.caret, content="0")
  let task = markdown_editor_transform_input("- [ ] ", 6, None, "\n").unwrap()
  inspect(task.text, content="")
  inspect(task.caret, content="0")
  let quote = markdown_editor_transform_input("> ", 2, None, "\n").unwrap()
  inspect(quote.text, content="")
  inspect(quote.caret, content="0")
  let ordered = markdown_editor_transform_input("1. ", 3, None, "\n").unwrap()
  inspect(ordered.text, content="")
  inspect(ordered.caret, content="0")
  let nested = markdown_editor_transform_input("- parent\n  - ", 12, None, "\n").unwrap()
  inspect(nested.text, content="- parent\n- ")
  inspect(nested.caret, content="11")
  let nested_task = markdown_editor_transform_input(
    "- parent\n  - [ ] ",
    16,
    None,
    "\n",
  ).unwrap()
  inspect(nested_task.text, content="- parent\n- [ ] ")
  inspect(nested_task.caret, content="15")
  let quoted_bullet = markdown_editor_transform_input("> - ", 4, None, "\n").unwrap()
  inspect(quoted_bullet.text, content="> ")
  inspect(quoted_bullet.caret, content="2")
  let quoted_ordered = markdown_editor_transform_input("> 4. ", 5, None, "\n").unwrap()
  inspect(quoted_ordered.text, content="> ")
  inspect(quoted_ordered.caret, content="2")
  let nested_quote = markdown_editor_transform_input("> > ", 4, None, "\n").unwrap()
  inspect(nested_quote.text, content="> ")
  inspect(nested_quote.caret, content="2")
  let deep_quote = markdown_editor_transform_input("> > > ", 6, None, "\n").unwrap()
  inspect(deep_quote.text, content="> > ")
  inspect(deep_quote.caret, content="4")
  let nested_quoted_bullet = markdown_editor_transform_input(
    "> > - ",
    6,
    None,
    "\n",
  ).unwrap()
  inspect(nested_quoted_bullet.text, content="> > ")
  inspect(nested_quoted_bullet.caret, content="4")
  let nested_quoted_task = markdown_editor_transform_input(
    "> > - [ ] ",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(nested_quoted_task.text, content="> > ")
  inspect(nested_quoted_task.caret, content="4")
  let middle = markdown_editor_transform_input("Intro\n- \nTail", 8, None, "\n").unwrap()
  inspect(middle.text, content="Intro\n\nTail")
  inspect(middle.caret, content="6")
}

///|
test "markdown editor backspace and delete exit empty continuation markers" {
  let bullet_backspace = markdown_editor_transform_input(
    "- ",
    2,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bullet_backspace.text, content="")
  inspect(bullet_backspace.caret, content="0")

  let nested_list = "- parent\n  - "
  let nested_backspace = markdown_editor_transform_input(
    nested_list,
    markdown_editor_text_length(nested_list),
    None,
    "\u{0008}",
  ).unwrap()
  inspect(nested_backspace.text, content="- parent\n- ")
  inspect(nested_backspace.caret, content="11")

  let nested_quote_backspace = markdown_editor_transform_input(
    "> > ",
    4,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(nested_quote_backspace.text, content="> ")
  inspect(nested_quote_backspace.caret, content="2")

  let nested_quote_delete = markdown_editor_transform_input(
    "> > ",
    0,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(nested_quote_delete.text, content="> ")
  inspect(nested_quote_delete.caret, content="2")

  let middle_delete = markdown_editor_transform_input(
    "Intro\n> - \nTail",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(middle_delete.text, content="Intro\n> \nTail")
  inspect(middle_delete.caret, content="8")
}

///|
test "markdown editor hard break preserves writing context" {
  let paragraph = markdown_editor_insert_hard_break("HelloWorld", 5, None).unwrap()
  inspect(paragraph.text, content="Hello  \nWorld")
  inspect(paragraph.caret, content="8")

  let quote = markdown_editor_insert_hard_break("> Hello", 7, None).unwrap()
  inspect(quote.text, content="> Hello  \n> ")
  inspect(quote.caret, content="12")

  let bullet = markdown_editor_insert_hard_break("- Hello", 7, None).unwrap()
  inspect(bullet.text, content="- Hello  \n  ")
  inspect(bullet.caret, content="12")

  let task = markdown_editor_insert_hard_break("- [x] Todo", 10, None).unwrap()
  inspect(task.text, content="- [x] Todo  \n      ")
  inspect(task.caret, content="19")

  let ordered = markdown_editor_insert_hard_break("12. Item", 8, None).unwrap()
  inspect(ordered.text, content="12. Item  \n    ")
  inspect(ordered.caret, content="15")

  let quoted_bullet = markdown_editor_insert_hard_break("> - Item", 8, None).unwrap()
  inspect(quoted_bullet.text, content="> - Item  \n>   ")
  inspect(quoted_bullet.caret, content="15")
}

///|
test "markdown editor hard break respects code and table contexts" {
  let code = markdown_editor_insert_hard_break("```\ncode\n```", 8, None).unwrap()
  inspect(code.text, content="```\ncode\n\n```")
  inspect(code.caret, content="9")

  let quoted_code = markdown_editor_insert_hard_break(
    "> ```\n> code\n> ```",
    12,
    None,
  ).unwrap()
  inspect(quoted_code.text, content="> ```\n> code\n> \n> ```")
  inspect(quoted_code.caret, content="15")

  inspect(
    markdown_editor_insert_hard_break("| A |\n| --- |\n| x |", 16, None) is None,
    content="true",
  )
}

///|
test "markdown editor enter exits empty heading markers" {
  let h1 = markdown_editor_transform_input("# ", 2, None, "\n").unwrap()
  inspect(h1.text, content="")
  inspect(h1.caret, content="0")
  let middle = markdown_editor_transform_input(
    "Intro\n## \nTail",
    9,
    None,
    "\n",
  ).unwrap()
  inspect(middle.text, content="Intro\n\nTail")
  inspect(middle.caret, content="6")
  let indented = markdown_editor_transform_input("  ### ", 6, None, "\n").unwrap()
  inspect(indented.text, content="  ")
  inspect(indented.caret, content="2")
  let quoted = markdown_editor_transform_input("> ## ", 5, None, "\n").unwrap()
  inspect(quoted.text, content="> ")
  inspect(quoted.caret, content="2")
  let nested_quoted = markdown_editor_transform_input("> > ### ", 8, None, "\n").unwrap()
  inspect(nested_quoted.text, content="> > ")
  inspect(nested_quoted.caret, content="4")
  inspect(
    markdown_editor_transform_input("# Title", 7, None, "\n") is None,
    content="true",
  )
  let quoted_title = markdown_editor_transform_input("> # Title", 9, None, "\n").unwrap()
  inspect(quoted_title.text, content="> # Title\n> ")
  inspect(quoted_title.caret, content="12")
  inspect(
    markdown_editor_transform_input("###", 3, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter falls back for plain paragraph" {
  inspect(
    markdown_editor_transform_input("paragraph", 9, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor typed space completes block markers" {
  let h1 = markdown_editor_transform_input("#", 1, None, " ").unwrap()
  inspect(h1.text, content="# ")
  inspect(h1.caret, content="2")
  let h2 = markdown_editor_transform_input("##", 2, None, " ").unwrap()
  inspect(h2.text, content="## ")
  inspect(h2.caret, content="3")
  let h3 = markdown_editor_transform_input("###", 3, None, " ").unwrap()
  inspect(h3.text, content="### ")
  inspect(h3.caret, content="4")
  let h6 = markdown_editor_transform_input("######", 6, None, " ").unwrap()
  inspect(h6.text, content="###### ")
  inspect(h6.caret, content="7")
  inspect(
    markdown_editor_transform_input("#######", 7, None, " ") is None,
    content="true",
  )
  let bullet = markdown_editor_transform_input("-", 1, None, " ").unwrap()
  inspect(bullet.text, content="- ")
  inspect(bullet.caret, content="2")
  let star = markdown_editor_transform_input("*", 1, None, " ").unwrap()
  inspect(star.text, content="- ")
  inspect(star.caret, content="2")
  let plus = markdown_editor_transform_input("+", 1, None, " ").unwrap()
  inspect(plus.text, content="- ")
  inspect(plus.caret, content="2")
  let ordered = markdown_editor_transform_input("1.", 2, None, " ").unwrap()
  inspect(ordered.text, content="1. ")
  inspect(ordered.caret, content="3")
  let paren_ordered = markdown_editor_transform_input("1)", 2, None, " ").unwrap()
  inspect(paren_ordered.text, content="1. ")
  inspect(paren_ordered.caret, content="3")
  let nested_paren_ordered = markdown_editor_transform_input(
    "  3)",
    5,
    None,
    " ",
  ).unwrap()
  inspect(nested_paren_ordered.text, content="  3. ")
  inspect(nested_paren_ordered.caret, content="5")
  let quote = markdown_editor_transform_input(">", 1, None, " ").unwrap()
  inspect(quote.text, content="> ")
  inspect(quote.caret, content="2")
  let nested_quote = markdown_editor_transform_input(">>", 2, None, " ").unwrap()
  inspect(nested_quote.text, content="> > ")
  inspect(nested_quote.caret, content="4")
  let deep_quote = markdown_editor_transform_input("  >>>", 5, None, " ").unwrap()
  inspect(deep_quote.text, content="  > > > ")
  inspect(deep_quote.caret, content="8")
  let quoted_heading = markdown_editor_transform_input("> ##", 4, None, " ").unwrap()
  inspect(quoted_heading.text, content="> ## ")
  inspect(quoted_heading.caret, content="5")
  let quoted_bullet = markdown_editor_transform_input("> *", 3, None, " ").unwrap()
  inspect(quoted_bullet.text, content="> - ")
  inspect(quoted_bullet.caret, content="4")
  let quoted_ordered = markdown_editor_transform_input("> 1)", 4, None, " ").unwrap()
  inspect(quoted_ordered.text, content="> 1. ")
  inspect(quoted_ordered.caret, content="5")
  let nested_quoted_task = markdown_editor_transform_input(
    "> > [X]",
    7,
    None,
    " ",
  ).unwrap()
  inspect(nested_quoted_task.text, content="> > - [x] ")
  inspect(nested_quoted_task.caret, content="10")
  let task = markdown_editor_transform_input("[ ]", 3, None, " ").unwrap()
  inspect(task.text, content="- [ ] ")
  inspect(task.caret, content="6")
  let checked = markdown_editor_transform_input("[x]", 3, None, " ").unwrap()
  inspect(checked.text, content="- [x] ")
  inspect(checked.caret, content="6")
  let natural_task = markdown_editor_transform_input("- [ ]", 5, None, " ").unwrap()
  inspect(natural_task.text, content="- [ ] ")
  inspect(natural_task.caret, content="6")
  let star_checked = markdown_editor_transform_input("* [X]", 5, None, " ").unwrap()
  inspect(star_checked.text, content="- [x] ")
  inspect(star_checked.caret, content="6")
  let plus_task = markdown_editor_transform_input("+ [ ]", 5, None, " ").unwrap()
  inspect(plus_task.text, content="- [ ] ")
  inspect(plus_task.caret, content="6")
  let nested_task = markdown_editor_transform_input("  + [x]", 7, None, " ").unwrap()
  inspect(nested_task.text, content="  - [x] ")
  inspect(nested_task.caret, content="8")
}

///|
test "markdown editor typed space only completes marker tokens" {
  inspect(
    markdown_editor_transform_input("text #", 6, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("text +", 6, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("text >>", 7, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("text - [ ]", 10, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "#",
      1,
      Some(@core.TextRange::new(start=0, end=1)),
      " ",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\n#\n```", 5, None, " ") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes bare autolinks" {
  let plain = markdown_editor_transform_input(
    "Visit https://moui.dev",
    22,
    None,
    "\n",
  ).unwrap()
  inspect(plain.text, content="Visit <https://moui.dev>\n")
  inspect(plain.caret, content="25")

  let wrapped = markdown_editor_transform_input(
    "See (https://moui.dev).",
    23,
    None,
    "\n",
  ).unwrap()
  inspect(wrapped.text, content="See (<https://moui.dev>).\n")
  inspect(wrapped.caret, content="26")

  let task = markdown_editor_transform_input(
    "- team@example.dev",
    18,
    None,
    "\n",
  ).unwrap()
  inspect(task.text, content="- <team@example.dev>\n- ")
  inspect(task.caret, content="23")

  let ordered = markdown_editor_transform_input(
    "3. https://moui.dev",
    19,
    None,
    "\n",
  ).unwrap()
  inspect(ordered.text, content="3. <https://moui.dev>\n4. ")
  inspect(ordered.caret, content="25")

  let quoted = markdown_editor_transform_input(
    "> https://moui.dev",
    18,
    None,
    "\n",
  ).unwrap()
  inspect(quoted.text, content="> <https://moui.dev>\n> ")
  inspect(quoted.caret, content="23")

  let code = markdown_editor_transform_input(
    "```\nhttps://moui.dev\n```",
    20,
    None,
    "\n",
  ).unwrap()
  inspect(code.text, content="```\nhttps://moui.dev\n\n```")
  inspect(code.caret, content="21")
}

///|
test "markdown editor enter completes horizontal rule lines" {
  let rule = markdown_editor_transform_input("---", 3, None, "\n").unwrap()
  inspect(rule.text, content="---\n")
  inspect(rule.caret, content="4")
  let star_rule = markdown_editor_transform_input("***", 3, None, "\n").unwrap()
  inspect(star_rule.text, content="***\n")
  inspect(star_rule.caret, content="4")
  inspect(
    markdown_editor_transform_input("--- title", 9, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor completes setext heading underlines" {
  let h1_enter = markdown_editor_transform_input("Title\n===", 9, None, "\n").unwrap()
  inspect(h1_enter.text, content="Title\n===\n")
  inspect(h1_enter.caret, content="10")
  let h1_space = markdown_editor_transform_input("Title\n===", 9, None, " ").unwrap()
  inspect(h1_space.text, content="Title\n===\n")
  inspect(h1_space.caret, content="10")
  let h2_space = markdown_editor_transform_input("Section\n----", 12, None, " ").unwrap()
  inspect(h2_space.text, content="Section\n----\n")
  inspect(h2_space.caret, content="13")
  inspect(
    markdown_editor_transform_input("# Title\n===", 11, None, "\n") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("\n===", 4, None, "\n") is None,
    content="true",
  )
  let rule = markdown_editor_transform_input("---", 3, None, " ").unwrap()
  inspect(rule.text, content="---\n")
  inspect(rule.caret, content="4")
}

///|
test "markdown editor typed space completes horizontal rule lines" {
  let dash = markdown_editor_transform_input("---", 3, None, " ").unwrap()
  inspect(dash.text, content="---\n")
  inspect(dash.caret, content="4")
  let star = markdown_editor_transform_input("***", 3, None, " ").unwrap()
  inspect(star.text, content="***\n")
  inspect(star.caret, content="4")
  let underscore = markdown_editor_transform_input("___", 3, None, " ").unwrap()
  inspect(underscore.text, content="___\n")
  inspect(underscore.caret, content="4")
  let nested = markdown_editor_transform_input("  ---", 5, None, " ").unwrap()
  inspect(nested.text, content="  ---\n")
  inspect(nested.caret, content="6")
  inspect(
    markdown_editor_transform_input("--- title", 9, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "---",
      3,
      Some(@core.TextRange::new(start=0, end=3)),
      " ",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("```\n---\n```", 7, None, " ") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes table header" {
  let table = markdown_editor_transform_input("| A | B |", 9, None, "\n").unwrap()
  inspect(table.text, content="| A | B |\n| --- | --- |\n|  |  |")
  inspect(table.caret, content="26")
  let compact = markdown_editor_transform_input("A | B", 5, None, "\n").unwrap()
  inspect(compact.text, content="A | B\n| --- | --- |\n|  |  |")
  inspect(compact.caret, content="22")
  inspect(
    markdown_editor_transform_input("| --- | --- |", 13, None, "\n") is None,
    content="true",
  )
}

///|
test "markdown editor enter completes fenced code opener" {
  let plain = markdown_editor_transform_input("```", 3, None, "\n").unwrap()
  inspect(plain.text, content="```\n\n```")
  inspect(plain.caret, content="4")
  let lang = markdown_editor_transform_input("```moonbit", 10, None, "\n").unwrap()
  inspect(lang.text, content="```moonbit\n\n```")
  inspect(lang.caret, content="11")
  let nested = markdown_editor_transform_input("  ```", 5, None, "\n").unwrap()
  inspect(nested.text, content="  ```\n  \n  ```")
  inspect(nested.caret, content="8")
  let long = markdown_editor_transform_input("````", 4, None, "\n").unwrap()
  inspect(long.text, content="````\n\n````")
  inspect(long.caret, content="5")
  let tilde = markdown_editor_transform_input("~~~", 3, None, "\n").unwrap()
  inspect(tilde.text, content="~~~\n\n~~~")
  inspect(tilde.caret, content="4")
  let tilde_lang = markdown_editor_transform_input("~~~moonbit", 10, None, "\n").unwrap()
  inspect(tilde_lang.text, content="~~~moonbit\n\n~~~")
  inspect(tilde_lang.caret, content="11")
  let nested_tilde = markdown_editor_transform_input("  ~~~~", 6, None, "\n").unwrap()
  inspect(nested_tilde.text, content="  ~~~~\n  \n  ~~~~")
  inspect(nested_tilde.caret, content="9")
  let tilde_info = markdown_editor_transform_input(
    "~~~bad~info",
    11,
    None,
    "\n",
  ).unwrap()
  inspect(tilde_info.text, content="~~~bad~info\n\n~~~")
  let quoted = markdown_editor_transform_input("> ```", 5, None, "\n").unwrap()
  inspect(quoted.text, content="> ```\n> \n> ```")
  inspect(quoted.caret, content="8")
  let nested_quoted = markdown_editor_transform_input(
    "> > ```moonbit",
    14,
    None,
    "\n",
  ).unwrap()
  inspect(nested_quoted.text, content="> > ```moonbit\n> > \n> > ```")
  inspect(nested_quoted.caret, content="19")
}

///|
test "markdown editor enter inside code block preserves code indentation" {
  let source = "```\n  let x = 1\n```"
  let result = markdown_editor_transform_input(source, 15, None, "\n").unwrap()
  inspect(result.text, content="```\n  let x = 1\n  \n```")
  inspect(result.caret, content="18")
  let quoted = markdown_editor_transform_input(
    "> ```\n>   let x = 1\n> ```",
    19,
    None,
    "\n",
  ).unwrap()
  inspect(quoted.text, content="> ```\n>   let x = 1\n>   \n> ```")
  inspect(quoted.caret, content="24")
}

///|
test "markdown editor enter exits empty fenced code blocks" {
  let empty = markdown_editor_transform_input("```\n\n```", 4, None, "\n").unwrap()
  inspect(empty.text, content="```\n\n```\n")
  inspect(empty.caret, content="9")

  let before_tail = markdown_editor_transform_input(
    "Intro\n```\n\n```\nTail",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(before_tail.text, content="Intro\n```\n\n```\n\nTail")
  inspect(before_tail.caret, content="15")

  let nested = markdown_editor_transform_input(
    "  ```\n  \n  ```",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(nested.text, content="  ```\n  \n  ```\n  ")
  inspect(nested.caret, content="17")

  let quoted = markdown_editor_transform_input(
    "> ```\n> \n> ```",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(quoted.text, content="> ```\n> \n> ```\n> ")
  inspect(quoted.caret, content="17")
}

///|
test "markdown editor code block content bypasses markdown marker transforms" {
  inspect(
    markdown_editor_transform_input("```\n# code\n```", 5, None, "\u{0008}")
    is None,
    content="true",
  )
  let entered = markdown_editor_transform_input(
    "```\n- item\n```",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(entered.text, content="```\n- item\n\n```")
  inspect(
    markdown_editor_transform_input("> ```\n> #\n> ```", 9, None, " ") is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("> ```\n> \n> ```", 8, None, "\"") is None,
    content="true",
  )
}

///|
test "markdown editor tab indents and shift tab outdents selected lines" {
  let indented = markdown_editor_transform_input(
    "Intro\n- one\n- two\nTail",
    17,
    Some(@core.TextRange::new(start=6, end=17)),
    "\t",
  ).unwrap()
  inspect(indented.text, content="Intro\n  - one\n  - two\nTail")
  inspect(indented.caret, content="21")
  guard indented.selection is Some(selection) else {
    fail("expected indented selection")
  }
  inspect(selection.start, content="6")
  inspect(selection.end, content="21")
  let outdented = markdown_editor_transform_input(
    indented.text,
    indented.caret,
    indented.selection,
    "\u{000b}",
  ).unwrap()
  inspect(outdented.text, content="Intro\n- one\n- two\nTail")
  inspect(outdented.caret, content="17")
}

///|
test "markdown editor tab moves through table cells" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let first = markdown_editor_transform_input(source, 2, None, "\t").unwrap()
  inspect(first.text, content=source)
  inspect(first.caret, content="6")
  let previous = markdown_editor_transform_input(source, 6, None, "\u{000b}").unwrap()
  inspect(previous.text, content=source)
  inspect(previous.caret, content="2")
  let exited_at_start = markdown_editor_transform_input(
    source,
    2,
    None,
    "\u{000b}",
  ).unwrap()
  inspect(exited_at_start.text, content="\n| A | B |\n| --- | --- |\n| 1 | 2 |")
  inspect(exited_at_start.caret, content="0")
  let exited_before_existing_blank = markdown_editor_transform_input(
    "Intro\n\n| A | B |\n| --- | --- |\n| 1 | 2 |",
    9,
    None,
    "\u{000b}",
  ).unwrap()
  inspect(
    exited_before_existing_blank.text,
    content="Intro\n\n| A | B |\n| --- | --- |\n| 1 | 2 |",
  )
  inspect(exited_before_existing_blank.caret, content="6")
  let appended = markdown_editor_transform_input(source, 30, None, "\t").unwrap()
  inspect(appended.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(appended.caret, content="36")
}

///|
test "markdown editor enter exits empty trailing table rows" {
  let with_data = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
    36,
    None,
    "\n",
  ).unwrap()
  inspect(with_data.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n")
  inspect(with_data.caret, content="34")

  let before_tail = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n|  |  |\nTail",
    26,
    None,
    "\n",
  ).unwrap()
  inspect(before_tail.text, content="| A | B |\n| --- | --- |\n|  |  |\n\nTail")
  inspect(before_tail.caret, content="32")

  let non_empty = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 |  |\nTail",
    26,
    None,
    "\n",
  ).unwrap()
  inspect(
    non_empty.text,
    content="| A | B |\n| --- | --- |\n| 1 |  |\n|  |  |\nTail",
  )
}

///|
test "markdown editor backspace removes empty trailing table rows" {
  let with_data = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
    36,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(with_data.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |")
  inspect(with_data.caret, content="27")

  let before_tail = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |\nTail",
    40,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(before_tail.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\nTail")
  inspect(before_tail.caret, content="31")

  inspect(
    markdown_editor_transform_input(
      "| A | B |\n| --- | --- |\n|  |  |",
      26,
      None,
      "\u{0008}",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "| A | B |\n| --- | --- |\n| 1 |  |\n|  | x |",
      38,
      None,
      "\u{0008}",
    )
    is None,
    content="true",
  )
}

///|
test "markdown editor delete removes empty trailing table rows" {
  let with_data = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
    36,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(with_data.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |")
  inspect(with_data.caret, content="27")

  let before_tail = markdown_editor_transform_input(
    "| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |\nTail",
    40,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(before_tail.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\nTail")
  inspect(before_tail.caret, content="31")

  inspect(
    markdown_editor_transform_input(
      "| A | B |\n| --- | --- |\n|  |  |",
      26,
      None,
      "\u{007f}",
    )
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input(
      "| A | B |\n| --- | --- |\n| 1 |  |\n|  | x |",
      38,
      None,
      "\u{007f}",
    )
    is None,
    content="true",
  )
}

///|
test "markdown editor multiline paste continues block context" {
  let bullet = markdown_editor_transform_input("- one", 5, None, " two\nthree").unwrap()
  inspect(bullet.text, content="- one two\n- three")
  inspect(bullet.caret, content="17")
  let task = markdown_editor_transform_input(
    "- [x] done",
    10,
    None,
    " today\ntomorrow",
  ).unwrap()
  inspect(task.text, content="- [x] done today\n- [ ] tomorrow")
  let quote = markdown_editor_transform_input("> note", 6, None, " now\nnext").unwrap()
  inspect(quote.text, content="> note now\n> next")
  let nested = markdown_editor_transform_input(
    "  3. one",
    8,
    None,
    " done\ntwo",
  ).unwrap()
  inspect(nested.text, content="  3. one done\n  4. two")
}

///|
test "markdown editor multiline paste preserves blank separators in block context" {
  let bullet = markdown_editor_transform_input(
    "- one",
    5,
    None,
    " two\n\nthree",
  ).unwrap()
  inspect(bullet.text, content="- one two\n\n- three")
  let task = markdown_editor_transform_input(
    "- [x] done",
    10,
    None,
    " today\n\ntomorrow",
  ).unwrap()
  inspect(task.text, content="- [x] done today\n\n- [ ] tomorrow")
  let ordered = markdown_editor_transform_input(
    "3. one",
    6,
    None,
    " done\n\ntwo",
  ).unwrap()
  inspect(ordered.text, content="3. one done\n\n4. two")
  let quoted = markdown_editor_transform_input(
    "> note",
    6,
    None,
    " now\n\nnext",
  ).unwrap()
  inspect(quoted.text, content="> note now\n> \n> next")
  let quoted_ordered = markdown_editor_transform_input(
    "> 3. one",
    8,
    None,
    " done\n\ntwo",
  ).unwrap()
  inspect(quoted_ordered.text, content="> 3. one done\n> \n> 4. two")
}

///|
test "markdown editor multiline paste preserves nested pasted indentation" {
  let bullet = markdown_editor_transform_input(
    "- one",
    5,
    None,
    " done\n  - child\nnext",
  ).unwrap()
  inspect(bullet.text, content="- one done\n  - child\n- next")
  let ordered = markdown_editor_transform_input(
    "3. one",
    6,
    None,
    " done\n  1. child\nnext",
  ).unwrap()
  inspect(ordered.text, content="3. one done\n  1. child\n4. next")
  let quoted_bullet = markdown_editor_transform_input(
    "> - one",
    7,
    None,
    " done\n  - child\nnext",
  ).unwrap()
  inspect(quoted_bullet.text, content="> - one done\n>   - child\n> - next")
}

///|
test "markdown editor multiline paste continues ordered numbers" {
  let result = markdown_editor_transform_input(
    "3. one",
    6,
    None,
    " done\ntwo\nthree",
  ).unwrap()
  inspect(result.text, content="3. one done\n4. two\n5. three")
  let quoted = markdown_editor_transform_input(
    "> 3. one",
    8,
    None,
    " done\ntwo\nthree",
  ).unwrap()
  inspect(quoted.text, content="> 3. one done\n> 4. two\n> 5. three")
  let nested_quoted = markdown_editor_transform_input(
    "> > 7. one",
    10,
    None,
    " done\ntwo\nthree",
  ).unwrap()
  inspect(
    nested_quoted.text,
    content="> > 7. one done\n> > 8. two\n> > 9. three",
  )
}

///|
test "markdown editor TSV paste creates markdown table blocks" {
  let pasted = markdown_editor_transform_input(
    "",
    0,
    None,
    "Name\tDone\nCore\tyes",
  ).unwrap()
  inspect(pasted.text, content="| Name | Done |\n| --- | --- |\n| Core | yes |")
  guard MarkdownEditorSnapshot::parse(pasted.text).rich_text.blocks[0].table
    is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="2")
  inspect(table.rows[0][0].text, content="Name")
  inspect(table.rows[1][1].text, content="yes")

  let inline = markdown_editor_transform_input(
    "Intro\nTail",
    5,
    None,
    "A | B\tC",
  ).unwrap()
  inspect(
    inline.text,
    content="Intro\n\n| A \\| B | C |\n| --- | --- |\n|  |  |\n\nTail",
  )
  inspect(inline.caret, content="43")
}

///|
test "markdown editor paste inside table cells preserves table shape" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let pasted = markdown_editor_transform_input(
    source,
    27,
    None,
    " alpha\nbeta | gamma",
  ).unwrap()
  inspect(
    pasted.text,
    content="| A | B |\n| --- | --- |\n| 1 alpha beta \\| gamma | 2 |",
  )
  inspect(pasted.caret, content="47")
  guard MarkdownEditorSnapshot::parse(pasted.text).rich_text.blocks[0].table
    is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows[0].length(), content="2")
  inspect(table.rows[1].length(), content="2")
  inspect(table.rows[1][0].text, content="1 alpha beta \\| gamma")

  let typed_pipe = markdown_editor_transform_input(source, 27, None, "|").unwrap()
  inspect(typed_pipe.text, content="| A | B |\n| --- | --- |\n| 1\\| | 2 |")
}

///|
test "markdown editor TSV paste fills table cells" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let filled = markdown_editor_transform_input(
    source,
    27,
    None,
    " alpha\tbeta\nnext\tlast",
  ).unwrap()
  inspect(
    filled.text,
    content="| A | B |\n| --- | --- |\n| 1 alpha | beta |\n| next | last |",
  )
  inspect(filled.caret, content="56")
  guard MarkdownEditorSnapshot::parse(filled.text).rich_text.blocks[0].table
    is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="3")
  inspect(table.rows[1][0].text, content="1 alpha")
  inspect(table.rows[1][1].text, content="beta")
  inspect(table.rows[2][0].text, content="next")
  inspect(table.rows[2][1].text, content="last")

  let expanded = markdown_editor_transform_input(source, 31, None, "x\ty").unwrap()
  inspect(
    expanded.text,
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2x | y |",
  )
}

///|
test "markdown editor Markdown table paste fills table cells" {
  let source = "| A | B |\n| --- | --- |\n| 1 | 2 |"
  let filled = markdown_editor_transform_input(
    source,
    27,
    None,
    "| X | Y |\n| :---: | ---: |\n| N | M |",
  ).unwrap()
  inspect(
    filled.text,
    content="| A | B |\n| :---: | ---: |\n| 1X | Y |\n| N | M |",
  )
  guard MarkdownEditorSnapshot::parse(filled.text).rich_text.blocks[0].table
    is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="3")
  guard table.rows[0][0].align is Some(@core.TextAlign::TextCenter) else {
    fail("expected pasted center alignment")
  }
  guard table.rows[0][1].align is Some(@core.TextAlign::TextEnd) else {
    fail("expected pasted end alignment")
  }
  inspect(table.rows[1][0].text, content="1X")
  inspect(table.rows[1][1].text, content="Y")
  inspect(table.rows[2][0].text, content="N")
  inspect(table.rows[2][1].text, content="M")
}

///|
test "markdown editor Markdown table paste creates table blocks" {
  let pasted = markdown_editor_transform_input(
    "Intro\nTail",
    5,
    None,
    "| A | B |\n| :--- | ---: |\n| 1 | 2 |",
  ).unwrap()
  inspect(
    pasted.text,
    content="Intro\n\n| A | B |\n| :--- | ---: |\n| 1 | 2 |\n\nTail",
  )
  inspect(pasted.caret, content="42")
  guard MarkdownEditorSnapshot::parse(pasted.text).rich_text.blocks[2].table
    is Some(table) else {
    fail("expected table preview")
  }
  inspect(table.rows.length(), content="2")
  inspect(table.rows[0][0].text, content="A")
  inspect(table.rows[1][1].text, content="2")
}

///|
test "markdown editor HTML block paste inserts or updates block content" {
  let inserted = markdown_editor_transform_input(
    "Intro\nTail",
    5,
    None,
    "<section>Note</section>",
  ).unwrap()
  inspect(inserted.text, content="Intro\n\n<section>Note</section>\n\nTail")
  inspect(inserted.caret, content="30")
  guard MarkdownEditorSnapshot::parse(inserted.text).blocks[2].block.kind
    is MarkdownBlockKind::HtmlBlock else {
    fail("expected inserted html block")
  }

  let replaced = markdown_editor_transform_input(
    "Intro\n<div>Old</div>\nTail",
    9,
    None,
    "<section>New</section>",
  ).unwrap()
  inspect(replaced.text, content="Intro\n<section>New</section>\nTail")
  inspect(replaced.caret, content="28")

  let selected = markdown_editor_transform_input(
    "Intro\nold\nTail",
    9,
    Some(@core.TextRange::new(start=6, end=9)),
    "<aside>Tip</aside>",
  ).unwrap()
  inspect(selected.text, content="Intro\n\n<aside>Tip</aside>\n\nTail")
  inspect(selected.caret, content="25")

  inspect(
    markdown_editor_transform_input("Intro ", 6, None, "<kbd>Esc</kbd>") is None,
    content="true",
  )
}

///|
test "markdown editor multiline paste inside code block preserves text with indent" {
  let result = markdown_editor_transform_input(
    "```\n  one\n```",
    9,
    None,
    " + two\nthree",
  ).unwrap()
  inspect(result.text, content="```\n  one + two\n  three\n```")
  let tsv = markdown_editor_transform_input(
    "```\n  one\n```",
    9,
    None,
    " + two\tthree\nfour\tfive",
  ).unwrap()
  inspect(tsv.text, content="```\n  one + two\tthree\n  four\tfive\n```")
  let table = markdown_editor_transform_input(
    "```\n  one\n```",
    9,
    None,
    " +\n| A | B |\n| --- | --- |",
  ).unwrap()
  inspect(table.text, content="```\n  one +\n  | A | B |\n  | --- | --- |\n```")
  let quoted = markdown_editor_transform_input(
    "> ```\n>   one\n> ```",
    13,
    None,
    " + two\nthree",
  ).unwrap()
  inspect(quoted.text, content="> ```\n>   one + two\n>   three\n> ```")
  let quoted_tsv = markdown_editor_transform_input(
    "> ```\n>   one\n> ```",
    13,
    None,
    " + two\tthree\nfour\tfive",
  ).unwrap()
  inspect(
    quoted_tsv.text,
    content="> ```\n>   one + two\tthree\n>   four\tfive\n> ```",
  )
  let quoted_table = markdown_editor_transform_input(
    "> ```\n>   one\n> ```",
    13,
    None,
    " +\n| A | B |\n| --- | --- |",
  ).unwrap()
  inspect(
    quoted_table.text,
    content="> ```\n>   one +\n>   | A | B |\n>   | --- | --- |\n> ```",
  )
}

///|
test "markdown editor backspace removes block marker at content start" {
  let heading = markdown_editor_transform_input("# Title", 2, None, "\u{0008}").unwrap()
  inspect(heading.text, content="Title")
  inspect(heading.caret, content="0")
  let task = markdown_editor_transform_input(
    "Intro\n- [x] done",
    12,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(task.text, content="Intro\ndone")
  inspect(task.caret, content="6")
  let quote = markdown_editor_transform_input("> quote", 2, None, "\u{0008}").unwrap()
  inspect(quote.text, content="quote")
  inspect(quote.caret, content="0")
  let quoted_bullet = markdown_editor_transform_input(
    "> - item",
    4,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_bullet.text, content="> item")
  inspect(quoted_bullet.caret, content="2")
  let quoted_task = markdown_editor_transform_input(
    "> - [x] done",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_task.text, content="> done")
  inspect(quoted_task.caret, content="2")
  let quoted_heading = markdown_editor_transform_input(
    "> ## Title",
    5,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_heading.text, content="> Title")
  inspect(quoted_heading.caret, content="2")
  let nested_quoted_ordered = markdown_editor_transform_input(
    "> > 7. child",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(nested_quoted_ordered.text, content="> > child")
  inspect(nested_quoted_ordered.caret, content="4")
  let nested = markdown_editor_transform_input("  - child", 4, None, "\u{0008}").unwrap()
  inspect(nested.text, content="- child")
  inspect(nested.caret, content="2")
  inspect(
    markdown_editor_transform_input("# Title", 3, None, "\u{0008}") is None,
    content="true",
  )
}

///|
test "markdown editor delete removes quoted inner block marker before content" {
  let quoted_bullet = markdown_editor_transform_input(
    "> - item",
    2,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_bullet.text, content="> item")
  inspect(quoted_bullet.caret, content="2")

  let quoted_task = markdown_editor_transform_input(
    "> - [x] done",
    2,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_task.text, content="> done")
  inspect(quoted_task.caret, content="2")

  let quoted_heading = markdown_editor_transform_input(
    "> ## Title",
    2,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_heading.text, content="> Title")
  inspect(quoted_heading.caret, content="2")

  let nested_quoted_ordered = markdown_editor_transform_input(
    "> > 7. child",
    4,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(nested_quoted_ordered.text, content="> > child")
  inspect(nested_quoted_ordered.caret, content="4")
}

///|
test "markdown editor delete removes block marker at marker start" {
  let heading = markdown_editor_transform_input("# Title", 0, None, "\u{007f}").unwrap()
  inspect(heading.text, content="Title")
  inspect(heading.caret, content="0")
  let task = markdown_editor_transform_input(
    "Intro\n- [x] done",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(task.text, content="Intro\ndone")
  inspect(task.caret, content="6")
  let quote = markdown_editor_transform_input("> quote", 0, None, "\u{007f}").unwrap()
  inspect(quote.text, content="quote")
  inspect(quote.caret, content="0")
  let ordered = markdown_editor_transform_input("7. item", 0, None, "\u{007f}").unwrap()
  inspect(ordered.text, content="item")
  inspect(ordered.caret, content="0")
  let nested = markdown_editor_transform_input("  - child", 2, None, "\u{007f}").unwrap()
  inspect(nested.text, content="- child")
  inspect(nested.caret, content="0")
  inspect(
    markdown_editor_transform_input("# Title", 1, None, "\u{007f}") is None,
    content="true",
  )
}

///|
test "markdown editor backspace removes inline marker pair at content start" {
  let bold = markdown_editor_transform_input(
    "Text **bold** tail",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bold.text, content="Text bold tail")
  inspect(bold.caret, content="5")
  let code = markdown_editor_transform_input(
    "Use `code` now",
    5,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(code.text, content="Use code now")
  inspect(code.caret, content="4")
  let strike = markdown_editor_transform_input(
    "~~old~~ text",
    2,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(strike.text, content="old text")
  inspect(strike.caret, content="0")
  let italic = markdown_editor_transform_input(
    "_old_ text",
    1,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(italic.text, content="old text")
  inspect(italic.caret, content="0")
  let underscore_bold = markdown_editor_transform_input(
    "__bold__ text",
    2,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(underscore_bold.text, content="bold text")
  inspect(underscore_bold.caret, content="0")
  let link = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(link.text, content="Visit MoUI today")
  inspect(link.caret, content="6")
  let image = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(image.text, content="Insert logo here")
  inspect(image.caret, content="7")
  inspect(
    markdown_editor_transform_input("Text **bold** tail", 8, None, "\u{0008}")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("snake_case_more", 6, None, "\u{0008}")
    is None,
    content="true",
  )
}

///|
test "markdown editor delete removes inline marker pair at content end" {
  let bold = markdown_editor_transform_input(
    "Text **bold** tail",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bold.text, content="Text bold tail")
  inspect(bold.caret, content="5")
  let code = markdown_editor_transform_input(
    "Use `code` now",
    9,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(code.text, content="Use code now")
  inspect(code.caret, content="4")
  let strike = markdown_editor_transform_input(
    "~~old~~ text",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(strike.text, content="old text")
  inspect(strike.caret, content="0")
  let italic = markdown_editor_transform_input(
    "_old_ text",
    4,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(italic.text, content="old text")
  inspect(italic.caret, content="0")
  let underscore_bold = markdown_editor_transform_input(
    "__bold__ text",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(underscore_bold.text, content="bold text")
  inspect(underscore_bold.caret, content="0")
  let link = markdown_editor_transform_input(
    "Visit [MoUI](https://moui.dev) today",
    11,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(link.text, content="Visit MoUI today")
  inspect(link.caret, content="6")
  let image = markdown_editor_transform_input(
    "Insert ![logo](image.png) here",
    13,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(image.text, content="Insert logo here")
  inspect(image.caret, content="7")
  inspect(
    markdown_editor_transform_input("Text **bold** tail", 10, None, "\u{007f}")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("snake_case_more", 5, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor removes inline marker pair at outside edges" {
  let bold_backspace = markdown_editor_transform_input(
    "Text **bold** tail",
    13,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bold_backspace.text, content="Text bold tail")
  inspect(bold_backspace.caret, content="5")

  let bold_delete = markdown_editor_transform_input(
    "Text **bold** tail",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bold_delete.text, content="Text bold tail")
  inspect(bold_delete.caret, content="5")

  let code_backspace = markdown_editor_transform_input(
    "Use `code` now",
    10,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(code_backspace.text, content="Use code now")
  inspect(code_backspace.caret, content="4")

  let strike_delete = markdown_editor_transform_input(
    "Keep ~~old~~ text",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(strike_delete.text, content="Keep old text")
  inspect(strike_delete.caret, content="5")

  inspect(
    markdown_editor_transform_input("snake_case_more", 11, None, "\u{0008}")
    is None,
    content="true",
  )
  inspect(
    markdown_editor_transform_input("snake_case_more", 5, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor backspace at block start merges with previous block" {
  let paragraph = markdown_editor_transform_input(
    "First\nSecond",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(paragraph.text, content="First Second")
  inspect(paragraph.caret, content="5")
  let bullets = markdown_editor_transform_input(
    "- first\n- second",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bullets.text, content="- first second")
  inspect(bullets.caret, content="7")
  let tasks = markdown_editor_transform_input(
    "- [x] done\n- [ ] next",
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(tasks.text, content="- [x] done next")
  inspect(tasks.caret, content="10")
  let quotes = markdown_editor_transform_input(
    "> first\n> second",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quotes.text, content="> first second")
  let nested_quotes = markdown_editor_transform_input(
    "> > first\n> > second",
    10,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(nested_quotes.text, content="> > first second")
  inspect(nested_quotes.caret, content="9")
  let quoted_bullets = markdown_editor_transform_input(
    "> > - one\n> > - two",
    10,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_bullets.text, content="> > - one two")
  inspect(quoted_bullets.caret, content="9")
  let quoted_ordered = markdown_editor_transform_input(
    "> > 7. one\n> > 9. two",
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_ordered.text, content="> > 7. one two")
  inspect(quoted_ordered.caret, content="10")
  let mixed = markdown_editor_transform_input(
    "# Title\n- item",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(mixed.text, content="Title item")
  inspect(mixed.caret, content="5")
  inspect(
    markdown_editor_transform_input("First\nSecond", 7, None, "\u{0008}")
    is None,
    content="true",
  )
  let blank = markdown_editor_transform_input(
    "First\n\nSecond",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(blank.text, content="First\nSecond")
  inspect(blank.caret, content="5")
  let heading_blank = markdown_editor_transform_input(
    "# Title\n\nBody",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(heading_blank.text, content="# Title\nBody")
  inspect(heading_blank.caret, content="7")
  let bullet_blank = markdown_editor_transform_input(
    "- item\n\nBody",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(bullet_blank.text, content="- item\nBody")
  inspect(bullet_blank.caret, content="6")
  let spaced_blank = markdown_editor_transform_input(
    "# Title\n   \nBody",
    8,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(spaced_blank.text, content="# Title\nBody")
  inspect(spaced_blank.caret, content="7")
}

///|
test "markdown editor delete at block end merges with next block" {
  let paragraph = markdown_editor_transform_input(
    "First\nSecond",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(paragraph.text, content="First Second")
  inspect(paragraph.caret, content="5")
  let bullets = markdown_editor_transform_input(
    "- first\n- second",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bullets.text, content="- first second")
  inspect(bullets.caret, content="7")
  let ordered = markdown_editor_transform_input(
    "1. first\n2. second",
    8,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(ordered.text, content="1. first second")
  inspect(ordered.caret, content="8")
  let nested_quotes = markdown_editor_transform_input(
    "> > first\n> > second",
    9,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(nested_quotes.text, content="> > first second")
  inspect(nested_quotes.caret, content="9")
  let quoted_bullets = markdown_editor_transform_input(
    "> > - one\n> > - two",
    9,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_bullets.text, content="> > - one two")
  inspect(quoted_bullets.caret, content="9")
  let quoted_ordered = markdown_editor_transform_input(
    "> > 7. one\n> > 9. two",
    10,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_ordered.text, content="> > 7. one two")
  inspect(quoted_ordered.caret, content="10")
  let mixed = markdown_editor_transform_input(
    "# Title\n- item",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(mixed.text, content="Title item")
  inspect(mixed.caret, content="5")
  let blank = markdown_editor_transform_input(
    "First\n\nSecond",
    5,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(blank.text, content="First\nSecond")
  inspect(blank.caret, content="5")
  let heading_blank = markdown_editor_transform_input(
    "# Title\n\nBody",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(heading_blank.text, content="# Title\nBody")
  inspect(heading_blank.caret, content="7")
  let bullet_blank = markdown_editor_transform_input(
    "- item\n\nBody",
    6,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(bullet_blank.text, content="- item\nBody")
  inspect(bullet_blank.caret, content="6")
  let spaced_blank = markdown_editor_transform_input(
    "# Title\n   \nBody",
    7,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(spaced_blank.text, content="# Title\nBody")
  inspect(spaced_blank.caret, content="7")
  inspect(
    markdown_editor_transform_input("First\nSecond", 6, None, "\u{007f}")
    is None,
    content="true",
  )
}

///|
test "markdown editor renumbers contiguous ordered lists after transforms" {
  let backspace = markdown_editor_transform_input(
    "1. first\n3. second\n4. third",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace.text, content="1. first second\n2. third")
  inspect(backspace.caret, content="8")
  let delete = markdown_editor_transform_input(
    "8. first\n10. second\n11. third",
    8,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete.text, content="8. first second\n9. third")
  inspect(delete.caret, content="8")
  let enter = markdown_editor_transform_input(
    "1. first\n7. second",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(enter.text, content="1. first\n2. \n3. second")
  inspect(enter.caret, content="12")
  let quoted_backspace = markdown_editor_transform_input(
    "> 7. one\n> 9. two\n> 10. three",
    9,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(quoted_backspace.text, content="> 7. one two\n> 8. three")
  inspect(quoted_backspace.caret, content="8")
  let nested_quoted_backspace = markdown_editor_transform_input(
    "> > 7. one\n> > 9. two\n> > 10. three",
    11,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(nested_quoted_backspace.text, content="> > 7. one two\n> > 8. three")
  inspect(nested_quoted_backspace.caret, content="10")
  let quoted_delete = markdown_editor_transform_input(
    "> 7. one\n> 9. two\n> 10. three",
    8,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(quoted_delete.text, content="> 7. one two\n> 8. three")
  inspect(quoted_delete.caret, content="8")
}

///|
test "markdown editor ordered renumbering resumes parent after nested list" {
  let enter = markdown_editor_transform_input(
    "1. first\n  1. nested\n4. second",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(enter.text, content="1. first\n2. \n  1. nested\n3. second")
  inspect(enter.caret, content="12")

  let nested_start = markdown_editor_transform_input(
    "1. first\n  7. nested\n  9. more\n4. second",
    8,
    None,
    "\n",
  ).unwrap()
  inspect(
    nested_start.text,
    content="1. first\n2. \n  7. nested\n  8. more\n3. second",
  )

  let quoted_parent = markdown_editor_transform_input(
    "> 1. first\n> > 7. nested\n> 4. second",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(
    quoted_parent.text,
    content="> 1. first\n> 2. \n> > 7. nested\n> 3. second",
  )
  inspect(quoted_parent.caret, content="16")

  let quoted_blank = markdown_editor_transform_input(
    "> 1. first\n> \n> 4. second",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(quoted_blank.text, content="> 1. first\n> 2. \n> \n> 3. second")

  let quoted_paragraph = markdown_editor_transform_input(
    "> 1. first\n> note\n> 4. second",
    10,
    None,
    "\n",
  ).unwrap()
  inspect(
    quoted_paragraph.text,
    content="> 1. first\n> 2. \n> note\n> 4. second",
  )
}

///|
