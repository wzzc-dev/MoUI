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
  assert_true(tokens.contains("node scripts/validate-maintenance-baseline.mjs"))
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("node --check scripts/smoke-check.mjs"))
  assert_true(tokens.contains("node --check scripts/test-smoke-check.mjs"))
  assert_true(tokens.contains("node scripts/test-smoke-check.mjs"))
  assert_true(tokens.contains("node scripts/smoke-check.mjs --check"))
  assert_true(tokens.contains("node --check scripts/smoke-gate.mjs"))
  assert_true(tokens.contains("node --check scripts/test-smoke-gate.mjs"))
  assert_true(tokens.contains("node scripts/test-smoke-gate.mjs"))
  assert_true(
    tokens.contains(
      "node scripts/smoke-gate.mjs --tier nightly --dry-run --json",
    ),
  )
  assert_true(tokens.contains("moon test moui/core --target native"))
  assert_true(
    tokens.contains("moon build examples/showcase/web_wasm --target wasm-gc"),
  )
}

///|
test "release readiness quality tokens summarize current daily gates" {
  let tokens = release_readiness_quality_tokens()
  assert_true(tokens.contains("node scripts/validate-maintenance-baseline.mjs"))
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("daily baseline"))
  assert_true(tokens.contains("maintenance ratchets"))
  assert_true(tokens.contains("manual smoke"))
  assert_true(tokens.contains("CI run or smoke log"))
  assert_true(tokens.contains("node scripts/smoke-check.mjs --check"))
  assert_true(tokens.contains("smoke gate catalog"))
  assert_true(tokens.contains("smoke/gates.json"))
  assert_true(
    tokens.contains(
      "node scripts/smoke-gate.mjs --tier release --dry-run --json",
    ),
  )
  assert_true(tokens.contains(".github/workflows/moui-runtime-smoke-gates.yml"))
  assert_true(tokens.contains("--theme-diagnostics"))
  assert_true(tokens.contains("Design Systems is addon diagnostic coverage"))
}

///|
test "agent quality gate tokens cover AGENTS sync points" {
  let tokens = agent_quality_gate_tokens()
  assert_true(tokens.contains("node scripts/validate-maintenance-baseline.mjs"))
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("daily validation script"))
  assert_true(tokens.contains("maintenance baseline"))
  assert_true(tokens.contains("manual smoke"))
  assert_true(tokens.contains("smoke/gates.json"))
  assert_true(tokens.contains("scripts/smoke-gate.mjs"))
  assert_true(tokens.contains(".github/workflows/moui-runtime-smoke-gates.yml"))
  assert_true(tokens.contains("Do not commit artifacts/"))
  assert_true(tokens.contains("--theme-diagnostics"))
  assert_true(tokens.contains("Design Systems is addon diagnostic coverage"))
}

///|
test "theme diagnostic rules cover opt-in addon checks" {
  let rules = theme_diagnostic_rules()
  assert_true(
    rules.any(rule => {
      rule.path == "scripts/dev-check.sh" && rule.token == "--theme-diagnostics"
    }),
  )
  assert_true(
    rules.any(rule => {
      rule.path == "scripts/dev-check.sh" &&
      rule.token == "moon test moui_theme/common --target native"
    }),
  )
  assert_true(
    rules.any(rule => {
      rule.path == "docs/testing.md" &&
      rule.token == "Design Systems is addon diagnostic coverage"
    }),
  )
}
