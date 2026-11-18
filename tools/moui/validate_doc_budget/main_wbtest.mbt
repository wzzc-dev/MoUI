///|
test "count_lines counts newline characters like wc -l" {
  assert_eq(count_lines(""), 0)
  assert_eq(count_lines("a"), 0)
  assert_eq(count_lines("a\n"), 1)
  assert_eq(count_lines("a\nb\n"), 2)
  assert_eq(count_lines("a\nb"), 1)
  assert_eq(count_lines("\n\n\n"), 3)
}

///|
test "path_is_excluded matches an excluded root and its subtree only" {
  let excluded = ["docs/plans/done", "docs/assets"]
  assert_true(path_is_excluded("docs/plans/done", excluded))
  assert_true(path_is_excluded("docs/plans/done/old.md", excluded))
  assert_true(path_is_excluded("docs/assets", excluded))
  assert_false(path_is_excluded("docs/plans/done-more/x.md", excluded))
  assert_false(path_is_excluded("docs/plans/active/x.md", excluded))
  assert_false(path_is_excluded("", excluded))
}

///|
test "total_lines adds every file" {
  let files : Array[DocFile] = [
    { path: "docs/a.md", lines: 3, },
    { path: "docs/b.md", lines: 4, },
  ]
  assert_eq(total_lines(files), 7)
  assert_eq(total_lines([]), 0)
}

///|
test "largest_files sorts by lines desc and breaks ties by path" {
  let files : Array[DocFile] = [
    { path: "docs/b.md", lines: 10, },
    { path: "docs/a.md", lines: 10, },
    { path: "docs/big.md", lines: 40, },
    { path: "docs/small.md", lines: 1, },
  ]
  let ranked : Array[DocFile] = largest_files(files, 3)
  assert_eq(ranked.length(), 3)
  assert_eq(ranked[0].path, "docs/big.md")
  assert_eq(ranked[1].path, "docs/a.md")
  assert_eq(ranked[2].path, "docs/b.md")
}

///|
test "budget_failures passes at the ceiling and fails one line over" {
  let catalog : DocBudgetCatalog = {
    max_lines: 100,
    roots: ["docs"],
    excluded: [],
  }
  let at_ceiling : Array[DocFile] = [{ path: "docs/a.md", lines: 100, }]
  assert_eq(budget_failures(at_ceiling, catalog).length(), 0)
  let over : Array[DocFile] = [{ path: "docs/a.md", lines: 101, }]
  let failures = budget_failures(over, catalog)
  assert_true(failures.length() >= 2)
  inspect(
    failures[0],
    content="doc budget exceeded: 101 lines > ceiling 100 (over by 1)",
  )
}

///|
test "budget_failures reports the largest contributors" {
  let catalog : DocBudgetCatalog = {
    max_lines: 10,
    roots: ["docs"],
    excluded: [],
  }
  let files : Array[DocFile] = [
    { path: "docs/small.md", lines: 1, },
    { path: "docs/big.md", lines: 9, },
    { path: "docs/medium.md", lines: 5, },
  ]
  let failures = budget_failures(files, catalog)
  assert_true(failures[0].has_prefix("doc budget exceeded: 15 lines"))
  let mut has_big = false
  let mut has_medium = false
  for failure in failures {
    if failure == "  docs/big.md: 9 lines" {
      has_big = true
    }
    if failure == "  docs/medium.md: 5 lines" {
      has_medium = true
    }
  }
  assert_true(has_big)
  assert_true(has_medium)
}
