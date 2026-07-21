///|
test "required window-hosted paths are non-empty" {
  assert_true(required_paths().length() >= 4)
  assert_true(forbidden_paths().contains("moui_shell"))
}
