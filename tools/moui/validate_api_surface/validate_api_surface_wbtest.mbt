///|
test "line count ignores trailing generated blank lines" {
  inspect(line_count(""), content="0")
  inspect(line_count("one"), content="1")
  inspect(line_count("one\n"), content="1")
  inspect(line_count("one\n\n"), content="1")
  inspect(line_count("one\ntwo"), content="2")
  inspect(line_count("one\ntwo\n\n"), content="2")
}
