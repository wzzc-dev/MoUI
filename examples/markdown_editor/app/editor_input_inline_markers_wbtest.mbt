///|
test "markdown editor pairs inline markdown markers while typing" {
  let bold = markdown_editor_transform_input("Say ", 4, None, "**").unwrap()
  inspect(bold.text, content="Say ****")
  inspect(bold.caret, content="6")
  let unicode_bold = markdown_editor_transform_input(
    "前🤣后",
    2,
    None,
    "**",
  ).unwrap()
  inspect(unicode_bold.text, content="前🤣****后")
  inspect(unicode_bold.caret, content="4")
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
test "markdown editor removes empty inline marker pairs at caret edges" {
  let backspace_middle = markdown_editor_transform_input(
    "Say ****",
    6,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace_middle.text, content="Say ")
  inspect(backspace_middle.caret, content="4")
  let unicode_backspace_middle = markdown_editor_transform_input(
    "前🤣****后",
    4,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(unicode_backspace_middle.text, content="前🤣后")
  inspect(unicode_backspace_middle.caret, content="2")
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
  let unicode_delete_before = markdown_editor_transform_input(
    "前🤣****后",
    2,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(unicode_delete_before.text, content="前🤣后")
  inspect(unicode_delete_before.caret, content="2")
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
test "markdown editor removes inline marker pairs around unicode content" {
  let backspace = markdown_editor_transform_input(
    "前 **🤣** 后",
    7,
    None,
    "\u{0008}",
  ).unwrap()
  inspect(backspace.text, content="前 🤣 后")
  inspect(backspace.caret, content="2")
  let delete = markdown_editor_transform_input(
    "前 **🤣** 后",
    2,
    None,
    "\u{007f}",
  ).unwrap()
  inspect(delete.text, content="前 🤣 后")
  inspect(delete.caret, content="2")
}
