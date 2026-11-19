// White-box tests for the maintenance baseline gate: scan scope, line/count
// budgets, overflow ordering and messages, and the MoonBit tool wrapper rules.

///|
fn sample_line_overflow(path : String, lines : Int32) -> LineBudgetOverflow {
  { path, lines, }
}

///|
test "scan scope and line-budget catalogs stay scoped" {
  let daily = monitored_roots("daily")
  let full = monitored_roots("full")
  assert_true(daily.contains("moui"))
  assert_true(daily.contains("examples"))
  assert_true(!daily.contains("tools"))
  assert_true(full.contains("tools"))
  assert_true(full.length() > daily.length())
  // Only the documented `full` scope widens the scan.
  assert_eq(monitored_roots("weekly"), daily)
  assert_eq(oversized_file_threshold(), 1800)
  assert_eq(line_budget_file_budgets("daily").length(), file_budgets().length())
  assert_true(
    line_budget_file_budgets("full").length() >
    line_budget_file_budgets("daily").length(),
  )
  assert_true(
    tracked_budget_paths(scope="full").contains(
      "examples/showcase/app/showcase_route_app_test.mbt",
    ),
  )
}

///|
test "line-budget overflows sort by lines then by descending path" {
  let overflows = [
    sample_line_overflow("b.mbt", 2000),
    sample_line_overflow("c.mbt", 1900),
    sample_line_overflow("a.mbt", 2000),
  ]
  assert_eq(line_budget_overflow_paths(overflows), ["b.mbt", "a.mbt", "c.mbt"])
}

///|
test "count-budget overflows respect the threshold and message format" {
  let budget = {
    kind: "pub(all)",
    label: "moui/core",
    path: "moui/core",
    max_count: 4,
  }
  let overflows : Array[CountBudgetOverflow] = []
  // Exactly at the limit is fine; one above it is reported.
  record_count_budget_overflow(budget, 4, overflows)
  assert_eq(overflows.length(), 0)
  record_count_budget_overflow(budget, 5, overflows)
  assert_eq(overflows.length(), 1)
  assert_eq(
    count_budget_overflow_message(overflows[0]),
    "pub(all) budget exceeded: moui/core count=5 max=4",
  )
  let second = {
    kind: "root-facade",
    label: "moui/root",
    path: "moui/root.mbt",
    max_count: 1,
  }
  record_count_budget_overflow(second, 2, overflows)
  // Sorting is by kind then label, independent of insertion order.
  assert_eq(count_budget_overflow_messages(overflows), [
    "pub(all) budget exceeded: moui/core count=5 max=4", "root-facade budget exceeded: moui/root count=2 max=1",
  ])
}

///|
test "source counting helpers count physical lines and facade forwards" {
  assert_eq(line_count(""), 0)
  assert_eq(line_count("a"), 1)
  assert_eq(line_count("a\n"), 1)
  assert_eq(line_count("a\nb"), 2)
  assert_eq(
    count_lines_containing_token(
      "pub(all) enum A\nfn b\npub(all) B", "pub(all)",
    ),
    2,
  )
  assert_eq(
    count_root_facade_forwards(
      "pub type A\n  pub type B\nfn c\npub typealias D",
    ),
    2,
  )
  assert_true(generated_fixture_path("x_unicode_17_wbtest.mbt"))
  assert_true(!generated_fixture_path("x_wbtest.mbt"))
  assert_true(generated_source_text("// DO NOT EDIT\nfn generated()"))
  assert_true(!generated_source_text("// hand written\nfn real()"))
  assert_true(skipped_directory_name("_build"))
  assert_true(!skipped_directory_name("src"))
}

///|
test "tool wrapper validation enforces runner usage and budget" {
  let budget : WrapperBudget = {
    path: "scripts/validate-demo.mjs",
    max_lines: 10,
  }
  let good = "import { runMoonbitTool } from './lib/moonbit-tool-runner.mjs';\nrunMoonbitTool('demo');\n"
  assert_eq(validate_moonbit_tool_wrapper_text(budget, good).length(), 0)
  let missing_runner = "runMoonbitTool('demo');\n"
  assert_true(
    validate_moonbit_tool_wrapper_text(budget, missing_runner).contains(
      "MoonBit tool wrapper missing shared runner import: scripts/validate-demo.mjs",
    ),
  )
  let missing_call = "import './lib/moonbit-tool-runner.mjs';\n"
  assert_true(
    validate_moonbit_tool_wrapper_text(budget, missing_call).contains(
      "MoonBit tool wrapper missing runMoonbitTool call: scripts/validate-demo.mjs",
    ),
  )
  let forbidden = "import './lib/moonbit-tool-runner.mjs';\nrunMoonbitTool('demo');\nreadFileSync('x');\n"
  assert_true(
    validate_moonbit_tool_wrapper_text(budget, forbidden).contains(
      "MoonBit tool wrapper contains forbidden token 'readFileSync(': scripts/validate-demo.mjs",
    ),
  )
  let oversized = "import './lib/moonbit-tool-runner.mjs';\nrunMoonbitTool('demo');\n// pad\n// pad\n// pad\n// pad\n// pad\n// pad\n// pad\n// pad\n// pad\n"
  assert_true(
    validate_moonbit_tool_wrapper_text(budget, oversized).contains(
      "MoonBit tool wrapper budget exceeded: scripts/validate-demo.mjs lines=11 max=10",
    ),
  )
}
