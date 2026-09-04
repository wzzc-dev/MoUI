///|
struct WrapperBudget {
  path : String
  max_lines : Int
}

///|
fn moonbit_tool_wrapper_budgets() -> Array[WrapperBudget] {
  [
    { path: "scripts/validate-api-surface.mjs", max_lines: 12 },
    { path: "scripts/validate-check-profiles.mjs", max_lines: 12 },
    { path: "scripts/validate-conformance-capture-manifest.mjs", max_lines: 28 },
    { path: "scripts/validate-doc-references.mjs", max_lines: 12 },
    { path: "scripts/validate-guidance-consistency.mjs", max_lines: 12 },
    { path: "scripts/validate-harness-invariants.mjs", max_lines: 16 },
    { path: "scripts/validate-gpu-promotion-manifest.mjs", max_lines: 20 },
    { path: "scripts/validate-gpu-worker-no-readback.mjs", max_lines: 16 },
    { path: "scripts/validate-maintenance-baseline.mjs", max_lines: 12 },
    { path: "scripts/validate-package-manifest.mjs", max_lines: 28 },
    { path: "scripts/validate-performance-budgets.mjs", max_lines: 26 },
    { path: "scripts/validate-renderer-provider-manifests.mjs", max_lines: 12 },
    { path: "scripts/validate-release-module-closures.mjs", max_lines: 12 },
    {
      path: "scripts/validate-renderer-capability-consistency.mjs",
      max_lines: 12,
    },
    { path: "scripts/validate-backend-common-boundary.mjs", max_lines: 12 },
    {
      path: "scripts/validate-runtime-state-render-ownership.mjs",
      max_lines: 12,
    },
    { path: "scripts/validate-platform-matrix.mjs", max_lines: 8 },
    { path: "scripts/validate-skia-entrypoints.mjs", max_lines: 16 },
    { path: "scripts/validate-viewnode-declaration-coverage.mjs", max_lines: 9 },
    { path: "scripts/validate-web-runtime-handoff-manifest.mjs", max_lines: 28 },
    { path: "scripts/validate-web-runtime-handoff.mjs", max_lines: 170 },
    {
      path: "scripts/validate-web-runtime-presentation-manifest.mjs",
      max_lines: 28,
    },
    { path: "scripts/validate-window-dependency.mjs", max_lines: 12 },
    { path: "scripts/validate-window-lifecycle-boundary.mjs", max_lines: 12 },
    { path: "scripts/smoke-check.mjs", max_lines: 12 },
  ]
}

///|
fn moonbit_tool_wrapper_forbidden_tokens() -> Array[String] {
  [
    "spawnSync(", "execSync(", "execFileSync(", "readFileSync(", "existsSync(", "node:fs",
    "_build/native/debug/build", "moon build",
  ]
}

///|
fn validate_moonbit_tool_wrapper_text(
  budget : WrapperBudget,
  text : String,
) -> Array[String] {
  let failures : Array[String] = []
  let lines = line_count(text)
  if lines > budget.max_lines {
    failures.push(
      "MoonBit tool wrapper budget exceeded: " +
      budget.path +
      " lines=\{lines} max=\{budget.max_lines}",
    )
  }
  if !text.contains("runMoonbitTool(") {
    failures.push(
      "MoonBit tool wrapper missing runMoonbitTool call: " + budget.path,
    )
  }
  if !text.contains("./lib/moonbit-tool-runner.mjs") {
    failures.push(
      "MoonBit tool wrapper missing shared runner import: " + budget.path,
    )
  }
  for token in moonbit_tool_wrapper_forbidden_tokens() {
    if text.contains(token) {
      failures.push(
        "MoonBit tool wrapper contains forbidden token '" +
        token +
        "': " +
        budget.path,
      )
    }
  }
  failures
}

///|
fn validate_moonbit_tool_wrapper_budget_coverage(
  actual_paths : Array[String],
) -> Array[String] {
  let failures : Array[String] = []
  let budget_paths = moonbit_tool_wrapper_budgets().map(budget => budget.path)
  for path in actual_paths {
    if !array_contains(budget_paths, path) {
      failures.push("MoonBit tool wrapper missing maintenance budget: " + path)
    }
  }
  failures
}

///|
fn collect_moonbit_tool_wrapper_paths(
  repo_root : String,
  failures : Array[String],
) -> Array[String] {
  let paths : Array[String] = []
  let scripts_dir = @tools.resolve_path(repo_root, "scripts")
  let entries = match read_dir_names(scripts_dir, "scripts") {
    Ok(values) => values
    Err(message) => {
      failures.push(message)
      return paths
    }
  }
  for entry in entries {
    if entry.has_prefix("validate-") && entry.has_suffix(".mjs") {
      let path = "scripts/" + entry
      match read_repo_text(repo_root, path) {
        Ok(text) => if text.contains("runMoonbitTool(") { paths.push(path) }
        Err(message) => failures.push(message)
      }
    }
  }
  paths.sort()
  paths
}

///|
fn collect_moonbit_tool_wrapper_failures(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  let actual_paths = collect_moonbit_tool_wrapper_paths(repo_root, failures)
  failures.append(validate_moonbit_tool_wrapper_budget_coverage(actual_paths))
  for budget in moonbit_tool_wrapper_budgets() {
    match read_repo_text(repo_root, budget.path) {
      Ok(text) =>
        failures.append(validate_moonbit_tool_wrapper_text(budget, text))
      Err(message) => failures.push(message)
    }
  }
  failures
}
