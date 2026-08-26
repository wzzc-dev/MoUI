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
    "Visit https://wzzc-dev.github.io/MoUI",
    37,
    None,
    "\n",
  ).unwrap()
  inspect(plain.text, content="Visit <https://wzzc-dev.github.io/MoUI>\n")
  inspect(plain.caret, content="40")

  let wrapped = markdown_editor_transform_input(
    "See (https://wzzc-dev.github.io/MoUI).",
    38,
    None,
    "\n",
  ).unwrap()
  inspect(wrapped.text, content="See (<https://wzzc-dev.github.io/MoUI>).\n")
  inspect(wrapped.caret, content="41")

  let task = markdown_editor_transform_input(
    "- team@example.dev",
    18,
    None,
    "\n",
  ).unwrap()
  inspect(task.text, content="- <team@example.dev>\n- ")
  inspect(task.caret, content="23")

  let ordered = markdown_editor_transform_input(
    "3. https://wzzc-dev.github.io/MoUI",
    34,
    None,
    "\n",
  ).unwrap()
  inspect(ordered.text, content="3. <https://wzzc-dev.github.io/MoUI>\n4. ")
  inspect(ordered.caret, content="40")

  let quoted = markdown_editor_transform_input(
    "> https://wzzc-dev.github.io/MoUI",
    33,
    None,
    "\n",
  ).unwrap()
  inspect(quoted.text, content="> <https://wzzc-dev.github.io/MoUI>\n> ")
  inspect(quoted.caret, content="38")

  let code = markdown_editor_transform_input(
    "```\nhttps://wzzc-dev.github.io/MoUI\n```",
    35,
    None,
    "\n",
  ).unwrap()
  inspect(code.text, content="```\nhttps://wzzc-dev.github.io/MoUI\n\n```")
  inspect(code.caret, content="36")
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
