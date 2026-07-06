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
test "extracts workspace members from members block" {
  let sample =
    #|# Development
    #|
    #|```toml
    #|members = [
    #|  "./moui",
    #|  "./examples/showcase",
    #|]
    #|```
  match workspace_members_from_member_block(sample) {
    Ok(values) => {
      assert_true(values.length() == 2)
      assert_true(values[0] == "./moui")
      assert_true(values[1] == "./examples/showcase")
    }
    Err(message) => fail(message)
  }
}

///|
test "detects duplicate workspace members" {
  let duplicates = duplicate_values(["./moui", "./tools", "./moui"])
  assert_true(duplicates.length() == 1)
  assert_true(duplicates[0] == "./moui")
}

///|
test "deduplicates values in first-seen order" {
  let values = unique_values(["a", "b", "a", "c", "b"])
  assert_true(values.length() == 3)
  assert_true(values[0] == "a")
  assert_true(values[1] == "b")
  assert_true(values[2] == "c")
}

///|
test "extracts window dependency tokens from docs and moon.mod text" {
  let sample =
    #|The current dependency is `wzzc-dev/window@0.5.1-0.1.6`.
    #|import {
    #|  "wzzc-dev/window@0.5.1-0.1.6",
    #|}
  let tokens = unique_values(window_dependency_tokens(sample))
  assert_true(tokens.length() == 1)
  assert_true(tokens[0] == "wzzc-dev/window@0.5.1-0.1.6")
}

///|
test "window dependency guidance rejects stale tokens" {
  let failures = window_dependency_guidance_failures(
    "docs/platform-notes.md", "wzzc-dev/window@0.5.1-0.1.6", "MoUI resolves `wzzc-dev/window@0.5.1-0.1.4`.",
  )
  assert_true(failures.length() == 2)
  assert_true(
    failures.contains(
      "docs/platform-notes.md: expected to mention wzzc-dev/window@0.5.1-0.1.6",
    ),
  )
  assert_true(
    failures.contains(
      "docs/platform-notes.md: window dependency token 'wzzc-dev/window@0.5.1-0.1.4' should be 'wzzc-dev/window@0.5.1-0.1.6'",
    ),
  )
}

///|
test "window dependency guidance requires a current mention" {
  let failures = window_dependency_guidance_failures(
    "docs/examples.md", "wzzc-dev/window@0.5.1-0.1.6", "No dependency here.",
  )
  assert_true(failures.length() == 1)
  assert_true(
    failures[0] ==
    "docs/examples.md: expected to mention wzzc-dev/window@0.5.1-0.1.6",
  )
}

///|
test "workspace member list match reports missing and stale entries" {
  let failures : Array[String] = []
  push_workspace_member_list_match(
    "docs/development.md",
    ["./moui", "./tools"],
    ["./moui", "./legacy"],
    failures,
  )
  assert_true(failures.length() == 2)
  assert_true(
    failures.contains(
      "docs/development.md: workspace member list is missing: ./tools",
    ),
  )
  assert_true(
    failures.contains(
      "docs/development.md: workspace member list has stale entries: ./legacy",
    ),
  )
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
  assert_false(
    tokens.contains("moon test examples/design_systems/app --target native"),
  )
  assert_true(
    tokens.contains("moon build examples/showcase/web_wasm --target wasm-gc"),
  )
  assert_false(
    tokens.contains(
      "moon build examples/design_systems/web_wasm --target wasm-gc",
    ),
  )
}

///|
test "release readiness quality tokens summarize current daily gates" {
  let tokens = release_readiness_quality_tokens()
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("dedicated checked-artifact validators"))
  assert_true(tokens.contains("--theme-diagnostics"))
  assert_true(tokens.contains("Design Systems is addon diagnostic coverage"))
}

///|
test "agent quality gate tokens cover AGENTS sync points" {
  let tokens = agent_quality_gate_tokens()
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("node scripts/validate-guidance-consistency.mjs"))
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
