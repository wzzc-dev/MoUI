///|
test "markdown_input_transform pairs '(' into '()' and places caret inside" {
  let transform = markdown_input_transform("", 0, None, "(")
  guard transform is Some(t) else { fail("expected a transform for '('") }
  inspect(t.text, content="()")
  inspect(t.caret, content="1")
  assert_true(t.selection is None)
}

///|
test "markdown_input_transform pairs '[' into '[]' and places caret inside" {
  let transform = markdown_input_transform("", 0, None, "[")
  guard transform is Some(t) else { fail("expected a transform for '['") }
  inspect(t.text, content="[]")
  inspect(t.caret, content="1")
}

///|
test "markdown_input_transform pairs delimiters at unicode scalar caret" {
  let transform = markdown_input_transform("前🤣后", 2, None, "(")
  guard transform is Some(result) else {
    fail("expected unicode delimiter pair transform")
  }
  inspect(result.text, content="前🤣()后")
  inspect(result.caret, content="3")
}

///|
test "markdown_input_transform pairs '{' into '{}'" {
  let transform = markdown_input_transform("", 0, None, "{")
  guard transform is Some(t) else { fail("expected a transform for '{'") }
  inspect(t.text, content="{}")
  inspect(t.caret, content="1")
}

///|
test "markdown_input_transform wraps selection with '(' ... ')'" {
  // source = "text", selection [0, 4), caret 4, input "("
  let selection = @core.TextRange::new(start=0, end=4)
  let transform = markdown_input_transform("text", 4, Some(selection), "(")
  guard transform is Some(t) else { fail("expected a wrap transform") }
  inspect(t.text, content="(text)")
  inspect(t.caret, content="5")
  guard t.selection is Some(range) else {
    fail("expected selection after wrap")
  }
  inspect(range.start, content="1")
  inspect(range.end, content="5")
}

///|
test "markdown_input_transform wraps unicode selection with delimiter pair" {
  let selection = @core.TextRange::new(start=1, end=2)
  let transform = markdown_input_transform(
    "前🤣后",
    2,
    Some(selection),
    "[",
  )
  guard transform is Some(result) else {
    fail("expected unicode selection wrap transform")
  }
  inspect(result.text, content="前[🤣]后")
  inspect(result.caret, content="3")
  guard result.selection is Some(range) else {
    fail("expected selection after unicode wrap")
  }
  inspect(range.start, content="2")
  inspect(range.end, content="3")
}

///|
test "markdown_input_transform wraps selection with '*' inline marker" {
  let selection = @core.TextRange::new(start=0, end=4)
  let transform = markdown_input_transform("text", 4, Some(selection), "*")
  guard transform is Some(t) else { fail("expected a wrap transform for '*'") }
  inspect(t.text, content="*text*")
  guard t.selection is Some(range) else {
    fail("expected selection after wrap")
  }
  inspect(range.start, content="1")
  inspect(range.end, content="5")
}

///|
test "markdown_input_transform wraps selection with '**' inline marker" {
  let selection = @core.TextRange::new(start=0, end=4)
  let transform = markdown_input_transform("text", 4, Some(selection), "**")
  guard transform is Some(t) else { fail("expected a wrap transform for '**'") }
  inspect(t.text, content="**text**")
  guard t.selection is Some(range) else {
    fail("expected selection after wrap")
  }
  inspect(range.start, content="2")
  inspect(range.end, content="6")
}

///|
test "markdown_input_transform pairs inline marker at unicode scalar caret" {
  let transform = markdown_input_transform("前🤣后", 2, None, "**")
  guard transform is Some(result) else {
    fail("expected unicode inline marker pair transform")
  }
  inspect(result.text, content="前🤣****后")
  inspect(result.caret, content="4")
}

///|
test "markdown_input_transform removes inline marker pair around unicode text" {
  let backspace = markdown_input_transform(
    "前 **🤣** 后",
    7,
    None,
    "\u{0008}",
  )
  guard backspace is Some(backspace_result) else {
    fail("expected unicode inline marker backspace transform")
  }
  inspect(backspace_result.text, content="前 🤣 后")
  inspect(backspace_result.caret, content="2")
  let delete = markdown_input_transform("前 **🤣** 后", 2, None, "\u{007f}")
  guard delete is Some(delete_result) else {
    fail("expected unicode inline marker delete transform")
  }
  inspect(delete_result.text, content="前 🤣 后")
  inspect(delete_result.caret, content="2")
}

///|
test "markdown_input_transform returns None for plain character in middle of text" {
  // Typing a plain letter does not trigger any transform.
  let transform = markdown_input_transform("abc", 1, None, "x")
  assert_true(transform is None)
}

///|
test "markdown_input_transform returns None for pair delimiter inside code block" {
  // source = "```\ncode\n```", caret 6 is inside the code block content.
  let transform = markdown_input_transform("```\ncode\n```", 6, None, "(")
  assert_true(transform is None)
}

///|
test "markdown_input_transform pairs backtick in empty source" {
  let transform = markdown_input_transform("", 0, None, "`")
  guard transform is Some(t) else { fail("expected a transform for '`'") }
  inspect(t.text, content="``")
  inspect(t.caret, content="1")
}

///|
test "markdown_input_transform skips closing delimiter when next char matches" {
  // source = "()" caret at 1 (between '(' and ')'), input ")"
  // The closing delimiter should be skipped (caret moves past the existing ')').
  let transform = markdown_input_transform("()", 1, None, ")")
  guard transform is Some(t) else { fail("expected skip-closing transform") }
  inspect(t.text, content="()")
  inspect(t.caret, content="2")
}

///|
test "markdown_input_transform indents selected lines on tab input" {
  // source = "line", selection [0, 4), input "\t"
  let selection = @core.TextRange::new(start=0, end=4)
  let transform = markdown_input_transform("line", 4, Some(selection), "\t")
  guard transform is Some(t) else { fail("expected a tab indent transform") }
  // Tab indent adds two leading spaces to the selected line.
  assert_true(t.text.contains("  line"))
  guard t.selection is Some(range) else {
    fail("expected selection after indent")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="6")
}

///|
test "markdown_input_transform returns None for unhandled single char in paragraph" {
  // A plain letter in the middle of a paragraph with no selection returns None.
  let transform = markdown_input_transform("hello world", 5, None, " ")
  // Space triggers autocomplete attempts; in this context it should return None
  // because "hello" is not a block marker prefix.
  assert_true(transform is None)
}

///|
test "markdown_editor_indent_lines produces a transform with two-space prefix" {
  let transform = markdown_editor_indent_lines("line", 4, None)
  inspect(transform.caret, content="6")
  inspect(transform.text, content="  line")
}

///|
test "markdown_editor_outdent_lines returns None when no indent to remove" {
  // "line" has no leading tab, so outdent should return None.
  let transform = markdown_editor_outdent_lines("line", 4, None)
  assert_true(transform is None)
}

///|
test "markdown_editor_insert_hard_break returns a transform when applicable" {
  // At the end of a paragraph, inserting a hard break should produce a newline.
  let transform = markdown_editor_insert_hard_break("line", 4, None)
  guard transform is Some(t) else {
    fail("expected a hard break transform at end of line")
  }
  assert_true(t.text.contains("\n"))
}
