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
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI) today",
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
    "Visit [MoUI](https://wzzc-dev.github.io/MoUI) today",
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
