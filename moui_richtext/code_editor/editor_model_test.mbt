///|
test "code editor finds and replaces ranges" {
  let source = "let count = 1\nlet next = count + 1"
  let matches = code_find_matches(source, "count")
  inspect(matches.length(), content="2")
  inspect(
    code_replace_all(source, "count", "total"),
    content="let total = 1\nlet next = total + 1",
  )
}

///|
test "code editor inserts indentation at multiple cursors" {
  let source = "fn main {\n  let value = 1\n}"
  let (updated, cursors) = code_insert_text(
    source,
    [CodeCursor::new(position=9)],
    "\n",
  )
  inspect(updated, content="fn main {\n  \n  let value = 1\n}")
  inspect(cursors[0].position, content="12")
}

///|
test "code editor reports caret line and column" {
  let position = code_editor_caret_position("one\ntwo", 5)
  inspect(position.line, content="2")
  inspect(position.column, content="2")
}

///|
test "code editor matches nested brackets" {
  let source = "fn main { let value = (1 + 2) }"
  let bracket = code_bracket_match(source, 9)
  let found = match bracket {
    Some(_) => true
    None => false
  }
  inspect(found, content="true")
}

///|
test "code editor registry provides MoonBit completions" {
  let items = CodeLanguageRegistry::new().completions("@views.", 7)
  inspect(items.is_empty(), content="false")
}
