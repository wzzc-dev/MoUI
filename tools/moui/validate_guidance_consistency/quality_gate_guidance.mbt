///|
fn daily_quality_gate_tokens() -> Array[String] {
  [
    "pr", "daily", "scripts/lint-scripts.mjs", "scripts/validate-check-profiles.mjs",
    "scripts/validate-guidance-consistency.mjs", "scripts/validate-api-surface.mjs",
    "scripts/validate-window-dependency.mjs", "scripts/validate-maintenance-baseline.mjs",
    "moon", "moui/core", "moui/views", "moui/render", "moui_skia_renderer", "moui/backend",
    "moui/backend/web", "examples/showcase/web_wasm", "examples/markdown_editor/web_wasm",
  ]
}

///|
fn push_daily_quality_gate_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in daily_quality_gate_tokens() {
    push_include_check(repo_root, "checks/profiles.json", token, failures)
    push_include_check(repo_root, "docs/testing.md", token, failures)
  }
}

///|
fn release_readiness_quality_tokens() -> Array[String] {
  [
    "node scripts/validate-api-surface.mjs", "checked conformance artifact guard",
    "dedicated checked-artifact validators", "scripts/check.sh --profile theme",
    "Design Systems is addon diagnostic coverage",
  ]
}

///|
fn push_release_readiness_quality_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in release_readiness_quality_tokens() {
    push_include_check(repo_root, "docs/release-readiness.md", token, failures)
  }
}

///|
fn agent_quality_gate_tokens() -> Array[String] {
  [
    "node scripts/validate-api-surface.mjs", "node scripts/validate-guidance-consistency.mjs",
    "scripts/check.sh --profile theme", "Design Systems is addon diagnostic coverage",
  ]
}

///|
fn push_agent_quality_gate_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in agent_quality_gate_tokens() {
    push_include_check(repo_root, "AGENTS.md", token, failures)
  }
}

///|
fn theme_diagnostic_rules() -> Array[TextRule] {
  [
    { path: "checks/profiles.json", token: "\"theme\"" },
    { path: "checks/profiles.json", token: "moui_theme/common" },
    { path: "checks/profiles.json", token: "examples/design_systems/web_wasm" },
    { path: "docs/testing.md", token: "scripts/check.sh --profile theme" },
    {
      path: "docs/testing.md",
      token: "Design Systems is addon diagnostic coverage",
    },
    {
      path: "docs/release-readiness.md",
      token: "scripts/check.sh --profile theme",
    },
    {
      path: "docs/release-readiness.md",
      token: "Design Systems is addon diagnostic coverage",
    },
    { path: "AGENTS.md", token: "scripts/check.sh --profile theme" },
    { path: "AGENTS.md", token: "Design Systems is addon diagnostic coverage" },
    { path: "moui/README.mbt.md", token: "scripts/check.sh --profile theme" },
    {
      path: "docs/maintenance.md",
      token: "Design Systems is addon diagnostic coverage",
    },
  ]
}

///|
fn push_theme_diagnostic_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for rule in theme_diagnostic_rules() {
    push_include_check(repo_root, rule.path, rule.token, failures)
  }
}
