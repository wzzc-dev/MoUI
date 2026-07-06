///|
fn daily_quality_gate_tokens() -> Array[String] {
  [
    "node --check scripts/validate-api-surface.mjs", "node --check scripts/validate-guidance-consistency.mjs",
    "node scripts/validate-guidance-consistency.mjs", "node scripts/validate-api-surface.mjs",
    "node --check scripts/validate-window-dependency.mjs", "node scripts/validate-window-dependency.mjs",
    "node --check scripts/validate-openseek-workbench.mjs", "node scripts/validate-openseek-workbench.mjs",
    "node --check scripts/validate-maintenance-baseline.mjs", "node scripts/validate-maintenance-baseline.mjs",
    "node scripts/validate-renderer-provider-manifests.mjs", "node scripts/validate-skia-entrypoints.mjs",
    "node scripts/test-validate-skia-entrypoints.mjs", "node --check scripts/test-moui-prebuild.mjs",
    "node scripts/test-moui-prebuild.mjs", "node scripts/test-validate-conformance-capture-manifest.mjs",
    "node scripts/generate-grapheme-break-fixtures.mjs --check", "node scripts/test-validate-web-runtime-handoff-manifest.mjs",
    "node scripts/test-record-web-runtime-presentation.mjs", "node scripts/test-validate-web-runtime-presentation-manifest.mjs",
    "node scripts/smoke-check.mjs --check", "node scripts/smoke-gate.mjs --tier nightly --dry-run --json",
    "sh -n scripts/ci-moon-update.sh", "sh -n scripts/ci-web-runtime-presentation.sh",
    "moon check", "moon test moui/core --target native", "moon test moui/views --target native",
    "moon test moui/render --target native", "moon test moui/render/skia --target native",
    "moon test moui/render/sun --target native", "moon test moui/backend/host --target native",
    "moon test moui_tester --target native", "moon test moui_devtools --target native",
    "moon test moui_skia --target native", "moon test moui/render/webgpu_adapter --target wasm-gc",
    "moon test moui/backend/web --target wasm-gc", "moon test examples/showcase/app --target native",
    "moon test examples/markdown_editor/app --target native", "moon build examples/showcase/web_wasm --target wasm-gc",
    "moon build examples/markdown_editor/web_wasm --target wasm-gc", "node scripts/validate-web-runtime-handoff.mjs",
  ]
}

///|
fn push_daily_quality_gate_checks(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for token in daily_quality_gate_tokens() {
    push_include_check(repo_root, "scripts/dev-check.sh", token, failures)
    push_include_check(repo_root, "docs/testing.md", token, failures)
  }
}

///|
fn release_readiness_quality_tokens() -> Array[String] {
  [
    "node scripts/validate-api-surface.mjs", "checked conformance artifact guard",
    "dedicated checked-artifact validators", "--theme-diagnostics", "Design Systems is addon diagnostic coverage",
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
    "--theme-diagnostics", "Design Systems is addon diagnostic coverage",
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
    { path: "scripts/dev-check.sh", token: "--theme-diagnostics" },
    {
      path: "scripts/dev-check.sh",
      token: "moon test moui_theme/common --target native",
    },
    {
      path: "scripts/dev-check.sh",
      token: "moon build examples/design_systems/web_wasm --target wasm-gc",
    },
    { path: "docs/testing.md", token: "--theme-diagnostics" },
    {
      path: "docs/testing.md",
      token: "Design Systems is addon diagnostic coverage",
    },
    { path: "docs/release-readiness.md", token: "--theme-diagnostics" },
    {
      path: "docs/release-readiness.md",
      token: "Design Systems is addon diagnostic coverage",
    },
    { path: "AGENTS.md", token: "--theme-diagnostics" },
    { path: "AGENTS.md", token: "Design Systems is addon diagnostic coverage" },
    { path: "moui/README.mbt.md", token: "--theme-diagnostics" },
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
