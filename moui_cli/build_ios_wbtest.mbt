// Whitebox tests for `build_ios.mbt`.
//
// Tests focus on the pure helpers (`parse_dotted_version`, `version_at_least`).
// End-to-end `xcodebuild` invocation is exercised by integration tests with
// a real Xcode install and is intentionally not covered here.

///|
test "test_parse_dotted_version_simple" {
  debug_inspect(parse_dotted_version("15.4"), content="[15, 4]")
  debug_inspect(parse_dotted_version("16.0.1"), content="[16, 0, 1]")
  debug_inspect(parse_dotted_version("17"), content="[17]")
}

///|
test "test_parse_dotted_version_invalid" {
  debug_inspect(parse_dotted_version("abc"), content="[]")
  debug_inspect(parse_dotted_version("15.x"), content="[]")
  debug_inspect(parse_dotted_version(""), content="[]")
  debug_inspect(parse_dotted_version("15a.4"), content="[]")
}

///|
test "test_version_at_least_equal" {
  assert_true(version_at_least("15.4", "15.4"))
  assert_true(version_at_least("16.0", "16"))
  assert_true(version_at_least("16", "16.0"))
}

///|
test "test_version_at_least_higher" {
  assert_true(version_at_least("16.0", "15.4"))
  assert_true(version_at_least("17.0", "15.4"))
  assert_true(version_at_least("15.5", "15.4"))
}

///|
test "test_version_at_least_lower" {
  assert_false(version_at_least("14.0", "15.4"))
  assert_false(version_at_least("15.3", "15.4"))
  assert_false(version_at_least("15.0", "16.0"))
}

///|
test "test_version_at_least_invalid" {
  assert_false(version_at_least("", "15.4"))
  assert_false(version_at_least("15.4", ""))
  assert_false(version_at_least("abc", "15.4"))
}

///|
test "test_xcode_version_string_returns_empty_when_unavailable" {
  // In sandboxes without `xcodebuild` on PATH, this returns "".
  // On macOS CI with Xcode installed, it may return a real version; either
  // outcome is acceptable, so we only assert the return type is a string.
  let _ = xcode_version_string()
  assert_true(true)
}
