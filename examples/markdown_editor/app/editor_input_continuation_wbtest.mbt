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
