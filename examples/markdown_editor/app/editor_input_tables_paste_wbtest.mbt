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
