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
  let middle = markdown_editor_transform_input("Intro\n- \nTail", 8, None, "\n").unwrap()
  inspect(middle.text, content="Intro\n\nTail")
  inspect(middle.caret, content="6")
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
}

///|
test "markdown editor enter inside code block preserves code indentation" {
  let source = "```\n  let x = 1\n```"
  let result = markdown_editor_transform_input(source, 15, None, "\n").unwrap()
  inspect(result.text, content="```\n  let x = 1\n  \n```")
  inspect(result.caret, content="18")
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
  let appended = markdown_editor_transform_input(source, 30, None, "\t").unwrap()
  inspect(appended.text, content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |")
  inspect(appended.caret, content="36")
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
test "markdown editor multiline paste continues ordered numbers" {
  let result = markdown_editor_transform_input(
    "3. one",
    6,
    None,
    " done\ntwo\nthree",
  ).unwrap()
  inspect(result.text, content="3. one done\n4. two\n5. three")
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
  let nested = markdown_editor_transform_input("  - child", 4, None, "\u{0008}").unwrap()
  inspect(nested.text, content="- child")
  inspect(nested.caret, content="2")
  inspect(
    markdown_editor_transform_input("# Title", 3, None, "\u{0008}") is None,
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
}

///|
