///|
test "source line count ignores a final newline" {
  inspect(source_line_count(""), content="0")
  inspect(source_line_count("one"), content="1")
  inspect(source_line_count("one\n"), content="1")
  inspect(source_line_count("one\ntwo\n"), content="2")
}

///|
test "source extension policy is explicit" {
  let extensions = [".mbt", ".kt", ".swift", ".ets", ".mm", ".cpp", ".mjs"]
  assert_true(has_source_extension("app/main.mbt", extensions))
  assert_true(has_source_extension("shell/App.swift", extensions))
  assert_false(has_source_extension("assets/data.json", extensions))
}

///|
test "repository policy paths cannot escape the checkout" {
  assert_true(repository_relative_path("moui/runtime/app.mbt"))
  assert_false(repository_relative_path("../outside.mbt"))
  assert_false(repository_relative_path("moui/../outside.mbt"))
  assert_false(repository_relative_path("C:\\outside.mbt"))
  assert_false(repository_relative_path("/outside.mbt"))
}

///|
test "logic thresholds review at 1000 and reject only above 1200" {
  inspect(unregistered_logic_classification(999, 1000, 1200), content="ok")
  inspect(unregistered_logic_classification(1000, 1000, 1200), content="review")
  inspect(unregistered_logic_classification(1200, 1000, 1200), content="review")
  inspect(
    unregistered_logic_classification(1201, 1000, 1200),
    content="hard-limit",
  )
}
