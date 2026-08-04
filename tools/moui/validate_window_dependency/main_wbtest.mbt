///|
test "window versions are extracted from every discovered consumer text" {
  let result = validate_window_dependency_inputs(
    Some("members = []"),
    [
      {
        path: "a/moon.mod",
        text: Some("import { \"wzzc-dev/window@0.5.4-0.1.3\" }"),
      },
      {
        path: "nested/b/moon.mod",
        text: Some("import { \"wzzc-dev/window@0.5.4-0.1.3\" }"),
      },
    ],
    None,
  )
  assert_true(result.errors.is_empty())
  assert_eq(result.pinned, "0.5.4-0.1.3")
}

///|
test "window version mismatch reports dynamic consumer paths" {
  let result = validate_window_dependency_inputs(
    Some("members = []"),
    [
      {
        path: "first/moon.mod",
        text: Some("import { \"wzzc-dev/window@1.0.0\" }"),
      },
      {
        path: "new-consumer/moon.mod",
        text: Some("import { \"wzzc-dev/window@2.0.0\" }"),
      },
    ],
    None,
  )
  assert_eq(result.errors.length(), 1)
  assert_true(result.errors[0].contains("first/moon.mod"))
  assert_true(result.errors[0].contains("new-consumer/moon.mod"))
  assert_false(result.errors[0].contains("all four consumers"))
}

///|
test "dependency scan skips generated and external dependency directories" {
  for
    name in [
      ".git", ".mooncakes", "_build", "artifacts", "node_modules", "output", "window",
    ] {
    assert_true(skipped_scan_directory(name))
  }
  assert_false(skipped_scan_directory("examples"))
}
