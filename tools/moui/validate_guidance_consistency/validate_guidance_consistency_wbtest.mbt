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
  assert_true(tokens.contains("scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("scripts/test-check-runner.mjs"))
  assert_true(tokens.contains("moui/core"))
  assert_false(
    tokens.contains("moon test examples/design_systems/app --target native"),
  )
  assert_true(tokens.contains("examples/showcase/web_wasm"))
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
  assert_true(tokens.contains("scripts/check.sh --profile theme"))
  assert_true(tokens.contains("Design Systems is addon diagnostic coverage"))
}

///|
test "agent quality gate tokens cover AGENTS sync points" {
  let tokens = agent_quality_gate_tokens()
  assert_true(tokens.contains("node scripts/validate-api-surface.mjs"))
  assert_true(tokens.contains("node scripts/validate-guidance-consistency.mjs"))
  assert_true(tokens.contains("scripts/check.sh --profile theme"))
  assert_true(tokens.contains("Design Systems is addon diagnostic coverage"))
}

///|
test "theme diagnostic rules cover opt-in addon checks" {
  let rules = theme_diagnostic_rules()
  assert_true(
    rules.any(rule => {
      rule.path == "checks/profiles.json" && rule.token == "\"theme\""
    }),
  )
  assert_true(
    rules.any(rule => {
      rule.path == "checks/profiles.json" && rule.token == "moui_theme/common"
    }),
  )
  assert_true(
    rules.any(rule => {
      rule.path == "docs/testing.md" &&
      rule.token == "Design Systems is addon diagnostic coverage"
    }),
  )
}

///|
test "forbidden guidance tokens include deleted entrypoints and old flags" {
  let tokens = forbidden_guidance_tokens()
  assert_true(tokens.contains("dev-check.sh"))
  assert_true(tokens.contains("dev_check.ps1"))
  assert_true(tokens.contains("conformance-check.sh"))
  assert_true(tokens.contains("--theme-diagnostics"))
  assert_true(tokens.contains("--skia-real-smoke"))
  let workflow_tokens = legacy_workflow_guidance_tokens()
  assert_true(workflow_tokens.contains("moui-real-skia-smoke.yml"))
  assert_true(workflow_tokens.contains("moui-skia-real-skia-pr-smoke.yml"))
  assert_true(workflow_tokens.contains("moui-renderer-real-skia-ci-smoke.yml"))
  assert_true(workflow_tokens.contains("moui-runtime-smoke-gates.yml"))
  assert_true(workflow_tokens.contains("moui-skia-fallback.yml"))
  assert_true(workflow_tokens.contains("Platform Evidence Dispatch"))
}

///|
test "forbidden guidance scan covers top-level public docs" {
  let files = top_level_guidance_files()
  assert_true(files.contains("AGENTS.md"))
  assert_true(files.contains("README.md"))
  assert_true(files.contains("CONTRIBUTING.md"))
  assert_true(files.contains("GOVERNANCE.md"))
}

///|
test "forbidden guidance token failure points at fixture-only allowance" {
  let failures = forbidden_guidance_token_failures(
    "docs/testing.md", "Run sh scripts/dev-check.sh or pass --theme-diagnostics.",
  )
  assert_true(failures.length() == 2)
  assert_true(
    failures.contains(
      "docs/testing.md: deleted or legacy check token 'dev-check.sh' must not be recommended; validator fixtures are the only allowed location for intentional negative tests",
    ),
  )
  assert_true(
    failures.contains(
      "docs/testing.md: deleted or legacy check token '--theme-diagnostics' must not be recommended; validator fixtures are the only allowed location for intentional negative tests",
    ),
  )
}

///|
test "legacy workflow guidance rejects current docs but permits session history" {
  let current_failures = forbidden_guidance_token_failures(
    "docs/testing.md", "Use moui-renderer-real-skia-ci-smoke.yml.",
  )
  assert_true(current_failures.length() == 1)
  assert_true(
    current_failures.contains(
      "docs/testing.md: legacy workflow name 'moui-renderer-real-skia-ci-smoke.yml' must not be recommended; docs/ai-sessions history and validator fixtures are the only allowed locations",
    ),
  )
  let historical_failures = forbidden_guidance_token_failures(
    "docs/ai-sessions/2026-06-29-ci-feature-proof-system.md", "Historically used moui-skia-real-skia-pr-smoke.yml.",
  )
  assert_true(historical_failures.is_empty())
}
