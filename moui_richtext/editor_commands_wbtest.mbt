///|
test "parse_markdown_inlines recovers ==highlight== spans from plain text" {
  let spans = parse_markdown_inlines("a ==mark== b")
  inspect(spans.length(), content="3")
  debug_inspect(spans[0].kind, content="Plain")
  inspect(spans[0].text, content="a ")
  debug_inspect(spans[1].kind, content="Highlight")
  inspect(spans[1].text, content="mark")
  debug_inspect(spans[2].kind, content="Plain")
  inspect(spans[2].text, content=" b")
  // Round-trip: the canonical serialization restores the == markers.
  inspect(markdown_editor_inline_source(spans), content="a ==mark== b")
  // An unmatched == pair stays plain text.
  let unmatched = parse_markdown_inlines("a == b")
  inspect(unmatched.length(), content="1")
  debug_inspect(unmatched[0].kind, content="Plain")
  inspect(unmatched[0].text, content="a == b")
  // Highlight markers inside code spans do not split the code content.
  let code = parse_markdown_inlines("`a ==mark== b`")
  inspect(code.length(), content="1")
  debug_inspect(code[0].kind, content="Code")
  inspect(code[0].text, content="a ==mark== b")
  // Highlight spans serialize back through the block source mapping.
  let source = markdown_editor_inline_source(
    parse_markdown_inlines("see ==this== now"),
  )
  inspect(source, content="see ==this== now")
}
