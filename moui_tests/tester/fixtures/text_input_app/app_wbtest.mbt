///|
test "text input fixture renders focusable text field" {
  let runtime = runtime()
  ignore(runtime.draw_commands())
  assert_true(runtime.draw_commands().length() > 0)
}
