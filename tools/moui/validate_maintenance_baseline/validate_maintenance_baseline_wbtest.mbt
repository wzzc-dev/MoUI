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
test "pub all budgets lock current maintenance exposure" {
  let labels = pub_all_budgets().map(budget => budget.label)
  inspect(labels.contains("moui/core"), content="true")
  inspect(labels.contains("moui/views"), content="true")
  inspect(labels.contains("moui/backend/host"), content="true")
  inspect(labels.contains("examples/markdown_editor/app"), content="true")
  inspect(labels.contains("website/app"), content="true")
}

///|
test "pub all token and root facade forward counts are line based" {
  let pub_all_source =
    #|pub(all) struct One {}
    #|let text = "pub(all) inside a string still counts for the ratchet"
    #|pub fn two() -> Unit { () }
    #|pub(all) enum Three { A }
  let root_facade_source =
    #|///|
    #|pub type View[Msg] = @core.View[Msg]
    #|  pub type Theme = @core.Theme
    #|pub fn helper() -> Unit { () }
  inspect(count_lines_containing_token(pub_all_source, "pub(all)"), content="3")
  inspect(count_root_facade_forwards(root_facade_source), content="2")
}

///|
test "count budget overflow messages include kind count and max" {
  let overflows = [
    {
      kind: "root facade forwards",
      label: "moui/moui.mbt",
      count: 37,
      max_count: 36,
    },
    { kind: "pub(all)", label: "moui/core", count: 281, max_count: 280 },
  ]
  debug_inspect(
    count_budget_overflow_messages(overflows),
    content=(
      #|[
      #|  "pub(all) budget exceeded: moui/core count=281 max=280",
      #|  "root facade forwards budget exceeded: moui/moui.mbt count=37 max=36",
      #|]
    ),
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
