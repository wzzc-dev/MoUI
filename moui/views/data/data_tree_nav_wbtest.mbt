///|
fn nav_tree() -> Array[TreeItem] {
  [
    tree_item(id="src", label="src", children=[
      tree_item(id="src/a", label="a.mbt", children=[
        tree_item(id="src/a/deep", label="deep.mbt"),
      ]),
      tree_item(id="src/b", label="b.mbt"),
    ]),
    tree_item(id="readme", label="README.md"),
  ]
}

///|
fn nav_key(key : String) -> @core.KeyboardEvent {
  @core.KeyboardEvent::new(key~, pressed=true)
}

///|
test "tree_visible_ids skips collapsed subtrees" {
  let items = nav_tree()
  let collapsed = tree_visible_ids(items, expanded=[])
  assert_eq(collapsed, ["src", "readme"])
  let opened = tree_visible_ids(items, expanded=["src"])
  assert_eq(opened, ["src", "src/a", "src/b", "readme"])
  let deep = tree_visible_ids(items, expanded=["src", "src/a"])
  assert_eq(deep, ["src", "src/a", "src/a/deep", "src/b", "readme"])
}

///|
test "tree_navigation_target walks the visible rows" {
  let items = nav_tree()
  // An empty active row starts the walk at the first row.
  assert_eq(
    tree_navigation_target(nav_key("ArrowDown"), items, expanded=[], active=""),
    Some({ id: "src", effect: Focus, }),
  )
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowDown"),
      items,
      expanded=[],
      active="src",
    ),
    Some({ id: "readme", effect: Focus, }),
  )
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowUp"),
      items,
      expanded=[],
      active="readme",
    ),
    Some({ id: "src", effect: Focus, }),
  )
  // ArrowUp at the first row stays put instead of wrapping around.
  assert_eq(
    tree_navigation_target(nav_key("ArrowUp"), items, expanded=[], active="src"),
    None,
  )
  assert_eq(
    tree_navigation_target(nav_key("Home"), items, expanded=[], active="readme"),
    Some({ id: "src", effect: Focus, }),
  )
  assert_eq(
    tree_navigation_target(nav_key("End"), items, expanded=[], active="src"),
    Some({ id: "readme", effect: Focus, }),
  )
}

///|
test "tree_navigation_target expands and collapses branches" {
  let items = nav_tree()
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowRight"),
      items,
      expanded=[],
      active="src",
    ),
    Some({ id: "src", effect: Expand, }),
  )
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowRight"),
      items,
      expanded=["src"],
      active="src",
    ),
    Some({ id: "src/a", effect: Focus, }),
  )
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowLeft"),
      items,
      expanded=["src"],
      active="src",
    ),
    Some({ id: "src", effect: Collapse, }),
  )
  // A collapsed branch has nothing to collapse, so Left steps out to the parent.
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowLeft"),
      items,
      expanded=["src", "src/a"],
      active="src/a/deep",
    ),
    Some({ id: "src/a", effect: Focus, }),
  )
  // A collapsed leaf without a parent has nowhere to go.
  assert_eq(
    tree_navigation_target(
      nav_key("ArrowLeft"),
      items,
      expanded=[],
      active="src",
    ),
    None,
  )
}

///|
test "tree_navigation_target activates on Enter and Space" {
  let items = nav_tree()
  assert_eq(
    tree_navigation_target(
      nav_key("Enter"),
      items,
      expanded=[],
      active="readme",
    ),
    Some({ id: "readme", effect: Activate, }),
  )
  assert_eq(
    tree_navigation_target(
      nav_key("Space"),
      items,
      expanded=[],
      active="readme",
    ),
    Some({ id: "readme", effect: Activate, }),
  )
  // Activation needs a target row; an empty tree resolves nothing.
  assert_eq(
    tree_navigation_target(nav_key("Enter"), [], expanded=[], active="readme"),
    None,
  )
}

///|
test "tree_navigation_target ignores releases and unknown keys" {
  let items = nav_tree()
  let released = @core.KeyboardEvent::new(key="ArrowDown", pressed=false)
  assert_eq(
    tree_navigation_target(released, items, expanded=[], active="src"),
    None,
  )
  assert_eq(
    tree_navigation_target(
      nav_key("PageDown"),
      items,
      expanded=[],
      active="src",
    ),
    None,
  )
}

///|
test "tree_navigation_target falls back to the physical key code" {
  let items = nav_tree()
  let logical_only = @core.KeyboardEvent::new(
    key="",
    code="ArrowDown",
    pressed=true,
  )
  assert_eq(
    tree_navigation_target(logical_only, items, expanded=[], active="src"),
    Some({ id: "readme", effect: Focus, }),
  )
}
