///|
test "extracts quoted moon.work members" {
  let sample =
    #|members = [
    #|  "./moui",
    #|  "./examples/counter",
    #|]
  let values = quoted_strings(sample)
  assert_true(values.length() == 2)
  assert_true(values[0] == "./moui")
  assert_true(values[1] == "./examples/counter")
}

///|
test "include failure names missing token" {
  match include_failure("docs/example.md", "hello world", "missing") {
    Some(message) =>
      assert_true(message == "docs/example.md: expected to include 'missing'")
    None => fail("expected include failure")
  }
}

///|
test "absent failure names stale token" {
  match absent_failure("docs/example.md", "legacy token", "legacy") {
    Some(message) =>
      assert_true(message == "docs/example.md: stale guidance token 'legacy'")
    None => fail("expected absent failure")
  }
}

///|
test "daily quality gate tokens include moonbit-backed api surface guard" {
  let tokens = daily_quality_gate_tokens()
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("moon test moui/core --target native"))
  assert_true(
    tokens.contains("moon build examples/showcase/web_wasm --target wasm-gc"),
  )
}
