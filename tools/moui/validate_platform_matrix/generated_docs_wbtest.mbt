///|
test "generated platform table replacement is stable" {
  let source = "before\n" +
    generated_begin +
    "\nold\n" +
    generated_end +
    "\nafter\n"
  let expected = "before\n" +
    generated_begin +
    "\nnew\n" +
    generated_end +
    "\nafter\n"
  assert_eq(replace_generated_table(source, "new"), Some(expected))
  assert_eq(replace_generated_table("no markers", "new"), None)
}
