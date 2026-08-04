///|
test "plan status follows directory semantics" {
  assert_true(status_matches_plan_directory("active", "- **Status**: active"))
  assert_true(
    status_matches_plan_directory(
      "active", "- **Status**: implementation active; parity audit in progress",
    ),
  )
  assert_false(status_matches_plan_directory("active", "- **Status**: done"))
  assert_true(status_matches_plan_directory("done", "- **Status**: completed"))
  assert_true(
    status_matches_plan_directory(
      "done", "- **Status**: superseded and archived",
    ),
  )
  assert_true(
    status_matches_plan_directory("done", "> 状态：实施完成并归档"),
  )
  assert_true(
    status_matches_plan_directory("done", "- 文档状态：已取代"),
  )
}

///|
test "plan index links are extracted by directory" {
  let readme =
    #|| [alpha](active/alpha.md) | A |
    #|| [beta](done/beta.md) | B |
    #|| [doc](../testing.md) | C |
  assert_eq(markdown_plan_links(readme, "active"), ["active/alpha.md"])
  assert_eq(markdown_plan_links(readme, "done"), ["done/beta.md"])
}
