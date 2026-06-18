///|
test "line count handles final newline consistently" {
  inspect(line_count(""), content="0")
  inspect(line_count("one"), content="1")
  inspect(line_count("one\n"), content="1")
  inspect(line_count("one\ntwo"), content="2")
}

///|
test "generated unicode fixtures are excluded from oversized ratchet scan" {
  inspect(
    generated_fixture_path(
      "moui/core/text_grapheme_break_unicode_17_wbtest.mbt",
    ),
    content="true",
  )
  inspect(
    generated_fixture_path("moui/runtime/runtime_view_smoke_wbtest.mbt"),
    content="false",
  )
}

///|
test "tracked budgets include current maintenance hotspots" {
  let paths = tracked_budget_paths()
  inspect(paths.contains("moui/backend/host/host_test.mbt"), content="true")
  inspect(paths.contains("moui/core/view_tree.mbt"), content="true")
  inspect(
    paths.contains("moui/runtime/program_runtime_diagnostics.mbt"),
    content="true",
  )
}

///|
test "line budget overflow paths are sorted from most lines to fewest" {
  let overflows = [
    { path: "small.mbt", lines: 12 },
    { path: "large.mbt", lines: 50 },
    { path: "also-large.mbt", lines: 50 },
  ]
  debug_inspect(
    line_budget_overflow_paths(overflows),
    content=(
      #|["also-large.mbt", "large.mbt", "small.mbt"]
    ),
  )
}
